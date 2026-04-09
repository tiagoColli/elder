# Elder — agent instructions

Use this file when working in the Elder repo: Elixir/Phoenix LiveView changes, Ecto/Postgres, tests, or Docker-based dev commands.

## Project

Elder is a Phoenix LiveView app: Google OAuth (`Ueberauth`), authenticated dashboard, file-backed **skills** with persisted **skill runs**, LLM calls (`req_llm`), and Asana HTTP integration. Domain lives under `lib/elder/`; HTTP/UI under `lib/elder_web/`.

## Stack (authoritative: `mix.exs`)

- Elixir `~> 1.18`, Phoenix 1.7+, LiveView, Ecto/PostgreSQL, Bandit, Jason, Credo, Dialyzer (dev/test), ExCoveralls

Respect APIs and language features available for the Elixir version declared in `mix.exs`.

## Local development

Commands run **inside Docker** via `./dev.sh` (see `README.md`).

| Goal | Command |
|------|---------|
| Start stack | `./dev.sh` |
| Mix task | `./dev.sh run <task>` e.g. `./dev.sh run test` |
| Quality (fmt, compile, credo, dialyzer) | `./dev.sh check` |
| Tests | `./dev.sh test` or `./dev.sh test path/to/test.exs` |
| IEx | `./dev.sh iex` |
| DB console | `./dev.sh db` / `./dev.sh db test` |

Prefer running these yourself when verifying changes; do not only suggest commands.

## Context layout (`lib/elder/<context>/`)

- `schemas/` — Ecto schemas: `Elder.<Context>.Schemas.<Schema>`
- `query.ex` — composable reads; queryable-in / queryable-out
- `write.ex` — creates/updates/deletes
- `<context>.ex` — thin public API: `defdelegate` to Query/Write (and small orchestration when needed)

**Examples:** `Elder.Accounts`, `Elder.Skills`, `Elder.Llm`, `Elder.Asana`.

## Web layer (`lib/elder_web/`)

- LiveViews: `homepage`, `dashboard`, `skills`, `skill_run` (see `router.ex`)
- Auth: `SetCurrentUser`, `RequireAuth`, `LiveAuth` for `live_session`
- Keep LiveViews and controllers thin; delegate to `Elder.*` contexts

## Code expectations

- Match existing modules: naming, `@spec`/`@doc` level, imports, and return shapes already in the file
- Prefer `{:ok, _}` / `{:error, _}` at boundaries; follow patterns in-repo over generic templates
- Focused diffs: change what the task needs; avoid drive-by refactors or unrelated files
- Tests: ExUnit; DB tests use Ecto repo (test alias creates/migrates DB — see `mix.exs` `test` alias)

## Integrations (boundaries)

- **LLM:** `Elder.Llm` / client modules — keep provider details at the edge
- **Asana:** `Elder.Asana` / `Elder.Asana.Client` — use behaviours/mocks where tests already do
- **Skills on disk:** `Elder.Skills.SkillFile` — skills are files; runs are DB rows (`SkillRun`)

## User Cursor skills (optional depth)

For stricter house style on Elixir code, docs, logs, tests, reviews, git, and workflows, the maintainer’s skills live under `~/.cursor/skills/` (e.g. `standards/elixir-code`, `standards/elixir-tests`). Use when the task needs project-grade consistency beyond this file.
