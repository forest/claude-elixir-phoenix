#!/usr/bin/env bash
# Fetch Ash Framework usage-rules from GitHub into the ash-framework skill references.
# Run this before plugin releases to pull the latest rules from the Ash maintainers.
#
# Usage:
#   ./scripts/fetch-ash-rules.sh              # Fetch all rules
#   ./scripts/fetch-ash-rules.sh --force      # Re-download even if files exist
#   ./scripts/fetch-ash-rules.sh --dry-run    # Show what would be downloaded

set -euo pipefail

SKILL_REFS="plugins/elixir-phoenix/skills/ash-framework/references"
GITHUB_RAW="https://raw.githubusercontent.com"
FORCE=false
DRY_RUN=false

# Ash core — 14 files
ASH_FILES=(
  "actions.md"
  "aggregates.md"
  "authorization.md"
  "calculations.md"
  "code_interfaces.md"
  "code_structure.md"
  "data_layers.md"
  "exist_expressions.md"
  "generating_code.md"
  "migrations.md"
  "query_filter.md"
  "querying_data.md"
  "relationships.md"
  "testing.md"
)

# AshPhoenix — 6 files
ASH_PHOENIX_FILES=(
  "best_practices.md"
  "debugging_form_submissions.md"
  "error_handling.md"
  "form_integration.md"
  "nested_forms.md"
  "union_forms.md"
)

# AshPostgres — 9 files
ASH_POSTGRES_FILES=(
  "advanced_features.md"
  "best_practices.md"
  "check_constraints.md"
  "configuration.md"
  "custom_indexes.md"
  "custom_sql_statements.md"
  "foreign_keys.md"
  "migrations.md"
  "multitenancy.md"
)

# AshAuthentication — 1 file (single usage-rules.md at repo root, team-alembic org)
ASH_AUTHENTICATION_FILE="usage-rules.md"

# AshJsonApi — 1 file (single usage-rules.md at repo root)
ASH_JSON_API_FILES=(
  "usage-rules.md"
)

# AshGraphQL — top-level overview + 3 directory files
ASH_GRAPHQL_ROOT_FILE="usage-rules.md"       # stored as overview.md
ASH_GRAPHQL_FILES=(
  "custom_types.md"
  "domain_configuration.md"
  "resource_configuration.md"
)

for arg in "$@"; do
  case "$arg" in
    --force)   FORCE=true ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: $0 [--force] [--dry-run]"
      echo ""
      echo "  --force    Re-download even if files already exist"
      echo "  --dry-run  Show what would be downloaded without fetching"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

echo "=== Ash Framework Rules Fetcher ==="
echo ""

fetch_file() {
  local repo="$1"
  local branch="$2"
  local remote_path="$3"
  local local_path="$4"
  local url="${GITHUB_RAW}/${repo}/${branch}/${remote_path}"

  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] would fetch: $url"
    echo "            → $local_path"
    return 0
  fi

  if [ "$FORCE" = false ] && [ -f "$local_path" ]; then
    echo "  [exists]  $(basename "$local_path")"
    return 0
  fi

  mkdir -p "$(dirname "$local_path")"

  for attempt in 1 2 3; do
    if curl -sfL "$url" -o "$local_path" 2>/dev/null; then
      local size
      size=$(wc -c < "$local_path")
      echo "  [fetched] $(basename "$local_path") (${size}B)"
      return 0
    fi
    [ "$attempt" -lt 3 ] && sleep $(( attempt * 2 ))
  done

  echo "  [FAILED]  $(basename "$local_path") — could not download after 3 attempts"
  rm -f "$local_path"
  return 1
}

failed=0

# ash core
echo "Fetching ash core rules (${#ASH_FILES[@]} files)..."
for f in "${ASH_FILES[@]}"; do
  fetch_file "ash-project/ash" "main" "usage-rules/$f" "${SKILL_REFS}/ash/$f" || (( failed++ )) || true
done

echo ""
echo "Fetching ash_phoenix rules (${#ASH_PHOENIX_FILES[@]} files)..."
for f in "${ASH_PHOENIX_FILES[@]}"; do
  fetch_file "ash-project/ash_phoenix" "main" "usage-rules/$f" "${SKILL_REFS}/ash-phoenix/$f" || (( failed++ )) || true
done

echo ""
echo "Fetching ash_postgres rules (${#ASH_POSTGRES_FILES[@]} files)..."
for f in "${ASH_POSTGRES_FILES[@]}"; do
  fetch_file "ash-project/ash_postgres" "main" "usage-rules/$f" "${SKILL_REFS}/ash-postgres/$f" || (( failed++ )) || true
done

echo ""
echo "Fetching ash_authentication rules (1 file)..."
fetch_file "team-alembic/ash_authentication" "main" "${ASH_AUTHENTICATION_FILE}" "${SKILL_REFS}/ash-authentication/usage-rules.md" || (( failed++ )) || true

echo ""
echo "Fetching ash_json_api rules (${#ASH_JSON_API_FILES[@]} file)..."
for f in "${ASH_JSON_API_FILES[@]}"; do
  fetch_file "ash-project/ash_json_api" "main" "$f" "${SKILL_REFS}/ash-json-api/$f" || (( failed++ )) || true
done

echo ""
echo "Fetching ash_graphql rules (1 + ${#ASH_GRAPHQL_FILES[@]} files)..."
fetch_file "ash-project/ash_graphql" "main" "${ASH_GRAPHQL_ROOT_FILE}" "${SKILL_REFS}/ash-graphql/overview.md" || (( failed++ )) || true
for f in "${ASH_GRAPHQL_FILES[@]}"; do
  fetch_file "ash-project/ash_graphql" "main" "usage-rules/$f" "${SKILL_REFS}/ash-graphql/$f" || (( failed++ )) || true
done

echo ""
echo "=== Summary ==="
total=$(( ${#ASH_FILES[@]} + ${#ASH_PHOENIX_FILES[@]} + ${#ASH_POSTGRES_FILES[@]} + 1 + ${#ASH_JSON_API_FILES[@]} + 1 + ${#ASH_GRAPHQL_FILES[@]} ))
if [ "$DRY_RUN" = true ]; then
  echo "  Dry run — $total files would be fetched"
else
  fetched=$(find "${SKILL_REFS}" -name "*.md" | wc -l | tr -d ' ')
  total_size=$(du -sh "${SKILL_REFS}" 2>/dev/null | cut -f1)
  echo "  Files: $fetched / $total"
  echo "  Size:  $total_size"
  echo "  Dest:  ${SKILL_REFS}/"
  [ "$failed" -gt 0 ] && echo "  Failures: $failed"
fi

if [ "$failed" -gt 0 ]; then
  exit 1
fi
