# Implementation Priorities — Roadmap with Reasoning

## Priority Ranking

### P0: Output Verifier Agent + Provenance Tracking
**Why first:** This is the foundation everything else builds on. Without verification, autoresearch on research quality has no metric. Without provenance, the user can't trust outputs.

**Scope:**
- New agent: `output-verifier` (sonnet, ~250 lines)
- New provenance sidecar format (`.provenance.md`)
- Source quality tier system (T1-T5)
- Severity classification (FATAL/MAJOR/MINOR/INFO)
- Claim decomposition and verification logic

**Integration points:**
- After `/phx:research` output (automatic)
- After `web-researcher` agent output (automatic)
- After `/phx:review` parallel-reviewer output (automatic)
- After `/phx:investigate` root cause analysis (automatic)

**Scientific basis:**
- CoVe: Independent verification reduces hallucination ([arXiv:2309.11495](https://arxiv.org/abs/2309.11495))
- FActScore: Atomic claim verification is more reliable than holistic checks ([arXiv:2305.14251](https://arxiv.org/abs/2305.14251))
- FIRE: Iterative verification is 7.6x cheaper than batch verification ([arXiv:2411.00784](https://arxiv.org/abs/2411.00784))

**Estimated artifacts:**
- `plugins/elixir-phoenix/agents/output-verifier.md` (~250 lines)
- New skill: `verification/SKILL.md` (~100 lines) with references
- Hook: PostToolUse addition for write to `research/`, `reviews/`, `plans/research/`

**Risk:** Latency. Verification adds a step to every workflow. Mitigation: FIRE's iterative approach — confident claims pass fast, only uncertain claims get deep verification.

### P1: Enhanced /phx:research with Verification Loop
**Why second:** Research is where hallucination risk is highest — the agent searches the web and synthesizes findings with no ground truth check. This is the highest-value application of the verifier.

**Scope:**
- Update `research` skill to include verification step
- Add "re-search on conflict" pattern (from Feynman)
- Source quality tiers integrated into web-researcher agent
- Provenance sidecar auto-generated for all research output
- Optional autoresearch loop for research quality improvement

**Enhancements over current `/phx:research`:**
1. Every claim gets a citation or gets removed
2. Source quality is assessed (HexDocs T1 > random blog T4)
3. Contradictions trigger targeted re-search, not just reporting both sides
4. Dead URLs are caught and replaced
5. Research output includes provenance sidecar showing what was consulted vs. rejected

**Scientific basis:**
- Feynman's 8-phase deep research with inline citation and verification review
- SELF-RAG: Self-reflective tokens for claim-source assessment ([arXiv:2310.11511](https://arxiv.org/abs/2310.11511))
- Self-Refine: Iterative improvement with self-feedback, ~20% improvement across tasks ([arXiv:2303.17651](https://arxiv.org/abs/2303.17651))

**Estimated artifacts:**
- Updated `plugins/elixir-phoenix/skills/research/SKILL.md`
- Updated `plugins/elixir-phoenix/agents/web-researcher.md`
- New reference: `research/references/verification-workflow.md`

### P2: Structured Lab Notebook (Scratchpad Enhancement)
**Why third:** The scratchpad already exists but is unstructured. Adding structure costs almost nothing and provides immediate value for session resume, compaction survival, and debugging loop prevention.

**Scope:**
- Define structured sections: Hypotheses Tested, Dead Ends, Decisions Made, Open Questions, Handoff Notes
- Update `check-scratchpad.sh` hook to read structured sections
- Update `precompact-rules.sh` to preserve structured sections during compaction
- Update `check-resume.sh` to read Handoff Notes for smart resume

**Structured format:**
```markdown
## Session: {date}T{time}

### Hypotheses Tested
1. [pass] Description of hypothesis that was verified
2. [fail] Description of hypothesis that was disproved — WHY: reason

### Dead Ends (DO NOT RETRY)
- Approach X — caused regression Y (evidence: test file Z)
- Approach W — Ecto doesn't support it for embeds (checked docs)

### Decisions Made
- Decision A — because of constraint B
- Decision C — chose over alternative D because E

### Open Questions
- Question 1 (untested, medium priority)
- Question 2 (unknown performance impact)

### Handoff Notes
- Branch: feature/xyz
- Status: 3/7 tasks complete, blocked on Q1 above
- Next step: implement task 4 after resolving Q1
```

**Scientific basis:**
- Reflexion: Episodic memory (recording WHY things failed) enables 91% vs 80% improvement ([arXiv:2303.11366](https://arxiv.org/abs/2303.11366))
- OMC's notepad-wisdom: Structured Dead Ends section prevents debugging loops
- Feynman's CHANGELOG: Chronological lab notebook with Tried/Failed/Verified/Decisions/Next

**Estimated artifacts:**
- Template: `.claude/templates/scratchpad-template.md`
- Updated hooks: `check-scratchpad.sh`, `precompact-rules.sh`, `check-resume.sh`
- Updated SessionStart hook to initialize structured scratchpad

### P3: AI Slop Cleaner (/phx:deslop)
**Why fourth:** Valuable post-implementation cleanup, but lower urgency than verification (which prevents bad output from being produced in the first place).

**Scope:**
- New skill: `/phx:deslop` with 5-category classification and 4-pass regression-safe workflow
- Categories adapted for Elixir/Phoenix:
  1. Dead code: unused `handle_event`, orphan context functions, stale module attributes
  2. Duplication: identical changeset validations, repeated query patterns
  3. Needless abstraction: single-use wrapper modules, unnecessary GenServer
  4. Boundary violations: Repo calls in LiveView, business logic in controllers
  5. Missing tests: new functions without test coverage
- `--review` mode for identification only (no changes)
- Integration with Iron Laws (boundary violations overlap with existing rules)

**Scientific basis:**
- OMC's AI Slop Cleaner: 5-category classification + 4-pass regression-safe workflow
- Model Collapse (Shumailov et al., Nature 2024): AI-on-AI training degrades quality — slop cleaner breaks the feedback loop
- Self-Refine: Test-first approach ensures cleanup doesn't introduce regressions

**Estimated artifacts:**
- New skill: `plugins/elixir-phoenix/skills/deslop/SKILL.md` (~100 lines)
- New reference: `deslop/references/categories.md`, `deslop/references/workflow.md`
- Could reuse `iron-law-judge` agent for boundary violation detection

### P4: Skill Learner Enhancement (/phx:learn)
**Why fifth:** Valuable for long-term knowledge accumulation, but the existing `/phx:compound` covers the most critical use case (fix documentation). The learner adds heuristic capture on top.

**Scope:**
- Implement reserved `/phx:learn` skill
- Quality gates from OMC: Non-Googleable + Codebase-Specific + Hard-Won
- Store in `.claude/skills/learned/` (project-scoped, version-controlled)
- Auto-load learned skills based on file patterns (like existing skill auto-loading)
- Distinction from compound-docs: heuristics vs. fix recipes

**Saved skill structure:**
```markdown
# Learned: {title}

**Context:** {project-specific context}
**Problem:** {symptoms observed}
**Root Cause:** {why this happens in this codebase}
**Fix Pattern:** {what to do when you see this}

**Evidence:**
- File: {file where discovered}
- Session: {date}
- Verified: {yes/no}
```

**Scientific basis:**
- Voyager: Verified skill library enables capability accumulation ([NeurIPS 2023](https://arxiv.org/abs/2305.16291))
- OMC Learner: Quality gates prevent noise in skill library
- Reflexion: Episodic → semantic memory conversion (learned patterns)

**Estimated artifacts:**
- New skill: `plugins/elixir-phoenix/skills/learn/SKILL.md` (~100 lines)
- New reference: `learn/references/quality-gates.md`
- Hook addition: auto-load from `.claude/skills/learned/` matching file patterns

### P5: Autoresearch for Research Quality
**Why last in initial wave:** Requires P0 (verifier) and P1 (enhanced research) to exist first. This is the capstone that ties verification + autoresearch together.

**Scope:**
- Extend existing `/phx:autoresearch` to support research quality as a metric
- Metric: verification score (verified claims / total claims)
- Loop: research → verify → re-search unverified → verify → done
- Cap at 3 iterations (Self-Refine diminishing returns)

## Phased Rollout

### Phase 1: Foundation (P0 + P2)
- Output verifier agent + provenance tracking
- Structured lab notebook
- These are independent and can be built in parallel
- Combined, they establish the verification infrastructure and episodic memory

### Phase 2: High-Value Applications (P1 + P3)
- Enhanced research with verification
- AI slop cleaner
- Both use the verifier from Phase 1
- Can be built in parallel

### Phase 3: Knowledge Accumulation (P4 + P5)
- Skill learner
- Autoresearch for research quality
- Build on all previous phases

## What We're NOT Building

- **Model routing / dynamic model selection** (from OMC) — Our static model assignment in agent frontmatter is simpler and sufficient. Dynamic routing adds complexity without clear benefit for our domain-specific agents.
- **Visual verdict / screenshot comparison** (from OMC) — Nice for LiveView UI but requires browser automation MCP that not all users have. Could revisit later.
- **Notification system** (from OMC) — Slack/Discord notifications for long runs. Nice-to-have but orthogonal to quality.
- **Academic paper search** (from Feynman) — Domain-specific to research. Not relevant for Phoenix development.
- **Docker/Modal/RunPod execution** (from Feynman autoresearch) — Our autoresearch runs locally via mix commands. Remote execution adds unnecessary complexity.

## Success Metrics

| Initiative | Metric | Target | How to Measure |
|-----------|--------|--------|----------------|
| Verifier | Claims with citations in research output | 90%+ | Provenance sidecar stats |
| Verifier | False positives in review findings | <10% | Manual spot-check of verified reviews |
| Lab notebook | Session resume time saved | 50%+ less re-discovery | Compare with/without structured scratchpad |
| Deslop | Code reduction per cleanup | 10-20% line reduction | git diff --stat before/after |
| Research quality | Source quality distribution | 60%+ T1/T2 sources | Provenance sidecar tier counts |
| Skill learner | Learned skills reuse rate | 30%+ applied in future sessions | Track skill loads from learned/ |
