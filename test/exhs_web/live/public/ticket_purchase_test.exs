defmodule ExhsWeb.PublicLive.TicketPurchaseTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Exhs.Test.Builders

  alias Exhs.Events

  setup do
    forening = create_forening!(%{subdomain: "kob#{System.unique_integer([:positive])}"})
    event = create_published_event!(forening, %{title: "Sommerfest", membership_required: false})
    %{forening: forening, event: event}
  end

  defp forening_conn(conn, forening), do: %{conn | host: "#{forening.subdomain}.lvh.me"}

  defp member_conn(conn, forening) do
    user = register_user!()
    join_forening!(forening, user)
    {conn |> log_in_user(user) |> forening_conn(forening), user}
  end

  test "free ticket: select and confirm in place", %{conn: conn, forening: f, event: e} do
    tt = create_ticket_type!(f, e, %{name: "Gratis", price_cents: 0})
    {conn, user} = member_conn(conn, f)

    {:ok, view, _html} = live(conn, "/events/#{e.id}")

    view |> element("button", "Vælg") |> render_click()
    render_submit(form(view, "form"), %{responses: %{}})

    {path, _flash} = assert_redirect(view)
    assert path =~ ~r{^/orders/}

    {:ok, regs} = Events.list_my_registrations(actor: user)
    assert Enum.any?(regs, &(&1.ticket_type_id == tt.id and &1.status == :confirmed))
  end

  test "anonymous viewer can load an event with a gated ticket", %{
    conn: conn,
    forening: f,
    event: e
  } do
    tt = create_ticket_type!(f, e, %{name: "Presale", price_cents: 0})
    group = create_group!(f)
    gate_ticket_type!(f, tt, [group])

    {:ok, _view, html} = live(forening_conn(conn, f), "/events/#{e.id}")

    assert html =~ "Presale"
    assert html =~ "Log ind for at tilmelde"
  end

  test "gated ticket is disabled for ineligible member", %{conn: conn, forening: f, event: e} do
    tt = create_ticket_type!(f, e, %{name: "Presale", price_cents: 0})
    group = create_group!(f)
    gate_ticket_type!(f, tt, [group])
    {conn, _user} = member_conn(conn, f)

    {:ok, _view, html} = live(conn, "/events/#{e.id}")

    assert html =~ "Presale"
    assert html =~ "Kun for berettigede grupper"
    refute html =~ ~s(phx-click="select_ticket")
  end

  test "sold out ticket shows a reason and no select", %{conn: conn, forening: f, event: e} do
    tt = create_ticket_type!(f, e, %{name: "Begrænset", price_cents: 0, capacity: 1})
    other = register_user!()
    join_forening!(f, other)
    register_for_event!(f, membership_for!(f, other), tt)

    {conn, _user} = member_conn(conn, f)
    {:ok, _view, html} = live(conn, "/events/#{e.id}")

    assert html =~ "Udsolgt"
  end

  test "live availability decrements seats_left across a broadcast", %{
    conn: conn,
    forening: f,
    event: e
  } do
    tt = create_ticket_type!(f, e, %{name: "Live", price_cents: 0, capacity: 3})
    {conn, _user} = member_conn(conn, f)

    {:ok, view, html} = live(conn, "/events/#{e.id}")
    assert html =~ "kun 3 tilbage"

    other = register_user!()
    join_forening!(f, other)
    register_for_event!(f, membership_for!(f, other), tt)

    assert render(view) =~ "kun 2 tilbage"
  end

  test "waitlisted viewer sees position, which advances live on promotion", %{
    conn: conn,
    forening: f,
    event: e
  } do
    tt = create_ticket_type!(f, e, %{name: "Venteliste", price_cents: 0, capacity: 1})

    # one confirmed buyer takes the only seat
    holder = register_user!()
    join_forening!(f, holder)
    register_for_event!(f, membership_for!(f, holder), tt)

    # one member ahead of the viewer on the waitlist
    ahead = register_user!()
    join_forening!(f, ahead)
    ahead_reg = register_for_event!(f, membership_for!(f, ahead), tt)
    assert ahead_reg.status == :waitlisted

    # the viewer joins the waitlist behind them
    {conn, user} = member_conn(conn, f)
    register_for_event!(f, membership_for!(f, user), tt)

    {:ok, view, html} = live(conn, "/events/#{e.id}")
    assert html =~ "plads 2 af 2"

    Events.promote_registration!(ahead_reg, tenant: f.id, authorize?: false)

    assert render(view) =~ "plads 1 af 1"
  end
end
