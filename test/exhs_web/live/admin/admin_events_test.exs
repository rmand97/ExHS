defmodule ExhsWeb.AdminLive.AdminEventsTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Exhs.Test.Builders

  alias Exhs.Events

  defp on_subdomain(conn, forening), do: %{conn | host: "#{forening.subdomain}.lvh.me"}

  defp admin_setup(_context) do
    forening = create_forening!(%{name: "Klub", subdomain: "ev_adm"})
    admin = register_user!()
    invite_member!(forening, admin, :admin)

    conn = build_conn() |> log_in_user(admin) |> on_subdomain(forening)
    %{conn: conn, forening: forening}
  end

  describe "authorization" do
    setup do
      %{forening: create_forening!(%{subdomain: "ev_auth"})}
    end

    test "unauthenticated user is redirected to sign-in", %{conn: conn, forening: forening} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} =
               conn |> on_subdomain(forening) |> live("/admin/events")
    end

    test "plain member is redirected to dashboard", %{conn: conn, forening: forening} do
      member = register_user!()
      join_forening!(forening, member)

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(member)
               |> on_subdomain(forening)
               |> live("/admin/events")
    end
  end

  describe "events list" do
    setup :admin_setup

    test "splits events into upcoming, past, and drafts tabs", %{conn: conn, forening: forening} do
      create_published_event!(forening, %{
        title: "Kommende Fest",
        starts_at: DateTime.add(DateTime.utc_now(), 7, :day)
      })

      create_published_event!(forening, %{
        title: "Gammel Fest",
        starts_at: DateTime.add(DateTime.utc_now(), -7, :day)
      })

      create_event!(forening, %{title: "Kladde Fest"})

      {:ok, view, html} = live(conn, "/admin/events")
      assert html =~ "Kommende Fest"
      refute html =~ "Gammel Fest"
      refute html =~ "Kladde Fest"

      past = view |> element("a", "Tidligere") |> render_click()
      assert past =~ "Gammel Fest"

      drafts = render_patch(view, "/admin/events?tab=drafts")
      assert drafts =~ "Kladde Fest"
    end
  end

  describe "create event" do
    setup :admin_setup

    test "creates an event and navigates to its detail page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/events")

      view |> element("button", "Nyt event") |> render_click()

      {:ok, _show, html} =
        view
        |> form("#event-modal form",
          event: %{
            "title" => "Sommerfest",
            "starts_at" => "2026-08-01T18:00",
            "membership_required" => "true"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Sommerfest"
    end
  end

  describe "event detail" do
    setup :admin_setup

    test "publishes a draft event", %{conn: conn, forening: forening} do
      event = create_event!(forening, %{title: "Kladde"})
      {:ok, view, _html} = live(conn, "/admin/events/#{event.id}")

      view |> element("button", "Publicér") |> render_click()

      {:ok, reloaded} =
        Events.get_event_by_id(event.id, tenant: forening.id, authorize?: false)

      assert reloaded.published
    end

    test "adds a ticket type", %{conn: conn, forening: forening} do
      event = create_event!(forening, %{title: "Med billetter"})
      {:ok, view, _html} = live(conn, "/admin/events/#{event.id}")

      view |> element("button[phx-click='new_ticket']") |> render_click()

      html =
        view
        |> form("#ticket-modal form", ticket: %{"name" => "Voksen", "price_kr" => "150"})
        |> render_submit()

      assert html =~ "Voksen"
    end

    test "unpublishes a published event", %{conn: conn, forening: forening} do
      event = create_published_event!(forening, %{title: "Live"})
      {:ok, view, _html} = live(conn, "/admin/events/#{event.id}")

      view |> element("button", "Afpublicér") |> render_click()

      {:ok, reloaded} = Events.get_event_by_id(event.id, tenant: forening.id, authorize?: false)
      refute reloaded.published
    end

    test "edits event details", %{conn: conn, forening: forening} do
      event = create_event!(forening, %{title: "Gammel titel"})
      {:ok, view, _html} = live(conn, "/admin/events/#{event.id}")

      view |> element("button", "Rediger") |> render_click()

      view
      |> form("#event-edit-modal form",
        event: %{
          "title" => "Ny titel",
          "location" => "Klubhuset",
          "starts_at" => "2026-09-01T18:00",
          "membership_required" => "false"
        }
      )
      |> render_submit()

      {:ok, reloaded} = Events.get_event_by_id(event.id, tenant: forening.id, authorize?: false)
      assert reloaded.title == "Ny titel"
      assert reloaded.location == "Klubhuset"
      refute reloaded.membership_required
    end

    test "rejects an event edit with a blank title", %{conn: conn, forening: forening} do
      event = create_event!(forening, %{title: "Beholdes"})
      {:ok, view, _html} = live(conn, "/admin/events/#{event.id}")

      view |> element("button", "Rediger") |> render_click()

      html =
        view
        |> form("#event-edit-modal form",
          event: %{"title" => "", "starts_at" => "2026-09-01T18:00"}
        )
        |> render_submit()

      assert html =~ "Kunne ikke gemme"
      {:ok, reloaded} = Events.get_event_by_id(event.id, tenant: forening.id, authorize?: false)
      assert reloaded.title == "Beholdes"
    end

    test "edits a ticket type", %{conn: conn, forening: forening} do
      event = create_event!(forening, %{title: "Med billet"})
      tt = create_ticket_type!(forening, event, %{name: "Standard", price_cents: 5000})
      {:ok, view, _html} = live(conn, "/admin/events/#{event.id}")

      view
      |> element("button[phx-click='edit_ticket'][phx-value-id='#{tt.id}']")
      |> render_click()

      view
      |> form("#ticket-modal form", ticket: %{"name" => "VIP", "price_kr" => "500"})
      |> render_submit()

      {:ok, reloaded} =
        Events.get_ticket_type_by_id(tt.id, tenant: forening.id, authorize?: false)

      assert reloaded.name == "VIP"
      assert reloaded.price_cents == 50_000
    end

    test "deletes a ticket type", %{conn: conn, forening: forening} do
      event = create_event!(forening, %{title: "Slet billet"})
      tt = create_ticket_type!(forening, event, %{name: "Engang"})
      {:ok, view, _html} = live(conn, "/admin/events/#{event.id}")

      html =
        view
        |> element("button[phx-click='delete_ticket'][phx-value-id='#{tt.id}']")
        |> render_click()

      refute html =~ "Engang"

      {:ok, tickets} =
        Events.list_ticket_types_for_event(event.id, tenant: forening.id, authorize?: false)

      assert tickets == []
    end

    test "promotes a registration from the waitlist", %{conn: conn, forening: forening} do
      event = create_published_event!(forening, %{title: "Fest"})
      tt = create_ticket_type!(forening, event, %{capacity: 1})

      m1 = invite_member!(forening, register_user!(), :member)
      reg1 = register_for_event!(forening, m1, tt)
      m2 = invite_member!(forening, register_user!(), :member)
      reg2 = register_for_event!(forening, m2, tt)

      # capacity 1 → reg1 confirmed, reg2 waitlisted
      assert reg1.status == :confirmed
      assert reg2.status == :waitlisted

      {:ok, view, _html} = live(conn, "/admin/events/#{event.id}")
      view |> element("button[phx-value-id='#{reg2.id}']", "Bekræft") |> render_click()

      {:ok, promoted} =
        Events.get_registration_by_id(reg2.id, tenant: forening.id, authorize?: false)

      assert promoted.status == :confirmed
    end

    test "cancels a confirmed registration", %{conn: conn, forening: forening} do
      event = create_published_event!(forening, %{title: "Fest"})
      tt = create_ticket_type!(forening, event)
      membership = invite_member!(forening, register_user!(), :member)
      reg = register_for_event!(forening, membership, tt)
      assert reg.status == :confirmed

      {:ok, view, _html} = live(conn, "/admin/events/#{event.id}")
      view |> element("button[phx-value-id='#{reg.id}']", "Annullér") |> render_click()

      {:ok, cancelled} =
        Events.get_registration_by_id(reg.id, tenant: forening.id, authorize?: false)

      assert cancelled.status == :cancelled
    end
  end

  describe "create event validation" do
    setup :admin_setup

    test "rejects an event with a blank title", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/events")
      view |> element("button", "Nyt event") |> render_click()

      html =
        view
        |> form("#event-modal form",
          event: %{"title" => "", "starts_at" => "2026-08-01T18:00"}
        )
        |> render_submit()

      assert html =~ "Kunne ikke oprette"
    end
  end

  describe "board read-only" do
    setup do
      forening = create_forening!(%{subdomain: "ev_board"})
      board = register_user!()
      invite_member!(forening, board, :board)
      create_published_event!(forening, %{title: "Synligt Event"})
      conn = build_conn() |> log_in_user(board) |> on_subdomain(forening)
      %{conn: conn}
    end

    test "board sees events but no create button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/events")
      assert html =~ "Synligt Event"
      refute html =~ "Nyt event"
    end
  end

  describe "tenant isolation" do
    test "show rejects an event from another forening", %{conn: _conn} do
      f1 = create_forening!(%{subdomain: "ev_iso1"})
      f2 = create_forening!(%{subdomain: "ev_iso2"})

      admin = register_user!()
      invite_member!(f1, admin, :admin)
      other_event = create_event!(f2, %{title: "Fremmed"})

      conn = build_conn() |> log_in_user(admin) |> on_subdomain(f1)

      assert {:error, {:live_redirect, %{to: "/admin/events"}}} =
               live(conn, "/admin/events/#{other_event.id}")
    end
  end

  describe "registration CSV export" do
    setup :admin_setup

    test "exports registrations for an event", %{conn: conn, forening: forening} do
      event = create_published_event!(forening, %{title: "Fest"})
      tt = create_ticket_type!(forening, event)
      user = register_user!(email: "deltager@example.com")
      membership = invite_member!(forening, user, :member)
      register_for_event!(forening, membership, tt)

      conn = get(conn, "/admin/export/events/#{event.id}/registrations.csv")
      assert response_content_type(conn, :csv)
      body = response(conn, 200)
      assert body =~ "Navn,Email,Billettype"
      assert body =~ "deltager@example.com"
    end
  end
end
