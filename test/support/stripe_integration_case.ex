defmodule Exhs.StripeIntegrationCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Exhs.Test.Builders
    end
  end

  setup _tags do
    pid = Sandbox.start_owner!(Exhs.Repo, shared: true)

    prev_client = Application.get_env(:exhs, :stripe_client)
    prev_base_url = Application.get_env(:stripity_stripe, :api_base_url)
    prev_api_key = Application.get_env(:stripity_stripe, :api_key)

    Application.put_env(:stripity_stripe, :api_base_url, "http://localhost:12111")
    Application.put_env(:stripity_stripe, :api_key, "sk_test_fake")
    Application.put_env(:exhs, :stripe_client, Exhs.Billing.StripeClient.Live)

    on_exit(fn ->
      Application.put_env(:exhs, :stripe_client, prev_client)

      if prev_base_url,
        do: Application.put_env(:stripity_stripe, :api_base_url, prev_base_url),
        else: Application.delete_env(:stripity_stripe, :api_base_url)

      if prev_api_key,
        do: Application.put_env(:stripity_stripe, :api_key, prev_api_key),
        else: Application.delete_env(:stripity_stripe, :api_key)

      Sandbox.stop_owner(pid)
    end)

    :ok
  end
end
