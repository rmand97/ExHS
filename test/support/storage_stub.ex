defmodule Exhs.Storage.Stub do
  @moduledoc false
  @behaviour Exhs.Storage

  def set_response(function_name, response) do
    Process.put({__MODULE__, function_name}, response)
  end

  def stored?(key), do: Process.get({__MODULE__, :stored, key}) == true

  @impl true
  def put(key, _body, content_type) do
    with nil <- Process.get({__MODULE__, :put}) do
      Process.put({__MODULE__, :stored, key}, true)
      Process.put({__MODULE__, :meta, key}, %{"content-type" => content_type})
      :ok
    end
  end

  @impl true
  def delete(key) do
    with nil <- Process.get({__MODULE__, :delete}) do
      Process.delete({__MODULE__, :stored, key})
      Process.delete({__MODULE__, :meta, key})
      :ok
    end
  end

  @impl true
  def presigned_put_url(key, _content_type, _opts) do
    with nil <- Process.get({__MODULE__, :presigned_put_url}) do
      bucket = Application.get_env(:exhs, :s3_bucket)
      {:ok, "http://localhost:9000/#{bucket}/#{key}?presigned=true"}
    end
  end

  @impl true
  def head(key) do
    with nil <- Process.get({__MODULE__, :head}) do
      if Process.get({__MODULE__, :stored, key}) do
        meta = Process.get({__MODULE__, :meta, key}) || %{}
        {:ok, Map.merge(%{"content-length" => "1024"}, meta)}
      else
        {:error, :not_found}
      end
    end
  end
end
