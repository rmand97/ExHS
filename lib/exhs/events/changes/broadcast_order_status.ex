defmodule Exhs.Events.Changes.BroadcastOrderStatus do
  @moduledoc "Broadcasts a live order-status update after a lifecycle transition (e.g. paid)."
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Exhs.Events.OrderUpdates

  def change(changeset, _opts, _context) do
    Changeset.after_action(changeset, fn _changeset, order ->
      OrderUpdates.broadcast(order.id)
      {:ok, order}
    end)
  end
end
