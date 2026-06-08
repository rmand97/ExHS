defmodule ExhsWeb.PublicLive.OrderPagesTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Exhs.Test.Builders

  alias Exhs.Events

  defp on_subdomain(conn, forening), do: %{conn | host: "#{forening.subdomain}.lvh.me"}

  defp member_conn(conn, forening) do
    user = register_user!()
    join_forening!(forening, user)
    membership = membership_for!(forening, user)
    {conn |> log_in_user(user) |> on_subdomain(forening), user, membership}
  end

  defp order_with_ticket!(forening, membership, event) do
    tt = create_ticket_type!(forening, event, %{name: "Adgang", price_cents: 0})
    order = create_order!(forening, membership, event)
    add_ticket_item!(forening, order, tt)
    order
  end

  setup %{conn: conn} do
    forening = create_forening!(%{subdomain: "ord#{System.unique_integer([:positive])}"})
    event = create_published_event!(forening, %{title: "Sommerfest", membership_required: false})
    %{conn: conn, forening: forening, event: event}
  end

  describe "order show" do
    test "renders the order with a Danish status label", %{conn: conn, forening: f, event: e} do
      {conn, _user, m} = member_conn(conn, f)
      order = order_with_ticket!(f, m, e)
      {:ok, _paid} = Events.mark_order_paid(order, tenant: f.id, authorize?: false)

      {:ok, _view, html} = live(conn, "/orders/#{order.id}")

      assert html =~ "Betalt"
      refute html =~ "pending_payment"
    end

    test "live-updates the status badge when the order is marked paid", %{
      conn: conn,
      forening: f,
      event: e
    } do
      {conn, _user, m} = member_conn(conn, f)
      order = order_with_ticket!(f, m, e)

      {:ok, view, html} = live(conn, "/orders/#{order.id}")
      assert html =~ "Kladde"

      {:ok, _paid} = Events.mark_order_paid(order, tenant: f.id, authorize?: false)

      assert render(view) =~ "Betalt"
    end

    test "unknown order id redirects to /events", %{conn: conn, forening: f} do
      {conn, _user, _m} = member_conn(conn, f)

      assert {:error, {:redirect, %{to: "/events"}}} =
               live(conn, "/orders/#{Ash.UUID.generate()}")
    end

    test "another tenant's order id is not found (redirects)", %{conn: conn, forening: f, event: e} do
      # An order living in a different forening must never resolve on this one.
      other = create_forening!(%{subdomain: "ord_other#{System.unique_integer([:positive])}"})
      other_user = register_user!()
      join_forening!(other, other_user)
      other_m = membership_for!(other, other_user)
      other_event = create_published_event!(other, %{membership_required: false})
      foreign_order = order_with_ticket!(other, other_m, other_event)

      _ = e
      {conn, _user, _m} = member_conn(conn, f)

      assert {:error, {:redirect, %{to: "/events"}}} =
               live(conn, "/orders/#{foreign_order.id}")
    end

    test "anonymous visitor is redirected to sign-in", %{conn: conn, forening: f} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} =
               conn |> on_subdomain(f) |> live("/orders/#{Ash.UUID.generate()}")
    end
  end

  describe "order list" do
    test "shows the member's own orders with a Danish status label", %{
      conn: conn,
      forening: f,
      event: e
    } do
      {conn, _user, m} = member_conn(conn, f)
      order = order_with_ticket!(f, m, e)
      {:ok, _paid} = Events.mark_order_paid(order, tenant: f.id, authorize?: false)

      {:ok, _view, html} = live(conn, "/orders")

      assert html =~ "Sommerfest"
      assert html =~ "Betalt"
      refute html =~ "pending_payment"
    end

    test "does not show another member's orders", %{conn: conn, forening: f, event: e} do
      buyer = register_user!()
      join_forening!(f, buyer)
      order_with_ticket!(f, membership_for!(f, buyer), e)

      # A different member sees an empty list, not the buyer's order.
      {conn, _other, _m} = member_conn(conn, f)
      {:ok, _view, html} = live(conn, "/orders")

      assert html =~ "Du har ingen ordrer endnu."
    end

    test "anonymous visitor is redirected to sign-in", %{conn: conn, forening: f} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} =
               conn |> on_subdomain(f) |> live("/orders")
    end
  end
end
