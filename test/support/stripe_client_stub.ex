defmodule Exhs.Billing.StripeClient.Stub do
  @moduledoc false
  @behaviour Exhs.Billing.StripeClient

  @valid_signature_marker "valid-test-signature"

  def set_response(function_name, response) do
    Process.put({__MODULE__, function_name}, response)
  end

  @impl true
  def create_account(_params) do
    with nil <- Process.get({__MODULE__, :create_account}) do
      {:ok, %{id: "acct_test_#{rand()}", details_submitted: false, charges_enabled: false}}
    end
  end

  @impl true
  def create_account_link(_params) do
    with nil <- Process.get({__MODULE__, :create_account_link}) do
      {:ok, %{url: "https://stripe.test/connect/onboard/#{rand()}", expires_at: now() + 3600}}
    end
  end

  @impl true
  def create_customer(_params, _account_id) do
    with nil <- Process.get({__MODULE__, :create_customer}) do
      {:ok, %{id: "cus_test_#{rand()}"}}
    end
  end

  @impl true
  def create_checkout_session(_params, _account_id) do
    with nil <- Process.get({__MODULE__, :create_checkout_session}) do
      id = "cs_test_#{rand()}"
      {:ok, %{id: id, url: "https://stripe.test/checkout/#{id}"}}
    end
  end

  @impl true
  def update_subscription(id, params, _account_id) do
    with nil <- Process.get({__MODULE__, :update_subscription}) do
      {:ok, Map.merge(%{id: id, cancel_at_period_end: false}, params)}
    end
  end

  @impl true
  def construct_event(payload, signature, _secret) do
    if signature == @valid_signature_marker do
      {:ok, Jason.decode!(payload)}
    else
      {:error, "Invalid signature"}
    end
  end

  def valid_signature, do: @valid_signature_marker

  defp rand, do: :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  defp now, do: System.system_time(:second)
end
