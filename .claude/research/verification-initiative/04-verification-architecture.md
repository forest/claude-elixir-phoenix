# Verification Architecture — Mapping to Our Plugin

How verification applies across our 40 skills, 20 agents, and 20 hooks.

## The Gap

Our plugin has excellent **code-level verification**:
- PostToolUse hooks: `mix format`, `mix compile`, Iron Law checks
- PostToolUseFailure: error critic with structured analysis
- verification-runner agent: compile + format + credo + test + dialyzer
- Iron Laws: 22 rules enforced at edit-time

What we **don't** verify:
- Agent output claims ("no N+1 queries found" — is that actually true?)
- Research findings ("this library supports X" — does it?)
- Review recommendations ("refactor to use streams" — is that the right pattern here?)
- Planning assumptions ("this will need 3 context modules" — based on what?)
- Investigation conclusions ("root cause is X" — evidence?)

## Verification Opportunity Map

### Tier 1: High-Value, High-Impact (implement first)

| Skill/Agent | Current Output | Unverified Claims | Verification Method |
|-------------|---------------|-------------------|-------------------|
| `/phx:research` | Research brief | Library exists, is maintained, supports claimed features | Verify hex.pm page exists, check latest version date, verify feature in docs |
| `web-researcher` | Research findings | URLs resolve, content matches claims | URL resolution check, content re-read |
| `/phx:review` | Review findings | Code actually has the issue described | Re-read code, grep for the pattern, run targeted test |
| `parallel-reviewer` | 4-track review | Each finding is real, not hallucinated | Cross-validate findings between tracks |
| `/phx:investigate` | Root cause analysis | Root cause is correct, evidence supports it | Reproduce with minimal test, verify stack trace matches |
| `planning-orchestrator` | Architecture plan | Assumptions about existing code are correct | Verify file existence, module structure, function signatures |

### Tier 2: Medium-Value (implement second)

| Skill/Agent | Current Output | Unverified Claims | Verification Method |
|-------------|---------------|-------------------|-------------------|
| `/phx:plan` | Implementation plan | Task estimates are reasonable, dependencies correct | Verify file paths exist, check module interfaces |
| `/phx:compound` | Solution documentation | Fix pattern is correct and generalizable | Re-run the test that proved the fix, check for edge cases |
| `/phx:audit` | Health report | Metrics and findings are accurate | Re-run specific checks that audit claims |
| `ecto-schema-designer` | Schema design | Proposed schema handles all cases | Verify against test data, check constraint coverage |
| `liveview-architect` | Component architecture | Performance claims, stream recommendations | Verify list sizes justify streams, check assign_async usage |

### Tier 3: Lower-Value (implement if resources allow)

| Skill/Agent | Current Output | Unverified Claims | Verification Method |
|-------------|---------------|-------------------|-------------------|
| `/phx:quick` | Small change | Change doesn't break anything | Already verified by mix compile/test |
| `/phx:verify` | Verification results | Results are complete | Already deterministic (mix commands) |
| `/phx:work` | Code changes | Code matches plan | Already verified by PostToolUse hooks |
| `context-supervisor` | Compressed summary | Summary preserves key information | Compare against source artifacts |

## Verifier Agent Design

Based on Feynman's verifier + CoVe + FIRE papers:

### Architecture

```
Any agent/skill produces output
    ↓
Output saved to file (artifact)
    ↓
Verifier agent receives:
  - The artifact (NOT the original prompt)
  - The sources/evidence used
  - Verification rules for this output type
    ↓
Verifier produces:
  - Verified artifact (claims removed/flagged)
  - Provenance sidecar (.provenance.md)
  - Confidence scores per claim
```

### Key Design Decisions

1. **Independence from generator** (CoVe principle): Verifier never sees the original user request or generation prompt. Only sees the output and its cited sources. This prevents confirmation bias.

2. **Iterative, not batch** (FIRE principle): Verify claims iteratively — confident claims pass quickly, uncertain claims get targeted re-search. This is 7.6x cheaper than verifying everything at the same depth.

3. **Atomic claims** (FActScore principle): Decompose output into individual claims before verifying. A review finding like "The user controller has 3 N+1 queries in the index action" has 3 atomic claims: (a) user controller exists, (b) index action exists, (c) there are N+1 queries in it.

4. **Severity-based action** (Feynman pattern):
   - FATAL: Claim contradicts source → **REMOVE** claim
   - MAJOR: Claim has no source → **REMOVE** claim
   - MINOR: Claim is imprecise → **FLAG** with caveat
   - INFO: Low confidence but likely correct → **KEEP** with note

5. **File-based handoff** (context hygiene): Verifier reads/writes artifacts on disk, never passes full content through the agent chain.

### Agent Specification (draft)

```yaml
---
name: output-verifier
description: >
  Post-processes agent/skill output to verify claims, remove unsupported
  assertions, and produce provenance sidecars. Use automatically after
  research, review, investigation, and planning outputs.
tools: Read, Grep, Glob, Bash, Write
disallowedTools: Edit, NotebookEdit
permissionMode: bypassPermissions
model: sonnet
effort: medium
skills:
  - compound-docs
---
```

The verifier should be **sonnet** (not haiku) because claim verification requires judgment, not just mechanical processing. It needs Write access to produce the verified artifact and provenance sidecar.

### Provenance Sidecar Format

```markdown
# Provenance: {artifact-name}

**Generated:** {date}
**Source skill:** {skill-name}
**Verification status:** {VERIFIED|PARTIAL|UNVERIFIED}
**Claims verified:** {n}/{total}

## Sources Consulted
| # | Source | Type | Tier | Status |
|---|--------|------|------|--------|
| 1 | HexDocs: Phoenix.LiveView | Official docs | T1 | ACCEPTED |
| 2 | ElixirForum post #12345 | Community | T3 | ACCEPTED (corroborated) |
| 3 | blog.example.com/liveview | Blog | T4 | REJECTED (no code examples) |

## Source Quality Tiers
- **T1 Authoritative:** HexDocs, GitHub source, academic papers, official docs
- **T2 First-party:** Core team posts, conference talks, maintainer blogs
- **T3 Community:** ElixirForum, SO, established blogs with code examples
- **T4 Low quality:** SEO content, AI-generated, no verification
- **T5 Rejected:** Dead links, paywalled, obvious fabrication

## Claim Verification Log
| # | Claim | Source | Status | Confidence |
|---|-------|--------|--------|------------|
| 1 | "LiveView streams use DOM patching" | [1] HexDocs | VERIFIED | HIGH |
| 2 | "Streams scale to 100k items" | — | REMOVED (no source) | — |
| 3 | ... | ... | ... | ... |

## Removed Claims
- "Streams scale to 100k items" — no source found, removed per MAJOR severity rule

## Conflicts Detected
- None (or: "Source [1] says X, Source [2] says Y — resolution: ...")
```

## Where Verification Hooks Into the Plugin

### Automatic Verification Points

These outputs should ALWAYS be verified:

1. **After `/phx:research`** — every research brief gets a provenance sidecar
2. **After `web-researcher` agent** — URL resolution + content match
3. **After `/phx:review`** parallel-reviewer — cross-validate findings
4. **After `/phx:investigate`** — verify root cause evidence
5. **After `/phx:plan` with `--existing`** (research-enhanced) — verify research fed into plan
6. **After `/phx:compound`** — verify the fix pattern before storing in solution library

### Optional Verification Points

These could benefit from verification but aren't critical:

- After `/phx:audit` — verify health metrics
- After `planning-orchestrator` — verify architecture assumptions
- After `ecto-schema-designer` — verify schema handles edge cases

### Implementation: PostToolUse Hook vs. Inline Agent Call

Two approaches:

**Option A: PostToolUse hook (automatic, always runs)**
- Hook detects when an agent writes to `research/`, `reviews/`, `plans/`
- Spawns verifier agent automatically
- Pro: Never forgotten. Con: Adds latency to every workflow step

**Option B: Inline in workflow skills (explicit, skill decides)**
- Each skill's SKILL.md includes a "Verify" step that calls the verifier
- Pro: More control, only runs when needed. Con: Can be skipped

**Recommendation: Option B with Option A as safety net.** Skills explicitly call the verifier at the right point in their workflow. A lightweight PostToolUse hook catches outputs that weren't verified and logs a warning.

## Integration with Existing Patterns

### Context-Supervisor + Verifier

Current flow:
```
Orchestrator → N sub-agents → context-supervisor (compress) → Orchestrator reads summary
```

New flow:
```
Orchestrator → N sub-agents → verifier (verify each) → context-supervisor (compress verified) → Orchestrator reads summary
```

### Review + Verification

Current `/phx:review` flow:
```
parallel-reviewer → 4 specialist agents → reviews/ directory → user reads
```

New flow:
```
parallel-reviewer → 4 specialist agents → verifier (cross-validate) → reviews/ + .provenance.md → user reads verified findings
```

### Research + Verification

Current `/phx:research` flow:
```
web-researcher → raw findings → synthesis → brief → user reads
```

New flow:
```
web-researcher → raw findings → synthesis → draft brief → verifier (cite + verify) → verified brief + .provenance.md → user reads
```
