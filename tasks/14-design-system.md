# Task 14 — Design system

## Goal
A consistent visual language and a reusable component library built on **Tailwind v4 + DaisyUI** (the Phoenix 1.8 default), aligned with the styling used by `ash_authentication_phoenix`. This is a soft prerequisite for all UI tasks (15, 16, 17).

## Prerequisites
- Task 1 (asset pipeline set up)

## Decisions
- **Design B (Bold Dark)** chosen — dark chrome, gradient accents, glassmorphism, vibrant color-coded cards
- **DaisyUI themes** tuned: dark (preferred) + light, oklch color palette matching Design B
- **Component architecture**: every component in its own file under `lib/exhs_web/components/`, imported via `exhs_web.ex` html_helpers
- **LiveView 1.2 RC blocked** — `ash_authentication_phoenix` needs 3.0 RC (pulls ash_auth 5.0 RC). Staying on 1.1.30 until Ash stack stabilizes.
- **Branding-per-forening** — CSS custom property override (`--color-primary`) on wrapper div, components inherit automatically via DaisyUI vars. No runtime theme switching needed.

## Implementation

### Tailwind / DaisyUI setup
- [x] Tailwind v4 with `@import "tailwindcss" source(none);` in `assets/css/app.css`
- [x] DaisyUI plugin + light/dark theme plugins wired in `assets/css/app.css`
- [x] `@source "../../deps/ash_authentication_phoenix"` so DaisyUI classes used by auth UI are scanned
- [x] Dark theme tuned to Design B palette (oklch), light theme tuned as alternate
- [x] Glass surface utility (`.glass-surface`), gradient text utility (`.text-gradient`)
- [x] Forening branding CSS vars (`--forening-primary`, `--forening-primary-content`)
- [x] Custom `dark` variant for data-theme attribute

### Core components (split into individual files)
- [x] `icon.ex` — Heroicon renderer
- [x] `flash.ex` — toast-style flash notices
- [x] `button.ex` — primary, secondary, ghost, destructive variants
- [x] `input.ex` — text, email, password, textarea, select, checkbox, hidden
- [x] `header.ex` — page title with subtitle and actions
- [x] `table.ex` — zebra table with sortable cols and actions
- [x] `list.ex` — DaisyUI list with title/value rows
- [x] `card.ex` — glass-surface rounded-2xl card
- [x] `badge.ex` — variant-colored pill
- [x] `avatar.ex` — initials or image, 4 sizes, gradient background
- [x] `stat_card.ex` — icon + value + label + change indicator
- [x] `tabs.ex` — horizontal tab navigation
- [x] `modal.ex` — glass-surface modal with backdrop blur + show_modal/hide_modal JS
- [x] `empty_state.ex` — icon + title + description + action
- [x] `skeleton.ex` — loading skeleton placeholder
- [x] `dropdown.ex` — DaisyUI dropdown + dropdown_item
- [x] `core_components.ex` — thin barrel: JS commands (show/hide) + translate_error helpers

### Layout
- [x] App shell with top nav bar (Design B style), theme toggle, user avatar
- [x] Glass-surface cards, backdrop-blur nav

### Showcase / storybook
- [x] LiveView at `/dev/components` showing every component in all states
- [x] Tab navigation: Overview, Data Display, Feedback, Forms, Branding
- [x] Route available in dev and test environments

### Branding-per-forening
- [x] CSS custom property override demonstrated on showcase (Rødovre Forening red, Grøn Spejder green)
- [x] Works by wrapping content in div with `style="--color-primary: oklch(...)"`

### Tests
- [x] Showcase LiveView mounts and renders
- [x] Tab navigation works between all sections

## Done when
- [x] Showcase page renders all components in light and dark modes
- [x] All later UI tasks reuse these components — no ad-hoc Tailwind blobs in feature LiveViews
- [x] Branding-override demoed on two foreninger with different primary colors
