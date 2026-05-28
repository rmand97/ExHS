defmodule ExhsWeb.PublicLive.Events.Show do
  @moduledoc false
  use ExhsWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if socket.assigns[:current_forening] do
      tenant_id = socket.assigns.current_forening.id

      case Exhs.Events.get_public_event(id, tenant: tenant_id) do
        {:ok, event} ->
          ticket_types = load_ticket_types(event.id, tenant_id)

          {:ok,
           assign(socket,
             event: event,
             ticket_types: ticket_types,
             page_title: event.title,
             page_description: event.description,
             page_image: event.cover_image_url
           )}

        {:error, _} ->
          {:ok, redirect(socket, to: "/events")}
      end
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
    >
      <div class="px-4 py-8 sm:px-6">
        <div class="mx-auto max-w-4xl">
          <a
            href="/events"
            class="hover:text-base-content text-base-content/50 mb-6 inline-flex items-center gap-1 text-sm transition"
          >
            <.icon name="hero-arrow-left-micro" class="size-4" /> Alle events
          </a>

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
                {format_date(@event.starts_at)}
              </p>
              <h1 class="text-base-content text-3xl font-bold sm:text-4xl">{@event.title}</h1>

              <div :if={@event.description} class="text-base-content/70 mt-6 text-lg/relaxed">
                {@event.description}
              </div>
            </div>

            <div class="space-y-4">
              <.event_details event={@event} />
              <.ticket_types_card
                ticket_types={@ticket_types}
                event={@event}
                current_user={@current_user}
              />
            </div>
          </div>
        </div>
      </div>
    </Layouts.public>
    """
  end

  defp event_details(assigns) do
    ~H"""
    <.card class="p-5">
      <h3 class="text-base-content mb-4 font-semibold">Detaljer</h3>
      <div class="space-y-3">
        <.detail_row icon="hero-calendar-days" label="Dato" value={format_date(@event.starts_at)} />
        <.detail_row
          :if={@event.ends_at}
          icon="hero-clock"
          label="Slut"
          value={format_date(@event.ends_at)}
        />
        <.detail_row
          :if={@event.location}
          icon="hero-map-pin"
          label="Sted"
          value={@event.location}
        />
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

  defp ticket_types_card(assigns) do
    ~H"""
    <.card class="p-5">
      <h3 class="text-base-content mb-4 font-semibold">Billetter</h3>

      <div :if={@ticket_types == []} class="text-base-content/50 text-sm">
        Ingen billettyper tilgængelige.
      </div>

      <div class="space-y-3">
        <div
          :for={tt <- @ticket_types}
          class="border-base-content/5 flex items-center justify-between rounded-lg border p-3"
        >
          <div>
            <p class="text-base-content text-sm font-medium">{tt.name}</p>
            <p :if={tt.description} class="text-base-content/50 text-xs">{tt.description}</p>
          </div>
          <p class="text-primary text-sm font-semibold">
            {format_price(tt.price_cents, tt.currency)}
          </p>
        </div>
      </div>

      <div class="mt-4">
        <a :if={@current_user} href="#" class="btn btn-block btn-primary">
          Tilmeld
        </a>
        <a :if={!@current_user} href="/sign-in" class="btn btn-block btn-primary">
          Log ind for at tilmelde
        </a>
      </div>
    </.card>
    """
  end

  defp load_ticket_types(event_id, tenant_id) do
    case Exhs.Events.list_ticket_types_for_event(event_id, tenant: tenant_id) do
      {:ok, types} -> types
      _ -> []
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d. %b %Y, kl. %H:%M")
  end

  defp format_price(0, _currency), do: "Gratis"
  defp format_price(cents, currency), do: "#{div(cents, 100)} #{currency}"
end
