defmodule Exhs.Events.ReservationExpiry do
  @moduledoc """
  Releases an expired paid-order hold. Scheduled at checkout for the order's
  `held_until`. Expires only orders still in `:pending_payment` whose hold has
  lapsed; a `:paid` order is left untouched. Expiring releases the seats (which
  enqueues waitlist promotion) and is idempotent — re-running on an already
  expired/paid order is a no-op.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 30, keys: [:order_id]]

  alias Exhs.Events

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"order_id" => order_id, "tenant" => tenant}}) do
    case Events.get_order(order_id, tenant: tenant, authorize?: false) do
      {:ok, %{status: :pending_payment} = order} -> maybe_expire(order, tenant)
      _ -> :ok
    end
  end

  defp maybe_expire(order, tenant) do
    if expired?(order) do
      Events.expire_order(order, tenant: tenant, authorize?: false)
    end

    :ok
  end

  defp expired?(%{held_until: nil}), do: true

  defp expired?(%{held_until: held_until}),
    do: DateTime.compare(DateTime.utc_now(), held_until) != :lt
end
