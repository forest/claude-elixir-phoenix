#!/usr/bin/env bash
# SessionStart hook: Detect Ash Framework and announce skill loading
if [ -f "mix.exs" ] && grep -q ':ash,' mix.exs 2>/dev/null; then
  echo "✓ Ash Framework detected — ash-framework skill loaded"
  echo "  Iron Laws: domain code interfaces, actor on query, generators first, codegen after changes"
  echo "  Generators: mix ash.gen.resource | mix ash.gen.domain (use --yes)"
  echo "  Migrations: mix ash.codegen <name> && mix ash.migrate  (NOT hand-edit; NOT mix ecto.migrate)"
fi
