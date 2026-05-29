defmodule ExhsWeb.LiveCurrentPath do
  @moduledoc false
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  def on_mount(:default, _params, _session, socket) do
    socket =
      attach_hook(socket, :set_current_path, :handle_params, fn _params, uri, socket ->
        {:cont, assign(socket, :current_path, URI.parse(uri).path)}
      end)

    {:cont, socket}
  end
end
