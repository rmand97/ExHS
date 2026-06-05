defmodule Exhs.Events.Changes.HoldSeat do
  @moduledoc """
  Takes a timed seat hold for a paid registration at checkout. Locks the ticket
  type, counts seats, and rejects when full (paid presale does not waitlist).
  The registration being held does not yet count toward capacity because its
  `held_until` is still nil in the database until this change commits.
  """
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Exhs.Events.Capacity

  def change(changeset, _opts, _context) do
    Changeset.before_action(changeset, fn changeset ->
      minutes = Changeset.get_argument(changeset, :minutes) || 10
      ticket_type_id = changeset.data.ticket_type_id
      tenant = changeset.tenant

      ticket_type = Capacity.lock_ticket_type!(ticket_type_id, tenant)

      if available?(ticket_type, tenant, changeset.data.id) do
        held_until = DateTime.add(DateTime.utc_now(), minutes * 60, :second)

        changeset
        |> Changeset.force_change_attribute(:status, :pending_payment)
        |> Changeset.force_change_attribute(:held_until, held_until)
      else
        Changeset.add_error(changeset, field: :ticket_type_id, message: "sold out")
      end
    end)
  end

  defp available?(%{capacity: nil}, _tenant, _exclude_id), do: true

  defp available?(%{capacity: cap, id: ticket_type_id}, tenant, exclude_id),
    do: Capacity.seats_taken(ticket_type_id, tenant, exclude_id: exclude_id) < cap
end
