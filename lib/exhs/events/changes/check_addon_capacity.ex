defmodule Exhs.Events.Changes.CheckAddonCapacity do
  @moduledoc """
  Enforces an add-on's `capacity` when an add-on order item is added. Locks the
  add-on row FOR UPDATE so concurrent purchases serialize, counts already-taken
  add-on seats, and rejects the item when the requested quantity would exceed
  capacity. A nil capacity is unlimited. Ticket items are ignored — their seats
  are guarded by `CheckCapacity`/`HoldSeat`.
  """
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Exhs.Events.Capacity

  def change(changeset, _opts, _context) do
    Changeset.before_action(changeset, fn changeset ->
      if Changeset.get_attribute(changeset, :item_type) == :addon do
        check(changeset)
      else
        changeset
      end
    end)
  end

  defp check(changeset) do
    add_on_id = Changeset.get_attribute(changeset, :add_on_id)
    quantity = Changeset.get_attribute(changeset, :quantity) || 1
    tenant = changeset.tenant

    add_on = Capacity.lock_add_on!(add_on_id, tenant)

    case add_on.capacity do
      nil ->
        changeset

      cap ->
        if Capacity.addon_seats_taken(add_on_id, tenant) + quantity <= cap do
          changeset
        else
          Changeset.add_error(changeset, field: :add_on_id, message: "sold out")
        end
    end
  end
end
