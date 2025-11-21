defmodule Jarga.Accounts.Infrastructure.Repositories.UserRepository do
  @moduledoc """
  Repository for User data access operations.

  Provides a clean abstraction over database operations for User entities.
  Uses the Queries module for query building and accepts injectable repo
  for testability.

  ## Examples

      iex> UserRepository.get_by_id(user_id)
      %User{}
      
      iex> UserRepository.get_by_email("user@example.com")
      %User{}
      
      iex> UserRepository.exists?(user_id)
      true

  """

  import Ecto.Query, only: [from: 2]

  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Accounts.Infrastructure.Queries.Queries
  alias Jarga.Repo

  @doc """
  Gets a user by ID.

  Returns the user if found, nil otherwise.

  ## Parameters

    - id: The user ID to look up
    - repo: Optional repo for dependency injection (defaults to Jarga.Repo)

  ## Examples

      iex> UserRepository.get_by_id(user_id)
      %User{}
      
      iex> UserRepository.get_by_id("non-existent-id")
      nil

  """
  def get_by_id(id, repo \\ Repo) do
    repo.get(User, id)
  end

  @doc """
  Gets a user by email address (case-insensitive).

  Returns the user if found, nil otherwise.

  ## Parameters

    - email: The email address to look up
    - repo: Optional repo for dependency injection (defaults to Jarga.Repo)

  ## Examples

      iex> UserRepository.get_by_email("user@example.com")
      %User{}
      
      iex> UserRepository.get_by_email("USER@EXAMPLE.COM")
      %User{}

  """
  def get_by_email(email, repo \\ Repo) when is_binary(email) do
    Queries.by_email_case_insensitive(email)
    |> repo.one()
  end

  @doc """
  Checks if a user exists by ID.

  Returns true if the user exists, false otherwise.

  ## Parameters

    - id: The user ID to check
    - repo: Optional repo for dependency injection (defaults to Jarga.Repo)

  ## Examples

      iex> UserRepository.exists?(user_id)
      true
      
      iex> UserRepository.exists?("non-existent-id")
      false

  """
  def exists?(id, repo \\ Repo) do
    repo.exists?(from(u in User, where: u.id == ^id))
  end

  @doc """
  Inserts a new user.

  Returns `{:ok, user}` if successful, `{:error, changeset}` otherwise.

  ## Parameters

    - attrs: Map of user attributes
    - repo: Optional repo for dependency injection (defaults to Jarga.Repo)

  ## Examples

      iex> UserRepository.insert(%{email: "new@example.com", ...})
      {:ok, %User{}}
      
      iex> UserRepository.insert(%{email: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def insert(attrs, repo \\ Repo) when is_map(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Updates an existing user.

  Returns `{:ok, user}` if successful, `{:error, changeset}` otherwise.

  ## Parameters

    - user: The user struct to update
    - attrs: Map of attributes to update
    - repo: Optional repo for dependency injection (defaults to Jarga.Repo)

  ## Examples

      iex> UserRepository.update(user, %{first_name: "Updated"})
      {:ok, %User{}}
      
      iex> UserRepository.update(user, %{email: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def update(user, attrs, repo \\ Repo) when is_map(attrs) do
    user
    |> Ecto.Changeset.cast(attrs, [:first_name, :last_name, :email, :hashed_password])
    |> Ecto.Changeset.validate_required([:first_name, :last_name, :email])
    |> repo.update()
  end
end
