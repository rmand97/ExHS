# Task 17 — Admin dashboard UI

## Goal
The forening admin's command center: members, events, shop, newsletters, economy, audit, settings — all scoped to the current forening.

## Prerequisites
- All preceding domain tasks (3–13), Task 14 (design system)

## Plan

### Routing & auth
- [x] Admin scope under forening subdomain, requires Membership role `:admin` (or `:board` for read-only views) — `LiveForeningAuth.:require_admin` on_mount, `admin_routes` live_session
- [ ] Use code interface `can_*` functions for conditional rendering (no policy duplication in UI) — currently gated via `@can_write?` assign derived from role; revisit if `can_*` interfaces are added

### Layout
- [x] App shell with sidebar (Members, Events, Shop, Newsletters, Economy, Audit, Settings) and topbar (user menu, forening switcher) — `Layouts.admin`; unbuilt sections shown disabled ("snart")
- [x] Active-route highlighting
- [x] Mobile-responsive (collapsible sidebar)

### Members
- [x] List with filters (status, role, group), search, sort, pagination — `AdminLive.Members.Index`, `MemberFilter`
- [x] Bulk actions (assign to group, send newsletter to selection, export CSV) — group-assign + activate/deactivate + CSV export done; newsletter deferred to Newsletters slice
- [x] Member detail page: profile, memberships, payments, registrations, orders, groups, audit history — `AdminLive.Members.Show` (orders pending Shop slice)
- [x] Invite new member — email + passwordless user + magic-link via `InviteWorker` (Oban)
- [x] Manual activate/deactivate (escape hatch, audit-logged)
- [x] Role management

### Groups
- [x] CRUD groups — `AdminLive.Groups.Index`
- [x] Member assignment UI (chip selector)

### Events
- [ ] List events (upcoming, past, drafts)
- [ ] Create / edit event with multiple ticket types
- [ ] Cover image upload (Task 12)
- [ ] Registration list per event (export CSV, see waitlist)
- [ ] Publish / unpublish

### Shop (mostly TBD per Task 10)
- [ ] Product list
- [ ] Create / edit product
- [ ] Orders list with fulfillment status

### Newsletters (TBD - defer for now)
- [ ] Drafts list, sent list
- [ ] Composer (subject, body, segment picker)
- [ ] Test-send to admin
- [ ] Scheduled-send picker
- [ ] Sent-newsletter analytics (delivered, opened, bounced)
- [ ] Segment manager (CRUD reusable segments)

### Economy
- [x] Revenue dashboard (kontingent, tickets, merch by month) — `AdminLive.Economy.Index`; `Exhs.Billing.Revenue` aggregates by `PayableType`/`PaymentStatus` enum values (extensible — new revenue source appears with no code change)
- [x] Payment list with filters, refund action — LiveView streams + `Exhs.Billing.PaymentFilter`; refund = `mark_refunded` state flip (real Stripe refund API deferred to a billing task)
- [x] CSV export for accounting (Bogføringslov) — `AdminExportController.payments`
- [x] Outstanding / failed payments — surfaced as the "Udestående" figure (pending + failed)

### Audit
- [ ] Forening-wide audit log with filters (actor, resource, action, date range)
- [ ] Per-record history panel (linked from member detail, event detail, etc.)

### Settings
- [x] Forening profile (name, branding) — `AdminLive.Settings.Index` General tab; logo/banner upload deferred (upload plumbing not yet wired)
- [x] Kontingent settings (amount, Stripe price ID)
- [x] Email "from" name and reply-to — stored in `branding` map
- [x] Admin management (add/remove admins) — promote/demote via Admins tab, reuses `set_member_role` (NotLastAdmin guard); transfer-ownership deferred
- [ ] Webhook secrets (Stripe) — deferred (app-level/sensitive)

### Superadmin area
- [ ] Separate scope (root domain or `admin.exhs.dk`)
- [ ] List all foreninger, create new, assign initial admin, archive
- [ ] Cross-tenant system health
- [ ] Oban dashboard mount (Task 13)

### Tests
LiveView tests via `Phoenix.LiveViewTest` — every interactive admin screen gets at least one test.

- [x] Admin-only routes deny non-admin (sign-in redirect or 403) — Members slice
- [x] Board role sees read-only views; write actions are absent or rejected — Members slice
- [x] Primary create/update/destroy action per admin LiveView submits and updates the page — Members + Groups
- [x] All admin actions appear in audit log — AshEvents logs invite/set_role/deactivate/group-add against the record; asserted in `admin_members_test` "audit log"
- [x] Bulk-action selection + apply works for at least one resource — bulk deactivate on members

## Open decisions
- [ ] **Bulk actions UX** — selection model (page-level vs filter-based "select all matching")
- [ ] **CSV vs Excel exports** — CSV is simpler, Excel is what accountants want
- [ ] **In-app notifications** — admin gets bell with new registrations, payments, etc.?

## Done when
- Admin can run their forening end-to-end without ever touching IEx or the DB
- All actions are audit-logged
- Board role works as read-only
- Superadmin can spin up a new forening from the UI
