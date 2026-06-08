defmodule ExhsWeb.MemberLive.Payments do
  @moduledoc false
  use ExhsWeb, :live_view

  import ExhsWeb.Labels,
    only: [
      format_amount: 2,
      payment_status_label: 1,
      payment_status_variant: 1,
      payable_type_label: 1
    ]

  alias LiveFilter.Params.Serializer

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
    <Layouts.member
      flash={@flash}
      current_user={@current_user}
      current_path={@current_path}
      my_foreninger={@my_foreninger}
    >
      <.header>
        {gettext("Payments")}
        <:subtitle>{gettext("Your payment history across associations")}</:subtitle>
      </.header>

      <div :if={@loading} class="mt-6 space-y-4">
        <.skeleton class="h-10 w-full" />
        <.skeleton class="h-64 w-full" />
      </div>

      <div :if={!@loading}>
        <div class="mt-6">
          <LiveFilter.bar filter={@livefilter} />
        </div>

        <div :if={@payments == []} class="mt-8">
          <.empty_state icon="hero-banknotes" title={gettext("No payments yet")}>
            {gettext("Your payments appear here.")}
          </.empty_state>
        </div>

        <div :if={@payments != []} class="mt-6">
          <.table id="payments" rows={@payments}>
            <:col :let={pay} label={gettext("Description")}>
              {pay.description || payable_type_label(pay.payable_type)}
            </:col>
            <:col :let={pay} label={gettext("Amount")}>
              {format_amount(pay.amount_cents, pay.currency)}
            </:col>
            <:col :let={pay} label={gettext("Status")}>
              <.badge variant={payment_status_variant(pay.status)}>
                {payment_status_label(pay.status)}
              </.badge>
            </:col>
            <:col :let={pay} label={gettext("Type")}>
              <.badge variant="default">{payable_type_label(pay.payable_type)}</.badge>
            </:col>
            <:col :let={pay} label={gettext("Date")}>{format_date(pay.paid_at)}</:col>
          </.table>
        </div>

        <div :if={@payments != []} class="mt-6">
          <LiveFilter.paginator pagination={@pagination} />
        </div>
      </div>
    </Layouts.member>
    """
  end

  defp filter_config do
    [
      LiveFilter.text(:search,
        label: gettext("Search"),
        always_on: true,
        placeholder: gettext("Search...")
      ),
      LiveFilter.select(:status,
        label: gettext("Status"),
        options: [
          {gettext("Completed"), "succeeded"},
          {gettext("Pending"), "pending"},
          {gettext("Failed"), "failed"},
          {gettext("Refunded"), "refunded"}
        ]
      ),
      LiveFilter.select(:payable_type,
        label: gettext("Type"),
        options: [
          {gettext("Subscription"), "subscription"},
          {gettext("Registration"), "registration"},
          {gettext("Order"), "order"}
        ]
      )
    ]
  end

  defp load_payments(socket, filters, pagination) do
    user = socket.assigns.current_user

    case Exhs.Billing.list_my_payments(actor: user) do
      {:ok, all_payments} ->
        filtered = apply_filters(all_payments, filters)
        total = length(filtered)
        page = Enum.slice(filtered, pagination.offset, pagination.limit)
        pagination = LiveFilter.Pagination.with_total(pagination, total)

        socket
        |> assign(:payments, page)
        |> assign(:pagination, pagination)
        |> assign(:page_title, "Betalinger")
        |> assign(:loading, false)

      {:error, _} ->
        pagination = LiveFilter.Pagination.with_total(pagination, 0)

        socket
        |> assign(:payments, [])
        |> assign(:pagination, pagination)
        |> assign(:page_title, "Betalinger")
        |> assign(:loading, false)
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
end
