defmodule ExhsWeb.PublicLive.OrderShow do
  @moduledoc false
  use ExhsWeb, :live_view

  import ExhsWeb.Labels, only: [order_status_label: 1, order_status_variant: 1]

  alias Exhs.Events
  alias Exhs.Events.OrderUpdates

  @order_load [items: [:ticket_type, :add_on], payment: []]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    cond do
      is_nil(socket.assigns[:current_user]) ->
        {:ok, redirect(socket, to: "/sign-in")}

      is_nil(socket.assigns[:current_forening]) ->
        {:ok, redirect(socket, to: "/")}

      true ->
        load(id, socket)
    end
  end

  defp load(id, socket) do
    scope = socket.assigns.current_scope

    case Events.get_order(id, scope: scope, load: @order_load) do
      {:ok, order} ->
        if connected?(socket), do: OrderUpdates.subscribe(order.id)
        {:ok, assign(socket, order: order, page_title: gettext("Order"))}

      {:error, _} ->
        {:ok, redirect(socket, to: "/events")}
    end
  end

  @impl true
  def handle_info({:order_updated, _order_id}, socket) do
    case Events.get_order(socket.assigns.order.id,
           scope: socket.assigns.current_scope,
           load: @order_load
         ) do
      {:ok, order} -> {:noreply, assign(socket, order: order)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.public
      flash={@flash}
      current_forening={@current_forening}
      current_user={@current_user}
      current_path={@current_path}
      current_role={@current_role}
    >
      <div class="px-4 py-8 sm:px-6">
        <div class="mx-auto max-w-xl">
          <.link
            navigate={~p"/orders"}
            class="text-base-content/50 mb-6 inline-flex items-center gap-1 text-sm"
          >
            <.icon name="hero-arrow-left-micro" class="size-4" /> {gettext("My tickets")}
          </.link>

          <.card class="p-6">
            <.status_badge status={@order.status} />
            <h1 class="text-base-content mt-3 text-2xl font-bold">{gettext("Your order")}</h1>

            <div class="border-base-content/5 mt-6 divide-y">
              <div :for={item <- @order.items} class="flex items-center justify-between py-3">
                <span class="text-base-content text-sm">{item_name(item)}</span>
                <span class="text-base-content/70 text-sm">
                  {format_price(item.unit_price_cents * item.quantity, @order.currency)}
                </span>
              </div>
            </div>

            <div class="border-base-content/5 mt-3 flex items-center justify-between border-t pt-3">
              <span class="text-base-content font-medium">{gettext("Total")}</span>
              <span class="text-base-content font-bold">
                {format_price(@order.total_cents, @order.currency)}
              </span>
            </div>

            <p :if={@order.payment} class="text-base-content/50 mt-4 text-xs">
              {gettext("Paid %{datetime} · receipt sent by email.",
                datetime: format_datetime(@order.paid_at)
              )}
            </p>
          </.card>
        </div>
      </div>
    </Layouts.public>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <.badge variant={order_status_variant(@status)}>
      <.icon :if={@status == :paid} name="hero-check-circle-micro" class="size-4" />
      {order_status_label(@status)}
    </.badge>
    """
  end

  defp item_name(%{item_type: :ticket, ticket_type: %{name: name}}), do: name
  defp item_name(%{item_type: :addon, add_on: %{name: name}}), do: name
  defp item_name(_), do: gettext("Item")
end
