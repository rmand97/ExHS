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

  def scope(user, forening) do
    %Exhs.Scope{actor: user, tenant: forening.id}
  end
end
