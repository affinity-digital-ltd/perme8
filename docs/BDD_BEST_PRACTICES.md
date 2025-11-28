# BDD Feature & Step Definition Best Practices

This guide establishes standards for writing Cucumber feature files and step definitions in this project. Following these practices ensures our BDD tests are maintainable, trustworthy, and provide genuine coverage rather than false confidence.

## Table of Contents

1. [Core Principles](#core-principles)
2. [Feature File Structure](#feature-file-structure)
3. [Priority & Test Type Tagging](#priority--test-type-tagging)
4. [Step Definition Standards](#step-definition-standards)
5. [Avoiding Pass-Through Steps](#avoiding-pass-through-steps)
6. [Test Type Selection](#test-type-selection)
7. [Scenario Writing Guidelines](#scenario-writing-guidelines)
8. [File Organization](#file-organization)
9. [Running Tests by Priority](#running-tests-by-priority)
10. [Quality Checklist](#quality-checklist)

---

## Core Principles

### 1. No False Positives
A passing test must mean the feature works. Empty step definitions that return `{:ok, context}` without verification are **forbidden** unless explicitly marked as stubs.

### 2. Single Responsibility
Each scenario tests ONE behavior. If you use "And" more than 3 times in your Then clause, consider splitting the scenario.

### 3. Priority-Driven Testing
Not all tests are equal. Critical user paths must have rock-solid coverage. Edge cases and styling can be lower priority.

### 4. Right Tool for the Job
Use LiveViewTest when possible (faster, more reliable). Use Wallaby/browser only when JavaScript execution is required.

### 5. Explicit Over Implicit
If a step can't be fully verified, document WHY and mark it appropriately. Hidden gaps are worse than known gaps.

---

## Feature File Structure

### Directory Organization

```
test/features/
├── accounts.feature              # Small, focused features can be single files
├── agents.feature
├── workspaces.feature
├── chat/                         # Large features should be split into directories
│   ├── chat_core.feature         # Panel open/close, basic UI
│   ├── chat_messaging.feature    # Send/receive messages
│   ├── chat_streaming.feature    # Streaming responses
│   ├── chat_sessions.feature     # History, new session, restore
│   ├── chat_agents.feature       # Agent selection, preferences
│   ├── chat_context.feature      # Document context integration
│   ├── chat_formatting.feature   # Markdown rendering
│   └── chat_editor.feature       # @j commands, insert into note
├── documents/
│   ├── document_crud.feature
│   ├── document_editor.feature
│   └── document_sharing.feature
└── step_definitions/
    ├── chat/                     # Mirror feature structure
    │   ├── chat_core_steps.exs
    │   ├── chat_messaging_steps.exs
    │   └── ...
    └── common_steps.exs          # Shared steps (login, navigation)
```

### Feature File Template

```gherkin
@feature-area
Feature: [Specific Capability]
  As a [user role]
  I want [goal]
  So that [benefit]

  # Brief description of what this feature file covers.
  # Keep each file focused on ONE aspect of functionality.

  Background:
    Given I am logged in as a user
    # Only include setup that applies to ALL scenarios in this file

  # ============================================================================
  # CRITICAL SCENARIOS - Must always pass
  # ============================================================================

  @critical @liveview
  Scenario: [Happy path scenario]
    Given [precondition]
    When [action]
    Then [expected outcome]

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  @high @liveview
  Scenario: [Important variation]
    ...

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  @medium @javascript
  Scenario: [Secondary feature]
    ...

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  @low @javascript
  Scenario: [Edge case or styling]
    ...
```

---

## Priority & Test Type Tagging

### Priority Tags (Required on every scenario)

| Tag | Description | CI Behavior | Example |
|-----|-------------|-------------|---------|
| `@critical` | Core user journeys that must never break | Block deploy if failing | Send message, login, create document |
| `@high` | Important features with business impact | Block deploy if failing | Agent selection, streaming, session restore |
| `@medium` | Useful features, acceptable short-term gaps | Warning only | Conversation history, markdown lists |
| `@low` | Polish, edge cases, nice-to-have | Informational | Animation timing, specific styling |

### Test Type Tags (Required on every scenario)

| Tag | Description | When to Use |
|-----|-------------|-------------|
| `@liveview` | Uses Phoenix.LiveViewTest | Server-rendered HTML, form submissions, LiveView events |
| `@javascript` | Uses Wallaby browser testing | localStorage, CSS transitions, keyboard shortcuts, JS hooks |

### Additional Tags

| Tag | Description |
|-----|-------------|
| `@wip` | Work in progress - excluded from CI |
| `@skip` | Temporarily skipped with documented reason |
| `@flaky` | Known intermittent failures - needs investigation |
| `@slow` | Takes >5 seconds - excluded from fast test runs |

### Tag Examples

```gherkin
@critical @liveview
Scenario: Send a chat message
  # This is a core user journey tested via LiveViewTest

@high @javascript
Scenario: Chat panel preference persists in localStorage
  # Requires browser to verify localStorage

@medium @liveview @slow
Scenario: Load conversation with 100 messages
  # Performance test that takes time

@low @javascript @wip
Scenario: Resize handle has hover effect
  # Not yet implemented
```

---

## Step Definition Standards

### Required Structure

Every step definition file must follow this structure:

```elixir
defmodule Chat.MessagingSteps do
  @moduledoc """
  Step definitions for chat messaging functionality.
  
  Coverage Status:
  - send_message: FULL (assertions verified)
  - receive_message: FULL (assertions verified)
  - message_timestamp: PARTIAL (format only, not accuracy)
  - typing_indicator: STUB (requires JS implementation)
  """
  
  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false
  
  import Phoenix.LiveViewTest
  import ExUnit.Assertions
  
  # ============================================================================
  # FULLY IMPLEMENTED STEPS
  # ============================================================================
  
  @doc "Verified: Checks actual DOM for message presence"
  step "my message {string} should appear in the chat", %{args: [content]} = context do
    html = render(context[:view])
    
    assert html =~ content, 
      "Expected message '#{content}' to appear in chat. HTML: #{String.slice(html, 0, 500)}"
    
    {:ok, Map.put(context, :last_html, html)}
  end
  
  # ============================================================================
  # PARTIAL IMPLEMENTATION STEPS
  # ============================================================================
  
  @doc """
  Partial: Verifies timestamp format but not accuracy.
  Full implementation would check actual time difference.
  """
  step "the message should show its timestamp", context do
    html = context[:last_html]
    
    # Verify timestamp element exists with expected format
    assert html =~ ~r/\d{1,2}:\d{2}/, "Expected timestamp in HH:MM format"
    
    {:ok, context}
  end
  
  # ============================================================================
  # STUB STEPS - Must be explicitly marked
  # ============================================================================
  
  @doc """
  STUB: Cannot verify without JavaScript execution.
  Requires @javascript tag on scenario.
  TODO: Implement with Wallaby when browser tests are set up.
  """
  step "the typing indicator should animate", context do
    # STUB: Animation requires browser execution
    # This step will pass but provides no verification
    Logger.warning("STUB STEP: 'typing indicator should animate' - no verification performed")
    
    {:ok, Map.put(context, :stub_steps, [context[:stub_steps] | "typing indicator"])}
  end
end
```

### Step Implementation Levels

Every step must be classified as one of:

#### FULL - Complete Verification
```elixir
step "the agent {string} should be selected", %{args: [name]} = context do
  html = render(context[:view])
  
  # Multiple assertions for confidence
  assert html =~ ~r/data-selected-agent="#{name}"/
  assert html =~ ~r/<option[^>]*selected[^>]*>#{name}<\/option>/
  
  {:ok, Map.put(context, :last_html, html)}
end
```

#### PARTIAL - Some Verification
```elixir
@doc "PARTIAL: Verifies presence but not full styling"
step "the message should have error styling", context do
  html = context[:last_html]
  
  # We verify the error class exists, but not the actual CSS appearance
  assert html =~ "text-error" or html =~ "alert-error"
  
  {:ok, context}
end
```

#### STUB - No Verification (Must Log Warning)
```elixir
@doc "STUB: Requires browser testing"
step "my preference should be saved to localStorage", context do
  # STUB: localStorage is JavaScript-only
  # Scenario MUST be tagged @javascript for this to be testable
  require Logger
  Logger.warning("STUB: localStorage verification skipped - requires @javascript")
  
  {:ok, context}
end
```

---

## Avoiding Pass-Through Steps

### The Problem

Pass-through steps silently return success without testing anything:

```elixir
# BAD - This ALWAYS passes, even if feature is broken
step "the panel should slide open", context do
  {:ok, context}
end
```

### The Solution

#### Option 1: Implement Real Assertion
```elixir
# GOOD - Actually verifies the behavior
step "the panel should be open", context do
  html = render(context[:view])
  assert html =~ ~r/id="chat-panel"[^>]*class="[^"]*open/
  {:ok, Map.put(context, :last_html, html)}
end
```

#### Option 2: Log Warning and Track
```elixir
# ACCEPTABLE - Explicit about limitation
step "the panel should slide open with animation", context do
  Logger.warning("STUB: Animation cannot be verified in LiveViewTest")
  
  # At least verify the panel is present
  html = render(context[:view])
  assert html =~ "chat-panel"
  
  {:ok, context}
end
```

#### Option 3: Use Skip Macro
```elixir
# Create a helper for consistent stub handling
defmodule StepHelpers do
  defmacro stub_step(reason) do
    quote do
      require Logger
      Logger.warning("STUB STEP: #{unquote(reason)}")
      # Could also track for reporting
      {:ok, var!(context)}
    end
  end
end

# Usage
step "localStorage should be updated", context do
  stub_step("localStorage requires @javascript browser test")
end
```

### Banned Patterns

These patterns are **not allowed** without explicit justification:

```elixir
# BANNED - Silent pass-through
step "something should happen", context do
  {:ok, context}
end

# BANNED - Assertion that always passes
step "the feature should work", context do
  assert true
  {:ok, context}
end

# BANNED - Checking wrong thing
step "the message should be saved to database", context do
  # Only checks HTML, not database!
  assert context[:last_html] =~ "message"
  {:ok, context}
end
```

---

## Test Type Selection

### Use LiveViewTest (`@liveview`) When:

| Capability | Example |
|------------|---------|
| Testing rendered HTML | `assert html =~ "Welcome"` |
| Form submissions | `form \|> render_submit()` |
| LiveView events | `render_click(view, "delete", %{id: 1})` |
| Server-sent updates | `assert_push_event(view, "message", %{})` |
| Database verification | `assert Repo.get(Message, id)` |
| PubSub broadcasts | Subscribe and verify messages |
| Flash messages | `assert html =~ "Saved successfully"` |

### Use Wallaby (`@javascript`) When:

| Capability | Example |
|------------|---------|
| localStorage/sessionStorage | `execute_script("localStorage.getItem('key')")` |
| CSS transitions/animations | Verify computed styles |
| Keyboard shortcuts | `send_keys([:escape])` |
| Focus management | Check `document.activeElement` |
| Scroll position | Verify scroll state |
| Drag and drop | Mouse event simulation |
| Complex JS hooks | Hook behavior that modifies DOM |
| Multi-tab behavior | Session isolation |

### Decision Matrix

```
                        Can I test this with LiveViewTest?
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                   YES                              NO
                    │                               │
            Use @liveview                   Does it need JS?
                    │                               │
                    │               ┌───────────────┴───────────────┐
                    │               │                               │
                    │              YES                              NO
                    │               │                               │
                    │       Use @javascript              Consider if test
                    │                                    is necessary at all
                    │
            Is it a critical path?
                    │
        ┌───────────┴───────────┐
        │                       │
       YES                      NO
        │                       │
   @critical @liveview     Lower priority tag
```

---

## Scenario Writing Guidelines

### Single Responsibility

Each scenario should test ONE specific behavior.

```gherkin
# BAD - Testing multiple things
Scenario: Chat panel functionality
  Given the chat panel is closed
  When I click the toggle button
  Then the panel should open
  And I should see the agent selector
  When I select an agent
  Then the agent should be selected
  When I type a message
  And I press Enter
  Then the message should be sent
  And I should see the response
  And the response should be formatted
```

```gherkin
# GOOD - Focused scenarios
@critical @liveview
Scenario: Open chat panel
  Given the chat panel is closed
  When I click the toggle button
  Then I should see the chat interface

@critical @liveview
Scenario: Send message in chat
  Given the chat panel is open
  And an agent is selected
  When I type "Hello" and press Enter
  Then my message should appear in the chat

@high @liveview
Scenario: Receive agent response
  Given I have sent a message
  When the agent responds
  Then I should see the response below my message
```

### Descriptive Scenario Names

```gherkin
# BAD - Vague names
Scenario: Test chat
Scenario: It works
Scenario: Agent stuff

# GOOD - Descriptive names
Scenario: Send message with Enter key submits to agent
Scenario: Empty message input disables send button
Scenario: Selecting new agent clears current conversation
```

### Given-When-Then Balance

```gherkin
# BAD - Too many Givens (complex setup suggests need for separate scenarios)
Scenario: Complex chat interaction
  Given I am logged in
  And I have a workspace
  And the workspace has 3 agents
  And I have selected agent "Helper"
  And I have an existing conversation
  And the conversation has 10 messages
  And I am viewing a document
  And the document has content
  When I send a message
  Then something happens

# GOOD - Use Background for common setup
Background:
  Given I am logged in
  And I have a workspace with agent "Helper"

Scenario: Send message with document context
  Given I am viewing document "Project Specs"
  And the chat panel is open
  When I send "Summarize this"
  Then the agent should receive the document content as context
```

### Avoid Implementation Details

```gherkin
# BAD - Exposes implementation
Scenario: Send message via Phoenix LiveView
  Given I mount the ChatPanelComponent
  When I push event "send_message" with payload %{content: "Hello"}
  Then I should receive "message_sent" event

# GOOD - User perspective
Scenario: Send message in chat
  Given the chat panel is open
  When I type "Hello" and click Send
  Then my message should appear in the chat
```

---

## File Organization

### Feature Files

- **One file per capability area** - Not one file per entire feature
- **50-150 lines per file** - If longer, split it
- **Group scenarios by priority** - Critical first, then high, medium, low
- **Use comments to separate sections**

### Step Definition Files

- **Mirror feature file structure** - `chat_messaging.feature` → `chat_messaging_steps.exs`
- **One step definition file per feature file**
- **Common steps in `common_steps.exs`** - Login, navigation, basic assertions
- **Document coverage level** - In @moduledoc, list each step's verification level

### Naming Conventions

```
Feature files:     snake_case.feature
Step files:        snake_case_steps.exs
Step modules:      PascalCase.SnakeCaseSteps
```

---

## Running Tests by Priority

### Command Reference

```bash
# Run only critical tests (fast, for development)
mix test --only critical

# Run critical and high priority (pre-commit)
mix test --only critical --only high

# Run all LiveViewTest scenarios (fast CI)
mix test --only liveview

# Run browser tests (slow, full CI)
mix test --only javascript

# Exclude work-in-progress
mix test --exclude wip

# Run specific feature area
mix test test/features/chat/

# Run single feature file
mix test test/features/chat/chat_messaging.feature
```

### CI Pipeline Suggestion

```yaml
# .github/workflows/ci.yml
jobs:
  critical-tests:
    # Fast feedback - run on every push
    runs-on: ubuntu-latest
    steps:
      - run: mix test --only critical
    timeout-minutes: 5

  full-liveview-tests:
    # Medium feedback - run on PR
    runs-on: ubuntu-latest
    steps:
      - run: mix test --only liveview --exclude wip
    timeout-minutes: 10

  browser-tests:
    # Slow feedback - run before merge
    runs-on: ubuntu-latest
    steps:
      - run: mix test --only javascript --exclude wip
    timeout-minutes: 20
```

---

## Quality Checklist

### Before Committing a Feature File

- [ ] Every scenario has a priority tag (`@critical`, `@high`, `@medium`, `@low`)
- [ ] Every scenario has a test type tag (`@liveview` or `@javascript`)
- [ ] Scenario names clearly describe the behavior being tested
- [ ] Each scenario tests ONE specific behavior
- [ ] Background only contains setup common to ALL scenarios
- [ ] File is under 150 lines (split if larger)

### Before Committing Step Definitions

- [ ] Every step has a `@doc` describing what it verifies
- [ ] No empty pass-through steps without explicit STUB documentation
- [ ] STUB steps log a warning when executed
- [ ] Module `@moduledoc` lists coverage status of each step
- [ ] Assertions include helpful failure messages
- [ ] Steps return updated context with any new state

### Code Review Checklist

- [ ] New scenarios have appropriate priority based on user impact
- [ ] `@javascript` tag is only used when truly necessary
- [ ] Step definitions actually verify the expected behavior
- [ ] No new pass-through steps without justification
- [ ] Related step definitions are in the correct file
- [ ] Flaky or slow tests are appropriately tagged

---

## Appendix: Step Coverage Report

Consider creating a mix task to generate coverage reports:

```bash
$ mix bdd.coverage

=== BDD STEP COVERAGE REPORT ===

chat_messaging_steps.exs:
  FULL:    send_message, receive_message, message_appears (3)
  PARTIAL: timestamp_format (1)
  STUB:    typing_indicator, read_receipts (2)

chat_ui_steps.exs:
  FULL:    panel_open, panel_close (2)
  PARTIAL: none (0)
  STUB:    animation_timing, localStorage_preference (2)

SUMMARY:
  Total steps: 45
  Fully verified: 28 (62%)
  Partially verified: 8 (18%)
  Stubs: 9 (20%)

STUB STEPS REQUIRING ATTENTION:
  - typing_indicator (requires JS animation)
  - read_receipts (feature not implemented)
  - animation_timing (CSS-only, consider removing)
  - localStorage_preference (needs @javascript scenario)
```

This report helps identify where test coverage is actually weak versus where it's strong.

---

## Summary

1. **Tag everything** with priority and test type
2. **Split large features** into focused files
3. **No silent pass-throughs** - verify or explicitly document as stub
4. **Use LiveViewTest by default** - Wallaby only when required
5. **One behavior per scenario** - keep them focused
6. **Document step coverage** - know what's actually tested
7. **Run by priority** - fast feedback on critical paths
