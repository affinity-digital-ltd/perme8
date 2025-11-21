defmodule Jarga.Accounts.Application.UseCases.LoginByMagicLink do
  @moduledoc """
  Use case for logging in a user via a magic link token.

  ## Business Rules

  There are three cases to consider based on user state:

  ### Case 1: Confirmed user (with or without password)
  - User has already confirmed their email
  - Delete only the magic link token
  - Return the user with empty expired tokens list

  ### Case 2: Unconfirmed user without password
  - User has not confirmed their email and no password is set
  - Confirm the user
  - Delete ALL tokens (including any session tokens)
  - Return the user with list of expired tokens
  - This is the strictest case for security

  ### Case 3: Unconfirmed user with password
  - User registered with password but hasn't confirmed email yet
  - Confirm the user when they click the magic link (proves email ownership)
  - Delete only the magic link token
  - Keep other tokens (like session tokens) intact

  ## Responsibilities

  - Verify the magic link token exists and is valid
  - Determine which case applies based on user state
  - Confirm user if needed
  - Delete appropriate tokens based on the case
  - Execute all operations in a transaction for atomicity
  """

  @behaviour Jarga.Accounts.Application.UseCases.UseCase

  alias Jarga.Repo
  alias Jarga.Accounts.Domain.Entities.{User, UserToken}
  alias Jarga.Accounts.Infrastructure.Queries.Queries

  @doc """
  Executes the login by magic link use case.

  ## Parameters

  - `params` - Map containing:
    - `:token` - The magic link token (string)

  - `opts` - Keyword list of options:
    - `:repo` - Repository module (default: Jarga.Repo)

  ## Returns

  - `{:ok, {user, expired_tokens}}` - User logged in successfully
  - `{:error, :invalid_token}` - Token format is invalid
  - `{:error, :not_found}` - Token not found in database
  """
  @impl true
  def execute(params, opts \\ []) do
    %{token: token} = params
    repo = Keyword.get(opts, :repo, Repo)

    with {:ok, query} <- Queries.verify_magic_link_token_query(token),
         result when not is_nil(result) <- repo.one(query) do
      handle_magic_link_result(result, repo)
    else
      nil -> {:error, :not_found}
      :error -> {:error, :invalid_token}
    end
  end

  # Case 3: Unconfirmed user with password - confirm and delete only the magic link token
  defp handle_magic_link_result(
         {%User{confirmed_at: nil, hashed_password: hash} = user, token},
         repo
       )
       when not is_nil(hash) do
    # For password-based registration, we confirm the user when they click the magic link
    # This is safe because they have proven ownership of the email
    case User.confirm_changeset(user) |> repo.update() do
      {:ok, confirmed_user} ->
        # Delete only the magic link token after confirmation
        repo.delete!(token)
        {:ok, {confirmed_user, []}}

      error ->
        error
    end
  end

  # Case 2: Unconfirmed user without password - confirm and delete ALL tokens
  defp handle_magic_link_result({%User{confirmed_at: nil} = user, _token}, repo) do
    repo.transact(fn ->
      with {:ok, user} <- user |> User.confirm_changeset() |> repo.update() do
        tokens_to_expire = repo.all_by(UserToken, user_id: user.id)
        repo.delete_all(Queries.tokens_by_ids(Enum.map(tokens_to_expire, & &1.id)))
        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  # Case 1: Already confirmed user - just delete the token
  defp handle_magic_link_result({user, token}, repo) do
    repo.delete!(token)
    {:ok, {user, []}}
  end
end
