defmodule Exhs.Test.StripeSigning do
  @moduledoc """
  Build a valid `Stripe-Signature` header for a given payload + webhook secret.
  Matches the verification done by `Stripe.Webhook.construct_event/4` so that
  controller tests can exercise the real signature path without hitting Stripe.
  """

  def signature_header(payload, secret, timestamp \\ System.system_time(:second)) do
    signed_payload = "#{timestamp}.#{payload}"

    signature =
      :crypto.mac(:hmac, :sha256, secret, signed_payload)
      |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{signature}"
  end
end
