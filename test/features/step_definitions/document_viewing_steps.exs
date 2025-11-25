defmodule DocumentViewingSteps do
  @moduledoc """
  Cucumber step definitions for document viewing and access control.

  Covers:
  - Viewing documents
  - Attempting to view (with authorization)
  - Read-only indicators
  - Edit permissions
  - Access control assertions
  - Breadcrumbs
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import Phoenix.LiveViewTest
  import ExUnit.Assertions

  alias Jarga.Repo
  alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema

  # ============================================================================
  # DOCUMENT VIEWING STEPS
  # ============================================================================

  step "I view document {string} in workspace {string}",
       %{args: [_title, _workspace_slug]} = context do
    workspace = context[:workspace]
    document = context[:document]
    conn = context[:conn]

    # View document via LiveView
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok, context |> Map.put(:last_html, html)}
  end

  step "I attempt to view document {string} in workspace {string}",
       %{args: [_title, _workspace_slug]} = context do
    workspace = context[:workspace]
    document = context[:document]
    conn = context[:conn]

    # Try to view document (should fail for unauthorized users)
    try do
      result = live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      case result do
        {:ok, _view, html} ->
          {:ok, context |> Map.put(:last_html, html) |> Map.put(:last_result, {:ok, :accessed})}

        {:error, {:redirect, _redirect}} ->
          # LiveView redirected (likely due to authorization failure)
          {:ok, context |> Map.put(:last_result, {:error, :unauthorized})}

        error ->
          {:ok, context |> Map.put(:last_result, error)}
      end
    rescue
      error ->
        # Caught an exception (e.g., authorization check raised)
        {:ok,
         context |> Map.put(:last_error, error) |> Map.put(:last_result, {:error, :unauthorized})}
    end
  end

  step "I am viewing the document", context do
    workspace = context[:workspace]
    document = context[:document]
    conn = context[:conn]

    result = live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    case result do
      {:ok, view, html} ->
        {:ok,
         context
         |> Map.put(:view, view)
         |> Map.put(:last_html, html)}

      error ->
        {:ok, context |> Map.put(:last_result, error)}
    end
  end

  step "I view the document", context do
    workspace = context[:workspace]
    document = context[:document]
    conn = context[:conn]
    current_user = context[:current_user]

    # Refresh document from DB to ensure it exists
    fresh_document = Repo.get(DocumentSchema, document.id)

    if fresh_document == nil do
      flunk("DocumentSchema not found in database: id=#{document.id}")
    end

    if fresh_document.user_id != current_user.id do
      flunk(
        "DocumentSchema user_id mismatch: document.user_id=#{fresh_document.user_id}, current_user.id=#{current_user.id}"
      )
    end

    result = live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    case result do
      {:ok, view, html} ->
        {:ok,
         context
         |> Map.put(:view, view)
         |> Map.put(:last_html, html)}

      error ->
        flunk(
          "Failed to view document: #{inspect(error)}\n" <>
            "DocumentSchema: slug=#{fresh_document.slug}, workspace_id=#{fresh_document.workspace_id}, user_id=#{fresh_document.user_id}, is_public=#{fresh_document.is_public}, project_id=#{inspect(fresh_document.project_id)}\n" <>
            "User: id=#{current_user.id}\n" <>
            "Workspace: id=#{workspace.id}, slug=#{workspace.slug}"
        )
    end
  end

  # ============================================================================
  # VIEWING ASSERTIONS
  # ============================================================================

  step "I should see the document content", context do
    html = context[:last_html]
    document = context[:document]

    assert html =~ document.title
    {:ok, context}
  end

  step "I should be able to edit the document", context do
    html = context[:last_html]

    # Check for edit button or edit form presence
    assert html =~ "edit" or html =~ "Edit"
    {:ok, context}
  end

  step "I should see a read-only indicator", context do
    html = context[:last_html]

    assert html =~ "read-only" or html =~ "Read Only" or html =~ "view only"
    {:ok, context}
  end

  step "I should not be able to edit the document", context do
    html = context[:last_html]

    # Should NOT have edit buttons/forms
    refute html =~ ~r/id="edit.*button"/
    {:ok, context}
  end

  step "I should see breadcrumbs showing {string}", %{args: [breadcrumb_text]} = context do
    html = context[:last_html]

    # Breadcrumb text like "Product Team > Mobile App > Specs"
    # needs to check for each part in the HTML breadcrumbs
    parts = String.split(breadcrumb_text, " > ")

    Enum.each(parts, fn part ->
      assert html =~ part, "Expected breadcrumb to contain '#{part}'"
    end)

    {:ok, context}
  end
end
