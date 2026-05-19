# Task 2 — AI-driven dev setup

## Goal
Set the project up so AI assistants (Claude Code et al.) have authoritative, up-to-date guidance, and so static analysis catches drift before it lands. The project leans heavily on AI for implementation — this task is the "rails" that keep it on track.

## Prerequisites
- Task 1 (deps installed)

## Plan

### Usage rules sync
- [ ] Confirm `usage_rules` is in deps (added in Task 1)
- [ ] Run `mix usage_rules.sync --all` to pull usage rules from all dependencies into `AGENTS.md` / `CLAUDE.md`
- [ ] Add a CI check that fails if usage rules are out of sync with deps
- [ ] Document `mix usage_rules.docs` and `mix usage_rules.search_docs` in `AGENTS.md` so agents know to consult them

### Agent guidance docs
- [ ] Audit existing `AGENTS.md` and `CLAUDE.md`; consolidate where redundant
- [ ] Add project-specific conventions section: domain naming, multitenancy (Task 4), Ash.Scope usage, code interfaces vs Ash. calls, no Repo. outside infrastructure code
- [ ] Add "do not do" list: no raw Ecto in domains, no `String.to_atom` on input, no DaisyUI components, no `require_atomic? false` without justification
- [ ] Point agents at `tasks/00-plan.md` as the source of truth for project scope

### Credo
- [ ] Add `.credo.exs` with a strict ruleset (start from `Credo.defaults` and tighten)
- [ ] Enable specific checks: `Credo.Check.Readability.StrictModuleLayout`, `Credo.Check.Refactor.LongQuoteBlocks`, etc.
- [ ] Wire `mix credo --strict` into CI
- [ ] Resolve all warnings on the existing skeleton so CI starts green

### Dialyzer
- [ ] Configure `dialyxir` (PLT location, ignored apps)
- [ ] Build PLTs in CI with caching
- [ ] Add `mix dialyzer` to CI (allow-list for known framework noise)

### Formatter & linting
- [ ] Ensure `.formatter.exs` includes Ash, Phoenix, AshPhoenix formatter plugins
- [ ] Add `mix format --check-formatted` to CI (already in Task 1)

### ex_slop
- [ ] Install and configure `ex_slop` per its README
- [ ] Decide where it runs: CI only? Pre-commit? Document the workflow
- [ ] Add to AGENTS.md so agents know what it enforces

### Pre-commit (optional)
- [ ] Decide whether to use a pre-commit framework (`pre-commit`, `git_hooks`) or rely on CI
- [ ] If yes: install hooks for `mix format`, `mix credo`, `mix usage_rules.sync --check`

### Claude Code skills / config
- [ ] Review `.claude/` directory; ensure project-relevant skills are enabled
- [ ] Add any project-specific allowed-bash-commands to `.claude/settings.json` to cut down on permission prompts
- [ ] Document in `AGENTS.md` which skills agents should reach for (ash-framework, phoenix-framework, simplify, review)

## Open decisions
- [ ] **Pre-commit vs CI-only** — pre-commit catches earlier but adds friction for human devs
- [ ] **Credo strictness level** — strict from day 1, or ratchet up over time?
- [ ] **Dialyzer in CI** — keep enabled or make it an optional/scheduled job (it's slow)?

## Done when
- `mix credo --strict`, `mix format --check-formatted`, `mix dialyzer`, `mix usage_rules.sync --check` all pass in CI
- `AGENTS.md` is the single canonical agent briefing, with usage rules synced
- A new contributor (human or AI) can read `AGENTS.md` + `tasks/00-plan.md` and orient in <10 minutes
