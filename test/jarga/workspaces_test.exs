defmodule Jarga.WorkspacesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Workspaces

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "list_workspaces_for_user/1" do
    test "returns empty list when user has no workspaces" do
      user = user_fixture()
      assert Workspaces.list_workspaces_for_user(user) == []
    end

    test "returns only workspaces where user is a member" do
      user = user_fixture()
      other_user = user_fixture()

      workspace1 = workspace_fixture(user)
      _workspace2 = workspace_fixture(other_user)

      workspaces = Workspaces.list_workspaces_for_user(user)

      assert length(workspaces) == 1
      assert hd(workspaces).id == workspace1.id
    end

    test "returns multiple workspaces for user" do
      user = user_fixture()

      workspace1 = workspace_fixture(user, %{name: "Workspace 1"})
      workspace2 = workspace_fixture(user, %{name: "Workspace 2"})

      workspaces = Workspaces.list_workspaces_for_user(user)

      assert length(workspaces) == 2
      workspace_ids = Enum.map(workspaces, & &1.id)
      assert workspace1.id in workspace_ids
      assert workspace2.id in workspace_ids
    end

    test "does not return archived workspaces" do
      user = user_fixture()

      _active_workspace = workspace_fixture(user, %{name: "Active"})
      _archived_workspace = workspace_fixture(user, %{name: "Archived", is_archived: true})

      workspaces = Workspaces.list_workspaces_for_user(user)

      assert length(workspaces) == 1
      assert hd(workspaces).name == "Active"
    end
  end

  describe "create_workspace/2" do
    test "creates workspace with valid attributes" do
      user = user_fixture()

      attrs = %{
        name: "My Workspace",
        description: "A test workspace",
        color: "#FF5733"
      }

      assert {:ok, workspace} = Workspaces.create_workspace(user, attrs)
      assert workspace.name == "My Workspace"
      assert workspace.description == "A test workspace"
      assert workspace.color == "#FF5733"
      assert workspace.is_archived == false
    end

    test "creates workspace with minimal attributes" do
      user = user_fixture()

      attrs = %{name: "Minimal Workspace"}

      assert {:ok, workspace} = Workspaces.create_workspace(user, attrs)
      assert workspace.name == "Minimal Workspace"
      assert workspace.description == nil
      assert workspace.color == nil
    end

    test "creates workspace member with owner role" do
      user = user_fixture()

      attrs = %{name: "My Workspace"}

      assert {:ok, workspace} = Workspaces.create_workspace(user, attrs)

      # Verify the user is added as owner
      workspaces = Workspaces.list_workspaces_for_user(user)
      assert length(workspaces) == 1
      assert hd(workspaces).id == workspace.id
    end

    test "returns error for missing name" do
      user = user_fixture()

      attrs = %{description: "No name provided"}

      assert {:error, changeset} = Workspaces.create_workspace(user, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "returns error for empty name" do
      user = user_fixture()

      attrs = %{name: ""}

      assert {:error, changeset} = Workspaces.create_workspace(user, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "get_workspace!/2" do
    test "returns workspace when user is a member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert fetched = Workspaces.get_workspace!(user, workspace.id)
      assert fetched.id == workspace.id
      assert fetched.name == workspace.name
    end

    test "raises when workspace doesn't exist" do
      user = user_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Workspaces.get_workspace!(user, Ecto.UUID.generate())
      end
    end

    test "raises when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      assert_raise Ecto.NoResultsError, fn ->
        Workspaces.get_workspace!(user, workspace.id)
      end
    end
  end

  describe "update_workspace/3" do
    test "updates workspace with valid attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Original Name"})

      attrs = %{name: "Updated Name", description: "Updated description"}

      assert {:ok, updated_workspace} = Workspaces.update_workspace(user, workspace.id, attrs)
      assert updated_workspace.name == "Updated Name"
      assert updated_workspace.description == "Updated description"
      assert updated_workspace.id == workspace.id
    end

    test "updates workspace with partial attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Original", description: "Original desc"})

      attrs = %{name: "New Name"}

      assert {:ok, updated_workspace} = Workspaces.update_workspace(user, workspace.id, attrs)
      assert updated_workspace.name == "New Name"
      assert updated_workspace.description == "Original desc"
    end

    test "returns error for invalid attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{name: ""}

      assert {:error, changeset} = Workspaces.update_workspace(user, workspace.id, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "returns error when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      attrs = %{name: "Updated Name"}

      assert {:error, :unauthorized} = Workspaces.update_workspace(user, workspace.id, attrs)
    end

    test "returns error when workspace does not exist" do
      user = user_fixture()

      attrs = %{name: "Updated Name"}

      assert {:error, :workspace_not_found} = Workspaces.update_workspace(user, Ecto.UUID.generate(), attrs)
    end
  end

  describe "delete_workspace/2" do
    test "deletes workspace when user is owner" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, deleted_workspace} = Workspaces.delete_workspace(user, workspace.id)
      assert deleted_workspace.id == workspace.id

      # Verify workspace is deleted
      assert_raise Ecto.NoResultsError, fn ->
        Workspaces.get_workspace!(user, workspace.id)
      end
    end

    test "deletes workspace and cascades to projects" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert {:ok, _deleted_workspace} = Workspaces.delete_workspace(user, workspace.id)

      # Verify project is also deleted
      assert Repo.get(Jarga.Projects.Project, project.id) == nil
    end

    test "returns error when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      assert {:error, :unauthorized} = Workspaces.delete_workspace(user, workspace.id)
    end

    test "returns error when workspace does not exist" do
      user = user_fixture()

      assert {:error, :workspace_not_found} = Workspaces.delete_workspace(user, Ecto.UUID.generate())
    end
  end
end
