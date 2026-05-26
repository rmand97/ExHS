defmodule ExhsWeb.CacheBodyReader do
  @moduledoc """
  Stashes the raw request body in `conn.assigns[:raw_body]` for paths that need
  byte-for-byte access (notably the Stripe webhook for HMAC signature
  verification). For everything else the read is a no-op.
  """

  @cache_paths ~w(/webhook/stripe)

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)

    if conn.request_path in @cache_paths do
      {:ok, body, Plug.Conn.assign(conn, :raw_body, body)}
    else
      {:ok, body, conn}
    end
  end
end
