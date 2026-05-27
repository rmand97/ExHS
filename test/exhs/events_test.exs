defmodule Exhs.EventsTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Events

  defp event_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        title: "Test Event",
        starts_at: DateTime.add(DateTime.utc_now(), 7, :day),
        location: "Somewhere"
      },
      overrides
    )
  end

  describe "event CRUD" do
    test "admin creates and publishes an event" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      scope = scope(admin, forening)

      {:ok, event} =
        Events.create_event(event_attrs(), tenant: forening.id, scope: scope)

      refute event.published

      {:ok, event} = Events.publish_event(event, scope: scope)
      assert event.published
    end

    test "regular member cannot create events" do
      forening = create_forening!()
      user = register_user!()
      invite_member!(forening, user)
      scope = scope(user, forening)

      assert {:error, %Ash.Error.Forbidden{}} =
               Events.create_event(event_attrs(), tenant: forening.id, scope: scope)
    end

    test "list_upcoming_events returns only future published events" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      scope = scope(admin, forening)

      {:ok, published} =
        Events.create_event(event_attrs(), tenant: forening.id, scope: scope)

      {:ok, published} = Events.publish_event(published, scope: scope)

      {:ok, _draft} =
        Events.create_event(
          event_attrs(%{title: "Draft"}),
          tenant: forening.id,
          scope: scope
        )

      upcoming = Events.list_upcoming_events!(scope: scope)
      assert length(upcoming) == 1
      assert hd(upcoming).id == published.id
    end
  end

  describe "ticket types" do
    test "admin creates ticket types for an event" do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      scope = scope(admin, forening)

      {:ok, event} =
        Events.create_event(event_attrs(), tenant: forening.id, scope: scope)

      {:ok, free_tt} =
        Events.create_ticket_type(
          %{event_id: event.id, name: "Free", price_cents: 0},
          tenant: forening.id,
          scope: scope
        )

      {:ok, paid_tt} =
        Events.create_ticket_type(
          %{event_id: event.id, name: "VIP", price_cents: 10_000, capacity: 50},
          tenant: forening.id,
          scope: scope
        )

      assert free_tt.price_cents == 0
      assert paid_tt.capacity == 50
    end
  end

  describe "registration" do
    setup do
      forening = create_forening!()
      admin = register_user!()
      invite_member!(forening, admin, :admin)
      admin_scope = scope(admin, forening)

      {:ok, event} =
        Events.create_event(event_attrs(), tenant: forening.id, scope: admin_scope)

      {:ok, event} = Events.publish_event(event, scope: admin_scope)

      {:ok, ticket_type} =
        Events.create_ticket_type(
          %{event_id: event.id, name: "Standard", price_cents: 0},
          tenant: forening.id,
          scope: admin_scope
        )

      %{
        forening: forening,
        event: event,
        ticket_type: ticket_type,
        admin: admin,
        admin_scope: admin_scope
      }
    end

    test "active member registers successfully", ctx do
      user = register_user!()
      membership = invite_member!(ctx.forening, user)
      scope = scope(user, ctx.forening)

      {:ok, reg} =
        Events.register_for_event(
          %{ticket_type_id: ctx.ticket_type.id, membership_id: membership.id},
          tenant: ctx.forening.id,
          scope: scope
        )

      assert reg.status == :confirmed
      assert reg.registered_at
    end

    test "inactive member cannot register for membership-required event", ctx do
      user = register_user!()
      membership = invite_member!(ctx.forening, user)

      Exhs.Organizations.deactivate_member!(membership,
        tenant: ctx.forening.id,
        authorize?: false
      )

      scope = scope(user, ctx.forening)

      assert {:error, _} =
               Events.register_for_event(
                 %{ticket_type_id: ctx.ticket_type.id, membership_id: membership.id},
                 tenant: ctx.forening.id,
                 scope: scope
               )
    end

    test "inactive member CAN register for open event", ctx do
      {:ok, open_event} =
        Events.create_event(
          event_attrs(%{membership_required: false}),
          tenant: ctx.forening.id,
          scope: ctx.admin_scope
        )

      {:ok, open_event} = Events.publish_event(open_event, scope: ctx.admin_scope)

      {:ok, tt} =
        Events.create_ticket_type(
          %{event_id: open_event.id, name: "Open", price_cents: 0},
          tenant: ctx.forening.id,
          scope: ctx.admin_scope
        )

      user = register_user!()
      membership = invite_member!(ctx.forening, user)

      Exhs.Organizations.deactivate_member!(membership,
        tenant: ctx.forening.id,
        authorize?: false
      )

      scope = scope(user, ctx.forening)

      {:ok, reg} =
        Events.register_for_event(
          %{ticket_type_id: tt.id, membership_id: membership.id},
          tenant: ctx.forening.id,
          scope: scope
        )

      assert reg.status == :confirmed
    end

    test "cannot register for unpublished event", ctx do
      {:ok, draft} =
        Events.create_event(event_attrs(), tenant: ctx.forening.id, scope: ctx.admin_scope)

      {:ok, tt} =
        Events.create_ticket_type(
          %{event_id: draft.id, name: "Draft TT", price_cents: 0},
          tenant: ctx.forening.id,
          scope: ctx.admin_scope
        )

      user = register_user!()
      membership = invite_member!(ctx.forening, user)
      scope = scope(user, ctx.forening)

      assert {:error, _} =
               Events.register_for_event(
                 %{ticket_type_id: tt.id, membership_id: membership.id},
                 tenant: ctx.forening.id,
                 scope: scope
               )
    end

    test "capacity enforced — waitlisted when full", ctx do
      {:ok, limited_tt} =
        Events.create_ticket_type(
          %{event_id: ctx.event.id, name: "Limited", price_cents: 0, capacity: 1},
          tenant: ctx.forening.id,
          scope: ctx.admin_scope
        )

      user1 = register_user!()
      m1 = invite_member!(ctx.forening, user1)

      {:ok, reg1} =
        Events.register_for_event(
          %{ticket_type_id: limited_tt.id, membership_id: m1.id},
          tenant: ctx.forening.id,
          scope: scope(user1, ctx.forening)
        )

      assert reg1.status == :confirmed

      user2 = register_user!()
      m2 = invite_member!(ctx.forening, user2)

      {:ok, reg2} =
        Events.register_for_event(
          %{ticket_type_id: limited_tt.id, membership_id: m2.id},
          tenant: ctx.forening.id,
          scope: scope(user2, ctx.forening)
        )

      assert reg2.status == :waitlisted
    end

    test "cancellation sets status and timestamp", ctx do
      user = register_user!()
      membership = invite_member!(ctx.forening, user)
      scope = scope(user, ctx.forening)

      {:ok, reg} =
        Events.register_for_event(
          %{ticket_type_id: ctx.ticket_type.id, membership_id: membership.id},
          tenant: ctx.forening.id,
          scope: scope
        )

      {:ok, cancelled} = Events.cancel_registration(reg, scope: scope)
      assert cancelled.status == :cancelled
      assert cancelled.cancelled_at
    end

    test "waitlist promoted on cancellation", ctx do
      {:ok, limited_tt} =
        Events.create_ticket_type(
          %{event_id: ctx.event.id, name: "Solo", price_cents: 0, capacity: 1},
          tenant: ctx.forening.id,
          scope: ctx.admin_scope
        )

      user1 = register_user!()
      m1 = invite_member!(ctx.forening, user1)

      {:ok, reg1} =
        Events.register_for_event(
          %{ticket_type_id: limited_tt.id, membership_id: m1.id},
          tenant: ctx.forening.id,
          scope: scope(user1, ctx.forening)
        )

      assert reg1.status == :confirmed

      user2 = register_user!()
      m2 = invite_member!(ctx.forening, user2)

      {:ok, reg2} =
        Events.register_for_event(
          %{ticket_type_id: limited_tt.id, membership_id: m2.id},
          tenant: ctx.forening.id,
          scope: scope(user2, ctx.forening)
        )

      assert reg2.status == :waitlisted

      {:ok, _} = Events.cancel_registration(reg1, scope: scope(user1, ctx.forening))

      promoted =
        Ash.get!(Exhs.Events.Registration, reg2.id, tenant: ctx.forening.id, authorize?: false)

      assert promoted.status == :confirmed
    end

    test "waitlist promotion is FIFO — earliest waitlisted promoted first", ctx do
      {:ok, limited_tt} =
        Events.create_ticket_type(
          %{event_id: ctx.event.id, name: "FIFO", price_cents: 0, capacity: 1},
          tenant: ctx.forening.id,
          scope: ctx.admin_scope
        )

      user1 = register_user!()
      m1 = invite_member!(ctx.forening, user1)

      {:ok, reg1} =
        Events.register_for_event(
          %{ticket_type_id: limited_tt.id, membership_id: m1.id},
          tenant: ctx.forening.id,
          scope: scope(user1, ctx.forening)
        )

      user2 = register_user!()
      m2 = invite_member!(ctx.forening, user2)

      {:ok, reg2} =
        Events.register_for_event(
          %{ticket_type_id: limited_tt.id, membership_id: m2.id},
          tenant: ctx.forening.id,
          scope: scope(user2, ctx.forening)
        )

      user3 = register_user!()
      m3 = invite_member!(ctx.forening, user3)

      {:ok, reg3} =
        Events.register_for_event(
          %{ticket_type_id: limited_tt.id, membership_id: m3.id},
          tenant: ctx.forening.id,
          scope: scope(user3, ctx.forening)
        )

      assert reg2.status == :waitlisted
      assert reg3.status == :waitlisted

      {:ok, _} = Events.cancel_registration(reg1, scope: scope(user1, ctx.forening))

      promoted2 =
        Ash.get!(Exhs.Events.Registration, reg2.id, tenant: ctx.forening.id, authorize?: false)

      still_waiting =
        Ash.get!(Exhs.Events.Registration, reg3.id, tenant: ctx.forening.id, authorize?: false)

      assert promoted2.status == :confirmed
      assert still_waiting.status == :waitlisted
    end

    test "no waitlisted registrations — cancellation still succeeds", ctx do
      user = register_user!()
      membership = invite_member!(ctx.forening, user)
      scope = scope(user, ctx.forening)

      {:ok, reg} =
        Events.register_for_event(
          %{ticket_type_id: ctx.ticket_type.id, membership_id: membership.id},
          tenant: ctx.forening.id,
          scope: scope
        )

      {:ok, cancelled} = Events.cancel_registration(reg, scope: scope)
      assert cancelled.status == :cancelled
    end

    test "duplicate registration rejected by identity", ctx do
      user = register_user!()
      membership = invite_member!(ctx.forening, user)
      scope = scope(user, ctx.forening)

      {:ok, _} =
        Events.register_for_event(
          %{ticket_type_id: ctx.ticket_type.id, membership_id: membership.id},
          tenant: ctx.forening.id,
          scope: scope
        )

      assert {:error, _} =
               Events.register_for_event(
                 %{ticket_type_id: ctx.ticket_type.id, membership_id: membership.id},
                 tenant: ctx.forening.id,
                 scope: scope
               )
    end
  end
end
