# Plugin Improvement Analysis: Competitive Landscape Review

**Date**: 2026-03-01
**Sources**:
- https://github.com/affaan-m/everything-claude-code (54.8K stars)
- https://github.com/blader/theorist (strategic memory skill)
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

---

# Part 2: Lessons from Theorist (Strategic Memory)

**Source**: https://github.com/blader/theorist

## What Theorist Does

Theorist is a single-file Claude Code skill that maintains `THEORY.MD` at the repo root — a living narrative document capturing the **operating theory** behind ongoing work. It's not a task log, changelog, or plan. It's the answer to: "What does this project understand about itself?"

The document has five sections:
1. **Problem thesis** — structural reason the problem exists
2. **Operating theory** — mental model of how the system works
3. **Strategic rationale** — higher-order approach connecting changes
4. **Key discoveries and pivots** — moments where understanding shifted
5. **Open questions** — uncertainties and where the theory might be wrong

Key behaviors:
- **Always-on**: Activates every session, reads silently for orientation
- **Holistic rewrites**: Rewrites the whole document (never appends), keeping it coherent
- **Intelligence-triggered**: Updates when understanding shifts, not when code changes
- **~200 lines max**: Forces distillation, not accumulation
- **Refreshes every ~10 minutes** of active work or after investigation→implement→verify loops

## Gap Analysis: Our Context System vs Living Theory

### What We Already Have (Building Blocks)

| Artifact | Purpose | Limitation |
|----------|---------|------------|
| `plans/{slug}/scratchpad.md` | DECISION, DEAD-END, HANDOFF entries | Append-only, unindexed, per-plan |
| `plans/{slug}/progress.md` | Phase status, verification results | Activity log, not understanding |
| `plans/{slug}/plan.md` | Checkbox state (what to do) | No "why" beyond inline notes |
| `.claude/solutions/` | Solved problems (compound knowledge) | Individual docs, no meta-patterns |
| PreCompact hook | Re-injects Iron Laws before compaction | Rules only, not project context |
| SessionStart `check-resume.sh` | Finds resumable plans | Shows checkboxes, not strategy |

### What's Missing: Strategic Understanding Layer

**Gap 1: Decisions are captured but theory is not.**
Our scratchpad records "Use Oban for email processing" with rationale. But it doesn't capture the project-level pattern: "We ALWAYS use Oban for async work because..." — meaning each new feature re-litigates the same architectural choice.

**Gap 2: Scratchpad is append-only, not indexed.**
No cross-reference between decisions across plans. Can't ask "show me all places where we chose Streams over assigns." Dead-ends are buried in individual plan scratchpads.

**Gap 3: No cross-solution meta-patterns.**
We have 15 individual solution docs in `solutions/ecto-issues/` but no synthesis: "Across all our Ecto solutions, the root cause is usually X, and the pattern is Y."

**Gap 4: Session orientation reads checkboxes, not context.**
When resuming, the SessionStart hook shows: "Plan 'user-auth' has 5 remaining tasks." It doesn't show: "This project uses Pow + Ueberauth for auth, has learned that Ecto.Multi is too rigid for registration, and the OAuth token refresh is still incomplete."

**Gap 5: No evolving "what this project understands" artifact.**
We have what-to-do (plan), what-happened (progress), what-went-wrong (dead-ends), and what-we-solved (solutions). We're missing: **what we understand** — the living mental model.

## Recommendation: `/phx:theory` Skill + `THEORY.md` Artifact

### Design

A new skill that maintains `.claude/THEORY.md` as a living strategic context document. Unlike Theorist's generic approach, ours would be **integrated into the existing workflow lifecycle**:

```
/phx:plan → /phx:work → /phx:review → /phx:compound → THEORY.md evolves
     │           │            │              │               ↑
     ↓           ↓            ↓              ↓               │
  plan.md    progress.md   reviews/    solutions/    Auto-synthesis
```

### THEORY.md Structure (Elixir/Phoenix-Adapted)

```markdown
# Project Theory

## Problem Thesis
[Why this project exists. What structural problem it solves.]

## Architectural Principles (Proven)
- All async work via Oban — persistence + retries + observability
  (Origin: user-auth plan, 2024-12-15)
- Streams for lists >100 items — O(1) memory per user
  (Evidence: user-listings, dashboard plans — both successful)
- Contexts own all Repo calls — no direct Repo access from LiveViews
  (Enforced: Iron Law in security skill)

## Domain Patterns
- Auth: Pow + Ueberauth + custom scope plugs (Phoenix 1.8)
- Forms: LiveView forms use streams for dynamic nested fields
- Notifications: PubSub for real-time, Oban for batch

## Dead-Ends (Do Not Retry)
- Ecto.Multi for multi-step registration → Too rigid
  (Alternative: Separate changesets + transaction wrapper)
- GenServer for rate-limiting → Complexity not justified
  (Alternative: Hammer library or ETS-based counter)

## Open Questions
- [ ] LiveView ephemeral assigns vs regular for session data?
  (Priority: HIGH — affects 3 pending features)
- [ ] Finch vs Req for external API calls?
  (Status: Evaluating in api-client plan)

## Cross-Feature Dependencies
- oauth-linking blocks user-profiles feature
- Payment feature shares Oban queue with email-delivery
```

### Integration Points

| Trigger | Action |
|---------|--------|
| `/phx:plan` completes | Extract architectural decisions → update Principles |
| `/phx:work` hits DEAD-END | Add to Dead-Ends section |
| `/phx:compound` captures solution | Update Domain Patterns + link to solution doc |
| `/phx:review` finds systemic issue | Add to Open Questions |
| SessionStart | Read THEORY.md silently for orientation |
| SessionStart (display) | Show 3-line summary: principles count, open questions, dependencies |
| PreCompact | Re-inject THEORY.md summary alongside Iron Laws |

### Why This Matters for Our Plugin Specifically

Theorist is generic — it works for any repo. Our version would be **workflow-integrated**:

1. **Not manual** — Updates flow from existing workflow artifacts (scratchpad → theory)
2. **Not generic** — Structured around Elixir/Phoenix domains (Ecto, LiveView, Oban, Auth)
3. **Not isolated** — SessionStart, PreCompact, and `/phx:brief` all consume it
4. **Holistic rewrites** — Like Theorist, rewrite the whole doc (prevents cruft accumulation)
5. **Bounded** — ~200 lines max, forces distillation of what actually matters

### Implementation Approach

**Phase 1** (Low effort): Add `THEORY.md` as a manual artifact. `/phx:theory` command reads scratchpads + solutions + dead-ends and synthesizes a theory doc. User invokes it periodically.

**Phase 2** (Medium effort): Auto-update triggers from workflow phases. When `/phx:compound` runs, also update THEORY.md. When `/phx:work` hits a DEAD-END, append to theory.

**Phase 3** (Higher effort): Full integration — SessionStart reads and displays theory summary, PreCompact re-injects it, `/phx:brief` includes a "Project Context" section from theory.

---

## Updated Implementation Priority Matrix

| # | Feature | Source | Effort | Impact | Priority |
|---|---------|--------|--------|--------|----------|
| 1 | PreToolUse dangerous ops blocking | everything-claude-code | Low | High | **P0** |
| 2 | Debug statement detection hook | everything-claude-code | Low | Medium | **P0** |
| 7 | Strategic compaction counter | everything-claude-code | Very Low | Medium | **P0** |
| 3 | `/phx:coverage` test coverage skill | everything-claude-code | Medium | High | **P1** |
| 6 | Build error resolver agent | everything-claude-code | Medium | Medium-High | **P1** |
| 9 | `/phx:theory` Phase 1 (manual) | theorist | Low-Med | High | **P1** |
| 4 | `/phx:checkpoint` milestone skill | everything-claude-code | Low-Med | Medium | **P2** |
| 5 | Enhanced continuous learning | everything-claude-code | Med-High | High | **P2** |
| 10 | `/phx:theory` Phase 2-3 (auto) | theorist | Med-High | Very High | **P2** |
| 8 | Doc sync reviewer agent | everything-claude-code | Medium | Medium | **P3** |

---

## Final Architectural Insight

Three distinct philosophies emerge across the landscape:

| Approach | Project | Strength | Weakness |
|----------|---------|----------|----------|
| **Domain depth** | Our plugin | Deep Elixir expertise, Iron Laws, specialist agents | Learning is manual, no strategic context layer |
| **Self-improvement loops** | everything-claude-code | Auto-extracts patterns, evolves skills | Breadth over depth, no domain Iron Laws |
| **Strategic memory** | Theorist | Living mental model, holistic understanding | No workflow integration, no domain specificity |

The optimal path: combine all three. We already have domain depth. Adding a theory layer (from Theorist) with automated extraction triggers (from everything-claude-code) would give us:

**Deep domain expertise** (Iron Laws) + **strategic memory** (THEORY.md) + **self-improving knowledge** (auto-compound from workflow phases)

This is the compound advantage that neither of the other projects achieves alone.
