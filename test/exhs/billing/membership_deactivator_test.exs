defmodule Exhs.Billing.MembershipDeactivatorTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Billing.MembershipDeactivator
  alias Exhs.Organizations

  defp setup_billing_member! do
    forening = create_forening!()
    user = register_user!()
    membership = invite_member!(forening, user)
    forening = activate_stripe_connect!(forening)
    membership = set_stripe_customer!(forening, membership)
    %{forening: forening, user: user, membership: membership}
  end

  describe "perform/1" do
    test "deactivates membership with canceled subscription past period end" do
      %{forening: f, membership: m} = setup_billing_member!()

      create_subscription!(f, m, %{
        status: :canceled,
        current_period_end: DateTime.add(DateTime.utc_now(), -1, :day)
      })

      assert :ok = MembershipDeactivator.perform(%Oban.Job{args: %{}})

      refreshed = Ash.get!(Exhs.Organizations.Membership, m.id, tenant: f.id, authorize?: false)
      assert refreshed.status == :inactive
    end

    test "does not deactivate membership with active subscription" do
      %{forening: f, membership: m} = setup_billing_member!()

      create_subscription!(f, m, %{
        status: :active,
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })

      assert :ok = MembershipDeactivator.perform(%Oban.Job{args: %{}})

      refreshed = Ash.get!(Exhs.Organizations.Membership, m.id, tenant: f.id, authorize?: false)
      assert refreshed.status == :active
    end

    test "does not deactivate if period has not ended yet" do
      %{forening: f, membership: m} = setup_billing_member!()

      create_subscription!(f, m, %{
        status: :canceled,
        current_period_end: DateTime.add(DateTime.utc_now(), 5, :day)
      })

      assert :ok = MembershipDeactivator.perform(%Oban.Job{args: %{}})

      refreshed = Ash.get!(Exhs.Organizations.Membership, m.id, tenant: f.id, authorize?: false)
      assert refreshed.status == :active
    end

    test "deactivates past_due subscription past period end" do
      %{forening: f, membership: m} = setup_billing_member!()

      create_subscription!(f, m, %{
        status: :past_due,
        current_period_end: DateTime.add(DateTime.utc_now(), -1, :day)
      })

      assert :ok = MembershipDeactivator.perform(%Oban.Job{args: %{}})

      refreshed = Ash.get!(Exhs.Organizations.Membership, m.id, tenant: f.id, authorize?: false)
      assert refreshed.status == :inactive
    end

    test "skips already-inactive memberships" do
      %{forening: f, membership: m} = setup_billing_member!()

      Organizations.deactivate_member!(m, tenant: f.id, authorize?: false)

      create_subscription!(f, m, %{
        status: :canceled,
        current_period_end: DateTime.add(DateTime.utc_now(), -1, :day)
      })

      assert :ok = MembershipDeactivator.perform(%Oban.Job{args: %{}})
    end
  end
end
