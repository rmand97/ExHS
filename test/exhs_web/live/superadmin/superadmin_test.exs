defmodule ExhsWeb.SuperadminLive.SuperadminTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Exhs.Test.Builders

  alias Exhs.Organizations

  describe "authorization" do
    test "unauthenticated user is redirected to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/superadmin")
    end

    test "non-superadmin user is redirected to dashboard", %{conn: conn} do
      user = register_user!()

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn |> log_in_user(user) |> live("/superadmin")
    end
  end

  describe "dashboard" do
    setup do
      superadmin = register_user!(superadmin: true)
      %{conn: log_in_user(build_conn(), superadmin), superadmin: superadmin}
    end

    test "lists foreninger with stats", %{conn: conn} do
      create_forening!(%{name: "Synlig Klub", subdomain: "sa_list"})

      {:ok, _view, html} = live(conn, "/superadmin")
      assert html =~ "Superadmin"
      assert html =~ "Synlig Klub"
      assert html =~ "Foreninger"
    end

    test "provisions a new forening with an admin", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/superadmin")

      view |> element("button", "Ny forening") |> render_click()

      html =
        view
        |> form("#forening-modal form",
          forening: %{
            "name" => "Frisk Forening",
            "subdomain" => "frisk",
            "admin_email" => "chef@frisk.dk"
          }
        )
        |> render_submit()

      assert html =~ "Frisk Forening"

      {:ok, forening} = Organizations.get_forening_by_subdomain("frisk", authorize?: false)
      members = Organizations.list_memberships!(tenant: forening.id, authorize?: false)
      assert Enum.any?(members, &(&1.role == :admin))
    end

    test "archives a forening", %{conn: conn} do
      forening = create_forening!(%{name: "Lukket Klub", subdomain: "sa_arch"})
      {:ok, view, _html} = live(conn, "/superadmin")

      view |> element("button[phx-value-id='#{forening.id}']") |> render_click()

      {:ok, reloaded} = Organizations.get_forening_by_id(forening.id, authorize?: false)
      refute reloaded.active
    end
  end
end
