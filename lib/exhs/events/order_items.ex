defmodule Exhs.Events.OrderItems do
  @moduledoc "Read helpers over an order's items, shared by order lifecycle changes."
  alias Exhs.Events.{OrderItem, Registration}

  require Ash.Query

  @doc "Loads the Registrations linked to an order's ticket items."
  def ticket_registrations(order_id, tenant) do
    registration_ids =
      OrderItem
      |> Ash.Query.filter(order_id == ^order_id and item_type == :ticket)
      |> Ash.read!(tenant: tenant, authorize?: false)
      |> Enum.map(& &1.registration_id)
      |> Enum.reject(&is_nil/1)

    if registration_ids == [] do
      []
    else
      Registration
      |> Ash.Query.filter(id in ^registration_ids)
      |> Ash.read!(tenant: tenant, authorize?: false)
    end
  end
end
