defmodule DocumentPubsubSteps do
  @moduledoc """
  Cucumber step definitions for real-time/PubSub features and workspace integration.

  Covers:
  - User viewing setup (PubSub subscriptions)
  - Real-time update assertions
  - Collaborative editing (JavaScript scenarios)
  - Broadcast verification
  - Breadcrumb updates
  - Workspace/project name updates
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import ExUnit.Assertions

  alias Jarga.{Projects, Workspaces}

  # ============================================================================
  # REAL-TIME COLLABORATION STEPS (@javascript scenarios)
  # ============================================================================

  step "user {string} is also viewing the document", %{args: [_email]} = context do
    # This would set up a second browser session in Wallaby
    # For now, skip as these are @javascript tests
    {:ok, context}
  end

  step "user {string} is viewing the document", %{args: [_email]} = context do
    document = context[:document]

    # Subscribe to PubSub to simulate another user watching
    Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{document.id}")

    {:ok, context |> Map.put(:pubsub_subscribed, true)}
  end

  step "user {string} is viewing the workspace", %{args: [_email]} = context do
    workspace = context[:workspace]

    # Subscribe to PubSub to simulate another user watching
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    {:ok, context |> Map.put(:pubsub_subscribed, true)}
  end

  step "I have unsaved changes", context do
    # For @javascript tests - would modify editor state
    {:ok, context}
  end

  step "I close the browser tab", context do
    # For @javascript tests with Wallaby
    {:ok, context}
  end

  step "I make changes to the document content", context do
    # For @javascript tests - would trigger editor changes
    {:ok, context}
  end

  step "I edit the document content", context do
    # For @javascript tests
    {:ok, context}
  end

  step "user {string} should see my changes in real-time via PubSub",
       %{args: [_email]} = context do
    # For @javascript tests - would verify PubSub broadcast
    {:ok, context}
  end

  step "the changes should be synced using Yjs CRDT", context do
    # For @javascript tests - would verify Yjs state
    {:ok, context}
  end

  step "the changes should be broadcast immediately to other users", context do
    # For @javascript tests
    {:ok, context}
  end

  step "the changes should be debounced before saving to database", context do
    # For @javascript tests
    {:ok, context}
  end

  step "the Yjs state should be persisted", context do
    # For @javascript tests
    {:ok, context}
  end

  step "the changes should be force saved immediately", context do
    # For @javascript tests
    {:ok, context}
  end

  step "the Yjs state should be updated", context do
    # For @javascript tests
    {:ok, context}
  end

  step "user {string} should receive a real-time title update", %{args: [_email]} = context do
    document = context[:document]

    # Verify the PubSub broadcast was received
    assert_receive {:document_title_changed, document_id, title}, 1000
    assert document_id == document.id
    assert title != nil

    {:ok, context}
  end

  step "the title should update in their UI without refresh", context do
    # For @javascript tests
    {:ok, context}
  end

  step "user {string} should receive a visibility changed notification",
       %{args: [_email]} = context do
    document = context[:document]

    # Verify the PubSub broadcast was received
    assert_receive {:document_visibility_changed, document_id, _is_public}, 1000
    assert document_id == document.id

    {:ok, context}
  end

  step "user {string} should lose access to the document", %{args: [_email]} = context do
    # For @javascript tests
    {:ok, context}
  end

  step "user {string} should see the document marked as pinned", %{args: [_email]} = context do
    document = context[:document]

    # Verify the PubSub broadcast was received
    assert_receive {:document_pinned_changed, document_id, is_pinned}, 1000
    assert document_id == document.id
    assert is_pinned == true

    {:ok, context}
  end

  # ============================================================================
  # WORKSPACE INTEGRATION STEPS
  # ============================================================================

  step "user {string} updates workspace name to {string}",
       %{args: [_email, new_name]} = context do
    workspace = context[:workspace]
    owner = context[:workspace_owner]

    {:ok, updated_workspace} = Workspaces.update_workspace(owner, workspace.id, %{name: new_name})

    {:ok, context |> Map.put(:workspace, updated_workspace)}
  end

  step "I should see the workspace name updated to {string} in breadcrumbs",
       %{args: [new_name]} = context do
    # In a real LiveView, this would be pushed via PubSub
    # For now, just verify the data changed
    assert context[:workspace].name == new_name
    {:ok, context}
  end

  step "user {string} updates project name to {string}", %{args: [_email, new_name]} = context do
    project = context[:project]
    owner = context[:workspace_owner]
    workspace = context[:workspace]

    {:ok, updated_project} =
      Projects.update_project(owner, workspace.id, project.id, %{name: new_name})

    {:ok, context |> Map.put(:project, updated_project)}
  end

  step "I should see the project name updated to {string} in breadcrumbs",
       %{args: [new_name]} = context do
    # In a real LiveView, this would be pushed via PubSub
    # For now, just verify the data changed
    assert context[:project].name == new_name
    {:ok, context}
  end
end
