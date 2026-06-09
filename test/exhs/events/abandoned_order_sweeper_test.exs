defmodule Exhs.Events.AbandonedOrderSweeperTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Events
  alias Exhs.Events.AbandonedOrderSweeper

  defp setup_buyer! do
    forening = create_forening!()
    user = register_user!()
    invite_member!(forening, user, :member)
    membership = membership_for!(forening, user)
    event = create_published_event!(forening, %{membership_required: false})
    %{forening: forening, membership: membership, event: event}
  end

  # Backdate inserted_at so the TTL window can be exercised without waiting.
  # Test-only: the create_timestamp is otherwise unwritable.
  defp backdate!(order, seconds) do
    naive =
      DateTime.utc_now()
      |> DateTime.add(-seconds, :second)
      |> DateTime.to_naive()

    Exhs.Repo.query!(
      "UPDATE event_orders SET inserted_at = $1 WHERE id = $2",
      [naive, Ecto.UUID.dump!(order.id)]
    )

    order
  end

  defp status(forening, order_id) do
    {:ok, o} = Events.get_order(order_id, tenant: forening.id, authorize?: false)
    o.status
  end

  defp run!, do: assert(:ok = AbandonedOrderSweeper.perform(%Oban.Job{args: %{}}))

  describe "perform/1" do
    test "cancels a stale building order end-to-end" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000, capacity: 100})
      order = create_order!(f, m, e)
      add_ticket_item!(f, order, tt)
      backdate!(order, 60 * 60)

      run!()

      assert status(f, order.id) == :cancelled
    end

    test "frees the dangling registration so the member can re-buy" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000, capacity: 100})
      order = create_order!(f, m, e)
      add_ticket_item!(f, order, tt)

      # The dangling pending_payment registration blocks the same member.
      assert_raise Ash.Error.Invalid, fn -> add_ticket_item!(f, create_order!(f, m, e), tt) end

      backdate!(order, 60 * 60)
      run!()

      assert add_ticket_item!(f, create_order!(f, m, e), tt)
    end

    test "leaves a fresh building order intact (TTL respected)" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      order = create_order!(f, m, e)

      run!()

      assert status(f, order.id) == :building
    end

    test "does not touch paid orders" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      order = create_order!(f, m, e)
      Events.mark_order_paid!(order, tenant: f.id, authorize?: false)
      backdate!(order, 60 * 60)

      run!()

      assert status(f, order.id) == :paid
    end

    test "is idempotent across repeated runs" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      tt = create_ticket_type!(f, e, %{price_cents: 10_000, capacity: 100})
      order = create_order!(f, m, e)
      add_ticket_item!(f, order, tt)
      backdate!(order, 60 * 60)

      run!()
      run!()

      assert status(f, order.id) == :cancelled
    end

    test "tenant isolation: stale carts in two foreninger both swept under their own tenant" do
      %{forening: fa, membership: ma, event: ea} = setup_buyer!()
      %{forening: fb, membership: mb, event: eb} = setup_buyer!()
      tta = create_ticket_type!(fa, ea, %{price_cents: 10_000, capacity: 100})
      ttb = create_ticket_type!(fb, eb, %{price_cents: 10_000, capacity: 100})

      oa = create_order!(fa, ma, ea)
      ob = create_order!(fb, mb, eb)
      add_ticket_item!(fa, oa, tta)
      add_ticket_item!(fb, ob, ttb)
      backdate!(oa, 60 * 60)
      backdate!(ob, 60 * 60)

      run!()

      assert status(fa, oa.id) == :cancelled
      assert status(fb, ob.id) == :cancelled
    end
  end

  describe "stale_building read" do
    test "returns only :building orders past the cutoff" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      building = create_order!(f, m, e)
      paid = create_order!(f, m, e)
      Events.mark_order_paid!(paid, tenant: f.id, authorize?: false)
      cancelled = create_order!(f, m, e)
      Events.cancel_order!(cancelled, tenant: f.id, authorize?: false)

      cutoff = DateTime.add(DateTime.utc_now(), 60, :second)

      ids =
        cutoff
        |> Events.list_stale_building_orders!(authorize?: false)
        |> Enum.map(& &1.id)
        |> MapSet.new()

      assert MapSet.member?(ids, building.id)
      refute MapSet.member?(ids, paid.id)
      refute MapSet.member?(ids, cancelled.id)
    end

    test "excludes building orders newer than the cutoff" do
      %{forening: f, membership: m, event: e} = setup_buyer!()
      fresh = create_order!(f, m, e)

      cutoff = DateTime.add(DateTime.utc_now(), -60, :second)

      ids =
        cutoff
        |> Events.list_stale_building_orders!(authorize?: false)
        |> Enum.map(& &1.id)

      refute fresh.id in ids
    end
  end
end
