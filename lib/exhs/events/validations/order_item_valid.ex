defmodule Exhs.Events.Validations.OrderItemValid do
  @moduledoc """
  Structural validation for an order item: ticket items require a ticket type and
  no add-on, add-on items require an add-on and no ticket type, and quantity must
  be 1 unless the ticket type opts into `allow_multiple`.
  """
  use Ash.Resource.Validation

  alias Ash.Changeset

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    item_type = Changeset.get_attribute(changeset, :item_type)
    ticket_type_id = Changeset.get_attribute(changeset, :ticket_type_id)
    add_on_id = Changeset.get_attribute(changeset, :add_on_id)
    quantity = Changeset.get_attribute(changeset, :quantity) || 1

    with :ok <- check_refs(item_type, ticket_type_id, add_on_id) do
      check_quantity(item_type, ticket_type_id, quantity, changeset.tenant)
    end
  end

  defp check_refs(:ticket, nil, _add_on_id),
    do: {:error, field: :ticket_type_id, message: "ticket item requires a ticket type"}

  defp check_refs(:ticket, _ticket_type_id, nil), do: :ok

  defp check_refs(:ticket, _ticket_type_id, _add_on_id),
    do: {:error, field: :add_on_id, message: "ticket item cannot also reference an add-on"}

  defp check_refs(:addon, nil, nil),
    do: {:error, field: :add_on_id, message: "add-on item requires an add-on"}

  defp check_refs(:addon, nil, _add_on_id), do: :ok

  defp check_refs(:addon, _ticket_type_id, _add_on_id),
    do:
      {:error, field: :ticket_type_id, message: "add-on item cannot also reference a ticket type"}

  defp check_quantity(_item_type, _ticket_type_id, quantity, _tenant) when quantity < 1,
    do: {:error, field: :quantity, message: "quantity must be at least 1"}

  defp check_quantity(:addon, _ticket_type_id, _quantity, _tenant), do: :ok
  defp check_quantity(:ticket, _ticket_type_id, 1, _tenant), do: :ok

  defp check_quantity(:ticket, ticket_type_id, _quantity, tenant) do
    case Ash.get(Exhs.Events.TicketType, ticket_type_id, tenant: tenant, authorize?: false) do
      {:ok, %{allow_multiple: true}} ->
        :ok

      _ ->
        {:error, field: :quantity, message: "only one ticket per type is allowed"}
    end
  end
end
