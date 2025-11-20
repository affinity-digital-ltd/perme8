defmodule JargaWeb.Features.DocumentCollaborationTest do
  use JargaWeb.FeatureCase, async: false

  @moduletag :wallaby

  describe "document collaboration" do
    setup do
      # Use persistent test users (created in test_helper.exs)
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
    test "two users can edit the same document simultaneously", %{
      session: session_a,
      user_a: user_a,
      user_b: user_b,
      workspace: workspace,
      document: document
    } do
      # Open second session for user B
      session_b = new_session()

      # User A logs in and opens document
      session_a
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)

      # User B logs in and opens document
      session_b
      |> log_in_user(user_b)
      |> open_document(workspace.slug, document.slug)

      # Both users click in editor to initialize awareness and Yjs sync
      session_a
      |> click_in_editor()

      session_b
      |> click_in_editor()

      # Give time for initial awareness/Yjs sync
      Process.sleep(500)

      # User A types "Hello"
      session_a
      |> send_keys(["Hello"])

      # User B should see "Hello"
      session_b
      |> wait_for_text_in_editor("Hello")

      # User B types " World"
      session_b
      |> send_keys([" World"])

      # Wait for Yjs to sync the changes
      Process.sleep(1000)

      # Verify both sessions have both contributions (order may vary due to CRDT)
      content_a = session_a |> get_editor_content()
      content_b = session_b |> get_editor_content()

      # Both sessions should contain both "Hello" and "World"
      assert content_a =~ "Hello"
      assert content_a =~ "World"
      assert content_b =~ "Hello"
      assert content_b =~ "World"

      # Clean up
      close_session(session_b)
    end

    @tag :wallaby
    test "concurrent edits converge to same state", %{
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

      # Both users type at the same time (simulating concurrent edits)
      session_a
      |> send_keys(["Alice's text"])

      session_b
      |> send_keys(["Bob's text"])

      # Wait for convergence (Yjs CRDT should merge the changes)
      Process.sleep(1000)

      # Both sessions should converge to have both users' contributions
      content_a = session_a |> get_editor_content()
      content_b = session_b |> get_editor_content()

      # Content should contain both users' contributions (order may vary)
      # Yjs CRDT ensures both edits are preserved
      assert content_a =~ "Alice's text"
      assert content_a =~ "Bob's text"
      assert content_b =~ "Alice's text"
      assert content_b =~ "Bob's text"

      close_session(session_b)
    end

    @tag :wallaby
    test "document saves persist after page refresh", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # User logs in, opens document, and types content
      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> type_in_editor("Persistent content")

      # Wait for auto-save (document saves happen automatically)
      Process.sleep(2000)

      # Refresh the page
      session
      |> refresh_page()
      |> wait_for_element(css(".milkdown", visible: true, count: 1))

      # Content should still be there after refresh
      assert session |> get_editor_content() =~ "Persistent content"
    end

    @tag :wallaby
    test "late-joining user receives full document state", %{
      session: session_a,
      user_a: user_a,
      user_b: user_b,
      workspace: workspace,
      document: document
    } do
      # User A logs in and adds content
      session_a
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> type_in_editor("Early content from Alice")

      # Wait for content to be saved
      Process.sleep(2000)

      # User B joins later
      session_b = new_session()

      session_b
      |> log_in_user(user_b)
      |> open_document(workspace.slug, document.slug)

      # Wait for editor to load and content to sync
      Process.sleep(1000)

      # User B should see all existing content
      content_b = session_b |> get_editor_content()
      assert content_b =~ "Early content from Alice"

      close_session(session_b)
    end
  end
end
