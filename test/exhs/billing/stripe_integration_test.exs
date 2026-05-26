defmodule Exhs.Billing.StripeIntegrationTest do
  @moduledoc """
  Integration tests that hit stripe-mock (localhost:12111).
  Excluded by default — run with: mix test --include integration
  """
  use Exhs.StripeIntegrationCase, async: false

  alias Exhs.Billing.StripeClient

  @moduletag :integration

  describe "create_account/1" do
    test "returns a valid account struct" do
      assert {:ok, %{id: "acct_" <> _}} =
               StripeClient.create_account(%{type: "standard", country: "DK"})
    end
  end

  describe "create_account_link/1" do
    test "returns a URL" do
      {:ok, %{id: acct_id}} = StripeClient.create_account(%{type: "standard"})

      assert {:ok, %{url: url}} =
               StripeClient.create_account_link(%{
                 account: acct_id,
                 refresh_url: "https://example.test/refresh",
                 return_url: "https://example.test/return",
                 type: "account_onboarding"
               })

      assert is_binary(url)
    end
  end

  describe "create_customer/2" do
    test "creates a customer on connected account" do
      {:ok, %{id: acct_id}} = StripeClient.create_account(%{type: "standard"})

      assert {:ok, %{id: "cus_" <> _}} =
               StripeClient.create_customer(%{metadata: %{test: "true"}}, acct_id)
    end
  end

  describe "create_checkout_session/2" do
    test "creates a checkout session with subscription mode" do
      {:ok, %{id: acct_id}} = StripeClient.create_account(%{type: "standard"})
      {:ok, %{id: cus_id}} = StripeClient.create_customer(%{}, acct_id)

      assert {:ok, %{id: "cs_" <> _, url: url}} =
               StripeClient.create_checkout_session(
                 %{
                   mode: "subscription",
                   customer: cus_id,
                   line_items: [%{price: "price_fake", quantity: 1}],
                   success_url: "https://example.test/ok",
                   cancel_url: "https://example.test/cancel"
                 },
                 acct_id
               )

      assert is_binary(url)
    end
  end

  describe "update_subscription/3" do
    test "updates cancel_at_period_end" do
      {:ok, %{id: acct_id}} = StripeClient.create_account(%{type: "standard"})
      {:ok, %{id: cus_id}} = StripeClient.create_customer(%{}, acct_id)

      {:ok, sub} =
        Stripe.Subscription.create(
          %{customer: cus_id, items: [%{price: "price_fake"}]},
          connect_account: acct_id
        )

      assert {:ok, updated} =
               StripeClient.update_subscription(
                 sub.id,
                 %{cancel_at_period_end: true},
                 acct_id
               )

      assert updated.cancel_at_period_end == true
    end
  end

  describe "construct_event/3" do
    test "verifies a correctly signed payload" do
      payload = Jason.encode!(%{id: "evt_test", type: "test.event", data: %{object: %{}}})
      secret = "whsec_integration_test"
      timestamp = System.system_time(:second)
      signed = "#{timestamp}.#{payload}"

      signature =
        :crypto.mac(:hmac, :sha256, secret, signed)
        |> Base.encode16(case: :lower)

      header = "t=#{timestamp},v1=#{signature}"

      assert {:ok, %{id: "evt_test"}} = StripeClient.construct_event(payload, header, secret)
    end

    test "rejects a tampered payload" do
      payload = Jason.encode!(%{id: "evt_test", type: "test.event", data: %{object: %{}}})
      secret = "whsec_integration_test"

      assert {:error, _} = StripeClient.construct_event(payload, "t=0,v1=deadbeef", secret)
    end
  end
end
