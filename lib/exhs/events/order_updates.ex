defmodule Exhs.Events.OrderUpdates do
  @moduledoc """
  Per-order PubSub for live order status. A buyer watching their order (or order
  list) subscribes and reloads whenever the order's lifecycle state changes —
  most importantly `pending_payment -> paid` after the Stripe webhook confirms.
  Topic is per-order (UUID) so it never crosses orders or tenants.
  """
  @pubsub Exhs.PubSub

  def subscribe(order_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(order_id))
  end

  def broadcast(order_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(order_id), {:order_updated, order_id})
  end

  defp topic(order_id), do: "events:order:#{order_id}"
end
