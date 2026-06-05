defmodule ExhsWeb.ForeningRedirectController do
  @moduledoc false
  use ExhsWeb, :controller

  # Generates a cross-domain handoff URL to a forening subdomain and redirects
  # the user there with a short-lived token so the session travels with them.
  def go(conn, %{"subdomain" => subdomain} = params) do
    case Exhs.Organizations.get_forening_by_subdomain(subdomain, authorize?: false) do
      {:ok, _forening} ->
        return_to = Map.get(params, "return_to", "/")
        destination = build_handoff_url(conn, subdomain, return_to)
        redirect(conn, external: destination)

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> put_view(ExhsWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  defp build_handoff_url(conn, subdomain, return_to) do
    base_host = Application.get_env(:exhs, :base_host, "exhs.dk")
    uri = ExhsWeb.Endpoint.url() |> URI.parse()

    base =
      URI.to_string(%{
        uri
        | host: "#{subdomain}.#{base_host}",
          path: "/auth/handoff",
          query: nil,
          fragment: nil
      })

    case get_session(conn, "user_token") do
      nil ->
        base <> "?" <> URI.encode_query(%{"return_to" => return_to})

      user_jwt ->
        token = Phoenix.Token.sign(ExhsWeb.Endpoint, "handoff", user_jwt)
        base <> "?" <> URI.encode_query(%{"t" => token, "return_to" => return_to})
    end
  end
end
