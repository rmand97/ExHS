defmodule ExhsWeb.MemberLive.Events do
  @moduledoc false
  use ExhsWeb, :live_view

  alias LiveFilter.Params.Serializer

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, loading: true)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    memberships = load_memberships(socket.assigns.current_user)
    config = filter_config(memberships)
    {filters, remaining} = LiveFilter.from_params(params, config)
    {pagination, remaining} = LiveFilter.pagination_from_params(remaining, default_limit: 20)

    socket =
      socket
      |> LiveFilter.init(config, filters)
      |> assign(:remaining_params, remaining)
      |> load_events(filters, pagination, memberships)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:livefilter, :updated, params}, socket) do
    all_params = Map.merge(socket.assigns.remaining_params, params)
    {:noreply, push_patch(socket, to: Serializer.to_path("/upcoming", all_params))}
  end

  def handle_info({:livefilter, :page_changed, pagination_params}, socket) do
    filter_params = Serializer.to_params(socket.assigns.livefilter.filters)
    all_params = Map.merge(filter_params, pagination_params)
    {:noreply, push_patch(socket, to: Serializer.to_path("/upcoming", all_params))}
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
        {gettext("Upcoming events")}
        <:subtitle>{gettext("Events from your associations")}</:subtitle>
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
          <.empty_state icon="hero-calendar-days" title={gettext("No upcoming events")}>
            {gettext("There are no upcoming events from your associations.")}
          </.empty_state>
        </div>

        <div :if={@events != []} class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <.event_card :for={entry <- @events} entry={entry} />
        </div>

        <div :if={@events != []} class="mt-6">
          <LiveFilter.paginator pagination={@pagination} />
        </div>
      </div>
    </Layouts.member>
    """
  end

  defp event_card(assigns) do
    ~H"""
    <.link href={event_url(@entry)} class="group">
      <.card class="overflow-hidden p-4 transition sm:hover:scale-[1.02]">
        <p class="text-primary mb-1 text-xs font-semibold uppercase">
          {format_datetime(@entry.event.starts_at)}
        </p>
        <h3 class="text-base-content font-semibold">{@entry.event.title}</h3>
        <p class="text-base-content/50 mt-0.5 text-xs">{@entry.forening.name}</p>
        <p
          :if={@entry.event.location}
          class="text-base-content/50 mt-2 flex items-center gap-1 text-sm"
        >
          <.icon name="hero-map-pin-micro" class="size-3.5" /> {@entry.event.location}
        </p>
      </.card>
    </.link>
    """
  end

  defp filter_config(memberships) do
    forening_options = Enum.map(memberships, & &1.forening.name)

    [
      LiveFilter.text(:search,
        label: gettext("Search event"),
        always_on: true,
        placeholder: gettext("Search...")
      ),
      LiveFilter.select(:forening, label: gettext("Association"), options: forening_options)
    ]
  end

  defp load_memberships(user) do
    case Exhs.Organizations.list_my_memberships(actor: user) do
      {:ok, memberships} -> memberships
      _ -> []
    end
  end

  defp load_events(socket, filters, pagination, memberships) do
    forening_ids = Enum.map(memberships, & &1.forening_id)
    forening_map = Map.new(memberships, &{&1.forening_id, &1.forening})

    all_events =
      case Exhs.Events.list_member_events(forening_ids, actor: socket.assigns.current_user) do
        {:ok, events} ->
          Enum.map(events, fn event ->
            %{event: event, forening: forening_map[event.forening_id] || event.forening}
          end)

        _ ->
          []
      end

    filtered = apply_filters(all_events, filters)
    total = length(filtered)
    page = Enum.slice(filtered, pagination.offset, pagination.limit)
    pagination = LiveFilter.Pagination.with_total(pagination, total)

    socket
    |> assign(:events, page)
    |> assign(:pagination, pagination)
    |> assign(:page_title, gettext("Upcoming events"))
    |> assign(:loading, false)
  end

  defp apply_filters(events, filters) do
    Enum.reduce(filters, events, fn filter, acc ->
      apply_filter(acc, filter)
    end)
  end

  defp apply_filter(events, %{field: :search, value: value})
       when is_binary(value) and value != "" do
    term = String.downcase(value)
    Enum.filter(events, &String.contains?(String.downcase(&1.event.title), term))
  end

  defp apply_filter(events, %{field: :forening, value: value})
       when is_binary(value) and value != "" do
    Enum.filter(events, &(&1.forening.name == value))
  end

  defp apply_filter(events, _filter), do: events

  defp event_url(%{event: event, forening: forening}) do
    ~p"/go/forening/#{forening.subdomain}?#{%{return_to: "/events/#{event.id}"}}"
  end
end
