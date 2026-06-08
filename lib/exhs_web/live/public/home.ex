defmodule ExhsWeb.PublicLive.Home do
  @moduledoc false
  use ExhsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      if forening = socket.assigns[:current_forening] do
        tagline = get_in(forening.branding || %{}, ["tagline"])

        socket
        |> assign(:page_title, forening.name)
        |> assign(:page_description, tagline)
        |> assign(:page_image, forening.banner_url)
        |> assign(:upcoming_events, list_upcoming_events(socket.assigns))
      else
        socket
        |> assign(:page_title, nil)
        |> assign(
          :page_description,
          gettext(
            "Members, events, membership fees and communication — all in one modern platform built for associations."
          )
        )
        |> assign(:upcoming_events, [])
      end

    {:ok, socket}
  end

  @impl true
  def render(%{current_forening: nil} = assigns) do
    ~H"""
    <Layouts.marketing flash={@flash} current_user={@current_user}>
      <.marketing_hero />
      <.marketing_features />
      <.marketing_cta />
    </Layouts.marketing>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.public
      flash={@flash}
      current_forening={@current_forening}
      current_user={@current_user}
      current_path={@current_path}
      current_role={@current_role}
    >
      <.hero forening={@current_forening} />

      <section :if={@current_forening.branding["about"]} class="px-4 py-16 sm:px-6">
        <div class="mx-auto max-w-3xl">
          <h2 class="text-base-content mb-6 text-2xl font-bold">{gettext("About us")}</h2>
          <p class="text-base-content/70 text-lg/relaxed">
            {@current_forening.branding["about"]}
          </p>
        </div>
      </section>

      <section class="px-4 py-16 sm:px-6">
        <div class="mx-auto max-w-7xl">
          <div class="mb-8 flex items-center justify-between">
            <h2 class="text-base-content text-2xl font-bold">{gettext("Upcoming events")}</h2>
            <.link navigate={~p"/events"} class="btn btn-ghost btn-sm gap-1">
              {gettext("See all")} <.icon name="hero-arrow-right-micro" class="size-4" />
            </.link>
          </div>

          <div :if={@upcoming_events == []} class="py-12">
            <.empty_state icon="hero-calendar-days" title={gettext("No upcoming events")} />
          </div>

          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <.event_card :for={event <- Enum.take(@upcoming_events, 3)} event={event} />
          </div>
        </div>
      </section>

      <.join_cta forening={@current_forening} />
    </Layouts.public>
    """
  end

  defp hero(assigns) do
    ~H"""
    <section class="relative overflow-hidden px-4 pt-16 pb-20 sm:px-6 lg:pt-24 lg:pb-28">
      <div class="from-primary/10 via-secondary/5 pointer-events-none absolute inset-0 bg-linear-to-br to-transparent" />
      <div class="from-primary/20 pointer-events-none absolute -top-40 -right-40 size-96 rounded-full bg-radial-[at_30%_40%] to-transparent blur-3xl" />

      <div :if={@forening.banner_url} class="absolute inset-0">
        <img
          src={@forening.banner_url}
          alt=""
          class="size-full object-cover opacity-20"
        />
        <div class="to-base-200 absolute inset-0 bg-linear-to-b from-transparent" />
      </div>

      <div class="relative mx-auto max-w-4xl text-center">
        <h1 class="text-base-content text-3xl font-bold tracking-tight sm:text-4xl lg:text-5xl">
          {@forening.name}
        </h1>
        <p :if={@forening.branding["tagline"]} class="text-base-content/60 mt-4 text-lg sm:text-xl">
          {@forening.branding["tagline"]}
        </p>
        <div class="mt-8 flex flex-wrap items-center justify-center gap-4">
          <.link navigate={~p"/events"} class="btn btn-primary gap-2">
            <.icon name="hero-calendar-days" class="size-5" /> {gettext("See events")}
          </.link>
          <.link navigate={~p"/join"} class="btn btn-ghost gap-2">
            <.icon name="hero-user-plus" class="size-5" /> {gettext("Become a member")}
          </.link>
        </div>
      </div>
    </section>
    """
  end

  defp event_card(assigns) do
    ~H"""
    <.link navigate={~p"/events/#{@event.id}"} class="group">
      <.card class="overflow-hidden transition sm:hover:scale-[1.02]">
        <div :if={@event.cover_image_url} class="aspect-video overflow-hidden">
          <img
            src={@event.cover_image_url}
            alt={@event.title}
            class="size-full object-cover transition group-hover:scale-105"
          />
        </div>
        <div
          :if={!@event.cover_image_url}
          class="from-primary/10 to-secondary/10 flex aspect-video items-center justify-center bg-linear-to-br"
        >
          <.icon name="hero-calendar-days" class="text-primary/30 size-12" />
        </div>
        <div class="p-4">
          <p class="text-primary mb-1 text-xs font-semibold uppercase">
            {format_datetime(@event.starts_at)}
          </p>
          <h3 class="text-base-content text-lg font-semibold">{@event.title}</h3>
          <p :if={@event.location} class="text-base-content/50 mt-1 flex items-center gap-1 text-sm">
            <.icon name="hero-map-pin-micro" class="size-3.5" /> {@event.location}
          </p>
        </div>
      </.card>
    </.link>
    """
  end

  defp join_cta(assigns) do
    ~H"""
    <section class="px-4 py-16 sm:px-6">
      <div class="glass-surface mx-auto max-w-3xl rounded-2xl px-6 py-12 text-center sm:px-12">
        <h2 class="text-base-content text-2xl font-bold">
          {gettext("Join %{name}", name: @forening.name)}
        </h2>
        <p class="text-base-content/60 mx-auto mt-3 max-w-lg">
          {gettext("Become a member and get access to events, community and much more.")}
        </p>
        <.link navigate={~p"/join"} class="btn btn-lg btn-primary mt-6">
          {gettext("Become a member")}
        </.link>
      </div>
    </section>
    """
  end

  defp marketing_hero(assigns) do
    ~H"""
    <section class="relative overflow-hidden px-4 pt-20 pb-24 sm:px-6 lg:pt-32 lg:pb-36">
      <div class="from-primary/10 via-secondary/5 pointer-events-none absolute inset-0 bg-linear-to-br to-transparent" />
      <div class="from-primary/20 pointer-events-none absolute -top-40 -right-40 size-96 rounded-full bg-radial-[at_30%_40%] to-transparent blur-3xl" />
      <div class="from-secondary/15 pointer-events-none absolute -bottom-20 -left-20 size-80 rounded-full bg-radial-[at_70%_60%] to-transparent blur-3xl" />

      <div class="relative mx-auto max-w-4xl text-center">
        <h1 class="text-base-content text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl">
          {gettext("Everything you need for your")}
          <span class="text-gradient">{gettext("association")}</span>
        </h1>
        <p class="text-base-content/60 mx-auto mt-6 max-w-2xl text-lg/relaxed sm:text-xl">
          {gettext(
            "Members, events, membership fees and communication — all in one modern platform built for associations."
          )}
        </p>
        <div class="mt-10 flex flex-wrap items-center justify-center gap-4">
          <.link navigate={~p"/register"} class="btn btn-lg btn-primary gap-2">
            <.icon name="hero-rocket-launch" class="size-5" /> {gettext("Get started for free")}
          </.link>
        </div>
      </div>
    </section>
    """
  end

  defp marketing_features(assigns) do
    ~H"""
    <section id="features" class="px-4 py-20 sm:px-6">
      <div class="mx-auto max-w-7xl">
        <div class="mb-16 text-center">
          <h2 class="text-base-content text-3xl font-bold tracking-tight sm:text-4xl">
            {gettext("Everything in one place")}
          </h2>
          <p class="text-base-content/60 mt-4 text-lg">
            {gettext("The tools your association needs — without the complexity.")}
          </p>
        </div>

        <div class="grid grid-cols-1 gap-4 md:grid-cols-2 md:gap-6 lg:grid-cols-3">
          <.feature_card
            icon="hero-users"
            color="primary"
            title={gettext("Member management")}
            text={gettext("An overview of all members, roles and contact details.")}
          />
          <.feature_card
            icon="hero-calendar-days"
            color="secondary"
            title={gettext("Events & registration")}
            text={gettext("Create events with registration, waitlists and automatic reminders.")}
          />
          <.feature_card
            icon="hero-banknotes"
            color="accent"
            title={gettext("Membership fees & payment")}
            text={gettext("Automatic collection via Stripe. Keep track of who has paid.")}
          />
          <.feature_card
            icon="hero-chart-bar"
            color="warning"
            title={gettext("Dashboard & statistics")}
            text={gettext("See your association's key figures at a glance.")}
          />
          <.feature_card
            icon="hero-paint-brush"
            color="info"
            title={gettext("Your own brand")}
            text={gettext("Your own logo, colours and subdomain. Members see your association.")}
          />
          <.feature_card
            icon="hero-shield-check"
            color="error"
            title={gettext("GDPR & security")}
            text={gettext("European hosting, encrypted data and full GDPR compliance.")}
          />
        </div>
      </div>
    </section>
    """
  end

  defp marketing_cta(assigns) do
    ~H"""
    <section class="px-4 py-20 sm:px-6">
      <div class="glass-surface mx-auto max-w-4xl rounded-3xl px-6 py-12 text-center sm:px-8 sm:py-16">
        <h2 class="text-base-content text-3xl font-bold tracking-tight">
          {gettext("Ready to get started?")}
        </h2>
        <p class="text-base-content/60 mx-auto mt-4 max-w-xl text-lg">
          {gettext("Create your association in under 5 minutes. Free to try.")}
        </p>
        <div class="mt-8 flex flex-wrap items-center justify-center gap-4">
          <.link navigate={~p"/register"} class="btn btn-lg btn-primary">
            {gettext("Create free account")}
          </.link>
          <.link navigate={~p"/sign-in"} class="btn btn-ghost btn-lg">
            {gettext("Already have an account")}
          </.link>
        </div>
      </div>
    </section>
    """
  end

  defp feature_card(assigns) do
    ~H"""
    <.card class="group p-6 transition sm:hover:scale-[1.02]">
      <div class={[
        "mb-4 flex size-12 items-center justify-center rounded-xl",
        feature_icon_class(@color)
      ]}>
        <.icon name={@icon} class="size-6" />
      </div>
      <h3 class="text-base-content mb-2 text-lg font-semibold">{@title}</h3>
      <p class="text-base-content/60 text-sm/relaxed">{@text}</p>
    </.card>
    """
  end

  defp feature_icon_class("primary"), do: "bg-primary/10 text-primary"
  defp feature_icon_class("secondary"), do: "bg-secondary/10 text-secondary"
  defp feature_icon_class("accent"), do: "bg-accent/10 text-accent"
  defp feature_icon_class("warning"), do: "bg-warning/10 text-warning"
  defp feature_icon_class("info"), do: "bg-info/10 text-info"
  defp feature_icon_class("error"), do: "bg-error/10 text-error"
  defp feature_icon_class(_), do: "bg-primary/10 text-primary"

  defp list_upcoming_events(%{current_scope: %Exhs.Scope{} = scope}) do
    case Exhs.Events.list_public_events(tenant: scope.tenant) do
      {:ok, events} -> events
      _ -> []
    end
  end

  defp list_upcoming_events(%{current_forening: %{id: tenant_id}}) do
    case Exhs.Events.list_public_events(tenant: tenant_id) do
      {:ok, events} -> events
      _ -> []
    end
  end

  defp list_upcoming_events(_), do: []
end
