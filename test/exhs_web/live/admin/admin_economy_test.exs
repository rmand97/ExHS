defmodule ExhsWeb.AdminLive.AdminEconomyTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Exhs.Test.Builders

  alias Exhs.Billing

  defp on_subdomain(conn, forening), do: %{conn | host: "#{forening.subdomain}.lvh.me"}

  defp pay!(forening, membership, attrs) do
    Billing.record_payment!(
      Map.merge(
        %{
          payable_type: :subscription,
          payable_id: membership.id,
          amount_cents: 30_000,
          currency: "DKK",
          status: :succeeded,
          description: "Kontingent 2026",
          paid_at: DateTime.utc_now()
        },
        Map.new(attrs)
      ),
      tenant: forening.id,
      authorize?: false
    )
  end

  defp admin_setup(_context) do
    forening = create_forening!(%{name: "Fodboldklubben", subdomain: "eco_adm"})
    admin = register_user!()
    membership = invite_member!(forening, admin, :admin)

    payment = pay!(forening, membership, %{description: "Kontingent 2026", amount_cents: 30_000})
    pay!(forening, membership, %{status: :pending, amount_cents: 5_000, description: "Afventer"})

    conn = build_conn() |> log_in_user(admin) |> on_subdomain(forening)
    %{conn: conn, forening: forening, payment: payment}
  end

  describe "authorization" do
    setup do
      %{forening: create_forening!(%{subdomain: "eco_auth"})}
    end

    test "unauthenticated user is redirected to sign-in", %{conn: conn, forening: forening} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} =
               conn |> on_subdomain(forening) |> live("/admin/economy")
    end

    test "plain member is redirected to dashboard", %{conn: conn, forening: forening} do
      member = register_user!()
      join_forening!(forening, member)

      assert {:error, {:redirect, %{to: "/dashboard"}}} =
               conn
               |> log_in_user(member)
               |> on_subdomain(forening)
               |> live("/admin/economy")
    end
  end

  describe "dashboard" do
    setup :admin_setup

    test "shows realised revenue and payment rows", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/economy")
      assert html =~ "Økonomi"
      assert html =~ "Realiseret omsætning"
      assert html =~ "300 DKK"
      assert html =~ "Kontingent 2026"
    end

    test "status filter narrows the stream", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/economy")

      html =
        view
        |> form("form[phx-change='filter']")
        |> render_change(%{"filters" => %{"status" => "pending"}})

      assert html =~ "Afventer"
      refute html =~ "Kontingent 2026"
    end
  end

  describe "refund" do
    setup :admin_setup

    test "marks a succeeded payment as refunded", %{
      conn: conn,
      forening: forening,
      payment: payment
    } do
      {:ok, view, _html} = live(conn, "/admin/economy")

      view
      |> element("button[phx-value-id='#{payment.id}']")
      |> render_click()

      {:ok, reloaded} =
        Billing.get_payment_by_id(payment.id, tenant: forening.id, authorize?: false)

      assert reloaded.status == :refunded
    end
  end

  describe "board read-only" do
    setup do
      forening = create_forening!(%{subdomain: "eco_board"})
      board = register_user!()
      membership = invite_member!(forening, board, :board)
      payment = pay!(forening, membership, %{description: "Kontingent 2026"})
      conn = build_conn() |> log_in_user(board) |> on_subdomain(forening)
      %{conn: conn, forening: forening, board: board, payment: payment}
    end

    test "board sees payments but no refund button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/economy")
      assert html =~ "Kontingent 2026"
      refute html =~ "Markér refunderet"
    end

    test "the refund policy rejects a board actor (server-side boundary)", %{
      forening: forening,
      board: board,
      payment: payment
    } do
      scope = %Exhs.Scope{actor: board, tenant: forening.id}
      assert {:error, _} = Billing.mark_payment_refunded(payment, scope: scope)

      {:ok, reloaded} =
        Billing.get_payment_by_id(payment.id, tenant: forening.id, authorize?: false)

      assert reloaded.status == :succeeded
    end
  end

  describe "tenant isolation" do
    test "economy only shows the current forening's payments" do
      f1 = create_forening!(%{subdomain: "eco_iso1"})
      f2 = create_forening!(%{subdomain: "eco_iso2"})

      admin = register_user!()
      m1 = invite_member!(f1, admin, :admin)
      pay!(f1, m1, %{description: "Egen betaling"})

      other = register_user!()
      m2 = invite_member!(f2, other, :member)
      pay!(f2, m2, %{description: "Fremmed betaling"})

      conn = build_conn() |> log_in_user(admin) |> on_subdomain(f1)
      {:ok, _view, html} = live(conn, "/admin/economy")

      assert html =~ "Egen betaling"
      refute html =~ "Fremmed betaling"
    end
  end

  describe "CSV export" do
    setup :admin_setup

    test "admin downloads payments CSV", %{conn: conn} do
      conn = get(conn, "/admin/export/payments.csv")
      assert response_content_type(conn, :csv)
      body = response(conn, 200)
      assert body =~ "Dato,Beskrivelse,Type"
      assert body =~ "Kontingent 2026"
    end

    test "non-admin gets 403", %{forening: forening} do
      outsider = register_user!()
      conn = build_conn() |> log_in_user(outsider) |> on_subdomain(forening)
      conn = get(conn, "/admin/export/payments.csv")
      assert conn.status == 403
    end
  end
end
