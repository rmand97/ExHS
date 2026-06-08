defmodule ExhsWeb.AdminLive.AdminDashboardTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Exhs.Test.Builders

  defp on_subdomain(conn, forening), do: %{conn | host: "#{forening.subdomain}.lvh.me"}

  setup do
    %{forening: create_forening!(%{name: "Fodboldklubben", subdomain: "adm_dash"})}
  end

  describe "authorization" do
    test "unauthenticated user is redirected to sign-in", %{conn: conn, forening: forening} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} =
               conn |> on_subdomain(forening) |> live("/admin")
    end

    test "plain member is redirected to dashboard", %{conn: conn, forening: forening} do
      member = register_user!()
      join_forening!(forening, member)

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(member)
               |> on_subdomain(forening)
               |> live("/admin")
    end
  end

  describe "rendering" do
    test "admin sees the dashboard with member stats", %{conn: conn, forening: forening} do
      admin = register_user!()
      invite_member!(forening, admin, :admin)

      {:ok, _view, html} =
        conn |> log_in_user(admin) |> on_subdomain(forening) |> live("/admin")

      assert html =~ "Medlemmer"
      assert html =~ "Grupper"
    end
  end
end
