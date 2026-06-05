defmodule ExhsWeb.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint ExhsWeb.Endpoint

      use ExhsWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import ExhsWeb.ConnCase
    end
  end

  setup tags do
    pid = Exhs.DataCase.setup_sandbox(tags)

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header(
        "user-agent",
        Phoenix.Ecto.SQL.Sandbox.encode_metadata(
          Phoenix.Ecto.SQL.Sandbox.metadata_for(Exhs.Repo, pid)
        )
      )

    {:ok, conn: conn}
  end

  alias AshAuthentication.Plug.Helpers, as: AuthHelpers

  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
