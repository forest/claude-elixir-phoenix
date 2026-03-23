#!/usr/bin/env bash
# PostToolUse hook: Log file modifications to active progress file
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
if [[ -n "$FILE_PATH" ]]; then
  LATEST=$(ls -t .claude/plans/*/progress.md 2>/dev/null | head -1)
  if [[ -n "$LATEST" ]]; then
    echo "[$(date '+%H:%M')] Modified: $FILE_PATH" >> "$LATEST"
  fi

  # Cross-project edit count in persistent plugin data (v2.1.78+)
  if [[ -n "${CLAUDE_PLUGIN_DATA}" ]]; then
    METRICS_FILE="${CLAUDE_PLUGIN_DATA}/skill-metrics/edits-$(date '+%Y-%m').jsonl"
    echo "{\"ts\":\"$(date -Iseconds)\",\"file\":\"$FILE_PATH\",\"project\":\"$(basename "$(pwd)")\"}" >> "$METRICS_FILE" 2>/dev/null || true
  fi
fi
