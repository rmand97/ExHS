defmodule Exhs.Events.Checkout do
  @moduledoc """
  Orchestrates turning a `:building` order into a payment. Free orders (zero
  total) confirm in place with no Stripe call. Paid orders take a timed seat hold
  on each ticket registration, build Stripe Checkout line items on the forening's
  connected account, and move the order to `:pending_payment`. The
  `checkout.session.completed` webhook later confirms it.
  """
  alias Exhs.Billing.StripeClient
  alias Exhs.Events
  alias Exhs.Events.{OrderItem, OrderItems, ReservationExpiry}
  alias Exhs.Organizations

  require Ash.Query

  @hold_minutes 10

  @doc """
  `opts` must include `:tenant`, and for paid orders `:success_url` and
  `:cancel_url`. Returns `{:ok, %{order: order, checkout_url: url | nil}}`.
  """
  def checkout_order(order, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, order} <- reload(order, tenant),
         :ok <- ensure_building(order),
         items <- load_items(order.id, tenant),
         :ok <- ensure_has_ticket(items) do
      if order.total_cents == 0 do
        free_checkout(order, tenant)
      else
        paid_checkout(order, items, tenant, opts)
      end
    end
  end

  defp free_checkout(order, tenant) do
    {:ok, paid} = Events.mark_order_paid(order, tenant: tenant, authorize?: false)
    {:ok, %{order: paid, checkout_url: nil}}
  end

  defp paid_checkout(order, items, tenant, opts) do
    success_url = Keyword.fetch!(opts, :success_url)
    cancel_url = Keyword.fetch!(opts, :cancel_url)

    with :ok <- take_holds(order.id, tenant),
         {:ok, forening} <- Organizations.get_forening_by_id(order.forening_id, authorize?: false),
         :ok <- require_connect_active(forening),
         {:ok, %{id: session_id, url: url}} <-
           create_session(order, items, forening, success_url, cancel_url),
         {:ok, order} <-
           Events.begin_order_checkout(
             order,
             %{stripe_checkout_session_id: session_id, held_until: hold_deadline()},
             tenant: tenant,
             authorize?: false
           ) do
      schedule_expiry(order, tenant)
      {:ok, %{order: order, checkout_url: url}}
    else
      {:error, reason} ->
        release_holds(order.id, tenant)
        {:error, reason}
    end
  end

  defp take_holds(order_id, tenant) do
    order_id
    |> OrderItems.ticket_registrations(tenant)
    |> Enum.reduce_while(:ok, fn registration, :ok ->
      case Events.hold_registration(registration, %{minutes: @hold_minutes},
             tenant: tenant,
             authorize?: false
           ) do
        {:ok, _held} -> {:cont, :ok}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp release_holds(order_id, tenant) do
    order_id
    |> OrderItems.ticket_registrations(tenant)
    |> Enum.reject(&(&1.status == :cancelled))
    |> Enum.each(fn registration ->
      Events.cancel_registration(registration, tenant: tenant, authorize?: false)
    end)
  end

  defp create_session(order, items, forening, success_url, cancel_url) do
    StripeClient.create_checkout_session(
      %{
        mode: "payment",
        line_items: line_items(items, order.currency),
        success_url: success_url,
        cancel_url: cancel_url,
        metadata: %{order_id: order.id, forening_id: forening.id}
      },
      forening.stripe_account_id
    )
  end

  defp line_items(items, currency) do
    Enum.map(items, fn item ->
      %{
        quantity: item.quantity,
        price_data: %{
          currency: String.downcase(currency),
          unit_amount: item.unit_price_cents,
          product_data: %{name: line_name(item)}
        }
      }
    end)
  end

  defp line_name(%{item_type: :ticket, ticket_type: %{name: name}}), do: name
  defp line_name(%{item_type: :addon, add_on: %{name: name}}), do: name
  defp line_name(_), do: "Billet"

  defp load_items(order_id, tenant) do
    OrderItem
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.Query.load([:ticket_type, :add_on])
    |> Ash.read!(tenant: tenant, authorize?: false)
  end

  defp reload(order, tenant) do
    Events.get_order(order.id, tenant: tenant, authorize?: false)
  end

  defp ensure_building(%{status: :building}), do: :ok
  defp ensure_building(_), do: {:error, :order_not_building}

  defp ensure_has_ticket(items) do
    if Enum.any?(items, &(&1.item_type == :ticket)) do
      :ok
    else
      {:error, :order_requires_ticket}
    end
  end

  defp require_connect_active(%{stripe_account_status: :active, stripe_account_id: id})
       when is_binary(id),
       do: :ok

  defp require_connect_active(_), do: {:error, :forening_billing_not_ready}

  defp hold_deadline, do: DateTime.add(DateTime.utc_now(), @hold_minutes * 60, :second)

  defp schedule_expiry(order, tenant) do
    %{order_id: order.id, tenant: tenant}
    |> ReservationExpiry.new(scheduled_at: order.held_until)
    |> Oban.insert()
  end
end
