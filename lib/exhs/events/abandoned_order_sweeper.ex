defmodule Exhs.Events.AbandonedOrderSweeper do
  @moduledoc """
  Cron worker that cancels carts abandoned in `:building` past a TTL. A ticket
  added to a cart creates a `:pending_payment` registration immediately, and the
  `one_per_ticket_type` identity (which ignores only `:cancelled`) then blocks
  the same member from re-buying that ticket type. Paid orders are released by
  `ReservationExpiry` on their hold deadline, but a cart that never reaches
  checkout has no such timer — without this sweep its dangling registration
  would lock the member out indefinitely. Cancelling the order releases those
  registrations (via `ReleaseOrderHolds`), freeing the identity.
  """
  use Oban.Worker, queue: :maintenance, max_attempts: 3

  alias Exhs.Events

  # Abandoned carts older than this are cancelled. Comfortably longer than the
  # 10-minute checkout hold so an actively-building cart is never killed.
  @ttl_minutes 30

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cutoff = DateTime.add(DateTime.utc_now(), -@ttl_minutes * 60, :second)

    cutoff
    |> Events.list_stale_building_orders!(authorize?: false)
    |> Enum.each(fn order ->
      Events.cancel_order(order, tenant: order.forening_id, authorize?: false)
    end)

    :ok
  end
end
