# Shaping Skills Plugin Analysis

## Source

Repository: https://github.com/rjs/shaping-skills
Author: rjs
Case study: [Shaping 0-1 with Claude Code](https://x.com/rjs/status/2020184079350563263) / [rjs/tick](https://github.com/rjs/tick)

## What It Is

A Claude Code skills plugin implementing the **Shape Up methodology** (from Basecamp) adapted for LLM-assisted development. It provides three skills:

1. **`/shaping`** (~594 lines) — Collaborative problem/solution exploration with structured notation
2. **`/breadboarding`** (~654 lines) — System mapping via affordance tables and wiring diagrams
3. **`/breadboard-reflection`** (~127 lines) — Design smell detection and naming tests for breadboards

Plus a **ripple-check hook** that fires on Write/Edit to shaping documents.

## Architecture Comparison

| Aspect | Shaping Skills | Our Plugin |
|--------|---------------|------------|
| **Focus** | Pre-implementation thinking (problem → shape → slice) | Full lifecycle (plan → work → review → compound) |
| **Planning model** | Human-driven iteration with structured notation | Agent-driven parallel research + synthesis |
| **Decomposition** | Requirements (R) × Shapes (S) → Fit Check → Breadboard → Slices | Feature → specialist agents → compressed research → tasks |
| **Decision making** | Binary fit check matrix (✅/❌) per requirement × shape | Decision council (3 agents) for contested decisions |
| **State tracking** | Document hierarchy (frame → shaping doc → slices → plans) | Filesystem (plan.md checkboxes → progress.md → scratchpad.md) |
| **Hooks** | Ripple-check on shaping docs (frontmatter-gated) | Format + compile + progress + security + plan STOP |
| **Skills count** | 3 | 38 |
| **Agent count** | 0 | 20 |
| **Model usage** | None specified | opus/sonnet/haiku tiered |

## Valuable Ideas to Adopt

### 1. Fit Check Matrix (High Value)

**What they do:** A structured R × S decision matrix where requirements are rows, solution shapes are columns, and each cell is binary ✅/❌ with notes explaining failures.

```markdown
| Req | Requirement | Status | A | B | C |
|-----|-------------|--------|---|---|---|
| R0 | Searchable from index | Core | ✅ | ✅ | ✅ |
| R1 | Survives refresh | Must | ✅ | ❌ | ✅ |
```

**What we do:** Technical Decisions table (Decision/Choice/Rationale) — less systematic, no cross-comparison.

**Opportunity:** Add a fit-check step to `/phx:plan` when the decision council identifies 2+ competing approaches. Instead of just spawning 3 agents to argue, also produce a fit-check grid showing which approach satisfies which requirements. This makes trade-offs visible at a glance.

### 2. Explicit Problem/Solution Separation (Medium Value)

**What they do:** Strict separation between R (requirements — what's needed) and S (shapes — how to build it). Requirements must be standalone, not dependent on any specific shape. Parts must be mechanisms, not intentions.

**What we do:** Planning mixes problem understanding with solution generation. Research agents gather context and the plan immediately proposes tasks.

**Opportunity:** Add an explicit "Requirements Extraction" step before task generation in `/phx:plan`. For complex features, first enumerate the Rs (what must be true), THEN generate the plan (how to achieve them). This catches missing requirements early.

### 3. Breadboarding for System Understanding (Medium Value)

**What they do:** Formal system mapping with Places (bounded interaction contexts), UI/Code affordances, and explicit wiring (control flow vs data flow). Tables are truth, diagrams render them.

**What we do:** Our planning references breadboarding for "multi-page features" but doesn't formalize it. Investigation traces code paths but doesn't produce reusable system maps.

**Opportunity:** Enhance `/phx:investigate` or create a `/phx:map` skill that produces affordance-style system maps for complex LiveView flows. Particularly useful for:
- Multi-LiveView navigation flows
- PubSub message routing
- Channel/Presence wiring
- Oban job chains

### 4. Ripple-Check Hook Pattern (Medium Value)

**What they do:** A PostToolUse hook that fires on Write/Edit, checks if the file has `shaping: true` frontmatter, and reminds Claude to update related documents.

**What we do:** Our hooks format code, compile, log progress, and remind about Iron Laws. But we don't have document-consistency checking.

**Opportunity:** Add a ripple-check to our plan ecosystem. When `plan.md` is edited, remind about:
- Progress.md consistency
- Scratchpad.md needs updating
- Review findings still valid?
- Related plans affected?

### 5. Vertical Slicing Discipline (High Value)

**What they do:** Strict rules for slicing: every slice must be demo-able (has visible UI), max 9 slices, each slice demonstrates a mechanism working. "A slice without UI is a horizontal layer."

**What we do:** Plans generate phased tasks grouped by pattern, but no explicit "demo-ability" requirement.

**Opportunity:** Add a slicing verification step to `/phx:plan` output:
- Each phase should have a demo statement: "After this phase, you can show X"
- Flag phases that are purely backend with no observable output
- Suggest reordering to ensure each phase delivers visible progress

### 6. Multi-Level Document Consistency (Low-Medium Value)

**What they do:** Explicit hierarchy (Frame → Shaping Doc → Slices → Plans) with bidirectional ripple rules. Changes at any level must propagate up/down.

**What we do:** Plan → work → review → compound, but no formal consistency checking between artifacts.

**Opportunity:** This is mostly handled by our checkpoint system (checkboxes in plan.md ARE the state). Lower priority.

### 7. Source Material Capture (Low Value)

**What they do:** Verbatim capture of user requests, quotes, stakeholder messages in a "Source" section.

**What we do:** Scratchpad captures decisions and dead-ends, but not the original request verbatim.

**Opportunity:** Auto-capture the user's initial feature description in `plans/{slug}/plan.md` as a Source section. Useful for long sessions where the original intent gets lost after context compaction.

### 8. Naming Test for Design Smells (Medium Value)

**What they do:** `/breadboard-reflection` provides a systematic way to find design problems: "Can you name each function with ONE idiomatic verb?" If you need "or" to connect two verbs, it's two functions bundled together.

**What we do:** Review agents find code smells, but no structured naming test.

**Opportunity:** Add to our Elixir review agent's checklist:
- For each new function: can it be named with one verb?
- Need "or" → suggest splitting
- Name matches downstream effect, not this step → suggest renaming

## Ideas NOT to Adopt

### 1. No Agents / No Automation

Shaping Skills is entirely human-driven — Claude assists but never spawns sub-agents. This is a deliberate philosophical choice (human thinks, Claude helps) but our plugin's parallel agent architecture is more powerful for development tasks.

### 2. Mermaid Diagrams as Primary Output

They generate extensive Mermaid diagrams. These look nice but aren't actionable for code generation. Our plan checkboxes → executable tasks flow is more useful for actual development.

### 3. Shape Letter Notation (A, B, C...)

Their notation system (R0, R1... for requirements; A, B, C... for shapes; C1, C2... for parts; C3-A, C3-B... for alternatives) is well-designed but only valuable for extended shaping sessions. Our decision council handles this more efficiently for typical development decisions.

## Recommended Actions (Priority Order)

1. **Add fit-check grid to decision council output** — When `/phx:plan` identifies competing approaches, produce R × S matrix
2. **Add "demo statement" to plan phases** — Each phase in plan.md should declare what's observable after completion
3. **Add requirements extraction step** — Before task generation, enumerate explicit requirements
4. **Create `/phx:map` skill** — Affordance-style system mapping for complex LiveView flows
5. **Add naming test to review agent** — "One verb per function" check
6. **Add source capture to plan.md** — Preserve original request verbatim
7. **Add ripple-check for plan consistency** — Hook when plan.md edited

## Summary

The Shaping Skills plugin excels at **structured pre-implementation thinking** — it forces you to clearly separate what you need (R) from how you'll build it (S), then systematically verify the fit. Our plugin excels at **automated execution** — parallel agents, context management, verification tiers.

The biggest gap in our plugin is the **structured decision comparison** phase. We jump from research to plan without a formal moment where requirements and solutions are cross-checked in a visible matrix. The fit-check pattern and demo-statement discipline would strengthen our planning without adding complexity to the execution phases.
