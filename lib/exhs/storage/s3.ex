defmodule Exhs.Storage.S3 do
  @moduledoc false
  @behaviour Exhs.Storage

  @impl true
  def put(key, body, content_type) do
    Exhs.Storage.bucket()
    |> ExAws.S3.put_object(key, body, content_type: content_type)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @impl true
  def delete(key) do
    Exhs.Storage.bucket()
    |> ExAws.S3.delete_object(key)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @impl true
  def presigned_put_url(key, content_type, opts) do
    expires_in = Keyword.get(opts, :expires_in, 3600)
    config = ExAws.Config.new(:s3)

    ExAws.S3.presigned_url(config, :put, Exhs.Storage.bucket(), key,
      expires_in: expires_in,
      query_params: [{"Content-Type", content_type}]
    )
  end

  @impl true
  def head(key) do
    Exhs.Storage.bucket()
    |> ExAws.S3.head_object(key)
    |> ExAws.request()
    |> case do
      {:ok, %{headers: headers}} ->
        {:ok, Map.new(headers, fn {k, v} -> {String.downcase(k), v} end)}

      {:error, _} = error ->
        error
    end
  end
end
