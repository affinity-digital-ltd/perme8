defmodule Jarga.Workspaces do
  @moduledoc """
  The Workspaces context.

  Handles workspace creation, management, and membership.
  """

  import Ecto.Query, warn: false
  alias Jarga.Repo

  alias Jarga.Accounts.User
  alias Jarga.Workspaces.{Workspace, WorkspaceMember}

  @doc """
  Returns the list of workspaces for a given user.

  Only returns non-archived workspaces where the user is a member.

  ## Examples

      iex> list_workspaces_for_user(user)
      [%Workspace{}, ...]

  """
  def list_workspaces_for_user(%User{} = user) do
    from(w in Workspace,
      join: wm in WorkspaceMember,
      on: wm.workspace_id == w.id,
      where: wm.user_id == ^user.id,
      where: w.is_archived == false,
      order_by: [desc: w.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Creates a workspace for a user.

  Automatically adds the creating user as an owner of the workspace.

  ## Examples

      iex> create_workspace(user, %{name: "My Workspace"})
      {:ok, %Workspace{}}

      iex> create_workspace(user, %{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_workspace(%User{} = user, attrs) do
    Repo.transact(fn ->
      with {:ok, workspace} <- create_workspace_record(attrs),
           {:ok, _member} <- add_member_as_owner(workspace, user) do
        {:ok, workspace}
      end
    end)
  end

  defp create_workspace_record(attrs) do
    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end

  defp add_member_as_owner(workspace, user) do
    %WorkspaceMember{}
    |> WorkspaceMember.changeset(%{
      workspace_id: workspace.id,
      user_id: user.id,
      email: user.email,
      role: :owner,
      joined_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  @doc """
  Gets a single workspace for a user.

  Raises `Ecto.NoResultsError` if the Workspace does not exist or
  if the user is not a member of the workspace.

  ## Examples

      iex> get_workspace!(user, workspace_id)
      %Workspace{}

      iex> get_workspace!(user, "non-existent-id")
      ** (Ecto.NoResultsError)

  """
  def get_workspace!(%User{} = user, id) do
    from(w in Workspace,
      join: wm in WorkspaceMember,
      on: wm.workspace_id == w.id,
      where: w.id == ^id,
      where: wm.user_id == ^user.id
    )
    |> Repo.one!()
  end

  @doc """
  Updates a workspace for a user.

  The user must be a member of the workspace to update it.

  ## Examples

      iex> update_workspace(user, workspace_id, %{name: "Updated Name"})
      {:ok, %Workspace{}}

      iex> update_workspace(user, workspace_id, %{name: ""})
      {:error, %Ecto.Changeset{}}

      iex> update_workspace(user, non_member_workspace_id, %{name: "Updated"})
      {:error, :unauthorized}

  """
  def update_workspace(%User{} = user, workspace_id, attrs) do
    case verify_workspace_membership(user, workspace_id) do
      {:ok, workspace} ->
        workspace
        |> Workspace.changeset(attrs)
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a workspace for a user.

  The user must be a member of the workspace to delete it.
  Deleting a workspace will cascade delete all associated projects.

  ## Examples

      iex> delete_workspace(user, workspace_id)
      {:ok, %Workspace{}}

      iex> delete_workspace(user, non_member_workspace_id)
      {:error, :unauthorized}

  """
  def delete_workspace(%User{} = user, workspace_id) do
    case verify_workspace_membership(user, workspace_id) do
      {:ok, workspace} ->
        Repo.delete(workspace)

      {:error, reason} ->
        {:error, reason}
    end
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
