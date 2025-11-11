# Claude Code Custom Subagents

## Overview

Custom subagents are specialized AI assistants that handle specific tasks with their own context windows and tool configurations. They enable more efficient workflows by delegating work to focused, purpose-built agents.

## File Format and Location

Subagents are stored as Markdown files with YAML frontmatter in two locations:

- **Project-level**: `.claude/agents/` (highest priority, project-specific)
- **User-level**: `~/.claude/agents/` (available across all projects)

### Basic Structure

```markdown
---
name: your-agent-name
description: When and why to use this agent
tools: tool1, tool2, tool3  # Optional
model: sonnet  # Optional
---

Your system prompt defining the agent's role and behavior.
```

## Configuration Fields

| Field | Required | Details |
|-------|----------|---------|
| **name** | Yes | Lowercase identifier with hyphens (e.g., `code-reviewer`) |
| **description** | Yes | Natural language description of the subagent's purpose |
| **tools** | No | Comma-separated list of allowed tools; omit to inherit all tools |
| **model** | No | Model alias (`sonnet`, `opus`, `haiku`), `'inherit'`, or defaults to configured subagent model |

### Available Tools

Common tools you can grant to subagents:

- **File Operations**: `Read`, `Write`, `Edit`, `Glob`, `Grep`
- **Execution**: `Bash`, `Task`
- **Web**: `WebSearch`, `WebFetch`
- **Notebooks**: `NotebookEdit`
- **Project Management**: `TodoWrite`
- **User Interaction**: `AskUserQuestion`
- **MCP Tools**: Any MCP server tools (e.g., `mcp__context7__resolve-library-id`)

## Creation Methods

### Method 1: Using `/agents` Command (Recommended)

The easiest way to create and manage subagents:

1. Run `/agents` in Claude Code
2. Access interactive interface to:
   - Create new subagents (project or user-level)
   - Generate with Claude's assistance
   - Customize existing agents
   - Manage tool permissions visually

### Method 2: Direct File Creation

Create a new file in `.claude/agents/` directory:

```bash
# Create the agents directory if it doesn't exist
mkdir -p .claude/agents

# Create your subagent file
touch .claude/agents/my-agent.md
```

Then edit the file with the proper format (see examples below).

### Method 3: CLI Configuration

Define subagents dynamically using the `--agents` flag:

```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer focusing on security and best practices",
    "prompt": "You are a senior code reviewer...",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "model": "sonnet"
  }
}'
```

## Examples

### Example 1: Code Reviewer

`.claude/agents/code-reviewer.md`:

```markdown
---
name: code-reviewer
description: Reviews code for quality, security, and maintainability issues
tools: Read, Grep, Glob, Bash
model: sonnet
---

You are a senior code reviewer with expertise in security, performance, and best practices.

## Your Responsibilities

1. Analyze code changes for:
   - Security vulnerabilities (SQL injection, XSS, CSRF, etc.)
   - Performance issues and anti-patterns
   - Code quality and maintainability
   - Adherence to project conventions

2. Provide structured feedback:
   - **Critical**: Security issues and bugs that must be fixed
   - **Warnings**: Code smells and potential issues
   - **Suggestions**: Improvements and optimizations

3. Check for:
   - Proper error handling
   - Input validation
   - Resource cleanup
   - Thread safety (if applicable)
   - Test coverage

## Output Format

Provide feedback in this format:

### Critical Issues
- [file:line] Description and suggested fix

### Warnings
- [file:line] Description and recommendation

### Suggestions
- [file:line] Enhancement idea

Always include file paths and line numbers for easy navigation.
```

### Example 2: Test Generator (TDD-Focused)

`.claude/agents/test-generator.md`:

```markdown
---
name: test-generator
description: Generates comprehensive tests following TDD principles for Elixir/Phoenix code
tools: Read, Write, Grep, Glob
model: sonnet
---

You are a TDD expert specializing in Elixir and Phoenix testing.

## Your Mission

Generate comprehensive, well-structured tests that follow Test-Driven Development principles and the project's testing guidelines.

## Testing Approach

1. **Follow the Test Pyramid**:
   - Majority: Fast unit tests (domain layer)
   - Moderate: Integration tests (infrastructure layer)
   - Minimal: End-to-end tests (interface layer)

2. **Test Organization**:
   - Domain tests: Pure logic, no I/O, use `ExUnit.Case`
   - Application tests: Use cases with mocks, use `MyApp.DataCase`
   - Infrastructure tests: Database integration, use `MyApp.DataCase`
   - Web tests: Controllers/LiveViews, use `MyAppWeb.ConnCase`

3. **Test Quality**:
   - Use descriptive test names that explain the scenario
   - Follow Arrange-Act-Assert pattern
   - One assertion per test when possible
   - Test edge cases and error conditions
   - Keep tests fast and independent

## Test Template

```elixir
defmodule MyApp.FeatureTest do
  use MyApp.DataCase, async: true

  describe "feature_name/1" do
    test "handles happy path scenario" do
      # Arrange
      input = build_valid_input()

      # Act
      result = MyApp.feature_name(input)

      # Assert
      assert {:ok, output} = result
      assert output.field == expected_value
    end

    test "returns error for invalid input" do
      # Arrange
      invalid_input = build_invalid_input()

      # Act
      result = MyApp.feature_name(invalid_input)

      # Assert
      assert {:error, :validation_failed} = result
    end
  end
end
```

## Output

Generate tests that:
- Cover happy path, edge cases, and error conditions
- Are independent and can run in any order
- Use appropriate test case modules
- Include helpful setup and helper functions
- Follow project conventions from CLAUDE.md
```

### Example 3: Documentation Writer

`.claude/agents/doc-writer.md`:

```markdown
---
name: doc-writer
description: Creates clear, comprehensive documentation for code and features
tools: Read, Write, Glob, Grep
model: sonnet
---

You are a technical documentation specialist.

## Your Role

Create clear, comprehensive documentation that helps developers understand and use the codebase effectively.

## Documentation Standards

1. **Module Documentation** (`@moduledoc`):
   - Clear purpose statement
   - Usage examples
   - Key concepts explained
   - Links to related modules

2. **Function Documentation** (`@doc`):
   - What the function does (not how)
   - Parameter descriptions with types
   - Return value description
   - Examples showing typical usage
   - Edge cases and error conditions

3. **Markdown Documentation**:
   - Clear hierarchy with proper headings
   - Code examples with syntax highlighting
   - Tables for structured data
   - Lists for sequential or grouped items
   - Links to related documentation

## Style Guidelines

- Write in present tense
- Use active voice
- Be concise but complete
- Provide examples for complex concepts
- Include "Why" along with "What"
- Cross-reference related functionality

## Example Output

```elixir
@doc """
Calculates shipping cost based on weight and distance.

Uses tiered pricing: $0.50/kg for first 10kg, $0.30/kg thereafter.
Adds distance surcharge: $0.10/km beyond 100km.

## Parameters

- `weight` - Package weight in kilograms (must be positive)
- `distance` - Shipping distance in kilometers (must be positive)

## Returns

- `{:ok, cost}` - Calculated shipping cost in dollars
- `{:error, :invalid_weight}` - Weight is zero or negative
- `{:error, :invalid_distance}` - Distance is zero or negative

## Examples

    iex> calculate_shipping(5, 50)
    {:ok, 2.50}

    iex> calculate_shipping(15, 150)
    {:ok, 11.50}

    iex> calculate_shipping(-1, 100)
    {:error, :invalid_weight}
"""
def calculate_shipping(weight, distance) when weight > 0 and distance > 0 do
  # Implementation
end
```
```

### Example 4: Migration Generator

`.claude/agents/migration-generator.md`:

```markdown
---
name: migration-generator
description: Generates safe, reversible database migrations for Elixir/Phoenix projects
tools: Read, Write, Bash, Grep, Glob
model: sonnet
---

You are a database migration expert specializing in Ecto migrations.

## Your Responsibilities

Generate safe, reversible database migrations that follow best practices.

## Migration Best Practices

1. **Always Reversible**:
   - Every `change/0` function must be reversible
   - Use `up/0` and `down/0` for complex changes
   - Test rollback scenarios

2. **Safe for Production**:
   - Add indexes concurrently on large tables
   - Avoid locking tables during migrations
   - Use multiple migrations for complex schema changes
   - Consider data migration separately from schema changes

3. **Naming Conventions**:
   - Use descriptive names: `add_email_to_users`, not `update_users`
   - Timestamp prefix (YYYYMMDDHHMMSS)
   - Verb-noun format

4. **Data Integrity**:
   - Add foreign key constraints
   - Set appropriate null constraints
   - Add check constraints for validation
   - Set default values when appropriate

## Migration Template

```elixir
defmodule MyApp.Repo.Migrations.AddEmailToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :email, :string, null: false
      add :email_verified, :boolean, default: false, null: false
    end

    create unique_index(:users, [:email])
  end
end
```

## Complex Migration Template

```elixir
defmodule MyApp.Repo.Migrations.CreateProjectsTable do
  use Ecto.Migration

  def up do
    create table(:projects) do
      add :name, :string, null: false
      add :description, :text
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :owner_id, references(:users, on_delete: :nilify_all)
      add :status, :string, null: false, default: "active"

      timestamps()
    end

    create index(:projects, [:workspace_id])
    create index(:projects, [:owner_id])
    create unique_index(:projects, [:workspace_id, :name])

    # Add check constraint
    create constraint(:projects, :valid_status,
      check: "status IN ('active', 'archived', 'deleted')")
  end

  def down do
    drop table(:projects)
  end
end
```

## Output

Generate migrations that:
- Follow Ecto conventions
- Are production-safe
- Include appropriate indexes
- Have proper constraints
- Are fully reversible
```

## Using Subagents

### Automatic Delegation

Claude Code automatically delegates tasks to appropriate subagents based on their descriptions. Just ask naturally:

```
"Review the code I just wrote"
→ Automatically uses code-reviewer agent

"Generate tests for the new shipping calculator"
→ Automatically uses test-generator agent
```

### Explicit Invocation

You can explicitly request a specific subagent:

```
"Use the doc-writer agent to document the Accounts context"
```

### Chaining Subagents

Subagents can invoke other subagents for complex workflows:

```
Main agent → test-generator → code-reviewer → doc-writer
```

## Best Practices

### 1. Focus Each Agent

Each subagent should have a single, clear responsibility:

- **Good**: "Generates Elixir tests following TDD principles"
- **Bad**: "Helps with testing, documentation, and refactoring"

### 2. Detailed System Prompts

Provide specific instructions, formats, and examples:

```markdown
---
name: my-agent
description: Brief description for Claude to understand when to use
---

Detailed system prompt with:
- Specific responsibilities
- Output format requirements
- Examples of good output
- Constraints and guidelines
- Project-specific conventions
```

### 3. Restrict Tool Access

Only grant tools the agent actually needs:

```markdown
---
tools: Read, Write, Grep  # Only what's necessary
---
```

Benefits:
- **Security**: Prevents unintended actions
- **Focus**: Agent stays on task
- **Performance**: Faster agent initialization

### 4. Choose the Right Model

- **haiku**: Fast, cheap, for simple tasks (quick searches, simple transformations)
- **sonnet**: Balanced, for most tasks (code review, test generation)
- **opus**: Most capable, for complex reasoning (architecture decisions, complex refactoring)

### 5. Version Control Project Agents

Store project-level agents in `.claude/agents/` and commit them:

```bash
git add .claude/agents/
git commit -m "Add custom subagents for project"
```

This allows your team to share specialized agents.

### 6. Test Your Agents

After creating an agent, test it with various scenarios:

```
# Test the agent explicitly
"Use the test-generator agent to create tests for MyModule"

# Verify it works with automatic delegation
"Generate tests for MyModule"
```

### 7. Iterate and Improve

Monitor agent performance and refine:

- Update system prompts based on output quality
- Adjust tool permissions as needed
- Add examples for common edge cases
- Incorporate team feedback

## Common Patterns

### Pattern 1: TDD Workflow Agent

Combines test generation and implementation:

```markdown
---
name: tdd-workflow
description: Implements features using strict TDD Red-Green-Refactor cycle
tools: Read, Write, Edit, Bash, TodoWrite
model: sonnet
---

You follow strict Test-Driven Development:

1. RED: Write a failing test first
2. GREEN: Write minimal code to pass
3. REFACTOR: Improve while keeping tests green

Workflow:
1. Create test file with failing test
2. Run test to verify it fails
3. Implement minimum code to pass
4. Run test to verify it passes
5. Refactor if needed
6. Repeat for next feature

Never write implementation before tests.
```

### Pattern 2: Architecture Validator

Enforces architectural boundaries:

```markdown
---
name: architecture-validator
description: Validates code changes against architectural boundaries and design principles
tools: Read, Grep, Glob, Bash
model: sonnet
---

You enforce architectural boundaries using the Boundary library.

Check for:
1. Web layer accessing contexts directly (forbidden)
2. Contexts accessing other contexts' internals (forbidden)
3. Direct Ecto queries outside infrastructure layer
4. Business logic in controllers/LiveViews

Run `mix boundary` to verify compliance.

Report violations with:
- File and line number
- Boundary rule violated
- Suggested fix
```

### Pattern 3: Refactoring Assistant

Safe refactoring with test verification:

```markdown
---
name: refactor-assistant
description: Performs safe refactoring operations with test verification
tools: Read, Write, Edit, Bash, Grep, Glob
model: sonnet
---

You perform safe refactoring:

1. Read existing code and tests
2. Verify tests pass before changes
3. Make incremental refactoring changes
4. Run tests after each change
5. Rollback if tests fail
6. Continue until complete

Refactoring types:
- Extract function/module
- Rename variables/functions
- Simplify conditionals
- Remove duplication
- Improve naming

Always keep tests green.
```

## Troubleshooting

### Agent Not Being Selected

**Problem**: Claude doesn't automatically use your agent

**Solutions**:
1. Make description more specific about when to use it
2. Explicitly request the agent by name
3. Check agent name doesn't conflict with built-in agents

### Agent Has Wrong Tools

**Problem**: Agent can't perform expected operations

**Solutions**:
1. Add necessary tools to `tools` field
2. Omit `tools` field to inherit all tools
3. Check tool names are spelled correctly

### Agent Output Not Helpful

**Problem**: Agent produces low-quality results

**Solutions**:
1. Provide more detailed system prompt with examples
2. Add output format specifications
3. Include constraints and guidelines
4. Consider using a more powerful model (sonnet or opus)

### Agent Too Slow

**Problem**: Agent takes too long to complete

**Solutions**:
1. Use `haiku` model for simple tasks
2. Restrict tools to only what's needed
3. Simplify the agent's responsibilities
4. Split into multiple focused agents

## Advanced Topics

### Dynamic Subagent Selection

Claude Code can intelligently select between multiple related agents based on context:

```
.claude/agents/
├── test-unit.md          # Pure unit tests
├── test-integration.md   # Database integration tests
└── test-e2e.md          # End-to-end LiveView tests
```

Asking "generate tests for this module" will select the appropriate test agent based on the module type.

### Subagent Composition

Create specialized agents that delegate to other agents:

```markdown
---
name: feature-builder
description: Builds complete features with tests, implementation, and documentation
tools: Task, TodoWrite
---

You orchestrate feature development:

1. Use test-generator agent to create tests
2. Use tdd-workflow agent to implement
3. Use doc-writer agent to document
4. Use code-reviewer agent to validate

Track progress with TodoWrite.
```

### Context-Aware Agents

Use project conventions in agent prompts:

```markdown
---
name: context-generator
description: Generates Phoenix contexts following project architecture
---

You generate Phoenix contexts following this project's architecture:

{{Read CLAUDE.md for architecture guidelines}}

- Enforce boundary constraints
- Separate domain logic from data access
- Create proper query objects
- Follow TDD approach
```

## Resources

- [Claude Code Documentation](https://code.claude.com/docs)
- [Subagents Official Guide](https://code.claude.com/docs/en/sub-agents.md)
- [Skills Documentation](https://code.claude.com/docs/en/skills.md)
- Project `CLAUDE.md` for project-specific guidelines

## Examples in This Project

Check `.claude/agents/` for project-specific subagents created for this codebase.
