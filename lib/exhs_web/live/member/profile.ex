defmodule ExhsWeb.MemberLive.Profile do
  @moduledoc false
  use ExhsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    form =
      Exhs.Accounts.form_to_update_profile(user, actor: user)
      |> to_form()

    {:ok, assign(socket, form: form, page_title: "Profil")}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profil opdateret")
         |> push_navigate(to: ~p"/profile")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
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
      <.header>
        Profil
        <:subtitle>Opdater dine personlige oplysninger</:subtitle>
      </.header>

      <div class="mx-auto mt-8 max-w-2xl">
        <.card class="sm:p-8">
          <.form for={@form} phx-change="validate" phx-submit="submit" class="space-y-6">
            <div class="grid gap-4 sm:grid-cols-2">
              <.input field={@form[:first_name]} label="Fornavn" />
              <.input field={@form[:last_name]} label="Efternavn" />
            </div>

            <.input field={@form[:phone]} label="Telefon" type="tel" />

            <.input field={@form[:address_line_1]} label="Adresse" />
            <.input field={@form[:address_line_2]} label="Adresse 2" />

            <div class="grid gap-4 sm:grid-cols-2">
              <.input field={@form[:postal_code]} label="Postnummer" />
              <.input field={@form[:city]} label="By" />
            </div>

            <div class="flex justify-end pt-4">
              <.button type="submit" variant="primary">Gem ændringer</.button>
            </div>
          </.form>
        </.card>

        <.card class="mt-6 p-6 sm:p-8">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 class="text-base-content font-semibold">Udseende</h3>
              <p class="text-base-content/50 mt-0.5 text-sm">
                Vælg lyst, mørkt eller følg systemets indstilling. Gælder på tværs af alle sider.
              </p>
            </div>
            <Layouts.theme_toggle />
          </div>
        </.card>
      </div>
    </Layouts.member>
    """
  end
end
