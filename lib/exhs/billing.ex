defmodule Exhs.Billing do
  @moduledoc """
  Billing domain. Owns Subscription and Payment, and provides orchestrators that
  combine Stripe API calls with persistent state changes. Webhook event dispatch
  lives in `Exhs.Billing.Webhook`; the HTTP receiver in
  `ExhsWeb.StripeWebhookController` defers to that module via an Oban worker.
  """
  use Ash.Domain, otp_app: :exhs, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Exhs.Billing.Subscription do
      define :create_subscription, action: :create
      define :sync_subscription, action: :sync
      define :cancel_subscription, action: :cancel

      define :get_subscription_by_id, action: :get_by_id, args: [:id], get?: true

      define :get_subscription_by_stripe_id,
        action: :get_by_stripe_id,
        args: [:stripe_subscription_id],
        get?: true

      define :list_subscriptions, action: :read
      define :list_my_subscriptions, action: :my_subscriptions
    end

    resource Exhs.Billing.Payment do
      define :record_payment, action: :record
      define :mark_payment_refunded, action: :mark_refunded

      define :get_payment_by_id, action: :get_by_id, args: [:id], get?: true

      define :get_payment_by_payment_intent,
        action: :get_by_payment_intent,
        args: [:stripe_payment_intent_id],
        get?: true

      define :list_payments, action: :read
      define :list_my_payments, action: :my_payments
    end
  end

  alias Exhs.Billing.StripeClient
  alias Exhs.Checks.Helpers, as: CheckHelpers
  alias Exhs.Organizations

  @doc """
  Begin Stripe Connect onboarding for a forening. Creates the connected account
  on first call (transitioning `stripe_account_status` from `:none` to
  `:onboarding`) and returns a Stripe-hosted Account Link URL.

  `opts` must include `:refresh_url` and `:return_url`.
  """
  def start_onboarding(forening, scope, opts) do
    refresh_url = Keyword.fetch!(opts, :refresh_url)
    return_url = Keyword.fetch!(opts, :return_url)

    with :ok <- require_admin(scope, forening.id),
         {:ok, account_id} <- ensure_connect_account(forening, scope),
         {:ok, %{url: url}} <-
           StripeClient.create_account_link(%{
             account: account_id,
             refresh_url: refresh_url,
             return_url: return_url,
             type: "account_onboarding"
           }) do
      {:ok, url}
    end
  end

  @doc """
  Create a Stripe Checkout Session for the member's kontingent subscription.
  Returns the hosted URL the member should be redirected to.

  `opts` must include `:success_url` and `:cancel_url`. The membership's
  forening must have a Connect account in status `:active`.
  """
  def start_kontingent_subscription(membership, scope, opts) do
    success_url = Keyword.fetch!(opts, :success_url)
    cancel_url = Keyword.fetch!(opts, :cancel_url)

    with :ok <- require_self_or_admin(scope, membership),
         {:ok, forening} <-
           Organizations.get_forening_by_id(membership.forening_id, authorize?: false),
         :ok <- require_connect_active(forening),
         {:ok, customer_id} <- ensure_customer(membership, forening, scope),
         {:ok, %{url: url}} <-
           StripeClient.create_checkout_session(
             %{
               mode: "subscription",
               customer: customer_id,
               line_items: [%{price: forening.kontingent_stripe_price_id, quantity: 1}],
               success_url: success_url,
               cancel_url: cancel_url,
               metadata: %{forening_id: forening.id, membership_id: membership.id}
             },
             forening.stripe_account_id
           ) do
      {:ok, url}
    end
  end

  @doc """
  Mark a subscription cancel-at-period-end on Stripe and persist the same
  locally. The matching `customer.subscription.updated` webhook will arrive
  later; persisting now lets the UI reflect the change immediately.
  """
  def cancel_kontingent_subscription(subscription, scope) do
    with :ok <- require_self_or_admin_for_subscription(scope, subscription),
         {:ok, forening} <-
           Organizations.get_forening_by_id(subscription.forening_id, authorize?: false),
         {:ok, _stripe_sub} <-
           StripeClient.update_subscription(
             subscription.stripe_subscription_id,
             %{cancel_at_period_end: true},
             forening.stripe_account_id
           ) do
      sync_subscription(subscription, %{cancel_at_period_end: true}, authorize?: false)
    end
  end

  defp ensure_connect_account(%{stripe_account_id: id}, _scope) when is_binary(id), do: {:ok, id}

  defp ensure_connect_account(forening, scope) do
    with {:ok, %{id: account_id}} <-
           StripeClient.create_account(%{type: "standard", country: "DK"}),
         {:ok, _updated} <-
           Organizations.set_forening_stripe_account(
             forening,
             %{stripe_account_id: account_id, stripe_account_status: :onboarding},
             scope: scope,
             authorize?: false
           ) do
      {:ok, account_id}
    end
  end

  defp ensure_customer(%{stripe_customer_id: id}, _forening, _scope) when is_binary(id),
    do: {:ok, id}

  defp ensure_customer(membership, forening, scope) do
    with {:ok, %{id: customer_id}} <-
           StripeClient.create_customer(
             %{metadata: %{membership_id: membership.id}},
             forening.stripe_account_id
           ),
         {:ok, _} <-
           Organizations.set_membership_stripe_customer(
             membership,
             %{stripe_customer_id: customer_id},
             scope: scope,
             authorize?: false
           ) do
      {:ok, customer_id}
    end
  end

  defp require_connect_active(%{stripe_account_status: :active, stripe_account_id: id})
       when is_binary(id),
       do: :ok

  defp require_connect_active(_), do: {:error, :forening_billing_not_ready}

  defp require_admin(%Exhs.Scope{actor: %{id: actor_id}}, forening_id) do
    case CheckHelpers.lookup_membership(actor_id, forening_id) do
      {:ok, %{role: :admin}} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp require_admin(_, _), do: {:error, :forbidden}

  defp require_self_or_admin(%Exhs.Scope{actor: %{id: actor_id}}, membership) do
    if actor_id == membership.user_id do
      :ok
    else
      case CheckHelpers.lookup_membership(actor_id, membership.forening_id) do
        {:ok, %{role: role}} when role in [:admin, :board] -> :ok
        _ -> {:error, :forbidden}
      end
    end
  end

  defp require_self_or_admin(_, _), do: {:error, :forbidden}

  defp require_self_or_admin_for_subscription(scope, subscription) do
    with {:ok, membership} <-
           Ash.get(Exhs.Organizations.Membership, subscription.membership_id,
             tenant: subscription.forening_id,
             authorize?: false
           ) do
      require_self_or_admin(scope, membership)
    end
  end
end
