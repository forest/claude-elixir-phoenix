# Deep Analysis & Actionable Suggestions

**Date:** 2026-03-27
**Input:** Research documents 00-07, current plugin audit, 15+ academic papers, Feynman & OMC verified patterns

---

## Part 1: Critical Analysis — What the Research Actually Tells Us

### 1.1 The Core Problem Is Real and Measurable

The research makes a strong case. But let's stress-test the claims:

**Evidence FOR the verification gap:**
- FActScore proves ChatGPT hallucinates 42% of atomic claims in biographies (well-studied domain). Our agents working on Elixir libraries (niche domain, less training data) likely hallucinate MORE, not less
- Our 137-session analysis found review agents occasionally reporting N+1 queries that don't exist — this is exactly the extrinsic hallucination Huang et al. classify as "sounds plausible but has no supporting evidence"
- Our `/phx:research` currently has ZERO verification steps — web-researcher extracts content and the skill synthesizes it without checking if claims match sources
- Our `parallel-reviewer` has no consensus step — if the security-analyzer and elixir-reviewer disagree on severity, nobody catches it

**Evidence that complicates the picture:**
- CoVe's hallucination reduction is measured on factoid QA, not software engineering tasks. Our agents make claims about CODE (which can be verified by running it), not general knowledge
- FIRE's 7.6x cost reduction is for fact-checking news claims. Elixir library verification is simpler (hex.pm exists? docs confirm feature?) — we might get even better efficiency, OR the domain mismatch could mean FIRE's approach doesn't transfer
- We already have code-level verification (Iron Laws, mix compile/test) that catches a large class of errors. The INCREMENTAL value of output verification is real but smaller than the papers suggest for domains without any verification

**Honest assessment:** The gap is real and significant for `/phx:research` and `/phx:review`. It's moderate for `/phx:plan` and `/phx:investigate`. It's minimal for `/phx:work` and `/phx:quick` which already verify via mix commands.

### 1.2 What the Research Doesn't Tell Us

**Cost-benefit remains unquantified.** None of the papers measure the cost of verification in a plugin-like system where:
- Verification adds latency to every workflow step
- Users want fast iteration, not audit-grade provenance
- Some users would trade 10% accuracy for 50% speed

**The "overnight" pattern doesn't map to interactive use.** Karpathy's autoresearch runs 37 experiments overnight. Our users expect results in minutes, not hours. Autoresearch for research quality (search → verify → re-search → verify) could take 5-10 minutes per iteration — users may not wait.

**Writer/reviewer independence is theoretically ideal but practically constrained.** CoVe says the verifier shouldn't see the original prompt. In our plugin, the verifier agent IS a Claude instance that shares the same training biases. Independence is limited to prompt isolation, not true cognitive independence.

### 1.3 What Feynman Gets Right That We're Missing

Feynman's 8-phase deep research is genuinely superior to our current approach in 3 specific ways:

1. **Iterative evaluation loop (Phase 4):** After parallel research, Feynman reads outputs and identifies gaps/contradictions/single-source claims, then does TARGETED follow-up research. We do one pass and stop. This is the single biggest improvement opportunity.

2. **Verification review (Phase 7):** A separate reviewer agent flags unsupported claims, logical gaps, and confidence-evidence mismatches. FATAL issues require re-research. We have no equivalent.

3. **Provenance as first-class artifact (Phase 8):** The provenance sidecar isn't an afterthought — it's part of the delivery. Users can inspect the audit trail. Our research output provides no way to assess trustworthiness.

### 1.4 What OMC Gets Right That We're Missing

1. **Dead Ends as structured memory:** OMC's notepad-wisdom explicitly records failed approaches with WHY they failed. Our scratchpad records events but not reasoning. Reflexion paper proves WHY matters (91% vs 80% improvement). This is cheap to implement and immediately valuable.

2. **Quality gates for learned knowledge:** OMC's learner has 4 explicit rejection criteria that prevent noise from entering the skill library. Our `/phx:compound` validates format but not whether the captured knowledge is actually non-obvious or codebase-specific.

3. **Slop categories are practical and concrete.** "Needless abstraction" and "boundary violations" map directly to Phoenix anti-patterns (GenServer wrappers, Repo calls in LiveView). These overlap with our Iron Laws but focus on the AI-specific failure modes.

---

## Part 2: Gap Analysis — What Our Plugin Actually Has vs. Needs

### Current Verification Landscape

| Component | Code Verification | Output Verification | Source Quality | Provenance |
|-----------|:-:|:-:|:-:|:-:|
| `/phx:work` | strong (mix compile/test/format) | — (not applicable) | — | — |
| `/phx:quick` | strong (mix compile/test) | — (not applicable) | — | — |
| `/phx:verify` | strong (full verification suite) | — (IS verification) | — | — |
| `/phx:research` | — | **NONE** | basic prioritization | **NONE** |
| `/phx:review` | — | **NONE** | — | — |
| `/phx:investigate` | — | **NONE** | — | — |
| `/phx:plan` | — | **NONE** | — | — |
| `/phx:compound` | format validation | **NONE** | — | — |
| `/phx:audit` | — | **NONE** | — | — |
| `web-researcher` | — | conflict flagging only | source extraction | — |
| `parallel-reviewer` | pre-existing detection | **NONE** | — | — |
| `context-supervisor` | coverage gap warning | **NONE** | — | — |

### Where Verification Matters Most (ranked by hallucination risk × user impact)

```
HIGH RISK, HIGH IMPACT:
  /phx:research       — Claims about libraries/patterns go directly to implementation decisions
  parallel-reviewer   — False findings waste user time debugging non-issues
  /phx:investigate    — Wrong root cause leads to wrong fix

MEDIUM RISK, HIGH IMPACT:
  /phx:plan           — Wrong architecture assumptions cascade through entire implementation
  /phx:audit          — Incorrect health metrics create false confidence

LOW RISK (already verified):
  /phx:work           — mix compile/test catches code errors
  /phx:quick          — same
  /phx:verify         — IS the verification
```

### Scratchpad Gap (quantified)

Current scratchpad content (from inspector-plugin plan):
```markdown
## API failure — 2026-03-25T14:23:00Z
Recovery: re-read plan.md and continue from last checked task
```

This is ~5% of what a structured lab notebook provides. Missing:
- Hypotheses tested (0% coverage)
- Dead ends with WHY (0% coverage)
- Decisions with reasoning (0% coverage)
- Open questions (0% coverage)
- Handoff notes (partial — the recovery instruction is a minimal handoff)

---

## Part 3: Concrete Suggestions (Prioritized)

### S1: MUST-DO — Verification for /phx:research (P0+P1 combined)

**Why this is #1:** Research output directly influences implementation decisions. A hallucinated library recommendation wastes hours. A wrong pattern recommendation creates tech debt. And research is where the hallucination rate is highest because it involves web content synthesis.

**Specific implementation:**

#### A. Add verification step to research skill (inline, not hook)

Add after synthesis, before delivery in `research/SKILL.md`:

```
Step 5: VERIFY (new)
For each factual claim in the draft:
  1. Is it cited to a specific source? IF NO → search for source or REMOVE
  2. Does the cited source actually say this? IF NO → fix or REMOVE
  3. Is the source T1/T2 quality? IF NO → seek corroboration from T1/T2
  4. Does the source URL resolve? IF NO → find alternative or flag

Produce: verified brief + .provenance.md sidecar
```

#### B. Update web-researcher agent to track source quality

Add to `web-researcher.md` system prompt:

```
For each source you use, classify quality tier:
- T1 (Authoritative): HexDocs, official GitHub repos, Elixir/Erlang docs
- T2 (First-party): Core team blog posts, ElixirConf talks, maintainer comments on ElixirForum
- T3 (Community): ElixirForum posts, Stack Overflow, blogs with working code examples
- T4 (Low quality): SEO listicles, AI-generated content, posts without code
- T5 (Rejected): Dead links, paywalled, fabricated

Include tier in your output: "[T1] HexDocs confirms assign_async requires connected? check"
```

#### C. Create output-verifier agent

New agent `plugins/elixir-phoenix/agents/output-verifier.md`:
- Sonnet model (needs judgment, not just mechanical checking)
- Receives: draft artifact file path + source files
- Does NOT receive: original user prompt (CoVe independence principle)
- Produces: verified artifact + provenance sidecar
- Uses FIRE's iterative approach: high-confidence claims pass fast, uncertain claims get re-checked

**Important design constraint:** The verifier should be OPTIONAL for speed-sensitive workflows. Research: always verify. Quick: never verify. Review: verify by default, skip with `--fast`.

#### D. Provenance sidecar format

Keep it simple. Don't over-engineer. The minimum viable provenance:

```markdown
# Provenance: {filename}
**Verified:** {n}/{total} claims | **Sources:** {count} (T1:{n} T2:{n} T3:{n})
**Removed:** {list of claims removed and why}
**Conflicts:** {list of unresolved contradictions, or "none"}
```

Full claim-by-claim log in a section below for those who want it. But the header gives the trust signal at a glance.

### S2: MUST-DO — Structured Scratchpad

**Why this is #2:** Nearly free to implement, immediately valuable. Just a template change + hook update. The Reflexion paper gives us scientific evidence that structured "why" tracking improves retry success by 11 percentage points.

**Specific implementation:**

Update `check-scratchpad.sh` SessionStart hook to initialize with template:
```markdown
## Session: {date}

### Hypotheses Tested
(none yet)

### Dead Ends (DO NOT RETRY)
(none yet)

### Decisions
(none yet)

### Open Questions
(none yet)

### Handoff
- Branch: {current branch}
- Plan: {active plan if any}
- Next: (to be filled)
```

Update `precompact-rules.sh` to PRESERVE these sections during compaction. They're small (~20 lines) and high-value.

Update `log-progress.sh` PostToolUse hook to append to appropriate section:
- Hypothesis confirmed → add to Hypotheses Tested with [pass]
- Approach failed → add to Dead Ends with WHY
- Decision made → add to Decisions

**Critical:** The Dead Ends section must survive compaction and session boundaries. It's the difference between 80% and 91% effectiveness on session resume.

### S3: SHOULD-DO — Review Cross-Validation

**Why:** Our `parallel-reviewer` spawns 4 specialist agents but has no consensus step. If the security-analyzer says "this is fine" and the iron-law-judge says "this violates Iron Law #11", nobody catches the disagreement.

**Specific implementation:**

Add to `parallel-reviewer.md` after all 4 agents complete, before context-supervisor:

```
Step: CROSS-VALIDATE (new)
Read all 4 review outputs.
For each finding, check:
  1. Does any other agent CONTRADICT this finding?
  2. Does the code actually contain what the finding claims?
     (Re-read the specific lines mentioned)
  3. Is the severity consistent across agents?

Output: Add [CROSS-VALIDATED], [DISPUTED], or [UNVERIFIED] tag to each finding.
```

This is lightweight (one extra read pass) and catches the most impactful false positives.

### S4: SHOULD-DO — /phx:deslop Skill

**Why:** AI-generated code accumulates slop. Phoenix-specific anti-patterns are well-defined. The 4-pass regression-safe workflow prevents cleanup from introducing bugs.

**Specific implementation:**

New skill `plugins/elixir-phoenix/skills/deslop/SKILL.md` with Elixir-specific categories:

| Category | Detection | Phoenix Examples |
|----------|-----------|-----------------|
| Dead code | `mix xref unreachable`, unused handle_event grep | `handle_event("old_button", ...)` for removed button |
| Duplication | AST comparison, changeset pattern matching | Same validation in `create_changeset` and `update_changeset` |
| Needless abstraction | Single-caller functions, pass-through modules | `UserHelpers.get_user(id)` → just use `Repo.get(User, id)` |
| Boundary violations | Repo calls outside contexts, Iron Law overlap | `Repo.all(Post)` inside `post_live.ex` mount |
| Missing tests | Coverage delta against changed files | New context function with 0% coverage |

**`--review` flag:** Identification only, no changes. This is the DEFAULT for first-time users. `--fix` enables autonomous cleanup.

**Integration:** Suggest after `/phx:work` or `/phx:full` completes. "Implementation done. Want to run `/phx:deslop --review` to check for AI slop?"

### S5: NICE-TO-HAVE — Enhanced Autoresearch for Research Quality

**Why nice-to-have, not must-do:** Requires S1 (verifier) to exist first. And the interactive latency concern is real — users may not wait for 3 verification iterations on a research query.

**When it makes sense:** Long-running research on critical topics. Library evaluation before adding a dependency. Architecture research before a major rewrite.

**Specific implementation:**

Add `--verified` flag to `/phx:research`:
```
/phx:research --verified "LiveView streams vs assigns for large lists"
```

This triggers the autoresearch loop:
1. Initial research → draft brief
2. Verify → identify unverified claims
3. Re-search unverified claims with targeted queries
4. Verify again → remove remaining unverified claims
5. Produce verified brief + provenance sidecar

Cap at 3 iterations. First iteration catches ~80% of issues (Self-Refine paper). Display progress: "Verifying... 14/18 claims confirmed, 2 re-searching, 2 removed"

### S6: NICE-TO-HAVE — /phx:learn Skill Learner

**Why nice-to-have:** Our `/phx:compound` already captures fix documentation. The learner adds heuristic capture on top — valuable but lower urgency.

**Specific implementation:**

New skill with OMC's quality gates adapted for Elixir:

```
Quality gates (ALL must pass):
1. Non-Googleable: "Would `mix hex.docs` or HexDocs answer this?" → NO
2. Codebase-specific: "Does this reference actual files in THIS project?" → YES
3. Hard-won: "Did this take >30min of debugging?" → YES
4. Actionable: "Can I apply this automatically when editing similar files?" → YES
```

Store in `.claude/skills/learned/` as lightweight skill files. Auto-load based on file patterns (same mechanism as existing skill auto-loading in CLAUDE.md).

**Trigger:** After `/phx:compound` or after a correction from the user. "This was a tricky debug. Want to save this as a learned pattern for this project?"

---

## Part 4: What NOT to Build (Anti-Recommendations)

### 4.1 Don't Build Dynamic Model Routing

OMC's complexity-based routing to Haiku/Sonnet/Opus is theoretically elegant but adds massive complexity for marginal benefit. Our static model assignment per agent is simpler, more predictable, and easier to debug. A `output-verifier` agent that's always Sonnet is better than one that dynamically switches between Haiku and Opus based on claim complexity scoring.

**Reason:** AlphaEvolve uses model ensembles because it runs thousands of iterations. We run 1-3. The overhead of routing logic exceeds the savings on 1-3 calls.

### 4.2 Don't Build Full Provenance for Every Output

The research document proposes provenance sidecars for research, review, investigation, planning, compound, AND audit outputs. That's too many. Provenance is only valuable where:
- The user can't easily verify the output themselves (research)
- The output feeds into irreversible decisions (architecture planning)
- Trust matters more than speed (library evaluation)

**Start with research only.** Add to review if research proves valuable. Skip for plan/investigate/compound — the user verifies those by reading the code.

### 4.3 Don't Build Verification Hooks (Use Inline Agent Calls)

The research document proposes "Option B with Option A as safety net" — skills call the verifier explicitly, with a PostToolUse hook as backup. The hook approach is fragile:
- Hooks can't spawn agents reliably in all contexts
- Hook output patterns are complex (exit 2 + stderr vs stdout vs JSON)
- A hook that spawns a verification agent on every write to `research/` would create unexpected latency

**Just use inline calls.** Each skill that needs verification adds a verification step. No hook needed.

### 4.4 Don't Build /phx:bench Yet

Autonomous performance benchmarking (the Feynman autoresearch for Ecto queries) requires:
- Tidewave available and connected
- Benchee or similar benchmark framework configured
- Reproducible benchmark conditions
- EXPLAIN ANALYZE access to database

Too many prerequisites for most projects. Revisit when Tidewave adoption is higher.

### 4.5 Don't Over-Structure the Scratchpad

The research proposes 5 sections (Hypotheses, Dead Ends, Decisions, Open Questions, Handoff). That's the right number for a TEMPLATE, but don't enforce it rigidly. The scratchpad should be freeform with suggested structure — not a schema that rejects entries that don't fit a category.

---

## Part 5: Dependency Graph and Build Order

```
                     ┌─────────────────────┐
                     │ S2: Structured       │
                     │     Scratchpad       │ ← Standalone, build first
                     └─────────────────────┘

                     ┌─────────────────────┐
                     │ S1a: Source Quality  │
                     │   in web-researcher  │ ← Standalone, build first
                     └──────────┬──────────┘
                                │
                     ┌──────────▼──────────┐
                     │ S1b: Output-Verifier│
                     │       Agent         │ ← Needs S1a for source data
                     └──────────┬──────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                  │
   ┌──────────▼──────┐  ┌──────▼───────┐  ┌──────▼──────────┐
   │ S1c: Research   │  │ S3: Review   │  │ S5: Autoresearch│
   │   Verification  │  │ Cross-Valid  │  │   for Research  │
   └─────────────────┘  └──────────────┘  └─────────────────┘

                     ┌─────────────────────┐
                     │ S4: /phx:deslop     │ ← Independent, build anytime
                     └─────────────────────┘

                     ┌─────────────────────┐
                     │ S6: /phx:learn      │ ← Independent, build anytime
                     └─────────────────────┘
```

**Parallel tracks:**
- Track A: S2 (scratchpad) — 1-2 hours, immediate value
- Track B: S1a → S1b → S1c (research verification) — 4-6 hours, highest impact
- Track C: S4 (deslop) — 2-3 hours, can start anytime
- Track D: S6 (learn) — 2-3 hours, can start anytime

S3 and S5 are add-ons after Track B completes.

---

## Part 6: Risk Assessment

| Suggestion | Risk | Mitigation |
|------------|------|------------|
| S1 (research verification) | Adds latency to /phx:research | Make verification opt-out (`--fast` skips it). Default: verify |
| S1 (output-verifier agent) | Agent may itself hallucinate during verification | Use Sonnet (good judgment), verify against sources only (not knowledge), keep independence |
| S2 (structured scratchpad) | Template becomes stale if not maintained | Auto-populate from hook events. User never manually writes template |
| S3 (review cross-validation) | Extra pass adds tokens to parallel-reviewer | Lightweight: one read of 4 files, tag findings. ~2k tokens |
| S4 (deslop) | Cleanup introduces regressions | 4-pass regression-safe workflow with test-first. `--review` default |
| S5 (autoresearch for research) | Users don't wait for iterative verification | Cap at 3 iterations. Show progress. Make it opt-in (`--verified` flag) |
| S6 (learn) | Learned skills accumulate noise | 4 quality gates. Expire learned skills after 90 days without reuse |

---

## Part 7: Version & Release Impact

These changes would constitute a **MINOR version bump** (new features, no breaking changes):

| Suggestion | New Artifacts | Changed Artifacts |
|------------|---------------|-------------------|
| S1 | output-verifier agent, verification skill, provenance format | research SKILL.md, web-researcher.md |
| S2 | scratchpad template | check-scratchpad.sh, precompact-rules.sh, log-progress.sh |
| S3 | (none) | parallel-reviewer.md |
| S4 | deslop skill + references | (none) |
| S5 | (none) | autoresearch SKILL.md, research SKILL.md |
| S6 | learn skill + references | (none) |

**Total new files:** ~8-10 (agent + skills + references + template)
**Total changed files:** ~6-8

No breaking changes to existing workflows. All new features are additive. Verification is opt-out for speed-sensitive users.

---

## Sources

### Academic Papers
- [CoVe — Chain-of-Verification](https://arxiv.org/abs/2309.11495) (Dhuliawala et al., ACL 2024)
- [SELF-RAG](https://arxiv.org/abs/2310.11511) (Asai et al., ICLR 2024 Oral)
- [FActScore](https://arxiv.org/abs/2305.14251) (Min et al., EMNLP 2023)
- [FIRE](https://arxiv.org/abs/2411.00784) (Xie et al., NAACL 2025)
- [Self-Refine](https://arxiv.org/abs/2303.17651) (Madaan et al., NeurIPS 2023)
- [Reflexion](https://arxiv.org/abs/2303.11366) (Shinn et al., NeurIPS 2023)
- [AlphaEvolve](https://arxiv.org/abs/2506.13131) (Google DeepMind, 2025)
- [Model Collapse](https://www.nature.com/articles/s41586-024-07566-y) (Shumailov et al., Nature 2024)
- [CoALA](https://arxiv.org/abs/2309.02427) (Sumers et al., TMLR 2024)
- [DelphiAgent](https://www.sciencedirect.com/science/article/abs/pii/S0306457325001827) (2025)
- [Karpathy autoresearch](https://github.com/karpathy/autoresearch) (March 2026)

### Reference Implementations
- [Feynman](https://github.com/getcompanion-ai/feynman) — Verified: verifier.md, autoresearch.md, deepresearch.md
- [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) — Verified: ai-slop-cleaner/SKILL.md, learner/SKILL.md
