# Task 14 — Design system

## Goal
A consistent visual language and a reusable component library backed by **Tailwind** components (NOT DaisyUI). This is a hard prerequisite for all UI tasks (15, 16, 17).

## Prerequisites
- Task 1 (asset pipeline set up)

## Plan

### Decisions first
- [ ] Pick a Tailwind component reference: shadcn-inspired-for-Phoenix, headlessui_phoenix, hand-rolled — **decision needed**
- [ ] Settle on a base color palette (primary, neutral, success, warning, error)
- [ ] Settle on typography stack (system font vs custom; size scale)
- [ ] Settle on spacing scale and border-radius scale
- [ ] Document branding-override mechanism so each forening can theme primary color (Task 4 stores branding)

### DaisyUI removal
- [ ] Remove `assets/vendor/daisyui.js` and `assets/vendor/daisyui-theme.js`
- [ ] Remove DaisyUI references from `assets/css/app.css` and `tailwind.config.js`
- [ ] Replace any existing DaisyUI-flavored components in `core_components.ex` with new Tailwind equivalents
- [ ] Keep `heroicons` (it's a vendor svg sprite, framework-agnostic)

### Tailwind setup
- [ ] Confirm Tailwind CSS version (v4?) — affects config style
- [ ] `tailwind.config.js` with theme tokens for palette + spacing + radii
- [ ] Plugin allow-list: `@tailwindcss/forms`, `@tailwindcss/typography`

### Core components (`lib/exhs_web/components/core_components.ex`)
- [ ] Buttons (primary, secondary, ghost, destructive; sizes; loading state)
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
- [ ] Auth screens layout (centered card)
- [ ] Responsive breakpoints documented

### Showcase / storybook
- [ ] Single LiveView at `/dev/components` (dev-only) showing every component in all states
- [ ] Acts as both docs and visual regression target

### Accessibility baseline
- [ ] All interactive components keyboard-navigable
- [ ] Focus states visible
- [ ] ARIA where appropriate
- [ ] Color contrast ≥ WCAG AA

### Branding-per-forening
- [ ] CSS custom properties driven by forening branding (primary color, logo)
- [ ] Layout components consume CSS vars

## Open decisions
- [ ] **Component reference library** — biggest decision; affects everything below it
- [ ] **Dark mode** — support from day 1 or defer?
- [ ] **Internationalization markers** — components ready for translated strings (Task 19)

## Done when
- Showcase page renders all components in light (and dark, if scoped) modes
- No DaisyUI artifacts in repo
- All later UI tasks reuse these components — no ad-hoc Tailwind blobs in feature LiveViews
- Branding-override demoed on two foreninger with different primary colors
