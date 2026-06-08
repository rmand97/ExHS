defmodule ExhsWeb.Plugs.UserLocale do
  @moduledoc """
  Applies a signed-in user's stored `locale` preference over whatever
  `Localize.Plug.PutLocale` resolved from the session/accept-language header.

  Must run after `load_from_session` (so `current_user` is assigned) and writes
  the choice back into the session so LiveView `on_mount` hooks pick it up.
  """
  import Plug.Conn

  @supported [:da, :en]
  @session_key Localize.Plug.PutLocale.session_key()

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %{locale: locale} when locale in @supported ->
        string_locale = Atom.to_string(locale)
        Localize.put_locale(locale)
        Gettext.put_locale(ExhsWeb.Gettext, string_locale)
        put_session(conn, @session_key, string_locale)

      _ ->
        conn
    end
  end
end
