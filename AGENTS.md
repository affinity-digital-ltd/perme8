This file provides guidance to OpenCode when working with Elixir and Phoenix code in this repository.

## 🤖 Orchestrated Development Workflow

**This project uses specialized subagents to maintain code quality, architectural integrity, and TDD discipline.**

### Feature Implementation Protocol

When implementing a new feature, follow this orchestrated workflow using **Behavior-Driven Development (BDD)** as the default approach:

### Planning Phases

#### Planning Phase 1: Requirements Gathering (Use `@prd` subagent) - OPTIONAL

**When to delegate:**

- User has a feature idea but requirements are unclear
- Feature is complex and needs detailed specification

**What the prd agent does:**

- Interviews user with structured questions
- Gathers functional and non-functional requirements
- Researches existing codebase for context
- Documents user stories, workflows, and acceptance criteria
- Identifies constraints, edge cases, and success metrics
- Creates comprehensive Product Requirements Document (PRD)

**Invocation:**

```
"Use the @prd subagent to gather requirements for [feature]"
```

**Output:**

- Comprehensive PRD with user stories, requirements, constraints, and codebase context
- **IMPORTANT**: Main Agent MUST save the PRD to `jargav3/docs/features/[feature-name]-prd.md`

**Note:** You can skip this phase if requirements are already clear and well-defined. Go directly to Planning Phase 2 for simple, well-understood features.

#### Planning Phase 2: Technical Planning (Use `@architect` subagent) - OPTIONAL

**When to delegate:**

- User requests a complex feature that spans multiple layers or contexts
- Feature is large enough to benefit from upfront planning
- You want a structured implementation plan

**What the architect does:**

- Reads architectural documentation
- Creates comprehensive BDD/TDD implementation plan
- Identifies affected boundaries
- Plans BDD implementation steps and supporting unit tests
- **Creates TodoList.md file** with all checkboxes for tracking

**Invocation:**

```
"Use the @architect subagent to plan implementation of [feature]"
```

**Output:**

- Detailed implementation plan with BDD feature scenarios and TDD unit test planning
- **IMPORTANT**: Main Agent MUST save the implementation plan to `jargav3/docs/features/[feature-name]-implementation-plan.md`
- **TodoList.md file** in project root with all checkboxes organized by phase

**After Planning Phase 2, Main Agent MUST:**

1. Save the architect's full implementation plan to `docs/features/[feature-name]-implementation-plan.md`
2. Save the prd agent's PRD to `docs/features/[feature-name]-prd.md` (if Planning Phase 1 was run)
3. Update `TodoList.md` header to reference these documents with full file paths
4. Ensure TodoList.md includes note: "IMPORTANT FOR SUBAGENTS: Read both the PRD and Implementation Plan before starting"

**The TodoList.md File:**
The architect creates a `TodoList.md` file that serves as the **single source of truth** for implementation progress. This file:

- Contains ALL implementation checkboxes from the detailed plan
- References PRD and Implementation Plan at the top with full file paths
- Organized by Implementation Steps (1-3) and QA Phases (1-2)
- Uses status indicators: ⏸ (Not Started), ⏳ (In Progress), ✓ (Complete)
- Implementation agents check off items as they complete them
- Main Agent updates phase status between agent runs

**Note:** You can skip this phase and go directly to BDD Step 1 for simple, well-understood features.

### BDD Implementation Workflow

The BDD workflow creates a feature file first, then implements the feature to make it pass. This provides executable documentation and verifies full-stack integration.

#### Implementation Step 1: Create Feature File (RED)

**When to delegate:**

- After requirements are gathered (PRD created)
- Before implementing the feature
- When you want executable specifications

**What fullstack-bdd does in Step 1:**

- Reads the PRD (or requirements from user)
- Creates `.feature` file in `test/features/` with Gherkin scenarios
- Writes step definitions in `test/features/step_definitions/`
- Step definitions contain full-stack test logic (HTTP → HTML)
- Runs tests to verify they FAIL (RED state)
- Documents expected behavior in business language

**Invocation:**

```
"Use the @fullstack-bdd subagent to create feature file and step definitions from the PRD"
```

**Output:**

- `.feature` file with Gherkin scenarios (Given/When/Then)
- Step definitions implementing full-stack test logic
- Tests run and FAIL (expected - feature not implemented yet)
- Clear specification of what needs to be built

**Example Feature File Created:**

```gherkin
Feature: Document Visibility Management
  As a document owner
  I want to control document visibility
  So that I can share documents with my team or keep them private

  Background:
    Given a workspace exists with name "Product Team" and slug "product-team"
    And the following users exist:
      | Email              | Role   |
      | alice@example.com  | Owner  |
      | bob@example.com    | Member |

  Scenario: Owner makes document public
    Given I am logged in as "alice@example.com"
    And a document "Product Roadmap" exists owned by "alice@example.com"
    When I make the document public
    Then the document visibility should be "public"
    And "bob@example.com" should be able to view the document

  Scenario: Member cannot change document visibility
    Given I am logged in as "bob@example.com"
    And a document "Product Roadmap" exists owned by "alice@example.com"
    When I attempt to make the document public
    Then I should receive a forbidden error
```

---

#### Implementation Step 2: Implement Feature via TDD (RED, GREEN)

**After feature file is created (Step 1), implement the feature using TDD agents:**

**For Backend Implementation:**

```
"Use the @phoenix-tdd subagent to implement backend for document visibility feature"
```

Phoenix-tdd implements:

- Domain logic (pure functions, visibility rules)
- Application layer (use cases with authorization)
- Infrastructure (database, queries)
- Interface (LiveView, controllers)

Each component follows RED-GREEN-REFACTOR cycle at unit level.

**For Frontend Implementation (if needed):**

```
"Use the @typescript-tdd subagent to implement frontend for document visibility UI"
```

Typescript-tdd implements:

- Domain logic (client-side validation)
- Application layer (visibility update use cases)
- Infrastructure (API calls, storage)
- Presentation (LiveView hooks, UI updates)

Each component follows RED-GREEN-REFACTOR cycle at unit level.

**During Step 2:**

- Unit tests pass (GREEN at unit level)
- Feature tests may still fail (RED at integration level)
- This is expected - implementation is incremental

**Main Agent Action During Implementation:**

Run pre-commit checks periodically to catch issues early:

```bash
mix precommit
```

Fix any issues:

- If formatter changes code: Review and commit changes
- If Credo reports warnings: Fix issues
- If Dialyzer reports type errors: Fix type specs
- If tests fail: Debug and fix failing tests
- If boundary violations: Refactor to fix violations

---

#### Implementation Step 3: Feature Tests Pass (GREEN)

**When all units are implemented:**

```
"Use the @fullstack-bdd subagent to verify feature tests pass"
```

**What fullstack-bdd does in Step 3:**

- Runs all feature scenarios
- Verifies full-stack integration (HTTP → HTML)
- All scenarios pass (GREEN state)
- Feature is complete and verified end-to-end

**Invocation:**

```
"Use the @fullstack-bdd subagent to run feature tests and verify they pass"
```

**Output:**

- All feature scenarios pass
- Full-stack integration verified
- Executable documentation of feature behavior

---

### BDD Testing Principles

The fullstack-bdd agent follows strict principles:

1. **Full-Stack Testing** - Always test HTTP → HTML, never backend-only
2. **Real Database** - Use Ecto Sandbox, not mocked repositories
3. **Mock 3rd Parties** - Mock external APIs (LLMs, payments, etc.)
4. **LiveViewTest First** - Use Phoenix.LiveViewTest, only Wallaby for `@javascript`
5. **Business Language** - Write tests in Gherkin (Given/When/Then)
6. **Executable Docs** - Tests document feature behavior

---

### Quality Assurance Phases

After implementation is complete, run these quality assurance phases:

#### QA Phase 1: Test Validation (Use `@test-validator` subagent)

**When to delegate:**

- After all 4 implementation phases complete
- Before code review
- To verify TDD process was followed across all layers

**What test-validator does:**

- Validates TDD process (tests written first)
- Checks test quality and organization
- Verifies test speed (domain tests in milliseconds)
- Validates test coverage across all layers
- Identifies test smells
- Ensures proper mocking strategy

**Invocation:**

```
"Use the @test-validator subagent to validate the test suite"
```

**Output:** Test validation report with issues and recommendations

#### QA Phase 2: Code Review (Use `@code-reviewer` subagent)

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
"Use the @code-reviewer subagent to review the implementation"
```

**Output:** Code review report with approval or required changes

### The Self-Learning Loop

Each feature implementation strengthens the system:

```
Feature Request
    ↓
Planning Phases:
    ↓
Planning Phase 1 (Optional): [prd] → Gathers requirements
    ↓
Planning Phase 2 (Optional): [architect] → Creates TDD plan
    ↓
BDD Implementation:
    ↓
Step 1: [fullstack-bdd] → Create .feature file from PRD (RED)
    - Write Gherkin scenarios describing user behavior
    - Write step definitions (tests will FAIL - this is expected)
    - Feature tests are RED (failing) because feature isn't implemented
    ↓
Step 2: [Implement via TDD] → Implement feature units via TDD (RED, GREEN)
    - Use phoenix-tdd for backend (Phases 1-2)
    - Use typescript-tdd for frontend (Phases 3-4)
    - Each unit follows RED-GREEN-REFACTOR
    - Unit tests pass, but feature tests may still be RED
    ↓
Step 3: [fullstack-bdd] → Feature tests pass (GREEN)
    - All unit implementations complete
    - Feature scenarios now pass end-to-end
    - Full-stack integration verified
    ↓
Quality Assurance Phases:
    ↓
QA Phase 1: [test-validator] → Validates TDD compliance across all layers
    ↓
QA Phase 2: [code-reviewer] → Ensures architectural integrity
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

Planning Phases:
  Planning Phase 1 (Optional): prd → Gather detailed requirements
  Planning Phase 2 (Optional): architect → Plan implementation

BDD Implementation:
  Step 1: fullstack-bdd → Create .feature file from PRD (RED)
  Step 2: Implement via TDD (RED, GREEN)
    - phoenix-tdd → Backend implementation (domain, application, infrastructure, interface)
    - typescript-tdd → Frontend implementation (domain, application, infrastructure, presentation)
  Step 3: fullstack-bdd → Feature tests pass (GREEN)

Quality Assurance Phases:
  QA Phase 1: test-validator → Validate all tests
  QA Phase 2: code-reviewer → Review implementation
```

**Key Points:**

- **Feature file first** - Always start with executable specifications
- **Full-stack integration** - Feature tests verify complete user workflows
- **Unit tests support** - TDD agents implement units with their own tests
- **End-to-end verification** - Feature tests confirm everything works together

**When main Agent should handle directly:**

- Simple bug fixes (< 5 lines)
- Documentation-only changes
- Configuration updates
- Exploratory research
- Answering questions about codebase

### Critical Rules

1. **NEVER skip test-validator** - Ensures TDD was followed
2. **NEVER skip code-reviewer** - Catches boundary violations
3. **ALWAYS run in sequence** - Each phase depends on previous
4. **NEVER write implementation before tests** - Non-negotiable
5. **Feature file first** - Write .feature before implementation
6. **Full-stack tests** - Always verify HTTP → HTML
7. **Real database** - Use Ecto Sandbox, not mocks
8. **Business language** - Gherkin scenarios readable by non-developers

---

### Subagent Reference

Available subagents in `.opencode/agent/`:

- **prd** - Requirements gathering and PRD creation (optional first step)
- **architect** - Feature planning and TDD design
- **phoenix-tdd** - Phoenix backend and LiveView implementation with TDD
- **typescript-tdd** - TypeScript implementation with TDD (hooks, clients, standalone code)
- **fullstack-bdd** - Full-stack BDD testing with Cucumber (feature files and step definitions)
- **test-validator** - Test quality and TDD process validation
- **code-reviewer** - Architectural and security review

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
2. **phoenix-tdd** - Check Phoenix/Elixir testing patterns and API usage
3. **typescript-tdd** - Verify TypeScript patterns and Vitest usage
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

Main agent: "I'll orchestrate this feature through our BDD workflow:

Planning Phases:

  Planning Phase 1 (Optional): First, let me use the prd subagent to gather requirements...
    [Delegates to prd - can skip if requirements are clear]

  Planning Phase 2 (Optional): The architect subagent will create a comprehensive plan...
    [Delegates to architect]
    Output:
    - Detailed implementation plan
    - TodoList.md created with all checkboxes for 3 implementation steps + 2 QA phases

BDD Implementation:
(All agents read TodoList.md and check off items as they complete them)

  Step 1: Create Feature File (RED)
    [Delegates to fullstack-bdd]
    Output:
    - test/features/user_avatar_upload.feature created
    - Step definitions created
    - Tests run and FAIL (expected - RED state)

  Step 2: Implement Feature via TDD (RED, GREEN)
    [Delegates to phoenix-tdd for backend]
    Output: Backend implemented, unit tests pass

    [Delegates to typescript-tdd for frontend if needed]
    Output: Frontend implemented, unit tests pass

  Main Agent Pre-commit Checkpoint (After Step 2):
    [Main Agent runs: mix precommit]
    [Main Agent runs: npm test]
    [Fixes any issues: formatting, Credo, Dialyzer, TypeScript, tests, boundaries]
    Output: "All pre-commit checks passing. Full test suite green. Ready for Step 3."

  Step 3: Feature Tests Pass (GREEN)
    [Delegates to fullstack-bdd]
    Output: All feature scenarios pass - full-stack integration verified

Quality Assurance Phases:
(All QA agents also use TodoList.md for their checklists)

  QA Phase 1: Verify TDD process across all layers...
    [Delegates to test-validator]
    Output: "Test validation complete. TodoList.md updated to ✓"

  QA Phase 2: Check architectural compliance...
    [Delegates to code-reviewer]
    Output: "Code review complete. TodoList.md updated to ✓"

Feature complete with full-stack verification!"
```

---

## Quick Reference

For detailed documentation on architecture, BDD, TDD practices, and implementation guidelines, see:

📖 **Architecture & Design:**

- `docs/prompts/architect/FEATURE_TESTING_GUIDE.md` - Complete BDD methodology
- `docs/prompts/phoenix/PHOENIX_DESIGN_PRINCIPLES.md` - Phoenix architecture
- `docs/prompts/phoenix/PHOENIX_BEST_PRACTICES.md` - Phoenix conventions
- `docs/prompts/typescript/TYPESCRIPT_DESIGN_PRINCIPLES.md` - Frontend assets architecture

🤖 **Subagent Details:**

- `.opencode/agent/prd.md` - Requirements gathering and PRD creation
- `.opencode/agent/architect.md` - Feature planning process
- `.opencode/agent/phoenix-tdd.md` - Phoenix and LiveView TDD implementation
- `.opencode/agent/typescript-tdd.md` - TypeScript TDD implementation
- `.opencode/agent/fullstack-bdd.md` - Full-stack BDD testing with Cucumber
- `.opencode/agent/test-validator.md` - Test quality validation
- `.opencode/agent/code-reviewer.md` - Code review process

**Key Principles:**

- ✅ **Tests first** - Always write tests before implementation
- ✅ **Boundary enforcement** - Use `mix boundary` to catch violations
- ✅ **SOLID principles** - Single responsibility, dependency inversion, etc.
- ✅ **Clean Architecture** - Domain → Application → Infrastructure → Interface

There are NO TIME Constraints and NO token limits!
