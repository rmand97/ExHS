defmodule Exhs.Billing.RevenueTest do
  use ExUnit.Case, async: true

  alias Exhs.Billing.PaymentFilter
  alias Exhs.Billing.Revenue

  defp payment(attrs) do
    Map.merge(
      %{
        payable_type: :subscription,
        amount_cents: 10_000,
        status: :succeeded,
        currency: "DKK",
        description: nil,
        paid_at: ~U[2026-03-01 10:00:00Z],
        inserted_at: ~U[2026-03-01 10:00:00Z]
      },
      Map.new(attrs)
    )
  end

  describe "summary/1" do
    test "counts only succeeded toward total, pending/failed toward outstanding" do
      payments = [
        payment(status: :succeeded, amount_cents: 30_000),
        payment(status: :pending, amount_cents: 5_000),
        payment(status: :failed, amount_cents: 2_000),
        payment(status: :refunded, amount_cents: 9_000)
      ]

      summary = Revenue.summary(payments)

      assert summary.total_cents == 30_000
      assert summary.outstanding_cents == 7_000
    end

    test "by_type has a key for every payable type, even with no payments" do
      summary = Revenue.summary([])

      # Extensibility: every PayableType value is present with a zero default.
      assert Map.keys(summary.by_type) |> Enum.sort() == [:order, :registration, :subscription]
      assert Enum.all?(Map.values(summary.by_type), &(&1 == 0))
    end

    test "by_type sums succeeded revenue per type" do
      payments = [
        payment(payable_type: :subscription, amount_cents: 30_000),
        payment(payable_type: :registration, amount_cents: 12_000),
        payment(payable_type: :registration, amount_cents: 8_000),
        payment(payable_type: :order, amount_cents: 5_000, status: :pending)
      ]

      by_type = Revenue.summary(payments).by_type
      assert by_type[:subscription] == 30_000
      assert by_type[:registration] == 20_000
      assert by_type[:order] == 0
    end

    test "by_month groups succeeded revenue newest first" do
      payments = [
        payment(amount_cents: 10_000, paid_at: ~U[2026-01-15 10:00:00Z]),
        payment(amount_cents: 20_000, paid_at: ~U[2026-03-15 10:00:00Z]),
        payment(amount_cents: 5_000, paid_at: ~U[2026-03-20 10:00:00Z])
      ]

      assert Revenue.summary(payments).by_month == [
               {{2026, 3}, 25_000},
               {{2026, 1}, 10_000}
             ]
    end

    test "count_by_status covers every status" do
      counts = Revenue.summary([payment(status: :succeeded)]).by_status
      assert counts[:succeeded] == 1
      assert counts[:pending] == 0
      assert Map.keys(counts) |> Enum.sort() == [:failed, :pending, :refunded, :succeeded]
    end
  end

  describe "PaymentFilter.apply/2" do
    setup do
      payments = [
        payment(
          status: :succeeded,
          payable_type: :subscription,
          amount_cents: 30_000,
          description: "Kontingent",
          paid_at: ~U[2026-03-01 10:00:00Z]
        ),
        payment(
          status: :pending,
          payable_type: :registration,
          amount_cents: 12_000,
          description: "Sommerlejr",
          paid_at: ~U[2026-04-01 10:00:00Z]
        )
      ]

      %{payments: payments}
    end

    test "filters by status", %{payments: payments} do
      assert [p] = PaymentFilter.apply(payments, %{status: "pending"})
      assert p.status == :pending
    end

    test "filters by type", %{payments: payments} do
      assert [p] = PaymentFilter.apply(payments, %{type: "subscription"})
      assert p.payable_type == :subscription
    end

    test "filters by month", %{payments: payments} do
      assert [p] = PaymentFilter.apply(payments, %{month: "2026-04"})
      assert p.payable_type == :registration
    end

    test "filters by description query", %{payments: payments} do
      assert [p] = PaymentFilter.apply(payments, %{q: "kontingent"})
      assert p.description == "Kontingent"
    end

    test "sorts by amount descending", %{payments: payments} do
      assert [a, b] = PaymentFilter.apply(payments, %{sort: "amount_desc"})
      assert a.amount_cents >= b.amount_cents
    end

    test "empty filters return everything", %{payments: payments} do
      assert length(PaymentFilter.apply(payments, %{})) == 2
    end
  end
end
