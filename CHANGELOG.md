# Changelog

All notable changes to the Elixir/Phoenix Claude Code plugin.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-03-05

### Added

- **SubagentStart hook** — injects all 21 Iron Laws into every spawned subagent
  via `additionalContext` (fixes #1 session analysis finding: zero skill
  auto-loading in subagents)
- **PostToolUseFailure hook** — Elixir-specific debugging hints when mix
  compile/test/credo/ecto commands fail, injected via `additionalContext`
- **Skill effectiveness monitoring** (`/skill-monitor`) — per-skill metrics
  dashboard with action rate, friction, corrections tracking. Includes
  `skill-effectiveness-analyzer` agent for improvement recommendations
- **9 new reference files** — `otp-patterns.md`, `js-interop.md`,
  `ci-templates.md`, `with-and-pipes.md`, `scopes-auth.md`,
  `advanced-patterns.md`, `documentation-patterns.md`, `briefing-guide.md`,
  `execution-guide.md`
- Iron Laws sections added to skills: audit, document, investigate, research
- Changelog and semantic versioning

### Fixed

- **PostToolUse hooks broken for ~1 month** (CRITICAL) — `plan-stop-reminder`,
  `security-reminder`, `format-elixir` all wrote to stdout which is
  verbose-mode only. Now use stderr + exit 2 so Claude actually receives
  the messages
- **PreCompact rules never injected** — stdout has no context injection path
  for PreCompact. Rewritten to use JSON `hookSpecificOutput.additionalContext`
- **SessionStart hooks running on /compact** — split matchers so informational
  hooks (scratchpad, resume, branch freshness) only run on startup|resume
- **compute-metrics.py O(n^2) bug** — `messages.index()` replaced with
  `enumerate` for correct windowing and O(n) performance
- **compute-metrics.py post_test_runs always 0** — ccrider-format messages
  have empty tool input; added text-based detection fallback
- **compute-metrics.py backfill schema gap** — `backfill_from_v1` now includes
  `skill_effectiveness: {}` for consistent schema

### Changed

- All 38 skill descriptions enriched for better auto-loading triggers
  (e.g., assigns-audit now triggers on "memory leaks", "slow LiveView renders")
- Updated CLAUDE.md hooks section with all 6 hook events and output patterns
- Updated README with `/skill-monitor` in session analysis tools
- Updated `/phx:intro` tutorial hooks table with new hooks

## [2.0.0] - 2026-02-19

### Added

- Iron Law #21: never use `assign_new` for values refreshed every mount
- VERIFYING phase in `/phx:full` workflow (compile + format + credo + test
  between work and review)
- Behavioral rules in CLAUDE.md: auto-load patterns, skill loading by file
  type, Iron Laws enforcement protocol
- Elixir 1.18 deprecations reference, try/after patterns, mix tasks reference
- `/phx:brief` skill for interactive plan briefings with visual formatting
- `/docs-check` contributor tool for plugin compatibility validation
- Markdown linting with markdownlint + husky pre-commit hooks
- `learn-from-fix` rewritten to write to project memory (not plugin files)

### Changed

- Agent model tiers optimized for Sonnet 4.6: most specialists moved from
  opus to sonnet, haiku for mechanical tasks (verification, compression)
- Planning workflow improved: agent blocking, session handoff for 5+ task
  plans, research synthesis
- Review, verify, testing, and Tidewave skills enhanced
- Intro tutorial split into 6 sections (was 5) to prevent content truncation
- Session analysis migrated to v2 pipeline (scan/deep-dive/trends with
  JSONL append-only ledger)

### Fixed

- Challenge skill dedup and multiSelect support
- Parallel-reviewer and skill tool scoping permissions
- `permissionMode: bypassPermissions` applied to all 20 agents (was causing
  "Bash command permission check failed" in background agents)
- Project name leaks in skill content
- Stale counts and intro tutorial accuracy
- Template placeholder filtering in session extraction

## [1.0.0] - 2026-02-13

### Added

- Initial release
- 20 specialist agents (orchestrators, reviewers, analysts)
- 38 skills covering full development lifecycle
- 20 Iron Laws (LiveView, Ecto, Oban, Security, OTP, Elixir)
- Plan-Work-Review-Compound workflow cycle
- PostToolUse hooks: format check, security reminder, progress logging
- SessionStart hooks: directory setup, Tidewave detection
- Stop hook: warn on uncompleted plan tasks
- PreCompact hook: rule preservation across context compaction
- Tidewave MCP integration (auto-detected)
- Context supervisor pattern for multi-agent output compression
- Plan namespaces (`.claude/plans/{slug}/`)
- Compound knowledge system (`.claude/solutions/`)
