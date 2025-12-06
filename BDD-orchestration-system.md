## BDD Orchestration System: Requirements Document

### Overview

We are building an autonomous development system where LLMs take a user story and produce working, tested software through a structured refinement process. The system begins with conversational requirements elicitation, produces a machine-verifiable PRD, and refines through features, scenarios, and implementation—each layer verifiable against the layer above it.

The only human intervention points are the initial conversation and final sign-off at each major stage.

**Core principle**: Refine until verifiable, then verify. At each layer, the system is either:
1. Breaking something abstract into something concrete
2. Running a check to see if it got it right
3. Backing up a level if it's stuck

Every artefact knows its parent. Trace links are maintained throughout so we can always answer: "Why does this code exist?" by walking back through scenarios, features, and PRD to the original user story.

---

### Value Proposition

**The fundamental problem this system solves**: Software accumulates "why does this exist?" debt rapidly. Developers leave, requirements documents rot, and within a few years, no one can confidently answer why a piece of code exists or what would break if it changed. This system makes that question answerable with auditable evidence, permanently.

#### Forward Mode: Greenfield Development

When building new software, the system provides:

- **Provable traceability**: Every line of production code traces back through scenarios, features, and PRD to the original user statement. Auditors, new team members, and future maintainers can follow the chain.

- **Structured LLM constraints**: LLMs are prone to drift, hallucination, and losing context. The verification gates catch errors before they compound. Containment checkers act as "type systems for requirements"—certain classes of mistakes become impossible.

- **Reduced human bottleneck**: Only three human touchpoints (initial conversation, PRD sign-off, final acceptance) versus constant back-and-forth in traditional development.

- **Self-correction loops**: When verification fails, structured feedback tells the LLM exactly what's wrong and how to fix it. Most failures resolve without human intervention.

#### Reverse Mode: Legacy Codebase Documentation

The system can run backwards on existing codebases to extract implicit requirements:

- **Requirement extraction**: Analyze existing code and tests to surface the requirements they implicitly satisfy. Make tacit knowledge explicit and auditable.

- **Refactoring safety**: Before a major refactor, extract the full requirement set from the current implementation. Use that as the specification for the new implementation. Prove the refactor preserved all behaviors—not just the ones covered by existing tests.

- **Dead code identification**: Code with no valid trace links to any requirement is provably dead. Remove it with confidence.

- **Impact analysis**: Given a proposed change, query "what depends on this?" and get back every requirement, scenario, and feature that would be affected.

#### Where This System Provides Most Value

- **Regulated industries**: Finance, healthcare, defense—anywhere auditors need to see why code exists and trace it to approved requirements.

- **Long-lived systems**: Products maintained for decades with inevitable team turnover. The trace chain survives personnel changes.

- **Safety-critical systems**: Where the cost of errors is high and proving correctness matters more than development speed.

- **Large codebase refactoring**: Where understanding what the current system actually does is prerequisite to changing it safely.

#### Where This System May Not Be Worth the Overhead

- **Exploratory work and MVPs**: When requirements genuinely can't be pinned down and speed matters more than auditability.

- **Small, short-lived projects**: The verification infrastructure cost exceeds the benefit for throwaway code.

---

### Target Architecture

```
User Story (conversational input)
  ↓ elicit via guided questions
PRD (structured, machine-verifiable)
  ↓ containment verification
  ↓ human sign-off
  ↓ decompose
Feature Files (.feature)
  ↓ containment verification
  ↓ decompose
Scenarios with Steps
  ↓ containment verification
  ↓ composition validation
Failing Tests (red)
  ↓ implement
Application Code
  ↓ trace verification
  ↓ verify
Passing Tests (green)
  ↓ human sign-off
  ↓ deploy
Production
```

---

### Current State

**What we have:**

- Cucumber for Elixir as the BDD framework
- LLM engineers writing scenarios and implementing code
- Custom step linter enforcing single responsibility steps
- Validity tests for stubs
- Duplicate step detection (built into Cucumber)
- Working flow from scenarios → steps → code → green tests

**What works well:**

- LLMs are effective at decomposing feature files into well-formed steps
- The test runner provides unambiguous pass/fail feedback
- Step linter catches common LLM mistakes before tests run

---

### What's Missing

#### 1. Requirements Elicitation Agent

**Problem**: PRDs must currently be written by humans. We want users to describe what they need conversationally and have an LLM produce a valid PRD.

**Required**: A conversational agent that:

**Conducts structured elicitation:**

The agent walks the user through a question sequence designed to extract everything needed for a complete PRD. The sequence adapts based on answers but ensures all required sections are covered.

**Question domains:**

- **Problem space**: What problem are you solving? Who experiences this problem? What happens if it's not solved?
- **User goals**: What should the user be able to accomplish? What does success look like from their perspective?
- **Capabilities**: What must the system do? What actions must users be able to take?
- **Error conditions**: What can go wrong? How should failures be handled? What edge cases exist?
- **Boundaries**: What is explicitly out of scope? What adjacent problems are we not solving?
- **Constraints**: Performance requirements? Security requirements? Compliance requirements?
- **Acceptance criteria**: How will we know this is done? What would a demo look like?

**Elicitation rules:**

- Never accept vague answers. Probe until concrete.
- Surface implicit assumptions by asking "What if X didn't happen?"
- Enumerate edge cases by asking "What's the worst case? The weird case?"
- Confirm understanding by reflecting back before moving on
- Track coverage of required PRD sections throughout

**Output**: A completed PRD in the structured template, ready for human sign-off.

---

#### 2. Structured PRD Template

**Problem**: PRDs must be machine-parseable so a constraint checker can validate them and feature decomposition can be automated.

**Required**: A formal PRD schema that is both human-readable and programmatically verifiable.

**Template structure:**

```
PRD: [identifier]
Version: [semver]
Status: [draft | review | approved]
Parent: [user-story-id or conversation-id]

---

Problem Statement:
  User: [who experiences the problem]
  Context: [when/where the problem occurs]
  Pain: [what happens if unsolved]

---

User Goal:
  Primary: [the main thing the user wants to accomplish]
  Success State: [what the world looks like when they've succeeded]

---

Capabilities:
  - ID: CAP-001
    Description: [what the system must do]
    Actor: [who initiates this]
    Trigger: [what causes this to happen]
    Outcome: [what state results]
    
  - ID: CAP-002
    ...

---

Error Handling:
  - ID: ERR-001
    Condition: [what goes wrong]
    Detection: [how we know it happened]
    Response: [what the system does]
    User Feedback: [what the user sees]
    
  - ID: ERR-002
    ...

---

Edge Cases:
  - ID: EDGE-001
    Scenario: [the unusual situation]
    Expected Behaviour: [what should happen]
    
  - ID: EDGE-002
    ...

---

Out of Scope:
  - [explicit boundary]
  - [explicit boundary]

---

Constraints:
  Performance:
    - [measurable requirement]
  Security:
    - [requirement]
  Compliance:
    - [requirement]

---

Acceptance Criteria:
  - ID: AC-001
    Given: [precondition]
    When: [action]
    Then: [observable outcome]
    
  - ID: AC-002
    ...

---

Trace:
  Conversation: [link to elicitation conversation]
  Signed Off By: [human identifier]
  Sign Off Date: [timestamp]
```

**Design principles:**

- Every item has an ID for traceability
- Acceptance criteria are already in Given/When/Then format (they become scenarios directly)
- Capabilities map to features
- Error handling and edge cases map to error scenarios
- Constraints map to non-functional test assertions

---

#### 3. PRD Constraint Checker

**Problem**: Before a PRD can be decomposed, we must verify it is internally consistent and complete.

**Required**: A programmatic validator that checks:

**Completeness rules:**

- All required sections are present and non-empty
- Every capability has at least one acceptance criterion that exercises it
- Every error condition has a defined response and user feedback
- At least one edge case is defined (forces thinking about boundaries)
- Out of scope section is non-empty (forces explicit boundaries)

**Consistency rules:**

- No capability contradicts another capability
- No acceptance criterion contradicts another
- Error responses don't conflict with success states
- Constraints are measurable (no "fast" or "secure" without numbers)

**Contradiction detection:**

Before decomposition, use an LLM to actively search for requirements that conflict:

- "What if CAP-003 and CAP-007 both trigger simultaneously? What wins?"
- "Does ERR-002's response contradict CAP-005's success state?"
- "Are there implicit ordering dependencies between capabilities?"

Surface contradictions before implementation rather than discovering them as bugs. The checker outputs:

```
CONTRADICTION WARNING: CAP-003 vs CAP-007

CAP-003 ensures: session.terminated
CAP-007 requires: session.active

If user triggers password reset (CAP-003) while in active workflow (CAP-007):
  - CAP-003 terminates session
  - CAP-007 cannot complete (requires active session)

Resolution required before decomposition.
Suggested: Add explicit priority or mutual exclusion rule.
```

**Traceability rules:**

- Every acceptance criterion references at least one capability or error condition
- No orphan capabilities (capabilities with no acceptance criteria)
- All IDs are unique within the document

**Decomposability rules:**

- Capabilities are atomic (one verb, one outcome)
- Acceptance criteria are concrete (specific values, not "appropriate" or "correct")
- Error conditions specify detection mechanism (can be tested)

**Output**: Pass with validated PRD, or fail with specific violations and their locations.

---

#### 4. PRD → Feature Decomposition Engine

**Problem**: No automated process to go from validated PRD to feature files.

**Required**: A decomposition module that:

**Generates features:**

- One feature file per capability (CAP-xxx)
- Feature description pulled from capability description
- Feature tagged with capability ID for traceability

**Generates scenarios:**

- Acceptance criteria (AC-xxx) become happy path scenarios directly (already in Given/When/Then)
- Error conditions (ERR-xxx) become error scenarios
- Edge cases (EDGE-xxx) become edge case scenarios
- Each scenario tagged with its source ID

**Generates constraint tests:**

- Performance constraints become benchmark scenarios
- Security constraints become security test scenarios
- Compliance constraints become compliance check scenarios

**Validates coverage:**

- Every CAP-xxx has at least one scenario
- Every ERR-xxx has at least one scenario
- Every EDGE-xxx has at least one scenario
- Every AC-xxx is represented in a scenario
- Reports coverage percentage and gaps

**Output**: Feature files with full traceability, or coverage report identifying gaps requiring PRD amendment.

---

#### 5. Semantic Step Library

**Problem**: Steps are defined with readable Cucumber patterns but lack semantic metadata. While LLMs can read step files to see available patterns, there is no structured way to query step capabilities, understand composition rules, or verify that step sequences satisfy scenario requirements.

**Required**: Step contracts derived directly from step implementations via Elixir macros. The step library is a reflection of the codebase, not a separate artifact to maintain.

**Step definition format:**

```elixir
defstep "I am logged in as a {role}" do
  @id "STEP-001"
  @type :setup
  @domain [:authentication, :user_management]
  
  requires [:user_exists]
  ensures [:user_authenticated, :session_active]
  
  conflicts_with ["I am logged out"]
  
  def execute(role) do
    # implementation
  end
end
```

**The macro extracts:**

- Contract (requires/ensures) for containment verification
- Type and domain for queryability
- Conflict declarations for linting
- Version hash of the contract for change detection

**Contract versioning:**

Steps evolve. When a step's requires/ensures change, the version hash changes. The system:

- Tracks which scenarios use which contract version
- Flags scenarios using outdated contract assumptions
- On contract change, identifies all affected scenarios for re-verification

```
CONTRACT VERSION CHANGE: STEP-042

Previous ensures: [reset_request.submitted, email.queued]
New ensures: [reset_request.submitted, email.queued, audit.logged]

Scenarios using previous version:
  - password_reset.feature:12 "User successfully resets password"
  - password_reset.feature:28 "User resets password from mobile"
  
Action: Re-run containment verification for affected scenarios.
```

**Query interface:**

- Find steps by domain
- Find steps by type
- Find steps matching a natural language intent
- Get composition suggestions given prior steps in a scenario
- Detect which scenarios use outdated contract versions

---

#### 6. Enhanced Step Linter

**Problem**: Current linter enforces single responsibility only.

**Required**: Extend the linter to validate composition rules:

- Setup steps must come before action steps
- Action steps must come before assertion steps
- Conflicting steps cannot appear in the same scenario
- Preconditions of each step must be satisfied by prior steps
- All steps must exist in the step library
- New steps are automatically added to the library

**Output**: Pass/fail with actionable error messages the LLM can use to self-correct.

---

#### 7. Code Traceability

**Problem**: Traceability currently stops at the step level. We cannot answer "which code implements this requirement?" or "why does this code exist?"

**Required**: A code annotation system that links implementation code to the steps it satisfies.

**Module-level tracing:**

```elixir
defmodule MyApp.PasswordReset do
  @trace [:STEP_042, :STEP_044]
  @moduledoc """
  Handles password reset flow via email.
  """
  
  # All public functions in this module inherit the module trace.
  # Private helpers inherit trace from their callers.
end
```

**Function-level tracing (public API boundaries only):**

```elixir
@trace [:STEP_042]
def request_reset(email) do
  # ...
end
```

**Special markers:**

- `@trace [:INFRASTRUCTURE]` — utility code not tied to a specific step
- `@trace [:GENERATED]` — code generated by framework/scaffolding
- `@trace [:PENDING, :STEP_XXX]` — placeholder awaiting step implementation

**Linter rules:**

- All modules must have a `@trace` attribute
- Public functions at API boundaries must have explicit `@trace` (not just inherited)
- Private functions inherit trace from their module or calling public function
- All trace links must reference valid step IDs
- Orphan modules (no valid trace links) generate warnings
- Invalid trace links (referencing non-existent steps) generate errors

**Trace analysis capabilities:**

- Forward trace: PRD → Features → Scenarios → Steps → Code
- Reverse trace: Code → Steps → Scenarios → Features → PRD
- Impact analysis: Given a PRD change, identify all affected code
- Orphan detection: Find code with no valid trace links
- Coverage report: Percentage of requirements with implementing code
- **"Why not" queries**: Given a proposed removal, show all dependencies

**"Why not" query interface:**

Essential for refactoring. Before removing or changing code, query the trace graph:

```
Query: why_not_remove(STEP-042)

STEP-042 "I submit the reset request" cannot be removed because:

Scenarios depending on this step:
  - password_reset.feature:12 "User successfully resets password"
  - password_reset.feature:28 "User resets password from mobile"
  - password_reset.feature:45 "Admin triggers password reset for user"

Features depending on these scenarios:
  - password_reset.feature @CAP-003

PRD capabilities depending on these features:
  - CAP-003 "User can reset password via email"

To remove STEP-042, you must first:
  1. Remove or modify the 3 scenarios using it
  2. Ensure CAP-003 is still satisfied by remaining scenarios
  3. Or: Remove CAP-003 from PRD (requires human sign-off)
```

This enables safe refactoring by making dependencies explicit before changes.

**LLM requirements:**

- When generating code, the LLM receives current step context from orchestrator
- The LLM must include appropriate trace comments in all generated code
- When modifying code, the LLM preserves or updates trace links as appropriate

---

#### 8. Containment Verification System

**Problem**: When decomposing from one layer to the next, we must prove that nothing is lost. All requirements in the PRD must be contained in the features. All behaviours in the features must be contained in the scenarios. All scenario behaviours must be contained in the steps.

**Required**: A verification system that proves containment at each layer transition, providing actionable feedback when decomposition is incomplete.

**Core principle**: At each layer transition, the children must subsume the parent:

```
Features ⊇ PRD requirements
Scenarios ⊇ Feature behaviours  
Steps ⊇ Scenario behaviours
Code ⊇ Step behaviours
```

---

**8.1 Unified Contract Model**

Predicates and contracts are unified into a single representation. A contract is simply predicates organized temporally—preconditions are predicates that must be true before, postconditions are predicates made true after.

**Contract format (used at all layers):**

```
Contract:
  id: [artifact identifier]
  requires: [predicates that must be true before]
  ensures: [predicates made true after]
```

**PRD capability as contract:**

```
CAP-003 "User can reset password via email":
  requires:
    - user.exists
    - user.has_email
  ensures:
    - password.is_reset
    - email.was_sent
```

**Feature as contract:**

```
password_reset.feature:
  requires:
    - user.exists
    - user.has_email
    - user.not_locked
  ensures:
    - password.is_reset
    - email.was_sent
    - audit.logged
```

**Step as contract (derived from step definition macro):**

```
STEP-042 "I request a password reset":
  requires:
    - page.is_reset_form
  ensures:
    - reset_request.submitted
    - email.queued
```

**Predicate normalization:**

- Predicates reduced to canonical form: `object.state` or `action(actor, object?, mechanism?)`
- Synonyms resolved to canonical terms (e.g., "authenticate" → "login")
- Implicit predicates expanded (e.g., "via email" → `requires_email`)
- Constrained vocabulary enforced where possible; unknown terms flagged for review

**Extraction method:**

- Structured fields (requires/ensures in step macros, PRD template fields) parsed directly
- Natural language descriptions parsed by LLM into contract form

---

**8.2 PRD → Feature Containment Checker**

**Input**: PRD contracts, Feature contracts with trace links

**Verification rules:**

1. **Ensures coverage**: Every PRD `ensures` predicate must appear in at least one feature
   ```
   ∀ p ∈ CAP.ensures: ∃ f ∈ Features: p ∈ f.ensures
   ```

2. **Contract subsumption**: Feature ensures must include all capability ensures
   ```
   ∀ cap ∈ Capabilities: 
     let f = feature_for(cap)
     f.ensures ⊇ cap.ensures
   ```

3. **No orphan features**: Every feature traces to a PRD item
   ```
   ∀ f ∈ Features: ∃ cap ∈ Capabilities: f.trace = cap.id
   ```

**Output on failure:**

```
CONTAINMENT FAILURE: PRD → Features

Missing ensures:
  - CAP-003.email.was_sent not found in any feature
  
Unsatisfied contract:
  - CAP-003 ensures "email.was_sent"
    Feature password_reset.feature does not guarantee this
    
Suggested fix: Add scenario to password_reset.feature that asserts email delivery
```

---

**8.3 Feature → Scenario Containment Checker**

**Input**: Feature contracts, Scenario contracts with trace links

**Verification rules:**

1. **Ensures coverage**: Every feature `ensures` predicate must appear in at least one scenario
   ```
   ∀ p ∈ Feature.ensures: ∃ s ∈ Scenarios: p ∈ s.ensures
   ```

2. **Behaviour coverage**: Every feature behaviour must be exercised
   - Happy path: At least one scenario exercises the success path
   - Error paths: Every ERR-xxx has at least one scenario
   - Edge cases: Every EDGE-xxx has at least one scenario

3. **Contract subsumption**: Combined scenario ensures cover feature ensures
   ```
   ∀ f ∈ Features:
     let scenarios = scenarios_for(f)
     ⋃(s.ensures for s in scenarios) ⊇ f.ensures
   ```

**Output on failure:**

```
CONTAINMENT FAILURE: Feature → Scenarios

Feature: password_reset.feature

Missing ensures coverage:
  - Predicate "reset_token_expires" not exercised by any scenario
  
Missing behaviour coverage:
  - ERR-004 (invalid email format) has no corresponding scenario
  
Suggested fix: Add scenario "User enters invalid email format" to cover ERR-004
```

---

**8.4 Scenario → Steps Containment Checker**

**Input**: Scenario as ordered Given/When/Then clauses, Step library with contracts

**Verification method**: Hoare-style verification by chaining step contracts

**Process:**

```
1. Initialize state = {}

2. For each step in scenario:
   a. Look up step in library, get requires/ensures
   b. Verify step.requires ⊆ current_state
   c. If requires not met, report error
   d. Add step.ensures to current_state

3. After all steps:
   a. Extract expected outcome from scenario's "Then" clause
   b. Verify expected_outcome ⊆ final_state
   c. If not satisfied, report missing ensures
```

**Example verification:**

```
Scenario: User successfully resets password

Given I am on the password reset page       # STEP-040
When I enter my email address               # STEP-041  
And I submit the reset request              # STEP-042
Then I should see a confirmation message    # STEP-043
And an email should be sent                 # STEP-044

Verification trace:
  {} 
    → STEP-040 → {page: reset_form}
    → STEP-041 → {page: reset_form, email: entered}
    → STEP-042 → {page: reset_form, email: entered, request: submitted}
    → STEP-043 → {page: reset_form, email: entered, request: submitted, message: shown}
    → STEP-044 → {page: reset_form, email: entered, request: submitted, message: shown, email: sent}
    
Expected outcome: {message: shown, email: sent}
Final state contains expected outcome: ✓ PASS
```

**Output on failure:**

```
CONTAINMENT FAILURE: Scenario → Steps

Scenario: User successfully resets password

Step chain breaks at STEP-042:
  Required: email.valid
  Current state: {page: reset_form, email: entered}
  Missing: email.valid
  
Suggested fix: Add validation step between STEP-041 and STEP-042
  Candidate: STEP-045 "the email address is valid"
```

---

**8.5 Steps → Code Containment Checker**

**Input**: Step library with ensures, Code with trace annotations

**Verification rules:**

1. **Implementation coverage**: Every step has implementing code
   ```
   ∀ step ∈ Steps_used: ∃ code ∈ Codebase: step.id ∈ code.trace_links
   ```

2. **Ensures satisfaction**: Code must produce step's ensures
   - This is verified by the test passing
   - Trace links allow us to identify which code is responsible if tests fail

**Output on failure:**

```
CONTAINMENT FAILURE: Steps → Code

Unimplemented steps:
  - STEP-044 "an email should be sent" has no implementing code
  
Suggested fix: Implement email sending functionality with trace link to STEP-044
```

---

**8.6 Verification Feedback Format**

All containment checkers produce structured feedback for LLM consumption:

```
ContainmentResult:
  status: pass | fail
  layer_transition: prd_to_features | features_to_scenarios | scenarios_to_steps | steps_to_code
  
  # On failure:
  failures:
    - type: missing_ensures | unsatisfied_requires | missing_implementation
      parent_artefact: [id]
      parent_element: [specific predicate]
      child_artefacts_checked: [ids]
      suggestion: [actionable fix description]
      candidate_fixes: [specific artefacts or steps that could resolve]
```

The LLM receives this structured feedback and can self-correct by:
- Adding missing scenarios or steps
- Revising decomposition to include dropped predicates
- Inserting intermediate steps to satisfy requires

---

#### 9. Orchestration Layer

**Problem**: No system manages the full refinement loop or handles failures intelligently.

**Required**: An event-driven orchestrator that reacts to state changes rather than polling in a loop. This makes the system easier to pause/resume, distribute across workers, and debug via event replay.

**Event model:**

```
Events:
  - artifact_created(type, id, parent_id)
  - artifact_modified(type, id, changes)
  - check_passed(checker, artifact_id)
  - check_failed(checker, artifact_id, failures)
  - human_signoff_requested(artifact_id, reason)
  - human_signoff_received(artifact_id, approved)
  - escalation_triggered(from_layer, to_layer, reason)

State:
  - Current layer (Elicitation, PRD, Feature, Scenario, Implementation)
  - Trace links between all artefacts
  - Attempt history (what's been tried, what failed)
  - Blocking flags (what's waiting on human input)
  - Event log (complete audit trail)
```

**Event handlers:**

```
on artifact_created:
  → run_relevant_checkers(artifact)
  
on check_passed:
  → if all_checks_passed_for_layer(artifact.layer):
      emit advancement_possible(artifact.layer, next_layer)
      
on check_failed:
  → emit fix_requested(artifact, failure.suggestion)
  → if max_retries_exceeded:
      emit escalation_needed(artifact, failure)
      
on advancement_possible:
  → if requires_human_signoff(next_layer):
      emit human_signoff_requested(artifact, "layer_transition")
  → else:
      begin_decomposition(artifact, next_layer)
      
on human_signoff_received:
  → if approved:
      resume_processing(artifact)
  → else:
      emit revision_requested(artifact, feedback)

on escalation_triggered:
  → log_escalation(from_layer, to_layer, reason)
  → if to_layer == :human:
      pause_and_notify()
  → else:
      reactivate_layer(to_layer)
```

**Benefits of event-driven model:**

- **Replayability**: Event log can be replayed to understand exactly what happened
- **Pausability**: System can pause at any point and resume from event state
- **Distributability**: Events can be processed by different workers
- **Debuggability**: Each state transition is explicit and logged

**Classifies failures:**

| Failure Type | Signal | Response |
|--------------|--------|----------|
| Implementation bug | Test fails, scenario correct | Fix code, retry |
| Missing scenario | Behaviour wrong despite green tests | Add scenario, re-implement |
| Containment failure | Checker reports missing predicates | Revise decomposition |
| Bad decomposition | Repeated containment failures | Escalate to parent layer |
| Incomplete PRD | Cannot generate valid features | Escalate to PRD, re-elicit |
| Ambiguous requirement | Constraint checker fails | Return to elicitation |
| Flaky environment | Intermittent failures | Retry with backoff |

**Enforces limits:**

- Maximum iterations per layer before mandatory escalation
- Maximum containment fix attempts before escalation
- No infinite loops
- Clear audit trail of all decisions

---

### Human Touchpoints

Humans are involved at exactly three points:

1. **Initial conversation** — user describes what they want, answers elicitation questions
2. **PRD sign-off** — user confirms the PRD captures their intent before implementation begins
3. **Final acceptance** — user confirms the working software meets their needs before deploy

Everything else is autonomous. The elicitation agent, constraint checker, containment verifiers, decomposition engine, step library, linter, and orchestrator operate without human intervention.

---

### Verification Chain Summary

Each transition has programmatic verification:

| Transition | Verification Method | Technique |
|------------|---------------------|-----------|
| Conversation → PRD | Constraint checker | Schema validation, completeness rules |
| PRD → Features | Containment checker | Predicate coverage, contract subsumption |
| Features → Scenarios | Containment checker | Predicate coverage, behaviour coverage |
| Scenarios → Steps | Containment checker | Hoare-style contract chaining |
| Steps → Code | Trace checker + tests | Graph coverage, test execution |
| Code → Deploy | All above + green tests | Full verification chain |

If any verification fails, the system knows exactly which layer to revisit, what is missing, and can suggest specific fixes.

---

### The Complete Trace Chain

Every line of production code answers "Why do I exist?" with evidence:

```
User Statement (in elicitation)
  ↓ "I need users to be able to reset their password"
PRD Capability (CAP-003)
  ↓ requires: user.exists, user.has_email
  ↓ ensures: password.is_reset, email.was_sent
Feature (password_reset.feature @CAP-003)
  ↓ ensures: ⊇ CAP-003.ensures ✓
Scenario (user resets password successfully @AC-007)
  ↓ ensures: ⊇ feature.ensures ✓
Step Sequence (STEP-040 → STEP-041 → STEP-042 → STEP-043 → STEP-044)
  ↓ contract chain satisfies scenario outcome ✓
Code Block
  ↓ @trace [:STEP_042, :STEP_044]
Function: send_password_reset_email/1
```

**Audit queries enabled:**

- "Why does this function exist?" → Trace up to user statement
- "What code implements CAP-003?" → Trace down to all linked functions
- "If we remove email-based reset, what changes?" → Impact analysis via trace links
- "Why can't I remove STEP-042?" → "Why not" query shows all dependencies
- "Is there dead code?" → Find code with no valid trace links
- "Are all requirements implemented?" → Forward containment verification

---

### Success Criteria

The system is complete when:

1. A user can describe a need in conversation and receive working, deployed software
2. The only human judgments are "yes this PRD captures what I want" and "yes this software does what I need"
3. Every piece of code traces back through scenarios, features, and PRD to the original conversation
4. Containment is verified at every layer transition—nothing is lost in decomposition
5. Failures are diagnosed and either fixed or escalated without human prompting
6. The step library grows organically as new domains are covered
7. PRDs that pass the constraint checker always produce valid, complete feature decompositions

---

### Suggested Build Order

**Phase 1: Foundation**

1. PRD template schema — define the formal structure, build a parser
2. Unified contract model — parse artefacts into requires/ensures contracts
3. Step definition macro — `defstep` with requires/ensures/conflicts_with, contract versioning

**Phase 2: Verification**

4. PRD constraint checker — completeness, consistency, decomposability rules, contradiction detection
5. PRD → Feature containment checker — ensures coverage and contract subsumption
6. Feature → Scenario containment checker — behaviour coverage verification
7. Scenario → Steps containment checker — Hoare-style contract chaining

**Phase 3: Infrastructure**

9. Step library reflection — auto-generate library from `defstep` macros, query interface
10. Enhanced step linter — composition rules, conflict detection, contract version tracking
11. Code trace linter — module-level @trace, API boundary enforcement, "why not" queries

**Phase 4: Decomposition**

12. PRD → Feature decomposition engine — generate features with containment verification
13. Elicitation agent — question flow, output to PRD template

**Phase 5: Orchestration**

15. Event system — define events, event log, replay capability
16. Event handlers — wire checkers to events, implement escalation logic
17. Feedback formatting — structured output for LLM self-correction