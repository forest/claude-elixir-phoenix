# Plugin Improvement Analysis: Lessons from everything-claude-code

**Date**: 2026-02-28
**Source**: https://github.com/affaan-m/everything-claude-code (54.8K stars)
**Our Plugin**: elixir-phoenix v2.0.0 (20 agents, 37 skills, 4 hook types)

---

## Executive Summary

The `everything-claude-code` repo is a language-agnostic Claude Code plugin with 14 agents, 56 skills, 33 commands, and sophisticated lifecycle hooks. While much of it targets JavaScript/TypeScript/Go/Python workflows, several architectural patterns and features are directly applicable to improving our Elixir/Phoenix plugin.

**Top 5 recommendations** (ordered by impact):

1. Add PreToolUse hooks for dangerous operation blocking
2. Add debug statement detection hook (`IO.inspect`/`dbg()`)
3. Add `/phx:coverage` skill for ExUnit test coverage analysis
4. Add `/phx:checkpoint` skill for workflow milestones
5. Enhance `learn-from-fix` with automated session-end extraction

---

## Detailed Gap Analysis

### 1. PreToolUse Hooks — Blocking Dangerous Operations

**What they have**: PreToolUse hooks that block or warn before risky operations:
- Block `npm run dev` outside tmux (prevents orphan processes)
- Warn before `git push` (review changes first)
- Warn about writing non-standard doc files

**What we lack**: We only use PostToolUse hooks (format, compile, security reminder). We have no pre-execution safety gates.

**Recommended additions**:

```json
{
  "type": "PreToolUse",
  "matcher": "Bash",
  "script": "hooks/scripts/block-dangerous-ops.sh",
  "description": "Block mix ecto.reset, mix ecto.rollback --all, and force-push without confirmation"
}
```

Specific operations to gate:
- `mix ecto.reset` / `mix ecto.drop` — destructive database operations
- `git push --force` / `git push -f` — rewrite history
- `mix phx.gen.release --docker` overwriting existing Dockerfile
- `MIX_ENV=prod mix` commands in dev context

**Effort**: Low (single shell script + hooks.json entry)
**Impact**: High — prevents accidental data loss

---

### 2. Debug Statement Detection Hook

**What they have**: PostToolUse hook that warns about `console.log` left in code, plus a Stop hook that audits all modified files for debug statements.

**What we lack**: No detection of debug statements left in code.

**Recommended additions**:

PostToolUse hook scanning edited `.ex`/`.exs` files for:
- `IO.inspect` (outside test files)
- `dbg()` calls
- `IO.puts` in non-script contexts
- `Logger.debug` in production paths (context-dependent)
- `|> tap(&IO.inspect/1)` pipeline debugging

```bash
#!/bin/bash
# hooks/scripts/debug-statement-warning.sh
FILE="$CLAUDE_FILE"
if [[ "$FILE" == *_test.exs ]] || [[ "$FILE" == *test_helper* ]]; then
  exit 0
fi
if grep -nE '(IO\.inspect|dbg\(\)|IO\.puts)' "$FILE" 2>/dev/null; then
  echo "WARNING: Debug statements detected in $FILE. Remove before committing."
fi
```

**Effort**: Low
**Impact**: Medium — catches a common mistake

---

### 3. Test Coverage Skill (`/phx:coverage`)

**What they have**: `/test-coverage` command that detects framework, runs coverage, identifies gaps below 80%, generates missing tests, and shows before/after report.

**What we lack**: No test coverage analysis skill. Our `verify` skill runs tests but doesn't analyze coverage gaps.

**Recommended skill**: `/phx:coverage`

Workflow:
1. Run `mix test --cover` (built-in) or `mix coveralls` (if hex dep available)
2. Parse coverage output, identify files below threshold (configurable, default 80%)
3. Prioritize: untested modules > low-coverage modules > missing edge cases
4. For each gap: read the source, identify untested functions, generate test skeletons
5. Run tests to verify generated tests pass
6. Report before/after coverage metrics

Would use `testing` skill references and the `testing-reviewer` agent for quality checks.

**Effort**: Medium (new skill + references)
**Impact**: High — directly improves code quality

---

### 4. Checkpoint/Milestone Skill (`/phx:checkpoint`)

**What they have**: `/checkpoint` command that creates named snapshots (git stash/commit), logs them with timestamps, and can compare current state against any checkpoint.

**What we lack**: Our workflow tracks progress in `plans/{slug}/progress.md` but has no formal milestone/checkpoint system for long sessions.

**Recommended skill**: `/phx:checkpoint`

Integration with existing workflow:
- Auto-checkpoint at phase transitions (plan complete, work 50%, review complete)
- Named checkpoints: `checkpoint:pre-refactor`, `checkpoint:tests-passing`
- Compare command: show files changed, tests delta, coverage delta since checkpoint
- Stored in `plans/{slug}/checkpoints.log`

This fits naturally into our filesystem-as-state-machine architecture.

**Effort**: Low-Medium
**Impact**: Medium — valuable for long multi-session workflows

---

### 5. Enhanced Continuous Learning

**What they have**: A sophisticated 3-tier system:
- **Stop hook**: Evaluates every session (10+ messages) for extractable patterns
- **Instincts**: Atomic learned behaviors with confidence scores and triggers
- **Evolve command**: Clusters related instincts into skills/commands/agents

**What we have**: `learn-from-fix` skill (manual, invoked via `/phx:learn` after fixing bugs). Compound system captures solutions manually.

**Gap**: No automated pattern extraction. Learning requires explicit user invocation.

**Recommended enhancements**:

a) **Stop hook enhancement** — After checking pending plans, also scan for:
   - Iron Law violations that were caught and fixed (auto-compound)
   - Repeated patterns (same mix task run 3+ times → suggest alias)
   - Error resolution sequences worth preserving

b) **Session summary in scratchpad** — Before session ends, write key decisions/learnings to `plans/{slug}/scratchpad.md` (we already have scratchpad, but don't auto-populate it)

c) **Long-term**: `/phx:evolve` that analyzes solution docs in `.claude/solutions/` and identifies patterns that should become new Iron Laws or skill references

**Effort**: Medium-High
**Impact**: High — compounds value over time

---

### 6. Build Error Resolver Agent

**What they have**: Dedicated `build-error-resolver` agent specialized in diagnosing and fixing compilation errors.

**What we have**: `verification-runner` (haiku) runs compile/test but doesn't diagnose. `deep-bug-investigator` is for runtime bugs, not compile errors.

**Recommended addition**: Enhance `verification-runner` or create `compile-error-resolver` agent:

- Parse `mix compile --warnings-as-errors` output
- Categorize errors: missing module, type mismatch, undefined function, deprecation
- For each error type, apply known fix patterns (e.g., missing alias, wrong arity)
- Auto-fix simple errors (missing alias, unused variable warnings)
- Escalate complex errors with context

This would integrate with the existing PostToolUse `verify-elixir.sh` hook — when compilation fails, suggest delegating to this agent.

**Effort**: Medium
**Impact**: Medium-High — reduces debugging loops

---

### 7. Strategic Compaction Awareness

**What they have**: PreToolUse hook tracking tool call count, suggesting manual `/compact` every ~50 calls to prevent context exhaustion.

**What we have**: PreCompact hook that re-injects Iron Laws, but no proactive compaction suggestion.

**Recommended addition**: Add a counter to PostToolUse or PreToolUse:

```bash
# Track tool calls, suggest compaction at threshold
COUNTER_FILE=".claude/.tool-call-count"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"
if [ "$COUNT" -ge 50 ]; then
  echo "INFO: $COUNT tool calls this session. Consider running /compact to preserve context quality."
  echo "0" > "$COUNTER_FILE"
fi
```

**Effort**: Very low
**Impact**: Medium — prevents quality degradation in long sessions

---

### 8. Doc Sync Agent

**What they have**: `doc-updater` agent that automatically updates documentation when code changes.

**What we lack**: No dedicated agent for keeping `@moduledoc`, `@doc`, README, and typespecs in sync with implementation.

**Recommended addition**: Lightweight `doc-sync-reviewer` agent (sonnet):
- After code changes, check if `@moduledoc`/`@doc` still match implementation
- Verify `@spec` typespecs match function signatures
- Flag stale examples in documentation
- Can be triggered from `/phx:review` as an optional track

This would complement our existing `document` skill which generates docs but doesn't verify existing ones.

**Effort**: Medium
**Impact**: Medium

---

## Already Well-Covered (No Action Needed)

These areas from `everything-claude-code` are already well-handled by our plugin:

| Their Feature | Our Equivalent | Notes |
|--------------|----------------|-------|
| Planner agent | `planning-orchestrator` (opus) | Ours is more sophisticated with parallel research |
| Code reviewer | `parallel-reviewer` + 4 specialists | Ours has domain-specific reviewers |
| Security reviewer | `security-analyzer` (opus) + Iron Laws | Our Iron Laws system is more rigorous |
| TDD guide | `testing` skill + `testing-reviewer` | Well covered |
| Session management | Scratchpad + progress.md + resume detection | Different approach, equally effective |
| PreCompact state saving | `precompact-rules.sh` re-injects Iron Laws | Targeted rather than generic, but effective |
| Workflow orchestration | `workflow-orchestrator` (opus) | Full lifecycle support |
| Multi-language rules | N/A — we're domain-specific by design | Our depth > their breadth |

---

## Not Applicable

| Their Feature | Why Skip |
|--------------|----------|
| Language-specific reviewers (Go, Python, JS) | We're Elixir-only |
| PM2 multi-service orchestration | Phoenix runs as single BEAM node |
| npm/pnpm/yarn/bun detection | Not relevant to Mix ecosystem |
| Chief-of-Staff (email/Slack triage) | Personal productivity, not dev tooling |
| Business skills (investor materials, etc.) | Out of scope |
| Cross-platform Node.js hooks | Our bash hooks work fine for Elixir devs (macOS/Linux) |

---

## Implementation Priority Matrix

| # | Feature | Effort | Impact | Priority |
|---|---------|--------|--------|----------|
| 1 | PreToolUse dangerous ops blocking | Low | High | P0 |
| 2 | Debug statement detection hook | Low | Medium | P0 |
| 7 | Strategic compaction counter | Very Low | Medium | P0 |
| 3 | `/phx:coverage` test coverage skill | Medium | High | P1 |
| 6 | Build error resolver agent | Medium | Medium-High | P1 |
| 4 | `/phx:checkpoint` milestone skill | Low-Med | Medium | P2 |
| 5 | Enhanced continuous learning | Med-High | High | P2 |
| 8 | Doc sync reviewer agent | Medium | Medium | P3 |

**Recommended implementation order**: Start with P0 items (3 changes, all low effort, immediate value), then P1 (2 medium-effort features), then P2-P3 as time allows.

---

## Architectural Insight

The biggest philosophical difference: `everything-claude-code` emphasizes **self-improvement loops** (continuous learning → instincts → evolve → new skills). Our plugin emphasizes **domain depth** (Iron Laws, specialist agents, Elixir-specific patterns).

Both approaches have merit. The compound system (`/phx:compound`) is our version of continuous learning, but it's manual. Adding automated pattern extraction (even lightweight) would combine the best of both worlds: deep domain expertise that grows automatically from usage.
