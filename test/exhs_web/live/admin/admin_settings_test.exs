defmodule ExhsWeb.AdminLive.AdminSettingsTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Exhs.Test.Builders

  alias Exhs.Organizations

  defp on_subdomain(conn, forening), do: %{conn | host: "#{forening.subdomain}.lvh.me"}

  defp admin_setup(_context) do
    forening = create_forening!(%{name: "Fodboldklubben", subdomain: "set_adm"})
    admin = register_user!()
    invite_member!(forening, admin, :admin)

    member_user = register_user!(email: "medlem@example.com")
    membership = invite_member!(forening, member_user, :member)

    conn = build_conn() |> log_in_user(admin) |> on_subdomain(forening)

    %{conn: conn, forening: forening, admin: admin, membership: membership}
  end

  defp reload(forening) do
    {:ok, f} = Organizations.get_forening_by_id(forening.id, authorize?: false)
    f
  end

  describe "authorization" do
    setup do
      %{forening: create_forening!(%{subdomain: "set_auth"})}
    end

    test "unauthenticated user is redirected to sign-in", %{conn: conn, forening: forening} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} =
               conn |> on_subdomain(forening) |> live("/admin/settings")
    end

    test "plain member is redirected to dashboard", %{conn: conn, forening: forening} do
      member = register_user!()
      join_forening!(forening, member)

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(member)
               |> on_subdomain(forening)
               |> live("/admin/settings")
    end
  end

  describe "general settings" do
    setup :admin_setup

    test "mounts and shows current values", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/settings")
      assert html =~ "Indstillinger"
      assert html =~ "Fodboldklubben"
    end

    test "saving updates profile, branding, and kontingent", %{conn: conn, forening: forening} do
      {:ok, view, _html} = live(conn, "/admin/settings")

      view
      |> form("form",
        forening: %{
          "name" => "Ny Klub",
          "tagline" => "Sammen er vi stærke",
          "about" => "En god forening",
          "primary_color" => "#111111",
          "accent_color" => "#222222",
          "email_from_name" => "Klubben",
          "email_reply_to" => "svar@klub.dk",
          "kontingent_kr" => "300",
          "kontingent_currency" => "DKK",
          "kontingent_stripe_price_id" => "price_123"
        }
      )
      |> render_submit()

      f = reload(forening)
      assert f.name == "Ny Klub"
      assert f.branding["tagline"] == "Sammen er vi stærke"
      assert f.branding["email_reply_to"] == "svar@klub.dk"
      assert f.kontingent_amount_cents == 30_000
      assert f.kontingent_stripe_price_id == "price_123"
    end

    test "rejects a save with a blank name", %{conn: conn, forening: forening} do
      {:ok, view, _html} = live(conn, "/admin/settings")

      html =
        view
        |> form("form", forening: %{"name" => "", "kontingent_kr" => "300"})
        |> render_submit()

      assert html =~ "Kunne ikke gemme"
      assert reload(forening).name == "Fodboldklubben"
    end
  end

  describe "board read-only" do
    setup do
      forening = create_forening!(%{subdomain: "set_board"})
      board = register_user!()
      invite_member!(forening, board, :board)
      conn = build_conn() |> log_in_user(board) |> on_subdomain(forening)
      %{conn: conn, forening: forening, board: board}
    end

    test "board sees no save button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/settings")
      refute html =~ "Gem ændringer"
      assert html =~ "skrivebeskyttet"
    end

    test "the board form inputs are disabled", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/settings")
      assert html =~ "disabled"
    end

    test "the update policy rejects a board actor (server-side boundary)", %{
      forening: forening,
      board: board
    } do
      scope = %Exhs.Scope{actor: board, tenant: forening.id}

      assert {:error, _} =
               Organizations.update_forening(forening, %{name: "Kapret Klub"}, scope: scope)

      {:ok, reloaded} = Organizations.get_forening_by_id(forening.id, authorize?: false)
      refute reloaded.name == "Kapret Klub"
    end
  end

  describe "admin management" do
    setup :admin_setup

    test "promotes a member to admin", %{conn: conn, forening: forening, membership: membership} do
      {:ok, view, _html} = live(conn, "/admin/settings")

      view
      |> element("button", "Administratorer")
      |> render_click()

      view
      |> form("form[phx-submit='set_role']", %{"id" => membership.id, "role" => "admin"})
      |> render_submit()

      {:ok, reloaded} =
        Organizations.get_membership_by_id(membership.id, tenant: forening.id, authorize?: false)

      assert reloaded.role == :admin
    end

    test "demoting the only admin is rejected", %{conn: conn, forening: forening, admin: admin} do
      admin_membership = membership_for!(forening, admin)
      {:ok, view, _html} = live(conn, "/admin/settings")

      view |> element("button", "Administratorer") |> render_click()

      html =
        view
        |> element("select[phx-value-id='#{admin_membership.id}']")
        |> render_change(%{"id" => admin_membership.id, "role" => "member"})

      assert html =~ "mindst én admin"

      {:ok, reloaded} =
        Organizations.get_membership_by_id(admin_membership.id,
          tenant: forening.id,
          authorize?: false
        )

      assert reloaded.role == :admin
    end
  end

  describe "tenant isolation" do
    test "admins tab only lists own forening's members", %{conn: _conn} do
      f1 = create_forening!(%{subdomain: "set_iso1"})
      f2 = create_forening!(%{subdomain: "set_iso2"})

      admin = register_user!()
      invite_member!(f1, admin, :admin)

      other = register_user!(email: "other@iso.dk")
      invite_member!(f2, other, :member)

      conn = build_conn() |> log_in_user(admin) |> on_subdomain(f1)
      {:ok, view, _html} = live(conn, "/admin/settings")
      html = view |> element("button", "Administratorer") |> render_click()

      refute html =~ "other@iso.dk"
    end
  end
end
