# PRD: In-Document Agent Chat

## User Story

As a product owner, developer, or business stakeholder collaborating on documentation in Jarga, I want to modify the @j mention system in Documents to invoke an AI agent directly within the document editor by typing `@j agent_name Question` so that I can get contextual assistance without leaving my editing flow or switching to a separate chat panel.

## Phase 1 Scope: Single Agent POC

**What's Included:**
- Enhance existing `@j` mention system to support agent selection via `@j agent_name Question` syntax
- Support any agent from the user's workspace agents list
- Pass full document content as context to the selected agent
- Agent response replaces the `@j` command inline with loading indicator and streaming response
- User sees their agent's custom system prompt combined with document context

**Why This is Minimum Viable:**
- Proves the core value: contextual agent help without breaking editing flow
- Leverages existing infrastructure: streaming, loading states, and document context extraction
- Single agent eliminates complexity of agent discovery UI while proving the interaction pattern works

**What's Deferred to Future Phases:**
- Agent selection UI/autocomplete (Phase 2)
- Agent name validation and error messages (Phase 2)
- Response editing/regeneration (Phase 4)
- document changes via a diff tool
- Agent Discovery UX - List accessible agents on `@j `  typing; filter by typing, arrow key navigation.


## Phase 1 User Flow

### Happy Path

1. **User opens document editor** in a workspace where they have at least one enabled agent
2. **User types:** `@j any-acessible-agent-name How can I structure this requirements section?`
3. **User presses Enter**
4. **System behavior:**
   - Text `@j my-writer-agent How can I structure this requirements section?` disappears
   - Loading indicator appears: "Agent thinking..." with spinner
   - System extracts full document content as context
   - System sends to the specified agent (using agent's custom system_prompt + document context)
   - Agent response streams back character-by-character, replacing the loading indicator
5. **User sees:** Agent's response appearing inline where they typed the command
6. **User can:** Continue editing the document with the agent's response now part of the content

### Example Interaction

**Before:**
```
# Project Requirements

@j doc-writer How should I structure the acceptance criteria section?
```

**During (loading):**
```
# Project Requirements

Agent thinking... [spinner]
```

**After (complete):**
```
# Project Requirements

For acceptance criteria, I recommend using the Given-When-Then format:

**Acceptance Criteria:**
- **Given** [initial context]
- **When** [action occurs]
- **Then** [expected outcome]

This format ensures testable, unambiguous requirements that both technical and non-technical stakeholders can understand.
```

## Success Criteria

1. User can invoke a workspace agent from within the document editor using `@j agent_name Question` syntax
2. Agent receives full document content as context
3. Agent response appears inline where the command was typed
4. Loading state is visible while agent processes the request
5. Agent uses its custom system_prompt combined with document context (not generic default prompt)

## Acceptance Criteria

**Given** a user is editing a document in a workspace with at least one enabled agent
**When** they type `@j [agent_name] [question]` and press Enter
**Then:**
- [ ] The command text disappears from the editor
- [ ] A loading indicator ("Agent thinking..." + spinner) appears at that location
- [ ] The system extracts the full document content
- [ ] The system identifies the agent by name from the workspace agents list
- [ ] The agent receives both its custom system_prompt and document context
- [ ] The agent's response streams back character-by-character
- [ ] The loading indicator is replaced by the streaming response
- [ ] The final response remains in the document as editable content

**Given** a user has an agent query in progress
**When** they cancel the query
**Then:**
- [ ] The streaming stops
- [ ] Partial response (if any) remains in the document
- [ ] User can continue editing

## Assumptions & Constraints

**Assumptions:**
- User knows the exact name of at least one agent in their workspace
- Workspace has at least one enabled agent available to the user
- Document editor supports inline text replacement (existing capability)
- Existing `@j` system infrastructure can be extended to parse agent names

**Constraints:**
- Phase 1 requires exact agent name match (no fuzzy matching or validation errors)
- Agent must be enabled and accessible in the current workspace
- Full document content passed as context (no partial selection in Phase 1)
- Single agent query at a time per document (existing limitation)
- Uses existing streaming and loading infrastructure

**Business Rules:**
- Only workspace-available agents can be invoked (respects agent visibility: user's own agents + other users' shared agents)
- Agent uses its configured system_prompt, model, and temperature settings etc.
- Document content is passed as context exactly as it exists at query time (no formatting/processing)

---

**Phase 1 Validation Checklist:**
- ✅ User completes ONE meaningful action: "Ask agent a question and get contextual response inline"
- ✅ Clear before/after: Document without response → Document with agent's response inserted
- ✅ Delivers immediate value: Contextual help without leaving editor or opening chat panel
- ✅ Everything non-essential deferred