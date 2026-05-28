---
name: livefilter
description: "Use this skill when building list/index pages that need filtering, sorting, or pagination. Covers LiveFilter setup, filter types, QueryBuilder, and pagination."
---

## When to use

Use LiveFilter for any list/index page with user-facing filtering or pagination (events, members, orders, etc.). It provides Linear/Notion-style filter bars with URL-driven state.

Do not use for simple single-field search — a plain `phx-change` text input is enough there.

## Important: Ash integration

This project uses Ash, not raw Ecto. LiveFilter's `QueryBuilder` works with Ecto queries, so you need to bridge:
- Build filters with LiveFilter's `from_params/2` and `init/3`
- Apply filters to Ash reads via action arguments or use `Ash.Query.filter/2` based on the parsed filter values
- Do NOT use `LiveFilter.QueryBuilder.apply/3` with `Repo.all` — go through Ash code interfaces

## JavaScript hooks

Hooks must be imported in `assets/js/app.js`:

```javascript
import { hooks as liveFilterHooks } from "live_filter"

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...liveFilterHooks, ...otherHooks }
})
```

esbuild needs `NODE_PATH` set in `config/config.exs` so it can resolve `live_filter` from `deps/`:

```elixir
config :esbuild,
  exhs: [
    args: ~w(...),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
```

## Tailwind source

Since we use Tailwind v4 (no config file), add LiveFilter templates as a source in `assets/css/app.css`:

```css
@source "../../deps/livefilter";
```

## Filter configuration

Define filters as a private function in the LiveView:

```elixir
defp filter_config do
  [
    LiveFilter.text(:name, label: "Search", always_on: true),
    LiveFilter.select(:status, label: "Status", options: ~w(active archived)),
    LiveFilter.multi_select(:tags, label: "Tags", options: ~w(bug feature)),
    LiveFilter.boolean(:active, label: "Active Only"),
    LiveFilter.date_range(:created_at, label: "Created"),
    LiveFilter.number(:amount, label: "Amount", mode: :command),
    LiveFilter.date(:due_date, label: "Due Date"),
    LiveFilter.datetime(:updated_at, label: "Updated"),
    LiveFilter.radio_group(:priority, label: "Priority")
  ]
end
```

## Filter types reference

| Type | Function | Default operators |
|------|----------|-------------------|
| Text | `LiveFilter.text/2` | ilike, eq, neq, like |
| Number | `LiveFilter.number/2` | eq, neq, gt, gte, lt, lte |
| Select | `LiveFilter.select/2` | eq, neq, in, not_in |
| Multi-select | `LiveFilter.multi_select/2` | ov, cs |
| Date | `LiveFilter.date/2` | eq, gt, gte, lt, lte |
| Date range | `LiveFilter.date_range/2` | gte_lte |
| DateTime | `LiveFilter.datetime/2` | eq, gt, gte, lt, lte |
| Boolean | `LiveFilter.boolean/2` | is |
| Radio group | `LiveFilter.radio_group/2` | eq |

### Common options

- `label:` — display label
- `always_on:` — filter always visible (not in "Add filter" menu)
- `mode:` — `:basic` (default) or `:command` (with operator dropdown)
- `operators:` — override available operators
- `default_operator:` — set default operator
- `placeholder:` — placeholder text
- `query_field:` — map to a different DB field name

### Select-specific

- `options:` — list of string values

### Boolean-specific

- `nullable:` — allow "any" state
- `true_label:`, `false_label:`, `any_label:` — custom labels

## LiveView integration

### handle_params

```elixir
def handle_params(params, _uri, socket) do
  {filters, remaining_params} = LiveFilter.from_params(params, filter_config())

  socket =
    socket
    |> LiveFilter.init(filter_config(), filters)
    |> assign(:remaining_params, remaining_params)
    |> load_data()

  {:noreply, socket}
end
```

### handle_info for filter updates

```elixir
def handle_info({:livefilter, :updated, params}, socket) do
  all_params = Map.merge(socket.assigns.remaining_params, params)
  {:noreply, push_patch(socket, to: ~p"/my-path?#{all_params}")}
end
```

### handle_info for pagination

```elixir
def handle_info({:livefilter, :page_changed, pagination_params}, socket) do
  all_params = Map.merge(filter_params, pagination_params)
  {:noreply, push_patch(socket, to: ~p"/my-path?#{all_params}")}
end
```

## Rendering

### Filter bar

```heex
<LiveFilter.bar filter={@livefilter} />
```

Attributes:
- `filter` — required, the `@livefilter` assign
- `mode` — `:basic` or `:command`
- `theme` — `:default`, `:minimal`, `:bordered`, `:neutral`
- `variant` — `:outline`, `:ghost`, `:soft`, `:neutral`
- `class` — extra CSS classes

### Paginator

```heex
<LiveFilter.paginator pagination={@pagination} max_pages={7} />
```

## Pagination setup

```elixir
{pagination, remaining} = LiveFilter.pagination_from_params(remaining, default_limit: 25)
total = get_total_count(socket)
pagination = LiveFilter.Pagination.with_total(pagination, total)
```
