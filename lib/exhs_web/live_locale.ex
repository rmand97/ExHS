defmodule ExhsWeb.LiveLocale do
  @moduledoc """
  LiveView `on_mount` hook that restores the locale set during the HTTP request
  (by `Localize.Plug.PutLocale`/`PutSession`) onto the LiveView process, for both
  Localize formatting and the `ExhsWeb.Gettext` backend.

  When the session carries no locale, Localize and Gettext fall back to their
  configured defaults (`:da`), so pages still render in Danish.
  """

  def on_mount(:default, _params, session, socket) do
    Localize.Plug.put_locale_from_session(session, gettext: ExhsWeb.Gettext)
    {:cont, socket}
  end
end
