defmodule Exhs.Events.Changes.CreateTicketRegistration do
  @moduledoc """
  For a ticket order item, creates the linked Registration after the item is
  inserted and stores its id on the item. Free tickets (price 0) confirm
  immediately via `:register`; paid tickets enter `:pending_payment` via
  `:reserve` with no seat hold yet — the hold is taken at checkout.
  """
  use Ash.Resource.Change

  alias Ash.Changeset

  def change(changeset, _opts, _context) do
    Changeset.after_action(changeset, fn changeset, item ->
      if Changeset.get_attribute(changeset, :item_type) == :ticket do
        link_registration(item)
      else
        {:ok, item}
      end
    end)
  end

  defp link_registration(item) do
    tenant = item.forening_id

    {:ok, ticket_type} =
      Ash.get(Exhs.Events.TicketType, item.ticket_type_id, tenant: tenant, authorize?: false)

    {:ok, order} = Ash.get(Exhs.Events.Order, item.order_id, tenant: tenant, authorize?: false)
    args = %{ticket_type_id: item.ticket_type_id, membership_id: order.membership_id}

    result =
      if ticket_type.price_cents == 0 do
        Exhs.Events.register_for_event(args, tenant: tenant, authorize?: false)
      else
        Exhs.Events.reserve_registration(args, tenant: tenant, authorize?: false)
      end

    with {:ok, registration} <- result do
      item
      |> Changeset.for_update(:link_registration, %{registration_id: registration.id},
        tenant: tenant,
        authorize?: false
      )
      |> Ash.update()
    end
  end
end
