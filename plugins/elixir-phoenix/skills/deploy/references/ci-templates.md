# CI/CD Templates for Phoenix

GitHub Actions workflows for Phoenix applications with optional Claude Code integration.

## Contents

- [Basic Phoenix CI](#basic-phoenix-ci)
- [Dialyzer Job](#dialyzer-job-separate-for-caching)
- [Claude Code PR Review](#claude-code-pr-review)
- [Credo + Claude Combined Analysis](#credo--claude-combined-analysis)
- [Full Matrix Build](#full-matrix-build)
- [Deployment Workflow](#deployment-workflow)
- [Required Secrets](#required-secrets)
- [Local Pre-commit Hook](#local-pre-commit-hook)

## Basic Phoenix CI

```yaml
# .github/workflows/phoenix-ci.yml
name: Phoenix CI

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]

env:
  MIX_ENV: test

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      db:
        image: postgres:16
        ports: ['5432:5432']
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup Elixir
        id: beam
        uses: erlef/setup-beam@v1
        with:
          otp-version: '27.2'
          elixir-version: '1.18.0'

      - name: Cache deps
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          restore-keys: ${{ runner.os }}-mix-

      - name: Install dependencies
        run: mix deps.get

      - name: Compile (warnings as errors)
        run: mix compile --warnings-as-errors

      - name: Check formatting
        run: mix format --check-formatted

      - name: Run Credo
        run: mix credo --strict

      - name: Setup database
        run: mix ecto.setup
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/my_app_test

      - name: Run tests
        run: mix test --trace
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/my_app_test

      - name: Security audit
        run: mix sobelow --config --exit medium
```

## Dialyzer Job (Separate for Caching)

```yaml
  dialyzer:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Elixir
        id: beam
        uses: erlef/setup-beam@v1
        with:
          otp-version: '27.2'
          elixir-version: '1.18.0'

      - name: Cache deps
        uses: actions/cache@v4
        with:
          path: deps
          key: deps-${{ hashFiles('**/mix.lock') }}

      - name: Restore PLT cache
        uses: actions/cache/restore@v4
        id: plt_cache
        with:
          key: plt-${{ steps.beam.outputs.otp-version }}-${{ steps.beam.outputs.elixir-version }}
          path: priv/plts

      - name: Install dependencies
        run: mix deps.get

      - name: Create PLTs
        if: steps.plt_cache.outputs.cache-hit != 'true'
        run: mkdir -p priv/plts && mix dialyzer --plt

      - name: Save PLT cache
        uses: actions/cache/save@v4
        if: steps.plt_cache.outputs.cache-hit != 'true'
        with:
          key: plt-${{ steps.beam.outputs.otp-version }}-${{ steps.beam.outputs.elixir-version }}
          path: priv/plts

      - name: Run Dialyzer
        run: mix dialyzer --format github
```

## Claude Code PR Review

```yaml
  claude-review:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    needs: [test]
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Review this Phoenix/Elixir PR for:

            ## Ecto & Database
            - N+1 patterns (Enum.map with Repo calls, missing preloads)
            - Unsafe migrations (table locks, missing indexes)
            - Query performance on large tables

            ## OTP Patterns
            - GenServer blocking calls without timeouts
            - Missing supervision for spawned processes
            - Unbounded message queues

            ## Phoenix Specific
            - Business logic in controllers (should be in contexts)
            - LiveView assigns memory (large lists without streams)
            - Atom creation from user input

            ## Security
            - SQL injection via raw queries
            - Path traversal in file handling
            - Missing authorization checks

            Provide specific file:line references for any issues found.
```

## Credo + Claude Combined Analysis

```yaml
  credo-analysis:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    needs: [test]
    permissions:
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          otp-version: '27.2'
          elixir-version: '1.18.0'

      - name: Cache deps
        uses: actions/cache@v4
        with:
          path: deps
          key: deps-${{ hashFiles('**/mix.lock') }}

      - name: Install dependencies
        run: mix deps.get

      - name: Run Credo and analyze
        run: |
          mix credo --strict --format json > credo-report.json || true
          ISSUES=$(cat credo-report.json | jq '.issues | length')
          echo "Found $ISSUES Credo issues"
          echo "CREDO_ISSUES=$ISSUES" >> $GITHUB_ENV

      - name: Claude analyze Credo results
        if: env.CREDO_ISSUES > 0
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Analyze these Credo issues and provide specific fixes:
            $(cat credo-report.json)

            For each issue:
            1. Explain why it's a problem
            2. Show the fix with code
            3. Rate severity: Critical/Important/Minor
```

## Full Matrix Build

```yaml
name: Matrix CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        otp: ['26.2', '27.2']
        elixir: ['1.17.3', '1.18.0']
        exclude:
          - otp: '27.2'
            elixir: '1.17.3'

    services:
      postgres:
        image: postgres:16
        ports: ['5432:5432']
        env:
          POSTGRES_PASSWORD: postgres

    steps:
      - uses: actions/checkout@v4

      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          otp-version: ${{ matrix.otp }}
          elixir-version: ${{ matrix.elixir }}

      - name: Cache
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-${{ matrix.otp }}-${{ matrix.elixir }}-${{ hashFiles('**/mix.lock') }}

      - run: mix deps.get
      - run: mix compile --warnings-as-errors
      - run: mix test
```

## Deployment Workflow

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    needs: [test, dialyzer]
    steps:
      - uses: actions/checkout@v4

      # For Fly.io
      - uses: superfly/flyctl-actions/setup-flyctl@master
      - run: flyctl deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}

      # OR for Docker-based
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: registry/app:${{ github.sha }}

      # Run post-deploy migrations
      - name: Run migrations
        run: flyctl ssh console -C "/app/bin/my_app eval 'MyApp.Release.migrate()'"
```

## Required Secrets

Add these to your repository settings:

| Secret | Description |
|--------|-------------|
| `ANTHROPIC_API_KEY` | For Claude Code review |
| `FLY_API_TOKEN` | For Fly.io deployment |
| `DOCKER_USERNAME` | For Docker registry |
| `DOCKER_PASSWORD` | For Docker registry |

## Local Pre-commit Hook

```bash
#!/bin/sh
# .git/hooks/pre-commit

mix format --check-formatted || exit 1
mix compile --warnings-as-errors || exit 1
mix credo --strict || exit 1
mix test || exit 1
```
