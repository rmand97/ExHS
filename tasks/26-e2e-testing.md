# Task 26 — End-to-end (browser) testing

## Goal

Add a real-browser end-to-end (E2E) test layer that exercises JavaScript, LiveView
wire behaviour, and full user journeys against a running server — complementing the
existing ExUnit unit tests and `Phoenix.LiveViewTest` integration tests. We want the
same confidence the Phoenix LiveView project gets from its Playwright suite, adapted
to a product app that has a database, authentication, multitenancy (subdomains), and
Stripe.

## Prerequisites

- Task 3 (auth), Task 4 (multitenancy/subdomain), Task 25 (checkout) — all delivered.
- Existing test infrastructure: `test/support/conn_case.ex`, `data_case.ex`,
  `builders.ex`, Stripe/storage integration cases.

## Background — how Phoenix LiveView does it

Studied `phoenix_live_view/test/e2e` (main branch). Key facts:

- **Raw Playwright (JS), not Elixir.** Tests live in `test/e2e/tests/*.spec.js`, run by
  `@playwright/test` across Chromium, Firefox, WebKit.
- **Standalone server, separate Mix env.** `npm run e2e:server` →
  `MIX_ENV=e2e mix test --cover --export-coverage e2e test/e2e/test_helper.exs`.
  `test_helper.exs` defines a self-contained `Endpoint` (`server: true`, port 4004),
  `Router`, `Layout`, and a pile of synthetic LiveViews, then
  `Supervisor.start_link([Endpoint, PubSub])`. It blocks on a `receive` until a `:halt`
  message (sent via a `/halt` route or stdin EOF) so Playwright can shut it down.
- **No database.** Their suite tests the LiveView JS client itself, so there is no Ecto,
  no sandbox, no auth. This is the crucial difference from us — we cannot copy it
  wholesale.
- **`webServer` block in `playwright.config.js`** boots the server and waits on a
  `/health` route before running specs. `reuseExistingServer: !CI`.
- **Sync helper.** `utils.js` exports `syncLV(page)` which waits for `.phx-connected`
  and zero `.phx-*-loading` elements — the canonical "LiveView settled" barrier.
- **In-LV eval.** `evalLV()` pushes a `sandbox:eval` event handled by an `on_mount` hook
  that runs `Code.eval_string` inside the LiveView process — lets a test assert/mutate
  server-side socket state. `evalPlug()` does the same in a plug request.
- **Colocated assets** are compiled before boot via `Phoenix.LiveView.ColocatedAssets.compile()`.

### Their helper toolkit (the reason their specs read cleanly)

`utils.js` exports:
- `syncLV(page)` — waits until the LV is settled: `.phx-connected` visible **and** zero
  `.phx-change-loading` / `.phx-click-loading` / `.phx-submit-loading`. Called after
  every interaction before asserting. The single most-used helper.
- `evalLV(page, code, selector)` — runs server-side Elixir **inside the LiveView
  process** (via the `sandbox:eval` `on_mount` hook) and returns the result. Lets a JS
  test read/mutate socket assigns.
- `evalPlug(request, code)` — same, but inside a plug request (`/eval` controller).
- `attributeMutations(page, selector)` — installs a `MutationObserver` and returns a
  thunk; awaiting it yields the list of attribute changes since the call. For asserting
  JS-driven DOM mutations.
- `randomString(size)` — random test data.

`test-fixtures.js` extends Playwright's `test` with:
- a `page` fixture that, after every test, **fails on any unhandled JS error**
  (`page.on("pageerror")`) and asserts no leftover `[data-phx-skip]` — a free regression
  net. Opt out per-test with `ignoreJSErrors`.
- `autoTestFixture` — auto JS/CSS coverage (Chromium) with LiveView sourcemaps.

These exist largely **because they write raw JS Playwright**. Our mapping under option 2
(`PhoenixTest.Playwright`):
- `syncLV` → built in; PhoenixTest auto-waits for LiveView quiescence between actions.
- `evalLV` / `evalPlug` → mostly unnecessary — Elixir tests have direct process access
  and can use `Ash` + `Exhs.Test.Builders` to set up and assert state. Keep a thin
  socket-eval escape hatch only for the rare test that must inspect raw socket assigns.
- `page` no-JS-error guard + `[data-phx-skip]` check → **port regardless of approach**;
  framework-agnostic and high value. Wire into `ExhsWeb.E2ECase`.
- `attributeMutations` → port only if/when we test bespoke JS hooks doing DOM mutation.
- coverage fixture → optional, defer.

## Decision — DECIDED

**Driver: `PhoenixTest.Playwright` (Elixir/ExUnit), Chromium-only to start.**

Two paths were considered:

1. **Raw Playwright (JS), mirroring Phoenix LV.** Maximum control, multi-browser, but we
   must hand-roll a dedicated Mix env + endpoint, DB sandbox checkout across the HTTP
   boundary, seeding, auth-session injection, and subdomain host resolution. High setup
   cost; tests in JS, no reuse of `Exhs.Test.Builders`.
2. **`PhoenixTest.Playwright`.** Drives Playwright from ExUnit. Ecto sandbox isolation
   handled by the library, reuses our builders/case templates, runs under `mix test`,
   sets request host per-test (needed for subdomain multitenancy). Trade-off: thinner
   raw-Playwright access, younger lib.

**Chosen: option 2.** For a product app with DB + auth + tenancy, sandbox isolation and
builder reuse beat the raw-Playwright control a framework needs to test *itself*. Raw JS
Playwright stays documented as a fallback for any test needing low-level JS-client
assertions. **Chromium-only** initially — our JS surface is small (`app.js`,
`cookie-consent.js`, `live_select`, LiveView core); add Firefox/WebKit later via the
library's `parameterize:` if a real cross-browser bug appears.

### Library facts (researched — main inputs to Phase A)

- Deps: `{:phoenix_test, "~> 0.11", only: :test, runtime: false}` +
  `{:phoenix_test_playwright, "~> 0.14", only: :test, runtime: false}` (pulls
  `playwright_ex` transitively).
- Browser install: `npm --prefix assets i -D playwright` then
  `npx --prefix assets playwright install chromium --with-deps`. The browser must be
  installed with the **same** playwright JS version the lib runs (`assets/node_modules`).
- **Our endpoint is already wired for the sandbox**: `lib/exhs_web/endpoint.ex` already
  has `plug Phoenix.Ecto.SQL.Sandbox` gated on `config :exhs, :sql_sandbox`, and the
  `/live` socket already passes `connect_info: [:user_agent, ...]`. We just set
  `config :exhs, sql_sandbox: true` in `config/test.exs`.
- `PhoenixTest.Playwright.Case` checks out the Ecto repo per test and sends the sandbox
  metadata as a `User-Agent` header, so the browser session shares the test's
  transaction. `async: true` works.
- **Ash-auth caveat:** sandbox allow for LiveView processes must run via
  `on_mount_prepend` (our router already uses `on_mount_prepend` slots — that's where the
  sandbox-allow hook goes in test env).
- **LiveView-ownership caveat:** Playwright tests can end while a LiveView still holds the
  sandbox connection → `DBConnection.OwnershipError`. Mitigate with
  `@tag ecto_sandbox_stop_owner_delay: 100` (or a small global default) on affected tests.
- Server: needs `config :exhs, ExhsWeb.Endpoint, server: true` in test env.
- `test_helper.exs`: `{:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()` +
  `Application.put_env(:phoenix_test, :base_url, ExhsWeb.Endpoint.url())`.
- Case API: `visit/2`, `fill_in/3`, `click_link`/`click_button`, `assert_has/3`,
  `within/3`, plus browser extras `screenshot/3`, `evaluate/2`, `step/3`. `@tag trace:
  :open` opens the interactive trace viewer; `parameterize:` runs multiple browsers.
- **`syncLV` equivalent is built in** — `assert_has("body .phx-connected")` blocks until
  LiveView connects, and the lib auto-waits for quiescence between actions. No manual
  settle helper needed.
- Email/magic-link flows: drive `Plug.Swoosh.MailboxPreview` via `within("iframe >>
  internal:control=enter-frame", fn ... end)`.

## Plan

### Phase A — Harness setup
- [ ] Add deps: `{:phoenix_test, "~> 0.11", only: :test, runtime: false}` +
      `{:phoenix_test_playwright, "~> 0.14", only: :test, runtime: false}`; `mix deps.get`.
- [ ] Install Playwright + Chromium: `npm --prefix assets i -D playwright` then
      `npx --prefix assets playwright install chromium --with-deps`. Wire the browser
      install into the `setup` alias (or a dedicated `test.e2e` alias) and document.
- [ ] `config/test.exs`:
      `config :exhs, ExhsWeb.Endpoint, server: true`,
      `config :exhs, sql_sandbox: true` (activates the existing endpoint plug),
      `config :phoenix_test, otp_app: :exhs, playwright: [browser: :chromium, headless: true,
      trace: System.get_env("PW_TRACE", "false") in ~w(t true),
      screenshot: System.get_env("PW_SCREENSHOT", "false") in ~w(t true)]`.
- [ ] `test/test_helper.exs`: add
      `{:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()` and
      `Application.put_env(:phoenix_test, :base_url, ExhsWeb.Endpoint.url())`
      (keep the existing `Sandbox.mode(:manual)` and add `:e2e` to the exclude list).
- [ ] Add the **sandbox-allow `on_mount`** for LiveViews to the router's
      `on_mount_prepend` slots in test env (Ash-auth requirement). Verify whether
      `PhoenixTest.Playwright.Case` already injects this before adding our own.
- [ ] Create `test/support/e2e_case.ex` (`ExhsWeb.E2ECase`) on top of
      `PhoenixTest.Playwright.Case`: import `Exhs.Test.Builders`; helper to mint an
      authenticated session (drive the login form once, or reuse the
      `ConnCase.log_in_user/2` session approach); helper to build the tenant **host**
      (`#{subdomain}.localhost`) and prepend it to `base_url` so the `Subdomain` plug
      resolves a forening.
- [ ] `mix test.e2e` alias running only `@tag :e2e`; exclude `:e2e` from the default fast
      `mix test`/`precommit` (mirror existing `exclude: [:integration]`).
- [ ] **Port the one Phoenix LV helper that earns its keep**: a post-test assertion that
      fails on any unhandled browser JS error (via `evaluate/2` + page-error listener) and
      checks no leftover `[data-phx-skip]`. Skip `evalLV`/`evalPlug`/coverage —
      `syncLV` is already covered by `assert_has("body .phx-connected")`.

### Phase B — Cross-boundary concerns (the hard parts)
- [ ] **DB sandbox across the browser.** Confirm `PhoenixTest.Playwright` propagates the
      sandbox owner to the real browser session (it uses the same Phoenix.Ecto sandbox
      metadata mechanism our `ConnCase` already uses via the `user-agent` header). Write
      one smoke test proving data created in the test process is visible in the browser
      and rolled back after.
- [ ] **Multitenancy / subdomain.** Browsers resolve `*.localhost` to 127.0.0.1, so a
      test can hit `http://t-test.localhost:PORT`. Verify the `Subdomain` plug assigns
      `current_forening`/`current_tenant` from that host in the e2e endpoint. Add a
      cross-tenant E2E case (two foreninger, assert isolation through the real browser).
- [ ] **Auth.** Provide a login helper — either drive the real login form once, or inject
      an `AshAuthentication` session (reuse `ConnCase.log_in_user/2` approach) so most
      tests start authenticated without re-driving the form.
- [ ] **Stripe.** Checkout E2E must not hit real Stripe. Reuse `StripeIntegrationCase`'s
      local stripe-mock (`http://localhost:12111`) or stub the redirect; assert we reach
      the Stripe-hosted-checkout boundary, not beyond.
- [ ] Add a `syncLV`-equivalent settle helper if `PhoenixTest` doesn't already block on
      LiveView quiescence (it generally does between assertions).

### Phase C — Test inventory (write the specs)

Prioritised by user-facing risk and JS involvement. Each is one happy path + the obvious
failure/auth-redirect case (per CLAUDE.md testing rules).

**Public (unauthenticated) journeys — highest priority, most JS:**
- [ ] Home (`/`) renders for a resolved forening; wrong/unknown subdomain handled.
- [ ] Event browse → show (`/events` → `/events/:id`): list, filter, open detail.
- [ ] **Ticket checkout** (`/events/:id` → order → `/orders/:id`): select ticket +
      add-on, quantity limits enforced, hold created, proceed to Stripe boundary. This is
      the crown-jewel flow and the most JS-/LiveView-stateful.
- [ ] Join / membership signup (`/join`).
- [ ] Cookie-consent banner (`assets/js/cookie-consent.js`) — accept/reject persists.

**Member (authenticated) journeys:**
- [ ] Dashboard (`/dashboard`) loads for a logged-in member.
- [ ] Profile edit (`/profile`) — form submit, validation, live feedback.
- [ ] Registrations / payments / memberships show pages render member-scoped data only.
- [ ] Unauthenticated access → redirect to login.

**Admin journeys (authz-sensitive):**
- [ ] Members index → show (`/admin/members`), incl. the `live_select`
      combobox/multiselect (recently added JS, worth an explicit interaction test).
- [ ] Groups, Settings, Economy, Events index/show CRUD smoke.
- [ ] Real-time update: `members_pubsub` — change in one session reflects in another
      admin session (LiveView PubSub, genuinely needs a browser).
- [ ] Non-admin member hitting `/admin/*` → redirect/403.
- [ ] CSV export links (`/admin/export/*.csv`) return a file.

**Cross-cutting:**
- [ ] Locale switch (`/locale/:locale`) flips UI language (i18n).
- [ ] Cross-tenant isolation through the browser (see Phase B).

### Phase D — CI & polish
- [ ] Run E2E headless in CI; upload Playwright traces/screenshots on failure
      (`trace: retain-on-failure`, `screenshot: only-on-failure`).
- [ ] Keep E2E out of the fast `mix precommit` loop (too slow); run in a separate CI job.
- [ ] Document the workflow in README: `mix test.e2e`, browser install, headed debugging.

## Decided

- Driver: **`PhoenixTest.Playwright`** (ExUnit) over raw JS Playwright — sandbox + builder
  reuse for a DB/auth/tenancy app.
- Browser: **Chromium-only** to start; add Firefox/WebKit later via `parameterize:` only
  if a real cross-browser bug surfaces.
- Versions: `phoenix_test ~> 0.11`, `phoenix_test_playwright ~> 0.14` (confirmed via
  `mix hex.info`, 2026-06-09).

## Open questions (resolve during implementation)

- [ ] Does `PhoenixTest.Playwright.Case` already inject the LiveView sandbox-allow
      `on_mount`, or must we add it to the router's `on_mount_prepend` slots?
- [ ] Auth helper: drive the real login form once per session, or inject an
      `AshAuthentication` session like `ConnCase.log_in_user/2`? (Prefer session inject for
      speed; fall back to form if session injection fights the browser cookie domain.)
- [ ] Which tests need `ecto_sandbox_stop_owner_delay` (LiveView ownership) — set per-tag
      or a small global default?

## Done when

- E2E harness boots a real server with DB sandbox isolation and tenant/subdomain
  resolution working from a browser.
- The crown-jewel public checkout flow plus member + admin smoke journeys pass headless.
- Cross-tenant isolation verified through the browser.
- A documented `mix test.e2e` (or `npm run e2e:test`) command, excluded from the default
  fast test run, green in a dedicated CI job.
