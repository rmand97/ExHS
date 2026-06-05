defmodule ExhsWeb.AdminLive.Events.Show do
  @moduledoc false
  use ExhsWeb, :live_view

  import ExhsWeb.Labels

  alias Exhs.Events

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Events.get_event_by_id(id,
           scope: socket.assigns.current_scope,
           load: [ticket_types: [:seats_taken, :seats_left, :eligible_groups]],
           authorize?: false
         ) do
      {:ok, event} ->
        {:ok,
         socket
         |> assign(:event, event)
         |> assign(:modal, nil)
         |> assign(:event_form, event_form(event))
         |> assign(:ticket_form, blank_ticket_form())
         |> assign(:addon_form, blank_addon_form())
         |> assign(:question_form, blank_question_form())
         |> assign(:questions, [])
         |> assign(:groups, load_groups(socket))
         |> assign(:page_title, event.title)
         |> load_addons()
         |> load_registrations()}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Event ikke fundet.")
         |> push_navigate(to: ~p"/admin/events")}
    end
  end

  # ── Event ──────────────────────────────────────

  @impl true
  def handle_event("edit_event", _params, socket) do
    {:noreply,
     socket |> assign(:modal, :event) |> assign(:event_form, event_form(socket.assigns.event))}
  end

  def handle_event("save_event", %{"event" => params}, socket) do
    case Events.update_event(socket.assigns.event, event_attrs(params),
           scope: socket.assigns.current_scope
         ) do
      {:ok, _} ->
        {:noreply,
         socket |> assign(:modal, nil) |> put_flash(:info, "Event opdateret.") |> reload()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Kunne ikke gemme. Tjek titel og dato.")}
    end
  end

  def handle_event("publish", _params, socket) do
    Events.publish_event(socket.assigns.event, scope: socket.assigns.current_scope)
    {:noreply, socket |> put_flash(:info, "Event publiceret.") |> reload()}
  end

  def handle_event("unpublish", _params, socket) do
    Events.unpublish_event(socket.assigns.event, scope: socket.assigns.current_scope)
    {:noreply, socket |> put_flash(:info, "Event afpubliceret.") |> reload()}
  end

  # ── Ticket types ───────────────────────────────

  def handle_event("new_ticket", _params, socket) do
    {:noreply,
     socket |> assign(:modal, {:ticket, :new}) |> assign(:ticket_form, blank_ticket_form())}
  end

  def handle_event("edit_ticket", %{"id" => id}, socket) do
    tt = Enum.find(socket.assigns.event.ticket_types, &(&1.id == id))

    form =
      to_form(
        %{
          "name" => tt.name,
          "price_kr" => to_string(div(tt.price_cents, 100)),
          "capacity" => (tt.capacity && to_string(tt.capacity)) || "",
          "description" => tt.description || "",
          "sales_starts_at" => to_input(tt.sales_starts_at),
          "sales_ends_at" => to_input(tt.sales_ends_at),
          "allow_multiple" => to_string(tt.allow_multiple),
          "group_ids" => Enum.map(tt.eligible_groups, & &1.id)
        },
        as: :ticket
      )

    {:noreply, socket |> assign(:modal, {:ticket, tt}) |> assign(:ticket_form, form)}
  end

  def handle_event("save_ticket", %{"ticket" => params}, socket) do
    scope = socket.assigns.current_scope
    group_ids = params["group_ids"] || []

    result =
      case socket.assigns.modal do
        {:ticket, :new} ->
          Events.create_ticket_type(
            Map.put(ticket_attrs(params), :event_id, socket.assigns.event.id),
            scope: scope
          )

        {:ticket, tt} ->
          Events.update_ticket_type(tt, ticket_attrs(params), scope: scope)
      end

    case result do
      {:ok, tt} ->
        Events.set_ticket_type_groups(tt, group_ids, scope: scope)

        {:noreply,
         socket |> assign(:modal, nil) |> put_flash(:info, "Billettype gemt.") |> reload()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Kunne ikke gemme billettypen. Navn er påkrævet.")}
    end
  end

  # ── Add-ons ────────────────────────────────────

  def handle_event("new_addon", _params, socket) do
    {:noreply, socket |> assign(:modal, :addon) |> assign(:addon_form, blank_addon_form())}
  end

  def handle_event("save_addon", %{"addon" => params}, socket) do
    attrs =
      %{
        event_id: socket.assigns.event.id,
        name: params["name"],
        price_cents: kr_to_cents(params["price_kr"]),
        description: nil_if_blank(params["description"]),
        capacity: parse_int(params["capacity"])
      }

    case Events.create_add_on(attrs, scope: socket.assigns.current_scope) do
      {:ok, _} ->
        {:noreply, socket |> assign(:modal, nil) |> put_flash(:info, "Tilkøb gemt.") |> reload()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Kunne ikke gemme tilkøb. Navn er påkrævet.")}
    end
  end

  def handle_event("delete_addon", %{"id" => id}, socket) do
    addon = Enum.find(socket.assigns.add_ons, &(&1.id == id))
    if addon, do: Events.destroy_add_on(addon, scope: socket.assigns.current_scope)
    {:noreply, socket |> put_flash(:info, "Tilkøb slettet.") |> reload()}
  end

  # ── Questions ──────────────────────────────────

  def handle_event("manage_questions", %{"id" => id}, socket) do
    tt = Enum.find(socket.assigns.event.ticket_types, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:modal, {:questions, tt})
     |> assign(:question_form, blank_question_form())
     |> assign(:questions, list_questions(socket, tt.id))}
  end

  def handle_event("save_question", %{"question" => params}, socket) do
    {:questions, tt} = socket.assigns.modal

    attrs = %{
      ticket_type_id: tt.id,
      label: params["label"],
      field_type: String.to_existing_atom(params["field_type"] || "text"),
      options: split_options(params["options"]),
      required: params["required"] == "true"
    }

    case Events.create_ticket_type_question(attrs, scope: socket.assigns.current_scope) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:question_form, blank_question_form())
         |> assign(:questions, list_questions(socket, tt.id))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Kunne ikke gemme spørgsmål. Tekst er påkrævet.")}
    end
  end

  def handle_event("delete_question", %{"id" => id}, socket) do
    {:questions, tt} = socket.assigns.modal
    question = Enum.find(socket.assigns.questions, &(&1.id == id))

    if question,
      do: Events.destroy_ticket_type_question(question, scope: socket.assigns.current_scope)

    {:noreply, assign(socket, :questions, list_questions(socket, tt.id))}
  end

  def handle_event("delete_ticket", %{"id" => id}, socket) do
    tt = Enum.find(socket.assigns.event.ticket_types, &(&1.id == id))
    if tt, do: Events.destroy_ticket_type(tt, scope: socket.assigns.current_scope)
    {:noreply, socket |> put_flash(:info, "Billettype slettet.") |> reload()}
  end

  # ── Registrations ──────────────────────────────

  def handle_event("cancel_reg", %{"id" => id}, socket) do
    reg = Enum.find(socket.assigns.registrations, &(&1.id == id))
    if reg, do: Events.cancel_registration(reg, scope: socket.assigns.current_scope)
    {:noreply, socket |> put_flash(:info, "Tilmelding annulleret.") |> reload()}
  end

  def handle_event("promote_reg", %{"id" => id}, socket) do
    reg = Enum.find(socket.assigns.registrations, &(&1.id == id))
    if reg, do: Events.promote_registration(reg, scope: socket.assigns.current_scope)
    {:noreply, socket |> put_flash(:info, "Flyttet fra venteliste.") |> reload()}
  end

  def handle_event("close", _params, socket), do: {:noreply, assign(socket, :modal, nil)}

  # ── Loading ────────────────────────────────────

  defp reload(socket) do
    {:ok, event} =
      Events.get_event_by_id(socket.assigns.event.id,
        scope: socket.assigns.current_scope,
        load: [ticket_types: [:seats_taken, :seats_left, :eligible_groups]],
        authorize?: false
      )

    socket |> assign(:event, event) |> load_addons() |> load_registrations()
  end

  defp load_groups(socket) do
    case Exhs.Organizations.list_groups(scope: socket.assigns.current_scope) do
      {:ok, groups} -> groups
      _ -> []
    end
  end

  defp load_addons(socket) do
    {:ok, add_ons} =
      Events.list_add_ons_for_event(socket.assigns.event.id,
        tenant: socket.assigns.current_forening.id,
        authorize?: false
      )

    assign(socket, :add_ons, add_ons)
  end

  defp load_registrations(socket) do
    {:ok, regs} =
      Events.list_registrations(
        scope: socket.assigns.current_scope,
        load: [:ticket_type, membership: [:user]],
        authorize?: false
      )

    ticket_ids = MapSet.new(socket.assigns.event.ticket_types, & &1.id)
    regs = Enum.filter(regs, &MapSet.member?(ticket_ids, &1.ticket_type_id))

    socket
    |> assign(:registrations, regs)
    |> assign(:confirmed, Enum.filter(regs, &(&1.status == :confirmed)))
    |> assign(:waitlisted, Enum.filter(regs, &(&1.status == :waitlisted)))
  end

  # ── Params ─────────────────────────────────────

  defp event_attrs(params) do
    %{
      title: params["title"],
      description: nil_if_blank(params["description"]),
      location: nil_if_blank(params["location"]),
      cover_image_url: nil_if_blank(params["cover_image_url"]),
      starts_at: parse_dt(params["starts_at"]),
      ends_at: parse_dt(params["ends_at"]),
      membership_required: params["membership_required"] == "true"
    }
  end

  defp ticket_attrs(params) do
    %{
      name: params["name"],
      price_cents: kr_to_cents(params["price_kr"]),
      capacity: parse_int(params["capacity"]),
      description: nil_if_blank(params["description"]),
      sales_starts_at: parse_dt(params["sales_starts_at"]),
      sales_ends_at: parse_dt(params["sales_ends_at"]),
      allow_multiple: params["allow_multiple"] == "true"
    }
  end

  defp event_form(event) do
    to_form(
      %{
        "title" => event.title,
        "description" => event.description || "",
        "location" => event.location || "",
        "cover_image_url" => event.cover_image_url || "",
        "starts_at" => to_input(event.starts_at),
        "ends_at" => to_input(event.ends_at),
        "membership_required" => to_string(event.membership_required)
      },
      as: :event
    )
  end

  defp blank_ticket_form do
    to_form(
      %{
        "name" => "",
        "price_kr" => "0",
        "capacity" => "",
        "description" => "",
        "sales_starts_at" => "",
        "sales_ends_at" => "",
        "allow_multiple" => "false",
        "group_ids" => []
      },
      as: :ticket
    )
  end

  defp blank_addon_form do
    to_form(%{"name" => "", "price_kr" => "0", "capacity" => "", "description" => ""}, as: :addon)
  end

  defp blank_question_form do
    to_form(%{"label" => "", "field_type" => "text", "options" => "", "required" => "true"},
      as: :question
    )
  end

  defp list_questions(socket, ticket_type_id) do
    case Events.list_ticket_type_questions(ticket_type_id,
           tenant: socket.assigns.current_forening.id,
           authorize?: false
         ) do
      {:ok, qs} -> qs
      _ -> []
    end
  end

  defp split_options(nil), do: []

  defp split_options(str) do
    str |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  defp to_input(nil), do: ""
  defp to_input(dt), do: Calendar.strftime(dt, "%Y-%m-%dT%H:%M")

  defp parse_dt(nil), do: nil
  defp parse_dt(""), do: nil

  defp parse_dt(str) do
    case NaiveDateTime.from_iso8601(str <> ":00") do
      {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
      _ -> nil
    end
  end

  defp kr_to_cents(kr) do
    case Integer.parse(to_string(kr || "0")) do
      {n, _} -> n * 100
      :error -> 0
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil

  defp parse_int(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp nil_if_blank(nil), do: nil
  defp nil_if_blank(v), do: if(String.trim(v) == "", do: nil, else: v)

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
        <.link navigate={~p"/admin/events"} class="text-base-content/50 text-sm hover:underline">
          ← Tilbage til events
        </.link>
      </div>

      <.header>
        {@event.title}
        <:subtitle>{format_datetime(@event.starts_at)}</:subtitle>
        <:actions>
          <.badge variant={if @event.published, do: "success", else: "default"}>
            {if @event.published, do: "Publiceret", else: "Kladde"}
          </.badge>
          <.button :if={@can_write?} phx-click="edit_event" variant="ghost">Rediger</.button>
          <.button :if={@can_write? and not @event.published} phx-click="publish" variant="primary">
            Publicér
          </.button>
          <.button :if={@can_write? and @event.published} phx-click="unpublish" variant="ghost">
            Afpublicér
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 grid gap-6 lg:grid-cols-3">
        <%!-- Details + ticket types --%>
        <div class="space-y-6 lg:col-span-1">
          <.card class="p-5">
            <h3 class="text-base-content font-semibold">Detaljer</h3>
            <dl class="mt-3 space-y-2 text-sm">
              <.detail_row label="Sted" value={@event.location || "—"} />
              <.detail_row label="Start" value={format_datetime(@event.starts_at)} />
              <.detail_row label="Slut" value={format_datetime(@event.ends_at)} />
              <.detail_row
                label="Kræver medlemskab"
                value={if @event.membership_required, do: "Ja", else: "Nej"}
              />
            </dl>
            <p :if={@event.description} class="text-base-content/70 mt-3 text-sm">
              {@event.description}
            </p>
          </.card>

          <.card class="p-5">
            <div class="flex items-center justify-between">
              <h3 class="text-base-content font-semibold">Billettyper</h3>
              <.button :if={@can_write?} phx-click="new_ticket" variant="ghost">
                <.icon name="hero-plus" class="size-4" />
              </.button>
            </div>
            <p :if={@event.ticket_types == []} class="text-base-content/40 mt-2 text-sm">
              Ingen billettyper endnu.
            </p>
            <ul class="divide-base-content/10 mt-2 divide-y">
              <li :for={tt <- @event.ticket_types} class="flex items-center justify-between py-2">
                <div>
                  <p class="text-base-content text-sm font-medium">
                    {tt.name}
                    <span :if={tt.eligible_groups != []} class="badge badge-secondary badge-xs">
                      presale
                    </span>
                  </p>
                  <p class="text-base-content/50 text-xs">
                    {format_amount(tt.price_cents, tt.currency)}
                    <span :if={tt.capacity}>
                      · {tt.seats_taken} solgt · {tt.seats_left} tilbage
                    </span>
                    <span :if={is_nil(tt.capacity)}>· {tt.seats_taken} solgt · ubegrænset</span>
                  </p>
                </div>
                <div :if={@can_write?} class="flex gap-1">
                  <button
                    phx-click="manage_questions"
                    phx-value-id={tt.id}
                    aria-label="Spørgsmål"
                    class="hover:text-base-content text-base-content/40"
                  >
                    <.icon name="hero-question-mark-circle" class="size-4" />
                  </button>
                  <button
                    phx-click="edit_ticket"
                    phx-value-id={tt.id}
                    aria-label="Rediger"
                    class="hover:text-base-content text-base-content/40"
                  >
                    <.icon name="hero-pencil-square" class="size-4" />
                  </button>
                  <button
                    phx-click="delete_ticket"
                    phx-value-id={tt.id}
                    data-confirm={"Slet \"#{tt.name}\"?"}
                    aria-label="Slet"
                    class="hover:text-error text-base-content/40"
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </div>
              </li>
            </ul>
          </.card>

          <.card class="p-5">
            <div class="flex items-center justify-between">
              <h3 class="text-base-content font-semibold">Tilkøb</h3>
              <.button :if={@can_write?} phx-click="new_addon" variant="ghost">
                <.icon name="hero-plus" class="size-4" />
              </.button>
            </div>
            <p :if={@add_ons == []} class="text-base-content/40 mt-2 text-sm">
              Ingen tilkøb endnu.
            </p>
            <ul class="divide-base-content/10 mt-2 divide-y">
              <li :for={a <- @add_ons} class="flex items-center justify-between py-2">
                <div>
                  <p class="text-base-content text-sm font-medium">{a.name}</p>
                  <p class="text-base-content/50 text-xs">
                    {format_amount(a.price_cents, a.currency)}
                  </p>
                </div>
                <button
                  :if={@can_write?}
                  phx-click="delete_addon"
                  phx-value-id={a.id}
                  data-confirm={"Slet \"#{a.name}\"?"}
                  aria-label="Slet"
                  class="hover:text-error text-base-content/40"
                >
                  <.icon name="hero-trash" class="size-4" />
                </button>
              </li>
            </ul>
          </.card>
        </div>

        <%!-- Registrations --%>
        <div class="space-y-6 lg:col-span-2">
          <.card class="p-5">
            <div class="flex items-center justify-between">
              <h3 class="text-base-content font-semibold">
                Tilmeldte ({length(@confirmed)})
              </h3>
              <.link
                href={~p"/admin/export/events/#{@event.id}/registrations.csv"}
                class="btn btn-outline btn-sm"
              >
                <.icon name="hero-arrow-down-tray" class="size-4" /> CSV
              </.link>
            </div>
            <p :if={@confirmed == []} class="text-base-content/40 mt-2 text-sm">
              Ingen bekræftede tilmeldinger.
            </p>
            <.reg_row :for={reg <- @confirmed} reg={reg} can_write={@can_write?} waitlist={false} />
          </.card>

          <.card :if={@waitlisted != []} class="p-5">
            <h3 class="text-base-content font-semibold">Venteliste ({length(@waitlisted)})</h3>
            <.reg_row :for={reg <- @waitlisted} reg={reg} can_write={@can_write?} waitlist={true} />
          </.card>
        </div>
      </div>

      <.modal :if={@modal == :event} id="event-edit-modal" show on_cancel={JS.push("close")}>
        <h3 class="text-base-content text-lg font-semibold">Rediger event</h3>
        <.form for={@event_form} phx-submit="save_event" class="mt-4 space-y-4">
          <.input field={@event_form[:title]} label="Titel" required />
          <.input field={@event_form[:description]} type="textarea" label="Beskrivelse" />
          <.input field={@event_form[:location]} label="Sted" />
          <.input field={@event_form[:cover_image_url]} label="Cover-billede URL" />
          <div class="grid gap-4 sm:grid-cols-2">
            <.input field={@event_form[:starts_at]} type="datetime-local" label="Start" required />
            <.input field={@event_form[:ends_at]} type="datetime-local" label="Slut" />
          </div>
          <.input
            field={@event_form[:membership_required]}
            type="select"
            label="Kræver medlemskab"
            options={[{"Ja", "true"}, {"Nej", "false"}]}
          />
          <div class="flex justify-end gap-2">
            <.button type="button" variant="ghost" phx-click="close">Annuller</.button>
            <.button type="submit" variant="primary">Gem</.button>
          </div>
        </.form>
      </.modal>

      <.modal :if={match?({:ticket, _}, @modal)} id="ticket-modal" show on_cancel={JS.push("close")}>
        <h3 class="text-base-content text-lg font-semibold">Billettype</h3>
        <.form for={@ticket_form} phx-submit="save_ticket" class="mt-4 space-y-4">
          <.input field={@ticket_form[:name]} label="Navn" required />
          <div class="grid gap-4 sm:grid-cols-2">
            <.input field={@ticket_form[:price_kr]} type="number" label="Pris (kr)" />
            <.input field={@ticket_form[:capacity]} type="number" label="Kapacitet (valgfri)" />
          </div>
          <.input field={@ticket_form[:description]} label="Beskrivelse" />
          <div class="grid gap-4 sm:grid-cols-2">
            <.input field={@ticket_form[:sales_starts_at]} type="datetime-local" label="Salg åbner" />
            <.input field={@ticket_form[:sales_ends_at]} type="datetime-local" label="Salg lukker" />
          </div>
          <.input
            field={@ticket_form[:allow_multiple]}
            type="select"
            label="Tillad flere pr. medlem"
            options={[{"Nej", "false"}, {"Ja", "true"}]}
          />
          <.input
            :if={@groups != []}
            field={@ticket_form[:group_ids]}
            type="select"
            multiple
            label="Begræns til grupper (presale)"
            options={Enum.map(@groups, &{&1.name, &1.id})}
          />
          <div class="flex justify-end gap-2">
            <.button type="button" variant="ghost" phx-click="close">Annuller</.button>
            <.button type="submit" variant="primary">Gem</.button>
          </div>
        </.form>
      </.modal>

      <.modal :if={@modal == :addon} id="addon-modal" show on_cancel={JS.push("close")}>
        <h3 class="text-base-content text-lg font-semibold">Tilkøb</h3>
        <.form for={@addon_form} phx-submit="save_addon" class="mt-4 space-y-4">
          <.input field={@addon_form[:name]} label="Navn" required />
          <div class="grid gap-4 sm:grid-cols-2">
            <.input field={@addon_form[:price_kr]} type="number" label="Pris (kr)" />
            <.input field={@addon_form[:capacity]} type="number" label="Kapacitet (valgfri)" />
          </div>
          <.input field={@addon_form[:description]} label="Beskrivelse" />
          <div class="flex justify-end gap-2">
            <.button type="button" variant="ghost" phx-click="close">Annuller</.button>
            <.button type="submit" variant="primary">Gem</.button>
          </div>
        </.form>
      </.modal>

      <.modal
        :if={match?({:questions, _}, @modal)}
        id="questions-modal"
        show
        on_cancel={JS.push("close")}
      >
        <h3 class="text-base-content text-lg font-semibold">Spørgsmål</h3>
        <ul class="divide-base-content/10 mt-3 divide-y">
          <li :for={q <- @questions} class="flex items-center justify-between py-2">
            <div>
              <p class="text-base-content text-sm">{q.label}</p>
              <p class="text-base-content/50 text-xs">
                {q.field_type}{if q.required, do: " · påkrævet"}
              </p>
            </div>
            <button
              phx-click="delete_question"
              phx-value-id={q.id}
              aria-label="Slet"
              class="hover:text-error text-base-content/40"
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </li>
        </ul>
        <.form for={@question_form} phx-submit="save_question" class="mt-4 space-y-3">
          <.input field={@question_form[:label]} label="Spørgsmål" required />
          <.input
            field={@question_form[:field_type]}
            type="select"
            label="Type"
            options={[{"Tekst", "text"}, {"Valg", "select"}, {"Tal", "number"}]}
          />
          <.input field={@question_form[:options]} label="Valgmuligheder (komma-adskilt)" />
          <.input
            field={@question_form[:required]}
            type="select"
            label="Påkrævet"
            options={[{"Ja", "true"}, {"Nej", "false"}]}
          />
          <div class="flex justify-end gap-2">
            <.button type="button" variant="ghost" phx-click="close">Luk</.button>
            <.button type="submit" variant="primary">Tilføj</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.admin>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp detail_row(assigns) do
    ~H"""
    <div class="flex justify-between gap-3">
      <dt class="text-base-content/50">{@label}</dt>
      <dd class="text-base-content text-right font-medium">{@value}</dd>
    </div>
    """
  end

  attr :reg, :map, required: true
  attr :can_write, :boolean, required: true
  attr :waitlist, :boolean, required: true

  defp reg_row(assigns) do
    ~H"""
    <div class="border-base-content/10 flex items-center justify-between gap-3 border-t py-2.5 first:border-t-0">
      <div class="min-w-0">
        <p class="text-base-content truncate text-sm font-medium">{member_name(@reg.membership)}</p>
        <p class="text-base-content/50 truncate text-xs">
          {@reg.ticket_type.name} · {format_date(@reg.registered_at)}
        </p>
      </div>
      <div class="flex shrink-0 items-center gap-2">
        <.badge variant={reg_status_variant(@reg.status)}>{reg_status_label(@reg.status)}</.badge>
        <.button
          :if={@can_write and @waitlist}
          phx-click="promote_reg"
          phx-value-id={@reg.id}
          variant="ghost"
        >
          Bekræft
        </.button>
        <.button
          :if={@can_write}
          phx-click="cancel_reg"
          phx-value-id={@reg.id}
          data-confirm="Annullér tilmeldingen?"
          variant="ghost"
        >
          Annullér
        </.button>
      </div>
    </div>
    """
  end
end
