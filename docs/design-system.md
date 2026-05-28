# Exhs Design System

Visual language and component library for the Exhs foreningsadministration platform. Built on **Tailwind v4 + DaisyUI**, aligned with the styling used by `ash_authentication_phoenix`.

## Design Direction: Bold Dark (Design B)

Dark chrome, gradient accents, glassmorphism, vibrant color-coded cards. The dark theme is the primary UI; a tuned light theme is available as an alternate.

## Color Palette

All colors use oklch for perceptual uniformity. Defined in `assets/css/app.css` via DaisyUI theme plugins.

### Dark Theme (primary)

| Token | oklch | Usage |
|-------|-------|-------|
| `base-100` | `oklch(16% 0.02 270)` | Page background |
| `base-200` | `oklch(13% 0.018 270)` | Sunken surfaces |
| `base-300` | `oklch(10% 0.015 270)` | Deepest surfaces |
| `base-content` | `oklch(95% 0.01 270)` | Body text |
| `primary` | `oklch(68% 0.16 277)` | Primary actions, links |
| `secondary` | `oklch(72% 0.18 310)` | Secondary accents |
| `accent` | `oklch(75% 0.15 165)` | Tertiary accent |
| `success` | `oklch(72% 0.15 165)` | Positive states |
| `warning` | `oklch(78% 0.16 80)` | Caution states |
| `error` | `oklch(65% 0.2 20)` | Destructive / error |

### Light Theme (alternate)

Lighter versions of the same hues. `base-100` is near-white (`oklch(98.5% 0.005 270)`), saturated primary/secondary/accent adjusted for legibility on light backgrounds.

## Surface Treatments

### Glass Surface

Translucent background with backdrop blur. Use `.glass-surface` class or the `<.card>` component.

```
Dark: background oklch(100% 0 0 / 0.03), border oklch(100% 0 0 / 0.06), blur 12px
Light: background oklch(100% 0 0 / 0.7), border oklch(0% 0 0 / 0.08)
```

### Gradient Text

`.text-gradient` — linear gradient from primary to secondary, applied as background-clip text.

## Typography

System font stack via Tailwind defaults. No custom fonts loaded.

- Page titles: `text-3xl font-bold tracking-tight` or larger
- Section headers: `text-lg font-semibold`
- Body: `text-sm` with `text-base-content/60` for secondary text
- Labels: `text-sm font-medium`

## Spacing & Layout

- Page max-width: `max-w-7xl` centered with `mx-auto`
- Page padding: `px-4 sm:px-6 lg:px-8`
- Section spacing: `py-6` to `py-20` depending on context
- Card padding: `p-5` or `p-6`
- Grid gaps: `gap-4` to `gap-6`

## Border Radius

Set via DaisyUI theme tokens:

- `--radius-box: 1rem` (cards, modals)
- `--radius-field: 0.75rem` (inputs, selects)
- `--radius-selector: 0.75rem` (buttons, badges)

## Components

All components live in `lib/exhs_web/components/` as individual modules. Imported globally via `exhs_web.ex` html_helpers.

### Atoms

| Component | Module | File |
|-----------|--------|------|
| Icon | `ExhsWeb.Components.Icon` | `icon.ex` |
| Badge | `ExhsWeb.Components.Badge` | `badge.ex` |
| Avatar | `ExhsWeb.Components.Avatar` | `avatar.ex` |
| Skeleton | `ExhsWeb.Components.Skeleton` | `skeleton.ex` |

### Controls

| Component | Module | File |
|-----------|--------|------|
| Button | `ExhsWeb.Components.Button` | `button.ex` |
| Input | `ExhsWeb.Components.Input` | `input.ex` |
| Dropdown | `ExhsWeb.Components.Dropdown` | `dropdown.ex` |
| Tabs | `ExhsWeb.Components.Tabs` | `tabs.ex` |
| Modal | `ExhsWeb.Components.Modal` | `modal.ex` |

### Layout & Data

| Component | Module | File |
|-----------|--------|------|
| Card | `ExhsWeb.Components.Card` | `card.ex` |
| Header | `ExhsWeb.Components.Header` | `header.ex` |
| Table | `ExhsWeb.Components.Table` | `table.ex` |
| List | `ExhsWeb.Components.List` | `list.ex` |
| Stat Card | `ExhsWeb.Components.StatCard` | `stat_card.ex` |

### Feedback

| Component | Module | File |
|-----------|--------|------|
| Flash | `ExhsWeb.Components.Flash` | `flash.ex` |
| Empty State | `ExhsWeb.Components.EmptyState` | `empty_state.ex` |

### Core (JS + helpers)

| Module | File | Purpose |
|--------|------|---------|
| `ExhsWeb.CoreComponents` | `core_components.ex` | `show/2`, `hide/2`, `translate_error/1` |

## Component Usage

### Buttons

```heex
<.button variant="primary">Save</.button>
<.button variant="secondary">Cancel</.button>
<.button variant="ghost">Link-style</.button>
<.button variant="destructive">Delete</.button>
```

Variants: `primary`, `secondary`, `ghost`, `destructive`. Supports `disabled`, `type`, `class` attrs.

### Cards

```heex
<.card class="p-6">
  Content here
</.card>
```

Glass-surface card with `rounded-2xl`. Pass padding via `class` attr.

### Inputs

```heex
<.input name="email" label="Email" type="email" value="" errors={["invalid"]} />
<.input name="role" label="Role" type="select" options={[{"Admin", "admin"}]} value="admin" />
```

Types: `text`, `email`, `password`, `textarea`, `select`, `checkbox`, `hidden`.

### Stat Cards

```heex
<.stat_card
  label="Members"
  value="1,247"
  change="+12%"
  change_type="positive"
  icon="hero-users"
  color="primary"
/>
```

Colors: `primary`, `secondary`, `accent`, `warning`.

### Modal

```heex
<.button phx-click={show_modal("my-modal")}>Open</.button>
<.modal id="my-modal">
  Modal content
</.modal>
```

Import `show_modal/1` and `hide_modal/1` from `ExhsWeb.Components.Modal`.

### Empty State

```heex
<.empty_state icon="hero-calendar" title="No events yet">
  Create your first event to get started.
  <:action>
    <.button variant="primary">Create event</.button>
  </:action>
</.empty_state>
```

## Branding Per Forening

Each forening can override the primary color via CSS custom properties on a wrapper div. DaisyUI components automatically inherit the override.

```heex
<div style="--color-primary: oklch(65% 0.24 25); --color-primary-content: oklch(98% 0.01 25);">
  <%!-- All primary-colored components inside adapt --%>
  <.button variant="primary">Branded</.button>
  <.badge variant="primary">Branded</.badge>
</div>
```

This is applied at the layout level based on `forening.branding` data.

## Showcase

A live component showcase is available at `/dev/components` (dev and test environments only). It demonstrates every component in all states across 5 tabs: Overview, Data Display, Feedback, Forms, and Branding.

## Tailwind Configuration

Tailwind v4 — no `tailwind.config.js`. All configuration is in `assets/css/app.css`:

```css
@import "tailwindcss" source(none);
@source "../../deps/ash_authentication_phoenix";
@source "../css";
@source "../js";
@source "../../lib/exhs_web";
```

DaisyUI themes are configured via `@plugin` directives in the same file.

## Do Not

- Do not use `@apply` in CSS
- Do not create a `tailwind.config.js`
- Do not add inline `<script>` tags — use JS hooks
- Do not reference external vendor scripts/CSS via `src`/`href`
- Do not use raw DaisyUI class names when a component exists (use `<.button>` not `<button class="btn btn-primary">`)
- Do not add components to `core_components.ex` — create a new file under `components/`
