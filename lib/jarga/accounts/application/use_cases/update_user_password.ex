defmodule Jarga.Accounts.Application.UseCases.UpdateUserPassword do
  @moduledoc """
  Use case for updating a user's password.

  ## Business Rules

  - User must provide a valid new password that meets format requirements
  - Password is hashed using PasswordService before storage
  - ALL user tokens are deleted after password update for security
  - This invalidates all existing sessions and magic links
  - Operation is executed in a transaction for atomicity

  ## Responsibilities

  - Validate password attributes (length, format, confirmation)
  - Hash the new password using PasswordService
  - Update the user record with new hashed password
  - Retrieve all user tokens before deletion
  - Delete all user tokens in a single operation
  - Return expired tokens list for session management
  """

  @behaviour Jarga.Accounts.Application.UseCases.UseCase

  import Ecto.Changeset, only: [get_change: 2, put_change: 3, delete_change: 2]

  alias Jarga.Repo
  alias Jarga.Accounts.Domain.Entities.{User, UserToken}
  alias Jarga.Accounts.Application.Services.PasswordService
  alias Jarga.Accounts.Infrastructure.Queries.Queries

  @doc """
  Executes the update user password use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user to update
    - `:attrs` - Password attributes (password, password_confirmation)

  - `opts` - Keyword list of options:
    - `:repo` - Repository module (default: Jarga.Repo)
    - `:password_service` - Password service module or function (default: PasswordService.hash_password/1)

  ## Returns

  - `{:ok, {user, expired_tokens}}` - Password updated successfully with list of expired tokens
  - `{:error, changeset}` - Validation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{user: user, attrs: attrs} = params

    repo = Keyword.get(opts, :repo, Repo)
    password_service = Keyword.get(opts, :password_service, &PasswordService.hash_password/1)

    # Validate password attributes
    changeset = User.password_changeset(user, attrs)

    # If changeset is valid and has a password, hash it
    changeset_with_hashed_password =
      if changeset.valid? && get_change(changeset, :password) do
        password = get_change(changeset, :password)

        # Support both module and function for password service
        hashed_password =
          if is_function(password_service, 1) do
            password_service.(password)
          else
            password_service.hash_password(password)
          end

        changeset
        |> put_change(:hashed_password, hashed_password)
        |> delete_change(:password)
      else
        changeset
      end

    # Execute update and token deletion in transaction
    update_user_and_delete_all_tokens(changeset_with_hashed_password, repo)
  end

  # Private helper to update user and delete all tokens in a transaction
  defp update_user_and_delete_all_tokens(changeset, repo) do
    repo.transact(fn ->
      with {:ok, user} <- repo.update(changeset) do
        # Retrieve all tokens before deletion (to return expired list)
        tokens_to_expire = repo.all_by(UserToken, user_id: user.id)

        # Delete all tokens in a single query
        repo.delete_all(Queries.tokens_by_ids(Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
