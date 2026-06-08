defmodule ExhsWeb.MemberLive.Profile do
  @moduledoc false
  use ExhsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    form =
      Exhs.Accounts.form_to_update_profile(user, actor: user)
      |> to_form()

    {:ok, assign(socket, form: form, page_title: gettext("Profile"))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _user} ->
        # The saved locale preference is applied by ExhsWeb.Plugs.UserLocale on the
        # next full request; the footer locale switcher provides instant switching.
        {:noreply,
         socket
         |> put_flash(:info, gettext("Profile updated"))
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
        {gettext("Profile")}
        <:subtitle>{gettext("Update your personal details")}</:subtitle>
      </.header>

      <div class="mx-auto mt-8 max-w-2xl">
        <.card class="sm:p-8">
          <.form for={@form} phx-change="validate" phx-submit="submit" class="space-y-6">
            <div class="grid gap-4 sm:grid-cols-2">
              <.input field={@form[:first_name]} label={gettext("First name")} />
              <.input field={@form[:last_name]} label={gettext("Last name")} />
            </div>

            <.input field={@form[:phone]} label={gettext("Phone")} type="tel" />

            <.input field={@form[:address_line_1]} label={gettext("Address")} />
            <.input field={@form[:address_line_2]} label={gettext("Address 2")} />

            <div class="grid gap-4 sm:grid-cols-2">
              <.input field={@form[:postal_code]} label={gettext("Postal code")} />
              <.input field={@form[:city]} label={gettext("City")} />
            </div>

            <.input
              field={@form[:locale]}
              type="select"
              label={gettext("Language")}
              options={[{gettext("Danish"), :da}, {gettext("English"), :en}]}
            />

            <div class="flex justify-end pt-4">
              <.button type="submit" variant="primary">{gettext("Save changes")}</.button>
            </div>
          </.form>
        </.card>

        <.card class="mt-6 p-6 sm:p-8">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 class="text-base-content font-semibold">{gettext("Appearance")}</h3>
              <p class="text-base-content/50 mt-0.5 text-sm">
                {gettext(
                  "Choose light, dark or follow your system setting. Applies across all pages."
                )}
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
