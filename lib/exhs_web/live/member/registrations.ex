defmodule ExhsWeb.MemberLive.Registrations do
  @moduledoc false
  use ExhsWeb, :live_view

  alias LiveFilter.Params.Serializer

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
      |> load_registrations(filters, pagination)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:livefilter, :updated, params}, socket) do
    all_params = Map.merge(socket.assigns.remaining_params, params)
    {:noreply, push_patch(socket, to: Serializer.to_path("/registrations", all_params))}
  end

  def handle_info({:livefilter, :page_changed, pagination_params}, socket) do
    filter_params = Serializer.to_params(socket.assigns.livefilter.filters)
    all_params = Map.merge(filter_params, pagination_params)
    {:noreply, push_patch(socket, to: Serializer.to_path("/registrations", all_params))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.member flash={@flash} current_user={@current_user} current_path={@current_path}>
      <.header>
        Mine events
        <:subtitle>Dine tilmeldinger på tværs af foreninger</:subtitle>
      </.header>

      <div class="mt-6">
        <LiveFilter.bar filter={@livefilter} />
      </div>

      <div :if={@registrations == []} class="mt-8">
        <.empty_state icon="hero-calendar-days" title="Ingen tilmeldinger endnu">
          Du er ikke tilmeldt nogen events.
        </.empty_state>
      </div>

      <div :if={@registrations != []} class="mt-6">
        <.table id="registrations" rows={@registrations}>
          <:col :let={reg} label="Event">{reg.ticket_type.event.title}</:col>
          <:col :let={reg} label="Forening">{reg.membership.forening.name}</:col>
          <:col :let={reg} label="Billet">{reg.ticket_type.name}</:col>
          <:col :let={reg} label="Status">
            <.badge variant={reg_status_variant(reg.status)}>
              {reg_status_label(reg.status)}
            </.badge>
          </:col>
          <:col :let={reg} label="Dato">{format_date(reg.registered_at)}</:col>
          <:col :let={reg} label="">
            <a
              href={event_url(reg)}
              class="text-primary text-sm font-medium hover:underline"
            >
              Se event
            </a>
          </:col>
        </.table>
      </div>

      <div :if={@registrations != []} class="mt-6">
        <LiveFilter.paginator pagination={@pagination} />
      </div>
    </Layouts.member>
    """
  end

  defp filter_config do
    [
      LiveFilter.text(:search, label: "Søg", always_on: true, placeholder: "Søg..."),
      LiveFilter.select(:status,
        label: "Status",
        options: [
          {"Bekræftet", "confirmed"},
          {"Venteliste", "waitlisted"},
          {"Annulleret", "cancelled"},
          {"Afventer betaling", "pending_payment"}
        ]
      )
    ]
  end

  defp load_registrations(socket, filters, pagination) do
    user = socket.assigns.current_user

    case Exhs.Events.list_my_registrations(actor: user) do
      {:ok, all_registrations} ->
        filtered = apply_filters(all_registrations, filters)
        total = length(filtered)
        page = Enum.slice(filtered, pagination.offset, pagination.limit)
        pagination = LiveFilter.Pagination.with_total(pagination, total)

        socket
        |> assign(:registrations, page)
        |> assign(:pagination, pagination)
        |> assign(:page_title, "Mine events")

      {:error, _} ->
        pagination = LiveFilter.Pagination.with_total(pagination, 0)

        socket
        |> assign(:registrations, [])
        |> assign(:pagination, pagination)
        |> assign(:page_title, "Mine events")
    end
  end

  defp apply_filters(registrations, filters) do
    Enum.reduce(filters, registrations, fn filter, acc ->
      apply_filter(acc, filter)
    end)
  end

  defp apply_filter(registrations, %{field: :search, value: value})
       when is_binary(value) and value != "" do
    term = String.downcase(value)

    Enum.filter(registrations, fn reg ->
      String.contains?(String.downcase(reg.ticket_type.event.title), term) ||
        String.contains?(String.downcase(reg.membership.forening.name), term)
    end)
  end

  defp apply_filter(registrations, %{field: :status, value: value})
       when is_binary(value) and value != "" do
    Enum.filter(registrations, &(to_string(&1.status) == value))
  end

  defp apply_filter(registrations, _filter), do: registrations

  defp reg_status_variant(:confirmed), do: "success"
  defp reg_status_variant(:waitlisted), do: "warning"
  defp reg_status_variant(:cancelled), do: "error"
  defp reg_status_variant(:pending_payment), do: "default"

  defp reg_status_label(:confirmed), do: "Bekræftet"
  defp reg_status_label(:waitlisted), do: "Venteliste"
  defp reg_status_label(:cancelled), do: "Annulleret"
  defp reg_status_label(:pending_payment), do: "Afventer betaling"

  defp event_url(reg) do
    ~p"/go/forening/#{reg.membership.forening.subdomain}?#{%{return_to: "/events/#{reg.ticket_type.event.id}"}}"
  end
end
