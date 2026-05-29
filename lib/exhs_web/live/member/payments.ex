defmodule ExhsWeb.MemberLive.Payments do
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
      |> load_payments(filters, pagination)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:livefilter, :updated, params}, socket) do
    all_params = Map.merge(socket.assigns.remaining_params, params)
    {:noreply, push_patch(socket, to: Serializer.to_path("/payments", all_params))}
  end

  def handle_info({:livefilter, :page_changed, pagination_params}, socket) do
    filter_params = Serializer.to_params(socket.assigns.livefilter.filters)
    all_params = Map.merge(filter_params, pagination_params)
    {:noreply, push_patch(socket, to: Serializer.to_path("/payments", all_params))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.member flash={@flash} current_user={@current_user} current_path={@current_path}>
      <.header>
        Betalinger
        <:subtitle>Din betalingshistorik på tværs af foreninger</:subtitle>
      </.header>

      <div class="mt-6">
        <LiveFilter.bar filter={@livefilter} />
      </div>

      <div :if={@payments == []} class="mt-8">
        <.empty_state icon="hero-banknotes" title="Ingen betalinger endnu">
          Dine betalinger vises her.
        </.empty_state>
      </div>

      <div :if={@payments != []} class="mt-6">
        <.table id="payments" rows={@payments}>
          <:col :let={pay} label="Beskrivelse">
            {pay.description || type_label(pay.payable_type)}
          </:col>
          <:col :let={pay} label="Beløb">{format_amount(pay.amount_cents, pay.currency)}</:col>
          <:col :let={pay} label="Status">
            <.badge variant={payment_status_variant(pay.status)}>
              {payment_status_label(pay.status)}
            </.badge>
          </:col>
          <:col :let={pay} label="Type">
            <.badge variant="default">{type_label(pay.payable_type)}</.badge>
          </:col>
          <:col :let={pay} label="Dato">{format_date(pay.paid_at)}</:col>
        </.table>
      </div>

      <div :if={@payments != []} class="mt-6">
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
          {"Gennemført", "succeeded"},
          {"Afventer", "pending"},
          {"Fejlet", "failed"},
          {"Refunderet", "refunded"}
        ]
      ),
      LiveFilter.select(:payable_type,
        label: "Type",
        options: [
          {"Abonnement", "subscription"},
          {"Tilmelding", "registration"},
          {"Ordre", "order"}
        ]
      )
    ]
  end

  defp load_payments(socket, filters, pagination) do
    user = socket.assigns.current_user

    membership_ids =
      case Exhs.Organizations.list_my_memberships(actor: user) do
        {:ok, memberships} -> Enum.map(memberships, & &1.id)
        _ -> []
      end

    case Exhs.Billing.list_my_payments(membership_ids, actor: user) do
      {:ok, all_payments} ->
        filtered = apply_filters(all_payments, filters)
        total = length(filtered)
        page = Enum.slice(filtered, pagination.offset, pagination.limit)
        pagination = LiveFilter.Pagination.with_total(pagination, total)

        socket
        |> assign(:payments, page)
        |> assign(:pagination, pagination)
        |> assign(:page_title, "Betalinger")

      {:error, _} ->
        pagination = LiveFilter.Pagination.with_total(pagination, 0)

        socket
        |> assign(:payments, [])
        |> assign(:pagination, pagination)
        |> assign(:page_title, "Betalinger")
    end
  end

  defp apply_filters(payments, filters) do
    Enum.reduce(filters, payments, fn filter, acc ->
      apply_filter(acc, filter)
    end)
  end

  defp apply_filter(payments, %{field: :search, value: value})
       when is_binary(value) and value != "" do
    term = String.downcase(value)

    Enum.filter(payments, fn p ->
      p.description && String.contains?(String.downcase(p.description), term)
    end)
  end

  defp apply_filter(payments, %{field: :status, value: value})
       when is_binary(value) and value != "" do
    Enum.filter(payments, &(to_string(&1.status) == value))
  end

  defp apply_filter(payments, %{field: :payable_type, value: value})
       when is_binary(value) and value != "" do
    Enum.filter(payments, &(to_string(&1.payable_type) == value))
  end

  defp apply_filter(payments, _filter), do: payments

  defp format_amount(cents, currency) do
    "#{div(cents, 100)} #{currency}"
  end

  defp payment_status_variant(:succeeded), do: "success"
  defp payment_status_variant(:pending), do: "warning"
  defp payment_status_variant(:failed), do: "error"
  defp payment_status_variant(:refunded), do: "default"

  defp payment_status_label(:succeeded), do: "Betalt"
  defp payment_status_label(:pending), do: "Afventer"
  defp payment_status_label(:failed), do: "Fejlet"
  defp payment_status_label(:refunded), do: "Refunderet"

  defp type_label(:subscription), do: "Kontingent"
  defp type_label(:registration), do: "Event"
  defp type_label(:order), do: "Ordre"

  defp format_date(nil), do: "—"
  defp format_date(dt), do: Calendar.strftime(dt, "%d. %b %Y")
end
