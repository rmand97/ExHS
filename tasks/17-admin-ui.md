# Task 17 — Admin dashboard UI

## Goal
The forening admin's command center: members, events, shop, newsletters, economy, audit, settings — all scoped to the current forening.

## Prerequisites
- All preceding domain tasks (3–13), Task 14 (design system)

## Plan

### Routing & auth
- [ ] Admin scope under forening subdomain, requires Membership role `:admin` (or `:board` for read-only views)
- [ ] Use code interface `can_*` functions for conditional rendering (no policy duplication in UI)

### Layout
- [ ] App shell with sidebar (Members, Events, Shop, Newsletters, Economy, Audit, Settings) and topbar (user menu, forening switcher)
- [ ] Active-route highlighting
- [ ] Mobile-responsive (collapsible sidebar)

### Members
- [ ] List with filters (status, role, group), search, sort, pagination
- [ ] Bulk actions (assign to group, send newsletter to selection, export CSV)
- [ ] Member detail page: profile, memberships, payments, registrations, orders, groups, audit history
- [ ] Invite new member
- [ ] Manual activate/deactivate (escape hatch, audit-logged)
- [ ] Role management

### Groups
- [ ] CRUD groups
- [ ] Member assignment UI (chip selector)

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

### Newsletters
- [ ] Drafts list, sent list
- [ ] Composer (subject, body, segment picker)
- [ ] Test-send to admin
- [ ] Scheduled-send picker
- [ ] Sent-newsletter analytics (delivered, opened, bounced)
- [ ] Segment manager (CRUD reusable segments)

### Economy
- [ ] Revenue dashboard (kontingent, tickets, merch by month)
- [ ] Payment list with filters, refund action
- [ ] CSV export for accounting (Bogføringslov)
- [ ] Outstanding / failed payments

### Audit
- [ ] Forening-wide audit log with filters (actor, resource, action, date range)
- [ ] Per-record history panel (linked from member detail, event detail, etc.)

### Settings
- [ ] Forening profile (name, branding, logo upload)
- [ ] Kontingent settings (amount, Stripe price ID)
- [ ] Email "from" name and reply-to
- [ ] Admin management (add/remove admins, transfer ownership)
- [ ] Webhook secrets (Stripe)

### Superadmin area
- [ ] Separate scope (root domain or `admin.exhs.dk`)
- [ ] List all foreninger, create new, assign initial admin, archive
- [ ] Cross-tenant system health
- [ ] Oban dashboard mount (Task 13)

### Tests
- [ ] Admin-only routes deny non-admin
- [ ] Board sees read-only views, can't write
- [ ] All admin actions appear in audit log

## Open decisions
- [ ] **Bulk actions UX** — selection model (page-level vs filter-based "select all matching")
- [ ] **CSV vs Excel exports** — CSV is simpler, Excel is what accountants want
- [ ] **In-app notifications** — admin gets bell with new registrations, payments, etc.?

## Done when
- Admin can run their forening end-to-end without ever touching IEx or the DB
- All actions are audit-logged
- Board role works as read-only
- Superadmin can spin up a new forening from the UI
