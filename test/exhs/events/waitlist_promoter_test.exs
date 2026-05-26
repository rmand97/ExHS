defmodule Exhs.Events.WaitlistPromoterTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Events
  alias Exhs.Events.WaitlistPromoter

  defp setup_event! do
    forening = create_forening!()
    admin = register_user!()
    invite_member!(forening, admin, :admin)
    admin_scope = scope(admin, forening)

    {:ok, event} =
      Events.create_event(
        %{title: "Test", starts_at: DateTime.add(DateTime.utc_now(), 7, :day), location: "Here"},
        tenant: forening.id,
        scope: admin_scope
      )

    {:ok, event} = Events.publish_event(event, scope: admin_scope)
    %{forening: forening, event: event, admin_scope: admin_scope}
  end

  defp create_limited_ticket!(forening, event, admin_scope, capacity) do
    {:ok, tt} =
      Events.create_ticket_type(
        %{event_id: event.id, name: "Cap#{capacity}", price_cents: 0, capacity: capacity},
        tenant: forening.id,
        scope: admin_scope
      )

    tt
  end

  defp register!(forening, ticket_type) do
    user = register_user!()
    membership = invite_member!(forening, user)

    {:ok, reg} =
      Events.register_for_event(
        %{ticket_type_id: ticket_type.id, membership_id: membership.id},
        tenant: forening.id,
        scope: scope(user, forening)
      )

    {reg, user}
  end

  describe "perform/1" do
    test "promotes first waitlisted registration" do
      %{forening: f, event: e, admin_scope: s} = setup_event!()
      tt = create_limited_ticket!(f, e, s, 1)

      {_reg1, _user1} = register!(f, tt)
      {reg2, _user2} = register!(f, tt)
      assert reg2.status == :waitlisted

      job = %Oban.Job{args: %{"ticket_type_id" => tt.id, "tenant" => f.id}}
      assert :ok = WaitlistPromoter.perform(job)

      promoted = Ash.get!(Exhs.Events.Registration, reg2.id, tenant: f.id, authorize?: false)
      assert promoted.status == :confirmed
    end

    test "no-op when no waitlisted registrations exist" do
      %{forening: f, event: e, admin_scope: s} = setup_event!()
      tt = create_limited_ticket!(f, e, s, 10)

      {reg1, _user1} = register!(f, tt)
      assert reg1.status == :confirmed

      job = %Oban.Job{args: %{"ticket_type_id" => tt.id, "tenant" => f.id}}
      assert :ok = WaitlistPromoter.perform(job)
    end

    test "no-op with nonexistent ticket_type_id" do
      forening = create_forening!()
      fake_id = Ash.UUIDv7.generate()

      job = %Oban.Job{args: %{"ticket_type_id" => fake_id, "tenant" => forening.id}}
      assert :ok = WaitlistPromoter.perform(job)
    end
  end
end
