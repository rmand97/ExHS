defmodule ExhsWeb.AdminLive.Dashboard do
  @moduledoc false
  use ExhsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok, memberships} = Exhs.Organizations.list_memberships(scope: scope, authorize?: false)
    {:ok, groups} = Exhs.Organizations.list_groups(scope: scope, authorize?: false)

    stats = %{
      members: length(memberships),
      active: Enum.count(memberships, &(&1.status == :active)),
      inactive: Enum.count(memberships, &(&1.status == :inactive)),
      admins: Enum.count(memberships, &(&1.role in [:admin, :board])),
      groups: length(groups)
    }

    {:ok,
     socket
     |> assign(:stats, stats)
     |> assign(:page_title, "Admin")}
  end

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
        {@current_forening.name}
        <:subtitle>Oversigt over din forening</:subtitle>
      </.header>

      <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <.stat_card label="Medlemmer" value={@stats.members} icon="hero-users" />
        <.stat_card label="Aktive" value={@stats.active} icon="hero-check-badge" />
        <.stat_card label="Bestyrelse/admin" value={@stats.admins} icon="hero-shield-check" />
        <.stat_card label="Grupper" value={@stats.groups} icon="hero-tag" />
      </div>

      <div class="mt-8 grid gap-4 sm:grid-cols-2">
        <.link
          navigate={~p"/admin/members"}
          class="bg-base-100 border-base-content/5 card hover:border-primary/40 border p-5 transition"
        >
          <div class="flex items-center gap-3">
            <.icon name="hero-users" class="text-primary size-6" />
            <div>
              <p class="text-base-content font-semibold">Medlemmer</p>
              <p class="text-base-content/50 text-sm">Administrer, inviter og rolleadministration</p>
            </div>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/groups"}
          class="bg-base-100 border-base-content/5 card hover:border-primary/40 border p-5 transition"
        >
          <div class="flex items-center gap-3">
            <.icon name="hero-tag" class="text-primary size-6" />
            <div>
              <p class="text-base-content font-semibold">Grupper</p>
              <p class="text-base-content/50 text-sm">Opret grupper og tildel medlemmer</p>
            </div>
          </div>
        </.link>
      </div>
    </Layouts.admin>
    """
  end
end
