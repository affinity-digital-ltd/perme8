defmodule Jarga.Projects.UseCases.CreateProject do
  @moduledoc """
  Use case for creating a project in a workspace.

  ## Business Rules

  - Actor must be a member of the workspace
  - Project name is required and must be valid
  - Generates a unique slug for the project

  ## Responsibilities

  - Validate actor has workspace membership
  - Create project with proper attributes
  - Notify workspace members of new project
  """

  @behaviour Jarga.Projects.UseCases.UseCase

  alias Jarga.Repo
  alias Jarga.Accounts.User
  alias Jarga.Projects.Project
  alias Jarga.Projects.Services.EmailAndPubSubNotifier
  alias Jarga.Workspaces

  @doc """
  Executes the create project use case.

  ## Parameters

  - `params` - Map containing:
    - `:actor` - User creating the project
    - `:workspace_id` - ID of the workspace
    - `:attrs` - Project attributes (name, description, etc.)

  - `opts` - Keyword list of options:
    - `:notifier` - Notification service implementation (default: EmailAndPubSubNotifier)

  ## Returns

  - `{:ok, project}` - Project created successfully
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      actor: actor,
      workspace_id: workspace_id,
      attrs: attrs
    } = params

    notifier = Keyword.get(opts, :notifier, EmailAndPubSubNotifier)

    with {:ok, _workspace} <- verify_workspace_membership(actor, workspace_id),
         {:ok, project} <- create_project(actor, workspace_id, attrs) do
      notifier.notify_project_created(project)
      {:ok, project}
    end
  end

  # Verify actor is a member of the workspace
  defp verify_workspace_membership(%User{} = user, workspace_id) do
    Workspaces.verify_membership(user, workspace_id)
  end

  # Create the project
  defp create_project(%User{} = user, workspace_id, attrs) do
    # Convert atom keys to string keys to avoid mixed keys
    string_attrs =
      attrs
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})
      |> Map.put("user_id", user.id)
      |> Map.put("workspace_id", workspace_id)

    %Project{}
    |> Project.changeset(string_attrs)
    |> Repo.insert()
  end
end
