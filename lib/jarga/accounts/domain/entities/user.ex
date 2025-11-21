defmodule Jarga.Accounts.Domain.Entities.User do
  @moduledoc """
  Schema for user accounts.

  This module defines the User entity with validation logic only.
  Password hashing is handled by the infrastructure layer (PasswordService).
  Password verification (read-only operation) remains in this module.

  ## Responsibilities

  - Data structure definition
  - Validation rules (format, length, required fields)
  - Password verification (Bcrypt read-only operations)

  ## NOT Responsible For

  - Password hashing (handled by PasswordService in infrastructure layer)
  - Database uniqueness checks (handled at database level via unique_constraint)
  - External API calls or I/O operations
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:role, :string)
    field(:status, :string)
    field(:avatar_url, :string)
    field(:confirmed_at, :utc_datetime)
    field(:authenticated_at, :utc_datetime, virtual: true)
    field(:last_login, :naive_datetime)
    field(:date_created, :naive_datetime)
    field(:preferences, :map, default: %{})

    # Legacy timestamp fields - not using standard inserted_at/updated_at
    # timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)
      |> update_change(:email, &String.downcase/1)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
      
  Note: Password hashing is handled by the infrastructure layer, not in this changeset.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :first_name, :last_name])
    |> validate_required([:first_name, :last_name])
    |> put_change(:date_created, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
    |> put_change(:status, "active")
    |> validate_email(opts)
    |> validate_password_format(opts)
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  Note: Password hashing is handled by the infrastructure layer, not in this changeset.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password_format(opts)
  end

  # Password format validation only - NO hashing
  # Password hashing is handled by the infrastructure layer (PasswordService)
  defp validate_password_format(changeset, _opts) do
    password = get_change(changeset, :password)

    if password do
      changeset
      |> validate_length(:password, min: 12, max: 72)

      # Examples of additional password validation:
      # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
      # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
      # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)

    user
    |> change()
    |> force_change(:confirmed_at, now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
