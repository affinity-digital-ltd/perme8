defmodule Workspaces.SetupSteps do
  @moduledoc """
  Step definitions for workspace test setup and fixtures.

  These steps create workspaces and users in various states for testing.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Ecto.Adapters.SQL.Sandbox

  # ============================================================================
  # DATA TABLE STEPS
  # ============================================================================

  step "the following users exist:", context do
    # Access data table using dot notation
    table_data = context.datatable.maps
    workspace = context[:workspace]

    users =
      Enum.reduce(table_data, %{}, fn row, acc ->
        email = row["Email"]
        role = String.to_existing_atom(row["Role"])

        # Create user
        user = user_fixture(%{email: email})

        # Add to workspace if workspace exists in context
        case workspace do
          nil -> :ok
          ws -> add_workspace_member_fixture(ws.id, user, role)
        end

        Map.put(acc, email, user)
      end)

    # Return context directly (no {:ok, }) for data table steps
    Map.put(context, :users, users)
  end

  # ============================================================================
  # USER FIXTURE STEPS
  # ============================================================================

  step "a user {string} exists but is not a member of any workspace",
       %{args: [email]} = context do
    # Check if user already exists in context
    users = Map.get(context, :users, %{})

    user =
      case Map.get(users, email) do
        nil ->
          # Only create user if not already exists
          user_fixture(%{email: email})

        existing_user ->
          existing_user
      end

    {:ok, Map.put(context, :users, Map.put(users, email, user))}
  end

  # ============================================================================
  # WORKSPACE FIXTURE STEPS
  # ============================================================================

  step "a workspace exists with name {string} and slug {string} and color {string}",
       %{args: [name, slug, color]} = context do
    # Only checkout sandbox if not already checked out
    case context[:workspace] do
      nil ->
        case Sandbox.checkout(Jarga.Repo) do
          :ok ->
            Sandbox.mode(Jarga.Repo, {:shared, self()})

          {:already, _owner} ->
            :ok
        end

      _ ->
        :ok
    end

    # Create owner user for workspace
    owner = user_fixture(%{email: "#{slug}_owner@example.com"})

    workspace = workspace_fixture(owner, %{name: name, slug: slug, color: color})

    # Store as additional workspace
    additional_workspaces = Map.get(context, :additional_workspaces, %{})

    {:ok,
     context
     |> Map.put(:additional_workspaces, Map.put(additional_workspaces, slug, workspace))
     |> Map.put(
       :additional_owners,
       Map.put(Map.get(context, :additional_owners, %{}), slug, owner)
     )}
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  def get_workspace_from_context(context, workspace_slug) do
    case workspace_slug do
      "product-team" ->
        context[:workspace]

      "Dev Team" ->
        context[:workspace] || context[:current_workspace]

      "QA Team" ->
        # Look for QA Team in workspaces map or create it
        Map.get(context[:workspaces] || %{}, "qa-team") ||
          Map.get(context[:additional_workspaces] || %{}, "qa-team") ||
          create_workspace_for_test(context, "QA Team", "qa-team")

      slug when is_binary(slug) ->
        # Look in workspaces map first, then additional_workspaces
        Map.get(context[:workspaces] || %{}, slug) ||
          Map.get(context[:additional_workspaces] || %{}, slug)
    end
  end

  defp create_workspace_for_test(context, name, slug) do
    user = context[:current_user]

    if user do
      workspace_fixture(user, %{name: name, slug: slug})
    else
      nil
    end
  end
end
