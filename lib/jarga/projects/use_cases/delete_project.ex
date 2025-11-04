defmodule Jarga.Projects.UseCases.DeleteProject do
  @moduledoc """
  Use case for deleting a project from a workspace.

  ## Business Rules

  - Actor must be a member of the workspace
  - Project must exist and belong to the workspace
  - User must have access to the project

  ## Responsibilities

  - Validate actor has project access
  - Delete the project
  - Notify workspace members of project deletion
  """

  @behaviour Jarga.Projects.UseCases.UseCase

  alias Jarga.Repo
  alias Jarga.Accounts.User
  alias Jarga.Projects.Policies.Authorization
  alias Jarga.Projects.Services.EmailAndPubSubNotifier

  @doc """
  Executes the delete project use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User deleting the project
    - `:workspace_id` - ID of the workspace
    - `:project_id` - ID of the project to delete

  - `opts` - Keyword list of options:
    - `:notifier` - Notification service implementation (default: EmailAndPubSubNotifier)

  ## Returns

  - `{:ok, project}` - Project deleted successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      actor: actor,
      workspace_id: workspace_id,
      project_id: project_id
    } = params

    notifier = Keyword.get(opts, :notifier, EmailAndPubSubNotifier)

    with {:ok, project} <- verify_project_access(actor, workspace_id, project_id),
         {:ok, deleted_project} <- delete_project(project) do
      notifier.notify_project_deleted(deleted_project, workspace_id)
      {:ok, deleted_project}
    end
  end

  # Verify actor has access to the project
  defp verify_project_access(%User{} = user, workspace_id, project_id) do
    Authorization.verify_project_access(user, workspace_id, project_id)
  end

  # Delete the project
  defp delete_project(project) do
    Repo.delete(project)
  end
end
