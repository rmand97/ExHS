defmodule Exhs.Billing.WebhookTest do
  use Exhs.DataCase, async: true

  alias Exhs.{Accounts, Billing, Organizations}
  alias Exhs.Billing.{Webhook, WebhookWorker}

  defp unique(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp setup_forening_with_member! do
    forening =
      Organizations.create_forening!(
        %{
          name: "Forening #{System.unique_integer([:positive])}",
          slug: unique("slug"),
          subdomain: unique("sub"),
          kontingent_stripe_price_id: "price_test_kontingent"
        },
        authorize?: false
      )

    account_id = "acct_test_#{System.unique_integer([:positive])}"

    forening =
      Organizations.set_forening_stripe_account!(
        forening,
        %{stripe_account_id: account_id, stripe_account_status: :active},
        authorize?: false
      )

    email = "user-#{System.unique_integer([:positive])}@example.com"

    user =
      Accounts.register_with_password!(email, "password123", "password123", authorize?: false)

    membership = Organizations.invite_member!(user.id, tenant: forening.id, authorize?: false)

    customer_id = "cus_test_#{System.unique_integer([:positive])}"

    membership =
      Organizations.set_membership_stripe_customer!(
        membership,
        %{stripe_customer_id: customer_id},
        tenant: forening.id,
        authorize?: false
      )

    %{
      forening: forening,
      account_id: account_id,
      user: user,
      membership: membership,
      customer_id: customer_id
    }
  end

  defp subscription_event(type, ctx, overrides \\ %{}) do
    base =
      Map.merge(
        %{
          "id" => "sub_test_#{System.unique_integer([:positive])}",
          "customer" => ctx.customer_id,
          "status" => "active",
          "current_period_start" => 1_700_000_000,
          "current_period_end" => 1_710_000_000,
          "cancel_at_period_end" => false
        },
        overrides
      )

    %{
      "type" => type,
      "account" => ctx.account_id,
      "data" => %{"object" => base}
    }
  end

  describe "customer.subscription.created" do
    test "inserts a subscription scoped to the forening" do
      ctx = setup_forening_with_member!()
      event = subscription_event("customer.subscription.created", ctx)

      assert {:ok, sub} = Webhook.apply_event(event)
      assert sub.stripe_subscription_id == event["data"]["object"]["id"]
      assert sub.status == :active
      assert sub.membership_id == ctx.membership.id
      assert sub.forening_id == ctx.forening.id
    end
  end

  describe "customer.subscription.updated" do
    test "updates an existing subscription" do
      ctx = setup_forening_with_member!()
      created = subscription_event("customer.subscription.created", ctx)
      {:ok, _} = Webhook.apply_event(created)

      updated =
        subscription_event(
          "customer.subscription.updated",
          ctx,
          %{
            "id" => created["data"]["object"]["id"],
            "status" => "past_due",
            "cancel_at_period_end" => true
          }
        )

      assert {:ok, sub} = Webhook.apply_event(updated)
      assert sub.status == :past_due
      assert sub.cancel_at_period_end == true
    end
  end

  describe "customer.subscription.deleted" do
    test "marks the subscription canceled" do
      ctx = setup_forening_with_member!()
      created = subscription_event("customer.subscription.created", ctx)
      {:ok, _} = Webhook.apply_event(created)

      deleted =
        subscription_event(
          "customer.subscription.deleted",
          ctx,
          %{"id" => created["data"]["object"]["id"]}
        )

      assert {:ok, sub} = Webhook.apply_event(deleted)
      assert sub.status == :canceled
    end
  end

  describe "invoice.payment_succeeded" do
    test "records a Payment row" do
      ctx = setup_forening_with_member!()

      event = %{
        "type" => "invoice.payment_succeeded",
        "account" => ctx.account_id,
        "data" => %{
          "object" => %{
            "id" => "in_test_1",
            "customer" => ctx.customer_id,
            "payment_intent" => "pi_test_1",
            "charge" => "ch_test_1",
            "amount_paid" => 50_000,
            "amount_due" => 50_000,
            "currency" => "dkk",
            "status_transitions" => %{"paid_at" => 1_700_000_500}
          }
        }
      }

      assert {:ok, payment} = Webhook.apply_event(event)
      assert payment.amount_cents == 50_000
      assert payment.currency == "DKK"
      assert payment.status == :succeeded
      assert payment.stripe_payment_intent_id == "pi_test_1"
      assert payment.forening_id == ctx.forening.id
    end

    test "is idempotent for the same payment_intent" do
      ctx = setup_forening_with_member!()

      event = %{
        "type" => "invoice.payment_succeeded",
        "account" => ctx.account_id,
        "data" => %{
          "object" => %{
            "id" => "in_test_2",
            "customer" => ctx.customer_id,
            "payment_intent" => "pi_test_2",
            "charge" => "ch_test_2",
            "amount_paid" => 50_000,
            "currency" => "dkk",
            "status_transitions" => %{"paid_at" => 1_700_000_500}
          }
        }
      }

      assert {:ok, first} = Webhook.apply_event(event)
      assert {:ok, second} = Webhook.apply_event(event)
      assert first.id == second.id

      payments = Billing.list_payments!(tenant: ctx.forening.id, authorize?: false)
      assert length(payments) == 1
    end
  end

  describe "charge.refunded" do
    test "marks an existing payment refunded" do
      ctx = setup_forening_with_member!()

      paid_event = %{
        "type" => "invoice.payment_succeeded",
        "account" => ctx.account_id,
        "data" => %{
          "object" => %{
            "id" => "in_test_3",
            "customer" => ctx.customer_id,
            "payment_intent" => "pi_test_3",
            "charge" => "ch_test_3",
            "amount_paid" => 50_000,
            "currency" => "dkk",
            "status_transitions" => %{"paid_at" => 1_700_000_500}
          }
        }
      }

      {:ok, _} = Webhook.apply_event(paid_event)

      refund_event = %{
        "type" => "charge.refunded",
        "account" => ctx.account_id,
        "data" => %{
          "object" => %{"id" => "ch_test_3", "payment_intent" => "pi_test_3"}
        }
      }

      assert {:ok, refunded} = Webhook.apply_event(refund_event)
      assert refunded.status == :refunded
    end
  end

  describe "WebhookWorker idempotency" do
    test "the same event id enqueued twice runs apply_event once" do
      ctx = setup_forening_with_member!()
      event_id = "evt_test_#{System.unique_integer([:positive])}"

      event =
        subscription_event("customer.subscription.created", ctx)
        |> Map.put("id", event_id)

      args = %{event_id: event_id, event: event}

      assert {:ok, _job1} = args |> WebhookWorker.new() |> Oban.insert()
      assert {:ok, _job2} = args |> WebhookWorker.new() |> Oban.insert()

      subs = Billing.list_subscriptions!(tenant: ctx.forening.id, authorize?: false)
      assert length(subs) == 1
    end
  end
end
