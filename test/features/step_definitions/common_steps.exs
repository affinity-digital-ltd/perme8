defmodule CommonSteps do
  @moduledoc """
  Common step definitions shared across all Cucumber features.

  These steps are full-stack integration tests using ConnCase.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Ecto.Adapters.SQL.Sandbox

  # ============================================================================
  # WORKSPACE SETUP STEPS
  # ============================================================================

  step "a workspace exists with name {string} and slug {string}",
       %{args: [name, slug]} = context do
    # Only checkout sandbox if not already checked out (first workspace in Background)
    unless context[:workspace] do
      :ok = Sandbox.checkout(Jarga.Repo)
      Sandbox.mode(Jarga.Repo, {:shared, self()})
    end

    # Create owner user for workspace
    owner = user_fixture(%{email: "#{slug}_owner@example.com"})

    workspace = workspace_fixture(owner, %{name: name, slug: slug})

    # If this is the first workspace (Background), set as primary
    # If this is a second workspace, store separately
    if context[:workspace] do
      # Store as additional workspace
      additional_workspaces = Map.get(context, :additional_workspaces, %{})

      {:ok,
       context
       |> Map.put(:additional_workspaces, Map.put(additional_workspaces, slug, workspace))
       |> Map.put(
         :additional_owners,
         Map.put(Map.get(context, :additional_owners, %{}), slug, owner)
       )}
    else
      # First workspace - set as primary
      {:ok,
       context
       |> Map.put(:workspace, workspace)
       |> Map.put(:workspace_owner, owner)}
    end
  end

  # ============================================================================
  # USER MEMBERSHIP STEPS
  # ============================================================================

  step "a user {string} exists as {word} of workspace {string}",
       %{args: [email, role, _workspace_slug]} = context do
    workspace = context[:workspace]

    # Create user
    user = user_fixture(%{email: email})

    # Add membership based on role
    role_atom = String.to_existing_atom(role)
    add_workspace_member_fixture(workspace.id, user, role_atom)

    # Store user in context by email for easy lookup
    users = Map.get(context, :users, %{})
    {:ok, Map.put(context, :users, Map.put(users, email, user))}
  end

  step "a user {string} exists but is not a member of workspace {string}",
       %{args: [email, _workspace_slug]} = context do
    user = user_fixture(%{email: email})
    users = Map.get(context, :users, %{})
    {:ok, Map.put(context, :users, Map.put(users, email, user))}
  end

  # ============================================================================
  # AUTHENTICATION STEPS
  # ============================================================================

  step "I am logged in as {string}", %{args: [email]} = context do
    user = get_in(context, [:users, email])
    conn = build_conn() |> log_in_user(user)

    {:ok,
     context
     |> Map.put(:conn, conn)
     |> Map.put(:current_user, user)}
  end
end
