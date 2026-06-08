defmodule ExhsWeb.LocaleController do
  @moduledoc """
  Switches the UI locale. Persists the choice into the session (read back by
  `Localize.Plug.PutLocale`) and, for signed-in users, onto their profile so the
  preference survives across devices.
  """
  use ExhsWeb, :controller

  alias Localize.Plug.PutLocale

  @supported ~w(da en)

  def update(conn, %{"locale" => locale} = params) when locale in @supported do
    conn
    |> persist_user_locale(locale)
    |> put_session(PutLocale.session_key(), locale)
    |> redirect(to: return_to(params))
  end

  def update(conn, params), do: redirect(conn, to: return_to(params))

  defp persist_user_locale(conn, locale) do
    case conn.assigns[:current_user] do
      %{} = user ->
        _ =
          Exhs.Accounts.update_profile(user, %{locale: String.to_existing_atom(locale)},
            actor: user
          )

        conn

      _ ->
        conn
    end
  end

  defp return_to(%{"return_to" => "/" <> _ = path}), do: path
  defp return_to(_), do: "/"
end
