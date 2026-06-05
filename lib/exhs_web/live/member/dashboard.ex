defmodule ExhsWeb.MemberLive.Dashboard do
  @moduledoc false
  use ExhsWeb, :live_view

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
      |> load_memberships(filters, pagination)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:livefilter, :updated, params}, socket) do
    all_params = Map.merge(socket.assigns.remaining_params, params)
    {:noreply, push_patch(socket, to: Serializer.to_path("/dashboard", all_params))}
  end

  def handle_info({:livefilter, :page_changed, pagination_params}, socket) do
    filter_params = Serializer.to_params(socket.assigns.livefilter.filters)
    all_params = Map.merge(filter_params, pagination_params)
    {:noreply, push_patch(socket, to: Serializer.to_path("/dashboard", all_params))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.member flash={@flash} current_user={@current_user} current_path={@current_path}>
      <.header>
        Dashboard
        <:subtitle>Dine foreninger og medlemskaber</:subtitle>
      </.header>

      <div :if={@loading} class="mt-6 space-y-4">
        <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <.skeleton class="h-24 w-full" />
          <.skeleton class="h-24 w-full" />
          <.skeleton class="h-24 w-full" />
        </div>
        <.skeleton class="h-10 w-full" />
        <.skeleton class="h-64 w-full" />
      </div>

      <div :if={!@loading}>
        <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <.stat_card
            label="Foreninger"
            value={@stats.foreninger}
            icon="hero-building-library"
          />
          <.stat_card
            label="Aktive medlemskaber"
            value={@stats.active}
            icon="hero-check-badge"
          />
          <.stat_card
            label="Medlemskaber i alt"
            value={@stats.total}
            icon="hero-user-group"
          />
        </div>

        <div class="mt-8">
          <LiveFilter.bar filter={@livefilter} />
        </div>

        <div :if={@memberships == []} class="mt-8">
          <.empty_state icon="hero-building-library" title="Ingen medlemskaber endnu">
            Du er ikke medlem af nogen foreninger.
          </.empty_state>
        </div>

        <div :if={@memberships != []} class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <.membership_card :for={membership <- @memberships} membership={membership} />
        </div>

        <div :if={@memberships != []} class="mt-6">
          <LiveFilter.paginator pagination={@pagination} />
        </div>
      </div>
    </Layouts.member>
    """
  end

  defp membership_card(assigns) do
    ~H"""
    <.card class="p-5">
      <div class="flex items-start gap-3">
        <.forening_logo forening={@membership.forening} />
        <div class="min-w-0 flex-1">
          <h3 class="text-base-content truncate font-semibold">
            {@membership.forening.name}
          </h3>
          <div class="mt-1 flex flex-wrap gap-1.5">
            <.badge variant={role_variant(@membership.role)}>
              {role_label(@membership.role)}
            </.badge>
            <.badge variant={status_variant(@membership.status)}>
              {status_label(@membership.status)}
            </.badge>
          </div>
          <p class="text-base-content/50 mt-2 text-xs">
            Medlem siden {format_date(@membership.joined_at)}
          </p>
        </div>
      </div>
      <div class="mt-4 flex items-center gap-4">
        <.link
          navigate={~p"/memberships/#{@membership.id}"}
          class="text-primary text-sm font-medium hover:underline"
        >
          Detaljer
        </.link>
        <a
          href={forening_url(@membership.forening)}
          class="text-base-content/40 text-sm hover:underline"
        >
          Besøg forening →
        </a>
      </div>
    </.card>
    """
  end

  defp forening_logo(assigns) do
    ~H"""
    <div :if={@forening.logo_url} class="size-10 shrink-0 overflow-hidden rounded-xl">
      <img src={@forening.logo_url} alt={@forening.name} class="size-full object-cover" />
    </div>
    <div
      :if={!@forening.logo_url}
      class="from-primary text-primary-content to-secondary flex size-10 shrink-0 items-center justify-center rounded-xl bg-linear-to-br text-sm font-bold"
    >
      {String.first(@forening.name)}
    </div>
    """
  end

  defp filter_config do
    [
      LiveFilter.text(:search, label: "Søg forening", always_on: true, placeholder: "Søg..."),
      LiveFilter.select(:role,
        label: "Rolle",
        options: [{"Admin", "admin"}, {"Bestyrelse", "board"}, {"Medlem", "member"}]
      ),
      LiveFilter.select(:status,
        label: "Status",
        options: [{"Aktiv", "active"}, {"Inaktiv", "inactive"}]
      )
    ]
  end

  defp load_memberships(socket, filters, pagination) do
    user = socket.assigns.current_user

    case Exhs.Organizations.list_my_memberships(actor: user) do
      {:ok, all_memberships} ->
        filtered = apply_filters(all_memberships, filters)
        total = length(filtered)
        page = Enum.slice(filtered, pagination.offset, pagination.limit)
        pagination = LiveFilter.Pagination.with_total(pagination, total)

        socket
        |> assign(:memberships, page)
        |> assign(:pagination, pagination)
        |> assign(:stats, compute_stats(all_memberships))
        |> assign(:page_title, "Dashboard")
        |> assign(:loading, false)

      {:error, _} ->
        pagination = LiveFilter.Pagination.with_total(pagination, 0)

        socket
        |> assign(:memberships, [])
        |> assign(:pagination, pagination)
        |> assign(:stats, %{total: 0, active: 0, foreninger: 0})
        |> assign(:page_title, "Dashboard")
        |> assign(:loading, false)
    end
  end

  defp apply_filters(memberships, filters) do
    Enum.reduce(filters, memberships, fn filter, acc ->
      apply_filter(acc, filter)
    end)
  end

  defp apply_filter(memberships, %{field: :search, value: value})
       when is_binary(value) and value != "" do
    term = String.downcase(value)
    Enum.filter(memberships, &String.contains?(String.downcase(&1.forening.name), term))
  end

  defp apply_filter(memberships, %{field: :role, value: value})
       when is_binary(value) and value != "" do
    Enum.filter(memberships, &(to_string(&1.role) == value))
  end

  defp apply_filter(memberships, %{field: :status, value: value})
       when is_binary(value) and value != "" do
    Enum.filter(memberships, &(to_string(&1.status) == value))
  end

  defp apply_filter(memberships, _filter), do: memberships

  defp compute_stats(memberships) do
    %{
      total: length(memberships),
      active: Enum.count(memberships, &(&1.status == :active)),
      foreninger: memberships |> Enum.map(& &1.forening.id) |> Enum.uniq() |> length()
    }
  end
end
