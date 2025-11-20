defmodule JargaWeb.Features.UndoRedoTest do
  use JargaWeb.FeatureCase, async: false

  @moduletag :wallaby

  describe "undo/redo (client-scoped)" do
    setup do
      # Use persistent test users
      user_a = Jarga.TestUsers.get_user(:alice)
      user_b = Jarga.TestUsers.get_user(:bob)

      # Create a workspace and add user_b as a member
      workspace = workspace_fixture(user_a)
      {:ok, _invitation} = Workspaces.invite_member(user_a, workspace.id, user_b.email, :member)
      {:ok, _membership} = Workspaces.accept_invitation_by_workspace(workspace.id, user_b.id)

      # Create a public document in the workspace so both users can access it
      document = document_fixture(user_a, workspace, nil, %{is_public: true})

      {:ok, user_a: user_a, user_b: user_b, workspace: workspace, document: document}
    end

    @tag :wallaby
    test "undo reverts only local user's changes", %{
      session: session_a,
      user_a: user_a,
      user_b: user_b,
      workspace: workspace,
      document: document
    } do
      session_b = new_session()

      # Both users log in and open document
      session_a
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)

      session_b
      |> log_in_user(user_b)
      |> open_document(workspace.slug, document.slug)

      # Both users click to initialize Yjs sync
      session_a
      |> click_in_editor()

      session_b
      |> click_in_editor()

      Process.sleep(500)

      # User A types "Hello"
      session_a
      |> send_keys(["Hello"])

      # User B types "World"
      session_b
      |> send_keys(["World"])

      # Wait for sync
      Process.sleep(1000)

      # User A undoes their change
      session_a
      |> undo()

      # Wait for undo to process
      Process.sleep(500)

      # User A's content should be undone (no "Hello")
      content_a = session_a |> get_editor_content()
      refute content_a =~ "Hello"
      assert content_a =~ "World"

      # User B's content should still have "World" (unaffected by A's undo)
      content_b = session_b |> get_editor_content()
      assert content_b =~ "World"

      close_session(session_b)
    end

    @tag :wallaby
    test "redo re-applies local user's undone changes", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # User logs in and opens document
      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()

      # User types "Hello"
      session
      |> send_keys(["Hello"])

      Process.sleep(500)

      # Verify "Hello" is there
      content = session |> get_editor_content()
      assert content =~ "Hello"

      # User undoes
      session
      |> undo()

      Process.sleep(500)

      # "Hello" should be gone
      content = session |> get_editor_content()
      refute content =~ "Hello"

      # User redoes
      session
      |> redo()

      Process.sleep(500)

      # "Hello" should reappear
      content = session |> get_editor_content()
      assert content =~ "Hello"
    end

    @tag :wallaby
    test "undo does not affect other users' undo stacks", %{
      session: session_a,
      user_a: user_a,
      user_b: user_b,
      workspace: workspace,
      document: document
    } do
      session_b = new_session()

      # Both users log in and open document
      session_a
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)

      session_b
      |> log_in_user(user_b)
      |> open_document(workspace.slug, document.slug)

      # Both users click to initialize
      session_a
      |> click_in_editor()

      session_b
      |> click_in_editor()

      Process.sleep(500)

      # User A types "A"
      session_a
      |> send_keys(["A"])

      # User B types "B"
      session_b
      |> send_keys(["B"])

      # Wait for sync
      Process.sleep(1000)

      # Both should have both letters
      content_a = session_a |> get_editor_content()
      content_b = session_b |> get_editor_content()
      assert content_a =~ "A"
      assert content_a =~ "B"
      assert content_b =~ "A"
      assert content_b =~ "B"

      # User A undoes their change
      session_a
      |> undo()

      Process.sleep(500)

      # User A should no longer have "A"
      content_a = session_a |> get_editor_content()
      refute content_a =~ "A"
      assert content_a =~ "B"

      # User B should still have both (B's undo stack is independent)
      content_b = session_b |> get_editor_content()
      assert content_b =~ "B"

      # User B can undo their own change independently
      session_b
      |> undo()

      Process.sleep(500)

      # User B should no longer have "B"
      content_b = session_b |> get_editor_content()
      refute content_b =~ "B"

      close_session(session_b)
    end

    @tag :wallaby
    test "undo works correctly after remote changes", %{
      session: session_a,
      user_a: user_a,
      user_b: user_b,
      workspace: workspace,
      document: document
    } do
      session_b = new_session()

      # Both users log in and open document
      session_a
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)

      session_b
      |> log_in_user(user_b)
      |> open_document(workspace.slug, document.slug)

      # Both users click to initialize
      session_a
      |> click_in_editor()

      session_b
      |> click_in_editor()

      Process.sleep(500)

      # User A types "Hello"
      session_a
      |> send_keys(["Hello"])

      Process.sleep(500)

      # User B types "World"
      session_b
      |> send_keys(["World"])

      Process.sleep(500)

      # User A types "!"
      session_a
      |> send_keys(["!"])

      # Wait for all changes to sync
      Process.sleep(1000)

      # Both users should have all content
      content_a = session_a |> get_editor_content()
      content_b = session_b |> get_editor_content()
      assert content_a =~ "Hello"
      assert content_a =~ "World"
      assert content_a =~ "!"
      assert content_b =~ "Hello"
      assert content_b =~ "World"
      assert content_b =~ "!"

      # User A undoes their last change (the "!")
      session_a
      |> undo()

      Process.sleep(500)

      # User A's "!" should be removed, but "Hello" and "World" should remain
      content_a = session_a |> get_editor_content()
      refute content_a =~ "!"
      assert content_a =~ "Hello"
      assert content_a =~ "World"

      # User B should still see all content (remote changes aren't undone)
      content_b = session_b |> get_editor_content()
      assert content_b =~ "Hello"
      assert content_b =~ "World"

      close_session(session_b)
    end
  end
end
