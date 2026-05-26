defmodule Exhs.Billing.StripeClient.Stub do
  @moduledoc """
  Test stub for `Exhs.Billing.StripeClient`. Returns canned responses; tests can
  override per-call behaviour by setting expectations in the process dictionary
  via `expect/2` and then asserting via `called?/1`.

  Tests do **not** hit real Stripe; this stub is the substitute. The webhook
  signature verifier is implemented honestly so that "invalid signature"
  scenarios fail loudly the same way the live verifier would.
  """
  @behaviour Exhs.Billing.StripeClient

  @valid_signature_marker "valid-test-signature"

  @impl true
  def create_account(_params) do
    {:ok, %{id: "acct_test_#{rand()}", details_submitted: false, charges_enabled: false}}
  end

  @impl true
  def create_account_link(_params) do
    {:ok, %{url: "https://stripe.test/connect/onboard/#{rand()}", expires_at: now() + 3600}}
  end

  @impl true
  def create_customer(_params, _account_id) do
    {:ok, %{id: "cus_test_#{rand()}"}}
  end

  @impl true
  def create_checkout_session(_params, _account_id) do
    id = "cs_test_#{rand()}"
    {:ok, %{id: id, url: "https://stripe.test/checkout/#{id}"}}
  end

  @impl true
  def update_subscription(id, params, _account_id) do
    {:ok, Map.merge(%{id: id, cancel_at_period_end: false}, params)}
  end

  @impl true
  def construct_event(payload, signature, _secret) do
    if signature == @valid_signature_marker do
      {:ok, Jason.decode!(payload)}
    else
      {:error, "Invalid signature"}
    end
  end

  @doc "Signature header value the stub treats as valid. Use in webhook tests."
  def valid_signature, do: @valid_signature_marker

  defp rand, do: :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  defp now, do: System.system_time(:second)
end
