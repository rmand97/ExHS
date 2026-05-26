defmodule Exhs.Billing.StripeClient do
  @moduledoc false

  @callback create_account(params :: map()) ::
              {:ok, map()} | {:error, term()}
  @callback create_account_link(params :: map()) ::
              {:ok, map()} | {:error, term()}
  @callback create_customer(params :: map(), connected_account_id :: String.t()) ::
              {:ok, map()} | {:error, term()}
  @callback create_checkout_session(params :: map(), connected_account_id :: String.t()) ::
              {:ok, map()} | {:error, term()}
  @callback update_subscription(
              subscription_id :: String.t(),
              params :: map(),
              connected_account_id :: String.t()
            ) :: {:ok, map()} | {:error, term()}
  @callback construct_event(
              payload :: String.t(),
              signature :: String.t(),
              secret :: String.t()
            ) :: {:ok, map()} | {:error, term()}

  def create_account(params), do: impl().create_account(params)
  def create_account_link(params), do: impl().create_account_link(params)
  def create_customer(params, account_id), do: impl().create_customer(params, account_id)

  def create_checkout_session(params, account_id),
    do: impl().create_checkout_session(params, account_id)

  def update_subscription(id, params, account_id),
    do: impl().update_subscription(id, params, account_id)

  def construct_event(payload, sig, secret), do: impl().construct_event(payload, sig, secret)

  defp impl, do: Application.get_env(:exhs, :stripe_client, Exhs.Billing.StripeClient.Live)
end
