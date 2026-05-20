defmodule ExhsWeb.Plugs.Subdomain do
  @moduledoc false
  import Plug.Conn

  @reserved ~w(www app admin api dev mail ftp)

  def init(opts), do: opts

  def call(conn, _opts) do
    case extract_subdomain(conn) do
      nil ->
        conn

      subdomain when subdomain in @reserved ->
        conn

      subdomain ->
        case Exhs.Organizations.get_forening_by_subdomain(subdomain, authorize?: false) do
          {:ok, forening} ->
            conn
            |> assign(:current_forening, forening)
            |> assign(:current_tenant, forening.id)

          {:error, _} ->
            conn
            |> put_status(:not_found)
            |> Phoenix.Controller.put_view(ExhsWeb.ErrorHTML)
            |> Phoenix.Controller.render("404.html")
            |> halt()
        end
    end
  end

  defp extract_subdomain(conn) do
    host = conn.host
    suffix = find_suffix(host)

    case suffix do
      nil -> nil
      s -> strip_suffix(host, s)
    end
  end

  defp find_suffix(host) do
    base = Application.get_env(:exhs, :base_host, "exhs.dk")

    [base, "lvh.me"]
    |> Enum.map(&("." <> &1))
    |> Enum.find(&String.ends_with?(host, &1))
  end

  defp strip_suffix(host, suffix) do
    case String.trim_trailing(host, suffix) do
      "" -> nil
      sub -> sub
    end
  end
end
