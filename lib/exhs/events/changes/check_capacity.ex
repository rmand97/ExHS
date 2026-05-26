defmodule Exhs.Events.Changes.CheckCapacity do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Changeset

  require Ash.Query

  def change(changeset, _opts, _context) do
    Changeset.before_action(changeset, fn changeset ->
      ticket_type_id = Changeset.get_attribute(changeset, :ticket_type_id)
      tenant = changeset.tenant

      ticket_type =
        Ash.get!(Exhs.Events.TicketType, ticket_type_id,
          tenant: tenant,
          authorize?: false
        )

      status = resolve_status(ticket_type, tenant)
      Changeset.force_change_attribute(changeset, :status, status)
    end)
  end

  defp resolve_status(%{capacity: nil}, _tenant), do: :confirmed

  defp resolve_status(%{capacity: cap, id: ticket_type_id}, tenant) do
    confirmed_count =
      Exhs.Events.Registration
      |> Ash.Query.filter(ticket_type_id == ^ticket_type_id and status == :confirmed)
      |> Ash.count!(tenant: tenant, authorize?: false)

    if confirmed_count < cap, do: :confirmed, else: :waitlisted
  end
end
