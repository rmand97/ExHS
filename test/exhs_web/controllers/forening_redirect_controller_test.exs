defmodule ExhsWeb.ForeningRedirectControllerTest do
  use ExhsWeb.ConnCase, async: true

  import Exhs.Test.Builders

  describe "go/2" do
    test "unauthenticated: redirects to handoff URL without token", %{conn: conn} do
      forening = create_forening!(%{subdomain: "redir_anon"})
      conn = get(conn, "/go/forening/#{forening.subdomain}")
      location = redirected_to(conn)

      assert location =~ "#{forening.subdomain}.lvh.me"
      assert location =~ "/auth/handoff"
      assert location =~ "return_to=%2F"
      refute location =~ "&t="
    end

    test "authenticated: redirect includes signed token", %{conn: conn} do
      user = register_user!()
      forening = create_forening!(%{subdomain: "redir_auth"})
      conn = conn |> log_in_user(user) |> get("/go/forening/#{forening.subdomain}")
      location = redirected_to(conn)

      assert location =~ "#{forening.subdomain}.lvh.me"
      assert location =~ "/auth/handoff"
      assert location =~ "t="
    end

    test "custom return_to is forwarded", %{conn: conn} do
      forening = create_forening!(%{subdomain: "redir_ret"})
      conn = get(conn, "/go/forening/#{forening.subdomain}?return_to=/events/abc")
      location = redirected_to(conn)

      assert location =~ "return_to=%2Fevents%2Fabc"
    end
  end
end
