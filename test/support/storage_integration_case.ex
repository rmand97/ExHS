defmodule Exhs.StorageIntegrationCase do
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

    prev_client = Application.get_env(:exhs, :storage_client)
    Application.put_env(:exhs, :storage_client, Exhs.Storage.S3)

    on_exit(fn ->
      if prev_client,
        do: Application.put_env(:exhs, :storage_client, prev_client),
        else: Application.delete_env(:exhs, :storage_client)

      Sandbox.stop_owner(pid)
    end)

    :ok
  end
end
