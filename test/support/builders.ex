defmodule Exhs.Test.Builders do
  @moduledoc false

  alias Exhs.Accounts
  alias Exhs.Organizations

  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive])}"

  def register_user!(opts \\ []) do
    email = Keyword.get(opts, :email, "#{unique("user")}@example.com")

    user =
      Accounts.register_with_password!(email, "password123", "password123", authorize?: false)

    if opts[:superadmin] do
      Ash.Changeset.for_update(user, :update_profile, %{}, authorize?: false)
      |> Ash.Changeset.force_change_attribute(:is_superadmin, true)
      |> Ash.update!(authorize?: false)
    else
      user
    end
  end

  def create_forening!(attrs \\ %{}) do
    defaults = %{
      name: "Forening #{unique("f")}",
      slug: unique("slug"),
      subdomain: unique("sub")
    }

    Organizations.create_forening!(Map.merge(defaults, attrs), authorize?: false)
  end

  def invite_member!(forening, user, role \\ :member) do
    Organizations.invite_member!(user.id, %{role: role},
      tenant: forening.id,
      authorize?: false
    )
  end

  def join_forening!(forening, user) do
    Organizations.join_forening!(%{}, tenant: forening.id, actor: user)
  end

  def create_group!(forening, attrs \\ %{}) do
    defaults = %{name: "Group #{unique("g")}", color: "#ff0000"}

    Organizations.create_group!(
      Map.merge(defaults, attrs),
      tenant: forening.id,
      authorize?: false
    )
  end

  def membership_for!(forening, user) do
    Organizations.list_memberships!(tenant: forening.id, authorize?: false)
    |> Enum.find(&(&1.user_id == user.id))
  end

  def activate_stripe_connect!(forening) do
    Organizations.set_forening_stripe_account!(
      forening,
      %{
        stripe_account_id: "acct_#{unique("test")}",
        stripe_account_status: :active
      },
      authorize?: false
    )
  end

  def set_stripe_customer!(forening, membership) do
    Organizations.set_membership_stripe_customer!(
      membership,
      %{stripe_customer_id: "cus_#{unique("test")}"},
      tenant: forening.id,
      authorize?: false
    )
  end

  def create_event!(forening, attrs \\ %{}) do
    defaults = %{
      title: "Event #{unique("ev")}",
      starts_at: DateTime.add(DateTime.utc_now(), 7, :day),
      location: "Test Location"
    }

    Exhs.Events.create_event!(Map.merge(defaults, attrs),
      tenant: forening.id,
      authorize?: false
    )
  end

  def publish_event!(event) do
    Exhs.Events.publish_event!(event, authorize?: false)
  end

  def create_published_event!(forening, attrs \\ %{}) do
    forening |> create_event!(attrs) |> publish_event!()
  end

  def create_ticket_type!(forening, event, attrs \\ %{}) do
    defaults = %{
      event_id: event.id,
      name: "Ticket #{unique("tt")}",
      price_cents: 0
    }

    Exhs.Events.create_ticket_type!(Map.merge(defaults, attrs),
      tenant: forening.id,
      authorize?: false
    )
  end

  def register_for_event!(forening, membership, ticket_type) do
    Exhs.Events.register_for_event!(
      %{ticket_type_id: ticket_type.id, membership_id: membership.id},
      tenant: forening.id,
      authorize?: false
    )
  end

  def create_add_on!(forening, event, attrs \\ %{}) do
    defaults = %{event_id: event.id, name: "AddOn #{unique("ao")}", price_cents: 5_000}

    Exhs.Events.create_add_on!(Map.merge(defaults, attrs),
      tenant: forening.id,
      authorize?: false
    )
  end

  def create_question!(forening, ticket_type, attrs \\ %{}) do
    defaults = %{
      ticket_type_id: ticket_type.id,
      label: "Question #{unique("q")}",
      field_type: :text,
      required: true
    }

    Exhs.Events.create_ticket_type_question!(Map.merge(defaults, attrs),
      tenant: forening.id,
      authorize?: false
    )
  end

  def gate_ticket_type!(forening, ticket_type, groups) do
    Exhs.Events.set_ticket_type_groups!(
      ticket_type,
      Enum.map(groups, & &1.id),
      tenant: forening.id,
      authorize?: false
    )
  end

  def add_to_group!(forening, membership, group) do
    Exhs.Organizations.add_member_to_group!(
      %{membership_id: membership.id, group_id: group.id},
      tenant: forening.id,
      authorize?: false
    )
  end

  def create_order!(forening, membership, event, attrs \\ %{}) do
    defaults = %{membership_id: membership.id, event_id: event.id}

    Exhs.Events.create_order!(Map.merge(defaults, attrs),
      tenant: forening.id,
      authorize?: false
    )
  end

  def add_ticket_item!(forening, order, ticket_type, attrs \\ %{}) do
    defaults = %{order_id: order.id, item_type: :ticket, ticket_type_id: ticket_type.id}

    Exhs.Events.add_order_item!(Map.merge(defaults, attrs),
      tenant: forening.id,
      authorize?: false
    )
  end

  def add_addon_item!(forening, order, add_on, attrs \\ %{}) do
    defaults = %{order_id: order.id, item_type: :addon, add_on_id: add_on.id}

    Exhs.Events.add_order_item!(Map.merge(defaults, attrs),
      tenant: forening.id,
      authorize?: false
    )
  end

  def create_subscription!(forening, membership, attrs \\ %{}) do
    defaults = %{
      membership_id: membership.id,
      stripe_subscription_id: "sub_#{unique("sub")}",
      stripe_customer_id: membership.stripe_customer_id || "cus_#{unique("cus")}",
      status: :active,
      current_period_start: DateTime.utc_now(),
      current_period_end: DateTime.add(DateTime.utc_now(), 30, :day),
      cancel_at_period_end: false
    }

    Exhs.Billing.create_subscription!(Map.merge(defaults, attrs),
      tenant: forening.id,
      authorize?: false
    )
  end

  def record_payment!(forening, membership, attrs \\ %{}) do
    defaults = %{
      payable_type: :subscription,
      payable_id: membership.id,
      amount_cents: 50_000,
      currency: "DKK",
      status: :succeeded,
      stripe_payment_intent_id: "pi_#{unique("pi")}",
      stripe_charge_id: "ch_#{unique("ch")}",
      description: "Kontingent",
      paid_at: DateTime.utc_now()
    }

    Exhs.Billing.record_payment!(Map.merge(defaults, attrs),
      tenant: forening.id,
      authorize?: false
    )
  end

  def scope(user, forening) do
    %Exhs.Scope{actor: user, tenant: forening.id}
  end
end
