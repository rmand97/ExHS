defmodule ExhsWeb.PublicLive.Events.Index do
  @moduledoc false
  use ExhsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_forening] do
      events = load_events(socket.assigns)

      {:ok,
       assign(socket,
         events: events,
         page_title: "Events",
         page_description: "Kommende events hos #{socket.assigns.current_forening.name}"
       )}
    else
      {:ok, redirect(socket, to: "/")}
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
      <div class="px-4 py-12 sm:px-6">
        <div class="mx-auto max-w-7xl">
          <div class="mb-8">
            <h1 class="text-base-content text-3xl font-bold">Events</h1>
            <p class="text-base-content/60 mt-2">
              Kommende events hos {@current_forening.name}
            </p>
          </div>

          <div :if={@events == []} class="py-16">
            <.empty_state icon="hero-calendar-days" title="Ingen kommende events lige nu" />
          </div>

          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <.event_card :for={event <- @events} event={event} />
          </div>
        </div>
      </div>
    </Layouts.public>
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
          <p :if={@event.description} class="text-base-content/50 mt-2 line-clamp-2 text-sm">
            {@event.description}
          </p>
          <p :if={@event.location} class="text-base-content/50 mt-2 flex items-center gap-1 text-sm">
            <.icon name="hero-map-pin-micro" class="size-3.5" /> {@event.location}
          </p>
        </div>
      </.card>
    </.link>
    """
  end

  defp load_events(%{current_forening: %{id: tenant_id}}) do
    case Exhs.Events.list_public_events(tenant: tenant_id) do
      {:ok, events} -> events
      _ -> []
    end
  end
end
