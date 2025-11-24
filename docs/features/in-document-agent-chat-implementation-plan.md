# Feature: In-Document Agent Chat - TDD Implementation Plan

## Overview

This feature enhances the existing `@j` mention system in Documents to support inline agent invocation using `@j agent_name Question` syntax. Users can invoke any workspace-available agent directly within the document editor, receive streaming responses inline, and see the agent's response replace the command text.

**Key Value Proposition:** Contextual AI assistance without breaking editing flow or switching to a separate chat panel.

## Affected Boundaries

- **Jarga.Documents** - Enhanced to handle agent query invocations within document editor
- **Jarga.Agents** - Extended to support agent lookup by name and document-context queries
- **JargaWeb** (Interface Layer) - Document LiveView updated to handle new `@j agent_name Question` syntax

**Boundary Considerations:**
- Documents context will call Agents context public API (allowed dependency)
- All agent logic remains in Agents context (no boundary violations)
- Frontend hooks will delegate to use cases (Clean Architecture preserved)

## Implementation Phases

**This feature will be implemented in 4 phases:**

### Phase 1: Backend Domain + Application Layers (phoenix-tdd)
**Scope**: Pure business logic and use case orchestration
- Domain Layer: Agent name parsing, validation logic
- Application Layer: Look up agent by name, prepare agent-specific context, orchestrate agent query with agent's custom settings

### Phase 2: Backend Infrastructure + Interface Layers (phoenix-tdd)
**Scope**: Database, external services, and user-facing endpoints
- Infrastructure Layer: Queries to find agents by name in workspace
- Interface Layer: LiveView event handlers, streaming response handling

### Phase 3: Frontend Domain + Application Layers (typescript-tdd)
**Scope**: Client-side business logic and use cases
- Domain Layer: Parse `@j agent_name Question` syntax, extract agent name and question
- Application Layer: Client-side validation, command parsing coordination

### Phase 4: Frontend Infrastructure + Presentation Layers (typescript-tdd)
**Scope**: Browser APIs and UI components
- Infrastructure Layer: (Minimal - uses existing Phoenix Channel/LiveView streaming)
- Presentation Layer: ProseMirror plugin to detect `@j` commands, loading indicator rendering

---

## Phase 1: Backend Domain + Application Layers

**Assigned to**: phoenix-tdd agent

### Domain Layer Tests & Implementation

#### Feature 1: Agent Query Command Parser (Domain Logic)

**Context**: We need pure domain logic to parse the `@j agent_name Question` syntax and extract agent name and question text.

- [ ] **RED**: Write test `test/jarga/documents/domain/agent_query_parser_test.exs`
  - Test: "parses valid @j agent_name Question syntax"
    - Input: `"@j doc-writer How should I structure this?"`
    - Expected: `{:ok, %{agent_name: "doc-writer", question: "How should I structure this?"}}`
  - Test: "handles multi-word agent names"
    - Input: `"@j my-writer-agent What is the format?"`
    - Expected: `{:ok, %{agent_name: "my-writer-agent", question: "What is the format?"}}`
  - Test: "handles questions with special characters"
    - Input: `"@j agent1 What's the difference? (explain)"`
    - Expected: `{:ok, %{agent_name: "agent1", question: "What's the difference? (explain)"}}`
  - Test: "returns error for invalid format (missing question)"
    - Input: `"@j agent-name"`
    - Expected: `{:error, :missing_question}`
  - Test: "returns error for invalid format (no agent name)"
    - Input: `"@j   What is this?"`
    - Expected: `{:error, :missing_agent_name}`
  - Test: "returns error for non-@j text"
    - Input: `"regular text"`
    - Expected: `{:error, :invalid_format}`
  - Expected failure: Module doesn't exist

- [ ] **GREEN**: Implement `lib/jarga/documents/domain/agent_query_parser.ex`
  - Create module with `parse/1` function
  - Implement regex matching for `@j agent_name Question` pattern
  - Return `{:ok, %{agent_name: string, question: string}}` or `{:error, atom}`
  - No external dependencies - pure pattern matching

- [ ] **REFACTOR**: Clean up while keeping tests green
  - Extract regex patterns as module attributes
  - Add @doc documentation
  - Improve error messages

### Application Layer Tests & Implementation

#### Use Case 1: Execute Agent Query in Document Context

**Context**: Orchestrate the complete flow: parse command → look up agent → prepare context with agent's settings → stream response. This extends the existing `AgentQuery` use case to support agent lookup by name.

- [ ] **RED**: Write test `test/jarga/documents/application/use_cases/execute_agent_query_test.exs`
  - Test: "successfully executes query with valid agent name"
    - Given: Valid `@j agent_name Question` command, agent exists in workspace
    - Mock: `Agents.get_workspace_agents_list/3` returns agent
    - Mock: `Agents.agent_query/2` streams response
    - Expected: Success with streaming initiated
  - Test: "returns error when agent not found in workspace"
    - Given: Valid command with non-existent agent name
    - Mock: `Agents.get_workspace_agents_list/3` returns empty list
    - Expected: `{:error, :agent_not_found}`
  - Test: "returns error when agent is disabled"
    - Given: Valid command, agent exists but enabled=false
    - Mock: `Agents.get_workspace_agents_list/3` returns disabled agent
    - Expected: `{:error, :agent_disabled}`
  - Test: "passes agent's custom system_prompt to agent_query"
    - Given: Agent with custom system_prompt
    - Mock: Capture call to `Agents.agent_query/2`
    - Expected: Params include agent with system_prompt
  - Test: "passes full document content as context"
    - Given: Document with content in assigns
    - Mock: Capture call to `Agents.agent_query/2`
    - Expected: Params include document context from assigns
  - Test: "returns error for invalid command syntax"
    - Given: Invalid command (fails parsing)
    - Expected: `{:error, :invalid_command_format}`
  - Expected failure: Module doesn't exist

- [ ] **GREEN**: Implement `lib/jarga/documents/application/use_cases/execute_agent_query.ex`
  ```elixir
  @moduledoc """
  Executes agent query within document editor context.
  
  Parses @j agent_name Question syntax, looks up agent by name,
  and delegates to Agents.agent_query with agent-specific settings.
  """
  
  def execute(params, caller_pid) do
    # 1. Parse command text using domain parser
    # 2. Look up agent by name in workspace (call Agents public API)
    # 3. Validate agent is enabled
    # 4. Delegate to Agents.agent_query with agent + document context
  end
  ```
  - Use `AgentQueryParser.parse/1` (domain layer)
  - Call `Agents.get_workspace_agents_list(workspace_id, user_id, enabled_only: true)`
  - Find agent by name (case-insensitive match)
  - Call `Agents.agent_query(%{question: question, assigns: assigns, agent: agent, node_id: node_id}, caller_pid)`

- [ ] **REFACTOR**: Improve organization
  - Extract agent lookup into private function
  - Add comprehensive documentation
  - Improve error handling clarity

### Phase 1 Completion Checklist

- [ ] All domain tests pass (`mix test test/jarga/documents/domain/`)
- [ ] All application tests pass (`mix test test/jarga/documents/application/`)
- [ ] No boundary violations (`mix boundary`)
- [ ] Domain tests run in milliseconds
- [ ] Application tests run in sub-second

---

## Phase 2: Backend Infrastructure + Interface Layers

**Assigned to**: phoenix-tdd agent

### Application Layer Extension: Agent Query Use Case

**Context**: Extend the existing `Jarga.Agents.Application.UseCases.AgentQuery` to support agent-specific settings (custom system_prompt, model, temperature).

#### Use Case Extension: AgentQuery with Agent Settings

- [ ] **RED**: Write test `test/jarga/agents/application/use_cases/agent_query_test.exs` (extend existing)
  - Test: "uses agent's custom system_prompt when provided"
    - Given: params include `agent: %{system_prompt: "You are X", model: "gpt-4", temperature: 0.8}`
    - Mock: LlmClient to verify it receives agent-specific settings
    - Expected: System message combines agent's prompt with document context
  - Test: "uses agent's model and temperature settings"
    - Given: Agent with model="gpt-4" and temperature=0.5
    - Mock: Verify LlmClient.chat_stream receives `model` and `temperature` in opts
    - Expected: Correct settings passed to LLM
  - Test: "falls back to default when agent has no custom settings"
    - Given: Agent without system_prompt
    - Expected: Uses default system message with context
  - Expected failure: Current implementation doesn't support agent parameter

- [ ] **GREEN**: Extend `lib/jarga/agents/application/use_cases/agent_query.ex`
  - Add `agent` parameter to params map (optional)
  - If agent present, use `PrepareContext.build_system_message_with_agent(agent, context)`
  - Pass agent's model and temperature to `llm_client.chat_stream/3` in opts
  - If no agent, use existing default system message logic

- [ ] **REFACTOR**: Clean up
  - Extract agent settings preparation into private function
  - Document the agent parameter in module docs
  - Ensure backward compatibility (agent is optional)

### Interface Layer Tests & Implementation

#### LiveView Event Handler: handle_event("agent_query_command")

**Context**: Document editor LiveView receives the `@j agent_name Question` command text and initiates the agent query process.

- [ ] **RED**: Write test `test/jarga_web/live/app_live/documents/show_test.exs` (extend existing)
  - Test: "handles valid agent query command"
    - Setup: Create workspace, agent, document, log in user
    - Action: Send event `agent_query_command` with `%{"command" => "@j my-agent What is this?", "node_id" => "node_123"}`
    - Expected: Response includes "ok", agent query initiated
  - Test: "handles agent not found error"
    - Given: Command with non-existent agent name
    - Expected: Response includes error message "Agent not found"
  - Test: "handles agent disabled error"
    - Given: Command with disabled agent
    - Expected: Response includes error message "Agent is disabled"
  - Test: "handles invalid command format"
    - Given: Malformed command text
    - Expected: Response includes error message "Invalid command format"
  - Test: "streams response chunks to client"
    - Given: Valid command, mock streaming
    - Expected: Client receives `agent_chunk` messages with node_id
  - Test: "sends completion message after streaming"
    - Given: Successful streaming completion
    - Expected: Client receives `agent_done` message with node_id
  - Expected failure: Event handler doesn't exist

- [ ] **GREEN**: Implement handler in `lib/jarga_web/live/app_live/documents/show.ex`
  ```elixir
  def handle_event("agent_query_command", %{"command" => command, "node_id" => node_id}, socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.current_workspace.id
    
    # Delegate to Documents context
    case Documents.execute_agent_query(
      %{command: command, assigns: socket.assigns, user: user, workspace_id: workspace_id, node_id: node_id},
      self()
    ) do
      {:ok, _pid} ->
        {:noreply, socket}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end
  
  # Handle streaming messages
  def handle_info({:agent_chunk, node_id, chunk}, socket) do
    # Push chunk to client via LiveView
    {:noreply, push_event(socket, "agent_chunk", %{node_id: node_id, chunk: chunk})}
  end
  
  def handle_info({:agent_done, node_id, response}, socket) do
    {:noreply, push_event(socket, "agent_done", %{node_id: node_id, response: response})}
  end
  
  def handle_info({:agent_error, node_id, reason}, socket) do
    {:noreply, push_event(socket, "agent_error", %{node_id: node_id, error: reason})}
  end
  ```

- [ ] **REFACTOR**: Keep LiveView thin
  - Extract error formatting into private function
  - Ensure proper error handling for all edge cases
  - Add clear documentation

#### Public API: Documents Context

**Context**: Add public API function to Documents context that delegates to the new use case.

- [ ] **RED**: Write test `test/jarga/documents_test.exs` (extend existing)
  - Test: "execute_agent_query delegates to use case"
    - Given: Valid params
    - Expected: Calls ExecuteAgentQuery.execute with params
  - Expected failure: Function doesn't exist

- [ ] **GREEN**: Implement `lib/jarga/documents.ex` (add public function)
  ```elixir
  @doc """
  Executes an agent query command within document context.
  
  Parses @j agent_name Question syntax, looks up agent by name,
  and streams response inline in the document.
  
  ## Examples
  
      iex> execute_agent_query(%{command: "@j agent1 Hello", assigns: assigns, user: user, workspace_id: wid, node_id: "node_1"}, self())
      {:ok, #PID<...>}
  """
  def execute_agent_query(params, caller_pid) do
    UseCases.ExecuteAgentQuery.execute(params, caller_pid)
  end
  ```

- [ ] **REFACTOR**: Clean up documentation

### Phase 2 Completion Checklist

- [ ] All infrastructure tests pass (`mix test test/jarga/`)
- [ ] All interface tests pass (`mix test test/jarga_web/`)
- [ ] No boundary violations (`mix boundary`)
- [ ] Full backend test suite passes (`mix test`)
- [ ] LiveView properly handles streaming events
- [ ] Error cases properly communicated to frontend

---

## Phase 3: Frontend Domain + Application Layers

**Assigned to**: typescript-tdd agent

### Domain Layer Tests & Implementation

#### Feature 1: Agent Command Parser (TypeScript)

**Context**: Pure TypeScript function to parse `@j agent_name Question` syntax on the client side.

- [ ] **RED**: Write test `assets/js/domain/parsers/agent-command-parser.test.ts`
  - Test: "parses valid @j command with single-word agent name"
    - Input: `"@j writer What is the format?"`
    - Expected: `{agentName: "writer", question: "What is the format?"}`
  - Test: "parses command with hyphenated agent name"
    - Input: `"@j my-writer-agent Question here"`
    - Expected: `{agentName: "my-writer-agent", question: "Question here"}`
  - Test: "handles questions with special characters"
    - Input: `"@j agent What's this? (explain)"`
    - Expected: `{agentName: "agent", question: "What's this? (explain)"}`
  - Test: "returns null for invalid format (no agent name)"
    - Input: `"@j    Question"`
    - Expected: `null`
  - Test: "returns null for invalid format (no question)"
    - Input: `"@j agent-name"`
    - Expected: `null`
  - Test: "returns null for non-@j text"
    - Input: `"regular text"`
    - Expected: `null`
  - Expected failure: Module doesn't exist

- [ ] **GREEN**: Implement `assets/js/domain/parsers/agent-command-parser.ts`
  ```typescript
  export interface AgentCommand {
    agentName: string
    question: string
  }
  
  export function parseAgentCommand(text: string): AgentCommand | null {
    // Pattern: @j agent_name Question
    const match = text.match(/^@j\s+([a-zA-Z0-9-_]+)\s+(.+)$/);
    if (!match) return null;
    
    return {
      agentName: match[1],
      question: match[2]
    };
  }
  ```
  - Pure function with no side effects
  - Returns null for invalid formats
  - Handles various agent name patterns

- [ ] **REFACTOR**: Clean up
  - Add JSDoc documentation
  - Consider edge cases (trailing whitespace, etc.)
  - Improve regex pattern if needed

#### Feature 2: Agent Command Validator

**Context**: Validate that parsed command has required fields and agent name is not empty.

- [ ] **RED**: Write test `assets/js/domain/validators/agent-command-validator.test.ts`
  - Test: "validates command with agent name and question"
    - Input: `{agentName: "writer", question: "What is this?"}`
    - Expected: `true`
  - Test: "rejects command with empty agent name"
    - Input: `{agentName: "", question: "Question"}`
    - Expected: `false`
  - Test: "rejects command with empty question"
    - Input: `{agentName: "agent", question: ""}`
    - Expected: `false`
  - Test: "rejects null command"
    - Input: `null`
    - Expected: `false`
  - Expected failure: Module doesn't exist

- [ ] **GREEN**: Implement `assets/js/domain/validators/agent-command-validator.ts`
  ```typescript
  import { AgentCommand } from '../parsers/agent-command-parser'
  
  export function isValidAgentCommand(command: AgentCommand | null): boolean {
    if (!command) return false
    if (!command.agentName || command.agentName.trim() === '') return false
    if (!command.question || command.question.trim() === '') return false
    return true
  }
  ```

- [ ] **REFACTOR**: Clean up and document

### Application Layer Tests & Implementation

#### Use Case 1: Process Agent Command

**Context**: Orchestrate command parsing, validation, and preparation for submission to LiveView.

- [ ] **RED**: Write test `assets/js/application/use-cases/process-agent-command.test.ts`
  - Test: "processes valid agent command"
    - Input: `"@j writer How should I format this?"`
    - Expected: Returns `{valid: true, agentName: "writer", question: "..."}`
  - Test: "rejects invalid command syntax"
    - Input: `"@j"`
    - Expected: Returns `{valid: false, error: "Invalid command format"}`
  - Test: "rejects command with missing agent name"
    - Input: `"@j    Question?"`
    - Expected: Returns `{valid: false, error: "Agent name is required"}`
  - Test: "rejects command with missing question"
    - Input: `"@j agent-name"`
    - Expected: Returns `{valid: false, error: "Question is required"}`
  - Expected failure: Module doesn't exist

- [ ] **GREEN**: Implement `assets/js/application/use-cases/process-agent-command.ts`
  ```typescript
  import { parseAgentCommand } from '../../domain/parsers/agent-command-parser'
  import { isValidAgentCommand } from '../../domain/validators/agent-command-validator'
  
  export interface ProcessResult {
    valid: boolean
    agentName?: string
    question?: string
    error?: string
  }
  
  export function processAgentCommand(commandText: string): ProcessResult {
    const parsed = parseAgentCommand(commandText)
    
    if (!isValidAgentCommand(parsed)) {
      if (parsed === null) {
        return { valid: false, error: 'Invalid command format' }
      }
      if (!parsed.agentName || parsed.agentName.trim() === '') {
        return { valid: false, error: 'Agent name is required' }
      }
      if (!parsed.question || parsed.question.trim() === '') {
        return { valid: false, error: 'Question is required' }
      }
    }
    
    return {
      valid: true,
      agentName: parsed!.agentName,
      question: parsed!.question
    }
  }
  ```

- [ ] **REFACTOR**: Improve error messages and structure

### Phase 3 Completion Checklist

- [ ] All domain tests pass (pure function tests)
- [ ] All application tests pass (use case tests)
- [ ] TypeScript compilation successful
- [ ] No type errors
- [ ] All functions properly documented

---

## Phase 4: Frontend Infrastructure + Presentation Layers

**Assigned to**: typescript-tdd agent

### Presentation Layer Tests & Implementation

#### ProseMirror Plugin: Agent Command Detection

**Context**: Extend or create a ProseMirror plugin to detect `@j agent_name Question` pattern and trigger agent query when user presses Enter.

- [ ] **RED**: Write test `assets/js/presentation/editor/plugins/agent-command-plugin.test.ts`
  - Test: "detects @j command at cursor position"
    - Given: Editor with text `"@j writer What is this?"`
    - Action: Move cursor to end of text
    - Expected: Plugin state has `activeMention` with parsed command
  - Test: "clears active mention when cursor moves away"
    - Given: Active mention detected
    - Action: Move cursor to different position
    - Expected: Plugin state `activeMention` is null
  - Test: "triggers query on Enter key"
    - Given: Active mention detected
    - Action: Press Enter key
    - Expected: Callback invoked with agent name and question
  - Test: "does not trigger on Enter without active mention"
    - Given: No active mention
    - Action: Press Enter
    - Expected: Callback not invoked, returns false (allow default)
  - Test: "replaces command text with loading placeholder"
    - Given: Active mention detected
    - Action: Press Enter
    - Expected: Command text removed, loading node inserted
  - Expected failure: Plugin doesn't exist

- [ ] **GREEN**: Implement `assets/js/presentation/editor/plugins/agent-command-plugin.ts`
  ```typescript
  import { Plugin, PluginKey } from '@milkdown/prose/state'
  import { Decoration, DecorationSet } from '@milkdown/prose/view'
  import { processAgentCommand } from '../../../application/use-cases/process-agent-command'
  
  export const agentCommandPluginKey = new PluginKey('agentCommand')
  
  export function createAgentCommandPlugin(
    schema: Schema,
    onQuery: (params: { agentName: string; question: string; nodeId: string }) => void
  ): Plugin {
    return new Plugin({
      key: agentCommandPluginKey,
      
      state: {
        init() {
          return { decorations: DecorationSet.empty, activeMention: null }
        },
        
        apply(tr, prevState) {
          // Detect @j command at cursor
          // Update activeMention state
          // Return updated state
        }
      },
      
      props: {
        handleDOMEvents: {
          keydown(view, event) {
            if (event.key !== 'Enter') return false
            
            const pluginState = agentCommandPluginKey.getState(view.state)
            const mention = pluginState?.activeMention
            
            if (!mention) return false
            
            // Process command
            const result = processAgentCommand(mention.text)
            if (!result.valid) return false
            
            // Prevent default
            event.preventDefault()
            event.stopPropagation()
            
            // Replace command with loading node
            const nodeId = generateNodeId()
            const tr = view.state.tr
            // ... create and insert loading node
            view.dispatch(tr)
            
            // Trigger callback
            if (onQuery) {
              onQuery({
                agentName: result.agentName!,
                question: result.question!,
                nodeId
              })
            }
            
            return true
          }
        }
      }
    })
  }
  ```

- [ ] **REFACTOR**: Improve plugin organization
  - Extract helper functions
  - Add comprehensive documentation
  - Handle edge cases

#### Phoenix Hook: Agent Query Coordinator

**Context**: Hook that receives the agent command from the ProseMirror plugin and communicates with LiveView to initiate the query and receive streaming responses.

- [ ] **RED**: Write test `assets/js/presentation/hooks/agent-query-hook.test.ts`
  - Test: "sends agent_query_command event to LiveView"
    - Given: Hook receives callback from plugin with agent name and question
    - Expected: Calls `pushEvent` with correct payload
  - Test: "handles agent_chunk events from LiveView"
    - Given: LiveView sends agent_chunk event
    - Expected: Updates editor with streamed chunk
  - Test: "handles agent_done event"
    - Given: LiveView sends agent_done event
    - Expected: Replaces loading indicator with final response
  - Test: "handles agent_error event"
    - Given: LiveView sends agent_error event
    - Expected: Shows error message in editor
  - Test: "supports cancellation"
    - Given: Query in progress
    - Action: User cancels
    - Expected: Sends cancel event to LiveView
  - Expected failure: Hook doesn't exist

- [ ] **GREEN**: Implement `assets/js/presentation/hooks/agent-query-hook.ts`
  ```typescript
  import { ViewHook } from 'phoenix_live_view'
  
  export class AgentQueryHook extends ViewHook<HTMLElement> {
    mounted(): void {
      // Listen for query initiation from ProseMirror plugin
      this.el.addEventListener('agent-query', this.handleAgentQuery)
      
      // Listen for streaming events from LiveView
      this.handleEvent('agent_chunk', this.handleChunk)
      this.handleEvent('agent_done', this.handleDone)
      this.handleEvent('agent_error', this.handleError)
    }
    
    private handleAgentQuery = (event: CustomEvent) => {
      const { agentName, question, nodeId } = event.detail
      
      // Send to LiveView
      this.pushEvent('agent_query_command', {
        command: `@j ${agentName} ${question}`,
        node_id: nodeId
      })
    }
    
    private handleChunk = (payload: any) => {
      // Dispatch event to editor to update node with chunk
      const event = new CustomEvent('agent-chunk-received', {
        detail: payload
      })
      this.el.dispatchEvent(event)
    }
    
    private handleDone = (payload: any) => {
      // Dispatch event to editor to finalize response
      const event = new CustomEvent('agent-done-received', {
        detail: payload
      })
      this.el.dispatchEvent(event)
    }
    
    private handleError = (payload: any) => {
      // Dispatch event to editor to show error
      const event = new CustomEvent('agent-error-received', {
        detail: payload
      })
      this.el.dispatchEvent(event)
    }
    
    destroyed(): void {
      this.el.removeEventListener('agent-query', this.handleAgentQuery)
      this.removeHandleEvent('agent_chunk')
      this.removeHandleEvent('agent_done')
      this.removeHandleEvent('agent_error')
    }
  }
  ```

- [ ] **REFACTOR**: Clean up
  - Ensure proper event cleanup
  - Add error handling
  - Document event contracts

#### Editor Integration: Response Rendering

**Context**: Update the editor to render loading indicators and stream agent responses.

- [ ] **RED**: Write test `assets/js/presentation/editor/agent-response-renderer.test.ts`
  - Test: "inserts loading indicator node"
    - Given: Agent query initiated with nodeId
    - Expected: Loading node inserted at cursor position
  - Test: "updates node with streamed chunks"
    - Given: Loading node exists, chunk received
    - Expected: Node content updated with accumulated response
  - Test: "replaces loading indicator with final response"
    - Given: Agent done event received
    - Expected: Loading node replaced with response node
  - Test: "shows error message on failure"
    - Given: Agent error event received
    - Expected: Shows error in editor at node position
  - Expected failure: Module doesn't exist

- [ ] **GREEN**: Implement `assets/js/presentation/editor/agent-response-renderer.ts`
  ```typescript
  export class AgentResponseRenderer {
    constructor(private view: EditorView) {
      this.setupEventListeners()
    }
    
    private setupEventListeners() {
      this.view.dom.addEventListener('agent-chunk-received', this.handleChunk)
      this.view.dom.addEventListener('agent-done-received', this.handleDone)
      this.view.dom.addEventListener('agent-error-received', this.handleError)
    }
    
    private handleChunk = (event: CustomEvent) => {
      const { nodeId, chunk } = event.detail
      // Find node by ID and update content
      // Append chunk to existing content
    }
    
    private handleDone = (event: CustomEvent) => {
      const { nodeId, response } = event.detail
      // Find node by ID and finalize
      // Replace loading indicator with final content
    }
    
    private handleError = (event: CustomEvent) => {
      const { nodeId, error } = event.detail
      // Find node by ID and show error
    }
    
    public destroy() {
      this.view.dom.removeEventListener('agent-chunk-received', this.handleChunk)
      this.view.dom.removeEventListener('agent-done-received', this.handleDone)
      this.view.dom.removeEventListener('agent-error-received', this.handleError)
    }
  }
  ```

- [ ] **REFACTOR**: Improve rendering logic

### Phase 4 Completion Checklist

- [ ] All infrastructure tests pass
- [ ] All presentation tests pass
- [ ] Full frontend test suite passes (`npm test`)
- [ ] TypeScript compilation successful
- [ ] Integration with backend verified
- [ ] ProseMirror plugin correctly detects commands
- [ ] Phoenix Hook properly bridges editor and LiveView
- [ ] Streaming responses render smoothly

---

## Integration Points

### Backend ↔ Frontend Communication

**LiveView Events:**
- **Client → Server**: `agent_query_command`
  - Payload: `{command: "@j agent_name Question", node_id: "node_123"}`
- **Server → Client**: `agent_chunk`
  - Payload: `{node_id: "node_123", chunk: "text..."}`
- **Server → Client**: `agent_done`
  - Payload: `{node_id: "node_123", response: "full response"}`
- **Server → Client**: `agent_error`
  - Payload: `{node_id: "node_123", error: "error message"}`

**Data Flow:**
1. User types `@j agent_name Question` and presses Enter
2. ProseMirror plugin detects command and dispatches to Phoenix Hook
3. Phoenix Hook sends `agent_query_command` event to LiveView
4. LiveView calls `Documents.execute_agent_query/2`
5. Documents context parses command and looks up agent
6. Documents context calls `Agents.agent_query/2` with agent settings
7. Agents context streams response back to LiveView process
8. LiveView pushes streaming events to client
9. Phoenix Hook receives events and updates editor
10. Editor renders streamed response inline

### Agent Settings Flow

**Agent Configuration:**
- Agent has `system_prompt`, `model`, `temperature` fields
- `Documents.execute_agent_query` looks up agent by name
- Agent object passed to `Agents.agent_query` as parameter
- `AgentQuery` use case uses agent's settings when present
- `PrepareContext.build_system_message_with_agent` combines agent's prompt with document context
- LLM receives agent's model and temperature settings

### Document Context

**Context Passed to Agent:**
- Workspace name
- Project name (if applicable)
- Document title
- Document content (markdown, truncated to 3000 chars)
- Agent's custom system_prompt (if configured)

---

## Testing Strategy

### Test Distribution by Layer

**Backend:**
- **Domain Layer**: 6 tests (parser: valid formats, edge cases, errors)
- **Application Layer**: 10 tests (use case: success, agent lookup, errors, settings)
- **Infrastructure Layer**: 0 new tests (uses existing Agents queries)
- **Interface Layer**: 8 tests (LiveView events, streaming handlers)
- **Total Backend**: ~24 tests

**Frontend:**
- **Domain Layer**: 11 tests (parser: 6 tests, validator: 5 tests)
- **Application Layer**: 4 tests (process command use case)
- **Infrastructure Layer**: 0 new tests (uses existing Phoenix LiveView infrastructure)
- **Presentation Layer**: 15 tests (plugin: 5 tests, hook: 5 tests, renderer: 5 tests)
- **Total Frontend**: ~30 tests

**Total Estimated Tests**: ~54 tests

### Critical Integration Tests

These tests validate the full stack integration:

1. **End-to-End Agent Query Flow**
   - File: `test/jarga_web/features/agent_query_in_document_test.exs`
   - Scope: Full flow from command entry to response rendering
   - Validates: Command parsing, agent lookup, streaming, response insertion

2. **Agent Not Found Error Path**
   - File: Same as above
   - Scope: Error handling when agent doesn't exist
   - Validates: Error message displayed to user

3. **Agent Settings Applied**
   - File: Same as above
   - Scope: Verify agent's custom settings used
   - Validates: System prompt, model, temperature correctly applied

4. **Streaming Response**
   - File: Same as above
   - Scope: Verify chunks streamed and accumulated
   - Validates: Loading indicator → chunks → final response

5. **Cancellation**
   - File: Same as above
   - Scope: User cancels mid-stream
   - Validates: Query terminated, error message shown

---

## Final Validation Checklist

### Phase Completion

- [ ] Phase 1 complete (Backend Domain + Application)
- [ ] Phase 2 complete (Backend Infrastructure + Interface)
- [ ] Phase 3 complete (Frontend Domain + Application)
- [ ] Phase 4 complete (Frontend Infrastructure + Presentation)

### Quality Gates

- [ ] Full test suite passes (backend + frontend)
  - `mix test` → All passing
  - `npm test` → All passing
- [ ] No boundary violations (`mix boundary`)
- [ ] Integration tests pass (end-to-end flows)
- [ ] No TypeScript compilation errors
- [ ] Code formatted and linted
  - `mix format --check-formatted`
  - Backend Credo checks pass
  - Frontend linting passes

### Feature Validation

- [ ] User can invoke agent with `@j agent_name Question` syntax
- [ ] Agent receives full document content as context
- [ ] Agent response appears inline where command was typed
- [ ] Loading state visible while agent processes request
- [ ] Agent uses its custom system_prompt combined with document context
- [ ] Error messages displayed for invalid commands or missing agents
- [ ] Streaming response updates smoothly character-by-character
- [ ] Final response remains in document as editable content

### Acceptance Criteria Met

**From PRD:**
- [x] User types `@j [agent_name] [question]` and presses Enter
- [x] Command text disappears from editor
- [x] Loading indicator ("Agent thinking..." + spinner) appears at that location
- [x] System extracts full document content
- [x] System identifies agent by name from workspace agents list
- [x] Agent receives both its custom system_prompt and document context
- [x] Agent's response streams back character-by-character
- [x] Loading indicator replaced by streaming response
- [x] Final response remains in document as editable content

### Non-Functional Requirements

- [ ] Performance: Agent query initiates within 200ms
- [ ] Performance: First chunk received within 2 seconds (network dependent)
- [ ] Performance: UI remains responsive during streaming
- [ ] Accessibility: Loading state announced to screen readers
- [ ] Security: Agent lookup respects workspace visibility rules
- [ ] Security: Only workspace-available agents can be invoked
