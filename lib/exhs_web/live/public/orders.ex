defmodule ExhsWeb.PublicLive.Orders do
  @moduledoc false
  use ExhsWeb, :live_view

  alias Exhs.Events

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_user] do
      orders =
        case Events.list_my_orders(actor: socket.assigns.current_user) do
          {:ok, orders} -> orders
          _ -> []
        end

      {:ok, assign(socket, orders: orders, page_title: "Mine billetter")}
    else
      {:ok, redirect(socket, to: "/sign-in")}
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
                  <p class="text-base-content/50 text-xs">{order.status}</p>
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
