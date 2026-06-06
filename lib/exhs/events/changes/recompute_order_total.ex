defmodule Exhs.Events.Changes.RecomputeOrderTotal do
  @moduledoc "Recomputes the parent order's `total_cents` from its current items."
  use Ash.Resource.Change

  alias Ash.Changeset

  require Ash.Query

  def change(changeset, _opts, _context) do
    Changeset.after_action(changeset, fn changeset, record ->
      order_id = order_id(changeset, record)
      tenant = changeset.tenant

      total = items_total(order_id, tenant)

      # The parent order can be gone (e.g. cancelled concurrently with a remove);
      # if so there's nothing to retotal and the item change still stands.
      case Ash.get(Exhs.Events.Order, order_id, tenant: tenant, authorize?: false) do
        {:ok, order} ->
          order
          |> Changeset.for_update(:set_total, %{total_cents: total},
            tenant: tenant,
            authorize?: false
          )
          |> Ash.update!()

        _ ->
          :ok
      end

      {:ok, record}
    end)
  end

  defp order_id(changeset, record) do
    Changeset.get_attribute(changeset, :order_id) || record.order_id
  end

  defp items_total(order_id, tenant) do
    Exhs.Events.OrderItem
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.reduce(0, fn item, acc -> acc + item.unit_price_cents * item.quantity end)
  end
end
