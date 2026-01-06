defmodule Accounts.ApiKeys.UpdateSteps do
  @moduledoc """
  Step definitions for API Key update and revocation operations.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.Test.StepHelpers

  alias Jarga.Accounts
  alias Jarga.Accounts.ApiKeys.Helpers

  # ============================================================================
  # API KEY REVOCATION STEPS
  # ============================================================================

  step "I revoke the API key {string}", %{args: [name]} = context do
    user = context[:current_user]

    # Find the API key by name
    {:ok, api_keys} = Accounts.list_api_keys(user.id)
    api_key = Enum.find(api_keys, fn k -> k.name == name end)

    assert api_key != nil, "Expected to find API key '#{name}'"

    result = Accounts.revoke_api_key(user.id, api_key.id)

    {:ok,
     context
     |> Map.put(:last_result, result)
     |> Map.put(:revoked_api_key, api_key)}
  end

  step "I attempt to revoke the API key {string}", %{args: [name]} = context do
    user = context[:current_user]
    other_api_key = context[:other_api_key]

    # This step expects other_api_key to be set by a prior step like "{string} has an API key named {string}"
    assert other_api_key != nil, "Expected other_api_key to be set in context"
    assert other_api_key.name == name, "Expected other_api_key name to match '#{name}'"

    result = Accounts.revoke_api_key(user.id, other_api_key.id)

    {:ok, Map.put(context, :last_result, result)}
  end

  # ============================================================================
  # API KEY UPDATE STEPS
  # ============================================================================

  step "I update the API key {string} to have access to {string}",
       %{args: [name, workspace_access_str]} = context do
    {view, context} = ensure_view(context, ~p"/users/settings/api-keys")

    workspace_access = Helpers.parse_workspace_access(workspace_access_str)

    # First, we need to get the API key ID from the list
    # Find the API key by name in the context
    user = context[:current_user]
    {:ok, api_keys} = Accounts.list_api_keys(user.id)
    api_key = Enum.find(api_keys, fn k -> k.name == name end)
    assert api_key, "Expected to find API key '#{name}'"

    # Click edit button for the specific API key
    view
    |> element("button[phx-click='edit_key'][phx-value-id='#{api_key.id}']")
    |> render_click()

    # Toggle workspace checkboxes to match desired workspace_access
    # First, get current selected workspaces from the API key
    current_workspaces = api_key.workspace_access

    # Calculate which workspaces to add and remove
    to_add = workspace_access -- current_workspaces
    to_remove = current_workspaces -- workspace_access

    # Remove unwanted workspaces
    Enum.each(to_remove, fn workspace ->
      view
      |> element("input[type='checkbox'][name='workspace_access[]'][value='#{workspace}']")
      |> render_click()
    end)

    # Add new workspaces
    Enum.each(to_add, fn workspace ->
      view
      |> element("input[type='checkbox'][name='workspace_access[]'][value='#{workspace}']")
      |> render_click()
    end)

    # Submit the form
    html =
      view
      |> form("#edit_form")
      |> render_submit()

    success? = html =~ name

    context =
      if success? do
        # Fetch the updated API key from database
        user = context[:current_user]
        {:ok, api_keys} = Accounts.list_api_keys(user.id)
        updated_api_key = Enum.find(api_keys, fn k -> k.id == api_key.id end)

        context
        |> Map.put(:api_key, updated_api_key)
        |> Map.put(:last_result, :ok)
      else
        Map.put(context, :last_result, {:error, :update_failed})
      end

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  step "I update the API key with the following details:", context do
    {view, context} = ensure_view(context, ~p"/users/settings/api-keys")

    table_data = context.datatable.maps
    row = List.first(table_data)

    new_name = row["Name"]
    description = row["Description"]

    # The API key to update should be in context from a previous step
    current_name =
      cond do
        context[:api_key_name] -> context[:api_key_name]
        context[:api_key] -> context[:api_key].name
        true -> nil
      end

    assert current_name, "Expected api_key or api_key_name in context"

    # Get the API key ID
    api_key = context[:api_key]
    assert api_key, "Expected api_key struct in context"

    # Click edit button for the current API key
    view
    |> element("button[phx-click='edit_key'][phx-value-id='#{api_key.id}']")
    |> render_click()

    # Update the name and description
    form_data = %{
      name: new_name,
      description: description
    }

    html =
      view
      |> form("#edit_form", form_data)
      |> render_submit()

    success? = html =~ new_name

    context =
      if success? do
        # Fetch the updated API key from database
        user = context[:current_user]
        {:ok, api_keys} = Accounts.list_api_keys(user.id)
        updated_api_key = Enum.find(api_keys, fn k -> k.id == api_key.id end)

        context
        |> Map.put(:api_key, updated_api_key)
        |> Map.put(:api_key_name, new_name)
        |> Map.put(:last_result, :ok)
      else
        Map.put(context, :last_result, {:error, :update_failed})
      end

    # Return context directly for data table steps
    context
    |> Map.put(:view, view)
    |> Map.put(:last_html, html)
  end
end
