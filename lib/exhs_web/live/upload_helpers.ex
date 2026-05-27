defmodule ExhsWeb.UploadHelpers do
  @moduledoc false

  alias Exhs.Storage

  def presign_upload(entry, socket) do
    key =
      Storage.generate_key(
        socket.assigns.upload_resource_type,
        socket.assigns.upload_resource_id,
        socket.assigns.upload_field,
        entry.client_name
      )

    {:ok, url} = Storage.presigned_put_url(key, entry.client_type)

    meta = %{uploader: "S3", key: key, url: url}
    {:ok, meta, socket}
  end

  def consume_upload_key(socket, upload_name) do
    socket
    |> Phoenix.LiveView.consume_uploaded_entries(upload_name, fn _upload, entry ->
      {:ok, entry.meta["key"]}
    end)
    |> List.first()
  end

  def maybe_cleanup_old_key(nil, _new_key), do: :ok
  def maybe_cleanup_old_key(_old, nil), do: :ok

  def maybe_cleanup_old_key(old_key, new_key) when old_key != new_key do
    Storage.CleanupWorker.enqueue(old_key)
  end

  def maybe_cleanup_old_key(_, _), do: :ok
end
