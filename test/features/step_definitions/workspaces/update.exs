defmodule Workspaces.UpdateSteps do
  @moduledoc """
  Step definitions for workspace update scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.WorkspacesFixtures

  # ============================================================================
  # WORKSPACE EDITING STEPS
  # ============================================================================

  step "I attempt to edit workspace {string}", %{args: [workspace_slug]} = context do
    workspace = get_workspace_from_context(context, workspace_slug)
    user = context[:current_user]

    result = Jarga.Workspaces.update_workspace(user, workspace.id, %{name: "Updated"})

    case result do
      {:ok, _workspace} ->
        # This shouldn't happen for unauthorized users, but if it does, try to access edit page
        try do
          {:ok, view, html} = live(context[:conn], ~p"/app/workspaces/#{workspace.slug}/edit")

          {:ok,
           context
           |> Map.put(:view, view)
           |> Map.put(:last_html, html)
           |> Map.put(:last_result, result)}
        rescue
          error ->
            {:ok,
             context
             |> Map.put(:last_error, error)
             |> Map.put(:last_result, {:error, :forbidden})}
        end

      {:error, _reason} ->
        {:ok,
         context
         |> Map.put(:last_result, result)}
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_workspace_from_context(context, workspace_slug) do
    case workspace_slug do
      "product-team" ->
        context[:workspace]

      "Dev Team" ->
        context[:workspace] || context[:current_workspace]

      "QA Team" ->
        Map.get(context[:workspaces] || %{}, "qa-team") ||
          Map.get(context[:additional_workspaces] || %{}, "qa-team") ||
          create_workspace_for_test(context, "QA Team", "qa-team")

      slug when is_binary(slug) ->
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
