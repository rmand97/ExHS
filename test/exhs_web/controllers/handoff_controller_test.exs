defmodule ExhsWeb.HandoffControllerTest do
  use ExhsWeb.ConnCase, async: true

  describe "create/2 with valid token" do
    test "installs user_token in session and redirects to return_to", %{conn: conn} do
      user_jwt = "header.payload.signature"
      token = Phoenix.Token.sign(ExhsWeb.Endpoint, "handoff", user_jwt)

      conn = get(conn, "/auth/handoff?t=#{token}&return_to=/dashboard")

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, "user_token") == user_jwt
    end
  end

  describe "create/2 with invalid token" do
    test "expired token redirects without crashing or installing session", %{conn: conn} do
      token = Phoenix.Token.sign(ExhsWeb.Endpoint, "handoff", "some.jwt", signed_at: 0)

      conn = get(conn, "/auth/handoff?t=#{token}&return_to=/events")

      assert redirected_to(conn) == "/events"
      assert get_session(conn, "user_token") == nil
    end

    test "garbage token redirects without crashing", %{conn: conn} do
      conn = get(conn, "/auth/handoff?t=not_a_valid_token&return_to=/events")

      assert redirected_to(conn) == "/events"
    end
  end

  describe "create/2 without token" do
    test "return_to only redirects to return_to", %{conn: conn} do
      conn = get(conn, "/auth/handoff?return_to=/join")

      assert redirected_to(conn) == "/join"
    end

    test "no params redirects to /", %{conn: conn} do
      conn = get(conn, "/auth/handoff")

      assert redirected_to(conn) == "/"
    end
  end

  describe "open redirect protection" do
    test "absolute URL in return_to is sanitized to /", %{conn: conn} do
      conn = get(conn, "/auth/handoff?return_to=https%3A%2F%2Fevil.com%2Fsteal")

      assert redirected_to(conn) == "/"
    end

    test "protocol-relative URL in return_to is sanitized to /", %{conn: conn} do
      conn = get(conn, "/auth/handoff?return_to=%2F%2Fevil.com%2Fsteal")

      assert redirected_to(conn) == "/"
    end
  end
end
