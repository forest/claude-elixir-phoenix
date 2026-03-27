# OMC Patterns — Deep Analysis

Source: [github.com/Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) (90k+ lines TypeScript)

## Overview

oh-my-claudecode is a massive general-purpose Claude Code enhancement framework. Most of its infrastructure (model routing, team management, tmux workers) is general orchestration we already have Elixir-specific versions of. But 3 patterns are genuinely novel and directly applicable.

## 1. AI Slop Cleaner

### The Problem It Solves

AI-generated code accumulates "slop" — technically correct but unnecessary code that bloats the codebase:
- Dead code paths (handle_event clauses that can never trigger)
- Needless abstractions (a `HelperUtils` module wrapping one function)
- Duplicate logic (same validation in 3 places)
- Over-engineering (GenServer for what should be a plain function)
- Missing tests (added code with no coverage)

### 5-Category Classification System (verified from SKILL.md)

| Category | Description | Phoenix Examples |
|----------|-------------|-----------------|
| **Duplication** | Repeated logic, copy-paste branches, redundant helpers | Identical changeset validations in create/update |
| **Dead Code** | Unused exports, unreachable branches, stale debug code | `handle_event` for removed buttons, unused context functions |
| **Needless Abstraction** | Pass-through wrappers, speculative indirection, single-use layers | `UserHelpers.get_user(id)` that just calls `Repo.get(User, id)` |
| **Boundary Violations** | Hidden coupling, misplaced responsibilities, wrong-layer imports | Database queries in LiveView `render/1` |
| **Missing Tests** | Unprotected behavior, weak regression coverage | New context function with no test |

### 4-Pass Ordered Cleanup (verified)

Core principle: "Lock behavior with focused regression tests first whenever practical." Deletion-first, small-diff, reversible pattern.

```
Pass 1: DEAD CODE DELETION (safest first)
  → Identify and remove unreachable code
  → Run quality gates: regression tests, linting, type checking

Pass 2: DUPLICATE REMOVAL
  → Consolidate repeated logic
  → Run quality gates

Pass 3: NAMING & ERROR-HANDLING REFINEMENT
  → Clean up naming, fix error handling patterns
  → Run quality gates

Pass 4: TEST REINFORCEMENT
  → Add missing test coverage for remaining code
  → Full verification suite
```

**Quality Gates (all passes):** regression tests, linting, type checking, unit/integration tests, static/security checks. Failed gates trigger **rollback** — never forced acceptance.

### Writer/Reviewer Separation (`--review` mode)

The slop cleaner has a `--review` mode where it only IDENTIFIES slop without cleaning it. This separation is important:
- Writer mode: finds AND cleans (autonomous)
- Review mode: finds and REPORTS (human decides)

### What This Means for Us

A `/phx:deslop` skill would be valuable after any substantial implementation phase. Phoenix/LiveView code gets bloated fast with AI:
- Extra `handle_event` clauses nobody asked for
- Redundant assigns that could be computed
- Wrapper functions around `Repo` calls
- Over-abstracted contexts (5 functions where 2 would do)
- GenServer wrappers around stateless operations

The 4-pass workflow is especially important because it PROTECTS before CLEANING — preventing the common failure mode where cleanup introduces regressions.

## 2. Skill Learner

### The Problem It Solves

Debugging sessions produce valuable insights that are lost when the session ends. Example: "In this project, Ecto custom types with `load/1` always need `equal?/2` overridden because of how Phoenix.HTML.Safe protocol dispatch works." This is hard-won knowledge that took 2 hours to discover, but it's trapped in one session.

### Quality Gates (verified from SKILL.md — ALL 4 must pass)

1. **Non-Googleable** — "Could someone Google this in 5 minutes?" → NO. Must include actual file paths and error messages from THIS project
2. **Codebase-Specific** — "Is this specific to THIS codebase?" → YES. Must reference actual codebase artifacts
3. **Actionable with Precision** — specifies exactly WHAT to do and WHERE in this codebase
4. **Hard-Won** — "Did this take real debugging effort to discover?" → YES. Significant investigation effort required

### Extraction Triggers (when to save)

- After solving tricky bugs requiring deep investigation
- After discovering non-obvious workarounds unique to the project
- After finding hidden gotchas that waste time when overlooked
- After uncovering undocumented behavior affecting the project

### Rejected Anti-Patterns (explicitly excluded)

- Generic programming patterns
- Refactoring techniques
- Library usage examples
- Type definitions or boilerplate
- Content junior developers could quickly research

### Saved Skill Structure (verified template)

```markdown
# Learned: {Title}

## The Insight
{Underlying principle, not just code}

## Why This Matters
{Symptoms and consequences if ignored}

## Recognition Pattern
{When to apply this knowledge}

## The Approach
{Decision-making heuristic}

## Example (optional)
{Code illustration from this project}
```

**Storage:** Project-level at `.omc/skills/` (default, version-controlled).
Key distinction: "Expertise updates during improvement; workflow remains stable."

### Distinction from Our /phx:compound

| Aspect | /phx:compound | Skill Learner |
|--------|---------------|---------------|
| Captures | Fix documentation (what was broken, what fixed it) | Mental models and heuristics |
| Scope | Problem → solution | Pattern → when to apply |
| Structure | YAML frontmatter solution doc | Project-scoped skill |
| Storage | `.claude/solutions/` | `.claude/skills/learned/` |
| Use | Search when debugging similar issues | Auto-loaded when editing related code |

### What This Means for Us

We already have `/phx:learn` reserved but unimplemented. The skill learner pattern fills the gap between:
- Iron Laws (universal rules) → too broad
- Compound docs (specific fixes) → too narrow
- Learned skills (project-specific heuristics) → just right for "how this particular codebase works"

## 3. Lab Notebook / Notepad Wisdom

### The Problem It Solves

Long sessions accumulate decisions, dead-ends, and context that gets lost during compaction or session boundaries. The scratchpad exists but is unstructured.

### OMC's Approach: Structured Sections

OMC's `notepad-wisdom` feature maintains a structured log:

```markdown
## Session: 2026-03-27T10:00

### Hypotheses Tested
1. ✅ Form reset issue caused by missing hidden_input for embedded schema
2. ❌ Thought it was a changeset casting issue — disproved by tracing

### Dead Ends (DO NOT RETRY)
- Tried `force_change/2` on all embedded fields — created worse regression
- Tried custom `prepare_changes` callback — Ecto doesn't support it for embeds

### Decisions Made
- Will use hidden_input pattern (Iron Law #19) instead of custom changeset logic
- Chose to fix at the template level, not the schema level

### Open Questions
- Does this pattern work with nested embeds? (untested)
- Performance impact of hidden_input on large forms? (unknown)

### Handoff Notes
- Branch: fix/embedded-form-reset
- Status: fix works for single-level embeds, needs testing for nested
- Next step: write test for nested embed case
```

### Key Insight: "Dead Ends" Section

The most valuable part is the **Dead Ends** section. Without it:
1. Next session/agent tries the same failed approach
2. Wastes time rediscovering it doesn't work
3. May even introduce the regression again

With it:
1. Next session reads "DO NOT RETRY: force_change on embeds causes regression"
2. Skips directly to the working approach
3. Saves 30-60 minutes per resumed session

### What This Means for Us

Our `scratchpad.md` needs structure. Currently it's freeform notes. Adding explicit sections would:
- Prevent debugging loops on session resume (Dead Ends section)
- Enable better compaction (structured content compresses better)
- Support the verifier (Hypotheses Tested shows what was actually verified vs. assumed)
- Improve handoff between sessions (Handoff Notes section)

## 4. Other Notable OMC Patterns

### Context Injector
OMC injects relevant context from previous sessions based on file being edited. When you open `user_controller.ex`, it automatically loads any session notes about user controllers from the last 7 days.

**Applicability:** Medium. Could enhance our skill auto-loading with session-specific context.

### Deep Dive 3-Point Injection
OMC's deep dive runs 3 parallel investigation lanes, then "injects" findings into a planning session through 3 specific insertion points (problem statement, constraints, solution space). This prevents investigation results from being dumped unstructured into the plan.

**Applicability:** High. Our investigate → plan handoff could use structured injection points.

### Model Routing with Complexity Scoring
OMC scores task complexity and routes to Haiku/Sonnet/Opus dynamically. Our agent frontmatter sets model statically. Dynamic routing could save cost on simple verifications while using Opus for complex ones.

**Applicability:** Low priority. Our static model assignment is simpler and more predictable. Could revisit if costs become an issue.

### Writer Memory (Korean creative writing)
Domain-specific. Not applicable.

### Visual Verdict (Screenshot comparison)
Screenshot-to-reference comparison with JSON scoring. Loops until score > 90.

**Applicability:** Medium for LiveView UI work. Would need browser automation MCP integration.
