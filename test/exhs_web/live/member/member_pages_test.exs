defmodule ExhsWeb.MemberLive.MemberPagesTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Exhs.Test.Builders

  describe "authentication" do
    test "dashboard redirects unauthenticated user to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/dashboard")
    end

    test "profile redirects unauthenticated user to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/profile")
    end

    test "registrations redirects unauthenticated user to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/registrations")
    end
  end

  describe "dashboard" do
    setup %{conn: conn} do
      user = register_user!()
      f1 = create_forening!(%{name: "Fodboldklubben", subdomain: "fodbold"})
      f2 = create_forening!(%{name: "Skakklubben", subdomain: "skak"})
      join_forening!(f1, user)
      join_forening!(f2, user)

      %{conn: log_in_user(conn, user), user: user, f1: f1, f2: f2}
    end

    test "shows memberships across multiple foreninger", %{conn: conn, f1: f1, f2: f2} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ f1.name
      assert html =~ f2.name
    end

    test "shows membership stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dashboard")

      assert html =~ "Foreninger"
      assert html =~ "Aktive medlemskaber"
    end

    test "does not show other users' memberships", %{conn: conn} do
      other = register_user!()
      f3 = create_forening!(%{name: "Hemmeligt Selskab", subdomain: "hemmeligt"})
      join_forening!(f3, other)

      {:ok, _view, html} = live(conn, "/dashboard")

      refute html =~ "Hemmeligt Selskab"
    end

    test "shows empty state when no memberships", %{conn: conn} do
      user = register_user!()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live("/dashboard")

      assert html =~ "Ingen medlemskaber endnu"
    end
  end

  describe "profile" do
    setup %{conn: conn} do
      user = register_user!()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders profile form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/profile")

      assert html =~ "Profil"
      assert html =~ "Fornavn"
      assert html =~ "Efternavn"
    end

    test "submits and persists profile changes", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, "/profile")

      view
      |> form("form", %{"form" => %{"first_name" => "Anders", "last_name" => "Andersen"}})
      |> render_submit()

      {:ok, updated} = Exhs.Accounts.get_user_by_id(user.id, actor: user)
      assert updated.first_name == "Anders"
      assert updated.last_name == "Andersen"
    end
  end

  describe "membership show" do
    setup %{conn: conn} do
      user = register_user!()
      forening = create_forening!(%{name: "Fodboldklubben", subdomain: "fodbold"})
      membership = join_forening!(forening, user)

      %{conn: log_in_user(conn, user), user: user, forening: forening, membership: membership}
    end

    test "shows membership details", %{conn: conn, membership: membership, forening: forening} do
      {:ok, _view, html} = live(conn, "/memberships/#{membership.id}")

      assert html =~ forening.name
      assert html =~ "Medlem"
      assert html =~ "Aktiv"
    end

    test "shows subscription info when present", %{
      conn: conn,
      membership: membership,
      forening: forening
    } do
      Exhs.Billing.create_subscription!(
        %{
          membership_id: membership.id,
          stripe_subscription_id: "sub_show_#{System.unique_integer([:positive])}",
          stripe_customer_id: "cus_show",
          status: :active,
          current_period_start: DateTime.utc_now(),
          current_period_end: DateTime.add(DateTime.utc_now(), 365, :day)
        },
        tenant: forening.id,
        authorize?: false
      )

      {:ok, _view, html} = live(conn, "/memberships/#{membership.id}")

      assert html =~ "Kontingent"
      assert html =~ "Aktiv"
    end

    test "redirects for non-owned membership", %{conn: conn} do
      other = register_user!()
      f2 = create_forening!()
      other_membership = join_forening!(f2, other)

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               live(conn, "/memberships/#{other_membership.id}")
    end

    test "redirects unauthenticated", %{conn: conn, membership: membership} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} =
               live(build_conn(), "/memberships/#{membership.id}")
    end
  end

  describe "payments" do
    setup %{conn: conn} do
      user = register_user!()
      forening = create_forening!(%{name: "Fodboldklubben", subdomain: "fodbold"})
      membership = join_forening!(forening, user)

      Exhs.Billing.record_payment!(
        %{
          payable_type: :subscription,
          payable_id: membership.id,
          amount_cents: 30_000,
          currency: "DKK",
          status: :succeeded,
          description: "Kontingent 2026",
          paid_at: DateTime.utc_now()
        },
        tenant: forening.id,
        authorize?: false
      )

      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows payment history", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/payments")

      assert html =~ "Kontingent 2026"
      assert html =~ "300 DKK"
      assert html =~ "Betalt"
    end

    test "redirects unauthenticated" do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), "/payments")
    end

    test "shows empty state when no payments" do
      user = register_user!()

      {:ok, _view, html} =
        build_conn()
        |> log_in_user(user)
        |> live("/payments")

      assert html =~ "Ingen betalinger endnu"
    end
  end

  describe "registrations" do
    setup %{conn: conn} do
      user = register_user!()
      f1 = create_forening!(%{name: "Fodboldklubben", subdomain: "fodbold"})
      f2 = create_forening!(%{name: "Skakklubben", subdomain: "skak"})
      m1 = join_forening!(f1, user)
      m2 = join_forening!(f2, user)

      event1 = create_published_event!(f1, %{title: "Fodboldkamp"})
      event2 = create_published_event!(f2, %{title: "Skakturnering"})
      tt1 = create_ticket_type!(f1, event1, %{name: "Standard"})
      tt2 = create_ticket_type!(f2, event2, %{name: "VIP"})
      register_for_event!(f1, m1, tt1)
      register_for_event!(f2, m2, tt2)

      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows registrations across foreninger", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/registrations")

      assert html =~ "Fodboldkamp"
      assert html =~ "Skakturnering"
    end

    test "does not show other users' registrations", %{conn: conn} do
      other = register_user!()
      f3 = create_forening!(%{name: "Hemmeligt", subdomain: "hemmeligt3"})
      m3 = join_forening!(f3, other)
      event3 = create_published_event!(f3, %{title: "Hemmelig Fest"})
      tt3 = create_ticket_type!(f3, event3)
      register_for_event!(f3, m3, tt3)

      {:ok, _view, html} = live(conn, "/registrations")

      refute html =~ "Hemmelig Fest"
    end

    test "shows empty state when no registrations", %{conn: conn} do
      user = register_user!()

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live("/registrations")

      assert html =~ "Ingen tilmeldinger endnu"
    end
  end
end
