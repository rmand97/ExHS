defmodule ExhsWeb.PublicLive.Orders do
  @moduledoc false
  use ExhsWeb, :live_view

  import ExhsWeb.Labels, only: [order_status_label: 1, order_status_variant: 1]

  alias Exhs.Events
  alias Exhs.Events.OrderUpdates

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_user] do
      orders = load_orders(socket)
      if connected?(socket), do: Enum.each(orders, &OrderUpdates.subscribe(&1.id))

      {:ok, assign(socket, orders: orders, page_title: "Mine billetter")}
    else
      {:ok, redirect(socket, to: "/sign-in")}
    end
  end

  @impl true
  def handle_info({:order_updated, _order_id}, socket) do
    {:noreply, assign(socket, orders: load_orders(socket))}
  end

  defp load_orders(socket) do
    case Events.list_my_orders(actor: socket.assigns.current_user) do
      {:ok, orders} -> orders
      _ -> []
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
        <div class="mx-auto max-w-2xl">
          <h1 class="text-base-content mb-6 text-2xl font-bold">Mine billetter</h1>

          <div :if={@orders == []} class="text-base-content/50 text-sm">
            Du har ingen ordrer endnu.
          </div>

          <div class="space-y-3">
            <.link
              :for={order <- @orders}
              navigate={~p"/orders/#{order.id}"}
              class="border-base-content/5 hover:border-primary/40 block rounded-lg border p-4 transition"
            >
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-base-content text-sm font-medium">{order.event.title}</p>
                  <p class="text-base-content/50 text-xs">{format_datetime(order.inserted_at)}</p>
                </div>
                <div class="text-right">
                  <p class="text-base-content text-sm font-semibold">
                    {format_price(order.total_cents, order.currency)}
                  </p>
                  <.badge variant={order_status_variant(order.status)}>
                    {order_status_label(order.status)}
                  </.badge>
                </div>
              </div>
            </.link>
          </div>
        </div>
      </div>
    </Layouts.public>
    """
  end
end
