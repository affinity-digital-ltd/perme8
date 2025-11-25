defmodule JargaWeb.FeatureCase.Helpers do
  @moduledoc """
  Helper functions for Wallaby feature tests.
  """

  import Wallaby.Browser
  import Wallaby.Query

  alias Phoenix.Ecto.SQL.Sandbox
  alias Wallaby.Element

  @doc """
  Gets a persistent test user by key.

  Available test users: :alice, :bob, :charlie

  ## Examples

      user = get_test_user(:alice)
      session |> log_in_user(user)

  """
  def get_test_user(key) when is_atom(key) do
    Jarga.TestUsers.get_user(key)
  end

  @doc """
  Logs in a user via the login page.

  Uses the actual login flow to ensure proper authentication in E2E tests.
  """
  def log_in_user(session, user) do
    password = Jarga.TestUsers.get_password(user_key_from_email(user.email))

    session
    |> visit("/users/log-in")
    # Wait for LiveView to fully mount and stabilize
    |> assert_has(css("#login_form_password"))
    |> then(fn session ->
      # Delay for LiveView to stabilize after mount and get DB access
      Process.sleep(500)
      session
    end)
    |> fill_in(css("#login_form_password_email"), with: user.email)
    |> fill_in(css("#login_form_password_password"), with: password)
    |> click(button("Log in and stay logged in"))
  end

  # Helper to get user key from email
  defp user_key_from_email("alice@example.com"), do: :alice
  defp user_key_from_email("bob@example.com"), do: :bob
  defp user_key_from_email("charlie@example.com"), do: :charlie
  # Default fallback
  defp user_key_from_email(_), do: :alice

  @doc """
  Opens a document in the editor for the given user.

  Assumes the user is already logged in.
  """
  def open_document(session, workspace_slug, document_slug) do
    session
    |> visit("/app/workspaces/#{workspace_slug}/documents/#{document_slug}")
    |> take_screenshot(name: "after_navigate_to_document")
    # Wait for Milkdown editor to load
    |> assert_has(css(".milkdown", visible: true, count: 1))
  end

  @doc """
  Types text into the Milkdown editor.

  Clicks in the editor to focus it, then types the text.
  """
  def type_in_editor(session, text) do
    session
    |> click_in_editor()
    |> then(fn session ->
      # Send keys directly to the focused editor
      send_keys(session, [text])
    end)
  end

  @doc """
  Clicks inside the Milkdown editor to focus it and initialize awareness.

  This is necessary for collaborative cursor tracking to work properly.
  The click triggers ProseMirror's selection update, which sets the awareness state.

  NOTE: This directly focuses the ProseMirror editor and sets selection at position 0.
  """
  def click_in_editor(session) do
    session
    |> assert_has(css("#editor-container"))
    |> execute_script("""
      // Find the ProseMirror editor within the container
      const container = document.querySelector('#editor-container');
      const pmEditor = container ? container.querySelector('.ProseMirror') : null;
      
      if (pmEditor) {
        // Focus the editor
        pmEditor.focus();
        
        // Set cursor to start of document to trigger selection update
        const event = new MouseEvent('click', {
          view: window,
          bubbles: true,
          cancelable: true,
          clientX: 10,
          clientY: 10
        });
        pmEditor.dispatchEvent(event);
      }
    """)
    |> then(fn session ->
      # Brief wait for awareness to initialize
      Process.sleep(200)
      session
    end)
  end

  @doc """
  Gets the text content from the Milkdown editor.

  Filters out remote cursor labels to get only the actual document content.
  """
  def get_editor_content(session) do
    text =
      session
      |> find(css(".milkdown"))
      |> Element.text()

    # Remove cursor labels which appear as "Name N." patterns
    # Cursor labels follow the pattern "Firstname L." (name with one-letter last name)
    text
    |> String.split("\n")
    |> Enum.reject(fn line ->
      # Remove lines that are just cursor labels (e.g., "Bob B.", "Alice A.")
      String.match?(line, ~r/^[A-Z][a-z]+ [A-Z]\.$/)
    end)
    |> Enum.join("\n")
  end

  @doc """
  Waits for text to appear in the editor.
  """
  def wait_for_text_in_editor(session, text, _timeout \\ 5000) do
    query = css(".milkdown", text: text, count: 1)

    session
    |> Wallaby.Browser.assert_has(query)
  end

  @doc """
  Simulates keyboard shortcut (e.g., undo, redo).

  Examples:
    - Undo: send_shortcut(session, [:control, "z"])
    - Redo: send_shortcut(session, [:control, :shift, "z"])
  """
  def send_shortcut(session, keys) do
    session
    |> send_keys(keys)
  end

  @doc """
  Triggers undo in the Milkdown editor.

  Uses WebDriver Actions API to send Ctrl+Z properly.
  """
  def undo(session) do
    session
    |> click_in_editor()
    |> then(fn session ->
      # Use execute_script to send proper keyboard combination
      execute_script(session, """
        const el = document.querySelector('#editor-container .ProseMirror');
        if (el) {
          el.focus();
          // Create and dispatch a proper keyboard event
          const event = new KeyboardEvent('keydown', {
            key: 'z',
            code: 'KeyZ',
            keyCode: 90,
            which: 90,
            ctrlKey: true,
            metaKey: false,
            bubbles: true,
            cancelable: true,
            composed: true
          });
          el.dispatchEvent(event);
        }
      """)
    end)
    |> then(fn session ->
      # Brief wait for undo operation to complete
      Process.sleep(300)
      session
    end)
  end

  @doc """
  Triggers redo in the Milkdown editor.

  Uses WebDriver Actions API to send Ctrl+Y properly.
  """
  def redo(session) do
    session
    |> click_in_editor()
    |> then(fn session ->
      # Use execute_script to send proper keyboard combination
      execute_script(session, """
        const el = document.querySelector('#editor-container .ProseMirror');
        if (el) {
          el.focus();
          // Create and dispatch a proper keyboard event
          const event = new KeyboardEvent('keydown', {
            key: 'y',
            code: 'KeyY',
            keyCode: 89,
            which: 89,
            ctrlKey: true,
            metaKey: false,
            bubbles: true,
            cancelable: true,
            composed: true
          });
          el.dispatchEvent(event);
        }
      """)
    end)
    |> then(fn session ->
      # Brief wait for redo operation to complete
      Process.sleep(300)
      session
    end)
  end

  @doc """
  Opens a new browser session (for multi-user tests).

  The new session will share the database transaction with the test process.
  """
  def new_session do
    metadata = Sandbox.metadata_for(Jarga.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    session
  end

  @doc """
  Refreshes the current page.
  """
  def refresh_page(session) do
    session
    |> execute_script("window.location.reload();")
    |> Wallaby.Browser.assert_has(css("body"))
  end

  @doc """
  Waits for an element to appear on the page.
  """
  def wait_for_element(session, query, _timeout \\ 5000) do
    session
    |> Wallaby.Browser.assert_has(query)
  end

  @doc """
  Takes a screenshot for debugging purposes.

  Screenshots are saved to the configured screenshot directory.
  """
  def debug_screenshot(session, name \\ "debug") do
    session
    |> take_screenshot(name: name)
  end

  @doc """
  Saves the current page HTML for debugging purposes.

  HTML is saved to tmp/html/ directory.
  """
  def save_html(session, name \\ "debug") do
    session
    |> then(fn session ->
      # Get HTML using page_source
      html = Wallaby.Browser.page_source(session)

      # Ensure tmp/html directory exists
      File.mkdir_p!("tmp/html")

      # Save HTML to file
      file_path = "tmp/html/#{name}.html"
      File.write!(file_path, html)

      IO.puts("💾 Saved HTML to #{file_path}")

      session
    end)
  end

  @doc """
  Clicks a checkbox element.
  """
  def click_checkbox(session, selector) do
    session
    |> click(css(selector))
  end

  @doc """
  Waits for a checkbox to be in the checked state.
  """
  def wait_for_checkbox_checked(session, selector, _timeout \\ 5000) do
    query = css("#{selector}:checked", count: 1)

    session
    |> Wallaby.Browser.assert_has(query)
  end

  @doc """
  Waits for a checkbox to be in the unchecked state.
  """
  def wait_for_checkbox_unchecked(session, selector, _timeout \\ 5000) do
    query = css("#{selector}:not(:checked)", count: 1)

    session
    |> Wallaby.Browser.assert_has(query)
  end

  @doc """
  Waits for a cursor element to appear (for multi-user cursor tests).

  Note: The remote user must click in their editor before their cursor will appear.
  This is because Yjs awareness only broadcasts cursor position after a selection is set.

  IMPORTANT: Remote cursors are rendered in ProseMirror's virtual DOM (decorations),
  not directly in the HTML DOM. We use JavaScript to query getElementsByClassName
  instead of CSS selectors.
  """
  def wait_for_cursor(session, user_name, timeout \\ 5000) do
    # Remote cursors exist in ProseMirror decorations, accessible via getElementsByClassName
    # We need to poll with JavaScript since they're not in the regular DOM
    session
    |> execute_script("""
      return new Promise((resolve, reject) => {
        const startTime = Date.now();
        const timeout = #{timeout};
        
        function checkForCursor() {
          const cursors = document.getElementsByClassName('remote-cursor');
          for (let cursor of cursors) {
            if (cursor.getAttribute('data-user-name') === '#{user_name}') {
              resolve(true);
              return;
            }
          }
          
          if (Date.now() - startTime > timeout) {
            reject(new Error('Cursor not found for user: #{user_name}'));
            return;
          }
          
          setTimeout(checkForCursor, 100);
        }
        
        checkForCursor();
      });
    """)
    |> then(fn session ->
      # Return session for chaining
      session
    end)
  end

  @doc """
  Waits for a cursor element to disappear.

  Polls using JavaScript getElementsByClassName since cursors are in ProseMirror decorations.
  """
  def wait_for_cursor_to_disappear(session, user_name, timeout \\ 3000) do
    session
    |> execute_script("""
      return new Promise((resolve, reject) => {
        const startTime = Date.now();
        const timeout = #{timeout};
        
        function checkCursorGone() {
          const cursors = document.getElementsByClassName('remote-cursor');
          let found = false;
          
          for (let cursor of cursors) {
            if (cursor.getAttribute('data-user-name') === '#{user_name}') {
              found = true;
              break;
            }
          }
          
          if (!found) {
            resolve(true);
            return;
          }
          
          if (Date.now() - startTime > timeout) {
            reject(new Error('Cursor still present for user: #{user_name}'));
            return;
          }
          
          setTimeout(checkCursorGone, 100);
        }
        
        checkCursorGone();
      });
    """)
    |> then(fn session ->
      # Return session for chaining
      session
    end)
  end

  @doc """
  Ends a browser session.

  Use this to clean up secondary sessions in multi-user tests.
  """
  def close_session(session) do
    Wallaby.end_session(session)
  end

  @doc """
  Pastes text into the editor using clipboard simulation.

  Note: This uses JavaScript to insert text as if it was pasted.
  """
  def paste_in_editor(session, text) do
    escaped_text = String.replace(text, "'", "\\'")

    session
    |> click(css(".milkdown"))
    |> execute_script("""
      const editor = document.querySelector('.milkdown');
      const event = new ClipboardEvent('paste', {
        clipboardData: new DataTransfer()
      });
      event.clipboardData.setData('text/plain', '#{escaped_text}');
      editor.dispatchEvent(event);
    """)
  end

  @doc """
  Presses Enter in the ProseMirror editor using a proper keydown event.

  This ensures the Enter key is properly handled by ProseMirror plugins.
  """
  def press_enter_in_editor(session) do
    session
    |> execute_script("""
      const pmEditor = document.querySelector('#editor-container .ProseMirror');
      if (pmEditor) {
        pmEditor.focus();
        const event = new KeyboardEvent('keydown', {
          key: 'Enter',
          code: 'Enter',
          keyCode: 13,
          which: 13,
          bubbles: true,
          cancelable: true,
          composed: true
        });
        pmEditor.dispatchEvent(event);
      }
    """)
    |> then(fn session ->
      Process.sleep(500)
      session
    end)
  end
end
