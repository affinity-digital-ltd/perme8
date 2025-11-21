defmodule Jarga.Accounts do
  @moduledoc """
  Public API for account management operations.

  This context module serves as a thin facade over the Accounts bounded context,
  delegating complex operations to use cases in the application layer while
  providing simple data access for reads.

  ## Architecture

  - **Simple reads** → Direct database queries via Repo
  - **Complex operations** → Delegated to use cases in `Application.UseCases`
  - **Business rules** → Encapsulated in domain policies

  ## Key Use Cases

  - `UseCases.RegisterUser` - User registration with password hashing
  - `UseCases.LoginByMagicLink` - Passwordless login via magic link
  - `UseCases.UpdateUserPassword` - Password updates with token expiry
  - `UseCases.UpdateUserEmail` - Email change with verification
  - `UseCases.GenerateSessionToken` - Session token generation
  - `UseCases.DeliverLoginInstructions` - Magic link email delivery
  - `UseCases.DeliverUserUpdateEmailInstructions` - Email change verification

  ## Domain Policies

  - `AuthenticationPolicy` - Authentication business rules (sudo mode)
  - `TokenPolicy` - Token expiration and validity rules
  """

  # Core context - cannot depend on JargaWeb (interface layer)
  # Exports: Main context module and shared types (User, Scope)
  # Internal modules (UserToken, UserNotifier) remain private
  use Boundary,
    top_level?: true,
    deps: [Jarga.Repo, Jarga.Mailer],
    exports: [
      {Domain.Entities.User, []},
      {Domain.Scope, []},
      {Application.Services.PasswordService, []}
    ]

  import Ecto.Query, warn: false
  alias Jarga.Repo

  alias Jarga.Accounts.Domain.Entities.{User, UserToken}
  alias Jarga.Accounts.Domain.Policies.AuthenticationPolicy
  alias Jarga.Accounts.Infrastructure.Queries.Queries
  alias Jarga.Accounts.Application.UseCases

  ## Database getters

  @doc """
  Gets a user by email. Returns `nil` if not found.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email (case-insensitive). Returns `nil` if not found.
  """
  def get_user_by_email_case_insensitive(email) when is_binary(email) do
    email
    |> Queries.by_email_case_insensitive()
    |> Repo.one()
  end

  @doc """
  Gets a user by email and password.

  Returns the user only if the password is valid AND the email is confirmed.
  Returns `nil` otherwise.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)

    if User.valid_password?(user, password) and user.confirmed_at != nil do
      user
    else
      nil
    end
  end

  @doc """
  Gets a single user. Raises `Ecto.NoResultsError` if not found.
  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user with the given attributes.

  Delegates to `UseCases.RegisterUser` which handles password hashing
  and user creation in a transaction.
  """
  def register_user(attrs) do
    UseCases.RegisterUser.execute(%{attrs: attrs})
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.

  Delegates to `AuthenticationPolicy.sudo_mode?/2`.
  """
  def sudo_mode?(user, minutes \\ -20) do
    AuthenticationPolicy.sudo_mode?(user, minutes)
  end

  @doc """
  Returns a changeset for changing the user email.
  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  Delegates to `UseCases.UpdateUserEmail` which verifies the token,
  updates the email, and deletes the token in a transaction.
  """
  def update_user_email(user, token) do
    UseCases.UpdateUserEmail.execute(%{
      user: user,
      token: token
    })
  end

  @doc """
  Returns a changeset for changing the user password.
  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Delegates to `UseCases.UpdateUserPassword` which hashes the password,
  updates the user, and expires all existing tokens in a transaction.

  Returns `{:ok, {user, expired_tokens}}` or `{:error, changeset}`.
  """
  def update_user_password(user, attrs) do
    UseCases.UpdateUserPassword.execute(%{user: user, attrs: attrs})
  end

  ## Session

  @doc """
  Generates a session token for the user.

  Delegates to `UseCases.GenerateSessionToken`.
  """
  def generate_user_session_token(user) do
    UseCases.GenerateSessionToken.execute(%{user: user})
  end

  @doc """
  Gets the user by session token.

  Returns `{user, token_inserted_at}` if valid, `nil` otherwise.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = Queries.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user by magic link token. Returns `nil` if invalid.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- Queries.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link token.

  Delegates to `UseCases.LoginByMagicLink` which handles three cases:
  1. Confirmed user → login and expire token
  2. Unconfirmed user without password → confirm, login, expire all tokens
  3. Unconfirmed user with password → confirm, login, expire token

  Returns `{:ok, {user, expired_tokens}}` or `{:error, reason}`.
  """
  def login_user_by_magic_link(token) do
    UseCases.LoginByMagicLink.execute(%{token: token})
  end

  @doc """
  Delivers email update instructions to the user.

  Delegates to `UseCases.DeliverUserUpdateEmailInstructions` which generates
  a change email token and sends verification email.
  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    UseCases.DeliverUserUpdateEmailInstructions.execute(%{
      user: user,
      current_email: current_email,
      url_fun: update_email_url_fun
    })
  end

  @doc """
  Delivers magic link login instructions to the user.

  Delegates to `UseCases.DeliverLoginInstructions` which generates
  a login token and sends magic link email.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    UseCases.DeliverLoginInstructions.execute(%{
      user: user,
      url_fun: magic_link_url_fun
    })
  end

  @doc """
  Deletes the session token.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(Queries.tokens_by_token_and_context(token, "session"))
    :ok
  end

  @doc """
  Gets a user token by user_id (primarily for testing).
  """
  def get_user_token_by_user_id(user_id) do
    Repo.get_by!(UserToken, user_id: user_id)
  end

  ## User preferences

  @doc """
  Gets a user's selected agent for a specific workspace.
  Returns nil if no preference is set.
  """
  def get_selected_agent_id(user_id, workspace_id)
      when is_binary(user_id) and is_binary(workspace_id) do
    case Repo.get(User, user_id) do
      nil -> nil
      user -> get_in(user.preferences, ["selected_agents", workspace_id])
    end
  end

  @doc """
  Sets a user's selected agent for a specific workspace.
  """
  def set_selected_agent_id(user_id, workspace_id, agent_id)
      when is_binary(user_id) and is_binary(workspace_id) and is_binary(agent_id) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :user_not_found}

      user ->
        selected_agents = Map.get(user.preferences, "selected_agents", %{})
        updated_selected_agents = Map.put(selected_agents, workspace_id, agent_id)

        updated_preferences =
          Map.put(user.preferences, "selected_agents", updated_selected_agents)

        user
        |> Ecto.Changeset.change(preferences: updated_preferences)
        |> Repo.update()
    end
  end
end
