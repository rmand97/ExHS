defmodule ExhsWeb.AdminLive.Members.Show do
  @moduledoc false
  use ExhsWeb, :live_view

  import ExhsWeb.Labels

  alias Exhs.Organizations
  alias ExhsWeb.AdminLive.MembersPubSub

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope

    case Organizations.get_membership_by_id(id,
           scope: scope,
           load: [:user, :groups],
           authorize?: false
         ) do
      {:ok, membership} ->
        if connected?(socket), do: MembersPubSub.subscribe(socket.assigns.current_forening.id)

        {:ok,
         socket
         |> assign(:membership, membership)
         |> assign(:page_title, member_name(membership))
         |> load_related()}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Medlem ikke fundet.")
         |> push_navigate(to: ~p"/admin/members")}
    end
  end

  @impl true
  def handle_info(:members_changed, socket) do
    {:noreply, reload(socket)}
  end

  # ── Actions ────────────────────────────────────

  @impl true
  def handle_event("set_role", %{"role" => role}, socket) do
    scope = socket.assigns.current_scope

    case Organizations.set_member_role(socket.assigns.membership, %{role: to_role(role)},
           scope: scope
         ) do
      {:ok, _} ->
        MembersPubSub.broadcast(socket.assigns.current_forening.id)
        {:noreply, socket |> put_flash(:info, "Rolle opdateret.") |> reload()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Kunne ikke ændre rolle (sidste admin?).")}
    end
  end

  def handle_event("activate", _params, socket) do
    Organizations.activate_member(socket.assigns.membership, scope: socket.assigns.current_scope)
    MembersPubSub.broadcast(socket.assigns.current_forening.id)
    {:noreply, socket |> put_flash(:info, "Medlem aktiveret.") |> reload()}
  end

  def handle_event("deactivate", _params, socket) do
    Organizations.deactivate_member(socket.assigns.membership,
      scope: socket.assigns.current_scope
    )

    MembersPubSub.broadcast(socket.assigns.current_forening.id)
    {:noreply, socket |> put_flash(:info, "Medlem deaktiveret.") |> reload()}
  end

  def handle_event("add_group", %{"group_id" => ""}, socket), do: {:noreply, socket}

  def handle_event("add_group", %{"group_id" => group_id}, socket) do
    Organizations.add_member_to_group(
      %{membership_id: socket.assigns.membership.id, group_id: group_id},
      scope: socket.assigns.current_scope
    )

    MembersPubSub.broadcast(socket.assigns.current_forening.id)
    {:noreply, socket |> put_flash(:info, "Tilføjet til gruppe.") |> reload()}
  end

  def handle_event("remove_group", %{"group_id" => group_id}, socket) do
    Organizations.remove_member_from_group_by_keys(
      socket.assigns.membership.id,
      group_id,
      socket.assigns.current_scope
    )

    MembersPubSub.broadcast(socket.assigns.current_forening.id)
    {:noreply, socket |> put_flash(:info, "Fjernet fra gruppe.") |> reload()}
  end

  # ── Loading ────────────────────────────────────

  defp reload(socket) do
    scope = socket.assigns.current_scope

    case Organizations.get_membership_by_id(socket.assigns.membership.id,
           scope: scope,
           load: [:user, :groups],
           authorize?: false
         ) do
      {:ok, membership} -> socket |> assign(:membership, membership) |> load_related()
      _ -> push_navigate(socket, to: ~p"/admin/members")
    end
  end

  defp load_related(socket) do
    scope = socket.assigns.current_scope
    membership = socket.assigns.membership

    {:ok, all_groups} = Organizations.list_groups(scope: scope, authorize?: false)
    {:ok, payments} = Exhs.Billing.list_payments(scope: scope, authorize?: false)

    {:ok, registrations} =
      Exhs.Events.list_registrations(scope: scope, load: [ticket_type: :event], authorize?: false)

    {:ok, events} =
      Exhs.Audit.list_events_for_record(membership.id, authorize?: false)

    member_group_ids = MapSet.new(membership.groups, & &1.id)

    socket
    |> assign(
      :available_groups,
      Enum.reject(all_groups, &MapSet.member?(member_group_ids, &1.id))
    )
    |> assign(:payments, Enum.filter(payments, &(&1.payable_id == membership.id)))
    |> assign(:registrations, Enum.filter(registrations, &(&1.membership_id == membership.id)))
    |> assign(:events, events)
  end

  # ── Render ─────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      current_forening={@current_forening}
      current_role={@current_role}
      current_path={@current_path}
    >
      <div class="mb-4">
        <.link navigate={~p"/admin/members"} class="text-base-content/50 text-sm hover:underline">
          ← Tilbage til medlemmer
        </.link>
      </div>

      <.header>
        {member_name(@membership)}
        <:subtitle>{@membership.user.email}</:subtitle>
        <:actions>
          <.badge variant={role_variant(@membership.role)}>{role_label(@membership.role)}</.badge>
          <.badge variant={status_variant(@membership.status)}>
            {status_label(@membership.status)}
          </.badge>
        </:actions>
      </.header>

      <div class="mt-6 grid gap-6 lg:grid-cols-3">
        <%!-- Left: profile + admin controls --%>
        <div class="space-y-6 lg:col-span-1">
          <.card class="p-5">
            <h3 class="text-base-content font-semibold">Profil</h3>
            <dl class="mt-3 space-y-2 text-sm">
              <.detail label="Navn" value={member_name(@membership)} />
              <.detail label="Email" value={to_string(@membership.user.email)} />
              <.detail label="Telefon" value={@membership.user.phone || "—"} />
              <.detail label="By" value={@membership.user.city || "—"} />
              <.detail label="Medlem siden" value={format_date(@membership.joined_at)} />
            </dl>
          </.card>

          <.card :if={@can_write?} class="p-5">
            <h3 class="text-base-content font-semibold">Administration</h3>

            <div class="mt-3">
              <label class="text-base-content/60 text-xs">Rolle</label>
              <form phx-change="set_role" class="mt-1">
                <select name="role" class="select select-bordered select-sm w-full">
                  <option value="member" selected={@membership.role == :member}>Medlem</option>
                  <option value="board" selected={@membership.role == :board}>Bestyrelse</option>
                  <option value="admin" selected={@membership.role == :admin}>Admin</option>
                </select>
              </form>
            </div>

            <div class="mt-4">
              <.button
                :if={@membership.status == :active}
                phx-click="deactivate"
                variant="destructive"
                class="w-full"
              >
                Deaktiver medlem
              </.button>
              <.button
                :if={@membership.status == :inactive}
                phx-click="activate"
                variant="primary"
                class="w-full"
              >
                Aktiver medlem
              </.button>
            </div>
          </.card>

          <.card class="p-5">
            <h3 class="text-base-content font-semibold">Grupper</h3>
            <div class="mt-3 flex flex-wrap gap-1.5">
              <span :if={@membership.groups == []} class="text-base-content/40 text-sm">
                Ingen grupper
              </span>
              <span
                :for={g <- @membership.groups}
                class="bg-base-content/5 text-base-content/70 inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs"
              >
                {g.name}
                <button
                  :if={@can_write?}
                  phx-click="remove_group"
                  phx-value-group_id={g.id}
                  class="hover:text-error"
                  aria-label="Fjern fra gruppe"
                >
                  <.icon name="hero-x-mark" class="size-3" />
                </button>
              </span>
            </div>
            <form
              :if={@can_write? and @available_groups != []}
              phx-change="add_group"
              class="mt-3"
            >
              <select name="group_id" class="select select-bordered select-sm w-full">
                <option value="">Tilføj til gruppe…</option>
                <option :for={g <- @available_groups} value={g.id}>{g.name}</option>
              </select>
            </form>
          </.card>
        </div>

        <%!-- Right: payments, registrations, audit --%>
        <div class="space-y-6 lg:col-span-2">
          <.card class="p-5">
            <h3 class="text-base-content font-semibold">Betalinger</h3>
            <p :if={@payments == []} class="text-base-content/40 mt-2 text-sm">Ingen betalinger</p>
            <ul :if={@payments != []} class="divide-base-content/5 mt-2 divide-y">
              <li :for={p <- @payments} class="flex items-center justify-between py-2 text-sm">
                <span class="text-base-content/70">{p.description || "Betaling"}</span>
                <span class="flex items-center gap-2">
                  <span class="text-base-content font-medium">
                    {format_amount(p.amount_cents, p.currency)}
                  </span>
                  <.badge variant={payment_variant(p.status)}>{payment_label(p.status)}</.badge>
                </span>
              </li>
            </ul>
          </.card>

          <.card class="p-5">
            <h3 class="text-base-content font-semibold">Tilmeldinger</h3>
            <p :if={@registrations == []} class="text-base-content/40 mt-2 text-sm">
              Ingen tilmeldinger
            </p>
            <ul :if={@registrations != []} class="divide-base-content/5 mt-2 divide-y">
              <li :for={r <- @registrations} class="flex items-center justify-between py-2 text-sm">
                <span class="text-base-content/70">{r.ticket_type.event.title}</span>
                <.badge variant="default">{r.status}</.badge>
              </li>
            </ul>
          </.card>

          <.card class="p-5">
            <h3 class="text-base-content font-semibold">Historik</h3>
            <p :if={@events == []} class="text-base-content/40 mt-2 text-sm">Ingen hændelser</p>
            <ul :if={@events != []} class="divide-base-content/5 mt-2 divide-y">
              <li :for={e <- @events} class="flex items-center justify-between py-2 text-sm">
                <span class="text-base-content/70">{e.action}</span>
                <span class="text-base-content/40">{format_datetime(e.occurred_at)}</span>
              </li>
            </ul>
          </.card>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp detail(assigns) do
    ~H"""
    <div class="flex justify-between gap-3">
      <dt class="text-base-content/50">{@label}</dt>
      <dd class="text-base-content text-right font-medium">{@value}</dd>
    </div>
    """
  end

  defp payment_label(:succeeded), do: "Betalt"
  defp payment_label(:refunded), do: "Refunderet"
  defp payment_label(:failed), do: "Fejlet"
  defp payment_label(other), do: to_string(other)

  defp payment_variant(:succeeded), do: "success"
  defp payment_variant(:refunded), do: "warning"
  defp payment_variant(:failed), do: "error"
  defp payment_variant(_), do: "default"
end
