# Plugin Improvement Analysis: Competitive Landscape Review

**Date**: 2026-03-01
**Sources**:
- https://github.com/affaan-m/everything-claude-code (54.8K stars)
- https://github.com/blader/theorist (strategic memory skill)
**Our Plugin**: elixir-phoenix v2.0.0 (20 agents, 38 skills, 6 hook types)

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

---

# Part 3: Iterative Engineering Plugin Analysis

**Source**: https://github.com/tmchow/tmc-marketplace/tree/main/plugins/iterative-engineering
**Author**: Trevin Chow
**Version**: 1.16.1 (18 agents, 12 skills)

## What It Is

A language-agnostic Claude Code plugin implementing an end-to-end development pipeline:
brainstorm → research → design exploration → tech planning → implementing → code review → PR.

Unlike our domain-specific (Elixir/Phoenix) plugin, iterative-engineering is framework-agnostic
but shares our philosophy of multi-agent orchestration and structured workflows.

## Architecture Comparison

| Aspect | Iterative Engineering | Our Plugin |
|--------|----------------------|------------|
| **Focus** | Language-agnostic iterative workflows | Elixir/Phoenix domain expertise |
| **Skills** | 12 (7 core + 5 supporting/internal) | 38 (domain-specific) |
| **Agents** | 18 (8 code review personas + 6 plan review + 4 workers) | 20 (tiered opus/sonnet/haiku) |
| **Hooks** | None visible | 6 hook types across 8+ hooks |
| **Review model** | Dynamic persona selection (3 always-on + 5 conditional) | Fixed 4-agent parallel review |
| **Planning** | Brainstorm → PRD → Tech Plan (3 phases) | Single planning-orchestrator phase |
| **Implementation** | Dependency-aware batching with TDD gates | Checkbox-based sequential execution |
| **Design phase** | Interactive HTML prototypes with star ratings | None |
| **Iron Laws** | None (language-agnostic) | 21 domain-specific rules |
| **State machine** | Documents (PRD, Tech Plan) | Filesystem (plan.md checkboxes) |

## Novel Patterns Worth Adopting

### 1. Dynamic Reviewer Persona Selection (High Value)

**What they do:** Instead of always spawning the same 4 reviewers, they use agent judgment
to analyze the diff and select 3-5 reviewers from a pool of 8. Security reviewer only spawns
if auth code changed. Data-migrations reviewer only if schemas touched. Each selection includes
a one-line justification.

**What we do:** Always spawn all 4 review agents (elixir-reviewer, security-analyzer,
testing-reviewer, verification-runner) regardless of what changed.

**Gap:** A CSS-only change still spawns the security analyzer. A test-only change still
spawns the full verification suite. This wastes context and time.

**Recommendation:** Add dynamic selection to `parallel-reviewer`. Define conditions:
- `security-analyzer` → only when auth/session/password files changed
- `ecto-schema-designer` → only when migrations/schemas changed
- `oban-specialist` → only when worker files changed
- `elixir-reviewer` + `testing-reviewer` → always on

**Effort:** Medium | **Impact:** High — faster reviews, more focused findings

### 2. Domain-Specific Confidence Calibration (High Value)

**What they do:** Different confidence thresholds per domain. A security finding at 0.60
confidence is actionable (cost of miss is high). A performance finding at 0.60 is noise
(easy to measure later). This prevents both false negatives in critical areas and alert
fatigue in low-impact areas.

**What we do:** No confidence scoring on review findings. Everything is treated equally.

**Recommendation:** Add confidence + severity to review agent output schemas:
- Security findings: threshold 0.50 (low bar — better safe)
- Performance findings: threshold 0.75 (need strong evidence)
- Idiom findings: threshold 0.60 (moderate confidence needed)
- Test findings: threshold 0.65

**Effort:** Medium | **Impact:** High — reduces noise, surfaces critical issues

### 3. Structured JSON Review Schema (High Value)

**What they do:** Reviewers return findings as structured JSON with typed fields:
`title`, `severity` (P0-P3), `file`, `line`, `why_it_matters`, `confidence`,
`evidence`, `pre_existing` flag, optional `suggested_fix`.

This enables deterministic deduplication (file + line bucket ±3 + normalized title
fingerprint), machine-readable reports, and automated fix routing.

**What we do:** Review agents write prose markdown to `reviews/{track}.md`.
Deduplication happens in context-supervisor via LLM (non-deterministic).

**Recommendation:** Define a JSON schema for review agent output. Keep the
human-readable markdown report as final output, but use structured intermediate
format for dedup/merge/triage.

**Effort:** Medium-High | **Impact:** High — deterministic dedup, better triage

### 4. Scope Assessment Before Ceremony (Medium Value)

**What they do:** Brainstorming skill auto-detects complexity before deciding how
much process to apply:
- **Quick** (bug fix, config): 0-2 questions, inline fix, no document
- **Standard** (small feature): 3-5 Q&A, lightweight brief
- **Full** (large feature): deep exploration, formal PRD, review cycle

**What we do:** Intent detection suggests commands, but each command applies the
same level of ceremony regardless of actual complexity.

**What we could improve:** `/phx:plan` could auto-detect scope:
- Small scope (1-2 files, simple change) → skip parallel research agents, generate inline plan
- Medium scope (3-10 files) → standard planning with 2-3 agents
- Large scope (10+ files, new domain) → full parallel research

This would make `/phx:plan` smarter without requiring users to choose between
`/phx:quick` and `/phx:plan`.

**Effort:** Medium | **Impact:** Medium — reduces friction for simple features

### 5. Dependency-Aware Batch Execution (Medium Value)

**What they do:** Implementation analyzes the dependency graph between subtasks
and groups them into batches. Tasks within a batch run concurrently (parallel
subagents), batches run sequentially. Test verification gates between batches
catch issues early.

**What we do:** `/phx:work` executes tasks sequentially (first unchecked → next).
No dependency analysis or parallelization.

**Recommendation:** For plans with 5+ tasks, analyze dependencies and identify
parallelizable groups. Run independent tasks as concurrent subagents where safe
(e.g., adding a migration + writing tests for existing code).

**Effort:** High | **Impact:** Medium — faster execution for large plans

### 6. Interactive HTML Design Exploration (Novel, Niche Value)

**What they do:** Generate 5-10 interactive HTML prototypes with Tailwind CSS +
Alpine.js. Each prototype has 4-8 live controls (sliders, toggles) for exploring
design decisions. Star ratings + structured feedback export for iteration.

**What we could do:** A `/phx:prototype` skill that generates LiveView component
HTML mockups with interactive controls. Particularly useful for:
- Complex form layouts (multi-step wizards vs. single-page)
- Dashboard layouts (grid vs. sidebar vs. tabs)
- Component API exploration (slot variations)

**Effort:** High | **Impact:** Low-Medium (niche but impressive)

### 7. Pre-Existing Issue Separation (Medium Value)

**What they do:** Review findings are flagged as `pre_existing: true/false`.
Pre-existing issues are separated from the verdict — they appear in the report
but don't block PR readiness.

**What we do:** Reviews don't distinguish between new issues and pre-existing ones.
This causes frustration when reviews flag problems in code the user didn't touch.

**Recommendation:** Add `pre_existing` detection to review agents by comparing
findings against the git diff base. Issues in unchanged files = pre-existing.

**Effort:** Low-Medium | **Impact:** Medium — reduces review frustration

### 8. TDD Hard Gate on Feature Tasks (Low Value for Us)

**What they do:** Feature subtasks have a hard gate: "Feature subtasks do not
ship without tests." If no test file exists, the agent stops and requests the path.

**What we already have:** Iron Laws + testing-reviewer catch missing tests. Our
compound system captures test patterns. However, we don't have a hard gate that
STOPS implementation without tests.

**Recommendation:** Consider adding a soft check in `/phx:work` that warns
(not blocks) when a task creates a new public function without a corresponding test.

**Effort:** Low | **Impact:** Low (we already catch this in review)

## Patterns NOT to Adopt

### Language-Agnostic Design
Their language-agnostic approach trades depth for breadth. Our domain-specific
Iron Laws, Ecto patterns, LiveView architecture — these are our differentiator.

### No Hooks
They don't use hooks at all. Our hooks (format, compile, security, progress,
SubagentStart Iron Laws injection) are a major advantage.

### Formal PRD Phase
Their brainstorm → PRD → tech plan is 3 separate commands with 3 documents.
Our single `/phx:plan` with parallel research agents is faster and produces
a directly executable artifact. No need to add PRD ceremony.

## Updated Implementation Priority Matrix

| # | Feature | Source | Effort | Impact | Priority |
|---|---------|--------|--------|--------|----------|
| 1 | Dynamic reviewer persona selection | iterative-engineering | Medium | High | **P0** |
| 2 | Confidence scoring + domain calibration | iterative-engineering | Medium | High | **P1** |
| 3 | Structured JSON review schema | iterative-engineering | Medium-High | High | **P1** |
| 4 | Pre-existing issue separation | iterative-engineering | Low-Medium | Medium | **P1** |
| 5 | Scope-adaptive planning | iterative-engineering | Medium | Medium | **P2** |
| 6 | Dependency-aware batch execution | iterative-engineering | High | Medium | **P2** |
| 7 | LiveView design prototyping | iterative-engineering | High | Low-Med | **P3** |

---

## Cross-Plugin Architectural Insights

Four distinct philosophies now visible across the landscape:

| Approach | Project | Strength | Weakness |
|----------|---------|----------|----------|
| **Domain depth** | Our plugin | Deep Elixir expertise, Iron Laws, specialist agents | Learning is manual, no strategic context layer |
| **Self-improvement loops** | everything-claude-code | Auto-extracts patterns, evolves skills | Breadth over depth, no domain Iron Laws |
| **Strategic memory** | Theorist | Living mental model, holistic understanding | No workflow integration, no domain specificity |
| **Iterative refinement** | iterative-engineering | Dynamic persona selection, structured review, TDD gates | No domain expertise, no hooks, no Iron Laws |

The optimal synthesis: **Domain depth** (Iron Laws) + **dynamic review intelligence** (persona selection + confidence calibration from iterative-engineering) + **strategic memory** (THEORY.md from Theorist) + **self-improving knowledge** (auto-compound from everything-claude-code).

Our plugin already has the strongest foundation (domain expertise + hooks + multi-agent orchestration). The highest-ROI additions from iterative-engineering are the review intelligence patterns (dynamic selection, confidence scoring, structured JSON, pre-existing separation) — these directly improve our existing `/phx:review` without adding new skills or changing the workflow.

---

# Part 4: Carmack Council Plugin Analysis

**Source**: https://github.com/Carmack-Council/Carmack-Council
**Structure**: 4 skills, 9 shared reference docs, 0 hooks, 0 agents (inline subagent prompts)
**Total content**: ~5,230 lines of markdown + build scripts
**Stack**: Next.js / tRPC / Prisma / Neon (but designed for forking via STACK.md)

## What It Is

A persona-grounded multi-expert review system where each subagent embodies a named industry expert (Troy Hunt for security, Kent Beck for testing, Martin Fowler for refactoring, etc.). John Carmack serves as the philosophical "Chair" who orchestrates, filters, and guards against over-recommendation. The plugin ships as individual `.skill` zip files rather than a Claude Code plugin manifest.

## Architecture Comparison

| Aspect | Carmack Council | Our Plugin |
|--------|----------------|------------|
| **Distribution** | Individual `.skill` zips | Plugin marketplace (`plugin.json`) |
| **Skills** | 4 (review, plan, implement, spec-writer) | 38 domain-specific |
| **Agents** | 0 files — 10+ inline subagent prompts in SKILL.md | 20 agent files with YAML frontmatter |
| **Hooks** | None | 6 hook types across 8+ hooks |
| **Review model** | 10 named-expert parallel review | 4-agent parallel review |
| **Reference docs** | 9 shared (250-340 lines each, deeply sourced) | 30+ per-skill references |
| **Compound learning** | `conventions.md` (auto-updated from reviews) | `solutions/{category}/` (manual via `/phx:compound`) |
| **Iron Laws** | None (expert personas instead) | 21 domain-specific rules |
| **File I/O** | Subagents write to disk, return 1-line summaries | Context-supervisor compresses worker output |
| **Max findings** | Hard cap at 15 per review | No explicit cap |

## Novel Patterns Worth Adopting

### 1. Named-Expert Persona Grounding (High Value — Technique)

**What they do:** Each subagent is assigned a real expert's persona backed by a 250-340 line reference document built from that expert's published work, specific quotes, production case studies, and documented opinions. This isn't roleplay — it's structured knowledge attribution.

Example: The security reference contains Troy Hunt's specific breach case studies (CloudPets, VTech, Nissan LEAF) as evidence for principles. The testing reference uses Kent Beck's quotes about TDD and a dedicated section on "AI agents cheat" with detection patterns.

**What we do:** Our review agents have domain names (security-analyzer, elixir-reviewer) but no persona grounding or attributed knowledge sources.

**Gap:** Our agents apply generic "best practices" rather than opinionated, sourced expertise. This makes findings less persuasive and harder to trust.

**Recommendation:** Enhance our reference docs with attributed expert sources where relevant:
- `security/references/authentication.md` → Add OWASP case studies, cite specific CVEs
- `ecto-patterns/references/queries.md` → Cite Ecto author (José Valim) documented recommendations
- `liveview-patterns/references/` → Cite Chris McCord's published patterns and conference talks

This doesn't require persona roleplay — just grounding recommendations in real, citable sources.

**Effort:** Medium (reference doc enhancement) | **Impact:** Medium-High — more trustworthy findings

### 2. File-Based Inter-Agent Communication with 1-Line Summaries (High Value)

**What they do:** Each subagent writes full findings to a file on disk and returns ONLY a one-line summary to the parent: `"Findings written to .council/review-output/$TIMESTAMP/hunt.md — 3 findings (1 P1, 2 P2)"`. The chair then reads all 10 output files for synthesis.

Instructions are emphatic: "Do NOT return your full findings to the parent. The file is your deliverable."

**What we do:** Our context-supervisor pattern is similar — workers write to files, supervisor compresses. But our subagents still return substantial content to the parent, and the supervisor reads worker output files rather than just summary pointers.

**Gap:** When spawning 4+ agents in parallel, the parent context can still get large from return values.

**Recommendation:** Adopt the strict "file is your deliverable, return only a pointer" pattern for review subagents. This is especially valuable as we consider adding more review agents (dynamic persona selection from Part 3).

**Effort:** Low | **Impact:** Medium — prevents context exhaustion at scale

### 3. The "Carmack Filter" — Anti-Over-Recommendation Gate (High Value)

**What they do:** During synthesis, every finding must pass a meta-filter:
- "Is this actually needed for THIS feature at THIS scale?"
- "Would Carmack build this, or would he call it premature?"
- "What's the concrete consequence if this isn't fixed?"

This structurally guards against the known LLM tendency to recommend everything.

**What we do:** No equivalent filter. Review findings go through deduplication but not an economic relevance test.

**Gap:** Our reviews sometimes surface technically correct but practically irrelevant findings, especially for small changes.

**Recommendation:** Add an "overriding filter" step to the `parallel-reviewer` synthesis phase. Before finalizing, apply 3-4 questions:
1. Does this finding affect the code that was actually changed?
2. What is the concrete production consequence if this isn't fixed?
3. Is this a real risk or pattern-matching against generic best practices?
4. Would a senior Elixir dev flag this in a real PR review?

**Effort:** Low (add to reviewer prompt) | **Impact:** High — reduces noise significantly

### 4. Conventions.md Compound Learning Loop (High Value)

**What they do:** After each review (Phase 7), the Chair surfaces "convention candidates":
- **Type A — Accepted Patterns:** "Don't flag this again" (e.g., "Fire-and-forget analytics calls are intentional")
- **Type B — Adopted Fixes:** "Always do this going forward" (e.g., "All tRPC mutations must verify ownership")

Users select which to adopt. These are written to `conventions.md` with numbered IDs, attributed to the review timestamp and expert. All four skills read this file at startup and respect it.

**What we do:** `/phx:compound` captures solved problems manually. No automated convention extraction from reviews.

**Gap:** Review findings are one-shot — if a team intentionally uses a pattern that gets flagged, it gets re-flagged every review. And good patterns discovered in reviews don't automatically feed back into future reviews.

**Recommendation:** Add a Phase 7 to `/phx:review` that offers convention extraction:
- After presenting findings, ask: "Any findings to suppress (accepted pattern) or adopt (new convention)?"
- Write to `.claude/conventions.md` with IDs and attribution
- All review agents read `conventions.md` at start and skip suppressed patterns

This is the missing link between our review and compound systems.

**Effort:** Medium | **Impact:** Very High — reviews improve over time automatically

### 5. Explicit Lane Discipline with Deduplication Rules (Medium Value)

**What they do:** Every subagent prompt ends with "Stay in your lane." The synthesis phase defines 7 specific overlap resolution rules:
- "Saarinen vs Dodds: Saarinen takes priority for visual/design concerns. Dodds for architectural."
- "Beck vs all others: Beck reviews test quality only. If Beck flags no tests and another expert flags a bug, keep both — they're complementary."

**What we do:** Review agents have implicit domain boundaries but no explicit overlap resolution rules. Context-supervisor deduplicates via LLM judgment (non-deterministic).

**Recommendation:** Add explicit overlap rules to `parallel-reviewer`:
- `security-analyzer` vs `elixir-reviewer`: Security takes priority for auth/input validation. Elixir takes priority for idiomatic patterns.
- `testing-reviewer` vs all: Testing reviews test quality only. If testing flags no test and another agent flags a bug, keep both.

**Effort:** Low | **Impact:** Medium — more consistent deduplication

### 6. Mandatory Conversational Summary Table (Medium Value)

**What they do:** Every review ends with a scannable table presented in conversation. "This table is NON-NEGOTIABLE. The user should never have to ask 'what did you find?'"

**What we do:** Reviews write to files. The user gets a brief summary but must open files for details.

**Recommendation:** Add a mandatory summary table at the end of `/phx:review` output:

```
| # | Finding | Severity | Expert | File |
|---|---------|----------|--------|------|
| 1 | Missing auth check in handle_event | P1 | Security | user_live.ex:45 |
| 2 | N+1 query in listing | P2 | Ecto | accounts.ex:78 |
```

**Effort:** Very Low | **Impact:** Medium — better UX

### 7. Compact Instructions for Long Sessions (Low-Medium Value)

**What they do:** Skills include explicit "Compact Instructions" sections telling Claude exactly what to preserve when context compaction happens: timestamp, file paths, which subagents dispatched, current phase number, etc.

**What we do:** PreCompact hook re-injects Iron Laws and workflow rules. But we don't tell skills what session-specific state to preserve.

**Recommendation:** Add compact-preservation hints to long-running skills (`/phx:work`, `/phx:full`, `/phx:review`):
- Current plan path and completion state
- Which review agents have run
- Active findings list
- Current phase number

**Effort:** Low | **Impact:** Low-Medium — helps long sessions

### 8. Triple-Redundant Anti-Code Enforcement (Technique — Already Applicable)

**What they do:** "No code in output" is stated 3+ times in different formulations across the skill. This addresses the known LLM tendency to include code even when told not to.

**Lesson:** For any critical behavioral constraint in our skills, state it at minimum twice — once in the dispatch and once in the output format section. Single-statement rules get ignored under pressure.

## Patterns NOT to Adopt

### Inline Subagent Prompts (Architectural Mismatch)
Their 857-line SKILL.md files embed all subagent prompts inline. This works for `.skill` zip distribution but would bloat our agent files beyond hard limits. Our separate agent files with YAML frontmatter + `skills:` preloading is better for maintenance.

### No Hooks
Zero hooks means no auto-formatting, no progress tracking, no Iron Laws injection into subagents. Our hooks system is a major advantage.

### 10-Expert Review (Diminishing Returns)
10 parallel reviewers is impressive but expensive. Our 4-agent model with dynamic selection (from Part 3) would achieve similar coverage at lower cost. The key insight isn't the number of experts — it's the quality of their reference documents.

### Stack-Specific Stack (Prisma/tRPC/Next.js)
Their reference docs are deeply Prisma/Next.js specific (13 Prisma defaults to override, etc.). Not applicable to Elixir/Phoenix. But the *pattern* of documenting known-bad framework defaults is excellent — we should do the same for Ecto/Phoenix.

## Updated Implementation Priority Matrix

| # | Feature | Source | Effort | Impact | Priority |
|---|---------|--------|--------|--------|----------|
| 1 | Conventions.md compound loop from reviews | Carmack Council | Medium | Very High | **P0** |
| 2 | Anti-over-recommendation filter | Carmack Council | Low | High | **P0** |
| 3 | Mandatory conversational summary table | Carmack Council | Very Low | Medium | **P0** |
| 4 | File-based 1-line return pattern for agents | Carmack Council | Low | Medium | **P1** |
| 5 | Expert-sourced reference docs | Carmack Council | Medium | Medium-High | **P1** |
| 6 | Explicit lane discipline / dedup rules | Carmack Council | Low | Medium | **P1** |
| 7 | Compact instructions for long skills | Carmack Council | Low | Low-Medium | **P2** |

---

## Consolidated Cross-Plugin Landscape

Five distinct philosophies now visible across the analyzed projects:

| Approach | Project | Strength | Weakness |
|----------|---------|----------|----------|
| **Domain depth** | Our plugin | Deep Elixir expertise, Iron Laws, specialist agents | Learning is manual, no strategic context layer |
| **Self-improvement loops** | everything-claude-code | Auto-extracts patterns, evolves skills | Breadth over depth, no domain Iron Laws |
| **Strategic memory** | Theorist | Living mental model, holistic understanding | No workflow integration, no domain specificity |
| **Iterative refinement** | iterative-engineering | Dynamic persona selection, structured review, TDD gates | No domain expertise, no hooks, no Iron Laws |
| **Expert council** | Carmack Council | Deep sourced references, persona grounding, compound conventions | No hooks, inline prompts, stack-specific |

### Highest-ROI Synthesis for Our Plugin

Combining the best patterns from all four external projects, prioritized by effort-to-impact ratio:

| Priority | Feature | Source | Why It's High-ROI |
|----------|---------|--------|-------------------|
| **P0** | Anti-over-recommendation filter | Carmack Council | Low effort, immediately reduces review noise |
| **P0** | Mandatory summary table in reviews | Carmack Council | Very low effort, immediate UX improvement |
| **P0** | Conventions.md from review findings | Carmack Council | Medium effort, compounds value over every review |
| **P0** | PreToolUse dangerous ops blocking | everything-claude-code | Low effort, prevents data loss |
| **P0** | Debug statement detection hook | everything-claude-code | Low effort, catches common mistake |
| **P0** | Dynamic reviewer persona selection | iterative-engineering | Medium effort, faster + more focused reviews |
| **P1** | Confidence scoring + calibration | iterative-engineering | Reduces noise, surfaces critical issues |
| **P1** | Structured JSON review schema | iterative-engineering | Deterministic dedup, better triage |
| **P1** | `/phx:theory` Phase 1 (manual) | Theorist | Strategic memory layer |
| **P1** | Expert-sourced reference docs | Carmack Council | More trustworthy findings |
| **P1** | Pre-existing issue separation | iterative-engineering | Reduces review frustration |
| **P1** | `/phx:coverage` test coverage skill | everything-claude-code | Directly improves code quality |
| **P2** | Scope-adaptive planning | iterative-engineering | Reduces friction for simple features |
| **P2** | Enhanced continuous learning | everything-claude-code | Compounds value over time |
| **P2** | `/phx:theory` Phase 2-3 (auto) | Theorist | Full strategic memory integration |

The theme: **review intelligence is the biggest gap**. Three of four external projects (Carmack Council, iterative-engineering, everything-claude-code) offer complementary improvements to our review pipeline. Combining the Carmack filter (reduces noise), dynamic selection (reduces waste), conventions loop (enables learning), and structured schema (enables automation) would make `/phx:review` dramatically more effective.
