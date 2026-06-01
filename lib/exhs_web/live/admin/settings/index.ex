defmodule ExhsWeb.AdminLive.Settings.Index do
  @moduledoc false
  use ExhsWeb, :live_view

  import ExhsWeb.Labels

  alias Exhs.Organizations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:tab, :general)
     |> assign(:page_title, "Indstillinger")
     |> assign_general_form()
     |> load_admins()}
  end

  @impl true
  def handle_event("tab", %{"tab" => "admins"}, socket) do
    {:noreply, socket |> assign(:tab, :admins) |> load_admins()}
  end

  def handle_event("tab", _params, socket) do
    {:noreply, assign(socket, :tab, :general)}
  end

  def handle_event("save", %{"forening" => params}, socket) do
    forening = socket.assigns.current_forening
    branding = merge_branding(forening.branding || %{}, params)

    attrs = %{
      name: params["name"],
      branding: branding,
      kontingent_amount_cents: kroner_to_cents(params["kontingent_kr"]),
      kontingent_currency: blank_to_default(params["kontingent_currency"], "DKK"),
      kontingent_stripe_price_id: nil_if_blank(params["kontingent_stripe_price_id"])
    }

    case Organizations.update_forening(forening, attrs, scope: socket.assigns.current_scope) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:current_forening, updated)
         |> assign_general_form()
         |> put_flash(:info, "Indstillinger gemt.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Kunne ikke gemme. Navn er påkrævet.")}
    end
  end

  def handle_event("set_role", %{"id" => id, "role" => role}, socket) do
    role = to_role(role)
    membership = Enum.find(all_memberships(socket), &(&1.id == id))

    socket =
      with %{} <- membership,
           {:ok, _} <-
             Organizations.set_member_role(membership, %{role: role},
               scope: socket.assigns.current_scope
             ) do
        put_flash(socket, :info, "Rolle opdateret.")
      else
        _ -> put_flash(socket, :error, "Kunne ikke ændre rolle (mindst én admin kræves).")
      end

    {:noreply, load_admins(socket)}
  end

  @branding_fields ~w(tagline about email_from_name email_reply_to)
  @color_defaults %{"primary_color" => "#6366f1", "accent_color" => "#ec4899"}

  defp assign_general_form(socket) do
    f = socket.assigns.current_forening
    b = f.branding || %{}

    params =
      %{
        "name" => f.name,
        "kontingent_kr" => cents_to_kroner(f.kontingent_amount_cents),
        "kontingent_currency" => f.kontingent_currency || "DKK",
        "kontingent_stripe_price_id" => f.kontingent_stripe_price_id || ""
      }
      |> Map.merge(branding_form_fields(b))

    assign(socket, :form, to_form(params, as: :forening))
  end

  defp branding_form_fields(branding) do
    text = Map.new(@branding_fields, fn key -> {key, branding[key] || ""} end)
    colors = Map.new(@color_defaults, fn {key, default} -> {key, branding[key] || default} end)
    Map.merge(text, colors)
  end

  defp load_admins(socket) do
    {:ok, all} =
      Organizations.list_memberships(
        scope: socket.assigns.current_scope,
        load: [:user],
        authorize?: false
      )

    admins = all |> Enum.filter(&(&1.role in [:admin, :board])) |> sort_members()

    candidates =
      all
      |> Enum.filter(&(&1.role == :member and &1.status == :active))
      |> sort_members()

    socket
    |> assign(:all_memberships, all)
    |> assign(:admins, admins)
    |> assign(:candidates, candidates)
  end

  defp all_memberships(socket), do: socket.assigns[:all_memberships] || []

  defp sort_members(memberships) do
    Enum.sort_by(memberships, &String.downcase(member_name(&1)))
  end

  defp merge_branding(branding, params) do
    Map.merge(branding, %{
      "tagline" => nil_if_blank(params["tagline"]),
      "about" => nil_if_blank(params["about"]),
      "primary_color" => params["primary_color"],
      "accent_color" => params["accent_color"],
      "email_from_name" => nil_if_blank(params["email_from_name"]),
      "email_reply_to" => nil_if_blank(params["email_reply_to"])
    })
  end

  defp cents_to_kroner(nil), do: ""
  defp cents_to_kroner(cents), do: to_string(div(cents, 100))

  defp kroner_to_cents(nil), do: nil
  defp kroner_to_cents(""), do: nil

  defp kroner_to_cents(kr) do
    case Integer.parse(String.trim(kr)) do
      {n, _} -> n * 100
      :error -> nil
    end
  end

  defp blank_to_default(nil, default), do: default
  defp blank_to_default("", default), do: default
  defp blank_to_default(v, _), do: v

  defp nil_if_blank(nil), do: nil
  defp nil_if_blank(v) when is_binary(v), do: if(String.trim(v) == "", do: nil, else: v)

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
        Indstillinger
        <:subtitle>Administrer din forenings profil og administratorer</:subtitle>
      </.header>

      <div role="tablist" class="tabs tabs-bordered mt-6">
        <button
          role="tab"
          class={["tab", @tab == :general && "tab-active"]}
          phx-click="tab"
          phx-value-tab="general"
        >
          Generelt
        </button>
        <button
          role="tab"
          class={["tab", @tab == :admins && "tab-active"]}
          phx-click="tab"
          phx-value-tab="admins"
        >
          Administratorer
        </button>
      </div>

      <div :if={@tab == :general} class="mt-6">
        <.form for={@form} phx-submit="save" class="space-y-8">
          <.card class="space-y-4 p-5">
            <h3 class="text-base-content font-semibold">Profil</h3>
            <.input field={@form[:name]} label="Navn" required disabled={!@can_write?} />
            <.input field={@form[:tagline]} label="Slogan" disabled={!@can_write?} />
            <.input
              field={@form[:about]}
              type="textarea"
              label="Om foreningen"
              disabled={!@can_write?}
            />
            <div class="grid gap-4 sm:grid-cols-2">
              <.input
                field={@form[:primary_color]}
                type="color"
                label="Primærfarve"
                disabled={!@can_write?}
              />
              <.input
                field={@form[:accent_color]}
                type="color"
                label="Accentfarve"
                disabled={!@can_write?}
              />
            </div>
          </.card>

          <.card class="space-y-4 p-5">
            <h3 class="text-base-content font-semibold">Email</h3>
            <.input field={@form[:email_from_name]} label="Afsendernavn" disabled={!@can_write?} />
            <.input
              field={@form[:email_reply_to]}
              type="email"
              label="Svar-til adresse"
              disabled={!@can_write?}
            />
          </.card>

          <.card class="space-y-4 p-5">
            <h3 class="text-base-content font-semibold">Kontingent</h3>
            <div class="grid gap-4 sm:grid-cols-2">
              <.input
                field={@form[:kontingent_kr]}
                type="number"
                label="Beløb (kr)"
                disabled={!@can_write?}
              />
              <.input field={@form[:kontingent_currency]} label="Valuta" disabled={!@can_write?} />
            </div>
            <.input
              field={@form[:kontingent_stripe_price_id]}
              label="Stripe Price ID"
              disabled={!@can_write?}
            />
          </.card>

          <div :if={@can_write?} class="flex justify-end">
            <.button type="submit" variant="primary">Gem ændringer</.button>
          </div>
          <p :if={!@can_write?} class="text-base-content/50 text-sm">
            Du har skrivebeskyttet adgang (bestyrelse).
          </p>
        </.form>
      </div>

      <div :if={@tab == :admins} class="mt-6 space-y-6">
        <.card class="p-5">
          <h3 class="text-base-content mb-4 font-semibold">Nuværende administratorer</h3>
          <div :if={@admins == []}>
            <.empty_state icon="hero-shield-check" title="Ingen administratorer">
              Forfrem et medlem til admin eller bestyrelse.
            </.empty_state>
          </div>
          <ul :if={@admins != []} class="divide-base-content/10 divide-y">
            <li :for={m <- @admins} class="flex items-center justify-between gap-3 py-3">
              <div class="min-w-0">
                <p class="text-base-content truncate font-medium">{member_name(m)}</p>
                <p class="text-base-content/50 truncate text-sm">{m.user.email}</p>
              </div>
              <div class="flex shrink-0 items-center gap-2">
                <.badge variant={role_variant(m.role)}>{role_label(m.role)}</.badge>
                <select
                  :if={@can_write?}
                  class="select select-bordered select-sm"
                  phx-change="set_role"
                  phx-value-id={m.id}
                  name="role"
                >
                  <option value="admin" selected={m.role == :admin}>Admin</option>
                  <option value="board" selected={m.role == :board}>Bestyrelse</option>
                  <option value="member">Fjern (gør til medlem)</option>
                </select>
              </div>
            </li>
          </ul>
        </.card>

        <.card :if={@can_write?} class="p-5">
          <h3 class="text-base-content mb-1 font-semibold">Forfrem medlem</h3>
          <p class="text-base-content/50 mb-4 text-sm">
            Giv et aktivt medlem admin- eller bestyrelsesrolle.
          </p>
          <div :if={@candidates == []} class="text-base-content/50 text-sm">
            Ingen menige medlemmer at forfremme.
          </div>
          <form :if={@candidates != []} phx-submit="set_role" class="flex flex-wrap items-end gap-3">
            <div class="grow">
              <label class="text-base-content/70 mb-1 block text-sm">Medlem</label>
              <select name="id" class="select select-bordered w-full">
                <option :for={m <- @candidates} value={m.id}>
                  {member_name(m)} ({m.user.email})
                </option>
              </select>
            </div>
            <div>
              <label class="text-base-content/70 mb-1 block text-sm">Rolle</label>
              <select name="role" class="select select-bordered">
                <option value="admin">Admin</option>
                <option value="board">Bestyrelse</option>
              </select>
            </div>
            <.button type="submit" variant="primary">Forfrem</.button>
          </form>
        </.card>
      </div>
    </Layouts.admin>
    """
  end
end
