defmodule Exhs.Events.EligibilityTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Events.Eligibility

  defp setup! do
    forening = create_forening!()
    event = create_published_event!(forening, %{membership_required: false})
    user = register_user!()
    invite_member!(forening, user, :member)
    membership = membership_for!(forening, user)
    %{f: forening, e: event, m: membership}
  end

  defp other_member!(forening) do
    user = register_user!()
    invite_member!(forening, user, :member)
    membership_for!(forening, user)
  end

  describe "status/5 with precomputed group ids" do
    test "ungated ticket is available" do
      %{f: f, e: e, m: m} = setup!()
      tt = create_ticket_type!(f, e, %{capacity: 5})

      assert Eligibility.status(tt, e, m, f.id, []) == :available
    end

    test "gated ticket: member in an eligible group is available" do
      %{f: f, e: e, m: m} = setup!()
      tt = create_ticket_type!(f, e)
      group = create_group!(f)
      gate_ticket_type!(f, tt, [group])
      add_to_group!(f, m, group)

      assert Eligibility.status(tt, e, m, f.id, [group.id]) == :available
    end

    test "gated ticket: member not in any group is ineligible" do
      %{f: f, e: e, m: m} = setup!()
      tt = create_ticket_type!(f, e)
      group = create_group!(f)
      gate_ticket_type!(f, tt, [group])

      assert Eligibility.status(tt, e, m, f.id, [group.id]) == :ineligible
    end

    test "gated ticket with no membership is ineligible" do
      %{f: f, e: e} = setup!()
      tt = create_ticket_type!(f, e)
      group = create_group!(f)

      assert Eligibility.status(tt, e, nil, f.id, [group.id]) == :ineligible
    end

    test "a full ticket type is :sold_out" do
      %{f: f, e: e, m: m} = setup!()
      tt = create_ticket_type!(f, e, %{capacity: 1, price_cents: 0})
      register_for_event!(f, m, tt)

      assert Eligibility.status(tt, e, other_member!(f), f.id, []) == :sold_out
    end

    test "the window check takes precedence over gating" do
      %{f: f, e: e, m: m} = setup!()
      future = DateTime.add(DateTime.utc_now(), 1, :day)
      tt = create_ticket_type!(f, e, %{sales_starts_at: future})
      group = create_group!(f)
      gate_ticket_type!(f, tt, [group])

      # Not open yet wins even though the member is also ineligible by group.
      assert Eligibility.status(tt, e, m, f.id, [group.id]) == :not_open
    end
  end

  describe "status/4 delegation" do
    test "fetches gating itself and agrees with status/5" do
      %{f: f, e: e, m: m} = setup!()
      tt = create_ticket_type!(f, e)
      group = create_group!(f)
      gate_ticket_type!(f, tt, [group])

      assert Eligibility.status(tt, e, m, f.id) == :ineligible
      assert Eligibility.status(tt, e, m, f.id) == Eligibility.status(tt, e, m, f.id, [group.id])
    end
  end

  describe "sales window" do
    test "before sales_starts_at is :not_open" do
      %{f: f, e: e, m: m} = setup!()
      future = DateTime.add(DateTime.utc_now(), 1, :day)
      tt = create_ticket_type!(f, e, %{sales_starts_at: future})

      assert Eligibility.status(tt, e, m, f.id, []) == :not_open
    end

    test "after sales_ends_at is :closed" do
      %{f: f, e: e, m: m} = setup!()
      past = DateTime.add(DateTime.utc_now(), -1, :day)
      tt = create_ticket_type!(f, e, %{sales_ends_at: past})

      assert Eligibility.status(tt, e, m, f.id, []) == :closed
    end
  end
end
