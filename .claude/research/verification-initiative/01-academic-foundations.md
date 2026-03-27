# Academic Foundations

Papers and systems providing scientific evidence for each pattern.

## 1. Verification & Hallucination Prevention

### CoVe — Chain-of-Verification (Dhuliawala et al., 2023)
- **Paper:** [arXiv:2309.11495](https://arxiv.org/abs/2309.11495), published in Findings of ACL 2024
- **Authors:** Shehzaad Dhuliawala, Mojtaba Komeili, Jing Xu, Roberta Raileanu, Xian Li, Asli Celikyilmaz, Jason Weston (Meta AI)
- **Key finding:** LLMs can verify their own outputs more accurately than they generate them, IF verification is done as a separate pass with independent prompting
- **Method:** (i) Draft initial response → (ii) Plan verification questions to fact-check draft → (iii) Answer those questions independently so answers are not biased by other responses → (iv) Generate final verified response
- **Result:** Decreases hallucinations across list-based questions (Wikidata), closed-book MultiSpanQA, and longform text generation
- **Relevance:** Direct template for our verifier agent. The critical insight is that verification must be **independent** — the verifier cannot see the original generation prompt, only the output. This prevents confirmation bias

### SELF-RAG — Self-Reflective Retrieval-Augmented Generation (Asai et al., ICLR 2024)
- **Paper:** [arXiv:2310.11511](https://arxiv.org/abs/2310.11511), ICLR 2024 **Oral (top 1%)**
- **Authors:** Akari Asai, Zeqiu Wu, Yizhong Wang, Avirup Sil, Hannaneh Hajishirzi
- **Key finding:** Training LLMs to emit special "reflection tokens" (ISREL, ISSUP, ISUSE) at generation time enables self-assessment of whether retrieved passages support generated claims
- **Result:** Outperforms ChatGPT and retrieval-augmented Llama2-chat on Open-domain QA, reasoning and fact verification tasks. Significant gains in factuality and citation accuracy for long-form generations
- **Relevance:** The reflection token pattern maps to our confidence scoring — each claim gets a support assessment. We can implement this as structured metadata rather than special tokens

### REFINER — Reasoning Feedback on Intermediate Representations (Paul et al., EACL 2024)
- **Venue:** EACL 2024
- **Key finding:** A dedicated "critic" model that provides structured feedback on intermediate reasoning steps (not just final output) catches errors earlier in the reasoning chain
- **Result:** Significant improvement on math, logic, and structured reasoning tasks
- **Relevance:** Supports our approach of verifying at intermediate steps (e.g., verify research findings before they feed into a plan, not just verify the final plan)

### FActScore — Fine-grained Atomic Claim Scoring (Min et al., EMNLP 2023)
- **Paper:** [arXiv:2305.14251](https://arxiv.org/abs/2305.14251), EMNLP 2023
- **Key finding:** Breaks generation into atomic facts and computes the percentage supported by a reliable knowledge source. Automated FActScore estimation has <2% error rate vs human evaluation
- **Result:** ChatGPT only achieves 58% FActScore on people biographies. High correlation with human factuality judgments. Available via `pip install factscore`
- **Relevance:** Directly applicable to our research output verification — decompose a research brief into individual claims, verify each against sources

### FIRE — Fact-checking with Iterative Retrieval and Verification (Xie et al., NAACL 2025)
- **Paper:** [arXiv:2411.00784](https://arxiv.org/abs/2411.00784), Findings of NAACL 2025
- **Authors:** Zhuohan Xie, Rui Xing, Yuxia Wang, Jiahui Geng, Hasan Iqbal, Dhruv Sahnan, Iryna Gurevych, Preslav Nakov (MBZUAI)
- **Key finding:** Integrates evidence retrieval and claim verification iteratively rather than as separate pipeline stages. Unified mechanism decides whether to provide final answer or generate next search query based on confidence
- **Result:** Slightly better performance while reducing LLM costs by **7.6x** and search costs by **16.5x**
- **Relevance:** **Directly applicable** to our verifier design. Instead of doing one big verification pass, verify claims iteratively — confident claims get fast-tracked, uncertain claims get targeted re-search. This is the efficiency breakthrough we need for making verification automatic without slowing down workflows

### DelphiAgent — Multi-Agent Verification Framework (2025)
- **Paper:** [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0306457325001827)
- **Key finding:** Multiple LLM agents with distinct "personalities" make factuality judgments independently, then reach consensus through multiple rounds of feedback and synthesis (emulating the Delphi method)
- **Architecture:** Dual-system: evidence mining module (extracts and refines evidence from raw reports) + Delphi decision-making module (multi-agent consensus)
- **Result:** Surpasses current LLM-based approaches, on par with supervised baselines without training. MacF1 improvements up to 6.84%
- **Relevance:** Validates multi-agent verification architecture. Our parallel-reviewer already has 4 specialist agents — adding a consensus/verification step after their independent reviews would catch disagreements

### Survey: Hallucination in LLMs (Huang et al., 2023)
- **Venue:** ACL 2023 Survey
- **Key taxonomy:**
  - **Intrinsic hallucination:** Contradicts the source (e.g., "Phoenix 1.7 supports scopes" when the source says 1.8+)
  - **Extrinsic hallucination:** Cannot be verified from source (e.g., "this library is maintained" with no evidence)
  - **Faithfulness hallucination:** Output contradicts its own earlier claims
- **Relevance:** Our verifier should check all three types. Most dangerous for us is extrinsic hallucination — agent claims that sound plausible but have no supporting evidence

## 2. Self-Refine & Iterative Improvement

### Self-Refine (Madaan et al., NeurIPS 2023)
- **Paper:** [arXiv:2303.17651](https://arxiv.org/abs/2303.17651), NeurIPS 2023
- **Key finding:** LLMs can iteratively improve their own output through generate → feedback → refine cycles, WITHOUT external training signals. Same LLM serves as generator, feedback provider, and refiner
- **Result:** ~20% absolute improvement on average across 7 tasks. Code optimization: 22.0 → 28.8 after 3 iterations. Works even on GPT-4 (i.e., SOTA models still benefit from self-refinement at test time)
- **Critical insight:** Diminishing returns after 2-3 iterations. The feedback quality matters more than iteration count
- **Relevance:** Template for our autoresearch loop. 2-3 iterations is the sweet spot. After that, escalate to human review

### Reflexion (Shinn et al., NeurIPS 2023)
- **Paper:** [arXiv:2303.11366](https://arxiv.org/abs/2303.11366), NeurIPS 2023
- **Authors:** Noah Shinn, Federico Cassano, Edward Berman, Ashwin Gopinath, Karthik Narasimhan, Shunyu Yao (Princeton)
- **Key finding:** Verbal "self-reflection" stored in episodic memory buffer allows agents to learn from failures within a session. Agents that reflect on WHY they failed improve more than agents that just retry. No weight updates needed — just linguistic feedback
- **Result:** 91% pass@1 on HumanEval (vs 80% GPT-4 baseline) through reflection-driven retry
- **Relevance:** Our scratchpad/lab notebook serves this function — recording not just what failed but WHY, so the next attempt is informed. The "Dead Ends" section in structured scratchpad IS episodic memory

### AlphaEvolve (Google DeepMind, 2025)
- **Paper:** [arXiv:2506.13131](https://arxiv.org/abs/2506.13131), announced May 2025
- **Key finding:** Evolutionary coding agent that orchestrates LLMs to improve algorithms through iterative mutations + automated evaluation. Uses Gemini Flash (throughput) + Gemini Pro (quality) ensemble
- **Architecture:** Prompt sampler (rich context from prior solutions) → LLM ensemble → Evaluator pool (verifies and scores) → Program database (evolutionary selection)
- **Result:** First improvement over Strassen's matrix multiplication algorithm in 56 years. Discovered heuristic saving 0.7% of Google's worldwide compute (in production 1+ year). Evolves entire codebases, not just single functions (unlike predecessor FunSearch)
- **Relevance:** Our autoresearch loop follows this pattern: mutate (edit code) → evaluate (mix test/benchmark) → select (keep or revert). The lesson: the evaluation function MUST be deterministic and trustworthy. The ensemble approach (fast model for volume + powerful model for quality) maps to our Haiku/Sonnet/Opus tiering

### Karpathy's Autoresearch (March 2026)
- **Repo:** [github.com/karpathy/autoresearch](https://github.com/karpathy/autoresearch)
- **Key finding:** Minimal but real "agent loop" for autonomous LLM experimentation. Agent edits training script → runs 5-minute time-boxed experiment → measures val_bpb → keeps or discards → repeats overnight
- **Results:** Tobias Lütke (Shopify CEO) ran it overnight: 37 experiments, **19% performance gain**. Karpathy found 20 tweaks gave 11% speedup on larger model
- **Vision:** "The loopy era" — continuous self-improvement loops on code/research becoming standard at frontier labs. Next step: asynchronously collaborative multi-agent environment emulating research community
- **Relevance:** **Direct validation** of our /phx:autoresearch pattern. Key insight: time-boxing experiments prevents runaway costs. Our autoresearch already does this with max iterations. The "research community" vision maps to our multi-agent orchestration

### DSPy (Khattab et al., 2023)
- **Venue:** Stanford NLP
- **Key finding:** Treating LLM prompts as optimizable programs with measurable metrics enables systematic prompt improvement
- **Relevance:** Our eval framework already does this for skill descriptions. DSPy validates our approach of metric-driven skill improvement

## 3. Agent Architecture & Verification Integration

### SWE-Agent (Yang et al., 2024)
- **Venue:** Princeton NLP
- **Key finding:** Software engineering agents that use structured action spaces (not free-form bash) and have access to verification tools (tests) produce higher-quality patches
- **Result:** 12.5% resolve rate on SWE-bench (SOTA at time of publication)
- **Relevance:** Our Iron Laws + mix compile/test verification is already this pattern. Extending it to output verification is the logical next step

### Aider — Structured Edit Verification (Gauthier, 2023-2024)
- **Key finding:** Diff-based editing with automatic lint/test verification catches ~40% of LLM coding errors before they compound. The "edit → verify → retry" loop is more effective than single-shot generation
- **Relevance:** We already do this with our PostToolUse hooks. The gap: we verify CODE but not CLAIMS

### MemGPT / Letta (Packer et al., 2023)
- **Venue:** NeurIPS 2023 Workshop
- **Key finding:** Explicit memory management (what to keep in context, what to externalize to files, what to page in on demand) is critical for long-running agents
- **Relevance:** Our context-supervisor pattern already handles this. Feynman's file-based context hygiene reinforces our approach

### CoALA — Cognitive Architectures for Language Agents (Sumers et al., 2024)
- **Venue:** TMLR 2024
- **Framework:** Classifies agent architectures along: memory (working/episodic/semantic/procedural), action space (internal/external), decision-making (planning/reflection)
- **Relevance:** Maps our plugin architecture:
  - Working memory = socket assigns, current plan
  - Episodic memory = scratchpad, CHANGELOG lab notebook
  - Semantic memory = compound-docs solutions
  - Procedural memory = Iron Laws, reference patterns
  - The GAP: no verification in the action→observation loop

### Voyager (Wang et al., 2023)
- **Venue:** NeurIPS 2023
- **Key finding:** Agents that build a "skill library" from solved problems (our compound-docs) AND verify skills work before storing them, accumulate capabilities faster
- **Relevance:** Our /phx:compound captures solutions but doesn't verify them. Adding verification before storage would improve skill library quality

## 4. AI Slop & Output Quality

### Model Collapse (Shumailov et al., Nature 2024)
- **Venue:** Nature 2024
- **Key finding:** Training AI on AI-generated data causes progressive quality degradation — "model collapse." Each generation loses distribution tails (rare but important patterns)
- **Relevance:** This is the theoretical foundation for why slop detection matters. AI-generated code/docs/reviews that feed back into AI workflows create a collapse loop. Our verifier breaks this loop by injecting human-verified ground truth

### LLM Code Security Vulnerabilities (Pearce et al., 2022-2023)
- **Key finding:** LLM-generated code contains security vulnerabilities at roughly the same rate as human code, but the TYPES differ — LLMs produce more "boilerplate vulnerabilities" (missing input validation, default configurations) while humans produce more logic errors
- **Relevance:** Our Iron Laws already catch the boilerplate vulnerabilities. The slop cleaner should focus on the logic quality — unnecessary abstraction, dead code paths, over-engineering

### MALT — Multi-Agent LLM Training (2024-2025)
- **Key finding:** Generator-verifier-refiner multi-agent architectures produce higher quality output than single-agent approaches, because each role has different optimization pressure
- **Relevance:** Directly supports our architecture of separate generator (work agent), verifier (new), and refiner (review agent) roles

## 5. Key Cross-Cutting Insights

### The Independence Principle (from CoVe, FActScore, REFINER)
Verification MUST be independent from generation. If the verifier has access to the same prompt/context as the generator, it exhibits confirmation bias and agrees with the original output. The verifier should only see: the output, and the sources/evidence.

### The Diminishing Returns Principle (from Self-Refine, Reflexion)
Iterative improvement hits diminishing returns after 2-3 cycles. Beyond that, errors become "stuck" — the model cannot see them because they're in its blind spot. At that point, escalate to a different model, a different approach, or human review.

### The Deterministic Evaluation Principle (from AlphaEvolve, FunSearch, DSPy)
Automated improvement loops only work when the evaluation function is deterministic and trustworthy. "Does mix test pass?" is deterministic. "Is this code good?" is not. Design evaluation functions to be as concrete and measurable as possible.

### The Atomic Verification Principle (from FActScore, CoVe)
Verifying individual claims is more reliable than verifying entire documents. Decompose outputs into atomic claims, verify each independently, then aggregate. A document with 20 verified claims and 2 unverified ones is more useful than a document rated "mostly correct."
