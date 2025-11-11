# CLAUDE.md

This file provides guidance to Claude Code when working with Elixir and Phoenix code in this repository.

## 🤖 Orchestrated Development Workflow

**This project uses specialized subagents to maintain code quality, architectural integrity, and TDD discipline.**

### Feature Implementation Protocol

When implementing a new feature, follow this orchestrated workflow:

#### Phase 1: Planning (Use `architect` subagent)

**When to delegate:**
- User requests a new feature
- Feature spans multiple layers or contexts
- Implementation requires TDD planning

**What the architect does:**
- Reads architectural documentation
- Creates comprehensive TDD implementation plan
- Identifies affected boundaries
- Plans RED-GREEN-REFACTOR cycles for each layer
- Creates structured TodoList

**Invocation:**
```
"Use the architect subagent to plan implementation of [feature]"
```

**Output:** Detailed implementation plan with test-first steps for all layers

#### Phase 2: Backend Implementation (Use `backend-tdd` subagent)

**When to delegate:**
- Implementing backend features from architect's plan
- Creating Elixir/Phoenix code
- Following TDD cycle for backend

**What backend-tdd does:**
- Strictly follows RED-GREEN-REFACTOR cycle
- Implements domain → application → infrastructure → interface layers
- Writes tests BEFORE implementation (enforced)
- Updates TodoList after each cycle
- Runs tests continuously
- Validates with `mix boundary`

**Invocation:**
```
"Use the backend-tdd subagent to implement the backend portion of the plan"
```

**Output:** Fully tested backend implementation with passing tests

#### Phase 3: Frontend Implementation (Use `frontend-tdd` subagent)

**When to delegate:**
- Implementing frontend features from architect's plan
- Creating TypeScript/JavaScript code
- Following TDD cycle for frontend

**What frontend-tdd does:**
- Strictly follows RED-GREEN-REFACTOR cycle
- Implements domain → application → infrastructure → presentation layers
- Writes tests BEFORE implementation (enforced)
- Updates TodoList after each cycle
- Uses Vitest for all tests
- Maintains TypeScript type safety

**Invocation:**
```
"Use the frontend-tdd subagent to implement the frontend portion of the plan"
```

**Output:** Fully tested frontend implementation with passing tests

#### Phase 4: Test Validation (Use `test-validator` subagent)

**When to delegate:**
- After implementation phase completes
- Before code review
- To verify TDD process was followed

**What test-validator does:**
- Validates TDD process (tests written first)
- Checks test quality and organization
- Verifies test speed (domain tests in milliseconds)
- Validates test coverage
- Identifies test smells
- Ensures proper mocking strategy

**Invocation:**
```
"Use the test-validator subagent to validate the test suite"
```

**Output:** Test validation report with issues and recommendations

#### Phase 5: Code Review (Use `code-reviewer` subagent)

**When to delegate:**
- After test validation passes
- Before committing code
- To ensure architectural compliance

**What code-reviewer does:**
- Runs `mix boundary` to check violations
- Reviews SOLID principles compliance
- Checks for security vulnerabilities
- Validates code quality
- Ensures proper error handling
- Verifies PubSub broadcasts after transactions
- Checks performance concerns

**Invocation:**
```
"Use the code-reviewer subagent to review the implementation"
```

**Output:** Code review report with approval or required changes

#### Phase 6: Documentation Sync (Use `doc-sync` subagent)

**When to delegate:**
- After successful code review
- When new patterns emerge
- To keep documentation current

**What doc-sync does:**
- Extracts reusable patterns
- Updates relevant documentation files
- Adds examples to TDD guides
- Formalizes new conventions
- Synchronizes code and docs
- Updates README if needed

**Invocation:**
```
"Use the doc-sync subagent to update documentation"
```

**Output:** Documentation update report with files changed

### The Self-Learning Loop

Each feature implementation strengthens the system:

```
Feature Request
    ↓
[architect] → Creates TDD plan
    ↓
[backend-tdd] → Implements with tests first
    ↓
[frontend-tdd] → Implements with tests first
    ↓
[test-validator] → Validates TDD compliance
    ↓
[code-reviewer] → Ensures architectural integrity
    ↓
[doc-sync] → Extracts patterns and updates docs
    ↓
Updated docs inform next implementation (LOOP)
```

### Workflow Benefits

1. **Consistent Quality** - Every feature follows same rigorous process
2. **Knowledge Retention** - Patterns documented as they emerge
3. **TDD Enforcement** - Tests written first (validated automatically)
4. **Boundary Protection** - Architectural violations caught early
5. **Self-Improving** - Each iteration makes next one easier

### Subagent Coordination

**When to use multiple subagents in sequence:**

```
User: "Add real-time notification feature"

Step 1: architect → Plan implementation
Step 2: backend-tdd → Implement Phoenix Channel
Step 3: frontend-tdd → Implement TypeScript hook
Step 4: test-validator → Validate all tests
Step 5: code-reviewer → Review implementation
Step 6: doc-sync → Document pattern
```

**When main Claude should handle directly:**

- Simple bug fixes (< 5 lines)
- Documentation-only changes
- Configuration updates
- Exploratory research
- Answering questions about codebase

### Critical Rules

1. **NEVER skip test-validator** - Ensures TDD was followed
2. **NEVER skip code-reviewer** - Catches boundary violations
3. **ALWAYS run in sequence** - Each phase depends on previous
4. **ALWAYS update docs** - Maintains self-learning loop
5. **NEVER write implementation before tests** - Non-negotiable

### Subagent Reference

Available subagents in `.claude/agents/`:

- **architect** - Feature planning and TDD design
- **backend-tdd** - Backend implementation with TDD
- **frontend-tdd** - Frontend implementation with TDD
- **test-validator** - Test quality and TDD process validation
- **code-reviewer** - Architectural and security review
- **doc-sync** - Documentation synchronization and pattern extraction

### MCP Tools Integration

All subagents have access to **Context7 MCP tools** for up-to-date library documentation:

**Available MCP Tools:**
- `mcp__context7__resolve-library-id` - Resolve library name to Context7 ID
- `mcp__context7__get-library-docs` - Fetch documentation for a library

**Common Libraries:**
- Phoenix: `/phoenixframework/phoenix`
- Phoenix LiveView: `/phoenixframework/phoenix_live_view`
- Ecto: `/elixir-ecto/ecto`
- Vitest: `/vitest-dev/vitest`
- TypeScript: `/microsoft/TypeScript`
- Mox: `/dashbitco/mox`

**When Subagents Use MCP Tools:**

1. **architect** - Research library capabilities before planning
2. **backend-tdd** - Check testing patterns and API usage
3. **frontend-tdd** - Verify TypeScript patterns and Vitest usage
4. **test-validator** - Validate against official testing guidelines
5. **code-reviewer** - Verify security practices and API usage

**Example Usage:**
```
Subagent needs Phoenix Channel testing patterns:
1. mcp__context7__resolve-library-id("phoenix") → "/phoenixframework/phoenix"
2. mcp__context7__get-library-docs("/phoenixframework/phoenix", topic: "channels")
3. Use documentation to implement/validate correctly
```

This ensures all subagents work with **current, official documentation** rather than outdated patterns.

### Quick Start Example

```
User: "Add user profile avatar upload"

Claude: "I'll orchestrate this feature through our TDD workflow:

1. First, I'll use the architect subagent to create a comprehensive plan...
   [Delegates to architect]

2. Next, the backend-tdd subagent will implement the backend with tests first...
   [Delegates to backend-tdd]

3. Then, the frontend-tdd subagent will implement the UI with tests first...
   [Delegates to frontend-tdd]

4. The test-validator will verify our TDD process...
   [Delegates to test-validator]

5. The code-reviewer will check architectural compliance...
   [Delegates to code-reviewer]

6. Finally, doc-sync will update documentation with any new patterns...
   [Delegates to doc-sync]

Feature complete with full test coverage and documentation!"
```

---

## Quick Reference

For detailed documentation on architecture, TDD practices, and implementation guidelines, see:

📖 **Architecture & Design:**
- `docs/prompts/architect/FULLSTACK_TDD.md` - Complete TDD methodology
- `docs/prompts/backend/PHOENIX_DESIGN_PRINCIPLES.md` - Backend architecture
- `docs/prompts/backend/PHOENIX_BEST_PRACTICES.md` - Phoenix conventions
- `docs/prompts/frontend/FRONTEND_DESIGN_PRINCIPLES.md` - Frontend architecture

🤖 **Subagent Details:**
- `.claude/agents/architect.md` - Feature planning process
- `.claude/agents/backend-tdd.md` - Backend TDD implementation
- `.claude/agents/frontend-tdd.md` - Frontend TDD implementation
- `.claude/agents/test-validator.md` - Test quality validation
- `.claude/agents/code-reviewer.md` - Code review process
- `.claude/agents/doc-sync.md` - Documentation synchronization

**Key Principles:**
- ✅ **Tests first** - Always write tests before implementation
- ✅ **Boundary enforcement** - Use `mix boundary` to catch violations
- ✅ **SOLID principles** - Single responsibility, dependency inversion, etc.
- ✅ **Clean Architecture** - Domain → Application → Infrastructure → Interface
- ✅ **Self-documenting** - Patterns extracted and documented automatically
