defmodule Exhs.Events.TicketingTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Events
  alias Exhs.Events.Capacity

  defp setup_buyer! do
    forening = create_forening!()
    user = register_user!()
    invite_member!(forening, user, :member)
    membership = membership_for!(forening, user)
    event = create_published_event!(forening, %{membership_required: false})
    %{forening: forening, user: user, membership: membership, event: event}
  end

  defp add_member!(forening, event, role \\ :member) do
    user = register_user!()
    invite_member!(forening, user, role)
    _ = event
    %{user: user, membership: membership_for!(forening, user)}
  end

  describe "group gating" do
    test "ungated ticket type: any member buys" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)
      order = create_order!(f, m, e)

      assert %{} = add_ticket_item!(f, order, tt)
    end

    test "gated, member in an eligible group: buys" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)
      group = create_group!(f)
      gate_ticket_type!(f, tt, [group])
      add_to_group!(f, m, group)
      order = create_order!(f, m, e)

      assert %{} = add_ticket_item!(f, order, tt)
    end

    test "gated, member not in any eligible group: rejected" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)
      group = create_group!(f)
      gate_ticket_type!(f, tt, [group])
      order = create_order!(f, m, e)

      assert {:error, _} =
               Events.add_order_item(
                 %{order_id: order.id, item_type: :ticket, ticket_type_id: tt.id},
                 tenant: f.id,
                 authorize?: false
               )
    end

    test "gated to multiple groups, member in one: buys" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)
      g1 = create_group!(f)
      g2 = create_group!(f)
      gate_ticket_type!(f, tt, [g1, g2])
      add_to_group!(f, m, g2)
      order = create_order!(f, m, e)

      assert %{} = add_ticket_item!(f, order, tt)
    end

    test "member removed from group after gating: subsequent buy rejected" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)
      group = create_group!(f)
      gate_ticket_type!(f, tt, [group])
      join = add_to_group!(f, m, group)
      Exhs.Organizations.remove_member_from_group!(join, tenant: f.id, authorize?: false)
      order = create_order!(f, m, e)

      assert {:error, _} =
               Events.add_order_item(
                 %{order_id: order.id, item_type: :ticket, ticket_type_id: tt.id},
                 tenant: f.id,
                 authorize?: false
               )
    end
  end

  describe "sales window" do
    test "before sales_starts_at: rejected" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      future = DateTime.add(DateTime.utc_now(), 1, :day)
      tt = create_ticket_type!(f, e, %{sales_starts_at: future})
      order = create_order!(f, m, e)

      assert {:error, _} =
               Events.add_order_item(
                 %{order_id: order.id, item_type: :ticket, ticket_type_id: tt.id},
                 tenant: f.id,
                 authorize?: false
               )
    end

    test "after sales_ends_at: rejected" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      past = DateTime.add(DateTime.utc_now(), -1, :day)
      tt = create_ticket_type!(f, e, %{sales_ends_at: past})
      order = create_order!(f, m, e)

      assert {:error, _} =
               Events.add_order_item(
                 %{order_id: order.id, item_type: :ticket, ticket_type_id: tt.id},
                 tenant: f.id,
                 authorize?: false
               )
    end

    test "inside window: buys" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      opens = DateTime.add(DateTime.utc_now(), -1, :day)
      closes = DateTime.add(DateTime.utc_now(), 1, :day)
      tt = create_ticket_type!(f, e, %{sales_starts_at: opens, sales_ends_at: closes})
      order = create_order!(f, m, e)

      assert %{} = add_ticket_item!(f, order, tt)
    end

    test "null window falls back to event registration window" do
      f = create_forening!()
      user = register_user!()
      invite_member!(f, user, :member)
      m = membership_for!(f, user)

      e =
        create_published_event!(f, %{
          membership_required: false,
          registration_closes_at: DateTime.add(DateTime.utc_now(), -1, :hour)
        })

      tt = create_ticket_type!(f, e)
      order = create_order!(f, m, e)

      assert {:error, _} =
               Events.add_order_item(
                 %{order_id: order.id, item_type: :ticket, ticket_type_id: tt.id},
                 tenant: f.id,
                 authorize?: false
               )
    end
  end

  describe "capacity & holds" do
    test "seats_taken counts confirmed; seats_left = capacity - taken" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{capacity: 5, price_cents: 0})
      order = create_order!(f, m, e)
      add_ticket_item!(f, order, tt)

      assert Capacity.seats_taken(tt.id, f.id) == 1

      {:ok, [loaded]} =
        Events.list_ticket_types_for_event(e.id,
          tenant: f.id,
          authorize?: false,
          load: [:seats_left]
        )

      assert loaded.seats_left == 4
    end

    test "nil capacity is unlimited" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{capacity: nil, price_cents: 0})
      order = create_order!(f, m, e)
      add_ticket_item!(f, order, tt)

      {:ok, [loaded]} =
        Events.list_ticket_types_for_event(e.id,
          tenant: f.id,
          authorize?: false,
          load: [:seats_left]
        )

      assert loaded.seats_left == nil
    end

    test "free oversell goes to waitlist" do
      %{forening: f, membership: m1, event: e} = setup_buyer!()
      %{membership: m2} = add_member!(f, e)
      tt = create_ticket_type!(f, e, %{capacity: 1, price_cents: 0})

      o1 = create_order!(f, m1, e)
      item1 = add_ticket_item!(f, o1, tt)
      o2 = create_order!(f, m2, e)
      item2 = add_ticket_item!(f, o2, tt)

      {:ok, r1} =
        Events.get_registration_by_id(item1.registration_id, tenant: f.id, authorize?: false)

      {:ok, r2} =
        Events.get_registration_by_id(item2.registration_id, tenant: f.id, authorize?: false)

      assert r1.status == :confirmed
      assert r2.status == :waitlisted
    end
  end

  describe "one-per-member identity" do
    test "duplicate ticket same member + type rejected" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)
      o = create_order!(f, m, e)
      add_ticket_item!(f, o, tt)

      assert {:error, _} =
               Events.add_order_item(
                 %{order_id: o.id, item_type: :ticket, ticket_type_id: tt.id},
                 tenant: f.id,
                 authorize?: false
               )
    end

    test "same member different ticket type same event allowed" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt1 = create_ticket_type!(f, e)
      tt2 = create_ticket_type!(f, e)
      o = create_order!(f, m, e)

      assert %{} = add_ticket_item!(f, o, tt1)
      assert %{} = add_ticket_item!(f, o, tt2)
    end

    test "member can re-buy after a cancelled order" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)
      o1 = create_order!(f, m, e)
      add_ticket_item!(f, o1, tt)
      Events.cancel_order!(o1, tenant: f.id, authorize?: false)

      o2 = create_order!(f, m, e)
      assert %{} = add_ticket_item!(f, o2, tt)
    end
  end

  describe "tenant isolation" do
    test "each forening lists only its own orders" do
      %{forening: f1, membership: m1, event: e1} = setup_buyer!()
      %{forening: f2, membership: m2, event: e2} = setup_buyer!()
      create_order!(f1, m1, e1)
      create_order!(f2, m2, e2)

      {:ok, f1_orders} = Events.list_orders(tenant: f1.id, authorize?: false)
      {:ok, f2_orders} = Events.list_orders(tenant: f2.id, authorize?: false)
      assert length(f1_orders) == 1
      assert length(f2_orders) == 1
    end

    test "get_order with cross-tenant id returns not found" do
      %{forening: f1, membership: m1, event: e1} = setup_buyer!()
      %{forening: f2} = setup_buyer!()
      order = create_order!(f1, m1, e1)

      assert {:error, _} = Events.get_order(order.id, tenant: f2.id, authorize?: false)
    end

    test "cross-tenant add_order_item is rejected" do
      %{forening: f1, membership: m1, event: e1} = setup_buyer!()
      %{forening: f2} = setup_buyer!()
      tt = create_ticket_type!(f1, e1)
      order = create_order!(f1, m1, e1)

      assert {:error, _} =
               Events.add_order_item(
                 %{order_id: order.id, item_type: :ticket, ticket_type_id: tt.id},
                 tenant: f2.id,
                 authorize?: false
               )
    end
  end
end
