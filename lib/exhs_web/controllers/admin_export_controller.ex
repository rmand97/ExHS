defmodule ExhsWeb.AdminExportController do
  @moduledoc """
  CSV exports for the admin area. Authorizes the same admin/board roles as the
  admin LiveViews using the forening resolved by the subdomain plug.
  """
  use ExhsWeb, :controller

  alias Exhs.Billing
  alias Exhs.Billing.PaymentFilter
  alias Exhs.Checks.Helpers
  alias Exhs.Events
  alias Exhs.Organizations
  alias Exhs.Organizations.Forening
  alias Exhs.Organizations.MemberFilter
  alias ExhsWeb.DisplayHelpers
  alias ExhsWeb.Labels

  @admin_roles [:admin, :board]

  def members(conn, params) do
    with_admin_scope(conn, fn scope ->
      filters = %{
        q: params["q"],
        status: params["status"],
        role: params["role"],
        group: params["group"],
        sort: params["sort"]
      }

      {:ok, all} =
        Organizations.list_memberships(scope: scope, load: [:user, :groups], authorize?: false)

      csv = all |> MemberFilter.apply(filters) |> build_members_csv()
      download(conn, gettext("members.csv"), csv)
    end)
  end

  def payments(conn, params) do
    with_admin_scope(conn, fn scope ->
      filters = %{
        q: params["q"],
        status: params["status"],
        type: params["type"],
        month: params["month"],
        sort: params["sort"]
      }

      {:ok, all} = Billing.list_payments(scope: scope, authorize?: false)
      csv = all |> PaymentFilter.apply(filters) |> build_payments_csv()
      download(conn, gettext("payments.csv"), csv)
    end)
  end

  def event_registrations(conn, %{"event_id" => event_id}) do
    with_admin_scope(conn, fn scope ->
      case Events.get_event_by_id(event_id,
             scope: scope,
             load: [:ticket_types],
             authorize?: false
           ) do
        {:ok, event} ->
          ticket_ids = MapSet.new(event.ticket_types, & &1.id)

          {:ok, all} =
            Events.list_registrations(
              scope: scope,
              load: [:ticket_type, membership: [:user]],
              authorize?: false
            )

          csv =
            all
            |> Enum.filter(&MapSet.member?(ticket_ids, &1.ticket_type_id))
            |> build_registrations_csv()

          download(conn, gettext("registrations.csv"), csv)

        _ ->
          conn |> put_status(:not_found) |> text("Not found")
      end
    end)
  end

  defp with_admin_scope(conn, fun) do
    with %Forening{} = forening <- conn.assigns[:current_forening],
         %{} = user <- conn.assigns[:current_user],
         {:ok, %{role: role}} when role in @admin_roles <-
           Helpers.lookup_membership(user.id, forening.id) do
      fun.(%Exhs.Scope{actor: user, tenant: forening.id})
    else
      _ -> conn |> put_status(:forbidden) |> text("Forbidden")
    end
  end

  defp download(conn, filename, csv) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end

  defp build_payments_csv(payments) do
    header = [
      gettext("Date"),
      gettext("Description"),
      gettext("Type"),
      gettext("Amount"),
      gettext("Currency"),
      gettext("Status"),
      "Stripe Payment Intent"
    ]

    rows =
      Enum.map(payments, fn p ->
        [
          DisplayHelpers.format_date(p.paid_at),
          p.description || "",
          Labels.payable_type_label(p.payable_type),
          to_string(div(p.amount_cents, 100)),
          p.currency,
          Labels.payment_status_label(p.status),
          p.stripe_payment_intent_id || ""
        ]
      end)

    to_csv([header | rows])
  end

  defp build_members_csv(memberships) do
    header = [
      gettext("Name"),
      "Email",
      gettext("Role"),
      gettext("Status"),
      gettext("Groups"),
      gettext("Member since")
    ]

    rows =
      Enum.map(memberships, fn m ->
        [
          Labels.member_name(m),
          to_string(m.user.email),
          DisplayHelpers.role_label(m.role),
          DisplayHelpers.status_label(m.status),
          Enum.map_join(m.groups, ", ", & &1.name),
          DisplayHelpers.format_date(m.joined_at)
        ]
      end)

    to_csv([header | rows])
  end

  defp build_registrations_csv(registrations) do
    header = [
      gettext("Name"),
      "Email",
      gettext("Ticket type"),
      gettext("Status"),
      gettext("Registered")
    ]

    rows =
      Enum.map(registrations, fn r ->
        [
          Labels.member_name(r.membership),
          to_string(r.membership.user.email),
          r.ticket_type.name,
          Labels.reg_status_label(r.status),
          DisplayHelpers.format_date(r.registered_at)
        ]
      end)

    to_csv([header | rows])
  end

  defp to_csv(rows), do: Enum.map_join(rows, "\r\n", &csv_line/1)

  defp csv_line(fields), do: Enum.map_join(fields, ",", &escape/1)

  defp escape(field) do
    str = to_string(field)

    if String.contains?(str, [",", "\"", "\n", "\r"]) do
      ~s("#{String.replace(str, "\"", "\"\"")}")
    else
      str
    end
  end
end
