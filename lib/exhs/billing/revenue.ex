defmodule Exhs.Billing.Revenue do
  @moduledoc """
  Pure, in-memory revenue aggregation over a list of `Payment` structs.

  Extensible by design: every breakdown iterates `PayableType.values/0` and
  `PaymentStatus.values/0` rather than hard-coding the current set, so adding a
  new revenue source (e.g. `:merch`) or payment status surfaces automatically
  with no change to this module or its callers. Only `:succeeded` payments count
  toward realised revenue; `:pending`/`:failed` feed the outstanding figure.
  """

  alias Exhs.Billing.Types.PayableType
  alias Exhs.Billing.Types.PaymentStatus

  @outstanding_statuses [:pending, :failed]

  @doc "Full dashboard summary for a list of payments."
  def summary(payments) do
    succeeded = Enum.filter(payments, &(&1.status == :succeeded))

    %{
      total_cents: sum(succeeded),
      by_type: by_type(succeeded),
      by_month: by_month(succeeded),
      by_status: count_by_status(payments),
      outstanding_cents: payments |> Enum.filter(&(&1.status in @outstanding_statuses)) |> sum()
    }
  end

  @doc "Realised revenue per payable type. Keys cover every `PayableType` value."
  def by_type(payments) do
    grouped = Enum.group_by(payments, & &1.payable_type)
    Map.new(PayableType.values(), fn type -> {type, sum(Map.get(grouped, type, []))} end)
  end

  @doc "Payment counts per status. Keys cover every `PaymentStatus` value."
  def count_by_status(payments) do
    grouped = Enum.group_by(payments, & &1.status)

    Map.new(PaymentStatus.values(), fn status ->
      {status, length(Map.get(grouped, status, []))}
    end)
  end

  @doc "Realised revenue per `{year, month}`, newest first."
  def by_month(payments) do
    payments
    |> Enum.reject(&is_nil(&1.paid_at))
    |> Enum.group_by(&{&1.paid_at.year, &1.paid_at.month})
    |> Enum.map(fn {month, ps} -> {month, sum(ps)} end)
    |> Enum.sort_by(fn {month, _} -> month end, :desc)
  end

  defp sum(payments), do: Enum.reduce(payments, 0, &(&1.amount_cents + &2))
end
