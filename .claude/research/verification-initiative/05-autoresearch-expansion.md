# Autoresearch Expansion — Beyond Code Metrics

How autoresearch loops apply to research, verification, planning, and skill improvement.

## Current State of Our /phx:autoresearch

Our existing `/phx:autoresearch` (added in v2.4.0) follows Karpathy's pattern for **code quality metrics**:

```
REPEAT until metric improves OR max iterations:
  1. LLM proposes edit (autoresearch-proposer agent)
  2. Apply edit
  3. Run metric command (mix credo, mix test --cover, mix compile)
  4. Log result to JSONL
  5. Keep or revert based on metric
  6. Next iteration reads history to avoid repeating failures
```

This works well for:
- Reducing Credo issues (`mix credo --strict` issue count)
- Improving test coverage (`mix test --cover` percentage)
- Eliminating compile warnings (`mix compile --warnings-as-errors` count)

## Expansion: Autoresearch for Research Quality

**Idea:** Apply the autoresearch loop to improve RESEARCH output quality, not just code quality.

### How It Would Work

```
BASELINE: Run /phx:research on topic → get initial brief
METRIC: Verification score (claims verified / total claims)

REPEAT:
  1. Verifier checks brief → identifies unverified claims
  2. For each unverified claim:
     a. Search for supporting evidence with refined query
     b. If evidence found: add citation, mark VERIFIED
     c. If no evidence: REMOVE claim
  3. Log: { iteration, verified_count, removed_count, total_claims }
  4. IF verification_score >= 0.9: DONE
  5. IF no unverified claims remain: DONE
  6. ELSE: check if removed claims left gaps → search for replacement content
```

### The "Re-search on Conflict" Pattern (from Feynman)

When the autoresearch loop finds contradictory information:

1. Identify the specific contradiction
2. Formulate a targeted search query to resolve it
3. Search for authoritative (T1/T2) sources that address the disagreement
4. Only then report the finding, with resolution attempt documented
5. If unresolved: flag as "Open Question" with both positions cited

This is fundamentally different from our current approach where `/phx:research` does one search pass and reports whatever it finds.

### Metric: Research Quality Score

```
research_quality = (
  verified_claims / total_claims * 0.4 +     # Verification rate
  t1_t2_sources / total_sources * 0.3 +       # Source quality
  resolved_conflicts / total_conflicts * 0.2 + # Conflict resolution
  (1 - removed_claims / initial_claims) * 0.1  # Retention rate
)
```

Target: 0.85+ for any research output.

## Expansion: Autoresearch for Review Quality

**Idea:** Apply the loop to improve review finding accuracy.

### How It Would Work

```
BASELINE: Run /phx:review → get findings
METRIC: Finding accuracy (confirmed findings / total findings)

REPEAT:
  1. For each finding:
     a. Re-read the code section mentioned
     b. Verify the issue actually exists
     c. If confirmed: mark VERIFIED
     d. If false positive: REMOVE
  2. Log: { iteration, confirmed, false_positives, total }
  3. IF accuracy >= 0.95: DONE
  4. For removed findings: check if there's a REAL issue we missed
```

### Why This Matters

From our 137-session analysis, review agents occasionally produce findings that don't match reality — "this code has an N+1 query" when it actually uses preloads correctly. A verification loop catches these before the user acts on them.

## Expansion: Autoresearch for Skill Descriptions

**We already do this** via our eval framework's behavioral dimension + trigger_scorer.py. But we can formalize it:

```
BASELINE: Current skill description
METRIC: Trigger accuracy (correct routing / total test cases)

REPEAT:
  1. Run trigger_scorer.py against test cases
  2. Identify misrouted cases
  3. Propose description edit to fix misrouting
  4. Re-run trigger_scorer.py
  5. Keep if accuracy improved, revert if not
```

This is exactly what `/phx:autoresearch` does for Credo issues but applied to our own plugin's skill descriptions.

## Expansion: Autoresearch for Performance

**Idea:** `/phx:bench` — autonomous Ecto query or LiveView render optimization.

### How It Would Work

```
USER: /phx:bench "optimize Repo.all(User) query in UserContext"
BASELINE: Run benchmark → capture timing

REPEAT:
  1. Analyze query plan (EXPLAIN ANALYZE via Tidewave)
  2. Propose optimization (index, preload strategy, query restructure)
  3. Apply change
  4. Run benchmark → capture timing
  5. Log: { iteration, query_time_ms, approach }
  6. Keep if faster, revert if slower
  7. Read history to avoid repeating failed approaches
```

### Metrics for Performance Autoresearch

| Metric | Source | Direction |
|--------|--------|-----------|
| Query execution time | `EXPLAIN ANALYZE` via Tidewave SQL | Lower is better |
| Memory usage | `:recon_alloc.memory(:allocated)` | Lower is better |
| LiveView diff size | Process info / socket assigns | Lower is better |
| Response time | `mix test` timing or benchee | Lower is better |

## Key Design Principles (from papers)

### 1. Deterministic Evaluation (AlphaEvolve)
Every autoresearch loop needs a deterministic, machine-checkable fitness function. "Is this research better?" is subjective. "What percentage of claims have citations?" is deterministic.

### 2. Diminishing Returns (Self-Refine)
Cap at 2-3 iterations for most loops. The first iteration catches 60-80% of issues. After 3 iterations, remaining issues are in the model's blind spot — escalate to human review or a different model.

### 3. Episodic Memory (Reflexion)
Every iteration's result feeds into the next iteration's context. The JSONL log IS the episodic memory. Failed approaches are explicitly marked to prevent repetition.

### 4. Time-Boxing (Karpathy autoresearch)
Each iteration has a time budget. For research: max 2 minutes of searching per unverified claim. For performance: max 5 minutes of benchmarking per iteration. Prevents runaway costs.

### 5. Revert-First (Feynman + Karpathy)
If an iteration doesn't measurably improve the metric, revert immediately. Don't accumulate uncertain changes hoping they'll compound.

## Implementation Priority

| Expansion | Value | Difficulty | Dependencies |
|-----------|-------|------------|--------------|
| Research quality loop | Very high | Medium | Verifier agent, provenance tracking |
| Review accuracy loop | High | Low | Verifier agent |
| Skill description optimization | Already exists | — | eval framework |
| Performance benchmark loop | Medium | High | Tidewave, benchee, EXPLAIN ANALYZE |

**Recommendation:** Start with research quality loop — it combines autoresearch + verifier + provenance in one coherent feature. The review accuracy loop is a lightweight addition once the verifier exists.
