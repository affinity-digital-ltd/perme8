defmodule Jarga.Projects do
  @moduledoc """
  The Projects context.

  Handles project creation, management within workspaces.
  """

  import Ecto.Query, warn: false
  alias Jarga.Repo

  alias Jarga.Accounts.User
  alias Jarga.Projects.Project
  alias Jarga.Workspaces.{Workspace, WorkspaceMember}

  @doc """
  Returns the list of projects for a given workspace.

  Only returns non-archived projects if the user is a member of the workspace.

  ## Examples

      iex> list_projects_for_workspace(user, workspace_id)
      [%Project{}, ...]

  """
  def list_projects_for_workspace(%User{} = user, workspace_id) do
    from(p in Project,
      join: w in Workspace,
      on: p.workspace_id == w.id,
      join: wm in WorkspaceMember,
      on: wm.workspace_id == w.id,
      where: p.workspace_id == ^workspace_id,
      where: wm.user_id == ^user.id,
      where: p.is_archived == false,
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Creates a project for a user in a workspace.

  The user must be a member of the workspace to create projects.

  ## Examples

      iex> create_project(user, workspace_id, %{name: "My Project"})
      {:ok, %Project{}}

      iex> create_project(user, workspace_id, %{name: ""})
      {:error, %Ecto.Changeset{}}

      iex> create_project(user, non_member_workspace_id, %{name: "Project"})
      {:error, :unauthorized}

  """
  def create_project(%User{} = user, workspace_id, attrs) do
    # First verify the user is a member of the workspace
    case verify_workspace_membership(user, workspace_id) do
      {:ok, _workspace} ->
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

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets a single project for a user in a workspace.

  Raises `Ecto.NoResultsError` if the Project does not exist,
  if the user is not a member of the workspace, or if the project
  doesn't belong to the specified workspace.

  ## Examples

      iex> get_project!(user, workspace_id, project_id)
      %Project{}

      iex> get_project!(user, workspace_id, "non-existent-id")
      ** (Ecto.NoResultsError)

  """
  def get_project!(%User{} = user, workspace_id, project_id) do
    from(p in Project,
      join: w in Workspace,
      on: p.workspace_id == w.id,
      join: wm in WorkspaceMember,
      on: wm.workspace_id == w.id,
      where: p.id == ^project_id,
      where: p.workspace_id == ^workspace_id,
      where: wm.user_id == ^user.id
    )
    |> Repo.one!()
  end

  defp verify_workspace_membership(user, workspace_id) do
    query =
      from w in Workspace,
        join: wm in WorkspaceMember,
        on: wm.workspace_id == w.id,
        where: w.id == ^workspace_id,
        where: wm.user_id == ^user.id

    case Repo.one(query) do
      nil ->
        # Check if workspace exists
        if Repo.get(Workspace, workspace_id) do
          {:error, :unauthorized}
        else
          {:error, :workspace_not_found}
        end

      workspace ->
        {:ok, workspace}
    end
  end
end
