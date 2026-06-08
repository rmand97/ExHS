defmodule ExhsWeb.PublicLive.PublicPagesTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Exhs.Test.Builders

  setup do
    forening =
      create_forening!(%{
        name: "Testforening",
        subdomain: "testforening",
        branding: %{
          "tagline" => "Vi tester ting",
          "about" => "En forening dedikeret til at teste ting."
        }
      })

    event = create_published_event!(forening, %{title: "Fodboldturnering"})
    _ticket = create_ticket_type!(forening, event, %{name: "Standard", price_cents: 5000})

    %{forening: forening, event: event}
  end

  defp forening_conn(conn, forening) do
    %{conn | host: "#{forening.subdomain}.lvh.me"}
  end

  describe "PublicLive.Home" do
    test "renders marketing page without subdomain", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Alt du behøver til din"
      assert html =~ "Exhs"
    end

    test "renders forening home with subdomain", %{conn: conn, forening: forening} do
      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/")

      assert html =~ forening.name
      assert html =~ "Vi tester ting"
      assert html =~ "Kommende events"
    end

    test "shows upcoming events on forening home", %{conn: conn, forening: forening} do
      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/")

      assert html =~ "Fodboldturnering"
    end
  end

  describe "PublicLive.Events.Index" do
    test "lists published events", %{conn: conn, forening: forening} do
      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/events")

      assert html =~ "Fodboldturnering"
      assert html =~ "Events"
    end

    test "redirects without subdomain", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/events")
    end
  end

  describe "PublicLive.Events.Show" do
    test "shows event details and ticket types", %{conn: conn, forening: forening, event: event} do
      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/events/#{event.id}")

      assert html =~ "Fodboldturnering"
      assert html =~ "Standard"
      assert html =~ "50,00"
    end

    test "redirects for nonexistent event", %{conn: conn, forening: forening} do
      assert {:error, {:redirect, _}} =
               conn
               |> forening_conn(forening)
               |> live("/events/#{Ash.UUID.generate()}")
    end
  end

  describe "tenant isolation" do
    setup %{conn: conn} do
      other_forening = create_forening!(%{name: "Anden Forening", subdomain: "anden"})
      other_event = create_published_event!(other_forening, %{title: "Hemmelig Fest"})
      create_ticket_type!(other_forening, other_event, %{name: "VIP Billet", price_cents: 10_000})

      %{other_forening: other_forening, other_event: other_event, conn: conn}
    end

    test "forening A home does not show forening B events", %{
      conn: conn,
      forening: forening
    } do
      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/")

      assert html =~ "Fodboldturnering"
      refute html =~ "Hemmelig Fest"
    end

    test "forening A events index does not list forening B events", %{
      conn: conn,
      forening: forening
    } do
      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/events")

      assert html =~ "Fodboldturnering"
      refute html =~ "Hemmelig Fest"
    end

    test "cannot view forening B event via forening A subdomain", %{
      conn: conn,
      forening: forening,
      other_event: other_event
    } do
      assert {:error, {:redirect, _}} =
               conn
               |> forening_conn(forening)
               |> live("/events/#{other_event.id}")
    end

    test "forening B sees only its own events", %{
      conn: conn,
      other_forening: other_forening
    } do
      {:ok, _view, html} =
        conn
        |> forening_conn(other_forening)
        |> live("/events")

      assert html =~ "Hemmelig Fest"
      refute html =~ "Fodboldturnering"
    end
  end

  describe "PublicLive.Join" do
    test "renders join page with forening info", %{conn: conn, forening: forening} do
      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/join")

      assert html =~ "Bliv medlem af #{forening.name}"
      assert html =~ "Opret konto"
    end

    test "redirects without subdomain", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/join")
    end
  end

  describe "branding" do
    test "renders forening CSS custom properties from branding", %{conn: conn} do
      forening =
        create_forening!(%{
          name: "Branded Forening",
          subdomain: "branded",
          branding: %{
            "primary_color" => "oklch(0.6 0.2 250)",
            "accent_color" => "oklch(0.7 0.15 150)",
            "tagline" => "Vi har farver"
          }
        })

      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/")

      assert html =~ "--color-primary: oklch(0.6 0.2 250)"
      assert html =~ "--color-accent: oklch(0.7 0.15 150)"
    end

    test "renders forening logo when logo_url is set", %{conn: conn} do
      forening =
        create_forening!(%{name: "Logo Forening", subdomain: "logof"})
        |> Exhs.Organizations.update_forening!(%{logo_url: "https://example.com/logo.png"},
          authorize?: false
        )

      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/")

      assert html =~ "https://example.com/logo.png"
    end

    test "renders initial fallback when no logo_url", %{conn: conn, forening: forening} do
      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/")

      assert html =~ String.first(forening.name)
    end
  end

  describe "join flow" do
    test "authenticated user can join forening", %{conn: conn, forening: forening} do
      user = register_user!()

      {:ok, view, html} =
        conn
        |> log_in_user(user)
        |> forening_conn(forening)
        |> live("/join")

      assert html =~ "Bliv medlem"
      refute html =~ "Du er allerede medlem"

      html = view |> element("button", "Bliv medlem") |> render_click()

      assert html =~ "Du er allerede medlem"

      membership = membership_for!(forening, user)
      assert membership.role == :member
      assert membership.status == :active
    end

    test "already-member user sees member state", %{conn: conn, forening: forening} do
      user = register_user!()
      join_forening!(forening, user)

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> forening_conn(forening)
        |> live("/join")

      assert html =~ "Du er allerede medlem"
    end

    test "unauthenticated user sees registration CTA", %{conn: conn, forening: forening} do
      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/join")

      assert html =~ "Opret konto"
      assert html =~ "/register"
    end
  end

  describe "PublicLive.Events.Show - purchase panel" do
    test "member sees a Vælg button for an available ticket", %{
      conn: conn,
      forening: forening,
      event: event
    } do
      user = register_user!()
      join_forening!(forening, user)

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> forening_conn(forening)
        |> live("/events/#{event.id}")

      assert html =~ "Vælg"
    end

    test "anonymous visitor is prompted to log in", %{
      conn: conn,
      forening: forening,
      event: event
    } do
      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/events/#{event.id}")

      assert html =~ "Log ind for at tilmelde"
    end
  end

  describe "logged-in member navigation" do
    test "member on forening site sees Din side link without being logged out", %{
      conn: conn,
      forening: forening
    } do
      user = register_user!()
      join_forening!(forening, user)
      authed = log_in_user(conn, user)

      {:ok, _view, html} = live(authed, "/dashboard")
      assert html =~ "Dashboard"

      {:ok, _view, html} = authed |> forening_conn(forening) |> live("/")
      assert html =~ "Din side"
      assert html =~ forening.name
    end

    test "bliv_member link and join page accessible even with active membership", %{
      conn: conn,
      forening: forening
    } do
      user = register_user!()
      join_forening!(forening, user)
      authed = conn |> log_in_user(user) |> forening_conn(forening)

      {:ok, _view, html} = live(authed, "/")
      assert html =~ "Bliv medlem"

      {:ok, _view, html} = live(authed, "/join")
      assert html =~ "Du er allerede medlem"
    end
  end

  describe "admin link in forening navbar" do
    test "admin of the forening sees an Admin link", %{conn: conn, forening: forening} do
      admin = register_user!()
      invite_member!(forening, admin, :admin)

      {:ok, _view, html} = conn |> log_in_user(admin) |> forening_conn(forening) |> live("/")
      assert html =~ ~s(href="/admin")
    end

    test "board member sees an Admin link", %{conn: conn, forening: forening} do
      board = register_user!()
      invite_member!(forening, board, :board)

      {:ok, _view, html} = conn |> log_in_user(board) |> forening_conn(forening) |> live("/")
      assert html =~ ~s(href="/admin")
    end

    test "plain member does not see an Admin link", %{conn: conn, forening: forening} do
      member = register_user!()
      join_forening!(forening, member)

      {:ok, _view, html} = conn |> log_in_user(member) |> forening_conn(forening) |> live("/")
      refute html =~ ~s(href="/admin")
    end

    test "anonymous visitor does not see an Admin link", %{conn: conn, forening: forening} do
      {:ok, _view, html} = conn |> forening_conn(forening) |> live("/")
      refute html =~ ~s(href="/admin")
    end

    test "an admin of a different forening does not see an Admin link here", %{
      conn: conn,
      forening: forening
    } do
      other = create_forening!(%{name: "Anden", subdomain: "anden"})
      admin_elsewhere = register_user!()
      invite_member!(other, admin_elsewhere, :admin)

      {:ok, _view, html} =
        conn |> log_in_user(admin_elsewhere) |> forening_conn(forening) |> live("/")

      refute html =~ ~s(href="/admin")
    end
  end

  describe "unknown subdomain" do
    test "returns 404 for nonexistent forening subdomain", %{conn: conn} do
      conn =
        conn
        |> Map.put(:host, "ikkeeksisterende.lvh.me")
        |> get("/")

      assert conn.status == 404
      assert conn.resp_body =~ "Siden blev ikke fundet"
    end
  end

  describe "reserved subdomains" do
    for reserved <- ~w(www app admin api) do
      test "#{reserved}.lvh.me passes through as main domain", %{conn: conn} do
        {:ok, _view, html} =
          conn
          |> Map.put(:host, "#{unquote(reserved)}.lvh.me")
          |> live("/")

        assert html =~ "Exhs"
        refute html =~ "Siden blev ikke fundet"
      end
    end
  end

  describe "unpublished events" do
    test "unpublished event absent from events index", %{conn: conn, forening: forening} do
      create_event!(forening, %{title: "Internt Møde"})

      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/events")

      assert html =~ "Fodboldturnering"
      refute html =~ "Internt Møde"
    end

    test "unpublished event absent from forening home", %{conn: conn, forening: forening} do
      create_event!(forening, %{title: "Intern Begivenhed"})

      {:ok, _view, html} =
        conn
        |> forening_conn(forening)
        |> live("/")

      refute html =~ "Intern Begivenhed"
    end
  end
end
