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
          "Medlemmer, events, kontingent og kommunikation — alt i én moderne platform bygget til foreninger."
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
          <h2 class="text-base-content mb-6 text-2xl font-bold">Om os</h2>
          <p class="text-base-content/70 text-lg/relaxed">
            {@current_forening.branding["about"]}
          </p>
        </div>
      </section>

      <section class="px-4 py-16 sm:px-6">
        <div class="mx-auto max-w-7xl">
          <div class="mb-8 flex items-center justify-between">
            <h2 class="text-base-content text-2xl font-bold">Kommende events</h2>
            <.link navigate={~p"/events"} class="btn btn-ghost btn-sm gap-1">
              Se alle <.icon name="hero-arrow-right-micro" class="size-4" />
            </.link>
          </div>

          <div :if={@upcoming_events == []} class="py-12">
            <.empty_state icon="hero-calendar-days" title="Ingen kommende events" />
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
            <.icon name="hero-calendar-days" class="size-5" /> Se events
          </.link>
          <.link navigate={~p"/join"} class="btn btn-ghost gap-2">
            <.icon name="hero-user-plus" class="size-5" /> Bliv medlem
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
          Bliv en del af {@forening.name}
        </h2>
        <p class="text-base-content/60 mx-auto mt-3 max-w-lg">
          Bliv medlem og få adgang til events, fællesskab og meget mere.
        </p>
        <.link navigate={~p"/join"} class="btn btn-lg btn-primary mt-6">
          Bliv medlem
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
          Alt du behøver til din <span class="text-gradient">forening</span>
        </h1>
        <p class="text-base-content/60 mx-auto mt-6 max-w-2xl text-lg/relaxed sm:text-xl">
          Medlemmer, events, kontingent og kommunikation — alt i én moderne platform
          bygget til foreninger.
        </p>
        <div class="mt-10 flex flex-wrap items-center justify-center gap-4">
          <.link navigate={~p"/register"} class="btn btn-lg btn-primary gap-2">
            <.icon name="hero-rocket-launch" class="size-5" /> Kom i gang gratis
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
            Alt samlet ét sted
          </h2>
          <p class="text-base-content/60 mt-4 text-lg">
            Værktøjerne din forening har brug for — uden kompleksiteten.
          </p>
        </div>

        <div class="grid grid-cols-1 gap-4 md:gap-6 md:grid-cols-2 lg:grid-cols-3">
          <.feature_card
            icon="hero-users"
            color="primary"
            title="Medlemshåndtering"
            text="Overblik over alle medlemmer, roller og kontaktoplysninger."
          />
          <.feature_card
            icon="hero-calendar-days"
            color="secondary"
            title="Events & tilmelding"
            text="Opret events med tilmelding, ventelister og automatiske påmindelser."
          />
          <.feature_card
            icon="hero-banknotes"
            color="accent"
            title="Kontingent & betaling"
            text="Automatisk opkrævning via Stripe. Hold styr på hvem der har betalt."
          />
          <.feature_card
            icon="hero-chart-bar"
            color="warning"
            title="Dashboard & statistik"
            text="Se din forenings nøgletal med ét blik."
          />
          <.feature_card
            icon="hero-paint-brush"
            color="info"
            title="Dit eget brand"
            text="Eget logo, farver og subdomæne. Medlemmer ser jeres forening."
          />
          <.feature_card
            icon="hero-shield-check"
            color="error"
            title="GDPR & sikkerhed"
            text="Europæisk hosting, krypteret data og fuld GDPR-overholdelse."
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
          Klar til at komme i gang?
        </h2>
        <p class="text-base-content/60 mx-auto mt-4 max-w-xl text-lg">
          Opret din forening på under 5 minutter. Gratis at prøve.
        </p>
        <div class="mt-8 flex flex-wrap items-center justify-center gap-4">
          <.link navigate={~p"/register"} class="btn btn-lg btn-primary">Opret gratis konto</.link>
          <.link navigate={~p"/sign-in"} class="btn btn-ghost btn-lg">Har du allerede en konto</.link>
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
