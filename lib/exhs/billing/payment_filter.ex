defmodule Exhs.Billing.PaymentFilter do
  @moduledoc """
  In-memory filter + sort for admin payment lists, mirroring
  `Exhs.Organizations.MemberFilter`. Filter values are strings (straight from
  query params); a blank value (`nil` or `""`) imposes no constraint.

  Extensible by design: status and type are matched against the stringified
  enum value, so new `PaymentStatus`/`PayableType` values filter correctly with
  no change here.
  """

  @doc """
  Apply `filters` to `payments`. Recognised keys (atom): `:status`, `:type`,
  `:month` (`"YYYY-MM"`), `:q` (matches description), `:sort`.
  """
  def apply(payments, filters) do
    payments
    |> filter_status(filters[:status])
    |> filter_type(filters[:type])
    |> filter_month(filters[:month])
    |> filter_query(filters[:q])
    |> sort(filters[:sort])
  end

  defp filter_status(payments, status) when status in [nil, ""], do: payments

  defp filter_status(payments, status),
    do: Enum.filter(payments, &(to_string(&1.status) == status))

  defp filter_type(payments, type) when type in [nil, ""], do: payments

  defp filter_type(payments, type),
    do: Enum.filter(payments, &(to_string(&1.payable_type) == type))

  defp filter_month(payments, month) when month in [nil, ""], do: payments

  defp filter_month(payments, month) do
    Enum.filter(payments, fn p -> p.paid_at && month_key(p.paid_at) == month end)
  end

  defp filter_query(payments, q) when q in [nil, ""], do: payments

  defp filter_query(payments, q) do
    term = String.downcase(q)

    Enum.filter(payments, fn p ->
      p.description && String.contains?(String.downcase(p.description), term)
    end)
  end

  defp sort(payments, "amount_desc"), do: Enum.sort_by(payments, & &1.amount_cents, :desc)
  defp sort(payments, "amount_asc"), do: Enum.sort_by(payments, & &1.amount_cents, :asc)
  defp sort(payments, "oldest"), do: Enum.sort_by(payments, &sort_time/1, :asc)
  defp sort(payments, _), do: Enum.sort_by(payments, &sort_time/1, :desc)

  defp sort_time(%{paid_at: nil, inserted_at: t}), do: t
  defp sort_time(%{paid_at: t}), do: t

  defp month_key(dt), do: "#{dt.year}-#{String.pad_leading(to_string(dt.month), 2, "0")}"
end
