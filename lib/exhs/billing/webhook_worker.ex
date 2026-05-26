defmodule Exhs.Billing.WebhookWorker do
  @moduledoc """
  Oban worker that applies a verified Stripe webhook event. Uniqueness on
  `:event_id` provides idempotency — the same event id arriving twice will
  enqueue only once, even across completed jobs.
  """
  use Oban.Worker,
    queue: :stripe,
    max_attempts: 5,
    unique: [period: :infinity, keys: [:event_id]]

  alias Exhs.Billing.Webhook

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event" => event}}) do
    Webhook.apply_event(event)
    :ok
  end
end
