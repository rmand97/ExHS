defmodule ExhsWeb.StripeWebhookTest do
  use ExhsWeb.ConnCase, async: false

  alias Exhs.{Accounts, Billing, Organizations}
  alias Exhs.Test.StripeSigning

  defp unique(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp secret, do: Application.get_env(:exhs, :stripe_webhook_signing_secret)

  defp setup_context! do
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

    Organizations.set_membership_stripe_customer!(
      membership,
      %{stripe_customer_id: customer_id},
      tenant: forening.id,
      authorize?: false
    )

    %{
      forening: forening,
      account_id: account_id,
      customer_id: customer_id,
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
      ctx = setup_context!()
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
      ctx = setup_context!()
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
      ctx = setup_context!()

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
