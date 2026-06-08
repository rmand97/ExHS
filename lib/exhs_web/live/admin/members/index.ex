defmodule ExhsWeb.AdminLive.Members.Index do
  @moduledoc false
  use ExhsWeb, :live_view

  import ExhsWeb.Labels

  alias Exhs.Organizations
  alias Exhs.Organizations.MemberFilter
  alias ExhsWeb.AdminLive.MembersPubSub

  @per_page 25

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      MembersPubSub.subscribe(socket.assigns.current_forening.id)
    end

    {:ok, groups} =
      Organizations.list_groups(scope: socket.assigns.current_scope, authorize?: false)

    {:ok,
     socket
     |> assign(:groups, groups)
     |> assign(:selected, MapSet.new())
     |> assign(:invite_form, to_form(%{"email" => "", "role" => "member"}, as: :invite))
     |> assign(:page_title, "Medlemmer")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      q: params["q"] || "",
      status: params["status"] || "",
      role: params["role"] || "",
      group: params["group"] || "",
      sort: params["sort"] || "joined_desc"
    }

    page = parse_page(params["page"])

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:page, page)
     |> load_members()}
  end

  @impl true
  def handle_info(:members_changed, socket) do
    {:noreply, load_members(socket)}
  end

  # ── Filtering ──────────────────────────────────

  @impl true
  def handle_event("filter", params, socket) do
    query =
      %{
        "q" => params["q"],
        "status" => params["status"],
        "role" => params["role"],
        "group" => params["group"],
        "sort" => params["sort"]
      }
      |> drop_blank()

    {:noreply, push_patch(socket, to: ~p"/admin/members?#{query}")}
  end

  # ── Selection ──────────────────────────────────

  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected = toggle(socket.assigns.selected, id)
    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("toggle_all", _params, socket) do
    page_ids = Enum.map(socket.assigns.members, & &1.id)

    selected =
      if Enum.all?(page_ids, &MapSet.member?(socket.assigns.selected, &1)) do
        MapSet.new()
      else
        MapSet.new(page_ids)
      end

    {:noreply, assign(socket, :selected, selected)}
  end

  # ── Invite ─────────────────────────────────────

  def handle_event("invite", %{"invite" => %{"email" => email} = params}, socket) do
    role = to_role(params["role"])

    case Organizations.invite_member_by_email(email, %{role: role}, socket.assigns.current_scope) do
      {:ok, _membership} ->
        MembersPubSub.broadcast(socket.assigns.current_forening.id)

        {:noreply,
         socket
         |> put_flash(:info, "#{email} er inviteret. En log-ind-mail er på vej.")
         |> assign(:invite_form, to_form(%{"email" => "", "role" => "member"}, as: :invite))
         |> load_members()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, invite_error_message(error))}
    end
  end

  # ── Bulk actions ───────────────────────────────

  def handle_event("bulk_assign_group", %{"group_id" => ""}, socket), do: {:noreply, socket}

  def handle_event("bulk_assign_group", %{"group_id" => group_id}, socket) do
    scope = socket.assigns.current_scope

    failures =
      count_failures(socket.assigns.selected, fn membership_id ->
        Organizations.add_member_to_group(
          %{membership_id: membership_id, group_id: group_id},
          scope: scope
        )
      end)

    {:noreply, finish_bulk(socket, "Tildelt gruppe.", failures)}
  end

  def handle_event("bulk_activate", _params, socket) do
    bulk_status(socket, :activate, "Aktiveret.")
  end

  def handle_event("bulk_deactivate", _params, socket) do
    bulk_status(socket, :deactivate, "Deaktiveret.")
  end

  defp bulk_status(socket, action, message) do
    scope = socket.assigns.current_scope
    by_id = Map.new(socket.assigns.members, &{&1.id, &1})

    failures =
      count_failures(socket.assigns.selected, fn id ->
        case by_id[id] do
          nil -> {:error, :not_found}
          membership -> apply_status(action, membership, scope)
        end
      end)

    {:noreply, finish_bulk(socket, message, failures)}
  end

  defp apply_status(:activate, m, scope), do: Organizations.activate_member(m, scope: scope)
  defp apply_status(:deactivate, m, scope), do: Organizations.deactivate_member(m, scope: scope)

  # Runs `fun` per selected id, returning how many returned a non-`:ok`/`{:ok, _}`
  # result so a partial bulk failure is surfaced instead of silently swallowed.
  defp count_failures(selected, fun) do
    Enum.reduce(selected, 0, fn item, acc ->
      case fun.(item) do
        :ok -> acc
        {:ok, _} -> acc
        _ -> acc + 1
      end
    end)
  end

  defp finish_bulk(socket, message, failures) do
    MembersPubSub.broadcast(socket.assigns.current_forening.id)

    socket =
      socket
      |> assign(:selected, MapSet.new())
      |> load_members()

    if failures > 0 do
      put_flash(socket, :error, "#{message} #{failures} kunne ikke opdateres.")
    else
      put_flash(socket, :info, message)
    end
  end

  # ── Loading ────────────────────────────────────

  defp load_members(socket) do
    scope = socket.assigns.current_scope

    {:ok, all} =
      Organizations.list_memberships(scope: scope, load: [:user, :groups], authorize?: false)

    filtered = MemberFilter.apply(all, socket.assigns.filters)
    total = length(filtered)
    pages = max(1, ceil(total / @per_page))
    page = min(socket.assigns.page, pages)
    members = Enum.slice(filtered, (page - 1) * @per_page, @per_page)

    socket
    |> assign(:members, members)
    |> assign(:total, total)
    |> assign(:page, page)
    |> assign(:pages, pages)
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
      <.header>
        Medlemmer
        <:subtitle>{@total} medlemmer</:subtitle>
        <:actions>
          <.button :if={@can_write?} phx-click={show_modal("invite-modal")} variant="primary">
            <.icon name="hero-user-plus" class="size-4" /> Inviter medlem
          </.button>
        </:actions>
      </.header>

      <.form
        for={%{}}
        as={:filter}
        phx-change="filter"
        phx-submit="filter"
        class="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-5"
      >
        <input
          type="search"
          name="q"
          value={@filters.q}
          placeholder="Søg navn eller email…"
          class="input input-bordered input-sm w-full lg:col-span-2"
        />
        <select name="status" class="select select-bordered select-sm">
          <option value="" selected={@filters.status == ""}>Alle statusser</option>
          <option value="active" selected={@filters.status == "active"}>Aktiv</option>
          <option value="inactive" selected={@filters.status == "inactive"}>Inaktiv</option>
        </select>
        <select name="role" class="select select-bordered select-sm">
          <option value="" selected={@filters.role == ""}>Alle roller</option>
          <option value="admin" selected={@filters.role == "admin"}>Admin</option>
          <option value="board" selected={@filters.role == "board"}>Bestyrelse</option>
          <option value="member" selected={@filters.role == "member"}>Medlem</option>
        </select>
        <select name="group" class="select select-bordered select-sm">
          <option value="" selected={@filters.group == ""}>Alle grupper</option>
          <option :for={g <- @groups} value={g.id} selected={@filters.group == g.id}>{g.name}</option>
        </select>
        <input type="hidden" name="sort" value={@filters.sort} />
      </.form>

      <div class="mt-3 flex flex-wrap items-center justify-between gap-2">
        <select
          name="sort"
          class="select select-bordered select-sm"
          phx-change="filter"
          form="sort-form"
        >
          <option value="joined_desc" selected={@filters.sort == "joined_desc"}>Nyeste først</option>
          <option value="joined_asc" selected={@filters.sort == "joined_asc"}>Ældste først</option>
          <option value="name" selected={@filters.sort == "name"}>Navn (A–Å)</option>
        </select>
        <.link
          href={export_path(@filters)}
          class="btn btn-ghost btn-sm"
          download
        >
          <.icon name="hero-arrow-down-tray" class="size-4" /> Eksporter CSV
        </.link>
      </div>

      <%!-- sort lives in its own tiny form so the select can submit independently --%>
      <form id="sort-form" phx-change="filter" class="hidden"></form>

      <%!-- Bulk toolbar --%>
      <div
        :if={@can_write? and MapSet.size(@selected) > 0}
        class="bg-base-100 border-base-content/10 mt-4 flex flex-wrap items-center gap-3 rounded-xl border p-3"
      >
        <span class="text-base-content/70 text-sm font-medium">
          {MapSet.size(@selected)} valgt
        </span>
        <form phx-change="bulk_assign_group" class="flex items-center gap-2">
          <select name="group_id" class="select select-bordered select-sm">
            <option value="">Tildel gruppe…</option>
            <option :for={g <- @groups} value={g.id}>{g.name}</option>
          </select>
        </form>
        <.button phx-click="bulk_activate" variant="ghost">Aktiver</.button>
        <.button phx-click="bulk_deactivate" variant="ghost">Deaktiver</.button>
      </div>

      <div :if={@members == []} class="mt-8">
        <.empty_state icon="hero-users" title="Ingen medlemmer">
          Ingen medlemmer matcher dine filtre.
        </.empty_state>
      </div>

      <div :if={@members != []} class="mt-4 overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th :if={@can_write?} class="w-10">
                <input
                  type="checkbox"
                  class="checkbox checkbox-sm"
                  phx-click="toggle_all"
                  checked={
                    @members != [] and
                      Enum.all?(@members, &MapSet.member?(@selected, &1.id))
                  }
                />
              </th>
              <th>Navn</th>
              <th class="hidden md:table-cell">Email</th>
              <th>Rolle</th>
              <th>Status</th>
              <th class="hidden lg:table-cell">Grupper</th>
              <th class="hidden sm:table-cell">Medlem siden</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={m <- @members} class="hover">
              <td :if={@can_write?}>
                <input
                  type="checkbox"
                  class="checkbox checkbox-sm"
                  phx-click="toggle_select"
                  phx-value-id={m.id}
                  checked={MapSet.member?(@selected, m.id)}
                />
              </td>
              <td>
                <.link
                  navigate={~p"/admin/members/#{m.id}"}
                  class="text-base-content font-medium hover:underline"
                >
                  {member_name(m)}
                </.link>
                <p class="text-base-content/50 truncate text-xs md:hidden">{m.user.email}</p>
              </td>
              <td class="text-base-content/60 hidden text-sm md:table-cell">{m.user.email}</td>
              <td>
                <.badge variant={role_variant(m.role)}>{role_label(m.role)}</.badge>
              </td>
              <td>
                <.badge variant={status_variant(m.status)}>{status_label(m.status)}</.badge>
              </td>
              <td class="hidden lg:table-cell">
                <div class="flex flex-wrap gap-1">
                  <.badge :for={g <- m.groups} variant="default">{g.name}</.badge>
                </div>
              </td>
              <td class="text-base-content/50 hidden text-sm sm:table-cell">
                {format_date(m.joined_at)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@pages > 1} class="mt-4 flex items-center justify-between">
        <.link
          :if={@page > 1}
          patch={page_path(@filters, @page - 1)}
          class="btn btn-ghost btn-sm"
        >
          ← Forrige
        </.link>
        <span class="text-base-content/50 text-sm">Side {@page} af {@pages}</span>
        <.link
          :if={@page < @pages}
          patch={page_path(@filters, @page + 1)}
          class="btn btn-ghost btn-sm"
        >
          Næste →
        </.link>
      </div>

      <.modal id="invite-modal">
        <h3 class="text-base-content text-lg font-semibold">Inviter nyt medlem</h3>
        <p class="text-base-content/60 mt-1 text-sm">
          Vi opretter en konto og sender et log-ind-link på email.
        </p>
        <.form for={@invite_form} phx-submit="invite" class="mt-4 space-y-4">
          <.input field={@invite_form[:email]} type="email" label="Email" required />
          <.input
            field={@invite_form[:role]}
            type="select"
            label="Rolle"
            options={[{"Medlem", "member"}, {"Bestyrelse", "board"}, {"Admin", "admin"}]}
          />
          <div class="flex justify-end gap-2">
            <.button type="button" variant="ghost" phx-click={hide_modal("invite-modal")}>
              Annuller
            </.button>
            <.button type="submit" variant="primary">Send invitation</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.admin>
    """
  end

  # ── Helpers ────────────────────────────────────

  defp toggle(set, id) do
    if MapSet.member?(set, id), do: MapSet.delete(set, id), else: MapSet.put(set, id)
  end

  defp parse_page(nil), do: 1

  defp parse_page(str) do
    case Integer.parse(str) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp drop_blank(map), do: Map.reject(map, fn {_k, v} -> v in [nil, ""] end)

  defp export_path(filters) do
    query = filters |> Map.take([:q, :status, :role, :group, :sort]) |> drop_blank()
    ~p"/admin/export/members.csv?#{query}"
  end

  defp page_path(filters, page) do
    query =
      filters
      |> Map.take([:q, :status, :role, :group, :sort])
      |> Map.put(:page, page)
      |> drop_blank()

    ~p"/admin/members?#{query}"
  end

  defp invite_error_message(%Ash.Error.Invalid{errors: errors}) do
    if Enum.any?(errors, &match?(%{field: :user_id}, &1)) do
      "Personen er allerede medlem."
    else
      "Kunne ikke invitere. Tjek emailadressen."
    end
  end

  defp invite_error_message(_), do: "Kunne ikke invitere."
end
