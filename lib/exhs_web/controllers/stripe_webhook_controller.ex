defmodule ExhsWeb.StripeWebhookController do
  @moduledoc """
  Receives Stripe webhook events. Verifies the HMAC signature against the
  configured Connect endpoint secret, then enqueues `Exhs.Billing.WebhookWorker`
  with the event keyed on `stripe_event_id` for idempotent processing.

  The raw payload is captured by `ExhsWeb.CacheBodyReader` (configured on
  `Plug.Parsers`) and read back via `conn.assigns[:raw_body]`; verification
  must run against the byte-for-byte original, not a re-serialized form.
  """
  use ExhsWeb, :controller

  alias Exhs.Billing.WebhookWorker

  def create(conn, _params) do
    secret = Application.get_env(:exhs, :stripe_webhook_signing_secret)
    raw = conn.assigns[:raw_body] || ""

    with [signature | _] <- Plug.Conn.get_req_header(conn, "stripe-signature"),
         {:ok, _event} <- Stripe.Webhook.construct_event(raw, signature, secret),
         event_map = Jason.decode!(raw),
         {:ok, _job} <- enqueue(event_map) do
      send_resp(conn, 200, "ok")
    else
      _ -> send_resp(conn, 400, "invalid")
    end
  end

  defp enqueue(%{"id" => event_id} = event) do
    %{event_id: event_id, event: event}
    |> WebhookWorker.new()
    |> Oban.insert()
  end

  defp enqueue(_), do: {:error, :missing_event_id}
end
