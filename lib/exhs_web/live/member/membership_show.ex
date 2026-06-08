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
         |> put_flash(:error, gettext("Membership not found"))
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
           tenant: membership.forening.id,
           actor: socket.assigns.current_user
         ) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("You have left %{name}", name: membership.forening.name))
         |> push_navigate(to: ~p"/dashboard")}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Could not leave the association. Are you the last admin?")
         )}
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
        {@membership.forening.name}
        <:subtitle>{gettext("Membership and membership fee")}</:subtitle>
        <:actions>
          <.link href={forening_url(@membership.forening)} class="btn btn-ghost btn-sm">
            {gettext("Visit association")} →
          </.link>
        </:actions>
      </.header>

      <div class="mt-8 grid gap-6 lg:grid-cols-2">
        <.card class="p-6">
          <h2 class="text-base-content mb-4 font-semibold">{gettext("Membership")}</h2>
          <.list>
            <:item title={gettext("Role")}>
              <.badge variant={role_variant(@membership.role)}>
                {role_label(@membership.role)}
              </.badge>
            </:item>
            <:item title={gettext("Status")}>
              <.badge variant={status_variant(@membership.status)}>
                {status_label(@membership.status)}
              </.badge>
            </:item>
            <:item title={gettext("Member since")}>{format_date(@membership.joined_at)}</:item>
          </.list>

          <div class="border-base-content/5 mt-6 border-t pt-4">
            <button
              phx-click="leave"
              data-confirm={
                gettext("Are you sure you want to leave %{name}?", name: @membership.forening.name)
              }
              class="btn btn-ghost btn-sm text-error"
            >
              <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> {gettext(
                "Leave association"
              )}
            </button>
          </div>
        </.card>

        <.card class="p-6">
          <h2 class="text-base-content mb-4 font-semibold">{gettext("Membership fee")}</h2>

          <.list>
            <:item title={gettext("Type")}>
              <.badge variant={kontingent_type_variant(@membership.forening)}>
                {kontingent_type_label(@membership.forening)}
              </.badge>
            </:item>
            <:item
              :if={(@membership.forening.kontingent_amount_cents || 0) > 0}
              title={gettext("Amount")}
            >
              {format_kontingent(@membership.forening)}
            </:item>
          </.list>

          <div :if={@subscription} class="mt-4">
            <.list>
              <:item title={gettext("Subscription")}>
                <.badge variant={sub_status_variant(@subscription.status)}>
                  {sub_status_label(@subscription.status)}
                </.badge>
              </:item>
              <:item title={gettext("Period")}>
                {format_date(@subscription.current_period_start)} — {format_date(
                  @subscription.current_period_end
                )}
              </:item>
              <:item :if={@subscription.cancel_at_period_end} title={gettext("Cancellation")}>
                <span class="text-warning">{gettext("Cancelled — expires at end of period")}</span>
              </:item>
            </.list>
          </div>

          <div
            :if={!@subscription && @membership.forening.kontingent_stripe_price_id != nil}
            class="mt-4"
          >
            <p class="text-base-content/50 text-sm">
              {gettext("No active subscription.")}
            </p>
          </div>
        </.card>
      </div>
    </Layouts.member>
    """
  end

  defp find_membership(user, id) do
    case Exhs.Organizations.get_my_membership(id, actor: user) do
      {:ok, membership} ->
        Ash.Resource.put_metadata(membership, :tenant, membership.forening.id)

      _ ->
        nil
    end
  end

  defp find_subscription(user, membership) do
    case Exhs.Billing.list_my_subscriptions(actor: user) do
      {:ok, subs} -> Enum.find(subs, &(&1.membership_id == membership.id))
      _ -> nil
    end
  end

  defp kontingent_type_label(%{kontingent_stripe_price_id: id}) when is_binary(id) and id != "",
    do: gettext("Recurring subscription")

  defp kontingent_type_label(%{kontingent_amount_cents: cents})
       when is_integer(cents) and cents > 0,
       do: gettext("One-time payment")

  defp kontingent_type_label(_), do: gettext("Free")

  defp kontingent_type_variant(%{kontingent_stripe_price_id: id}) when is_binary(id) and id != "",
    do: "primary"

  defp kontingent_type_variant(%{kontingent_amount_cents: cents})
       when is_integer(cents) and cents > 0,
       do: "warning"

  defp kontingent_type_variant(_), do: "success"

  defp sub_status_variant(:active), do: "success"
  defp sub_status_variant(:trialing), do: "primary"
  defp sub_status_variant(:past_due), do: "warning"
  defp sub_status_variant(:canceled), do: "error"
  defp sub_status_variant(_), do: "default"

  defp sub_status_label(:active), do: gettext("Active")
  defp sub_status_label(:trialing), do: gettext("Trial period")
  defp sub_status_label(:past_due), do: gettext("Past due")
  defp sub_status_label(:canceled), do: gettext("Cancelled")
  defp sub_status_label(:incomplete), do: gettext("Incomplete")
end
