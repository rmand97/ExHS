defmodule Exhs.Events.Capacity do
  @moduledoc """
  Shared seat-counting helpers for ticket capacity. `seats_taken` counts
  `:confirmed` registrations plus unexpired held `:pending_payment` ones; cart
  entries with no `held_until` do not consume a seat until checkout takes a hold.
  """
  alias Exhs.Events.{AddOn, OrderItem, Registration, TicketType}

  require Ash.Query

  # Order states whose add-on items consume add-on capacity. Cancelled/expired
  # orders free their add-ons; abandoned `:building` carts are swept by
  # `Exhs.Events.AbandonedOrderSweeper`, so counting them here stays conservative
  # (never oversells) without permanently leaking capacity.
  @addon_consuming_statuses [:building, :pending_payment, :paid]

  @doc "Lock the ticket type row FOR UPDATE so concurrent holds serialize."
  def lock_ticket_type!(ticket_type_id, tenant) do
    TicketType
    |> Ash.Query.filter(id == ^ticket_type_id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(tenant: tenant, authorize?: false)
  end

  @doc "Lock the add-on row FOR UPDATE so concurrent add-on purchases serialize."
  def lock_add_on!(add_on_id, tenant) do
    AddOn
    |> Ash.Query.filter(id == ^add_on_id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(tenant: tenant, authorize?: false)
  end

  @doc """
  Add-on seats consumed: summed `quantity` of add-on order items belonging to
  orders in a consuming state. Pass `exclude_id:` to omit a specific order item.
  """
  def addon_seats_taken(add_on_id, tenant, opts \\ []) do
    exclude_id = Keyword.get(opts, :exclude_id)

    OrderItem
    |> Ash.Query.filter(
      add_on_id == ^add_on_id and item_type == :addon and
        order.status in ^@addon_consuming_statuses
    )
    |> exclude(exclude_id)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.reduce(0, &(&1.quantity + &2))
  end

  @doc """
  Count seats consumed: confirmed + unexpired held pending_payment. Pass
  `exclude_id:` to leave a specific registration out (used when re-holding it).
  """
  def seats_taken(ticket_type_id, tenant, opts \\ []) do
    now = DateTime.utc_now()
    exclude_id = Keyword.get(opts, :exclude_id)

    Registration
    |> Ash.Query.filter(
      ticket_type_id == ^ticket_type_id and
        (status == :confirmed or
           (status == :pending_payment and not is_nil(held_until) and held_until > ^now))
    )
    |> exclude(exclude_id)
    |> Ash.count!(tenant: tenant, authorize?: false)
  end

  defp exclude(query, nil), do: query
  defp exclude(query, id), do: Ash.Query.filter(query, id != ^id)
end
