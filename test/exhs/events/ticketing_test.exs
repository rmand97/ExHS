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

  describe "add-on capacity" do
    test "a limited add-on cannot be oversold across orders" do
      %{forening: f, membership: m1, event: e} = setup_buyer!()
      %{membership: m2} = add_member!(f, e)
      add_on = create_add_on!(f, e, %{capacity: 1})

      assert add_addon_item!(f, create_order!(f, m1, e), add_on)

      assert_raise Ash.Error.Invalid, fn ->
        add_addon_item!(f, create_order!(f, m2, e), add_on)
      end
    end

    test "fills exactly to capacity then rejects the next" do
      %{forening: f, membership: m1, event: e} = setup_buyer!()
      %{membership: m2} = add_member!(f, e)
      %{membership: m3} = add_member!(f, e)
      add_on = create_add_on!(f, e, %{capacity: 2})

      assert add_addon_item!(f, create_order!(f, m1, e), add_on)
      assert add_addon_item!(f, create_order!(f, m2, e), add_on)

      assert_raise Ash.Error.Invalid, fn ->
        add_addon_item!(f, create_order!(f, m3, e), add_on)
      end
    end

    test "quantity is summed against capacity" do
      %{forening: f, membership: m1, event: e} = setup_buyer!()
      %{membership: m2} = add_member!(f, e)
      add_on = create_add_on!(f, e, %{capacity: 2})

      assert add_addon_item!(f, create_order!(f, m1, e), add_on, %{quantity: 2})

      assert_raise Ash.Error.Invalid, fn ->
        add_addon_item!(f, create_order!(f, m2, e), add_on, %{quantity: 1})
      end
    end

    test "quantity larger than total capacity is rejected up front" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      add_on = create_add_on!(f, e, %{capacity: 2})

      assert_raise Ash.Error.Invalid, fn ->
        add_addon_item!(f, create_order!(f, m, e), add_on, %{quantity: 3})
      end
    end

    test "nil capacity is unlimited" do
      %{forening: f, membership: m1, event: e} = setup_buyer!()
      %{membership: m2} = add_member!(f, e)
      add_on = create_add_on!(f, e, %{capacity: nil})

      assert add_addon_item!(f, create_order!(f, m1, e), add_on)
      assert add_addon_item!(f, create_order!(f, m2, e), add_on)
    end

    test "a cancelled order frees its add-on capacity" do
      %{forening: f, membership: m1, event: e} = setup_buyer!()
      %{membership: m2} = add_member!(f, e)
      add_on = create_add_on!(f, e, %{capacity: 1})

      o1 = create_order!(f, m1, e)
      add_addon_item!(f, o1, add_on)
      Events.cancel_order!(o1, tenant: f.id, authorize?: false)

      assert add_addon_item!(f, create_order!(f, m2, e), add_on)
    end

    test "removing the add-on item frees its capacity" do
      %{forening: f, membership: m1, event: e} = setup_buyer!()
      %{membership: m2} = add_member!(f, e)
      add_on = create_add_on!(f, e, %{capacity: 1})

      item = add_addon_item!(f, create_order!(f, m1, e), add_on)
      Events.remove_order_item!(item, tenant: f.id, authorize?: false)

      assert add_addon_item!(f, create_order!(f, m2, e), add_on)
    end

    test "a paid order keeps consuming add-on capacity" do
      %{forening: f, membership: m1, event: e} = setup_buyer!()
      %{membership: m2} = add_member!(f, e)
      add_on = create_add_on!(f, e, %{capacity: 1})

      o1 = create_order!(f, m1, e)
      add_addon_item!(f, o1, add_on)
      Events.mark_order_paid!(o1, tenant: f.id, authorize?: false)

      assert_raise Ash.Error.Invalid, fn ->
        add_addon_item!(f, create_order!(f, m2, e), add_on)
      end
    end
  end

  describe "currency (DKK only)" do
    test "ticket type create rejects non-DKK" do
      %{forening: f, event: e} = setup_buyer!()

      assert {:error, _} =
               Events.create_ticket_type(
                 %{event_id: e.id, name: "EUR ticket", price_cents: 100, currency: "EUR"},
                 tenant: f.id,
                 authorize?: false
               )
    end

    test "ticket type update rejects non-DKK" do
      %{forening: f, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{price_cents: 100})

      assert {:error, _} =
               Events.update_ticket_type(tt, %{currency: "EUR"}, tenant: f.id, authorize?: false)
    end

    test "add-on create rejects non-DKK" do
      %{forening: f, event: e} = setup_buyer!()

      assert {:error, _} =
               Events.create_add_on(
                 %{event_id: e.id, name: "EUR bus", price_cents: 100, currency: "EUR"},
                 tenant: f.id,
                 authorize?: false
               )
    end

    test "DKK is accepted and orders default to DKK" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{price_cents: 100, currency: "DKK"})

      assert tt.currency == "DKK"
      assert create_order!(f, m, e).currency == "DKK"
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

    test "one forening filling an add-on never blocks another's identical one" do
      %{forening: f1, membership: m1, event: e1} = setup_buyer!()
      %{forening: f2, membership: m2, event: e2} = setup_buyer!()
      add_on1 = create_add_on!(f1, e1, %{capacity: 1})
      add_on2 = create_add_on!(f2, e2, %{capacity: 1})

      add_addon_item!(f1, create_order!(f1, m1, e1), add_on1)

      assert add_addon_item!(f2, create_order!(f2, m2, e2), add_on2)
    end
  end
end
