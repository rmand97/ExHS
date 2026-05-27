defmodule Exhs.Storage do
  @moduledoc false

  @callback put(key :: String.t(), body :: binary(), content_type :: String.t()) ::
              :ok | {:error, term()}
  @callback delete(key :: String.t()) :: :ok | {:error, term()}
  @callback presigned_put_url(key :: String.t(), content_type :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}
  @callback head(key :: String.t()) :: {:ok, map()} | {:error, term()}

  def put(key, body, content_type), do: impl().put(key, body, content_type)
  def delete(key), do: impl().delete(key)

  def presigned_put_url(key, content_type, opts \\ []),
    do: impl().presigned_put_url(key, content_type, opts)

  def head(key), do: impl().head(key)

  def public_url(key) do
    base = Application.get_env(:exhs, :s3_public_base_url, default_base_url())
    bucket = bucket()
    "#{base}/#{bucket}/#{key}"
  end

  def generate_key(resource_type, resource_id, field, filename) do
    ext = Path.extname(filename)
    uuid = Ash.UUID.generate()
    "uploads/#{resource_type}/#{resource_id}/#{field}/#{uuid}#{ext}"
  end

  def bucket, do: Application.get_env(:exhs, :s3_bucket)

  defp impl, do: Application.get_env(:exhs, :storage_client, Exhs.Storage.S3)

  defp default_base_url do
    s3_config = ExAws.Config.new(:s3)
    "#{s3_config.scheme}#{s3_config.host}:#{s3_config.port}"
  end
end
