defmodule Jarga.Agents.Infrastructure.Schemas.ChatSessionSchemaTest do
  @moduledoc """
  Tests for ChatSessionSchema.
  """
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures
  import Jarga.AgentsFixtures

  alias Jarga.Agents.Infrastructure.Schemas.ChatSessionSchema

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{
        user_id: user.id,
        workspace_id: workspace.id,
        title: "Project Discussion"
      }

      changeset = ChatSessionSchema.changeset(%ChatSessionSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :user_id) == user.id
      assert get_change(changeset, :workspace_id) == workspace.id
      assert get_change(changeset, :title) == "Project Discussion"
    end

    test "valid changeset with project_id" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      attrs = %{
        user_id: user.id,
        workspace_id: workspace.id,
        project_id: project.id,
        title: "Project Chat"
      }

      changeset = ChatSessionSchema.changeset(%ChatSessionSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :project_id) == project.id
    end

    test "valid changeset without title (optional)" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = ChatSessionSchema.changeset(%ChatSessionSchema{}, attrs)

      assert changeset.valid?
    end

    test "invalid without user_id" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{
        workspace_id: workspace.id,
        title: "Test"
      }

      changeset = ChatSessionSchema.changeset(%ChatSessionSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "title is trimmed of whitespace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{
        user_id: user.id,
        workspace_id: workspace.id,
        title: "  Spaced Title  "
      }

      changeset = ChatSessionSchema.changeset(%ChatSessionSchema{}, attrs)

      assert get_change(changeset, :title) == "Spaced Title"
    end

    test "title is limited to 255 characters" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      long_title = String.duplicate("a", 256)

      attrs = %{
        user_id: user.id,
        workspace_id: workspace.id,
        title: long_title
      }

      changeset = ChatSessionSchema.changeset(%ChatSessionSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).title
    end
  end

  describe "title_changeset/2" do
    test "updates title on existing session" do
      session = chat_session_fixture(title: "Old Title")

      changeset = ChatSessionSchema.title_changeset(session, %{title: "New Title"})

      assert changeset.valid?
      assert get_change(changeset, :title) == "New Title"
    end

    test "allows setting title to nil" do
      session = chat_session_fixture(title: "Has Title")

      changeset = ChatSessionSchema.title_changeset(session, %{title: nil})

      assert changeset.valid?
      assert get_change(changeset, :title) == nil
    end

    test "trims whitespace when updating title" do
      session = chat_session_fixture()

      changeset = ChatSessionSchema.title_changeset(session, %{title: "  Trimmed  "})

      assert get_change(changeset, :title) == "Trimmed"
    end
  end
end
