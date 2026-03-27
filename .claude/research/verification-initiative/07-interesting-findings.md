# Interesting Findings — Outside the Main Scope

Surprising discoveries during research that may inform future work.

## 1. ChatGPT's FActScore is Only 58%

From FActScore (Min et al., EMNLP 2023): When generating people biographies, ChatGPT achieves only 58% factual precision at the atomic claim level. This means **42% of its factual claims are unsupported by reliable sources**.

**Why this matters for us:** If ChatGPT hallucinates 42% of claims in a well-studied domain (biographies), our agents likely have similar or worse rates when making claims about Elixir libraries, Phoenix patterns, or codebase-specific details. The verification gap isn't theoretical — it's 40%+ of output.

## 2. FIRE Reduces Verification Cost by 7.6x

FIRE (Xie et al., NAACL 2025) achieves slightly BETTER verification performance while reducing LLM costs by 7.6x and search costs by 16.5x. The key: iterative confidence-based verification — check high-confidence claims quickly, spend resources on uncertain ones.

**Why this matters for us:** The main objection to automatic verification is "it will slow everything down." FIRE proves it doesn't have to. Iterative verification is dramatically cheaper than batch verification while being slightly more accurate.

## 3. Self-Refine Works Even on GPT-4

Self-Refine (Madaan et al., NeurIPS 2023) shows ~20% improvement even when applied to GPT-4 — the strongest model at the time. This means even the best models benefit from test-time refinement.

**Why this matters for us:** Our agents already use strong models (Opus for orchestrators, Sonnet for specialists). Self-Refine says they'd STILL benefit from a verification/refinement pass. "The model is already good enough" is not a valid objection.

## 4. Karpathy's Autoresearch: 37 Experiments Overnight, 19% Gain

Tobias Lütke (Shopify CEO) ran Karpathy's autoresearch overnight and got 37 experiments with a 19% performance gain — fully autonomous, no human intervention.

**Why this matters for us:** Our `/phx:autoresearch` already implements this pattern for code quality. The expansion to research quality, review accuracy, and performance is validated by real-world results at scale. The "overnight" pattern is especially relevant — set up a research quality improvement loop and let it run.

## 5. AlphaEvolve's Ensemble Approach Matches Our Tiering

AlphaEvolve uses Gemini Flash (throughput) + Gemini Pro (quality) in ensemble. Flash generates more candidates quickly, Pro provides higher-quality suggestions that advance the search.

**Why this matters for us:** This validates our Haiku/Sonnet/Opus tiering. Haiku for mechanical tasks (context compression, verification checks), Sonnet for specialists (review, analysis), Opus for judgment-heavy orchestration. The science says mixed models outperform uniform models.

## 6. The "Delphi Method" for AI Consensus

DelphiAgent uses multiple LLM agents with DISTINCT personalities making independent judgments, then reaching consensus through multiple rounds. This is the Delphi method from decision science adapted for AI.

**Why this matters for us:** Our parallel-reviewer has 4 specialist agents that review independently — but they don't have a consensus step. Adding a "do the findings agree?" check after parallel review would catch disagreements that indicate uncertainty.

## 7. Reflexion's Key Insight: WHY > WHAT

Reflexion (Shinn et al., NeurIPS 2023) showed that agents reflecting on WHY they failed improve dramatically (91% vs 80% on HumanEval), while agents that just retry without reflection don't improve much.

**Why this matters for us:** Our scratchpad records WHAT happened but rarely WHY. The structured lab notebook with explicit "WHY: reason" annotations is not a nice-to-have — it's the difference between 80% and 91% effectiveness on retry.

## 8. Model Collapse: The Theoretical Case Against AI Slop

Shumailov et al. (Nature 2024) proved that training AI on AI-generated data causes progressive quality degradation. Distribution tails (rare but important patterns) disappear first.

**Why this matters for us:** In Phoenix development, "distribution tails" are edge cases — race conditions in LiveView, subtle Ecto constraint interactions, OTP supervisor restart strategies. These are exactly what AI slop misses. A slop cleaner that removes AI-generated boilerplate and preserves edge case handling is fighting model collapse at the application level.

## 9. OMC's Writer/Reviewer Separation is Scientifically Grounded

OMC's AI slop cleaner has a `--review` mode where one agent identifies problems and a DIFFERENT agent fixes them. This writer/reviewer separation is independently supported by:
- CoVe: Independent verification prevents confirmation bias
- MALT: Generator-verifier-refiner with different optimization pressures
- DelphiAgent: Distinct "personalities" for different judgment roles

**Why this matters for us:** Our review skills already follow this pattern (/phx:review identifies, /phx:work fixes). The deslop skill should maintain this separation.

## 10. The "Research Community" Vision

Karpathy envisions autoresearch evolving into "asynchronously, massively collaborative environments for agents, designed to emulate a research community rather than a single PhD student."

**Why this matters for us:** Our multi-agent orchestration (planning-orchestrator, parallel-reviewer, workflow-orchestrator) already operates as a "research community" for code quality. The verification initiative extends this to knowledge quality. We're building a research community where agents check each other's work.

## 11. Source Quality Matters More Than Source Quantity

Feynman's explicit source quality tiers (T1 Authoritative → T5 Rejected) with different trust levels per tier. SELF-RAG's reflection tokens assess whether each retrieved passage actually supports the generated claim.

**Why this matters for us:** Our `/phx:research` treats all sources equally — a HexDocs page and a random Medium blog get the same weight. Adding source quality assessment would dramatically improve research output trustworthiness. One T1 source (HexDocs) is worth more than five T4 sources (SEO blogs).

## 12. oh-my-claudecode is 90k+ Lines of TypeScript

OMC is a massive general-purpose framework with model routing, team management, tmux workers, HUD rendering, background task management, and multi-AI coordination (Claude + Gemini + Codex).

**Why this matters for us:** It's a cautionary tale about scope. Our plugin is ~5k lines of focused Elixir/Phoenix-specific content. OMC's general approach requires 18x more code. Domain-specific plugins that do one thing deeply (our approach) are more maintainable than general frameworks that try to do everything.

## 13. Feynman's "Task Ledger" Pattern

Feynman's deep research tracks each research dimension with a task ledger: ownership, status, output location. Blocked or superseded work gets explicit notation — no silent drops.

**Why this matters for us:** Our orchestrators delegate to sub-agents but don't always track completion explicitly. A task ledger pattern would make our parallel-reviewer and planning-orchestrator more reliable — every delegated task has an explicit status and output location.

## 14. FACT-AUDIT: Adaptive Difficulty Scaling

FACT-AUDIT (ACL 2025) adapts verification difficulty based on claim complexity. Simple claims (dates, names) get fast verification. Complex claims (causal relationships, comparisons) get deeper analysis.

**Why this matters for us:** Our verifier should do the same. "Phoenix 1.8 supports scopes" is easy to verify (check release notes). "Using streams instead of assigns reduces memory by 90% for lists >1000 items" is harder (needs benchmarking or authoritative source). Adaptive depth saves resources.
