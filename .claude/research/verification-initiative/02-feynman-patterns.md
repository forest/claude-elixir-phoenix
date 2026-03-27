# Feynman Patterns — Deep Analysis

Source: [github.com/getcompanion-ai/feynman](https://github.com/getcompanion-ai/feynman)

## Overview

Feynman is a research-focused CLI agent built on Pi runtime and alphaXiv paper search. It does one thing exceptionally well: **source-grounded research with provenance tracking**. Every output is verifiable, every claim is traced to a source, and a dedicated verifier agent post-processes all outputs.

## 1. Verifier Agent

The verifier is a dedicated post-processing agent that runs AFTER every research output.

### How It Works

```
Researcher writes draft
    → Verifier receives ONLY the draft (not the original prompt)
    → Verifier checks each claim against sources
    → Verifier produces verified output + provenance sidecar
```

### Verifier Rules (verified from `.feynman/agents/verifier.md`)

From the actual verifier agent specification:

1. **Every factual claim gets at least one inline citation** — `[1]`, `[2]` placed directly after assertions. Multiple sources per claim permitted: `[7, 12]`
2. **Every URL must be fetched and confirmed** — verify the URL resolves AND contains the claimed content. Flag dead links, search for archived/mirror versions
3. **Unsupported claims are DELETED, not hedged** — if a factual assertion cannot be traced to research files, either locate a source or delete it entirely. No softening language
4. **Meaning-based validation** — citations must actually support the specific number, quote, or conclusion — not merely share topical overlap
5. **Hedged/opinion statements exempt** — only factual claims require citations
6. **Unified citation index** — merge numbering from multiple research files into single sequence starting at [1]. Deduplicate identical sources across files
7. **Preserve structure** — maintain draft structure while removing unsupported content

### Severity Classification

| Severity | Definition | Action |
|----------|-----------|--------|
| FATAL | Claim contradicts cited source | Remove claim, flag in provenance |
| MAJOR | Claim has no supporting source | Remove claim |
| MINOR | Claim is supported but imprecise | Flag for review, keep with caveat |
| INFO | Source quality is low but claim is likely correct | Keep, note source quality |

### What This Means for Us

Our agents produce output that goes directly to the user or feeds into the next workflow phase. Nobody checks if:
- A review agent's "no N+1 queries found" is actually true
- A research agent's library recommendation exists and is maintained
- A planning agent's architecture assumptions are correct
- An investigation agent's root cause analysis is based on evidence, not pattern-matching

The verifier pattern fixes this by adding a mandatory verification pass.

## 2. Provenance Tracking

Every research output produces a `.provenance.md` sidecar file.

### Provenance Sidecar Structure

```markdown
# Provenance Record

**Generated:** 2026-03-27
**Skill:** /research
**Verification Status:** VERIFIED (18/20 claims supported)

## Sources Consulted
1. [HexDocs: Phoenix.LiveView](https://hexdocs.pm/phoenix_live_view) — ACCEPTED (authoritative)
2. [ElixirForum: LiveView streams discussion](https://elixirforum.com/...) — ACCEPTED (first-party)
3. [Blog: "10 LiveView tips"](https://example.com/...) — REJECTED (no code examples, SEO content)

## Source Quality Assessment
- Tier 1 (Authoritative): 2 sources — HexDocs, GitHub source code
- Tier 2 (First-party): 1 source — ElixirForum post by core team member
- Tier 3 (Community): 0 sources
- Tier 4 (Rejected): 1 source — SEO blog with no verification

## Claim Verification Log
| # | Claim | Source | Status | Confidence |
|---|-------|--------|--------|------------|
| 1 | "LiveView streams use DOM patching" | HexDocs | VERIFIED | HIGH |
| 2 | "Streams scale to 100k items" | None | REMOVED | — |
| 3 | "assign_async requires connected? check" | HexDocs | VERIFIED | HIGH |
| ... | ... | ... | ... | ... |

## Conflicts Detected
- None

## Intermediate Files
- research/liveview-streams-raw.md (raw search results)
- research/liveview-streams-draft.md (pre-verification draft)
```

### Source Quality Hierarchy

Feynman defines explicit quality tiers for sources:

| Tier | Examples | Trust Level |
|------|----------|-------------|
| 1 — Authoritative | HexDocs, official docs, source code, academic papers | Accept by default |
| 2 — First-party | Core team blog posts, conference talks, ElixirForum posts by maintainers | Accept with citation |
| 3 — Community | ElixirForum community posts, Stack Overflow, established blogs with code examples | Accept if corroborated |
| 4 — Low quality | SEO listicles, AI-generated tutorials, posts without code examples | Reject unless corroborated by Tier 1-2 |
| 5 — Rejected | Paywalled without preview, dead links, obvious AI slop | Always reject |

### What This Means for Us

Our `/phx:research` produces output with no provenance. The user cannot tell:
- Which HexDocs pages were actually consulted
- Whether a recommendation is based on official docs or a random blog post
- Whether conflicting information was found and how it was resolved
- What was searched but rejected

Adding provenance sidecars to research output (and review output) makes our plugin's knowledge work auditable.

## 3. Autoresearch Loop

Feynman's `/autoresearch` (verified from `prompts/autoresearch.md`) is a 4-phase autonomous experiment system: "try ideas, measure results, keep what works, discard what doesn't, repeat."

### Four-Phase Process

**Phase 1: Gather** — Collect optimization target, benchmark command, metric details (name/unit/direction), affected files, and iteration limit (default: 20). Resume existing sessions if `autoresearch.md` and `autoresearch.jsonl` exist.

**Phase 2: Environment** — Select execution context: Local, new git branch, virtual environment, Docker, Modal (serverless GPU), or RunPod (persistent GPU). Requires explicit user selection.

**Phase 3: Confirm** — Present full plan covering target metric, benchmark command, file scope, environment choice, and max iterations. Requires explicit user approval.

**Phase 4: Run** — Execute iterative cycle: initialize session → run baseline → loop through edit → commit → benchmark → log → keep/revert decisions. Update `CHANGELOG.md` at milestones.

### Key Design Decisions

1. **Metrics tracked with three tools** — `init_experiment`, `run_experiment` (captures output + execution time), `log_experiment` (records results + auto-commits)
2. **Direction specified** — optimize toward lower or higher values
3. **Revert is automatic** — keep successful iterations, discard unsuccessful ones
4. **Max iterations configurable** — default 20, prevents infinite loops
5. **Subcommands** — `/autoresearch <text>` (start/resume), `/autoresearch off` (stop), `/autoresearch clear` (reset)
6. **Execution environments are pluggable** — local, Docker, Modal, RunPod

### Differences from Our /phx:autoresearch

| Aspect | Our Current | Feynman's Approach |
|--------|------------|-------------------|
| Scope | Code quality metrics (credo, coverage, warnings) | Any measurable metric |
| Mutation source | LLM proposes edits | LLM proposes edits (same) |
| Evaluation | mix commands | Any command/script |
| Revert strategy | git checkout on failure | git stash + pop |
| History tracking | JSONL (we added this) | JSONL (same) |
| Research re-search | No | Yes — if sources conflict, search again with refined query |

### The "Re-search on Conflict" Pattern

When Feynman's researcher finds contradictory information, it doesn't just report both sides. It:
1. Identifies the specific contradiction
2. Formulates a targeted search query to resolve it
3. Searches for authoritative sources that address the specific disagreement
4. Only then reports the finding, with the resolution attempt documented

This is the most valuable pattern for improving our `/phx:research`.

## 4. CHANGELOG as Lab Notebook

Feynman uses `CHANGELOG.md` not as release notes but as a chronological lab notebook:

```markdown
## 2026-03-27

### Tried
- Switched from cosine similarity to BM25 for paper search
- Added citation deduplication in verifier

### Failed
- BM25 performed worse on long queries (>50 tokens) — reverted
- Dedup by DOI missed papers with different DOI formats

### Verified
- Verifier catch rate: 94% on synthetic hallucination dataset
- Search latency improved 2.3x with cached embeddings

### Decisions
- Keep cosine similarity for now, add BM25 as fallback for short queries
- Use normalized DOI + title fuzzy match for dedup

### Next
- Test hybrid search (cosine + BM25 fusion)
- Add ORCID-based author disambiguation
```

### What This Means for Us

Our `scratchpad.md` is already a lab notebook but less structured. The key improvement: explicit sections for **Tried**, **Failed**, **Verified**, **Decisions**, **Next**. This structure:
- Prevents repeating failed approaches (what Reflexion paper calls "episodic memory")
- Survives compaction (explicit structure is easier to compress without losing info)
- Enables resume detection (the `Next` section is the resumption point)

## 5. Deep Research: 8-Phase Verified Workflow

Feynman's `/deepresearch` (verified from `prompts/deepresearch.md`) operates in 8 sequential phases:

1. **Planning** — Structured research strategy with key questions, evidence types, acceptance criteria. Save to `outputs/.plans/<slug>.md`
2. **Scale Decision** — Single facts bypass subagents (3-10 tool calls). Broad surveys: 3-4 parallel researchers. Complex multi-domain: 4-6 researchers
3. **Parallel Research** — Each researcher gets: clear objective, output format, tool guidance, task boundaries (prevent duplication), specific ledger task IDs. Blocked/superseded work gets explicit notation — no silent drops
4. **Iterative Evaluation** — Read outputs, identify gaps/contradictions/single-source claims. Loop with targeted follow-up rounds until evidence sufficiency threshold met
5. **Synthesis & Drafting** — Lead researcher (not delegated) writes brief grounding claims in verification log. Generate charts via pi-charts for quantitative findings
6. **Inline Citation** — Verifier agent adds inline citations, builds numbered Sources section, verifies all URLs
7. **Verification Review** — Reviewer flags: unsupported claims, logical gaps, single-source dependencies, confidence-evidence mismatches. FATAL → fix + re-review, MAJOR → Open Questions, MINOR → logged
8. **Delivery & Provenance** — Final output + provenance sidecar recording: round count, sources consulted, verification status, research file locations

### Key Quality Controls
- **Task Ledger:** ownership, status, output for each research dimension
- **Verification Log:** maps critical claims to verification method
- **Decision Log:** chronological record of choices and findings
- **Unresolved contradictions** populate "Open Questions" section
- **Single-source claims on critical findings** trigger additional research or downgrade to inference status

## 6. Context Hygiene — File-Based Working Memory

Feynman's agents NEVER pass full content through the agent chain. Instead:

```
Researcher → writes findings to disk → passes file PATH to verifier
Verifier → reads file, writes verified version → passes file PATH to formatter
```

This means:
- Each agent's context window stays clean
- Large research outputs don't bloat parent context
- Intermediate artifacts are preserved for debugging

### What This Means for Us

Our `context-supervisor` pattern already does this for multi-agent orchestration. But some workflows still pass content directly (e.g., review findings → plan creation). Enforcing file-based handoff everywhere would improve context efficiency.
