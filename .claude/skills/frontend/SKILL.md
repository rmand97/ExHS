---
name: frontend
description: "Use this skill when building or modifying UI: LiveView templates, components, layouts, CSS, and responsive design. Covers mobile-first patterns, component conventions, Tailwind v4 with DaisyUI, and design system rules for this project."
---

## Mobile-first mandate

Every page and component must work well on small screens (320px) before scaling up. Base Tailwind classes target mobile; use `sm:`, `md:`, `lg:` prefixes to layer on wider layouts. If it doesn't look right on a phone, it's not done.

### Responsive breakpoints

| Prefix | Min-width | Typical use |
|--------|-----------|-------------|
| (none) | 0px | Phone — the default |
| `sm:` | 640px | Large phone / small tablet |
| `md:` | 768px | Tablet |
| `lg:` | 1024px | Desktop |

Always think "what does this look like at 320px?" first, then progressively enhance.

### Key patterns

**Navigation**: The member layout uses a `flex-wrap` tab bar below `md:` that wraps into multiple rows. Desktop shows inline nav in the header bar. Never use `overflow-x-auto` on navigation — it hides items and is bad UX.

**Tables**: The `<.table>` component wraps its `<table>` in `overflow-x-auto` with negative margins (`-mx-4 px-4 sm:mx-0 sm:px-0`) so data tables can scroll edge-to-edge on mobile. This is acceptable for data-heavy views (activity, payments, registrations). For simpler lists, prefer card-based layouts over tables.

**Grids**: Use mobile-first grid patterns:
```
grid gap-4 sm:grid-cols-2 lg:grid-cols-3
```
Never set a multi-column grid without a breakpoint prefix — base should always be single-column.

**Spacing**: Use tighter spacing on mobile and increase at breakpoints:
```
p-4 sm:p-6 lg:p-8
gap-3 sm:gap-4 lg:gap-6
```

**Touch targets**: Buttons and interactive elements must be at least 44x44px on mobile. DaisyUI button sizes handle this, but custom interactive elements need explicit sizing.

**Hover effects**: Never rely on hover for critical interactions — mobile has no hover. Disable decorative hover effects on mobile:
```
sm:hover:scale-[1.02]     (not hover:scale-[1.02])
sm:hover:shadow-lg        (not hover:shadow-lg)
```
Use `sm:hover:` prefix for any scale/shadow/transform hover effects. Color-based hover states (`hover:bg-*`) are fine everywhere.

## Tailwind v4 + DaisyUI

This project uses Tailwind v4 with DaisyUI v5. There is **no `tailwind.config.js`**. Configuration is done in `assets/css/app.css` via `@plugin` directives.

### DaisyUI component classes

Use DaisyUI classes directly in templates:
```
btn btn-primary btn-sm
badge badge-success
```

### Color system

Use DaisyUI semantic colors, never raw colors:
```
text-base-content          (main text)
text-base-content/70       (secondary text)
text-base-content/50       (muted text)
text-base-content/40       (disabled text)
bg-base-100               (card/surface background)
bg-base-200               (page background)
bg-base-300               (inset/well background)
text-primary               (links, accents)
text-success/error/warning (status colors)
```

Opacity modifiers on semantic colors: `text-base-content/50`, `bg-primary/10`.

### Glass surface

Use the `.glass-surface` utility class for elevated cards and surfaces. It provides backdrop blur and subtle borders that adapt to light/dark themes. Applied automatically by the `<.card>` component.

### Gradient text

Use `.text-gradient` for primary-to-secondary gradient text effects (marketing pages only).

## Component system

### Core components (always available via imports)

| Component | Usage |
|-----------|-------|
| `<.card>` | Glass-surface container. Pass content via slot. Add padding with `class="p-5"` |
| `<.button>` | DaisyUI button. Supports `variant`, `size` attrs |
| `<.input>` | Form input with label/error. Always use over raw `<input>` |
| `<.badge>` | Status badges. `variant`: success, warning, error, default, primary |
| `<.icon>` | Heroicon. `name="hero-*"`, `class="size-5"` |
| `<.header>` | Page header with title, subtitle slot, actions slot |
| `<.table>` | Data table with column slots. Mobile-scrollable |
| `<.modal>` | Modal dialog. Responsive padding |
| `<.stat_card>` | Dashboard stat with icon, value, label |
| `<.empty_state>` | Empty content placeholder with icon and message |
| `<.list>` | DaisyUI list with `:item` slots |
| `<.skeleton>` | Loading placeholder |
| `<.flash_group>` | Flash messages — lives in layouts only |

### Component conventions

- Extract repeated markup into private function components within the LiveView (`defp card(assigns)`, `defp event_row(assigns)`)
- If reused across 2+ LiveViews, promote to a module under `ExhsWeb.Components`
- Component slots over complex conditional rendering
- Keep component files single-purpose — one public component per file

### Layout components

Three layout variants, used as the outermost wrapper in LiveView templates:

| Layout | Usage | File |
|--------|-------|------|
| `<Layouts.marketing>` | Landing page (no forening) | `layouts.ex` |
| `<Layouts.public>` | Public forening pages (events, join, home) | `layouts.ex` |
| `<Layouts.member>` | Authenticated member area | `layouts.ex` |

Always wrap template content in the appropriate layout. Pass required assigns:
```heex
<Layouts.member flash={@flash} current_user={@current_user} current_path={@current_path}>
  ...content...
</Layouts.member>
```

## Design patterns

### Cards

Cards are the primary content container. Standard pattern:
```heex
<.card class="p-5">
  <h3 class="text-base-content font-semibold">Title</h3>
  <p class="text-base-content/60 mt-2 text-sm">Description</p>
</.card>
```

### Page structure

Standard page layout:
```heex
<Layouts.member ...>
  <.header>
    Page Title
    <:subtitle>Description</:subtitle>
    <:actions><.button>Action</.button></:actions>
  </.header>

  <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
    ...content cards...
  </div>
</Layouts.member>
```

### Empty states

Always show a meaningful empty state when lists are empty:
```heex
<.empty_state icon="hero-calendar-days" title="Ingen kommende events">
  Optional description text
</.empty_state>
```

### Loading states

Use skeleton placeholders that match the shape of the content they replace:
```heex
<div :if={@loading} class="mt-6 space-y-4">
  <.skeleton class="h-10 w-full" />
  <.skeleton class="h-64 w-full" />
</div>
```

### Status badges

Use consistent badge variants for status indicators:

| Status type | Variant |
|------------|---------|
| Active/Confirmed/Success | `success` |
| Pending/Warning | `warning` |
| Error/Failed/Cancelled | `error` |
| Default/Neutral | `default` |
| Primary/Active highlight | `primary` |

### Filter bars

Pages with filterable data use LiveFilter. Standard pattern:
```heex
<div class="mt-6">
  <LiveFilter.bar filter={@livefilter} />
</div>
```

Place filter bar between header and content, with `mt-6` spacing.

## Spacing scale

Use consistent spacing throughout:

| Context | Mobile | Desktop |
|---------|--------|---------|
| Page padding (main) | `px-4 py-6` | `sm:px-6 lg:px-8` |
| Section padding | `px-4 py-12` | `sm:px-6 sm:py-16` |
| Card padding | `p-4` or `p-5` | `sm:p-6` or `sm:p-8` |
| Grid gap | `gap-4` | `md:gap-6` |
| Element spacing (mt/mb) | `mt-4` / `mt-6` | — |

## Typography

| Role | Classes |
|------|---------|
| Page title (h1) | `text-lg/8 font-semibold` (via `<.header>`) |
| Section title (h2) | `text-2xl font-bold` or `text-3xl font-bold` |
| Card title (h3) | `text-base-content font-semibold` |
| Body text | `text-base-content/70 text-sm` or `text-lg/relaxed` |
| Caption/meta | `text-base-content/50 text-xs` |
| Label | `text-base-content/50 text-xs uppercase font-semibold` |

## Do not

- Do not use `overflow-x-auto` on navigation elements
- Do not use `hover:scale-*` or `hover:shadow-*` without `sm:` prefix
- Do not set multi-column grids without breakpoint prefixes
- Do not use raw hex/rgb colors — use DaisyUI semantic colors
- Do not use `@apply` in CSS
- Do not add `tailwind.config.js` — all config is in `app.css`
- Do not use `<script>` tags in templates — use hooks
- Do not reference external vendor CDN URLs for CSS/JS
- Do not use fixed pixel widths on containers — use `max-w-*` utilities
- Do not put `<.flash_group>` anywhere except layouts
- Do not build complex tables for data that could be shown as cards on mobile
