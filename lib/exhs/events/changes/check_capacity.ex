defmodule Exhs.Events.Changes.CheckCapacity do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Exhs.Events.Capacity

  def change(changeset, _opts, _context) do
    Changeset.before_action(changeset, fn changeset ->
      ticket_type_id = Changeset.get_attribute(changeset, :ticket_type_id)
      tenant = changeset.tenant

      ticket_type = Capacity.lock_ticket_type!(ticket_type_id, tenant)
      Changeset.force_change_attribute(changeset, :status, resolve_status(ticket_type, tenant))
    end)
  end

  defp resolve_status(%{capacity: nil}, _tenant), do: :confirmed

  defp resolve_status(%{capacity: cap, id: ticket_type_id}, tenant) do
    if Capacity.seats_taken(ticket_type_id, tenant) < cap, do: :confirmed, else: :waitlisted
  end
end
