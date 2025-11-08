# Chat to Note Text Insertion - Implementation Plan

## Overview

This document outlines the implementation plan for inserting text from chat messages into notes while maintaining architectural boundaries and following Phoenix LiveView best practices.

### Key Requirements

1. **Context Detection**: Chat panel must detect when user is on a **page** (not workspace/project view)
2. **Conditional Display**: Insert link only shown when:
   - User is viewing a page (not workspace or project)
   - Page has a note attached
   - Message is from assistant (not user)
3. **Minimal UI**: Insert link is **clickable text only** ("insert") to minimize space
   - No icon, no button styling
   - Only visible on message hover
   - Small font size (0.75rem)
4. **Architecture**: Maintains clean boundaries, uses `push_event` + JavaScript hooks

### Visual Design

```
┌─────────────────────────────────┐
│ AI Assistant                    │ ← Message header
├─────────────────────────────────┤
│ Here's some helpful content     │ ← Message content
│ that you might want to save.    │
│                                 │
│ insert ← appears on hover       │ ← Subtle clickable text
└─────────────────────────────────┘
```

## Current Architecture

### Chat Implementation
- **Context**: `Jarga.Documents` (top-level boundary)
- **Web Layer**: `JargaWeb.ChatLive.Panel` (LiveComponent mounted globally in admin layout)
- **Storage**: Messages stored with role ("user"/"assistant") and content
- **Integration**: Already has page context integration via `PrepareContext` use case

### Notes Implementation
- **Context**: `Jarga.Notes` (top-level boundary)
- **Technology**: Collaborative editing using Yjs (stores both markdown and binary state)
- **Web Layer**: Embedded in pages via `JargaWeb.AppLive.Pages.Show`
- **Sync**: Real-time synchronization via PubSub and client-side Yjs hooks

### Current Relationship
- Chat reads note content for context (via `Documents.PrepareContext`)
- Separate contexts with clear boundaries
- No direct schema associations
- Communication only through exported public APIs

## Recommended Approach

**Solution**: Client-Side Push Event + JavaScript Hook

### Architecture Flow

```
User clicks "Insert"
    ↓
ChatLive.Panel (Interface Layer)
    ↓
handle_event("insert_into_note")
    ↓
push_event("insert-text", %{content: ...})
    ↓
JavaScript Hook (Client-Side)
    ↓
Yjs Editor (Collaborative Editor)
    ↓
Text inserted at cursor position
```

### Why This Approach?

✅ **Maintains architectural boundaries** - No direct coupling between Documents and Notes contexts
✅ **Follows Phoenix best practices** - Uses `push_event/3` + hooks for client interactions
✅ **Works with collaborative editing** - Yjs handles state on client side
✅ **Provides responsive UX** - No server round-trip for insertion
✅ **Minimal code changes** - Focused, surgical implementation

### Boundary Compliance

```
Documents Context (Chat)      Notes Context
      ↓                            ↓
JargaWeb.ChatLive.Panel    JargaWeb.Pages.Show
      ↓                            ↓
    push_event → JavaScript Hook → Yjs Editor
```

**Key Points:**
- `Documents` context doesn't call `Notes` context
- `Notes` context doesn't know about `Documents`
- Communication happens at Interface layer via events
- No business logic involved (pure UI feature)

## Implementation Steps (TDD Approach)

### Phase 1: Chat Message Component UI

#### Step 1.1: Write Test for Insert Button

**File**: `test/jarga_web/live/chat_live/components/message_test.exs`

```elixir
defmodule JargaWeb.ChatLive.Components.MessageTest do
  use JargaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Jarga.Documents.ChatMessage
  alias JargaWeb.ChatLive.Components.Message

  describe "message/1 component" do
    test "renders insert link for assistant messages when note is present" do
      message = %ChatMessage{
        role: "assistant",
        content: "Here's some helpful text"
      }

      html = render_component(&Message.message/1,
        message: message,
        show_insert: true
      )

      assert html =~ "insert"
      assert html =~ ~s(phx-click="insert_into_note")
      assert html =~ ~s(phx-value-content="Here's some helpful text")
      assert html =~ ~s(class="message__insert-link")
    end

    test "does not render insert link for user messages" do
      message = %ChatMessage{
        role: "user",
        content: "My question"
      }

      html = render_component(&Message.message/1,
        message: message,
        show_insert: true
      )

      refute html =~ "insert"
      refute html =~ "message__insert-link"
    end

    test "does not render insert link when show_insert is false" do
      message = %ChatMessage{
        role: "assistant",
        content: "Some text"
      }

      html = render_component(&Message.message/1,
        message: message,
        show_insert: false
      )

      refute html =~ "insert"
      refute html =~ "message__insert-link"
    end

    test "insert link has proper accessibility attributes" do
      message = %ChatMessage{
        role: "assistant",
        content: "Test content"
      }

      html = render_component(&Message.message/1,
        message: message,
        show_insert: true
      )

      assert html =~ ~s(role="button")
      assert html =~ ~s(tabindex="0")
      assert html =~ ~s(title="Insert this text into the current note")
    end
  end
end
```

#### Step 1.2: Implement Insert Link in Component

**File**: `lib/jarga_web/live/chat_live/components/message.ex`

```elixir
defmodule JargaWeb.ChatLive.Components.Message do
  use JargaWeb, :html

  alias Jarga.Documents.ChatMessage

  attr :message, ChatMessage, required: true
  attr :show_insert, :boolean, default: false

  def message(assigns) do
    ~H"""
    <div class={"message message--#{@message.role}"}>
      <div class="message__header">
        <span class="message__role">
          {if @message.role == "assistant", do: "AI", else: "You"}
        </span>
        <span class="message__time">
          {Calendar.strftime(@message.inserted_at, "%I:%M %p")}
        </span>
      </div>

      <div class="message__content">
        {@message.content}
      </div>

      <div :if={@show_insert and @message.role == "assistant"} class="message__actions">
        <span
          phx-click="insert_into_note"
          phx-value-content={@message.content}
          class="message__insert-link"
          role="button"
          tabindex="0"
          title="Insert this text into the current note"
        >
          insert
        </span>
      </div>
    </div>
    """
  end
end
```

**Key Changes:**
- Changed from `<button>` to `<span>` for minimal space
- Removed icon to save space
- Changed text from "Insert into note" to just "insert" (lowercase, subtle)
- Added `role="button"` and `tabindex="0"` for accessibility
- Changed class from button styles to custom `message__insert-link`

### Phase 2: Event Handler in Chat Panel

#### Step 2.1: Write Test for Event Handler

**File**: `test/jarga_web/live/chat_live/panel_test.exs`

```elixir
defmodule JargaWeb.ChatLive.PanelTest do
  use JargaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Jarga.AccountsFixtures
  alias Jarga.WorkspacesFixtures
  alias Jarga.PagesFixtures
  alias Jarga.NotesFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    workspace = WorkspacesFixtures.workspace_fixture(user)
    project = ProjectsFixtures.project_fixture(user, workspace)
    page = PagesFixtures.page_fixture(user, workspace, project)
    note = NotesFixtures.note_fixture(user, workspace, project)

    %{user: user, workspace: workspace, project: project, page: page, note: note}
  end

  describe "insert_into_note event" do
    test "pushes insert-text event to client", %{conn: conn, page: page} do
      conn = log_in_user(conn, page.user)
      {:ok, view, _html} = live(conn, ~p"/app/pages/#{page.id}")

      # Trigger insert event
      view
      |> element("#chat-panel")
      |> render_click("insert_into_note", %{"content" => "Sample text to insert"})

      # Assert that push_event was called
      assert_push_event view, "insert-text", %{content: "Sample text to insert"}
    end

    test "handles empty content gracefully", %{conn: conn, page: page} do
      conn = log_in_user(conn, page.user)
      {:ok, view, _html} = live(conn, ~p"/app/pages/#{page.id}")

      html = view
        |> element("#chat-panel")
        |> render_click("insert_into_note", %{"content" => ""})

      # Should not crash, but may not push event
      refute html =~ "error"
    end
  end
end
```

#### Step 2.2: Implement Event Handler

**File**: `lib/jarga_web/live/chat_live/panel.ex`

Add the event handler to the Panel LiveComponent:

```elixir
defmodule JargaWeb.ChatLive.Panel do
  use JargaWeb, :live_component

  # ... existing code ...

  @impl true
  def handle_event("insert_into_note", %{"content" => content}, socket) do
    # Validate content is not empty
    if String.trim(content) != "" do
      {:noreply,
       socket
       |> push_event("insert-text", %{content: content})
       |> put_flash(:info, "Text sent to note")}
    else
      {:noreply, put_flash(socket, :error, "Cannot insert empty text")}
    end
  end

  # ... existing code ...

  @impl true
  def render(assigns) do
    ~H"""
    <div id="chat-panel" class="chat-panel" data-state={@view_mode}>
      <!-- Existing chat UI -->

      <div class="chat-messages">
        <.message
          :for={msg <- @messages}
          message={msg}
          show_insert={should_show_insert_link?(assigns)}
        />
      </div>

      <!-- Rest of existing UI -->
    </div>
    """
  end

  # Helper to determine when to show insert link
  defp should_show_insert_link?(assigns) do
    # Only show when on a page view with a note attached
    assigns[:page] != nil && assigns[:note] != nil
  end
end
```

### Phase 3: JavaScript Hook for Yjs Integration

#### Step 3.1: Write JavaScript Tests

**File**: `assets/js/hooks/__tests__/note_editor_test.js`

```javascript
import { NoteEditor } from '../note_editor';

describe('NoteEditor Hook', () => {
  let hook;
  let mockEl;
  let mockDoc;
  let mockText;

  beforeEach(() => {
    // Mock Yjs document
    mockText = {
      insert: jest.fn(),
      toString: jest.fn(() => 'existing content')
    };

    mockDoc = {
      getText: jest.fn(() => mockText)
    };

    mockEl = document.createElement('div');

    hook = Object.create(NoteEditor);
    hook.el = mockEl;
    hook.doc = mockDoc;
    hook.editor = {
      getCursorPosition: jest.fn(() => 0),
      focus: jest.fn()
    };
  });

  test('inserts text at cursor position when receiving insert-text event', () => {
    const eventHandler = jest.fn();
    hook.handleEvent = (eventName, callback) => {
      if (eventName === 'insert-text') {
        eventHandler.mockImplementation(callback);
      }
    };

    hook.mounted();

    // Simulate event from LiveView
    eventHandler({ content: 'Inserted text' });

    expect(mockText.insert).toHaveBeenCalledWith(0, 'Inserted text\n\n');
    expect(hook.editor.focus).toHaveBeenCalled();
  });

  test('appends text with proper spacing', () => {
    hook.editor.getCursorPosition = jest.fn(() => 10);

    const eventHandler = jest.fn();
    hook.handleEvent = (eventName, callback) => {
      if (eventName === 'insert-text') {
        eventHandler.mockImplementation(callback);
      }
    };

    hook.mounted();
    eventHandler({ content: 'New paragraph' });

    expect(mockText.insert).toHaveBeenCalledWith(10, 'New paragraph\n\n');
  });
});
```

#### Step 3.2: Implement or Extend Note Editor Hook

**File**: `assets/js/hooks/note_editor.js`

```javascript
/**
 * NoteEditor Hook
 *
 * Handles collaborative editing for notes using Yjs.
 * Listens for insert-text events from LiveView to insert chat content.
 */
export const NoteEditor = {
  mounted() {
    // Existing Yjs setup would be here...
    // this.doc = new Y.Doc()
    // this.provider = new WebsocketProvider(...)
    // this.editor = setupEditor(...)

    // Listen for insert-text events from LiveView (chat panel)
    this.handleEvent("insert-text", ({ content }) => {
      this.insertTextIntoNote(content);
    });
  },

  /**
   * Inserts text into the note at the current cursor position
   * @param {string} content - The text content to insert
   */
  insertTextIntoNote(content) {
    if (!content || typeof content !== 'string') {
      console.warn('Invalid content provided for insertion');
      return;
    }

    // Get the Yjs text type for the note content
    const yText = this.doc.getText('content');

    // Get current cursor position from editor
    const cursorPos = this.editor.getCursorPosition() || yText.length;

    // Insert content with double newline for spacing
    const textToInsert = content.trim() + '\n\n';
    yText.insert(cursorPos, textToInsert);

    // Focus editor and move cursor after inserted text
    this.editor.focus();
    this.editor.setCursorPosition(cursorPos + textToInsert.length);

    console.log(`Inserted ${textToInsert.length} characters at position ${cursorPos}`);
  },

  destroyed() {
    // Existing cleanup...
  }
};
```

**File**: `assets/js/app.js`

Ensure the hook is registered:

```javascript
import { NoteEditor } from "./hooks/note_editor"

let Hooks = {
  NoteEditor: NoteEditor,
  // ... other hooks
}

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: {_csrf_token: csrfToken}
})
```

### Phase 4: Integration Testing

#### Step 4.1: Write End-to-End Test

**File**: `test/jarga_web/live/app_live/pages/show_test.exs`

```elixir
defmodule JargaWeb.AppLive.Pages.ShowTest do
  use JargaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  # ... existing tests ...

  describe "chat to note insertion" do
    @tag :integration
    test "inserting chat message into note pushes event to client", %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)
      page = page_fixture(user, workspace, project)
      note = note_fixture(user, workspace, project)

      # Attach note to page
      Pages.attach_component(page, "note", note.id)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/app/pages/#{page.id}")

      # Verify note is present in assigns
      assert has_element?(view, "#note-editor")

      # Simulate clicking insert link on a chat message
      chat_content = "This is AI-generated content to insert"

      html = view
        |> element("#chat-panel .message__insert-link", "insert")
        |> render_click(%{"content" => chat_content})

      # Verify push_event was triggered
      assert_push_event view, "insert-text", %{content: ^chat_content}

      # Verify no errors occurred
      refute html =~ "error"
    end

    test "insert link only shown when on page with note", %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)
      page = page_fixture(user, workspace, project)
      # Note: no note attached to page

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/app/pages/#{page.id}")

      # Insert links should not be visible
      refute has_element?(view, "#chat-panel .message__insert-link")
    end

    test "insert link not shown on workspace or project views", %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      # Test workspace view
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.id}")
      refute has_element?(view, "#chat-panel .message__insert-link")

      # Test project view
      {:ok, view, _html} = live(conn, ~p"/app/projects/#{project.id}")
      refute has_element?(view, "#chat-panel .message__insert-link")
    end

    test "insert link only shown for assistant messages", %{conn: conn} do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)
      page = page_fixture(user, workspace, project)
      note = note_fixture(user, workspace, project)

      Pages.attach_component(page, "note", note.id)

      # Create chat session with both user and assistant messages
      session = session_fixture(user, workspace, project)
      Documents.save_message(session, "user", "My question")
      Documents.save_message(session, "assistant", "AI response")

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/app/pages/#{page.id}")

      # Load the chat session
      view
        |> element("#chat-panel [phx-click='load_session']")
        |> render_click(%{"session_id" => session.id})

      # Verify insert links only appear on assistant messages
      # User messages should not have insert links
      user_message_element = view
        |> element("#chat-panel .message.message--user")

      refute has_element?(user_message_element, ".message__insert-link")

      # Assistant messages should have insert links
      assistant_message_element = view
        |> element("#chat-panel .message.message--assistant")

      assert has_element?(assistant_message_element, ".message__insert-link", "insert")
    end
  end
end
```

## Conditional Rendering Logic

The insert link should only appear when:

1. ✅ User is viewing a **page** (not just workspace or project)
2. ✅ Page has a **note** attached
3. ✅ Message is from assistant (not user messages)
4. ✅ Note is editable by current user (optional enhancement)

### Implementation in Panel

**Key Point**: The chat panel is mounted globally in the admin layout, so it appears on workspace, project, AND page views. We need to detect specifically when we're on a page with a note.

```elixir
# In Panel component's render function
def render(assigns) do
  ~H"""
  <div id="chat-panel" class="chat-panel">
    <div class="chat-messages">
      <.message
        :for={msg <- @messages}
        message={msg}
        show_insert={should_show_insert_link?(assigns)}
      />
    </div>
  </div>
  """
end

defp should_show_insert_link?(assigns) do
  # Only show when:
  # 1. We have a page (not just workspace/project)
  # 2. That page has a note attached
  # 3. (Optional) Note is editable
  assigns[:page] != nil &&
  assigns[:note] != nil
  # Future enhancement:
  # && assigns[:note_editable] == true
end
```

### How Panel Receives Context

The Panel component receives assigns from the parent LiveView:

```elixir
# In admin layout (lib/jarga_web/components/layouts.ex)
<.live_component
  module={JargaWeb.ChatLive.Panel}
  id="global-chat-panel"
  current_scope={@current_scope}
  current_workspace={@workspace}    # Always present in admin
  current_project={@project}        # Present on project/page views
  page={@page}                      # Only present on page views
  note={@note}                      # Only present when page has note
  page_title={@page_title}
/>
```

When user is on:
- **Workspace view**: `@workspace` present, `@project` and `@page` are `nil`
- **Project view**: `@workspace` and `@project` present, `@page` is `nil`
- **Page view**: All present (`@workspace`, `@project`, `@page`)
- **Page with note**: All present + `@note` is loaded

This ensures insert links only appear on page views with notes.

## CSS Styling

**File**: `assets/css/components/_chat.css`

```css
/* Message actions container - minimal space, hidden by default */
.message__actions {
  margin-top: 0.25rem;
  opacity: 0;
  transition: opacity 0.2s ease-in-out;
}

/* Show actions on message hover */
.message:hover .message__actions {
  opacity: 1;
}

/* Insert link - styled as subtle, clickable text */
.message__insert-link {
  display: inline-block;
  font-size: 0.75rem;
  color: var(--color-blue-600, #2563eb);
  cursor: pointer;
  text-decoration: none;
  padding: 0.125rem 0.25rem;
  border-radius: 0.25rem;
  transition: all 0.15s ease-in-out;
}

.message__insert-link:hover {
  color: var(--color-blue-700, #1d4ed8);
  background-color: var(--color-blue-50, #eff6ff);
  text-decoration: underline;
}

.message__insert-link:active {
  transform: scale(0.95);
}

/* Focus state for accessibility (keyboard navigation) */
.message__insert-link:focus {
  outline: 2px solid var(--color-blue-500, #3b82f6);
  outline-offset: 2px;
}

/* Dark mode support (if applicable) */
@media (prefers-color-scheme: dark) {
  .message__insert-link {
    color: var(--color-blue-400, #60a5fa);
  }

  .message__insert-link:hover {
    color: var(--color-blue-300, #93c5fd);
    background-color: var(--color-blue-900, #1e3a8a);
  }
}
```

**Design Rationale:**
- **Minimal space**: No icon, short text ("insert"), small font size (0.75rem)
- **Subtle appearance**: Colored link text, only visible on hover
- **Clear affordance**: Underline on hover shows it's clickable
- **Accessible**: Focus outline for keyboard navigation, proper ARIA roles
- **Smooth transitions**: Fade in/out, subtle scale on click

## Phoenix LiveView Best Practices Applied

Based on Context7 documentation analysis:

### ✅ 1. Using push_event for Client Communication

**Quote from docs**: "Pushes events from server to client-side JavaScript hooks using Phoenix.LiveView.push_event/3"

Our implementation uses `push_event/3` to send the insert command to the client without requiring a full page update.

### ✅ 2. JavaScript Hooks for Complex UI Interactions

**Quote from docs**: "Enables bidirectional communication, allowing the server to trigger custom JavaScript behaviors on the client"

We use a JavaScript hook to handle the actual insertion into the Yjs editor, keeping the complex client-side logic separate from the server.

### ✅ 3. Component Event Targeting with phx-click

**Quote from docs**: "Events can be sent to the component itself using '@myself' or to other components using DOM ID"

Our button uses `phx-click` with `phx-value-*` attributes to properly scope the event to the component.

### ✅ 4. Stateful LiveComponents

**Quote from docs**: "This component manages its own state and lifecycle, handling events independently from the parent LiveView"

The Chat Panel is a stateful LiveComponent that manages its own messages and events.

### ✅ 5. No Unnecessary Server Round-trips

The actual text insertion happens client-side via the Yjs editor. The server only facilitates the event dispatch, minimizing latency.

## Architectural Compliance Checklist

- ✅ **No forbidden boundary crossings**: Documents and Notes contexts remain independent
- ✅ **Interface layer orchestration**: Communication happens at web layer via events
- ✅ **No business logic in controllers/LiveViews**: Pure UI interaction
- ✅ **Proper use of public APIs**: No access to internal context modules
- ✅ **Respects existing patterns**: Follows established Yjs integration approach
- ✅ **Test-driven development**: Tests written before implementation
- ✅ **Clean Architecture layers**: Domain, Application, Infrastructure, Interface remain separate

## Migration Path

### Phase 1: Basic Implementation (MVP)
- Add subtle insert link to chat messages (text only, minimal space)
- Detect page context to show/hide link appropriately
- Implement event handler in Panel with `push_event`
- Create JavaScript hook for Yjs insertion
- Comprehensive tests (unit, component, integration)

### Phase 2: Enhanced UX (Optional)
- Add brief visual feedback on insertion (fade effect)
- Support text selection (insert only selected portion of message)
- Keyboard shortcuts (e.g., Ctrl+Shift+I to insert last message)
- Undo/redo integration with Yjs history

### Phase 3: Advanced Features (Future)
- Insert at specific note position (not just cursor)
- Insert with formatting preserved (if message has markdown)
- Insert as quote/reference (with attribution)
- Track insertions for citation purposes
- Bulk insert multiple messages

## Testing Strategy (TDD)

### Test Pyramid

```
        /\
       /  \    E2E Tests (1-2)
      /____\   - Full flow from button to insertion
     /      \
    / Component Tests (5-10)
   /________\  - Event handlers, hooks
  /          \
 / Unit Tests  (15-20)
/______________\ - Pure functions, validations
```

### Test Execution Order

1. **Unit Tests**: Component rendering, pure functions
2. **Component Tests**: Event handling, LiveComponent behavior
3. **JavaScript Tests**: Hook behavior, Yjs integration
4. **Integration Tests**: Full flow with real LiveView

## Security Considerations

### XSS Prevention
- Content is passed through Yjs which handles sanitization
- No direct HTML injection
- Phoenix's built-in escaping applies to button attributes

### Authorization
- User must have access to both the page and note
- Insert button only shown when note exists in assigns
- Server doesn't modify note (client-side operation via Yjs)

### Content Validation
- Check for empty/null content before pushing event
- Yjs handles collaborative editing conflicts
- No direct database writes from this feature

## Performance Considerations

- **No database queries**: Purely event-driven
- **No server-side rendering overhead**: Client-side insertion
- **Collaborative editing intact**: Yjs handles all synchronization
- **Minimal payload**: Only content string sent in event

## Rollback Plan

If issues arise:

1. **Remove insert link**: Comment out the `message__actions` div in `message.ex`
2. **Disable event handler**: Comment out `handle_event("insert_into_note")` in `panel.ex`
3. **Remove JavaScript listener**: Comment out `handleEvent("insert-text")` in hook
4. **Hide CSS**: Add `.message__insert-link { display: none; }` as emergency fix

No database migrations or schema changes required for rollback. Feature is purely UI-driven.

## Success Criteria

- ✅ Insert link appears on assistant messages when on page with note
- ✅ Insert link does NOT appear on workspace or project views
- ✅ Insert link is subtle and minimal (just "insert" text, no icon)
- ✅ Clicking link inserts text into note at cursor position
- ✅ Link only visible on message hover (minimal visual clutter)
- ✅ No errors in browser console or LiveView logs
- ✅ Collaborative editing still works after insertion
- ✅ All tests pass
- ✅ No boundary violations when running `mix compile`
- ✅ Feature works across different browsers
- ✅ Keyboard accessible (tab navigation and focus states work)

## Documentation Updates Required

After implementation:

1. Update user documentation with new feature
2. Add code comments explaining event flow
3. Document JavaScript hook API
4. Update ARCHITECTURE.md with new event example (if warranted)

## Timeline Estimate

- **Phase 1 (UI)**: 1-2 hours
- **Phase 2 (Events)**: 1-2 hours
- **Phase 3 (JavaScript)**: 2-3 hours
- **Phase 4 (Testing)**: 2-3 hours
- **Documentation**: 1 hour

**Total**: 7-11 hours for complete implementation with tests

## References

- [Phoenix LiveView Docs](https://hexdocs.pm/phoenix_live_view)
- [Context7 LiveView Documentation](https://context7.com)
- Project: `docs/ARCHITECTURE.md`
- Project: `CLAUDE.md` (TDD guidelines)
