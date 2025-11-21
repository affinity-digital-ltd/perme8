defmodule Jarga.Accounts.Application.UseCases.DeliverLoginInstructions do
  @moduledoc """
  Use case for delivering login instructions via magic link.

  ## Business Rules

  - Generates a token with context "login"
  - Token is persisted in database before email is sent
  - Email contains a URL with the encoded token for magic link login
  - Uses UserNotifier to deliver the email

  ## Responsibilities

  - Build email token with context "login"
  - Persist token in database
  - Generate login URL using provided function
  - Deliver email with magic link to user
  """

  @behaviour Jarga.Accounts.Application.UseCases.UseCase

  alias Jarga.Repo
  alias Jarga.Accounts.Domain.Entities.UserToken
  alias Jarga.Accounts.Infrastructure.Notifiers.UserNotifier

  @doc """
  Executes the deliver login instructions use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user requesting login
    - `:url_fun` - Function that takes encoded token and returns magic link URL

  - `opts` - Keyword list of options:
    - `:repo` - Repository module (default: Jarga.Repo)
    - `:notifier` - Notifier function (default: UserNotifier.deliver_login_instructions/2)

  ## Returns

  - Result from the notifier (typically `{:ok, email}`)
  """
  @impl true
  def execute(params, opts \\ []) do
    %{user: user, url_fun: url_fun} = params

    repo = Keyword.get(opts, :repo, Repo)
    notifier = Keyword.get(opts, :notifier, &UserNotifier.deliver_login_instructions/2)

    # Build email token with context "login"
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")

    # Persist token in database
    if is_atom(repo) do
      repo.insert!(user_token)
    else
      repo.insert!.(user_token)
    end

    # Generate login URL
    url = url_fun.(encoded_token)

    # Deliver email with magic link
    notifier.(user, url)
  end
end
