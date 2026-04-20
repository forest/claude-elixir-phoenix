#!/usr/bin/env bash
# SessionStart hook: Check if Ash Framework is in use
if [ -f "mix.exs" ] && grep -q ':ash,' mix.exs 2>/dev/null; then
  echo "✓ Ash Framework detected — prefer Ash patterns for data access; Phoenix/LiveView/OTP patterns still apply"
  echo "  Research first: mix usage_rules.search_docs \"<topic>\" -p ash -p ash_phoenix -p ash_postgres -p ash_authentication -p ash_oban"
  echo "  Module lookup:  mix usage_rules.docs Ash.Resource"
  echo "  Generators:     mix ash.gen.resource | mix ash.codegen | mix ash.gen.domain"
  echo "  Code interfaces over direct Ash calls: MyApp.Domain.action() not Ash.create()"
fi
