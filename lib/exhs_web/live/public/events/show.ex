defmodule ExhsWeb.PublicLive.Events.Show do
  @moduledoc false
  use ExhsWeb, :live_view

  alias Exhs.Checks.Helpers
  alias Exhs.Events
  alias Exhs.Events.{Availability, Eligibility}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if socket.assigns[:current_forening] do
      mount_event(id, socket)
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  defp mount_event(id, socket) do
    tenant = socket.assigns.current_forening.id

    case Exhs.Events.get_public_event(id, tenant: tenant) do
      {:ok, event} ->
        if connected?(socket), do: Availability.subscribe(event.id)
        membership = load_membership(socket.assigns[:current_user], tenant)

        socket =
          socket
          |> assign(
            event: event,
            membership: membership,
            page_title: event.title,
            page_description: event.description,
            page_image: event.cover_image_url,
            step: :browse,
            selected: nil,
            error: nil,
            selected_addons: [],
            responses: %{}
          )
          |> load_tickets()
          |> load_addons()
          |> load_pending_order()
          |> schedule_tick()

        {:ok, socket}

      {:error, _} ->
        {:ok, redirect(socket, to: "/events")}
    end
  end

  @impl true
  def handle_info({:availability_changed, _event_id}, socket) do
    {:noreply, socket |> load_tickets() |> load_pending_order()}
  end

  def handle_info(:tick, socket) do
    socket = schedule_tick(socket)

    case socket.assigns.pending_order do
      %{held_until: held_until} = order ->
        if DateTime.compare(DateTime.utc_now(), held_until) != :lt do
          {:noreply, socket |> assign(pending_order: nil) |> load_tickets()}
        else
          {:noreply, assign(socket, countdown: remaining_seconds(order))}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_ticket", %{"id" => id}, socket) do
    ticket = Enum.find(socket.assigns.tickets, &(&1.ticket_type.id == id))

    if ticket && ticket.status == :available do
      {:noreply,
       assign(socket,
         step: :configure,
         selected: ticket,
         error: nil,
         responses: %{},
         selected_addons: []
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_addon", %{"id" => id}, socket) do
    selected = socket.assigns.selected_addons

    selected = if id in selected, do: List.delete(selected, id), else: [id | selected]
    {:noreply, assign(socket, selected_addons: selected)}
  end

  def handle_event("cancel_purchase", _params, socket) do
    {:noreply, assign(socket, step: :browse, selected: nil, error: nil)}
  end

  def handle_event("submit_purchase", params, socket) do
    responses = params["responses"] || %{}
    purchase(socket, responses)
  end

  defp purchase(socket, responses) do
    %{event: event, membership: membership, selected: selected, current_scope: scope} =
      socket.assigns

    tenant = event.forening_id

    with {:ok, order} <-
           Events.create_order(%{membership_id: membership.id, event_id: event.id},
             tenant: tenant,
             scope: scope
           ),
         {:ok, _item} <- add_ticket(order, selected.ticket_type, responses, tenant, scope),
         :ok <- add_addons(order, socket.assigns.selected_addons, tenant, scope),
         {:ok, result} <- checkout(order, event, tenant) do
      finish_purchase(socket, result)
    else
      {:error, reason} ->
        {:noreply, assign(socket, error: humanize(reason))}
    end
  end

  defp finish_purchase(socket, %{checkout_url: nil, order: order}) do
    {:noreply,
     socket
     |> put_flash(:info, "Din tilmelding er bekræftet!")
     |> redirect(to: ~p"/orders/#{order.id}")}
  end

  defp finish_purchase(socket, %{checkout_url: url}) do
    {:noreply, redirect(socket, external: url)}
  end

  defp add_ticket(order, ticket_type, responses, tenant, scope) do
    Events.add_order_item(
      %{
        order_id: order.id,
        item_type: :ticket,
        ticket_type_id: ticket_type.id,
        responses: responses
      },
      tenant: tenant,
      scope: scope
    )
  end

  defp add_addons(order, addon_ids, tenant, scope) do
    Enum.reduce_while(addon_ids, :ok, fn add_on_id, :ok ->
      case Events.add_order_item(
             %{order_id: order.id, item_type: :addon, add_on_id: add_on_id},
             tenant: tenant,
             scope: scope
           ) do
        {:ok, _} -> {:cont, :ok}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp checkout(order, event, tenant) do
    Events.checkout_order(order,
      tenant: tenant,
      success_url: url(~p"/orders/#{order.id}"),
      cancel_url: url(~p"/events/#{event.id}")
    )
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
        <div class="mx-auto max-w-4xl">
          <.link
            navigate={~p"/events"}
            class="hover:text-base-content text-base-content/50 mb-6 inline-flex items-center gap-1 text-sm transition"
          >
            <.icon name="hero-arrow-left-micro" class="size-4" /> Alle events
          </.link>

          <div :if={@event.cover_image_url} class="mb-8 overflow-hidden rounded-2xl">
            <img
              src={@event.cover_image_url}
              alt={@event.title}
              class="aspect-21/9 w-full object-cover"
            />
          </div>

          <div class="grid grid-cols-1 gap-8 lg:grid-cols-3">
            <div class="lg:col-span-2">
              <p class="text-primary mb-2 text-sm font-semibold uppercase">
                {format_datetime(@event.starts_at)}
              </p>
              <h1 class="text-base-content text-3xl font-bold sm:text-4xl">{@event.title}</h1>
              <div :if={@event.description} class="text-base-content/70 mt-6 text-lg/relaxed">
                {@event.description}
              </div>
            </div>

            <div class="space-y-4">
              <.event_details event={@event} />
              <.pending_banner :if={@pending_order} order={@pending_order} countdown={@countdown} />
              <.purchase_panel :if={@step == :browse} {assigns} />
              <.configure_panel :if={@step == :configure} {assigns} />
            </div>
          </div>
        </div>
      </div>
    </Layouts.public>
    """
  end

  defp purchase_panel(assigns) do
    ~H"""
    <.card class="p-5">
      <h3 class="text-base-content mb-4 font-semibold">Billetter</h3>

      <div :if={@tickets == []} class="text-base-content/50 text-sm">
        Ingen billettyper tilgængelige.
      </div>

      <div class="space-y-3">
        <div
          :for={t <- @tickets}
          class="border-base-content/5 rounded-lg border p-3"
        >
          <div class="flex items-center justify-between gap-2">
            <div>
              <p class="text-base-content text-sm font-medium">
                {t.ticket_type.name}
                <span :if={t.gated?} class="badge badge-secondary badge-sm ml-1">Presale</span>
              </p>
              <p :if={t.ticket_type.description} class="text-base-content/50 text-xs">
                {t.ticket_type.description}
              </p>
              <p :if={t.seats_left} class="text-warning mt-1 text-xs font-medium">
                kun {t.seats_left} tilbage
              </p>
            </div>
            <p class="text-primary text-sm font-semibold whitespace-nowrap">
              {format_price(t.ticket_type.price_cents, t.ticket_type.currency)}
            </p>
          </div>

          <div class="mt-3">
            <button
              :if={@current_user && @membership && t.status == :available}
              type="button"
              phx-click="select_ticket"
              phx-value-id={t.ticket_type.id}
              class="btn btn-block btn-primary btn-sm"
            >
              Vælg
            </button>
            <p
              :if={@current_user && t.status != :available}
              class="text-base-content/40 text-center text-xs"
            >
              {reason(t.status)}
            </p>
          </div>
        </div>
      </div>

      <.link :if={!@current_user} navigate={~p"/sign-in"} class="btn btn-block btn-primary mt-4">
        Log ind for at tilmelde
      </.link>
    </.card>
    """
  end

  defp configure_panel(assigns) do
    ~H"""
    <.card class="p-5">
      <div class="mb-4 flex items-center justify-between">
        <h3 class="text-base-content font-semibold">{@selected.ticket_type.name}</h3>
        <button type="button" phx-click="cancel_purchase" class="text-base-content/40 text-xs">
          Annullér
        </button>
      </div>

      <div :if={@error} class="bg-error/10 text-error mb-4 rounded-lg px-3 py-2 text-sm">
        {@error}
      </div>

      <form phx-submit="submit_purchase" class="space-y-4">
        <div :for={q <- @selected.questions} class="space-y-1">
          <label class="text-base-content text-sm font-medium">
            {q.label}<span :if={q.required} class="text-error">*</span>
          </label>
          <select
            :if={q.field_type == :select}
            name={"responses[#{q.id}]"}
            class="select select-bordered select-sm w-full"
          >
            <option value="">Vælg…</option>
            <option :for={opt <- q.options} value={opt}>{opt}</option>
          </select>
          <input
            :if={q.field_type != :select}
            type={if q.field_type == :number, do: "number", else: "text"}
            name={"responses[#{q.id}]"}
            class="input input-bordered input-sm w-full"
          />
        </div>

        <div :if={@addons != []} class="space-y-2">
          <p class="text-base-content text-sm font-medium">Tilkøb</p>
          <label
            :for={a <- @addons}
            class="border-base-content/5 flex items-center gap-3 rounded-lg border p-2"
          >
            <input
              type="checkbox"
              class="checkbox checkbox-sm"
              phx-click="toggle_addon"
              phx-value-id={a.id}
              checked={a.id in @selected_addons}
            />
            <span class="flex-1 text-sm">{a.name}</span>
            <span class="text-primary text-sm">{format_price(a.price_cents, a.currency)}</span>
          </label>
        </div>

        <div class="border-base-content/5 flex items-center justify-between border-t pt-3">
          <span class="text-base-content/60 text-sm">I alt</span>
          <span class="text-base-content font-semibold">
            {format_price(preview_total(assigns), @selected.ticket_type.currency)}
          </span>
        </div>

        <button type="submit" class="btn btn-block btn-primary">
          {if preview_total(assigns) == 0, do: "Bekræft tilmelding", else: "Fortsæt til betaling"}
        </button>
      </form>
    </.card>
    """
  end

  defp pending_banner(assigns) do
    ~H"""
    <.card class="border-warning/40 border p-4">
      <p class="text-base-content text-sm font-medium">Reservation afventer betaling</p>
      <p class="text-warning mt-1 text-2xl font-bold tabular-nums">
        {format_countdown(@countdown)}
      </p>
      <.link navigate={~p"/orders/#{@order.id}"} class="btn btn-block btn-sm btn-warning mt-3">
        Fortsæt
      </.link>
    </.card>
    """
  end

  defp event_details(assigns) do
    ~H"""
    <.card class="p-5">
      <h3 class="text-base-content mb-4 font-semibold">Detaljer</h3>
      <div class="space-y-3">
        <.detail_row icon="hero-calendar-days" label="Dato" value={format_datetime(@event.starts_at)} />
        <.detail_row
          :if={@event.ends_at}
          icon="hero-clock"
          label="Slut"
          value={format_datetime(@event.ends_at)}
        />
        <.detail_row :if={@event.location} icon="hero-map-pin" label="Sted" value={@event.location} />
        <.detail_row
          :if={@event.membership_required}
          icon="hero-user-group"
          label="Krav"
          value="Kun for medlemmer"
        />
      </div>
    </.card>
    """
  end

  defp detail_row(assigns) do
    ~H"""
    <div class="flex items-start gap-3">
      <.icon name={@icon} class="text-base-content/40 mt-0.5 size-4 shrink-0" />
      <div>
        <p class="text-base-content/50 text-xs">{@label}</p>
        <p class="text-base-content text-sm">{@value}</p>
      </div>
    </div>
    """
  end

  # --- data loading ---

  defp load_membership(nil, _tenant), do: nil

  defp load_membership(user, tenant) do
    case Helpers.lookup_membership(user.id, tenant) do
      {:ok, membership} -> membership
      _ -> nil
    end
  end

  defp load_tickets(socket) do
    %{event: event, membership: membership} = socket.assigns
    tenant = event.forening_id

    tickets =
      case Events.list_ticket_types_for_event(event.id,
             tenant: tenant,
             authorize?: false,
             load: [:seats_left]
           ) do
        {:ok, types} ->
          Enum.map(types, fn tt ->
            %{
              ticket_type: tt,
              seats_left: tt.seats_left,
              gated?: Eligibility.gated?(tt, tenant),
              status: Eligibility.status(tt, event, membership, tenant),
              questions: questions(tt.id, tenant)
            }
          end)

        _ ->
          []
      end

    selected =
      if socket.assigns[:selected],
        do: Enum.find(tickets, &(&1.ticket_type.id == socket.assigns.selected.ticket_type.id)),
        else: nil

    assign(socket, tickets: tickets, selected: selected || socket.assigns[:selected])
  end

  defp load_addons(socket) do
    tenant = socket.assigns.event.forening_id

    addons =
      case Events.list_add_ons_for_event(socket.assigns.event.id, tenant: tenant) do
        {:ok, addons} -> addons
        _ -> []
      end

    assign(socket, addons: addons)
  end

  defp questions(ticket_type_id, tenant) do
    case Events.list_ticket_type_questions(ticket_type_id, tenant: tenant) do
      {:ok, qs} -> qs
      _ -> []
    end
  end

  defp load_pending_order(socket) do
    %{event: event, membership: membership} = socket.assigns

    order =
      with %{} <- membership,
           {:ok, orders} <-
             Events.list_orders_for_membership(membership.id,
               tenant: event.forening_id,
               authorize?: false
             ) do
        Enum.find(orders, &pending_for_event?(&1, event.id))
      else
        _ -> nil
      end

    assign(socket,
      pending_order: order,
      countdown: if(order, do: remaining_seconds(order), else: 0)
    )
  end

  defp pending_for_event?(order, event_id) do
    (order.status == :pending_payment and order.event_id == event_id and
       order.held_until) && DateTime.compare(DateTime.utc_now(), order.held_until) == :lt
  end

  defp schedule_tick(socket) do
    if connected?(socket), do: Process.send_after(self(), :tick, 1000)
    socket
  end

  # --- view helpers ---

  defp preview_total(assigns) do
    addon_total =
      assigns.addons
      |> Enum.filter(&(&1.id in assigns.selected_addons))
      |> Enum.reduce(0, &(&1.price_cents + &2))

    assigns.selected.ticket_type.price_cents + addon_total
  end

  defp remaining_seconds(%{held_until: held_until}) do
    max(DateTime.diff(held_until, DateTime.utc_now()), 0)
  end

  defp format_countdown(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  defp reason(:sold_out), do: "Udsolgt"
  defp reason(:not_open), do: "Salg ikke åbnet endnu"
  defp reason(:closed), do: "Salg lukket"
  defp reason(:ineligible), do: "Kun for berettigede grupper"
  defp reason(_), do: ""

  defp humanize(:order_requires_ticket), do: "Vælg mindst én billet."
  defp humanize(:forening_billing_not_ready), do: "Betaling er ikke klar for denne forening."
  defp humanize(%Ash.Error.Invalid{}), do: "Tjek dine svar og prøv igen."
  defp humanize(_), do: "Noget gik galt. Prøv igen."
end
