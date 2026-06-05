defmodule ExhsWeb.PublicLive.OrderShow do
  @moduledoc false
  use ExhsWeb, :live_view

  alias Exhs.Events
  alias Exhs.Events.Availability

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

    case Events.get_order(id, scope: scope, load: [items: [:ticket_type, :add_on], payment: []]) do
      {:ok, order} ->
        if connected?(socket), do: Availability.subscribe(order.event_id)
        {:ok, assign(socket, order: order, page_title: "Ordre")}

      {:error, _} ->
        {:ok, redirect(socket, to: "/events")}
    end
  end

  @impl true
  def handle_info({:availability_changed, _event_id}, socket) do
    case Events.get_order(socket.assigns.order.id,
           scope: socket.assigns.current_scope,
           load: [items: [:ticket_type, :add_on], payment: []]
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
            <.icon name="hero-arrow-left-micro" class="size-4" /> Mine billetter
          </.link>

          <.card class="p-6">
            <.status_badge status={@order.status} />
            <h1 class="text-base-content mt-3 text-2xl font-bold">Din ordre</h1>

            <div class="border-base-content/5 mt-6 divide-y">
              <div :for={item <- @order.items} class="flex items-center justify-between py-3">
                <span class="text-base-content text-sm">{item_name(item)}</span>
                <span class="text-base-content/70 text-sm">
                  {format_price(item.unit_price_cents * item.quantity, @order.currency)}
                </span>
              </div>
            </div>

            <div class="border-base-content/5 mt-3 flex items-center justify-between border-t pt-3">
              <span class="text-base-content font-medium">I alt</span>
              <span class="text-base-content font-bold">
                {format_price(@order.total_cents, @order.currency)}
              </span>
            </div>

            <p :if={@order.payment} class="text-base-content/50 mt-4 text-xs">
              Betalt {format_datetime(@order.paid_at)} · kvittering sendt på e-mail.
            </p>
          </.card>
        </div>
      </div>
    </Layouts.public>
    """
  end

  defp status_badge(%{status: :paid} = assigns) do
    ~H"""
    <span class="badge badge-success gap-1">
      <.icon name="hero-check-circle-micro" class="size-4" /> Bekræftet
    </span>
    """
  end

  defp status_badge(%{status: :pending_payment} = assigns) do
    ~H"""
    <span class="badge badge-warning">Afventer betaling</span>
    """
  end

  defp status_badge(%{status: status} = assigns) do
    assigns = assign(assigns, :label, label(status))

    ~H"""
    <span class="badge badge-ghost">{@label}</span>
    """
  end

  defp label(:cancelled), do: "Annulleret"
  defp label(:expired), do: "Udløbet"
  defp label(:building), do: "Kladde"
  defp label(other), do: to_string(other)

  defp item_name(%{item_type: :ticket, ticket_type: %{name: name}}), do: name
  defp item_name(%{item_type: :addon, add_on: %{name: name}}), do: name
  defp item_name(_), do: "Vare"
end
