defmodule Exhs.Events.OrderTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Events

  defp setup_buyer! do
    forening = create_forening!()
    user = register_user!()
    invite_member!(forening, user, :member)
    membership = membership_for!(forening, user)
    event = create_published_event!(forening, %{membership_required: false})
    %{forening: forening, user: user, membership: membership, event: event}
  end

  describe "order lifecycle" do
    test "create_order starts in :building with zero total" do
      %{forening: f, membership: m, event: e} = setup_buyer!()

      order = create_order!(f, m, e)

      assert order.status == :building
      assert order.total_cents == 0
      assert order.membership_id == m.id
      assert order.event_id == e.id
    end

    test "add ticket item recomputes total and links a Registration" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000})
      order = create_order!(f, m, e)

      item = add_ticket_item!(f, order, tt)

      assert item.unit_price_cents == 10_000
      assert item.registration_id

      assert {:ok, reloaded} = Events.get_order(order.id, tenant: f.id, authorize?: false)
      assert reloaded.total_cents == 10_000
    end

    test "add addon item adds its price to the total" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000})
      addon = create_add_on!(f, e, %{price_cents: 5_000})
      order = create_order!(f, m, e)

      add_ticket_item!(f, order, tt)
      add_addon_item!(f, order, addon)

      assert {:ok, reloaded} = Events.get_order(order.id, tenant: f.id, authorize?: false)
      assert reloaded.total_cents == 15_000
    end

    test "remove item recomputes total" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000})
      addon = create_add_on!(f, e, %{price_cents: 5_000})
      order = create_order!(f, m, e)

      ticket_item = add_ticket_item!(f, order, tt)
      add_addon_item!(f, order, addon)

      Events.remove_order_item!(ticket_item, tenant: f.id, authorize?: false)

      assert {:ok, reloaded} = Events.get_order(order.id, tenant: f.id, authorize?: false)
      assert reloaded.total_cents == 5_000
    end

    test "cancel from :building releases held seats" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000})
      order = create_order!(f, m, e)
      item = add_ticket_item!(f, order, tt)

      {:ok, cancelled} = Events.cancel_order(order, tenant: f.id, authorize?: false)
      assert cancelled.status == :cancelled

      {:ok, reg} =
        Events.get_registration_by_id(item.registration_id, tenant: f.id, authorize?: false)

      assert reg.status == :cancelled
    end

    test "get_order loads items and payment" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000})
      order = create_order!(f, m, e)
      add_ticket_item!(f, order, tt)

      {:ok, loaded} = Events.get_order(order.id, tenant: f.id, authorize?: false)
      assert length(loaded.items) == 1
      assert loaded.payment == nil
    end

    test "add item to a non-building order is rejected" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000})
      order = create_order!(f, m, e)
      {:ok, cancelled} = Events.cancel_order(order, tenant: f.id, authorize?: false)

      assert {:error, _} =
               Events.add_order_item(
                 %{order_id: cancelled.id, item_type: :ticket, ticket_type_id: tt.id},
                 tenant: f.id,
                 authorize?: false
               )
    end

    test "unit_price_cents is a snapshot — later price change does not mutate the order" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000})
      order = create_order!(f, m, e)
      add_ticket_item!(f, order, tt)

      Events.update_ticket_type!(tt, %{price_cents: 99_999}, tenant: f.id, authorize?: false)

      {:ok, reloaded} = Events.get_order(order.id, tenant: f.id, authorize?: false)
      assert reloaded.total_cents == 10_000
    end

    test "state machine rejects an illegal transition" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      order = create_order!(f, m, e)
      {:ok, cancelled} = Events.cancel_order(order, tenant: f.id, authorize?: false)

      # :cancelled is terminal — re-checking out is not a permitted transition.
      assert {:error, %Ash.Error.Invalid{}} =
               Events.begin_order_checkout(
                 cancelled,
                 %{stripe_checkout_session_id: "cs_x", held_until: DateTime.utc_now()},
                 tenant: f.id,
                 authorize?: false
               )
    end
  end

  describe "order item validation" do
    test "ticket item missing ticket_type_id is rejected" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      order = create_order!(f, m, e)

      assert {:error, _} =
               Events.add_order_item(%{order_id: order.id, item_type: :ticket},
                 tenant: f.id,
                 authorize?: false
               )
    end

    test "addon item missing add_on_id is rejected" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      order = create_order!(f, m, e)

      assert {:error, _} =
               Events.add_order_item(%{order_id: order.id, item_type: :addon},
                 tenant: f.id,
                 authorize?: false
               )
    end

    test "item with both ticket_type_id and add_on_id is rejected" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)
      addon = create_add_on!(f, e)
      order = create_order!(f, m, e)

      assert {:error, _} =
               Events.add_order_item(
                 %{
                   order_id: order.id,
                   item_type: :ticket,
                   ticket_type_id: tt.id,
                   add_on_id: addon.id
                 },
                 tenant: f.id,
                 authorize?: false
               )
    end

    test "quantity > 1 rejected when allow_multiple is false" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)
      order = create_order!(f, m, e)

      assert {:error, _} =
               Events.add_order_item(
                 %{order_id: order.id, item_type: :ticket, ticket_type_id: tt.id, quantity: 2},
                 tenant: f.id,
                 authorize?: false
               )
    end
  end

  describe "custom questions" do
    test "required question answered → item persists with responses keyed by question id" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)

      q =
        create_question!(f, tt, %{label: "Year", field_type: :select, options: ["2010", "2011"]})

      order = create_order!(f, m, e)

      item = add_ticket_item!(f, order, tt, %{responses: %{q.id => "2010"}})
      assert item.responses[q.id] == "2010"
    end

    test "required question unanswered → rejected" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)
      create_question!(f, tt, %{label: "Year", required: true})
      order = create_order!(f, m, e)

      assert {:error, _} =
               Events.add_order_item(
                 %{order_id: order.id, item_type: :ticket, ticket_type_id: tt.id, responses: %{}},
                 tenant: f.id,
                 authorize?: false
               )
    end

    test "select answer outside options → rejected" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)
      q = create_question!(f, tt, %{field_type: :select, options: ["2010"]})
      order = create_order!(f, m, e)

      assert {:error, _} =
               Events.add_order_item(
                 %{
                   order_id: order.id,
                   item_type: :ticket,
                   ticket_type_id: tt.id,
                   responses: %{q.id => "1999"}
                 },
                 tenant: f.id,
                 authorize?: false
               )
    end

    test "text answer for a :number question → rejected" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e)
      q = create_question!(f, tt, %{field_type: :number})
      order = create_order!(f, m, e)

      assert {:error, _} =
               Events.add_order_item(
                 %{
                   order_id: order.id,
                   item_type: :ticket,
                   ticket_type_id: tt.id,
                   responses: %{q.id => "abc"}
                 },
                 tenant: f.id,
                 authorize?: false
               )
    end
  end
end
