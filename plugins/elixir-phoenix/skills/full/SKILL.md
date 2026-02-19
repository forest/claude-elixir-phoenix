---
name: phx:full
description: Full Phoenix feature development cycle. Runs plan → work → review with Elixir specialist agents, Iron Laws, and mix verification. Cycles until complete.
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

TRANSITIONS:
  INITIALIZING → DISCOVERING (always)
  DISCOVERING → PLANNING ("research it" or "plan it")
  DISCOVERING → WORKING ("just do it" - LOW complexity only)
  PLANNING → WORKING (plan file complete)
  WORKING → VERIFYING (all tasks done OR blocker limit)
  VERIFYING → VERIFYING (issues found, fix and re-verify)
  VERIFYING → REVIEWING (all checks pass)
  REVIEWING → VERIFYING (review issues fixed, re-verify)
  REVIEWING → COMPLETED (no critical issues)
  ANY → BLOCKED (max cycles OR fatal error)
```

Track state in `.claude/plans/{slug}/progress.md` (plan checkboxes + progress log).

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

## References

- `references/execution-steps.md` — Detailed step-by-step execution
- `references/example-run.md` — Example full cycle run
- `references/safety-recovery.md` — Safety rails, resume, rollback
- `references/cycle-patterns.md` — Advanced cycling strategies
