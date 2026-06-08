defmodule ExhsWeb.SuperadminLive.Dashboard do
  @moduledoc false
  use ExhsWeb, :live_view

  alias Exhs.Organizations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:creating, false)
     |> assign(:form, blank_form())
     |> assign(:page_title, "Superadmin")
     |> load_foreninger()}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:noreply, socket |> assign(:creating, true) |> assign(:form, blank_form())}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, :creating, false)}
  end

  def handle_event("save", %{"forening" => params}, socket) do
    subdomain = params["subdomain"] |> to_string() |> String.trim() |> String.downcase()

    attrs = %{
      name: params["name"],
      subdomain: subdomain,
      slug: subdomain
    }

    case Organizations.provision_forening(
           attrs,
           params["admin_email"],
           socket.assigns.current_user
         ) do
      {:ok, _forening} ->
        {:noreply,
         socket
         |> assign(:creating, false)
         |> put_flash(:info, gettext("Association created and admin invited."))
         |> load_foreninger()}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Could not create the association. Subdomain must be unique.")
         )}
    end
  end

  def handle_event("archive", %{"id" => id}, socket) do
    forening = Enum.find(socket.assigns.foreninger, &(&1.id == id))

    if forening do
      Organizations.archive_forening(forening, actor: socket.assigns.current_user)
    end

    {:noreply, socket |> put_flash(:info, gettext("Association archived.")) |> load_foreninger()}
  end

  defp load_foreninger(socket) do
    actor = socket.assigns.current_user
    {:ok, foreninger} = Organizations.list_foreninger(actor: actor)
    {:ok, memberships} = Organizations.list_all_memberships(actor: actor)
    {:ok, events} = Exhs.Events.list_all_events(actor: actor)

    rows = Enum.sort_by(foreninger, &String.downcase(&1.name))

    socket
    |> assign(:foreninger, rows)
    |> assign(:member_counts, Enum.frequencies_by(memberships, & &1.forening_id))
    |> assign(:event_counts, Enum.frequencies_by(events, & &1.forening_id))
    |> assign(:stats, %{
      total: length(rows),
      active: Enum.count(rows, & &1.active),
      members: length(memberships),
      events: length(events)
    })
    |> stream(:foreninger, rows, reset: true)
  end

  defp blank_form do
    to_form(%{"name" => "", "subdomain" => "", "admin_email" => ""}, as: :forening)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.member
      flash={@flash}
      current_user={@current_user}
      current_path={@current_path}
      my_foreninger={@my_foreninger}
    >
      <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6">
        <.header>
          Superadmin
          <:subtitle>{gettext("All associations on the platform")}</:subtitle>
          <:actions>
            <.button phx-click="new" variant="primary">
              <.icon name="hero-plus" class="size-4" /> {gettext("New association")}
            </.button>
          </:actions>
        </.header>

        <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.stat_card
            label={gettext("Associations")}
            value={to_string(@stats.total)}
            icon="hero-building-office-2"
          />
          <.stat_card
            label={gettext("Active")}
            value={to_string(@stats.active)}
            icon="hero-check-circle"
            color="success"
          />
          <.stat_card
            label={gettext("Memberships")}
            value={to_string(@stats.members)}
            icon="hero-users"
            color="accent"
          />
          <.stat_card
            label="Events"
            value={to_string(@stats.events)}
            icon="hero-calendar-days"
            color="secondary"
          />
        </div>

        <div class="mt-8 overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>{gettext("Name")}</th>
                <th>{gettext("Subdomain")}</th>
                <th>{gettext("Members")}</th>
                <th>Events</th>
                <th>{gettext("Status")}</th>
                <th></th>
              </tr>
            </thead>
            <tbody id="foreninger" phx-update="stream">
              <tr :for={{dom_id, f} <- @streams.foreninger} id={dom_id}>
                <td class="font-medium">{f.name}</td>
                <td class="text-base-content/60">{f.subdomain}</td>
                <td>{Map.get(@member_counts, f.id, 0)}</td>
                <td>{Map.get(@event_counts, f.id, 0)}</td>
                <td>
                  <.badge variant={if f.active, do: "success", else: "default"}>
                    {if f.active, do: gettext("Active"), else: gettext("Archived")}
                  </.badge>
                </td>
                <td class="text-right">
                  <.button
                    :if={f.active}
                    variant="ghost"
                    phx-click="archive"
                    phx-value-id={f.id}
                    data-confirm={gettext("Archive \"%{name}\"?", name: f.name)}
                  >
                    {gettext("Archive")}
                  </.button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <.modal :if={@creating} id="forening-modal" show on_cancel={JS.push("cancel")}>
        <h3 class="text-base-content text-lg font-semibold">{gettext("New association")}</h3>
        <.form for={@form} phx-submit="save" class="mt-4 space-y-4">
          <.input field={@form[:name]} label={gettext("Name")} required />
          <.input field={@form[:subdomain]} label={gettext("Subdomain")} required />
          <.input field={@form[:admin_email]} type="email" label={gettext("Admin email")} required />
          <p class="text-base-content/50 text-xs">
            {gettext("The association becomes available at")}
            <code>subdomain.exhs.dk</code>. {gettext("The admin receives a magic login link.")}
          </p>
          <div class="flex justify-end gap-2">
            <.button type="button" variant="ghost" phx-click="cancel">{gettext("Cancel")}</.button>
            <.button type="submit" variant="primary">{gettext("Create")}</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.member>
    """
  end
end
