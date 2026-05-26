defmodule Exhs.Billing.WebhookTest do
  use Exhs.DataCase, async: true

  import Exhs.Test.Builders

  alias Exhs.Billing
  alias Exhs.Billing.{Webhook, WebhookWorker}

  defp setup_billing_member! do
    forening =
      create_forening!(%{kontingent_stripe_price_id: "price_test_kontingent"})
      |> activate_stripe_connect!()

    user = register_user!()
    membership = invite_member!(forening, user)
    membership = set_stripe_customer!(forening, membership)

    %{
      forening: forening,
      account_id: forening.stripe_account_id,
      user: user,
      membership: membership,
      customer_id: membership.stripe_customer_id
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

  defp payment_event(ctx, overrides) do
    defaults = %{
      "id" => "in_test_#{System.unique_integer([:positive])}",
      "customer" => ctx.customer_id,
      "payment_intent" => "pi_test_#{System.unique_integer([:positive])}",
      "charge" => "ch_test_#{System.unique_integer([:positive])}",
      "amount_paid" => 50_000,
      "amount_due" => 50_000,
      "currency" => "dkk",
      "status_transitions" => %{"paid_at" => 1_700_000_500}
    }

    %{
      "type" => "invoice.payment_succeeded",
      "account" => ctx.account_id,
      "data" => %{"object" => Map.merge(defaults, overrides)}
    }
  end

  describe "customer.subscription.created" do
    test "inserts a subscription scoped to the forening" do
      ctx = setup_billing_member!()
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
      ctx = setup_billing_member!()
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
      ctx = setup_billing_member!()
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
      ctx = setup_billing_member!()
      event = payment_event(ctx, %{"payment_intent" => "pi_test_1", "charge" => "ch_test_1"})

      assert {:ok, payment} = Webhook.apply_event(event)
      assert payment.amount_cents == 50_000
      assert payment.currency == "DKK"
      assert payment.status == :succeeded
      assert payment.stripe_payment_intent_id == "pi_test_1"
      assert payment.forening_id == ctx.forening.id
    end

    test "is idempotent for the same payment_intent" do
      ctx = setup_billing_member!()
      event = payment_event(ctx, %{"payment_intent" => "pi_test_2", "charge" => "ch_test_2"})

      assert {:ok, first} = Webhook.apply_event(event)
      assert {:ok, second} = Webhook.apply_event(event)
      assert first.id == second.id

      payments = Billing.list_payments!(tenant: ctx.forening.id, authorize?: false)
      assert length(payments) == 1
    end
  end

  describe "invoice.payment_failed" do
    test "records a Payment row with :failed status" do
      ctx = setup_billing_member!()

      event = %{
        "type" => "invoice.payment_failed",
        "account" => ctx.account_id,
        "data" => %{
          "object" => %{
            "id" => "in_fail_#{System.unique_integer([:positive])}",
            "customer" => ctx.customer_id,
            "payment_intent" => "pi_fail_1",
            "charge" => "ch_fail_1",
            "amount_paid" => 0,
            "amount_due" => 50_000,
            "currency" => "dkk",
            "status_transitions" => %{"paid_at" => nil}
          }
        }
      }

      assert {:ok, payment} = Webhook.apply_event(event)
      assert payment.status == :failed
      assert payment.amount_cents == 0
      assert payment.stripe_payment_intent_id == "pi_fail_1"
    end
  end

  describe "account.updated" do
    test "syncs forening stripe_account_status to :active" do
      forening =
        create_forening!(%{kontingent_stripe_price_id: "price_test_kontingent"})
        |> activate_stripe_connect!()

      event = %{
        "type" => "account.updated",
        "data" => %{
          "object" => %{
            "id" => forening.stripe_account_id,
            "charges_enabled" => true,
            "payouts_enabled" => true,
            "details_submitted" => true
          }
        }
      }

      assert {:ok, updated} = Webhook.apply_event(event)
      assert updated.stripe_account_status == :active
    end

    test "syncs forening stripe_account_status to :restricted" do
      forening =
        create_forening!(%{kontingent_stripe_price_id: "price_test_kontingent"})
        |> activate_stripe_connect!()

      event = %{
        "type" => "account.updated",
        "data" => %{
          "object" => %{
            "id" => forening.stripe_account_id,
            "charges_enabled" => false,
            "payouts_enabled" => false,
            "details_submitted" => true
          }
        }
      }

      assert {:ok, updated} = Webhook.apply_event(event)
      assert updated.stripe_account_status == :restricted
    end
  end

  describe "checkout.session.completed" do
    test "is handled without error" do
      event = %{
        "type" => "checkout.session.completed",
        "data" => %{
          "object" => %{
            "id" => "cs_test_1",
            "mode" => "subscription",
            "subscription" => "sub_test_1"
          }
        }
      }

      assert :ok = Webhook.apply_event(event)
    end
  end

  describe "charge.refunded" do
    test "marks an existing payment refunded" do
      ctx = setup_billing_member!()

      paid = payment_event(ctx, %{"payment_intent" => "pi_test_3", "charge" => "ch_test_3"})
      {:ok, _} = Webhook.apply_event(paid)

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
      ctx = setup_billing_member!()
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
