# Task 14 — Design system

## Goal
A consistent visual language and a reusable component library built on **Tailwind v4 + DaisyUI** (the Phoenix 1.8 default), aligned with the styling used by `ash_authentication_phoenix`. This is a soft prerequisite for all UI tasks (15, 16, 17).

## Prerequisites
- Task 1 (asset pipeline set up)

## Plan

### Decisions first
- [ ] Confirm DaisyUI theme set (light/dark already wired in `assets/css/app.css`) — adjust palette to brand
- [ ] Settle on typography stack (system font vs custom; size scale)
- [ ] Settle on spacing scale and border-radius scale (DaisyUI exposes `--radius-*` / `--size-*` already)
- [ ] Document branding-override mechanism so each forening can theme primary color (Task 4 stores branding) — likely via CSS custom properties layered on top of the DaisyUI theme

### Tailwind / DaisyUI setup
- [x] Tailwind v4 with `@import "tailwindcss" source(none);` in `assets/css/app.css`
- [x] DaisyUI plugin + light/dark theme plugins wired in `assets/css/app.css`
- [x] `@source "../../deps/ash_authentication_phoenix"` so DaisyUI classes used by auth UI are scanned
- [ ] Decide on additional Tailwind plugins (`@tailwindcss/forms`, `@tailwindcss/typography`)

### Core components (`lib/exhs_web/components/core_components.ex`)
- [ ] Buttons (primary, secondary, ghost, destructive; sizes; loading state) — wrap DaisyUI `btn` variants
- [ ] Form inputs (text, email, password, textarea, select, checkbox, radio, file)
- [ ] Form helpers (label, error, hint, fieldset)
- [ ] Modal / dialog
- [ ] Slide-over / drawer
- [ ] Toast / flash
- [ ] Card
- [ ] Badge / pill
- [ ] Avatar
- [ ] Data table (sortable header, empty state, pagination controls)
- [ ] Tabs
- [ ] Dropdown / menu
- [ ] Loading skeleton
- [ ] Empty state
- [ ] Stat card (for admin dashboard)

### Layout components
- [ ] App shell with sidebar + topbar (admin)
- [ ] Public-page shell (no sidebar, branding-aware)
- [ ] Auth screens layout (centered card) — already covered by `ash_authentication_phoenix` defaults; review and customize via `ExhsWeb.AuthOverrides`
- [ ] Responsive breakpoints documented

### Showcase / storybook
- [ ] Single LiveView at `/dev/components` (dev-only) showing every component in all states
- [ ] Acts as both docs and visual regression target

### Accessibility baseline
- [ ] All interactive components keyboard-navigable
- [ ] Focus states visible
- [ ] ARIA where appropriate
- [ ] Color contrast ≥ WCAG AA

### Tests
- [ ] The `/dev/components` showcase LiveView mounts and renders without errors (one LiveView test) — that's enough; visual correctness is not unit-testable
- [ ] No per-component unit tests for cosmetics; rely on the showcase + manual review

### Branding-per-forening
- [ ] CSS custom properties driven by forening branding (primary color, logo)
- [ ] Layout components consume CSS vars (compose with DaisyUI theme variables)

## Open decisions
- [ ] **Dark mode** — already wired via theme toggle; confirm we support from day 1 across all components
- [ ] **Internationalization markers** — components ready for translated strings (Task 19)

## Done when
- Showcase page renders all components in light and dark modes
- All later UI tasks reuse these components — no ad-hoc Tailwind blobs in feature LiveViews
- Branding-override demoed on two foreninger with different primary colors
