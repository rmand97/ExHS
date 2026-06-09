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
         |> put_flash(:error, gettext("Member not found."))
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
        {:noreply, socket |> put_flash(:info, gettext("Role updated.")) |> reload()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not change role (last admin?)."))}
    end
  end

  def handle_event("activate", _params, socket) do
    Organizations.activate_member(socket.assigns.membership, scope: socket.assigns.current_scope)
    MembersPubSub.broadcast(socket.assigns.current_forening.id)
    {:noreply, socket |> put_flash(:info, gettext("Member activated.")) |> reload()}
  end

  def handle_event("deactivate", _params, socket) do
    Organizations.deactivate_member(socket.assigns.membership,
      scope: socket.assigns.current_scope
    )

    MembersPubSub.broadcast(socket.assigns.current_forening.id)
    {:noreply, socket |> put_flash(:info, gettext("Member deactivated.")) |> reload()}
  end

  def handle_event("live_select_change", %{"text" => text, "id" => live_select_id}, socket) do
    query = String.downcase(text)

    options =
      socket.assigns.available_groups
      |> Enum.filter(&String.contains?(String.downcase(&1.name), query))
      |> group_options()

    send_update(LiveSelect.Component, id: live_select_id, options: options)
    {:noreply, socket}
  end

  def handle_event("add_group", %{"group_id" => group_id}, socket) when group_id != "" do
    Organizations.add_member_to_group(
      %{membership_id: socket.assigns.membership.id, group_id: group_id},
      scope: socket.assigns.current_scope
    )

    MembersPubSub.broadcast(socket.assigns.current_forening.id)
    {:noreply, socket |> put_flash(:info, gettext("Added to group.")) |> reload()}
  end

  def handle_event("add_group", _params, socket), do: {:noreply, socket}

  def handle_event("remove_group", %{"group_id" => group_id}, socket) do
    Organizations.remove_member_from_group_by_keys(
      socket.assigns.membership.id,
      group_id,
      socket.assigns.current_scope
    )

    MembersPubSub.broadcast(socket.assigns.current_forening.id)
    {:noreply, socket |> put_flash(:info, gettext("Removed from group.")) |> reload()}
  end

  # ── Loading ────────────────────────────────────

  defp group_options(groups), do: Enum.map(groups, &%{label: &1.name, value: &1.id})

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
          ← {gettext("Back to members")}
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
            <h3 class="text-base-content font-semibold">{gettext("Profile")}</h3>
            <dl class="mt-3 space-y-2 text-sm">
              <.detail label={gettext("Name")} value={member_name(@membership)} />
              <.detail label="Email" value={to_string(@membership.user.email)} />
              <.detail label={gettext("Phone")} value={@membership.user.phone || "—"} />
              <.detail label={gettext("City")} value={@membership.user.city || "—"} />
              <.detail label={gettext("Member since")} value={format_date(@membership.joined_at)} />
            </dl>
          </.card>

          <.card :if={@can_write?} class="p-5">
            <h3 class="text-base-content font-semibold">Administration</h3>

            <div class="mt-3">
              <label class="text-base-content/60 text-xs">{gettext("Role")}</label>
              <form phx-change="set_role" class="mt-1">
                <select name="role" class="select select-bordered select-sm w-full">
                  <option value="member" selected={@membership.role == :member}>
                    {gettext("Member")}
                  </option>
                  <option value="board" selected={@membership.role == :board}>
                    {gettext("Board")}
                  </option>
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
                {gettext("Deactivate member")}
              </.button>
              <.button
                :if={@membership.status == :inactive}
                phx-click="activate"
                variant="primary"
                class="w-full"
              >
                {gettext("Activate member")}
              </.button>
            </div>
          </.card>

          <.card class="p-5">
            <h3 class="text-base-content font-semibold">{gettext("Groups")}</h3>
            <div class="mt-3 flex flex-wrap gap-1.5">
              <span :if={@membership.groups == []} class="text-base-content/40 text-sm">
                {gettext("No groups")}
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
                  aria-label={gettext("Remove from group")}
                >
                  <.icon name="hero-x-mark" class="size-3" />
                </button>
              </span>
            </div>
            <.form
              :let={f}
              :if={@can_write? and @available_groups != []}
              for={to_form(%{"group_id" => nil}, as: nil)}
              phx-change="add_group"
              class="mt-3"
            >
              <.live_select
                id="add-group-select"
                field={f[:group_id]}
                options={group_options(@available_groups)}
                style={:daisyui}
                placeholder={gettext("Add to group…")}
              />
            </.form>
          </.card>
        </div>

        <%!-- Right: payments, registrations, audit --%>
        <div class="space-y-6 lg:col-span-2">
          <.card class="p-5">
            <h3 class="text-base-content font-semibold">{gettext("Payments")}</h3>
            <p :if={@payments == []} class="text-base-content/40 mt-2 text-sm">
              {gettext("No payments")}
            </p>
            <ul :if={@payments != []} class="divide-base-content/5 mt-2 divide-y">
              <li :for={p <- @payments} class="flex items-center justify-between py-2 text-sm">
                <span class="text-base-content/70">{p.description || gettext("Payment")}</span>
                <span class="flex items-center gap-2">
                  <span class="text-base-content font-medium">
                    {format_amount(p.amount_cents, p.currency)}
                  </span>
                  <.badge variant={payment_status_variant(p.status)}>
                    {payment_status_label(p.status)}
                  </.badge>
                </span>
              </li>
            </ul>
          </.card>

          <.card class="p-5">
            <h3 class="text-base-content font-semibold">{gettext("Registrations")}</h3>
            <p :if={@registrations == []} class="text-base-content/40 mt-2 text-sm">
              {gettext("No registrations")}
            </p>
            <ul :if={@registrations != []} class="divide-base-content/5 mt-2 divide-y">
              <li :for={r <- @registrations} class="flex items-center justify-between py-2 text-sm">
                <span class="text-base-content/70">{r.ticket_type.event.title}</span>
                <.badge variant={reg_status_variant(r.status)}>{reg_status_label(r.status)}</.badge>
              </li>
            </ul>
          </.card>

          <.card class="p-5">
            <h3 class="text-base-content font-semibold">{gettext("History")}</h3>
            <p :if={@events == []} class="text-base-content/40 mt-2 text-sm">
              {gettext("No events")}
            </p>
            <ul :if={@events != []} class="divide-base-content/5 mt-2 divide-y">
              <li :for={e <- @events} class="flex items-center justify-between py-2 text-sm">
                <span class="text-base-content/70">{action_label(e.action)}</span>
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
end
