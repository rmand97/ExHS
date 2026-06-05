defmodule Exhs.Events.Changes.OrderItemSnapshot do
  @moduledoc "Snapshots `unit_price_cents` from the ticket type or add-on at add time."
  use Ash.Resource.Change

  alias Ash.Changeset

  def change(changeset, _opts, _context) do
    Changeset.before_action(changeset, fn changeset ->
      price = source_price(changeset)
      Changeset.force_change_attribute(changeset, :unit_price_cents, price)
    end)
  end

  defp source_price(changeset) do
    tenant = changeset.tenant

    case Changeset.get_attribute(changeset, :item_type) do
      :ticket ->
        id = Changeset.get_attribute(changeset, :ticket_type_id)
        {:ok, tt} = Ash.get(Exhs.Events.TicketType, id, tenant: tenant, authorize?: false)
        tt.price_cents

      :addon ->
        id = Changeset.get_attribute(changeset, :add_on_id)
        {:ok, addon} = Ash.get(Exhs.Events.AddOn, id, tenant: tenant, authorize?: false)
        addon.price_cents
    end
  end
end
