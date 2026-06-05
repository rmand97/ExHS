defmodule Exhs.Events.Availability do
  @moduledoc """
  Per-event PubSub for live ticket availability. Connected viewers of an event
  subscribe and reload `seats_left` whenever a seat is reserved, confirmed, or
  released. Topic is per-event so tenants never cross streams.
  """
  @pubsub Exhs.PubSub

  def subscribe(event_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(event_id))
  end

  def broadcast(event_id) do
    Phoenix.PubSub.broadcast(@pubsub, topic(event_id), {:availability_changed, event_id})
  end

  defp topic(event_id), do: "events:availability:#{event_id}"
end
