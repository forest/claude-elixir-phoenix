---
name: ash-framework
description: "Ash Framework patterns — resources, actions, domains, policies, AshPhoenix forms, LiveView, AshPostgres migrations. Use when editing Ash resources, changes, checks, types, validations, or domain code interfaces."
effort: medium
user-invocable: false
paths:
  - "**/changes/*.ex"
  - "**/checks/*.ex"
  - "**/actions/*.ex"
  - "**/types/*.ex"
  - "**/validations/*.ex"
  - "**/resource_snapshots/**/*.json"
---

# Ash Framework Reference

Reference for Ash Framework in Phoenix/LiveView projects.
Ash complements Phoenix/Ecto — LiveView, security, and OTP Iron Laws still apply.
Only data access patterns shift toward Ash actions and domain code interfaces.

## Iron Laws

1. **USE DOMAIN CODE INTERFACES** — Never call `Ash.create/Ash.read` directly in LiveViews or Controllers; use domain code interfaces: `MyApp.Accounts.register_user()` not `Ash.create(User, attrs)`
2. **SET ACTOR ON QUERY, NOT ON CALL** — `Ash.Query.for_read(:read, %{}, actor: actor)` is correct; passing `actor:` to `Ash.read!()` is wrong and may bypass row-level policies
3. **GENERATORS FIRST** — Before writing Ash code manually, run `mix ash.gen.resource` or `mix ash.gen.domain` with `--yes`; check `mix help ash.gen.<task>` for options
4. **CODEGEN AFTER RESOURCE CHANGES** — Always run `mix ash.codegen` after modifying resources; this generates migrations from resource snapshots — never write AshPostgres migrations by hand
5. **ACTIONS OVER FUNCTIONS** — Put business logic in named actions, not domain functions; expose via code interfaces defined on the domain
6. **NEVER EDIT RESOURCE SNAPSHOTS** — `priv/resource_snapshots/` is owned exclusively by `mix ash.codegen`; manual edits corrupt migration tracking
7. **NO DIRECT `Repo.*` IN ASH PROJECTS** — `Repo.all/get/insert` bypass Ash policies and notifications; use domain code interfaces. Any `Repo` call in an Ash project is an escape hatch and must be documented

## Quick Reference

### Domain Code Interface Pattern

```elixir
# Domain definition
defmodule MyApp.Accounts do
  use Ash.Domain

  resources do
    resource MyApp.Accounts.User do
      define :register_user, action: :create, args: [:email, :password]
      define :get_user_by_email, action: :read, get_by: [:email]
    end
  end
end

# In LiveView/Controller — always via domain, never Ash.create directly
{:ok, user} = MyApp.Accounts.register_user(email, password, actor: nil)
user = MyApp.Accounts.get_user_by_email!(email, actor: current_user)
```

### Authorization — Actor Must Be on Query

```elixir
# CORRECT — actor on query, policies evaluated per-row
MyApp.Post
|> Ash.Query.for_read(:list_published, %{}, actor: current_user)
|> Ash.read!()

# WRONG — actor on Ash call, bypasses row-level policy evaluation
MyApp.Post
|> Ash.Query.for_read(:list_published)
|> Ash.read!(actor: current_user)
```

### File Conventions (from `mix ash.gen.*`)

| File | Location | Behaviour |
|------|----------|-----------|
| Changes | `lib/app/ctx/changes/name.ex` | `use Ash.Resource.Change` |
| Policy Checks | `lib/app/ctx/checks/name.ex` | `use Ash.Policy.Check` |
| Custom Actions | `lib/app/ctx/actions/name.ex` | generic action logic |
| Custom Types | `lib/app/ctx/types/name.ex` | `use Ash.Type` |
| Validations | `lib/app/ctx/validations/name.ex` | `use Ash.Resource.Validation` |

### Generator Workflow

```bash
mix ash.gen.resource MyApp.Accounts.User --yes
mix ash.gen.domain MyApp.Accounts --yes
mix ash.codegen        # reads resource snapshots → generates migration
mix ecto.migrate
```

## References

Read the relevant reference before implementing unfamiliar patterns — especially authorization and AshPostgres migrations.

- `${CLAUDE_SKILL_DIR}/references/ash/actions.md` — Actions, changes, validations, error classes
- `${CLAUDE_SKILL_DIR}/references/ash/authorization.md` — Policies, actor placement, policy checks
- `${CLAUDE_SKILL_DIR}/references/ash/code_interfaces.md` — Domain code interfaces, define syntax
- `${CLAUDE_SKILL_DIR}/references/ash/relationships.md` — Relationships, loading, belongs_to vs has_many
- `${CLAUDE_SKILL_DIR}/references/ash/testing.md` — Ash testing patterns
- `${CLAUDE_SKILL_DIR}/references/ash/generating_code.md` — Generator workflow and flags
- `${CLAUDE_SKILL_DIR}/references/ash/querying_data.md` — Query building, filters, calculations
- `${CLAUDE_SKILL_DIR}/references/ash-phoenix/form_integration.md` — AshPhoenix.Form with LiveView
- `${CLAUDE_SKILL_DIR}/references/ash-phoenix/nested_forms.md` — Nested AshPhoenix forms
- `${CLAUDE_SKILL_DIR}/references/ash-phoenix/debugging_form_submissions.md` — Form debug patterns
- `${CLAUDE_SKILL_DIR}/references/ash-postgres/migrations.md` — AshPostgres migration workflow
- `${CLAUDE_SKILL_DIR}/references/ash-postgres/best_practices.md` — AshPostgres patterns
- `${CLAUDE_SKILL_DIR}/references/ash-postgres/multitenancy.md` — Multitenancy patterns
- `${CLAUDE_SKILL_DIR}/references/ash-authentication/usage-rules.md` — AshAuthentication setup, strategies, tokens
- `${CLAUDE_SKILL_DIR}/references/ash-json-api/usage-rules.md` — AshJsonApi domain setup, routes, resource config
- `${CLAUDE_SKILL_DIR}/references/ash-graphql/overview.md` — AshGraphql overview and setup
- `${CLAUDE_SKILL_DIR}/references/ash-graphql/domain_configuration.md` — Domain-level GraphQL config
- `${CLAUDE_SKILL_DIR}/references/ash-graphql/resource_configuration.md` — Resource-level GraphQL config
- `${CLAUDE_SKILL_DIR}/references/ash-graphql/custom_types.md` — Custom GraphQL types
