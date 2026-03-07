---
name: phx:full
description: Full Phoenix feature development cycle — plan, implement, review, and compound in one command. Use for large features spanning multiple contexts, new domain modules, or when the user wants an autonomous end-to-end implementation with specialist agents and Iron Laws enforcement.
argument-hint: <feature description>
---

# Full Phoenix Feature Development

Execute complete Elixir/Phoenix feature development autonomously: research patterns,
plan with specialist agents, implement with verification, Elixir code review.
Cycles back automatically if review finds issues.

## Usage

```
/phx:full Add user authentication with magic links
/phx:full Real-time notification system with Phoenix PubSub
/phx:full Background job processing for email campaigns --max-cycles 5
```

## Workflow Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                       /phx:full {feature}                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  │
│  │Discover│→ │  Plan  │→ │  Work  │→ │ Verify │→ │ Review │→ │Compound│→Done│
│  │ Assess │  │[Pn-Tm] │  │Execute │  │  Full  │  │4 Agents│  │Capture │     │
│  │ Decide │  │ Phases │  │ Tasks  │  │  Loop  │  │Parallel│  │ Solve  │     │
│  └───┬────┘  └────────┘  └────────┘  └───┬────┘  └────────┘  └────────┘     │
│       │                            ↑      │    ↑              │         │
│       ├── "just do it" ────────────┤      │    │              │         │
│       ├── "plan it" ──┐            │      ↓    │              │         │
│       │               ↓            │ ┌────────┐│              │         │
│       │     ┌──────────────┐       │ │Fix     ││ ┌─────────┐ │         │
│       │     │   PLANNING   │       │ │Issues  │└─│ Fix     │←┘         │
│       │     └──────────────┘       │ └───┬────┘  │ Review  │           │
│       │                            │     ↓       │ Findings│           │
│       │                       ┌────┴─────────┐   └────┬────┘           │
│       │                       │   VERIFYING   │←──────┘                │
│       └── "research it" ─────┘  (re-verify)                            │
│            (comprehensive plan)                                         │
│                                                                  │
│  On Completion:                                                  │
│  Auto-compound: Capture solved problems → .claude/solutions/     │
│  Auto-suggest: /phx:document → /phx:learn                       │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## State Machine

```
STATES: INITIALIZING → DISCOVERING → PLANNING → WORKING →
        VERIFYING → REVIEWING → COMPLETED → COMPOUNDING | BLOCKED
```

Track state in `.claude/plans/{slug}/progress.md` AND via Claude Code
tasks. Create one task per phase at start, mark `in_progress` on
entry and `completed` on exit:

```
TaskCreate({subject: "Discover & assess complexity", activeForm: "Discovering..."})
TaskCreate({subject: "Plan feature", activeForm: "Planning..."})
TaskCreate({subject: "Implement tasks", activeForm: "Working..."})
TaskCreate({subject: "Verify implementation", activeForm: "Verifying..."})
TaskCreate({subject: "Review with specialists", activeForm: "Reviewing..."})
TaskCreate({subject: "Capture solutions", activeForm: "Compounding..."})
```

Set up `blockedBy` dependencies between phases (sequential).

On COMPLETED: auto-run COMPOUNDING phase to capture solved problems as searchable
solution docs in `.claude/solutions/`. Then suggest `/phx:document` for docs and
`/phx:learn` for quick pattern capture.

## Cycle Limits

| Setting | Default | Description |
|---------|---------|-------------|
| `--max-cycles` | 10 | Max plan→review cycles |
| `--max-retries` | 3 | Max retries per task |
| `--max-blockers` | 5 | Max blockers before stopping |

When limits exceeded, output INCOMPLETE status with remaining work and recommended action.

## Integration

```text
/phx:full = /phx:plan → /phx:work → /phx:verify → /phx:review → (fix → /phx:verify) → /phx:compound
```

For fully autonomous execution with Ralph Wiggum Loop:

```bash
/ralph-loop:ralph-loop "/phx:full {feature}" --completion-promise "DONE" --max-iterations 50
```

## Iron Laws

1. **NEVER skip verification** — Every task must pass `mix compile --warnings-as-errors` + `mix test` before moving to the next. Skipping compounds errors across tasks
2. **Respect cycle limits** — When `--max-cycles` is exhausted, STOP with INCOMPLETE status. Do not continue indefinitely hoping the next fix works
3. **One state transition at a time** — Follow the state machine strictly. Never jump from PLANNING to REVIEWING — each state produces artifacts the next state needs
4. **Discover before deciding** — Always run DISCOVERING phase to assess complexity. Skipping it for "simple" features leads to underplanned implementations
5. **Agent output is findings, not fixes** — Review agents report issues. Only the WORKING state makes code changes

## References

- `references/execution-steps.md` — Detailed step-by-step execution
- `references/example-run.md` — Example full cycle run
- `references/safety-recovery.md` — Safety rails, resume, rollback
- `references/cycle-patterns.md` — Advanced cycling strategies
