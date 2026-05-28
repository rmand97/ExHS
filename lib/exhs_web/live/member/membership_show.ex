defmodule ExhsWeb.MemberLive.MembershipShow do
  @moduledoc false
  use ExhsWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user

    case find_membership(user, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Medlemskab ikke fundet")
         |> redirect(to: ~p"/dashboard")}

      membership ->
        subscription = find_subscription(user, membership)

        {:ok,
         assign(socket,
           membership: membership,
           subscription: subscription,
           page_title: membership.forening.name
         )}
    end
  end

  @impl true
  def handle_event("leave", _params, socket) do
    membership = socket.assigns.membership

    case Exhs.Organizations.leave_forening(membership,
           tenant: membership.forening_id,
           actor: socket.assigns.current_user
         ) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Du har forladt #{membership.forening.name}")
         |> push_navigate(to: ~p"/dashboard")}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Kunne ikke forlade foreningen. Er du den sidste admin?")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.member flash={@flash} current_user={@current_user}>
      <.header>
        {@membership.forening.name}
        <:subtitle>Medlemskab og kontingent</:subtitle>
        <:actions>
          <a href={forening_url(@membership.forening)} class="btn btn-ghost btn-sm">
            Besøg forening →
          </a>
        </:actions>
      </.header>

      <div class="mt-8 grid gap-6 lg:grid-cols-2">
        <.card class="p-6">
          <h2 class="text-base-content mb-4 font-semibold">Medlemskab</h2>
          <.list>
            <:item title="Rolle">
              <.badge variant={role_variant(@membership.role)}>
                {role_label(@membership.role)}
              </.badge>
            </:item>
            <:item title="Status">
              <.badge variant={status_variant(@membership.status)}>
                {status_label(@membership.status)}
              </.badge>
            </:item>
            <:item title="Medlem siden">{format_date(@membership.joined_at)}</:item>
          </.list>

          <div class="border-base-content/5 mt-6 border-t pt-4">
            <button
              phx-click="leave"
              data-confirm="Er du sikker på, at du vil forlade #{@membership.forening.name}?"
              class="btn btn-ghost btn-sm text-error"
            >
              <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> Forlad forening
            </button>
          </div>
        </.card>

        <.card class="p-6">
          <h2 class="text-base-content mb-4 font-semibold">Kontingent</h2>

          <div :if={@subscription}>
            <.list>
              <:item title="Status">
                <.badge variant={sub_status_variant(@subscription.status)}>
                  {sub_status_label(@subscription.status)}
                </.badge>
              </:item>
              <:item title="Periode">
                {format_date(@subscription.current_period_start)} — {format_date(
                  @subscription.current_period_end
                )}
              </:item>
              <:item :if={@subscription.cancel_at_period_end} title="Opsigelse">
                <span class="text-warning">Opsagt — udløber ved periodens slut</span>
              </:item>
            </.list>
          </div>

          <div :if={!@subscription}>
            <p class="text-base-content/50 text-sm">
              Ingen aktiv kontingentabonnement.
            </p>
          </div>
        </.card>
      </div>
    </Layouts.member>
    """
  end

  defp find_membership(user, id) do
    case Exhs.Organizations.list_my_memberships(actor: user) do
      {:ok, memberships} -> Enum.find(memberships, &(&1.id == id))
      _ -> nil
    end
  end

  defp find_subscription(user, membership) do
    case Exhs.Billing.list_my_subscriptions(actor: user) do
      {:ok, subs} -> Enum.find(subs, &(&1.membership_id == membership.id))
      _ -> nil
    end
  end

  defp role_variant(:admin), do: "error"
  defp role_variant(:board), do: "warning"
  defp role_variant(_), do: "default"

  defp role_label(:admin), do: "Admin"
  defp role_label(:board), do: "Bestyrelse"
  defp role_label(:member), do: "Medlem"

  defp status_variant(:active), do: "success"
  defp status_variant(:inactive), do: "default"

  defp status_label(:active), do: "Aktiv"
  defp status_label(:inactive), do: "Inaktiv"

  defp sub_status_variant(:active), do: "success"
  defp sub_status_variant(:trialing), do: "primary"
  defp sub_status_variant(:past_due), do: "warning"
  defp sub_status_variant(:canceled), do: "error"
  defp sub_status_variant(_), do: "default"

  defp sub_status_label(:active), do: "Aktiv"
  defp sub_status_label(:trialing), do: "Prøveperiode"
  defp sub_status_label(:past_due), do: "Forfalden"
  defp sub_status_label(:canceled), do: "Opsagt"
  defp sub_status_label(:incomplete), do: "Ufuldstændig"

  defp format_date(nil), do: "—"
  defp format_date(dt), do: Calendar.strftime(dt, "%d. %b %Y")

  defp forening_url(forening) do
    base = Application.get_env(:exhs, :base_host, "exhs.dk")
    "//#{forening.subdomain}.#{base}/"
  end
end
