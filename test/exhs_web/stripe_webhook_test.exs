defmodule ExhsWeb.StripeWebhookTest do
  use ExhsWeb.ConnCase, async: false

  import Exhs.Test.Builders

  alias Exhs.Billing
  alias Exhs.Test.StripeSigning

  defp secret, do: Application.get_env(:exhs, :stripe_webhook_signing_secret)

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
      customer_id: membership.stripe_customer_id,
      membership: membership
    }
  end

  defp event_payload(type, ctx) do
    Jason.encode!(%{
      object: "event",
      id: "evt_test_#{System.unique_integer([:positive])}",
      type: type,
      account: ctx.account_id,
      data: %{
        object: %{
          object: "subscription",
          id: "sub_test_#{System.unique_integer([:positive])}",
          customer: ctx.customer_id,
          status: "active",
          current_period_start: 1_700_000_000,
          current_period_end: 1_710_000_000,
          cancel_at_period_end: false
        }
      }
    })
  end

  describe "POST /webhook/stripe" do
    test "accepts a properly signed event and persists state", %{conn: conn} do
      ctx = setup_billing_member!()
      payload = event_payload("customer.subscription.created", ctx)
      sig = StripeSigning.signature_header(payload, secret())

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", sig)
        |> post("/webhook/stripe", payload)

      assert conn.status == 200, "got #{conn.status}, body: #{conn.resp_body}"

      subs = Billing.list_subscriptions!(tenant: ctx.forening.id, authorize?: false)
      assert length(subs) == 1
    end

    test "rejects an invalid signature", %{conn: conn} do
      ctx = setup_billing_member!()
      payload = event_payload("customer.subscription.created", ctx)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", "t=0,v1=deadbeef")
        |> post("/webhook/stripe", payload)

      assert conn.status == 400

      subs = Billing.list_subscriptions!(tenant: ctx.forening.id, authorize?: false)
      assert Enum.empty?(subs)
    end

    test "redelivery of the same event id applies state only once", %{conn: conn} do
      ctx = setup_billing_member!()

      payload =
        Jason.encode!(%{
          object: "event",
          id: "evt_replay_1",
          type: "customer.subscription.created",
          account: ctx.account_id,
          data: %{
            object: %{
              object: "subscription",
              id: "sub_replay_1",
              customer: ctx.customer_id,
              status: "active",
              current_period_start: 1_700_000_000,
              current_period_end: 1_710_000_000,
              cancel_at_period_end: false
            }
          }
        })

      sig = StripeSigning.signature_header(payload, secret())

      send_event = fn ->
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", sig)
        |> post("/webhook/stripe", payload)
      end

      assert send_event.().status == 200
      assert send_event.().status == 200

      subs = Billing.list_subscriptions!(tenant: ctx.forening.id, authorize?: false)
      assert length(subs) == 1
    end
  end
end
