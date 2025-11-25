# PubSub Testing Guide for Cucumber BDD Tests

## Overview

This guide covers best practices for testing Phoenix PubSub broadcasts in Cucumber/BDD feature tests. PubSub testing ensures that real-time notifications work correctly across the application.

## Testing Approaches

### 1. **Unit Testing Approach** (Recommended for BDD)

Test that the broadcast is sent with the correct message structure, without requiring a second user session.

**Pattern:**
```elixir
step "a visibility changed notification should be broadcast", context do
  document = context[:document]
  
  # Subscribe to the document's PubSub topic
  Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{document.id}")
  
  # The broadcast should have already happened in the previous step
  # Check if we received it
  assert_receive {:document_updated, %{document_id: document_id, changes: %{visibility: _}}}, 1000
  assert document_id == document.id
  
  {:ok, context}
end
```

**Pros:**
- ✅ Fast execution
- ✅ No need for multiple browser sessions
- ✅ Tests the broadcast mechanism directly
- ✅ Works in ConnCase (no Wallaby needed)

**Cons:**
- ⚠️ Doesn't test the full LiveView push/handle_info cycle
- ⚠️ Requires subscribing after the action (broadcast already sent)

### 2. **Proactive Subscribe Pattern** (Better for BDD)

Subscribe BEFORE the action that triggers the broadcast.

**Pattern:**
```elixir
step "user {string} is viewing the document", %{args: [email]} = context do
  document = context[:document]
  
  # Subscribe to document updates on behalf of the "other user"
  Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{document.id}")
  
  {:ok, context |> Map.put(:subscribed_to_document, document.id)}
end

step "I make the document private", context do
  # ... perform action that broadcasts ...
  {:ok, updated_context}
end

step "user {string} should receive a visibility changed notification", 
     %{args: [email]} = context do
  # Now check for the broadcast
  assert_receive {:document_updated, %{changes: %{visibility: :private}}}, 1000
  {:ok, context}
end
```

**Pros:**
- ✅ More realistic test flow
- ✅ Matches the Gherkin scenario structure
- ✅ Tests timing of broadcasts
- ✅ Works in ConnCase

**Cons:**
- ⚠️ Still doesn't test LiveView push cycle

### 3. **Full Integration with Wallaby** (For @javascript scenarios)

Test the complete real-time update flow with actual browser sessions.

**Pattern:**
```elixir
@tag :wallaby
test "real-time title update", %{session: session} do
  # Session 1: Alice's browser
  alice_session = session
    |> visit("/document/123")
  
  # Session 2: Charlie's browser  
  charlie_session = Wallaby.start_session()
    |> visit("/document/123")
  
  # Alice updates title
  alice_session
    |> fill_in(Query.css("#document-title"), with: "New Title")
    |> blur(Query.css("#document-title"))
  
  # Charlie sees the update in real-time
  assert charlie_session
    |> has?(Query.css("#document-title", text: "New Title"))
end
```

**Pros:**
- ✅ Tests complete end-to-end flow
- ✅ Tests LiveView push and JavaScript handling
- ✅ Tests actual UI updates

**Cons:**
- ⚠️ Slow (requires browser automation)
- ⚠️ Complex setup with multiple sessions
- ⚠️ Only works with `@javascript` tag

## Recommended Approach for Documents Feature

For the documents feature, use a **hybrid approach**:

### Non-JavaScript Scenarios (ConnCase)

Use **Proactive Subscribe Pattern** for simple broadcast verification:

```elixir
# In document_steps.exs

step "user {string} is viewing the document", %{args: [_email]} = context do
  document = context[:document]
  
  # Subscribe to document-specific PubSub topic
  Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{document.id}")
  
  {:ok, context |> Map.put(:pubsub_subscribed, true)}
end

step "user {string} is viewing the workspace", %{args: [_email]} = context do
  workspace = context[:workspace]
  
  # Subscribe to workspace-specific PubSub topic
  Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
  
  {:ok, context |> Map.put(:pubsub_subscribed, true)}
end

step "a visibility changed notification should be broadcast", context do
  # The broadcast should have been sent in the previous action step
  # Wait for and verify the message
  assert_receive {:document_visibility_changed, payload}, 1000
  
  document = context[:document]
  assert payload.document_id == document.id
  assert payload.is_public in [true, false]
  
  {:ok, context}
end

step "a pin status changed notification should be broadcast", context do
  assert_receive {:document_pinned_changed, payload}, 1000
  
  document = context[:document]
  assert payload.document_id == document.id
  assert payload.is_pinned in [true, false]
  
  {:ok, context}
end

step "a document deleted notification should be broadcast", context do
  assert_receive {:document_deleted, payload}, 1000
  
  document = context[:document]
  assert payload.document_id == document.id
  
  {:ok, context}
end

step "user {string} should receive a real-time title update", 
     %{args: [_email]} = context do
  document = context[:document]
  
  assert_receive {:document_updated, payload}, 1000
  assert payload.document_id == document.id
  assert payload.changes[:title] != nil
  
  {:ok, context}
end
```

### JavaScript Scenarios (Wallaby)

For `@javascript` tagged scenarios, use Wallaby to test the full real-time collaboration:

```elixir
# Mark scenarios with @javascript tag in .feature file
@javascript
Scenario: Multiple users edit document simultaneously
  Given I am logged in as "alice@example.com"
  And a public document exists with title "Collaborative Doc"
  And user "charlie@example.com" is also viewing the document
  When I make changes to the document content
  Then user "charlie@example.com" should see my changes in real-time
```

```elixir
# Implementation would use Wallaby (future work)
step "user {string} is also viewing the document", %{args: [email]} = context do
  # This would start a second Wallaby session
  # For now, just acknowledge it's a @javascript test
  if context[:javascript] do
    # Wallaby implementation
    {:ok, context}
  else
    # Skip for non-javascript tests
    {:ok, context}
  end
end
```

## Message Structures

Document the expected PubSub message formats:

```elixir
# Document visibility changed
{:document_visibility_changed, %{
  document_id: UUID,
  is_public: boolean(),
  changed_by_user_id: UUID
}}

# Document pinned status changed
{:document_pinned_changed, %{
  document_id: UUID,
  is_pinned: boolean(),
  changed_by_user_id: UUID
}}

# Document deleted
{:document_deleted, %{
  document_id: UUID,
  deleted_by_user_id: UUID
}}

# Document updated (title, etc.)
{:document_updated, %{
  document_id: UUID,
  changes: %{title: String.t() | nil}
}}

# Yjs collaborative editing update
{:yjs_update, %{
  update: binary(),
  user_id: String.t()
}}
```

## Testing Checklist

For each PubSub broadcast feature:

- [ ] **Define message structure** - Document expected payload format
- [ ] **Test broadcast is sent** - Verify message is published
- [ ] **Test message content** - Verify payload contains correct data
- [ ] **Test topic routing** - Verify message sent to correct topic
- [ ] **Test authorization** - Only authorized users receive messages
- [ ] **Test timing** - Broadcast happens at the right time in the flow
- [ ] **Add @javascript test** (optional) - For full end-to-end validation

## Common Pitfalls

### ❌ Subscribing After Broadcast

```elixir
# WRONG - The broadcast already happened!
step "I make the document private", context do
  result = Documents.update_document(user, document.id, %{is_public: false})
  {:ok, context}
end

step "a notification should be broadcast", context do
  Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{document.id}")
  assert_receive {:document_updated, _}, 1000  # Will timeout!
  {:ok, context}
end
```

### ✅ Subscribe Before Action

```elixir
# CORRECT - Subscribe first, then act
step "user {string} is viewing the document", context do
  Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{document.id}")
  {:ok, context}
end

step "I make the document private", context do
  result = Documents.update_document(user, document.id, %{is_public: false})
  {:ok, context}
end

step "a notification should be broadcast", context do
  assert_receive {:document_updated, _}, 1000  # Will work!
  {:ok, context}
end
```

### ❌ Wrong Message Pattern

```elixir
# WRONG - Message pattern doesn't match actual broadcast
assert_receive {:visibility_changed, _}, 1000
```

Check the actual broadcast code to know the correct message format:

```elixir
# In the use case or service
Phoenix.PubSub.broadcast(
  Jarga.PubSub,
  "document:#{document.id}",
  {:document_visibility_changed, payload}
)
```

### ✅ Match Actual Message

```elixir
# CORRECT - Matches the broadcast format
assert_receive {:document_visibility_changed, payload}, 1000
```

## Example: Complete Scenario

**Feature File:**
```gherkin
Scenario: Document title change notification
  Given I am logged in as "alice@example.com"
  And a public document exists with title "Team Doc" owned by "alice@example.com"
  And user "charlie@example.com" is viewing the document
  When I update the document title to "Updated Team Doc"
  Then user "charlie@example.com" should receive a real-time title update
```

**Step Definitions:**
```elixir
step "user {string} is viewing the document", %{args: [_email]} = context do
  document = context[:document]
  Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{document.id}")
  {:ok, context |> Map.put(:pubsub_document_id, document.id)}
end

step "I update the document title to {string}", %{args: [new_title]} = context do
  document = context[:document]
  user = context[:current_user]
  
  {:ok, updated_document} = Documents.update_document(user, document.id, %{title: new_title})
  
  {:ok, context |> Map.put(:document, updated_document)}
end

step "user {string} should receive a real-time title update", %{args: [_email]} = context do
  document = context[:document]
  
  # Wait for the broadcast message
  assert_receive {:document_updated, payload}, 1000
  
  # Verify the payload
  assert payload.document_id == document.id
  assert payload.changes.title == document.title
  
  {:ok, context}
end
```

## Summary

**Best Practice for BDD/Cucumber:**
1. Use **Proactive Subscribe Pattern** for most scenarios (ConnCase)
2. Subscribe in "user is viewing" setup steps
3. Verify broadcasts in "should receive notification" assertion steps
4. Use `@javascript` + Wallaby only for full end-to-end UI update tests
5. Document expected message structures
6. Always use `assert_receive` with timeout (1000ms recommended)

This approach keeps tests fast, maintainable, and properly validates the PubSub behavior without needing complex multi-session setups for most scenarios.
