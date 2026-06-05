# ExHS Codebase Review

**Date:** 2026-06-05
**Reviewer:** Claude Opus 4.6
**Codebase:** ~16,000 lines across 156 files, 36 commits
**Test suite:** 302 tests, 0 failures (13 excluded integration tests)
**Credo:** 3 readability issues, 6 design suggestions (all minor)
**Compilation:** Clean, zero warnings

---

## Executive Summary

This is a well-structured Ash Framework application for Danish association (forening) management. The domain modeling is sensible, multitenancy is consistently applied, code interfaces are properly defined, and the test suite has good coverage with cross-tenant isolation tests. The Stripe integration is cleanly abstracted behind a behaviour pattern.

The codebase is in solid shape for an early-stage project. The issues below are organized by severity — the high-priority ones are genuine bugs or security gaps that should be fixed before any production deployment, while the medium and low items are architectural improvements.

---

## Overall Architecture Assessment

### What's done well

- **Domain separation** — Accounts, Organizations, Billing, Events, Audit, and Storage are clean bounded contexts with clear ownership.
- **Multitenancy** — Attribute-based multitenancy on `:forening_id` is consistent across all tenant-scoped resources. `Exhs.Scope` correctly implements `Ash.Scope.ToOpts`.
- **Code interfaces** — Domains define code interfaces, and LiveViews call them (not `Ash.create!` directly).
- **Stripe abstraction** — `StripeClient` behaviour + `StripeClient.Live` implementation + app-env config for stubs is a clean pattern.
- **Webhook idempotency** — Oban unique jobs keyed on Stripe event ID is a solid approach.
- **Test coverage** — 302 tests covering domain logic, policies, cross-tenant isolation, LiveViews, controllers, and Stripe webhooks. The policy test file alone has 47 tests.
- **Builder pattern** — Shared test builders are clean and minimal.
- **Design system** — Consistent DaisyUI + glass-surface design. Mobile-first layouts with progressive enhancement.
- **Cross-domain session handoff** — Phoenix.Token-based handoff with 300s TTL for subdomain navigation is well-implemented.
- **Project organization** — Task files, comprehensive CLAUDE.md, seeds file, precommit alias, ExSlop + ExDNA in Credo.

### Structural concerns

- **Client-side filtering on full datasets** — The Dashboard, Events, Payments, Registrations, and Activity LiveViews all load full datasets into memory, then filter and paginate in Elixir. This works at small scale but will degrade with growth.
- **Shared helper extraction** — `format_date`, `role_variant/label`, `status_variant/label`, `forening_logo`, `forening_url`, `format_kontingent` are duplicated across 5-8 LiveViews. A shared `ExhsWeb.DisplayHelpers` module would eliminate this.
- **Billing attributes on Forening** — `kontingent_*` and `stripe_*` attributes on the Organizations resource create cross-domain coupling. Pragmatic for now, but worth noting.

---

## High Priority Issues

These are bugs, security gaps, or crash risks that should be fixed before production.

### 1. Authorization bypass in `my_payments` action

**File:** `lib/exhs/billing/payment.ex:49-58`

The `my_payments` action takes `membership_ids` as an argument and trusts the caller to provide correct IDs. If an attacker provides another user's membership IDs, they see that user's payments. The policy is just `actor_present()`.

**Fix:** Derive membership IDs from the actor internally (like `my_subscriptions` does with `filter expr(membership.user_id == ^actor(:id))`), or validate that provided IDs belong to the actor.

### 2. Race condition in event registration capacity check

**File:** `lib/exhs/events/changes/check_capacity.ex:27-33`

The capacity check reads the confirmed count and sets the status, but without a database-level lock. Two concurrent registrations for the last spot could both read `count = capacity - 1` and both get `:confirmed`, exceeding capacity.

**Fix:** Use `SELECT count(*) ... FOR UPDATE` on the ticket type row, or a database-level constraint/trigger.

### 3. `String.to_existing_atom` on external Stripe data

**File:** `lib/exhs/billing/webhook.ex:151`

`String.to_existing_atom(sub["status"])` will raise `ArgumentError` if Stripe sends an unexpected status (e.g., `"paused"` which Stripe added). This crashes the Oban worker and retries 5 times before giving up, silently losing the event.

**Fix:** Use a safe mapping function:
```elixir
defp map_subscription_status("active"), do: :active
defp map_subscription_status("trialing"), do: :trialing
# ... etc
defp map_subscription_status(unknown), do: {:error, {:unknown_status, unknown}}
```

### 4. Database query inside `render/1`

**File:** `lib/exhs_web/live/public/home.ex:39-40`

The public home page calls `list_upcoming_events(assigns)` inside the `render/1` function. Every re-render triggers a database query.

**Fix:** Move the query to `mount/3` and store events in assigns.

### 5. CSS injection via branding colors

**File:** `lib/exhs_web/components/layouts.ex:301-316`

`forening_css_vars/1` interpolates `branding["primary_color"]` and `branding["accent_color"]` directly into an HTML `style` attribute without validation. A forening admin could inject arbitrary CSS to redress the UI.

**Fix:** Validate colors against a pattern (hex, oklch, or named colors only) before interpolation.

### 6. Protocol-relative open redirect

**File:** `lib/exhs_web/controllers/handoff_controller.ex:30`

`sanitize_return_to("/" <> _ = path)` also matches `//evil.com` (protocol-relative URL), which browsers treat as an absolute URL to `evil.com`.

**Fix:** Add `defp sanitize_return_to("//" <> _), do: "/"` before the current clause.

### 7. Missing policy on Registration `:promote` action

**File:** `lib/exhs/events/registration.ex` (policies block)

The `promote` action has no policy. Only superadmin and AshOban bypasses can reach it. If an admin ever tries to manually promote a waitlisted registration, it will be forbidden.

**Fix:** Add `policy action(:promote) do authorize_if {Exhs.Checks.HasMembershipRole, roles: [:admin]} end`.

### 8. `Jason.decode!` inside `with` chain

**File:** `lib/exhs_web/controllers/stripe_webhook_controller.ex:21`

`Jason.decode!(raw)` will raise instead of falling through to the error handling in the `with` block.

**Fix:** Use `{:ok, event_map} <- Jason.decode(raw)`.

---

## Medium Priority Issues

Architectural improvements, performance concerns, and code quality fixes.

### 9. N+1 query in member events page

**File:** `lib/exhs_web/live/member/events.ex:106-116`

`load_events` calls `list_public_events` once per membership. A user in 10 foreninger generates 10 queries.

**Fix:** Batch into a single query across all tenant IDs, or use a purpose-built action.

### 10. Activity page filters after pagination

**File:** `lib/exhs_web/live/member/activity.ex:126-147`

Client-side filters are applied AFTER server-side pagination. Filtering for a specific resource type only filters the current page, not all data.

**Fix:** Push the filter into the Ash query (add a `:resource` filter argument to the `my_activity` action), or load all data and paginate client-side.

### 11. Membership show loads all data then filters

**File:** `lib/exhs_web/live/member/membership_show.ex:139-163`

`find_membership` loads ALL memberships via `list_my_memberships` then does `Enum.find`. Same pattern for `find_subscription`. These should be targeted `get` calls.

### 12. Direct `__metadata__` manipulation

**File:** `lib/exhs_web/live/member/membership_show.ex:149`

`%{membership | __metadata__: Map.put(membership.__metadata__, :tenant, ...)}` reaches into Ash internals. Fragile and will break if Ash changes the metadata structure.

### 13. `Mix.env()` in runtime code

**File:** `lib/exhs_web/endpoint.ex:31`

`if Mix.env() == :dev` — `Mix` is not available in production releases. Will crash.

**Fix:** Use `if code_reloading?` or `if Application.compile_env(:exhs, :dev_routes)`.

### 14. Dead code

| File | Issue |
|------|-------|
| `lib/exhs_web/controllers/page_controller.ex` | Never routed to. `/` goes to `PublicLive.Home`. |
| `lib/exhs_web/controllers/page_html.ex` | Associated with dead PageController. |
| `lib/exhs_web/controllers/page_html/home.html.heex` | Duplicate of marketing content in PublicLive.Home. |
| `lib/exhs/billing/preparations/filter_by_actor_memberships.ex` | Never referenced by any resource or action. |

### 15. Webhook module uses raw `Ash.Query` instead of existing code interfaces

**File:** `lib/exhs/billing/webhook.ex:158-198`

Four separate queries use `Ash.Query` + `Ash.read_one!` when code interfaces like `get_subscription_by_stripe_id` already exist on the Billing domain.

### 16. Near-identical validation clones

**Files:**
- `lib/exhs/organizations/membership/validations/not_last_admin.ex`
- `lib/exhs/organizations/membership/validations/not_last_admin_destroy.ex`

Share identical admin-counting logic. Also use `Ash.read!` + `length()` instead of `Ash.count!`.

### 17. `list_upcoming` and `list_public` events are identical

**File:** `lib/exhs/events/event.ex:68-76`

Same filter, same sort. Only the policy differs. Consolidate into one action or differentiate the filters.

### 18. `SimpleCheck` does DB query per authorization

**Files:** `lib/exhs/checks/has_membership_role.ex`, `lib/exhs/checks/active_member.ex`

Every authorization call triggers a `Ash.read_one` query. For list actions authorizing per-record, this is an N+1.

**Fix:** Migrate to `Ash.Policy.FilterCheck` which pushes the check into SQL.

### 19. Forening redirect doesn't validate subdomain

**File:** `lib/exhs_web/controllers/forening_redirect_controller.ex:7-10`

The `subdomain` parameter is embedded into the redirect hostname without validation. An attacker could craft `/go/forening/evil.attacker.com` which redirects to `evil.attacker.com.exhs.dk`.

**Fix:** Look up the forening by subdomain before building the redirect URL.

### 20. Missing test builders for subscriptions and payments

The inline subscription/payment creation pattern (8+ fields) appears in 5+ test files. A `create_subscription!` and `record_payment!` builder would reduce duplication.

### 21. Runtime port config applies to all environments

**File:** `config/runtime.exs:30`

`http: [port: String.to_integer(System.get_env("PORT", "4000"))]` applies unconditionally. If `PORT` is set in the shell during test runs, it overrides the test port 4002.

**Fix:** Gate to prod: `if config_env() == :prod`.

---

## Low Priority Issues

Minor improvements, style consistency, and code hygiene.

### 22. Duplicated helpers across LiveViews

| Helper | Duplicated in |
|--------|--------------|
| `format_date/1` | 8 files (with variations) |
| `role_variant/1`, `role_label/1` | `dashboard.ex`, `membership_show.ex` |
| `status_variant/1`, `status_label/1` | `dashboard.ex`, `membership_show.ex` |
| `forening_logo/1` | `dashboard.ex`, `layouts.ex` |
| `forening_url/1` | `dashboard.ex`, `membership_show.ex` |
| `format_kontingent/1` | `join.ex`, `membership_show.ex` |
| `format_price/2` | `payments.ex`, `events/show.ex`, `membership_show.ex` |
| `apply_filters/apply_filter` | 5 LiveViews (identical scaffolding) |

**Fix:** Extract to `ExhsWeb.DisplayHelpers` and import in the `:live_view` macro.

### 23. TODO comments in email senders

**Files:** All three senders in `lib/exhs/accounts/user/senders/`

`# TODO: Replace with your email` — these are generated scaffolding markers that should be resolved.

### 24. Missing inverse relationships

- `Membership` has no `has_many :subscriptions`, `has_many :registrations`
- `Event` has no `has_many :registrations` (only through ticket types)
- `TicketType` has no `has_many :registrations`
- `User` has no `has_many :memberships`

### 25. Audit EventLog not tenant-scoped

**File:** `lib/exhs/audit/event_log.ex`

All other data resources use multitenancy. The audit log does not, making tenant-scoped queries impossible. This may be intentional for superadmin overview.

### 26. Inconsistent superadmin bypass style

The `Exhs.Checks.Superadmin` module is used everywhere except `EventLog`, which uses `actor_attribute_equals(:is_superadmin, true)` inline. Same logic, different spelling.

### 27. No loading states in LiveViews

The `Skeleton` component exists but is never used outside the showcase. No LiveView shows loading states during data fetches.

### 28. Webhook controller double-decodes payload

**File:** `lib/exhs_web/controllers/stripe_webhook_controller.ex:20-21`

`Stripe.Webhook.construct_event` already decodes the JSON. Then `Jason.decode!(raw)` decodes it again. Use the result from `construct_event`.

### 29. `checkout.session.completed` silently ignored

**File:** `lib/exhs/billing/webhook.ex:17`

No comment explaining why. Relies on `customer.subscription.created` arriving instead.

### 30. Redundant `require Ash.Query` calls

**File:** `lib/exhs/billing/webhook.ex:175,189`

Already required at module level (line 13). These inner requires are dead code.

### 31. Icon component has no catch-all

**File:** `lib/exhs_web/components/icon.ex`

Only handles `hero-` prefixed names. Any other name causes an unhelpful `FunctionClauseError`.

### 32. `auth_controller.ex` return_to not sanitized

**File:** `lib/exhs_web/controllers/auth_controller.ex:6,48`

`return_to` from session used in redirect without path validation. Lower risk since session data is server-controlled, but defense-in-depth suggests sanitizing.

---

## Test Coverage Gaps

The test suite is strong overall. These are the notable gaps:

| Area | Gap |
|------|-----|
| **Cross-tenant events** | Domain-layer isolation for events/registrations/ticket_types not tested (only tested through LiveViews) |
| **Cross-tenant billing** | No test verifying subscription/payment isolation at the domain layer |
| **Auth controller** | `success/4` and `failure/4` callbacks have zero direct test coverage |
| **ApiKey resource** | Exists but has zero tests |
| **Event update/destroy** | Only creation and publishing are tested |
| **Ticket type update/destroy** | Only creation is tested |
| **Registration by non-member** | Edge case not tested |
| **Password reset end-to-end** | Token request tested, but actual reset flow not tested |
| **Event registration UI** | "Tilmeld" button renders but clicking it is not tested |
| **Upload helpers** | `lib/exhs_web/live/upload_helpers.ex` has no tests |
| **Activity isolation** | The "user B doesn't see user A's events" test at `activity_test.exs:114` is a false positive — both users create groups, so user B's page contains "Oprettet" and "Gruppe" from their own actions |

---

## Recommendations (Priority Order)

1. **DONE Fix the security issues** — `my_payments` auth bypass (#1), open redirect (#6), CSS injection (#5)
2. **DONE Fix the bugs** — render-time query (#4), `Jason.decode!` crash (#8), `String.to_existing_atom` crash (#3)
3. **DONE Add missing policy** — Registration `:promote` (#7)
4. **DONE Address capacity race condition** (#2) — FOR UPDATE lock on ticket type row
5. **DONE Fix `Mix.env()` in endpoint** (#13) — replaced with `code_reloading?`
6. **DONE Delete dead code** (#14) — PageController, PageHTML, template removed
7. **DONE Extract shared helpers** (#22) — ExhsWeb.DisplayHelpers module
8. **DONE Add missing test builders** (#20) and fill cross-tenant test gaps
9. **Replace client-side filtering** with server-side queries as data grows
10. **Migrate SimpleChecks to FilterChecks** (#18) — medium-term performance improvement

---

## Verdict

For a project built with Gemini, this is surprisingly well-organized. The Ash patterns are largely correct, the domain modeling is clean, and the test coverage is above average for a project at this stage. The multitenancy implementation is consistent and the Stripe integration is properly abstracted.

The high-priority items (#1-8) are the kind of issues that are easy to miss during rapid development but important to catch before production. None of them are fundamental design flaws — they're fixable without restructuring.

The medium-term work is about scaling: replacing client-side filtering with server-side queries, migrating SimpleChecks to FilterChecks, and extracting shared helpers to reduce duplication. These don't block shipping but will matter as the user base grows.
