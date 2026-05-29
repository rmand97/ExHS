defmodule ExhsWeb.HandoffController do
  @moduledoc false
  use ExhsWeb, :controller

  # Cross-domain session handoff — receives a short-lived Phoenix.Token wrapping
  # the user's AshAuthentication JWT and installs it into the Plug session.
  # Used when navigating from the main domain to a forening subdomain so that
  # the user remains logged in without relying on cross-subdomain cookie sharing.
  def create(conn, %{"t" => token, "return_to" => return_to}) do
    case Phoenix.Token.verify(ExhsWeb.Endpoint, "handoff", token, max_age: 300) do
      {:ok, user_jwt} ->
        conn
        |> put_session("user_token", user_jwt)
        |> redirect(to: sanitize_return_to(return_to))

      {:error, _} ->
        redirect(conn, to: sanitize_return_to(return_to))
    end
  end

  def create(conn, %{"return_to" => return_to}) do
    redirect(conn, to: sanitize_return_to(return_to))
  end

  def create(conn, _params) do
    redirect(conn, to: "/")
  end

  # Only allow relative paths to prevent open-redirect attacks
  defp sanitize_return_to("/" <> _ = path), do: path
  defp sanitize_return_to(_), do: "/"
end
