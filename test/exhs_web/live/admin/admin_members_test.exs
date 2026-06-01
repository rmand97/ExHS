defmodule ExhsWeb.AdminLive.AdminMembersTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Exhs.Test.Builders

  alias Exhs.Organizations

  defp on_subdomain(conn, forening), do: %{conn | host: "#{forening.subdomain}.lvh.me"}

  defp admin_setup(_context) do
    forening = create_forening!(%{name: "Fodboldklubben", subdomain: "fodbold_adm"})
    admin = register_user!()
    invite_member!(forening, admin, :admin)

    member_user = register_user!(email: "medlem@example.com")
    membership = invite_member!(forening, member_user, :member)

    conn = build_conn() |> log_in_user(admin) |> on_subdomain(forening)

    %{
      conn: conn,
      forening: forening,
      admin: admin,
      membership: membership,
      member_user: member_user
    }
  end

  describe "authorization" do
    setup do
      forening = create_forening!(%{subdomain: "auth_adm"})
      %{forening: forening}
    end

    test "unauthenticated user is redirected to sign-in", %{conn: conn, forening: forening} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} =
               conn |> on_subdomain(forening) |> live("/admin/members")
    end

    test "plain member is redirected to dashboard", %{conn: conn, forening: forening} do
      member = register_user!()
      join_forening!(forening, member)

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(member)
               |> on_subdomain(forening)
               |> live("/admin/members")
    end

    test "non-member is redirected to dashboard", %{conn: conn, forening: forening} do
      outsider = register_user!()

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(outsider)
               |> on_subdomain(forening)
               |> live("/admin/members")
    end
  end

  describe "members list" do
    setup :admin_setup

    test "lists members of the forening", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/members")
      assert html =~ "Medlemmer"
      assert html =~ "medlem@example.com"
    end

    test "admin sees the invite button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/members")
      assert html =~ "Inviter medlem"
    end
  end

  describe "board role is read-only" do
    setup do
      forening = create_forening!(%{subdomain: "board_adm"})
      board = register_user!()
      invite_member!(forening, board, :board)
      conn = build_conn() |> log_in_user(board) |> on_subdomain(forening)
      %{conn: conn, forening: forening}
    end

    test "board can view but sees no invite button or checkboxes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/members")
      assert html =~ "Medlemmer"
      refute html =~ "Inviter medlem"
      refute html =~ ~s(phx-click="toggle_all")
    end
  end

  describe "invite" do
    setup :admin_setup

    test "inviting a new member adds them to the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/members")
      email = "ny_#{System.unique_integer([:positive])}@example.com"

      html =
        view
        |> form("#invite-modal form", %{invite: %{email: email, role: "member"}})
        |> render_submit()

      assert html =~ "inviteret"
      assert html =~ email
    end

    test "inviting an already-invited email shows an error", %{conn: conn, forening: forening} do
      existing = register_user!(email: "dup_invite@example.com")
      invite_member!(forening, existing, :member)

      {:ok, view, _html} = live(conn, "/admin/members")

      html =
        view
        |> form("#invite-modal form", %{
          invite: %{email: "dup_invite@example.com", role: "member"}
        })
        |> render_submit()

      assert html =~ "Kunne ikke" or html =~ "allerede"
    end
  end

  describe "bulk actions" do
    setup :admin_setup

    test "bulk deactivate changes selected members' status", %{
      conn: conn,
      forening: forening,
      membership: membership
    } do
      {:ok, view, _html} = live(conn, "/admin/members")

      view
      |> element("input[phx-click='toggle_select'][phx-value-id='#{membership.id}']")
      |> render_click()

      view |> element("button[phx-click='bulk_deactivate']") |> render_click()

      reloaded =
        Organizations.get_membership_by_id!(membership.id, tenant: forening.id, authorize?: false)

      assert reloaded.status == :inactive
    end
  end

  describe "member detail" do
    setup :admin_setup

    test "shows member profile and history", %{conn: conn, membership: membership} do
      {:ok, _view, html} = live(conn, "/admin/members/#{membership.id}")
      assert html =~ "medlem@example.com"
      assert html =~ "Historik"
    end

    test "changing role persists", %{conn: conn, forening: forening, membership: membership} do
      {:ok, view, _html} = live(conn, "/admin/members/#{membership.id}")

      view
      |> element("form[phx-change='set_role']")
      |> render_change(%{role: "board"})

      reloaded =
        Organizations.get_membership_by_id!(membership.id, tenant: forening.id, authorize?: false)

      assert reloaded.role == :board
    end

    test "deactivate then activate toggles status", %{
      conn: conn,
      forening: forening,
      membership: membership
    } do
      {:ok, view, _html} = live(conn, "/admin/members/#{membership.id}")

      view |> element("button[phx-click='deactivate']") |> render_click()

      assert Organizations.get_membership_by_id!(membership.id,
               tenant: forening.id,
               authorize?: false
             ).status == :inactive

      view |> element("button[phx-click='activate']") |> render_click()

      assert Organizations.get_membership_by_id!(membership.id,
               tenant: forening.id,
               authorize?: false
             ).status == :active
    end

    test "rejects a membership id from another forening", %{conn: conn} do
      other_f = create_forening!(%{subdomain: "other_adm"})
      other_user = register_user!()
      other_membership = invite_member!(other_f, other_user, :member)

      assert {:error, {:live_redirect, %{to: "/admin/members"}}} =
               live(conn, "/admin/members/#{other_membership.id}")
    end
  end

  describe "groups CRUD" do
    setup :admin_setup

    test "creating a group adds it to the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/groups")

      view |> element("button[phx-click='new']") |> render_click()

      html =
        view
        |> form("#group-modal form", %{group: %{name: "U12 hold", color: "#ff0000"}})
        |> render_submit()

      assert html =~ "U12 hold"
    end
  end

  describe "tenant isolation" do
    setup :admin_setup

    test "admin does not see another forening's members", %{conn: conn} do
      other_f = create_forening!(%{subdomain: "iso_adm"})
      other_user = register_user!(email: "skjult@example.com")
      invite_member!(other_f, other_user, :member)

      {:ok, _view, html} = live(conn, "/admin/members")
      refute html =~ "skjult@example.com"
    end
  end

  describe "CSV export" do
    setup :admin_setup

    test "admin can download members CSV", %{conn: conn} do
      conn = get(conn, "/admin/export/members.csv")
      assert response_content_type(conn, :csv)
      body = response(conn, 200)
      assert body =~ "Navn,Email"
      assert body =~ "medlem@example.com"
    end

    test "non-admin is forbidden", %{forening: forening} do
      outsider = register_user!()

      conn =
        build_conn()
        |> log_in_user(outsider)
        |> on_subdomain(forening)
        |> get("/admin/export/members.csv")

      assert conn.status == 403
    end
  end
end
