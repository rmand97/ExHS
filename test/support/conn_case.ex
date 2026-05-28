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
    Exhs.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  alias AshAuthentication.Plug.Helpers, as: AuthHelpers

  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AuthHelpers.store_in_session(user)
  end
end
