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

  describe "sign out" do
    setup %{conn: conn} do
      user = register_user!()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "DELETE /sign-out redirects", %{conn: conn} do
      conn = delete(conn, "/sign-out")
      assert redirected_to(conn) =~ "/"
    end

    test "session cleared after sign out — protected routes redirect to sign-in", %{conn: conn} do
      conn = delete(conn, "/sign-out")
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, "/dashboard")
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

    test "shows an Admin link only for admin/board memberships", %{conn: conn} do
      admin = register_user!()
      f = create_forening!(%{name: "Adminklub", subdomain: "adminklub"})
      invite_member!(f, admin, :admin)

      {:ok, _view, html} = conn |> log_in_user(admin) |> live("/dashboard")
      assert html =~ "/go/forening/adminklub?return_to=%2Fadmin"

      member = register_user!()
      f2 = create_forening!(%{name: "Menigklub", subdomain: "menigklub"})
      join_forening!(f2, member)

      {:ok, _view, html2} = conn |> log_in_user(member) |> live("/dashboard")
      refute html2 =~ "return_to=%2Fadmin"
    end

    test "shows a Superadmin link only for superadmins", %{conn: conn} do
      super_user = register_user!(superadmin: true)
      {:ok, _view, html} = conn |> log_in_user(super_user) |> live("/dashboard")
      assert html =~ "/superadmin"

      regular = register_user!()
      {:ok, _view, html2} = conn |> log_in_user(regular) |> live("/dashboard")
      refute html2 =~ "/superadmin"
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

    test "redirects unauthenticated", %{conn: _conn, membership: membership} do
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

  describe "dashboard livefilter" do
    setup %{conn: conn} do
      user = register_user!()
      f1 = create_forening!(%{name: "Adminforening", subdomain: "admin_club"})
      f2 = create_forening!(%{name: "Bestyrelsesforening", subdomain: "board_club"})
      f3 = create_forening!(%{name: "Medlemsforening", subdomain: "member_club"})
      m1 = join_forening!(f1, user)
      m2 = join_forening!(f2, user)
      _m3 = join_forening!(f3, user)

      Exhs.Organizations.set_member_role!(m1, %{role: :admin}, tenant: f1.id, authorize?: false)
      Exhs.Organizations.set_member_role!(m2, %{role: :board}, tenant: f2.id, authorize?: false)

      %{conn: log_in_user(conn, user), f1: f1, f2: f2, f3: f3}
    end

    test "role filter shows only matching membership", %{conn: conn, f1: f1, f2: f2, f3: f3} do
      {:ok, _view, html} = live(conn, "/dashboard?role=admin")

      assert html =~ f1.name
      refute html =~ f2.name
      refute html =~ f3.name
    end

    test "role filter board shows only board membership", %{conn: conn, f1: f1, f2: f2, f3: f3} do
      {:ok, _view, html} = live(conn, "/dashboard?role=board")

      assert html =~ f2.name
      refute html =~ f1.name
      refute html =~ f3.name
    end
  end

  describe "membership show - kontingent type" do
    test "shows Gratis when forening has no kontingent amount", %{conn: conn} do
      user = register_user!()
      forening = create_forening!(%{subdomain: "gratis_f"})
      membership = join_forening!(forening, user)

      {:ok, _view, html} = conn |> log_in_user(user) |> live("/memberships/#{membership.id}")

      assert html =~ "Gratis"
    end

    test "shows Løbende abonnement when forening has stripe price", %{conn: conn} do
      user = register_user!()

      forening =
        create_forening!(%{subdomain: "recurring_f"})
        |> Exhs.Organizations.update_forening!(
          %{
            kontingent_amount_cents: 30_000,
            kontingent_stripe_price_id: "price_test_123"
          },
          authorize?: false
        )

      membership = join_forening!(forening, user)

      {:ok, _view, html} = conn |> log_in_user(user) |> live("/memberships/#{membership.id}")

      assert html =~ "Løbende abonnement"
      assert html =~ "300 DKK"
    end

    test "shows Enkeltbetaling when forening has amount but no stripe price", %{conn: conn} do
      user = register_user!()

      forening =
        create_forening!(%{subdomain: "onetime_f"})
        |> Exhs.Organizations.update_forening!(
          %{kontingent_amount_cents: 15_000},
          authorize?: false
        )

      membership = join_forening!(forening, user)

      {:ok, _view, html} = conn |> log_in_user(user) |> live("/memberships/#{membership.id}")

      assert html =~ "Enkeltbetaling"
      assert html =~ "150 DKK"
    end
  end

  describe "membership show - leave forening" do
    setup %{conn: conn} do
      user = register_user!()
      forening = create_forening!(%{name: "Fodboldklubben", subdomain: "fodbold_leave"})
      membership = join_forening!(forening, user)

      %{
        conn: log_in_user(conn, user),
        user: user,
        forening: forening,
        membership: membership
      }
    end

    test "leave button redirects to dashboard", %{conn: conn, membership: membership} do
      {:ok, view, _html} = live(conn, "/memberships/#{membership.id}")

      assert {:error, {:live_redirect, %{to: "/dashboard"}}} =
               view |> element("[phx-click='leave']") |> render_click()
    end

    test "leave removes the membership", %{
      conn: conn,
      membership: membership,
      forening: forening
    } do
      {:ok, view, _html} = live(conn, "/memberships/#{membership.id}")
      view |> element("[phx-click='leave']") |> render_click()

      remaining = Exhs.Organizations.list_memberships!(tenant: forening.id, authorize?: false)
      refute Enum.any?(remaining, &(&1.id == membership.id))
    end
  end

  describe "profile - validation errors" do
    setup %{conn: conn} do
      user = register_user!()
      %{conn: log_in_user(conn, user)}
    end

    test "too-long phone renders error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/profile")

      html =
        view
        |> form("form", %{"form" => %{"phone" => String.duplicate("1", 25)}})
        |> render_submit()

      assert html =~ "Profil"
      assert html =~ "length"
    end
  end

  describe "membership show - subscription cancellation state" do
    setup %{conn: conn} do
      user = register_user!()
      forening = create_forening!(%{name: "Fodboldklubben", subdomain: "fodbold_sub"})
      membership = join_forening!(forening, user)

      Exhs.Billing.create_subscription!(
        %{
          membership_id: membership.id,
          stripe_subscription_id: "sub_cancel_#{System.unique_integer([:positive])}",
          stripe_customer_id: "cus_cancel",
          status: :active,
          current_period_start: DateTime.utc_now(),
          current_period_end: DateTime.add(DateTime.utc_now(), 30, :day),
          cancel_at_period_end: true
        },
        tenant: forening.id,
        authorize?: false
      )

      %{conn: log_in_user(conn, user), membership: membership}
    end

    test "renders cancellation notice when cancel_at_period_end is true", %{
      conn: conn,
      membership: membership
    } do
      {:ok, _view, html} = live(conn, "/memberships/#{membership.id}")

      assert html =~ "Opsagt — udløber ved periodens slut"
    end
  end

  describe "payments - filter by type" do
    setup %{conn: conn} do
      user = register_user!()
      forening = create_forening!(%{name: "Fodboldklubben", subdomain: "fodbold_pay"})
      membership = join_forening!(forening, user)

      Exhs.Billing.record_payment!(
        %{
          payable_type: :subscription,
          payable_id: membership.id,
          amount_cents: 30_000,
          currency: "DKK",
          status: :succeeded,
          description: "Kontingentbetaling",
          paid_at: DateTime.utc_now()
        },
        tenant: forening.id,
        authorize?: false
      )

      Exhs.Billing.record_payment!(
        %{
          payable_type: :registration,
          payable_id: membership.id,
          amount_cents: 5_000,
          currency: "DKK",
          status: :succeeded,
          description: "Eventbetaling",
          paid_at: DateTime.utc_now()
        },
        tenant: forening.id,
        authorize?: false
      )

      %{conn: log_in_user(conn, user)}
    end

    test "filtering by subscription type shows only subscription payment", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/payments?payable_type=subscription")

      assert html =~ "Kontingentbetaling"
      refute html =~ "Eventbetaling"
    end

    test "filtering by registration type shows only registration payment", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/payments?payable_type=registration")

      assert html =~ "Eventbetaling"
      refute html =~ "Kontingentbetaling"
    end
  end

  describe "upcoming events" do
    setup %{conn: conn} do
      user = register_user!()
      f1 = create_forening!(%{name: "Fodboldklubben", subdomain: "fodbold_ev"})
      f2 = create_forening!(%{name: "Skakklubben", subdomain: "skak_ev"})
      join_forening!(f1, user)
      join_forening!(f2, user)

      create_published_event!(f1, %{title: "Fodboldkamp 2026"})
      create_published_event!(f2, %{title: "Skakturnering 2026"})

      %{conn: log_in_user(conn, user)}
    end

    test "mounts and shows events from member foreninger", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/upcoming")

      assert html =~ "Kommende events"
      assert html =~ "Fodboldkamp 2026"
      assert html =~ "Skakturnering 2026"
    end

    test "does not show events from non-member foreninger", %{conn: conn} do
      other = register_user!()
      f3 = create_forening!(%{name: "Hemmeligt", subdomain: "hemmeligt_ev"})
      join_forening!(f3, other)
      create_published_event!(f3, %{title: "Hemmelig Begivenhed"})

      {:ok, _view, html} = live(conn, "/upcoming")

      refute html =~ "Hemmelig Begivenhed"
    end

    test "shows empty state when foreninger have no events", %{conn: conn} do
      user = register_user!()
      forening = create_forening!(%{name: "Tom Forening", subdomain: "tom_ev"})
      join_forening!(forening, user)

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live("/upcoming")

      assert html =~ "Ingen kommende events"
    end

    test "unauthenticated redirects to sign-in" do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(build_conn(), "/upcoming")
    end
  end

  describe "upcoming events - forening filter" do
    setup %{conn: conn} do
      user = register_user!()
      f1 = create_forening!(%{name: "Fodboldklubben", subdomain: "fodbold_evf"})
      f2 = create_forening!(%{name: "Skakklubben", subdomain: "skak_evf"})
      join_forening!(f1, user)
      join_forening!(f2, user)

      create_published_event!(f1, %{title: "Fodboldkamp Filter"})
      create_published_event!(f2, %{title: "Skakturnering Filter"})

      %{conn: log_in_user(conn, user)}
    end

    test "forening filter shows only events from that forening", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/upcoming?forening=Fodboldklubben")

      assert html =~ "Fodboldkamp Filter"
      refute html =~ "Skakturnering Filter"
    end

    test "forening filter for other forening hides first forening events", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/upcoming?forening=Skakklubben")

      assert html =~ "Skakturnering Filter"
      refute html =~ "Fodboldkamp Filter"
    end
  end

  describe "upcoming events - unpublished" do
    setup %{conn: conn} do
      user = register_user!()
      forening = create_forening!(%{name: "Fodboldklubben", subdomain: "fodbold_unpub"})
      join_forening!(forening, user)

      create_event!(forening, %{title: "Intern Arrangement"})

      %{conn: log_in_user(conn, user)}
    end

    test "unpublished event does not appear in upcoming", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/upcoming")

      refute html =~ "Intern Arrangement"
    end
  end

  describe "registrations - status filter" do
    setup %{conn: conn} do
      user = register_user!()
      forening = create_forening!(%{subdomain: "regf_status"})
      membership = join_forening!(forening, user)
      event = create_published_event!(forening, %{title: "Testturneringen"})
      tt = create_ticket_type!(forening, event)
      register_for_event!(forening, membership, tt)

      %{conn: log_in_user(conn, user)}
    end

    test "confirmed filter shows confirmed registration", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/registrations?status=confirmed")

      assert html =~ "Testturneringen"
    end

    test "other status filter hides confirmed registration", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/registrations?status=cancelled")

      refute html =~ "Testturneringen"
    end
  end

  describe "payments - cross-forening" do
    setup %{conn: conn} do
      user = register_user!()
      f1 = create_forening!(%{subdomain: "pay_f1"})
      f2 = create_forening!(%{subdomain: "pay_f2"})
      m1 = join_forening!(f1, user)
      m2 = join_forening!(f2, user)

      Exhs.Billing.record_payment!(
        %{
          payable_type: :subscription,
          payable_id: m1.id,
          amount_cents: 30_000,
          currency: "DKK",
          status: :succeeded,
          description: "Kontingent Forening 1",
          paid_at: DateTime.utc_now()
        },
        tenant: f1.id,
        authorize?: false
      )

      Exhs.Billing.record_payment!(
        %{
          payable_type: :subscription,
          payable_id: m2.id,
          amount_cents: 15_000,
          currency: "DKK",
          status: :succeeded,
          description: "Kontingent Forening 2",
          paid_at: DateTime.utc_now()
        },
        tenant: f2.id,
        authorize?: false
      )

      %{conn: log_in_user(conn, user)}
    end

    test "shows payments from both foreninger", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/payments")

      assert html =~ "Kontingent Forening 1"
      assert html =~ "Kontingent Forening 2"
    end
  end
end
