defmodule Exhs.Events.Changes.BroadcastAvailability do
  @moduledoc "Broadcasts a live availability update for the registration's event after a seat change."
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Exhs.Events.Availability

  def change(changeset, _opts, _context) do
    Changeset.after_action(changeset, fn changeset, registration ->
      ticket_type_id = registration.ticket_type_id
      tenant = changeset.tenant

      case Ash.get(Exhs.Events.TicketType, ticket_type_id, tenant: tenant, authorize?: false) do
        {:ok, ticket_type} -> Availability.broadcast(ticket_type.event_id)
        _ -> :ok
      end

      {:ok, registration}
    end)
  end
end
