defmodule ExhsWeb.AdminLive.Events.Index do
  @moduledoc false
  use ExhsWeb, :live_view

  alias Exhs.Events

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:tab, :upcoming)
     |> assign(:creating, false)
     |> assign(:form, blank_form())
     |> assign(:page_title, "Events")
     |> load_events()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = parse_tab(params["tab"])
    {:noreply, socket |> assign(:tab, tab) |> stream_tab(tab)}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:noreply, socket |> assign(:creating, true) |> assign(:form, blank_form())}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, :creating, false)}
  end

  def handle_event("save", %{"event" => params}, socket) do
    case Events.create_event(event_attrs(params), scope: socket.assigns.current_scope) do
      {:ok, event} ->
        {:noreply, push_navigate(socket, to: ~p"/admin/events/#{event.id}")}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, gettext("Could not create the event. Check title and date."))}
    end
  end

  def handle_event("publish", %{"id" => id}, socket) do
    toggle_publish(socket, id, &Events.publish_event/2, gettext("Event published."))
  end

  def handle_event("unpublish", %{"id" => id}, socket) do
    toggle_publish(socket, id, &Events.unpublish_event/2, gettext("Event unpublished."))
  end

  defp toggle_publish(socket, id, fun, message) do
    event = Enum.find(socket.assigns.events, &(&1.id == id))

    socket =
      with %{} <- event,
           {:ok, _} <- fun.(event, scope: socket.assigns.current_scope) do
        put_flash(socket, :info, message)
      else
        _ -> put_flash(socket, :error, gettext("The action could not be completed."))
      end

    {:noreply, socket |> load_events() |> stream_tab(socket.assigns.tab)}
  end

  defp load_events(socket) do
    {:ok, events} =
      Events.list_events(
        scope: socket.assigns.current_scope,
        load: [:ticket_types],
        authorize?: false
      )

    {:ok, registrations} =
      Events.list_registrations(scope: socket.assigns.current_scope, authorize?: false)

    ticket_event = ticket_type_to_event(events)

    counts =
      registrations
      |> Enum.reject(&(&1.status == :cancelled))
      |> Enum.frequencies_by(&Map.get(ticket_event, &1.ticket_type_id))

    socket
    |> assign(:events, events)
    |> assign(:counts, counts)
  end

  defp ticket_type_to_event(events) do
    for event <- events, tt <- event.ticket_types, into: %{}, do: {tt.id, event.id}
  end

  defp stream_tab(socket, tab) do
    rows = socket.assigns.events |> filter_tab(tab) |> Enum.sort_by(& &1.starts_at, DateTime)
    rows = if tab == :past, do: Enum.reverse(rows), else: rows

    socket
    |> assign(:row_count, length(rows))
    |> stream(:events, rows, reset: true)
  end

  defp filter_tab(events, :drafts), do: Enum.filter(events, &(not &1.published))

  defp filter_tab(events, :past) do
    now = DateTime.utc_now()
    Enum.filter(events, &(&1.published and DateTime.compare(&1.starts_at, now) == :lt))
  end

  defp filter_tab(events, _upcoming) do
    now = DateTime.utc_now()
    Enum.filter(events, &(&1.published and DateTime.compare(&1.starts_at, now) != :lt))
  end

  defp parse_tab("past"), do: :past
  defp parse_tab("drafts"), do: :drafts
  defp parse_tab(_), do: :upcoming

  defp event_attrs(params) do
    %{
      title: params["title"],
      description: nil_if_blank(params["description"]),
      location: nil_if_blank(params["location"]),
      starts_at: parse_dt(params["starts_at"]),
      ends_at: parse_dt(params["ends_at"]),
      membership_required: params["membership_required"] == "true"
    }
  end

  defp parse_dt(nil), do: nil
  defp parse_dt(""), do: nil

  defp parse_dt(str) do
    case NaiveDateTime.from_iso8601(str <> ":00") do
      {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
      _ -> nil
    end
  end

  defp nil_if_blank(nil), do: nil
  defp nil_if_blank(v), do: if(String.trim(v) == "", do: nil, else: v)

  defp blank_form do
    to_form(
      %{
        "title" => "",
        "description" => "",
        "location" => "",
        "starts_at" => "",
        "ends_at" => "",
        "membership_required" => "true"
      },
      as: :event
    )
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
        Events
        <:subtitle>{gettext("Create and manage events")}</:subtitle>
        <:actions>
          <.button :if={@can_write?} phx-click="new" variant="primary">
            <.icon name="hero-plus" class="size-4" /> {gettext("New event")}
          </.button>
        </:actions>
      </.header>

      <div role="tablist" class="tabs tabs-bordered mt-6">
        <.link
          :for={
            {key, label} <- [
              {:upcoming, gettext("Upcoming")},
              {:past, gettext("Past")},
              {:drafts, gettext("Drafts")}
            ]
          }
          patch={~p"/admin/events?tab=#{key}"}
          role="tab"
          class={["tab", @tab == key && "tab-active"]}
        >
          {label}
        </.link>
      </div>

      <div :if={@row_count == 0} class="mt-8">
        <.empty_state icon="hero-calendar-days" title={gettext("No events here")}>
          {empty_copy(@tab)}
        </.empty_state>
      </div>

      <div id="events" phx-update="stream" class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div
          :for={{dom_id, e} <- @streams.events}
          id={dom_id}
          class="glass-surface flex flex-col overflow-hidden rounded-2xl p-5"
        >
          <div class="flex items-start justify-between gap-2">
            <h3 class="text-base-content font-semibold">{e.title}</h3>
            <.badge variant={if e.published, do: "success", else: "default"}>
              {if e.published, do: gettext("Published"), else: gettext("Draft")}
            </.badge>
          </div>
          <p class="text-base-content/50 mt-1 text-sm">
            <.icon name="hero-calendar" class="size-3.5" /> {format_datetime(e.starts_at)}
          </p>
          <p :if={e.location} class="text-base-content/50 text-sm">
            <.icon name="hero-map-pin" class="size-3.5" /> {e.location}
          </p>
          <p class="text-base-content/40 mt-2 text-xs">
            {gettext("%{tickets} ticket type(s) · %{count} registered",
              tickets: length(e.ticket_types),
              count: Map.get(@counts, e.id, 0)
            )}
          </p>
          <div class="border-base-content/10 mt-4 flex items-center gap-2 border-t pt-3">
            <.link navigate={~p"/admin/events/#{e.id}"} class="btn btn-outline btn-sm">
              {gettext("Open")}
            </.link>
            <.button
              :if={@can_write? and not e.published}
              phx-click="publish"
              phx-value-id={e.id}
              variant="ghost"
            >
              {gettext("Publish")}
            </.button>
            <.button
              :if={@can_write? and e.published}
              phx-click="unpublish"
              phx-value-id={e.id}
              variant="ghost"
            >
              {gettext("Unpublish")}
            </.button>
          </div>
        </div>
      </div>

      <.modal :if={@creating} id="event-modal" show on_cancel={JS.push("cancel")}>
        <h3 class="text-base-content text-lg font-semibold">{gettext("New event")}</h3>
        <.form for={@form} phx-submit="save" class="mt-4 space-y-4">
          <.input field={@form[:title]} label={gettext("Title")} required />
          <.input field={@form[:description]} type="textarea" label={gettext("Description")} />
          <.input field={@form[:location]} label={gettext("Location")} />
          <div class="grid gap-4 sm:grid-cols-2">
            <.input
              field={@form[:starts_at]}
              type="datetime-local"
              label={gettext("Start time")}
              required
            />
            <.input field={@form[:ends_at]} type="datetime-local" label={gettext("End time")} />
          </div>
          <.input
            field={@form[:membership_required]}
            type="select"
            label={gettext("Requires membership")}
            options={[{gettext("Yes"), "true"}, {gettext("No"), "false"}]}
          />
          <div class="flex justify-end gap-2">
            <.button type="button" variant="ghost" phx-click="cancel">{gettext("Cancel")}</.button>
            <.button type="submit" variant="primary">{gettext("Create")}</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.admin>
    """
  end

  defp empty_copy(:drafts), do: gettext("No drafts. Create an event to get started.")
  defp empty_copy(:past), do: gettext("No past events yet.")
  defp empty_copy(_), do: gettext("No upcoming events. Create a new event.")
end
