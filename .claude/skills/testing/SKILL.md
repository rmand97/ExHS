---
name: testing
description: "Use this skill when writing or modifying tests. Covers shared builders, naming conventions, and testing philosophy for this project."
---

## Testing philosophy

Follow Saša Jurić's testing approach: tests should read like specifications. Each test tells a story — setup, action, assertion — with minimal ceremony.

## Shared builders

All test helpers live in `test/support/builders.ex` (`Exhs.Test.Builders`). Import it in every test module:

```elixir
import Exhs.Test.Builders
```

Available builders:

| Builder | Purpose |
|---------|---------|
| `register_user!(opts)` | Creates user. Opts: `:email`, `:superadmin` |
| `create_forening!(attrs)` | Creates forening with unique slug/subdomain |
| `invite_member!(forening, user, role \\ :member)` | Invites user to forening |
| `join_forening!(forening, user)` | User self-joins forening |
| `create_group!(forening, attrs)` | Creates group in forening |
| `membership_for!(forening, user)` | Looks up existing membership |
| `activate_stripe_connect!(forening)` | Activates Stripe Connect on forening |
| `set_stripe_customer!(forening, membership)` | Sets Stripe customer on membership |
| `scope(user, forening)` | Returns `%Exhs.Scope{}` |

**Do not** duplicate these in test modules. If a new builder is needed across 2+ test files, add it to `builders.ex`.

## Naming rules

- If a helper calls a bang (`!`) function, name the helper with a bang too: `create_forening!`, not `create_forening`.
- Domain-specific helpers that are only relevant to one test file stay local (e.g., `events_for/1` in audit tests, `subscription_event/3` in webhook tests).
- Composite setup functions (`setup_billing_member!`) stay local when they combine multiple builders for a specific test context.

## Test structure

- Use `describe` blocks to group by feature or action.
- One happy-path test plus obvious failure cases. Don't over-engineer.
- Test through code interfaces (same entry point real callers use), not internals.
- No elaborate factories, custom DSLs, or speculative edge cases.

## What to test more thoroughly

- **External dependencies** (Stripe, email, webhooks): cover success, failure, idempotency. Use fakes/stubs, never hit real services.
- **LiveViews**: mount, primary action, auth redirects. Skip for pure static render.
- **Policies/authorization**: test each role boundary.
- **Tenant isolation**: every feature that reads tenant-scoped data must have cross-tenant tests. Create two foreninger, put data in both, verify each only sees its own. This catches multitenancy filter bugs that are invisible in single-tenant tests. Specifically test:
  - List pages don't show other tenant's records
  - Show/detail pages reject IDs belonging to another tenant
  - Actions (create, update) can't reference cross-tenant resources

## Patterns

### Standard test module header
```elixir
defmodule Exhs.SomeTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.SomeDomain
```

### Policy tests
Test both positive (role has access) and negative (role denied) for each action. Group by action in `describe` blocks.

### Billing/webhook tests
Use local `setup_billing_member!/0` that composes shared builders. Keep event payload builders local.
