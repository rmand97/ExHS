defmodule ExhsWeb.AdminExportController do
  @moduledoc """
  CSV exports for the admin area. Authorizes the same admin/board roles as the
  admin LiveViews using the forening resolved by the subdomain plug.
  """
  use ExhsWeb, :controller

  alias Exhs.Checks.Helpers
  alias Exhs.Organizations
  alias Exhs.Organizations.Forening
  alias Exhs.Organizations.MemberFilter
  alias ExhsWeb.Labels

  @admin_roles [:admin, :board]

  def members(conn, params) do
    with %Forening{} = forening <- conn.assigns[:current_forening],
         %{} = user <- conn.assigns[:current_user],
         {:ok, %{role: role}} when role in @admin_roles <-
           Helpers.lookup_membership(user.id, forening.id) do
      scope = %Exhs.Scope{actor: user, tenant: forening.id}

      {:ok, all} =
        Organizations.list_memberships(scope: scope, load: [:user, :groups], authorize?: false)

      filters = %{
        q: params["q"],
        status: params["status"],
        role: params["role"],
        group: params["group"],
        sort: params["sort"]
      }

      csv = all |> MemberFilter.apply(filters) |> build_csv()

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", ~s(attachment; filename="medlemmer.csv"))
      |> send_resp(200, csv)
    else
      _ -> conn |> put_status(:forbidden) |> text("Forbidden")
    end
  end

  defp build_csv(memberships) do
    header = ["Navn", "Email", "Rolle", "Status", "Grupper", "Medlem siden"]

    rows =
      Enum.map(memberships, fn m ->
        [
          Labels.member_name(m),
          to_string(m.user.email),
          Labels.role_label(m.role),
          Labels.status_label(m.status),
          Enum.map_join(m.groups, ", ", & &1.name),
          Labels.format_date(m.joined_at)
        ]
      end)

    [header | rows]
    |> Enum.map_join("\r\n", &csv_line/1)
  end

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
