defmodule ExhsWeb.MemberLive.Activity do
  @moduledoc false
  use ExhsWeb, :live_view

  import ExhsWeb.Labels, only: [action_label: 1]

  alias LiveFilter.Params.Serializer

  defp resource_options do
    [
      {gettext("Association"), "Elixir.Exhs.Organizations.Forening"},
      {gettext("Membership"), "Elixir.Exhs.Organizations.Membership"},
      {gettext("Group"), "Elixir.Exhs.Organizations.Group"},
      {gettext("Event"), "Elixir.Exhs.Events.Event"},
      {gettext("Registration"), "Elixir.Exhs.Events.Registration"},
      {gettext("Ticket type"), "Elixir.Exhs.Events.TicketType"},
      {gettext("Subscription"), "Elixir.Exhs.Billing.Subscription"},
      {gettext("Payment"), "Elixir.Exhs.Billing.Payment"}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, loading: true)}
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
    <Layouts.member
      flash={@flash}
      current_user={@current_user}
      current_path={@current_path}
      my_foreninger={@my_foreninger}
    >
      <.header>
        {gettext("Activity")}
        <:subtitle>{gettext("Your activity history across associations")}</:subtitle>
      </.header>

      <div :if={@loading} class="mt-6 space-y-4">
        <.skeleton class="h-10 w-full" />
        <.skeleton class="h-64 w-full" />
      </div>

      <div :if={!@loading}>
        <div class="mt-6">
          <LiveFilter.bar filter={@livefilter} />
        </div>

        <div :if={@events == []} class="mt-8">
          <.empty_state icon="hero-clock" title={gettext("No activity yet")}>
            {gettext("Your activity appears here when you make changes.")}
          </.empty_state>
        </div>

        <div :if={@events != []} class="mt-6">
          <.table id="activity" rows={@events}>
            <:col :let={event} label={gettext("Action")} class="w-0 whitespace-nowrap">
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
            <:col :let={event} label={gettext("Resource")} class="w-0 whitespace-nowrap">
              <.badge variant="default">{resource_label(event.resource)}</.badge>
            </:col>
            <:col :let={event} label={gettext("Time")} class="w-0 whitespace-nowrap">
              <span class="text-base-content/50 text-xs">{format_timestamp(event.occurred_at)}</span>
            </:col>
            <:col :let={event} label={gettext("Details")}>
              <.event_data :if={event.data != %{}} data={event.data} />
            </:col>
          </.table>
        </div>

        <div :if={@events != []} class="mt-6">
          <LiveFilter.paginator pagination={@pagination} />
        </div>
      </div>
    </Layouts.member>
    """
  end

  defp event_data(assigns) do
    ~H"""
    <details class="group">
      <summary class="hover:text-base-content/60 text-base-content/40 cursor-pointer text-xs">
        {gettext("Show")}
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
        label: gettext("Resource"),
        options: resource_options()
      )
    ]
  end

  defp load_activity(socket, filters, pagination) do
    user = socket.assigns.current_user
    resource_filter = extract_filter(filters, :resource)
    input = if resource_filter, do: %{resource: resource_filter}, else: %{}

    case Exhs.Audit.list_my_activity(input, actor: user, page: page_opts(pagination)) do
      {:ok, page} ->
        pagination = LiveFilter.Pagination.with_total(pagination, page.count || 0)

        socket
        |> assign(:events, page.results)
        |> assign(:pagination, pagination)
        |> assign(:page_title, gettext("Activity"))
        |> assign(:loading, false)

      {:error, _} ->
        pagination = LiveFilter.Pagination.with_total(pagination, 0)

        socket
        |> assign(:events, [])
        |> assign(:pagination, pagination)
        |> assign(:page_title, gettext("Activity"))
        |> assign(:loading, false)
    end
  end

  defp page_opts(pagination) do
    [offset: pagination.offset, limit: pagination.limit, count: true]
  end

  defp extract_filter(filters, field) do
    case Enum.find(filters, &(&1.field == field)) do
      %{value: value} when is_binary(value) and value != "" -> value
      _ -> nil
    end
  end

  defp action_type_bg(:create), do: "bg-success/15 text-success"
  defp action_type_bg(:update), do: "bg-info/15 text-info"
  defp action_type_bg(:destroy), do: "bg-error/15 text-error"
  defp action_type_bg(_), do: "bg-base-content/10 text-base-content/60"

  defp action_type_icon(:create), do: "hero-plus"
  defp action_type_icon(:update), do: "hero-pencil"
  defp action_type_icon(:destroy), do: "hero-trash"
  defp action_type_icon(_), do: "hero-bolt"

  defp resource_label(Exhs.Organizations.Forening), do: gettext("Association")
  defp resource_label(Exhs.Organizations.Membership), do: gettext("Membership")
  defp resource_label(Exhs.Organizations.Group), do: gettext("Group")
  defp resource_label(Exhs.Organizations.MemberGroup), do: gettext("Group membership")
  defp resource_label(Exhs.Events.Event), do: gettext("Event")
  defp resource_label(Exhs.Events.TicketType), do: gettext("Ticket type")
  defp resource_label(Exhs.Events.Registration), do: gettext("Registration")
  defp resource_label(Exhs.Billing.Subscription), do: gettext("Subscription")
  defp resource_label(Exhs.Billing.Payment), do: gettext("Payment")
  defp resource_label(resource), do: resource |> Module.split() |> List.last()

  defp format_timestamp(nil), do: "—"
  defp format_timestamp(dt), do: ExhsWeb.DisplayHelpers.format_datetime(dt)

  defp humanize_key(key) when is_binary(key) do
    key |> String.replace("_", " ") |> String.capitalize()
  end

  defp humanize_key(key), do: to_string(key)

  defp format_value(value) when is_map(value) do
    case Jason.encode(value) do
      {:ok, json} -> json
      _ -> inspect(value)
    end
  end

  defp format_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_value(nil), do: "—"
  defp format_value(value), do: to_string(value)
end
