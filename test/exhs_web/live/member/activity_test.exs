defmodule ExhsWeb.MemberLive.ActivityTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Exhs.Test.Builders

  alias Exhs.Organizations

  describe "authentication" do
    test "redirects unauthenticated user to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/activity")
    end
  end

  describe "activity display" do
    setup %{conn: conn} do
      user = register_user!()
      forening = create_forening!()
      invite_member!(forening, user, :admin)

      Organizations.create_group!(%{name: "Testgruppe"},
        tenant: forening.id,
        actor: user
      )

      %{conn: log_in_user(conn, user), user: user, forening: forening}
    end

    test "mounts and shows activity header", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/activity")

      assert html =~ "Aktivitet"
      assert html =~ "aktivitetshistorik"
    end

    test "shows events from user's actions", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/activity")

      assert html =~ "Gruppe"
      assert html =~ "Oprettet"
    end

    test "shows empty state when user has no activity", %{conn: conn} do
      new_user = register_user!()

      {:ok, _view, html} =
        conn
        |> log_in_user(new_user)
        |> live("/activity")

      assert html =~ "Ingen aktivitet endnu"
    end
  end

  describe "cross-forening activity" do
    setup %{conn: conn} do
      user = register_user!()
      f1 = create_forening!(%{name: "Forening Alpha", subdomain: "alpha"})
      f2 = create_forening!(%{name: "Forening Beta", subdomain: "beta"})
      invite_member!(f1, user, :admin)
      invite_member!(f2, user, :admin)

      Organizations.create_group!(%{name: "Alpha Gruppe"},
        tenant: f1.id,
        actor: user
      )

      Organizations.create_group!(%{name: "Beta Gruppe"},
        tenant: f2.id,
        actor: user
      )

      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows activity from multiple foreninger", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/activity")

      assert html =~ "Gruppe"
    end
  end

  describe "tenant isolation in LiveView" do
    setup %{conn: conn} do
      user_a = register_user!()
      user_b = register_user!()
      forening = create_forening!()
      invite_member!(forening, user_a, :admin)
      invite_member!(forening, user_b, :admin)

      Organizations.create_group!(%{name: "Group by A"},
        tenant: forening.id,
        actor: user_a
      )

      Organizations.create_group!(%{name: "Group by B"},
        tenant: forening.id,
        actor: user_b
      )

      %{conn: conn, user_a: user_a, user_b: user_b}
    end

    test "user A only sees their own events", %{user_a: user_a} do
      {:ok, _view, html} =
        build_conn()
        |> log_in_user(user_a)
        |> live("/activity")

      assert html =~ "Oprettet"
      assert html =~ "Gruppe"
    end

    test "user B does not see user A's events", %{user_b: user_b} do
      {:ok, _view, html} =
        build_conn()
        |> log_in_user(user_b)
        |> live("/activity")

      assert html =~ "Group by B"
      refute html =~ "Group by A"
    end

    test "admin changes in forening A visible only to that admin, not to member" do
      admin = register_user!()
      member = register_user!()
      forening = create_forening!()
      invite_member!(forening, admin, :admin)
      invite_member!(forening, member)

      Organizations.create_group!(%{name: "Admin's Private Group"},
        tenant: forening.id,
        actor: admin
      )

      {:ok, _view, admin_html} =
        build_conn()
        |> log_in_user(admin)
        |> live("/activity")

      {:ok, _view, member_html} =
        build_conn()
        |> log_in_user(member)
        |> live("/activity")

      assert admin_html =~ "Oprettet"
      refute member_html =~ "Admin&#39;s Private Group"
    end
  end

  describe "pagination" do
    setup %{conn: conn} do
      user = register_user!()
      forening = create_forening!()
      invite_member!(forening, user, :admin)

      for i <- 1..30 do
        Organizations.create_group!(%{name: "Gruppe #{i}"},
          tenant: forening.id,
          actor: user
        )
      end

      %{conn: log_in_user(conn, user), user: user}
    end

    test "first page shows paginator when more than one page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/activity")

      assert html =~ "Oprettet"
      refute html =~ "Ingen aktivitet"
      assert html =~ "page="
    end

    test "navigating to page 2 shows more events", %{conn: conn} do
      {:ok, _view, page1_html} = live(conn, "/activity")
      {:ok, _view, page2_html} = live(conn, "/activity?page=2")

      assert page1_html =~ "Oprettet"
      assert page2_html =~ "Oprettet"
    end

    test "page 2 shows different events than page 1", %{conn: conn} do
      {:ok, view1, _html} = live(conn, "/activity?limit=5")
      {:ok, view2, _html} = live(conn, "/activity?limit=5&page=2")

      page1_text = render(view1)
      page2_text = render(view2)

      refute page1_text == page2_text
    end
  end

  describe "filtering" do
    setup %{conn: conn} do
      user = register_user!()
      forening = create_forening!()
      invite_member!(forening, user, :admin)

      Organizations.create_group!(%{name: "Filter Gruppe"},
        tenant: forening.id,
        actor: user
      )

      member = register_user!()
      membership = invite_member!(forening, member)

      Organizations.set_member_role!(membership, %{role: :board},
        tenant: forening.id,
        actor: user
      )

      %{conn: log_in_user(conn, user), user: user}
    end

    test "resource type filter restricts visible events", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, "/activity?resource=Elixir.Exhs.Organizations.Group")

      assert html =~ "Gruppe"
    end
  end
end
