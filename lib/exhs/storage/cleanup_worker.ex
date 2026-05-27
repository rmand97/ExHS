defmodule Exhs.Storage.CleanupWorker do
  @moduledoc false
  use Oban.Worker, queue: :default, max_attempts: 5

  def enqueue(key) when is_binary(key) do
    %{key: key}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"key" => key}}) do
    Exhs.Storage.delete(key)
  end
end
