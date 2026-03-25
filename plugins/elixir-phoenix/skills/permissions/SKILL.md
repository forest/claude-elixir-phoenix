---
name: phx:permissions
description: Analyze recent Claude Code sessions and recommend safe Bash permissions for settings.json. Use when too many permission prompts slow the workflow, after 5+ permission prompts in a session, or when the user says "fix permissions", "reduce prompts", "allow commands", "permission fatigue", "optimize permissions", "mix command blocked", "bash permission denied", "allowedTools", "settings.json permissions", "stop asking for permission", "auto-allow mix", or "too many prompts for mix test/compile/format".
argument-hint: "[--days=14] [--dry-run]"
---

# Permission Analyzer

Analyze recent session history to identify frequently-approved Bash
commands, classify them by risk, and write safe ones to `settings.json`.

## Usage

```
/phx:permissions                # Analyze last 14 days, apply safe commands
/phx:permissions --days=30      # Analyze last 30 days
/phx:permissions --dry-run      # Show recommendations without applying
```

## Arguments

`$ARGUMENTS` — Optional flags:

- `--days=N` — How many days of history to scan (default: 14)
- `--dry-run` — Preview recommendations without writing to settings.json

## Iron Laws

1. **Never auto-allow RED commands** — `rm`, `sudo`, `curl|wget` piped to shell, `chmod 777`, `kill -9`, `docker rm` require manual approval every time
2. **Evidence-based only** — Only recommend commands the user has actually approved in recent sessions, never guess or suggest commands speculatively
3. **Show before writing** — Always present the full proposed `settings.json` diff to the user and get explicit confirmation before modifying settings
4. **Preserve existing permissions** — Merge with current settings, never overwrite user's manually configured permissions

## Risk Classification

| Level | Category | Examples | Action |
|-------|----------|----------|--------|
| GREEN | Read-only, tests | `ls`, `cat`, `grep`, `mix test`, `mix compile`, `mix format`, `mix credo`, `git status`, `git log`, `git diff` | Auto-recommend |
| YELLOW | Writes, git ops | `git add`, `git commit`, `git push`, `mkdir`, `mix ecto.migrate`, `mix deps.get`, `npm install` | Recommend with note |
| RED | Destructive | `rm`, `sudo`, `kill`, `curl\|sh`, `mix ecto.reset`, `git push --force`, `chmod` | Never recommend |

## Workflow

### Step 1: Parse `--days` and `--dry-run` from `$ARGUMENTS`

Default: `--days=14`, `--dry-run=false`.

### Step 2: Scan Session Transcripts

Find recent sessions and extract approved Bash commands:

```bash
# Find session directories from last N days
find ~/.claude/projects/ -name "*.jsonl" -mtime -${DAYS} 2>/dev/null

# Also check for session transcripts
find ~/.claude/ -name "transcript*.jsonl" -mtime -${DAYS} 2>/dev/null
```

Parse each session file for Bash tool calls that were approved
(not denied). Extract the command string from each.

### Step 3: Classify Commands

For each unique command pattern:

1. **Normalize** — Strip arguments to get the base command pattern
   (e.g., `mix test test/foo_test.exs` → `mix test`)
2. **Classify** — Assign GREEN / YELLOW / RED per the table above
3. **Count** — Track approval frequency

### Step 4: Read Current Settings

```bash
cat ~/.claude/settings.json 2>/dev/null || echo "{}"
cat .claude/settings.json 2>/dev/null || echo "{}"
cat .claude/settings.local.json 2>/dev/null || echo "{}"
```

Parse existing `allowedTools` to avoid duplicating.

### Step 5: Generate Recommendations

Present a table to the user:

```
## Permission Recommendations (last {N} days)

### GREEN — Safe to allow (approved {X} times)
| Command Pattern | Times Approved | Risk |
|----------------|---------------|------|
| mix test *     | 47            | GREEN |
| mix compile *  | 32            | GREEN |
| ...            |               |       |

### YELLOW — Recommended with caution (approved {X} times)
| Command Pattern | Times Approved | Risk | Note |
|----------------|---------------|------|------|
| git commit *   | 23            | YELLOW | Writes to repo |
| ...            |               |        |       |

### RED — Never auto-allowed (still require approval)
| Command Pattern | Times Approved | Risk |
|----------------|---------------|------|
| rm -rf *       | 2             | RED  |
```

### Step 6: Apply (unless `--dry-run`)

If user confirms, write GREEN + approved YELLOW commands to
`.claude/settings.json` as `allowedTools` entries:

```json
{
  "permissions": {
    "allow": [
      "Bash(mix test*)",
      "Bash(mix compile*)",
      "Bash(mix format*)",
      "Bash(git status)",
      "Bash(git diff*)",
      "Bash(git log*)"
    ]
  }
}
```

**Merge** with existing settings — never overwrite.

### Step 7: Summary

Report what was added, what was skipped (RED), and suggest
re-running in 2-4 weeks as workflow evolves.

## References

- `references/risk-classification.md` — Full command classification rules
- `references/settings-format.md` — Claude Code settings.json permission format
