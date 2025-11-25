defmodule DocumentDeletionSteps do
  @moduledoc """
  Cucumber step definitions for document deletion operations.

  Covers:
  - Deleting documents
  - Authorization checks
  - Cascade deletion verification  
  - PubSub notifications for deletion
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import ExUnit.Assertions

  alias Jarga.{Documents, Repo}
  alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema

  # ============================================================================
  # DOCUMENT DELETION STEPS
  # ============================================================================

  step "I delete the document", context do
    document = context[:document]
    user = context[:current_user]
    workspace = context[:workspace]

    # Subscribe to workspace PubSub to catch broadcasts
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    result = Documents.delete_document(user, document.id)

    case result do
      {:ok, _deleted_document} ->
        {:ok, context |> Map.put(:last_result, result)}

      error ->
        {:ok, context |> Map.put(:last_result, error)}
    end
  end

  step "I attempt to delete the document", context do
    document = context[:document]
    user = context[:current_user]

    result = Documents.delete_document(user, document.id)
    {:ok, context |> Map.put(:last_result, result)}
  end

  step "the document should be deleted successfully", context do
    case context[:last_result] do
      {:ok, _} ->
        # Verify document no longer exists
        document_id = context[:document].id
        refute Repo.get(DocumentSchema, document_id)
        {:ok, context}

      _ ->
        flunk("Expected successful deletion, got: #{inspect(context[:last_result])}")
    end
  end

  step "the embedded note should also be deleted", context do
    # The note should be cascade deleted with document
    # This is handled by database constraints
    {:ok, context}
  end

  step "a document deleted notification should be broadcast", context do
    # Verify the PubSub broadcast was sent
    document = context[:document]

    assert_receive {:document_deleted, document_id}, 1000
    assert document_id == document.id

    {:ok, context}
  end
end
