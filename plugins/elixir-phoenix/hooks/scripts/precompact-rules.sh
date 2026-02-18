#!/usr/bin/env bash
# PreCompact hook: Re-inject critical SKILL-SPECIFIC rules before compaction.
# Iron Laws from CLAUDE.md survive compaction (system prompt), so we only
# re-inject rules from loaded skills that live in conversation context.

# Detect active workflow phase and output relevant rules.
# /phx:full uses progress.md with **State**: field — skip STOP rules for it.

FULL_MODE=false
ACTIVE_PLAN=false
ACTIVE_WORK=false

for dir in .claude/plans/*/; do
  [ -d "$dir" ] || continue

  # Check for /phx:full autonomous mode
  if [ -f "${dir}progress.md" ] && grep -q '\*\*State\*\*:' "${dir}progress.md" 2>/dev/null; then
    FULL_MODE=true
    continue
  fi

  # Research exists but no plan yet = mid /phx:plan
  if [ -d "${dir}research" ] && [ ! -f "${dir}plan.md" ]; then
    ACTIVE_PLAN=true
  fi

  # Plan exists with PENDING status and unchecked tasks = planning or about to work
  if [ -f "${dir}plan.md" ]; then
    if grep -q 'Status.*PENDING' "${dir}plan.md" 2>/dev/null; then
      ACTIVE_PLAN=true
    elif grep -q '^\- \[ \]' "${dir}plan.md" 2>/dev/null; then
      ACTIVE_WORK=true
    fi
  fi
done

# Output rules based on active phase
if [ "$ACTIVE_PLAN" = true ] && [ "$FULL_MODE" = false ]; then
  echo "PRESERVE ACROSS COMPACTION — active /phx:plan session:"
  echo ""
  echo "CRITICAL: After writing plan.md, you MUST STOP."
  echo "Do NOT proceed to implementation or /phx:work."
  echo "Present the plan summary and use AskUserQuestion with options:"
  echo "  - Start in fresh session (recommended)"
  echo "  - Get a briefing (/phx:brief)"
  echo "  - Start here"
  echo "  - Review the plan"
  echo "  - Adjust the plan"
  echo "Wait for user response. This is Iron Law #1 of /phx:plan."
fi

if [ "$ACTIVE_WORK" = true ] && [ "$FULL_MODE" = false ]; then
  echo "PRESERVE ACROSS COMPACTION — active /phx:work session:"
  echo ""
  echo "- Verify after EVERY task (mix compile --warnings-as-errors)"
  echo "- Max 3 retries per task, then mark BLOCKER"
  echo "- Auto-continue between phases, but STOP when ALL phases done"
  echo "- NEVER auto-start /phx:review — ask user what to do next"
  echo "- Re-read plan.md for current state (checkboxes are the source of truth)"
fi

if [ "$FULL_MODE" = true ]; then
  echo "PRESERVE ACROSS COMPACTION — /phx:full autonomous mode:"
  echo ""
  echo "- Continue autonomous plan → work → review cycle"
  echo "- Re-read progress.md for current state and cycle count"
  echo "- Re-read plan.md for task checkboxes"
  echo "- Max cycles, retries, and blocker limits still apply"
fi
