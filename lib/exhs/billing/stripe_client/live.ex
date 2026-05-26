defmodule Exhs.Billing.StripeClient.Live do
  @moduledoc false
  @behaviour Exhs.Billing.StripeClient

  alias Stripe.Checkout.Session, as: CheckoutSession

  @impl true
  def create_account(params), do: Stripe.Account.create(params)

  @impl true
  def create_account_link(params), do: Stripe.AccountLink.create(params)

  @impl true
  def create_customer(params, account_id),
    do: Stripe.Customer.create(params, connect_account: account_id)

  @impl true
  def create_checkout_session(params, account_id),
    do: CheckoutSession.create(params, connect_account: account_id)

  @impl true
  def update_subscription(id, params, account_id),
    do: Stripe.Subscription.update(id, params, connect_account: account_id)

  @impl true
  def construct_event(payload, sig, secret),
    do: Stripe.Webhook.construct_event(payload, sig, secret)
end
