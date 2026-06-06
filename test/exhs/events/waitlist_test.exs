defmodule Exhs.Events.WaitlistTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Events
  alias Exhs.Events.{Registration, Waitlist, WaitlistPromoter}

  defp waitlist!(forening, ticket_type) do
    user = register_user!()
    membership = invite_member!(forening, user)
    reg = register_for_event!(forening, membership, ticket_type)
    %{user: user, membership: membership, reg: reg}
  end

  describe "standing/3" do
    test "nil when the member is not waitlisted" do
      f = create_forening!()
      e = create_published_event!(f)
      tt = create_ticket_type!(f, e, %{capacity: 5})

      %{membership: m, reg: reg} = waitlist!(f, tt)
      assert reg.status == :confirmed

      assert Waitlist.standing(tt.id, m.id, f.id) == nil
    end

    test "1-based position and total reflect queue order" do
      f = create_forening!()
      e = create_published_event!(f)
      tt = create_ticket_type!(f, e, %{capacity: 1})

      waitlist!(f, tt)
      %{membership: m1} = waitlist!(f, tt)
      %{membership: m2} = waitlist!(f, tt)

      assert Waitlist.standing(tt.id, m1.id, f.id) == %{position: 1, total: 2}
      assert Waitlist.standing(tt.id, m2.id, f.id) == %{position: 2, total: 2}
    end

    test "position advances when an earlier waitlisted member is promoted" do
      f = create_forening!()
      e = create_published_event!(f)
      tt = create_ticket_type!(f, e, %{capacity: 1})

      waitlist!(f, tt)
      %{reg: reg1} = waitlist!(f, tt)
      %{membership: m2} = waitlist!(f, tt)

      assert Waitlist.standing(tt.id, m2.id, f.id) == %{position: 2, total: 2}

      Events.promote_registration!(reg1, tenant: f.id, authorize?: false)

      assert Waitlist.standing(tt.id, m2.id, f.id) == %{position: 1, total: 1}
    end
  end

  describe "tie-breaking" do
    test "equal registered_at is broken by id, matching the promoter" do
      f = create_forening!()
      e = create_published_event!(f)
      tt = create_ticket_type!(f, e, %{price_cents: 0})

      # Seed two waitlisted registrations sharing the exact same registered_at so
      # ordering can only be decided by the id tiebreak.
      ts = DateTime.utc_now(:microsecond)

      [r1, r2] =
        for _ <- 1..2 do
          user = register_user!()
          membership = invite_member!(f, user)

          Ash.Seed.seed!(Registration, %{
            forening_id: f.id,
            ticket_type_id: tt.id,
            membership_id: membership.id,
            status: :waitlisted,
            registered_at: ts
          })
        end

      [low, high] = Enum.sort_by([r1, r2], & &1.id)

      assert Waitlist.position(low, f.id) == 1
      assert Waitlist.position(high, f.id) == 2
      assert Waitlist.size(tt.id, f.id) == 2

      # The promoter must pick exactly the registration shown at position 1.
      job = %Oban.Job{args: %{"ticket_type_id" => tt.id, "tenant" => f.id}}
      assert :ok = WaitlistPromoter.perform(job)

      assert Ash.get!(Registration, low.id, tenant: f.id, authorize?: false).status == :confirmed

      assert Ash.get!(Registration, high.id, tenant: f.id, authorize?: false).status ==
               :waitlisted
    end
  end

  describe "tenant isolation" do
    test "standing only counts waitlisted entries within the tenant" do
      f1 = create_forening!()
      f2 = create_forening!()
      e1 = create_published_event!(f1)
      e2 = create_published_event!(f2)
      tt1 = create_ticket_type!(f1, e1, %{capacity: 1})
      tt2 = create_ticket_type!(f2, e2, %{capacity: 1})

      waitlist!(f1, tt1)
      %{membership: m1} = waitlist!(f1, tt1)

      waitlist!(f2, tt2)
      waitlist!(f2, tt2)
      %{membership: m2} = waitlist!(f2, tt2)

      assert Waitlist.standing(tt1.id, m1.id, f1.id) == %{position: 1, total: 1}
      assert Waitlist.standing(tt2.id, m2.id, f2.id) == %{position: 2, total: 2}
    end
  end
end
