defmodule Accounts.ApiKeys.CreateSteps do
  @moduledoc """
  Step definitions for API Key creation operations.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.Test.StepHelpers

  alias Jarga.Accounts
  alias Jarga.Accounts.ApiKeys.Helpers

  # ============================================================================
  # API KEY CREATION STEPS
  # ============================================================================

  step "I create an API key with the following details:", context do
    table_data = context.datatable.maps
    row = List.first(table_data)

    name = row["Name"]
    description = row["Description"]
    workspace_access_str = row["Workspace Access"]

    workspace_access = Helpers.parse_workspace_access(workspace_access_str)

    {view, context} = ensure_view(context, ~p"/users/settings/api-keys")

    # Click "New API Key" button to show create modal
    # The header contains a div with flex items-center justify-between, and the button is in it
    view
    |> element("div.flex.items-center.justify-between button[phx-click='show_create_modal']")
    |> render_click()

    # Submit the form with API key details
    form_data = %{
      name: name,
      description: description || "",
      workspace_access: workspace_access
    }

    html =
      view
      |> form("#create_form", form_data)
      |> render_submit(event: "create_key")

    # Check if creation was successful by looking for the name in the list
    success? = html =~ name

    context =
      if success? do
        # Extract token from token modal if shown
        # Tokens are 64 characters of URL-safe Base64 (a-z, A-Z, 0-9, -, _)
        plain_token =
          case Regex.run(~r/[a-zA-Z0-9_-]{64}/, html) do
            [token] -> token
            nil -> nil
          end

        # Fetch the created API key from the database to store in context
        user = context[:current_user]
        {:ok, api_keys} = Accounts.list_api_keys(user.id)
        api_key = Enum.find(api_keys, fn k -> k.name == name end)

        context
        |> Map.put(:last_html, html)
        |> Map.put(:plain_token, plain_token)
        |> Map.put(:api_key, api_key)
        |> Map.put(:last_result, :ok)
      else
        context
        |> Map.put(:last_html, html)
        |> Map.put(:last_result, {:error, :creation_failed})
      end

    # Return context directly for data table steps
    Map.put(context, :view, view)
  end

  step "I create an API key with name {string}", %{args: [name]} = context do
    {view, context} = ensure_view(context, ~p"/users/settings/api-keys")

    # Click "New API Key" button to show create modal
    # The header contains a div with flex items-center justify-between, and the button is in it
    view
    |> element("div.flex.items-center.justify-between button[phx-click='show_create_modal']")
    |> render_click()

    # Submit the form with just a name
    form_data = %{
      name: name,
      description: "",
      workspace_access: []
    }

    html =
      view
      |> form("#create_form", form_data)
      |> render_submit(event: "create_key")

    # Check if creation was successful
    success? = html =~ name

    # Extract token from response if successful
    # Tokens are 64 characters of URL-safe Base64 (a-z, A-Z, 0-9, -, _)
    plain_token =
      case success? && Regex.run(~r/[a-zA-Z0-9_-]{64}/, html) do
        [token] -> token
        _ -> nil
      end

    # Fetch the created API key from the database to store in context
    api_key =
      if success? do
        user = context[:current_user]
        {:ok, api_keys} = Accounts.list_api_keys(user.id)
        Enum.find(api_keys, fn k -> k.name == name end)
      else
        nil
      end

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:plain_token, plain_token)
     |> Map.put(:api_key, api_key)
     |> Map.put(:last_result, if(success?, do: :ok, else: {:error, :creation_failed}))}
  end

  step "I attempt to create an API key with access to workspace {string}",
       %{args: [workspace_slug]} = context do
    user = context[:current_user]

    attrs = %{
      name: "Test Key",
      description: "Test description",
      workspace_access: [workspace_slug]
    }

    result = Accounts.create_api_key(user.id, attrs)

    {:ok, Map.put(context, :last_result, result)}
  end
end
