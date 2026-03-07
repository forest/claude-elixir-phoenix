---
name: phx:review
description: Review code with parallel specialist agents covering tests, security, Ecto, LiveView, and Oban patterns. Use after any implementation to catch bugs, security vulnerabilities, and anti-patterns before committing. Even quick changes benefit from at least a targeted review track.
argument-hint: [test|security|oban|deploy|iron-laws|all]
disable-model-invocation: true
---

# Review Elixir/Phoenix Code

Review code by spawning parallel specialist agents. Find and
explain issues — do NOT create tasks or fix anything.

## Usage

```
/phx:review                          # Review all changed files
/phx:review test                     # Review test files only
/phx:review security                 # Run security audit only
/phx:review oban                     # Review Oban workers only
/phx:review deploy                   # Validate deployment config
/phx:review iron-laws                # Check Iron Law violations only
/phx:review .claude/plans/auth/plan.md    # Review implementation of plan
```

## Arguments

`$ARGUMENTS` = Focus area or path to plan file.

## Workflow

### Step 1: Identify Changed Files and Prepare Directories

```bash
# CRITICAL: Create output dirs BEFORE spawning agents — agents
# cannot create directories and will fail repeatedly on writes
SLUG="$(basename "$(ls -td .claude/plans/*/ 2>/dev/null | head -1)" 2>/dev/null || echo "review")"
mkdir -p ".claude/plans/${SLUG}/reviews" ".claude/plans/${SLUG}/summaries"

# If no plan context, use fallback directory
mkdir -p .claude/reviews

git diff --name-only HEAD~5   # Recent changes
git diff --name-only main     # Or changes from main
```

### Step 1b: Load Plan Context (Scratchpad)

If reviewing a plan, read `.claude/plans/${SLUG}/scratchpad.md` for
planning decisions, rationale, and handoff notes. Include relevant
decisions in each agent's prompt so they have context about WHY
code was written a certain way. This eliminates session archaeology.

### Step 1c: Check Prior Reviews

If `.claude/plans/${SLUG}/reviews/` has prior output, include consolidated
summary in each agent's prompt as "PRIOR FINDINGS" with instruction:
"Focus on NEW issues. Mark still-present issues as PERSISTENT."

### Step 2: Create Task List and Spawn Review Agents (MANDATORY)

**NEVER spawn the same agent role twice in one review.** If reviewing
a plan, scope ALL agents to the plan's changed files in a single pass.
Do NOT run a scoped review followed by a broader review — one pass per role.

**Create Claude Code tasks** for each review agent BEFORE spawning.
This gives real-time progress visibility:

```
For each agent to spawn:
  TaskCreate({
    subject: "{Agent Name} review",
    description: "Review changed files for {focus area}",
    activeForm: "Running {Agent Name}..."
  })
  TaskUpdate({taskId, status: "in_progress"})
```

Then spawn agents using the Agent tool. Do NOT analyze code
yourself — delegate to agents.

**For `/phx:review` or `/phx:review all` — spawn ALL 5 in ONE
message (parallel).** Use these EXACT subagent_type values:

| Agent | subagent_type |
|-------|---------------|
| Elixir Reviewer | `elixir-phoenix:elixir-reviewer` |
| Testing Reviewer | `elixir-phoenix:testing-reviewer` |
| Security Analyzer | `elixir-phoenix:security-analyzer` |
| Verification Runner | `elixir-phoenix:verification-runner` |
| Iron Law Judge | `elixir-phoenix:iron-law-judge` |

Spawn ALL agents with `mode: "bypassPermissions"` and
`run_in_background: true` — background agents cannot answer
interactive Bash permission prompts.

**For focused reviews — spawn the specified agent only:**

| Argument | subagent_type |
|----------|---------------|
| `test` | `elixir-phoenix:testing-reviewer` |
| `security` | `elixir-phoenix:security-analyzer` |
| `oban` | `elixir-phoenix:oban-specialist` |
| `deploy` | `elixir-phoenix:deployment-validator` |
| `iron-laws` | `elixir-phoenix:iron-law-judge` |

Zero agents spawned = skill failure.

### Step 3: Collect and Compress Findings

Wait for ALL agents to FULLY complete. **Do NOT report status
until every agent completes.** Mark each agent's Claude Code task
as `completed` via `TaskUpdate` as it finishes.

**Verification-runner fallback**: If it fails/times out, run directly:
`mix compile --warnings-as-errors && mix format --check-formatted $(git diff --name-only HEAD~5 | grep '\.exs\?$' | tr '\n' ' ') && mix credo --strict && mix test`

**For full reviews (5 agents):** Spawn `elixir-phoenix:context-supervisor` to compress output:

```
Prompt: "Compress review agent output.
  input_dir: .claude/plans/{slug}/reviews
  output_dir: .claude/plans/{slug}/summaries
  output_file: review-consolidated.md
  priority_instructions: BLOCKERs and WARNINGs: KEEP ALL.
    SUGGESTIONs: COMPRESS similar ones into groups.
    Deconfliction: when iron-law-judge and elixir-reviewer
    flag same code, keep iron-law-judge finding."
```

**For focused reviews (1 agent):** Skip supervisor, read
agent output directly.

### Step 4: Generate Review Summary

Read the consolidated summary (full review) or agent output
(focused review). Write to `.claude/plans/{slug}/reviews/{feature}-review.md`
with verdict: PASS | PASS WITH WARNINGS | REQUIRES CHANGES | BLOCKED.

### Step 5: Present Findings and Ask User

**STOP and present the review.** Do NOT create tasks or fix
anything.

**On BLOCKED or REQUIRES CHANGES**: Show finding count by
severity, then offer concrete options via `AskUserQuestion`:

- **Triage first** — `/phx:triage` to convert findings to tasks (recommended)
- **Replan fixes** — `/phx:plan .claude/plans/{slug}/reviews/{file}.md`
- **Fix directly** — fix blockers now in this session
- **Handle myself** — I'll take it from here

Example: "Review complete — 3 blockers, 5 warnings, 2 suggestions.
Recommend triaging first to prioritize."

**On PASS / PASS WITH WARNINGS**: Suggest `/phx:compound`,
`/phx:document`, `/phx:learn`. If warnings reveal scope gaps,
also suggest: `/phx:plan .claude/plans/{slug}/reviews/{file}.md`
to create a follow-up plan from review findings.

## Iron Laws

1. **Review is READ-ONLY** — Find and explain, never fix
2. **NEVER auto-fix after review** — Always ask the user first
3. **Always offer both paths**: `/phx:plan` and `/phx:work`
4. **Research before claiming** — Agents MUST research before
   making claims about CI/CD or external services

## Integration with Workflow

```text
/phx:plan → /phx:work
       ↓
/phx:review  ← YOU ARE HERE (findings only, no tasks)
       ↓
   Blocked? → /phx:triage, /phx:plan, or /phx:work
   Pass    → /phx:compound (capture solutions)
```

## References

- `references/review-template.md` — Full review template format
- `references/example-review.md` — Example review output
- `references/blocker-handling.md` — Severity classification
