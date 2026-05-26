defmodule Exhs.Billing.Webhook do
  @moduledoc """
  Applies the effects of a verified Stripe event. Called exclusively by
  `Exhs.Billing.WebhookWorker`. Idempotency is enforced one layer up (Oban
  unique-job keyed on `stripe_event_id`), so this module assumes the event is
  ready to apply and does not re-check for duplicates.
  """
  alias Exhs.Billing
  alias Exhs.Billing.{Payment, Subscription}
  alias Exhs.Organizations

  require Ash.Query

  def apply_event(%{"type" => type} = event), do: dispatch(type, event)

  defp dispatch("checkout.session.completed", _event), do: :ok

  defp dispatch("account.updated", %{"data" => %{"object" => account}}) do
    sync_account_status(account)
  end

  defp dispatch(
         "customer.subscription.created",
         %{"data" => %{"object" => sub}} = event
       ) do
    upsert_subscription(sub, account_id(event))
  end

  defp dispatch(
         "customer.subscription.updated",
         %{"data" => %{"object" => sub}} = event
       ) do
    upsert_subscription(sub, account_id(event))
  end

  defp dispatch(
         "customer.subscription.deleted",
         %{"data" => %{"object" => sub}} = event
       ) do
    terminate_subscription(sub, account_id(event))
  end

  defp dispatch(
         "invoice.payment_succeeded",
         %{"data" => %{"object" => invoice}} = event
       ) do
    record_invoice_payment(invoice, account_id(event), :succeeded)
  end

  defp dispatch(
         "invoice.payment_failed",
         %{"data" => %{"object" => invoice}} = event
       ) do
    record_invoice_payment(invoice, account_id(event), :failed)
  end

  defp dispatch("charge.refunded", %{"data" => %{"object" => charge}} = event) do
    refund_payment(charge, account_id(event))
  end

  defp dispatch(_other, _event), do: :ok

  defp sync_account_status(account) do
    with {:ok, forening} <- forening_for_account(account["id"]) do
      Organizations.set_forening_stripe_account(
        forening,
        %{
          stripe_account_id: account["id"],
          stripe_account_status: connect_status_for(account)
        },
        authorize?: false
      )
    end
  end

  defp connect_status_for(%{"charges_enabled" => true, "payouts_enabled" => true}), do: :active
  defp connect_status_for(%{"details_submitted" => true}), do: :restricted
  defp connect_status_for(_), do: :onboarding

  defp upsert_subscription(sub, account_id) do
    with {:ok, forening} <- forening_for_account(account_id),
         {:ok, membership} <- membership_for_customer(sub["customer"], forening.id) do
      attrs = subscription_attrs(sub)

      case existing_subscription(sub["id"], forening.id) do
        nil ->
          Billing.create_subscription(
            Map.merge(attrs, %{
              membership_id: membership.id,
              stripe_subscription_id: sub["id"],
              stripe_customer_id: sub["customer"]
            }),
            tenant: forening.id,
            authorize?: false
          )

        existing ->
          Billing.sync_subscription(existing, attrs, authorize?: false)
      end
    end
  end

  defp terminate_subscription(sub, account_id) do
    with {:ok, forening} <- forening_for_account(account_id),
         %Subscription{} = existing <- existing_subscription(sub["id"], forening.id) do
      Billing.sync_subscription(existing, %{status: :canceled}, authorize?: false)
    else
      _ -> :ok
    end
  end

  defp record_invoice_payment(invoice, account_id, status) do
    with {:ok, forening} <- forening_for_account(account_id),
         {:ok, membership} <- membership_for_customer(invoice["customer"], forening.id) do
      intent_id = invoice["payment_intent"]

      attrs = %{
        payable_type: :subscription,
        payable_id: membership.id,
        amount_cents: invoice["amount_paid"] || invoice["amount_due"] || 0,
        currency: String.upcase(invoice["currency"] || "dkk"),
        status: status,
        stripe_payment_intent_id: intent_id,
        stripe_charge_id: invoice["charge"],
        description: "Kontingent — invoice #{invoice["id"]}",
        paid_at: timestamp_or_nil(invoice["status_transitions"]["paid_at"])
      }

      case existing_payment_by_intent(intent_id, forening.id) do
        nil ->
          Billing.record_payment(attrs, tenant: forening.id, authorize?: false)

        existing ->
          {:ok, existing}
      end
    end
  end

  defp refund_payment(charge, account_id) do
    with {:ok, forening} <- forening_for_account(account_id),
         intent_id when is_binary(intent_id) <- charge["payment_intent"],
         %Payment{} = existing <- existing_payment_by_intent(intent_id, forening.id) do
      Billing.mark_payment_refunded(existing, authorize?: false)
    else
      _ -> :ok
    end
  end

  defp subscription_attrs(sub) do
    %{
      status: String.to_existing_atom(sub["status"]),
      current_period_start: timestamp_or_nil(sub["current_period_start"]),
      current_period_end: timestamp_or_nil(sub["current_period_end"]),
      cancel_at_period_end: sub["cancel_at_period_end"] || false
    }
  end

  defp existing_subscription(stripe_id, forening_id) do
    Subscription
    |> Ash.Query.filter(stripe_subscription_id == ^stripe_id)
    |> Ash.read_one!(tenant: forening_id, authorize?: false)
  end

  defp existing_payment_by_intent(nil, _forening_id), do: nil

  defp existing_payment_by_intent(intent_id, forening_id) do
    Payment
    |> Ash.Query.filter(stripe_payment_intent_id == ^intent_id)
    |> Ash.read_one!(tenant: forening_id, authorize?: false)
  end

  defp forening_for_account(nil), do: {:error, :account_missing}

  defp forening_for_account(account_id) do
    require Ash.Query

    case Exhs.Organizations.Forening
         |> Ash.Query.filter(stripe_account_id == ^account_id)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> {:error, :forening_not_found}
      {:ok, forening} -> {:ok, forening}
      {:error, err} -> {:error, err}
    end
  end

  defp membership_for_customer(nil, _forening_id), do: {:error, :customer_missing}

  defp membership_for_customer(customer_id, forening_id) do
    require Ash.Query

    case Exhs.Organizations.Membership
         |> Ash.Query.filter(stripe_customer_id == ^customer_id)
         |> Ash.read_one(tenant: forening_id, authorize?: false) do
      {:ok, nil} -> {:error, :membership_not_found}
      {:ok, membership} -> {:ok, membership}
      {:error, err} -> {:error, err}
    end
  end

  defp account_id(%{"account" => account_id}) when is_binary(account_id), do: account_id
  defp account_id(_), do: nil

  defp timestamp_or_nil(nil), do: nil
  defp timestamp_or_nil(unix) when is_integer(unix), do: DateTime.from_unix!(unix)
end
