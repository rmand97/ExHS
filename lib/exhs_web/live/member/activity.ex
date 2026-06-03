defmodule ExhsWeb.MemberLive.Activity do
  @moduledoc false
  use ExhsWeb, :live_view

  alias LiveFilter.Params.Serializer

  @resource_options [
    {"Forening", "Elixir.Exhs.Organizations.Forening"},
    {"Medlemskab", "Elixir.Exhs.Organizations.Membership"},
    {"Gruppe", "Elixir.Exhs.Organizations.Group"},
    {"Event", "Elixir.Exhs.Events.Event"},
    {"Tilmelding", "Elixir.Exhs.Events.Registration"},
    {"Billettype", "Elixir.Exhs.Events.TicketType"},
    {"Abonnement", "Elixir.Exhs.Billing.Subscription"},
    {"Betaling", "Elixir.Exhs.Billing.Payment"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    config = filter_config()
    {filters, remaining} = LiveFilter.from_params(params, config)
    {pagination, remaining} = LiveFilter.pagination_from_params(remaining, default_limit: 25)

    socket =
      socket
      |> LiveFilter.init(config, filters)
      |> assign(:remaining_params, remaining)
      |> load_activity(filters, pagination)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:livefilter, :updated, params}, socket) do
    all_params = Map.merge(socket.assigns.remaining_params, params)
    {:noreply, push_patch(socket, to: Serializer.to_path("/activity", all_params))}
  end

  def handle_info({:livefilter, :page_changed, pagination_params}, socket) do
    filter_params = Serializer.to_params(socket.assigns.livefilter.filters)
    all_params = Map.merge(filter_params, pagination_params)
    {:noreply, push_patch(socket, to: Serializer.to_path("/activity", all_params))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.member flash={@flash} current_user={@current_user} current_path={@current_path}>
      <.header>
        Aktivitet
        <:subtitle>Din aktivitetshistorik på tværs af foreninger</:subtitle>
      </.header>

      <div class="mt-6">
        <LiveFilter.bar filter={@livefilter} />
      </div>

      <div :if={@events == []} class="mt-8">
        <.empty_state icon="hero-clock" title="Ingen aktivitet endnu">
          Din aktivitet vises her, når du foretager ændringer.
        </.empty_state>
      </div>

      <div :if={@events != []} class="mt-6">
        <.table id="activity" rows={@events}>
          <:col :let={event} label="Handling" class="w-0 whitespace-nowrap">
            <div class="flex items-center gap-2">
              <span class={[
                "inline-flex size-6 shrink-0 items-center justify-center rounded-full",
                action_type_bg(event.action_type)
              ]}>
                <.icon name={action_type_icon(event.action_type)} class="size-3" />
              </span>
              <span class="font-medium">{action_label(event.action)}</span>
            </div>
          </:col>
          <:col :let={event} label="Ressource" class="w-0 whitespace-nowrap">
            <.badge variant="default">{resource_label(event.resource)}</.badge>
          </:col>
          <:col :let={event} label="Tidspunkt" class="w-0 whitespace-nowrap">
            <span class="text-base-content/50 text-xs">{format_timestamp(event.occurred_at)}</span>
          </:col>
          <:col :let={event} label="Detaljer">
            <.event_data :if={event.data != %{}} data={event.data} />
          </:col>
        </.table>
      </div>

      <div :if={@events != []} class="mt-6">
        <LiveFilter.paginator pagination={@pagination} />
      </div>
    </Layouts.member>
    """
  end

  defp event_data(assigns) do
    ~H"""
    <details class="group">
      <summary class="hover:text-base-content/60 text-base-content/40 cursor-pointer text-xs">
        Vis
      </summary>
      <dl class="mt-1 space-y-0.5">
        <div :for={{key, value} <- @data} class="flex gap-1.5 text-xs">
          <dt class="text-base-content/50 shrink-0">{humanize_key(key)}:</dt>
          <dd class="text-base-content/70 truncate">{format_value(value)}</dd>
        </div>
      </dl>
    </details>
    """
  end

  defp filter_config do
    [
      LiveFilter.select(:resource,
        label: "Ressource",
        options: @resource_options
      )
    ]
  end

  defp load_activity(socket, filters, pagination) do
    user = socket.assigns.current_user

    case Exhs.Audit.list_my_activity(actor: user, page: page_opts(pagination)) do
      {:ok, page} ->
        events = apply_filters(page.results, filters)
        pagination = LiveFilter.Pagination.with_total(pagination, page.count || length(events))

        socket
        |> assign(:events, events)
        |> assign(:pagination, pagination)
        |> assign(:page_title, "Aktivitet")

      {:error, _} ->
        pagination = LiveFilter.Pagination.with_total(pagination, 0)

        socket
        |> assign(:events, [])
        |> assign(:pagination, pagination)
        |> assign(:page_title, "Aktivitet")
    end
  end

  defp page_opts(pagination) do
    [offset: pagination.offset, limit: pagination.limit, count: true]
  end

  defp apply_filters(events, filters) do
    Enum.reduce(filters, events, fn filter, acc ->
      apply_filter(acc, filter)
    end)
  end

  defp apply_filter(events, %{field: :resource, value: value})
       when is_binary(value) and value != "" do
    Enum.filter(events, &(to_string(&1.resource) == value))
  end

  defp apply_filter(events, _filter), do: events

  defp action_type_bg(:create), do: "bg-success/15 text-success"
  defp action_type_bg(:update), do: "bg-info/15 text-info"
  defp action_type_bg(:destroy), do: "bg-error/15 text-error"
  defp action_type_bg(_), do: "bg-base-content/10 text-base-content/60"

  defp action_type_icon(:create), do: "hero-plus"
  defp action_type_icon(:update), do: "hero-pencil"
  defp action_type_icon(:destroy), do: "hero-trash"
  defp action_type_icon(_), do: "hero-bolt"

  @action_labels %{
    create: "Oprettet",
    update: "Opdateret",
    destroy: "Slettet",
    invite: "Inviteret",
    set_role: "Rolle ændret",
    activate: "Aktiveret",
    deactivate: "Deaktiveret",
    join: "Tilmeldt",
    leave: "Forladt",
    publish: "Publiceret",
    register: "Tilmeldt",
    record: "Registreret",
    set_stripe_account: "Stripe tilsluttet",
    set_stripe_customer: "Stripe-kunde sat"
  }

  defp action_label(action) do
    Map.get(
      @action_labels,
      action,
      action |> to_string() |> String.replace("_", " ") |> String.capitalize()
    )
  end

  @resource_labels %{
    Exhs.Organizations.Forening => "Forening",
    Exhs.Organizations.Membership => "Medlemskab",
    Exhs.Organizations.Group => "Gruppe",
    Exhs.Organizations.MemberGroup => "Gruppemedlemskab",
    Exhs.Events.Event => "Event",
    Exhs.Events.TicketType => "Billettype",
    Exhs.Events.Registration => "Tilmelding",
    Exhs.Billing.Subscription => "Abonnement",
    Exhs.Billing.Payment => "Betaling"
  }

  defp resource_label(resource) do
    Map.get(@resource_labels, resource, resource |> Module.split() |> List.last())
  end

  defp format_timestamp(nil), do: "—"

  defp format_timestamp(dt) do
    Calendar.strftime(dt, "%d. %b %Y kl. %H:%M")
  end

  defp humanize_key(key) when is_binary(key) do
    key |> String.replace("_", " ") |> String.capitalize()
  end

  defp humanize_key(key), do: to_string(key)

  defp format_value(value) when is_map(value), do: Jason.encode!(value)
  defp format_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_value(nil), do: "—"
  defp format_value(value), do: to_string(value)
end
