defmodule ExhsWeb.AdminLive.Groups.Index do
  @moduledoc false
  use ExhsWeb, :live_view

  alias Exhs.Organizations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:editing, nil)
     |> assign(:form, blank_form())
     |> assign(:page_title, "Grupper")
     |> load_groups()}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:noreply, socket |> assign(:editing, :new) |> assign(:form, blank_form())}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    group = Enum.find(socket.assigns.groups, &(&1.id == id))

    form =
      to_form(
        %{
          "name" => group.name,
          "description" => group.description || "",
          "color" => group.color || "#3b82f6"
        },
        as: :group
      )

    {:noreply, socket |> assign(:editing, group) |> assign(:form, form)}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, :editing, nil)}
  end

  def handle_event("save", %{"group" => params}, socket) do
    attrs = %{
      name: params["name"],
      description: params["description"],
      color: params["color"]
    }

    result =
      case socket.assigns.editing do
        :new -> Organizations.create_group(attrs, scope: socket.assigns.current_scope)
        group -> Organizations.update_group(group, attrs, scope: socket.assigns.current_scope)
      end

    case result do
      {:ok, _group} ->
        {:noreply,
         socket
         |> assign(:editing, nil)
         |> put_flash(:info, "Gruppe gemt.")
         |> load_groups()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Kunne ikke gemme gruppen. Navn er påkrævet.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    group = Enum.find(socket.assigns.groups, &(&1.id == id))

    if group do
      Organizations.destroy_group(group, scope: socket.assigns.current_scope)
    end

    {:noreply, socket |> put_flash(:info, "Gruppe slettet.") |> load_groups()}
  end

  defp load_groups(socket) do
    {:ok, groups} =
      Organizations.list_groups(scope: socket.assigns.current_scope, authorize?: false)

    assign(socket, :groups, groups)
  end

  defp blank_form do
    to_form(%{"name" => "", "description" => "", "color" => "#3b82f6"}, as: :group)
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
        Grupper
        <:subtitle>{length(@groups)} grupper</:subtitle>
        <:actions>
          <.button :if={@can_write?} phx-click="new" variant="primary">
            <.icon name="hero-plus" class="size-4" /> Ny gruppe
          </.button>
        </:actions>
      </.header>

      <div :if={@groups == []} class="mt-8">
        <.empty_state icon="hero-tag" title="Ingen grupper endnu">
          Opret en gruppe for at organisere dine medlemmer.
        </.empty_state>
      </div>

      <div :if={@groups != []} class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <.card :for={g <- @groups} class="p-5">
          <div class="flex items-start justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <span class="size-4 rounded-full" style={"background-color: #{g.color || "#3b82f6"}"} />
              <div>
                <h3 class="text-base-content font-semibold">{g.name}</h3>
                <p :if={g.description} class="text-base-content/50 mt-0.5 text-sm">
                  {g.description}
                </p>
              </div>
            </div>
            <div :if={@can_write?} class="flex shrink-0 gap-1">
              <button
                phx-click="edit"
                phx-value-id={g.id}
                class="hover:text-base-content text-base-content/40"
                aria-label="Rediger"
              >
                <.icon name="hero-pencil-square" class="size-4" />
              </button>
              <button
                phx-click="delete"
                phx-value-id={g.id}
                data-confirm={"Slet gruppen \"#{g.name}\"?"}
                class="hover:text-error text-base-content/40"
                aria-label="Slet"
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </div>
          </div>
        </.card>
      </div>

      <.modal :if={@editing} id="group-modal" show on_cancel={JS.push("cancel")}>
        <h3 class="text-base-content text-lg font-semibold">
          {if @editing == :new, do: "Ny gruppe", else: "Rediger gruppe"}
        </h3>
        <.form for={@form} phx-submit="save" class="mt-4 space-y-4">
          <.input field={@form[:name]} label="Navn" required />
          <.input field={@form[:description]} label="Beskrivelse" />
          <.input field={@form[:color]} type="color" label="Farve" />
          <div class="flex justify-end gap-2">
            <.button type="button" variant="ghost" phx-click="cancel">Annuller</.button>
            <.button type="submit" variant="primary">Gem</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.admin>
    """
  end
end
