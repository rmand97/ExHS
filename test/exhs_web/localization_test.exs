defmodule ExhsWeb.LocalizationTest do
  use ExhsWeb.ConnCase, async: true

  alias ExhsWeb.DisplayHelpers

  describe "locale-aware formatting" do
    test "format_money renders the active locale's currency format" do
      assert Localize.with_locale(:da, fn -> DisplayHelpers.format_money(30_000, "DKK") end) =~
               "300,00"

      assert Localize.with_locale(:en, fn -> DisplayHelpers.format_money(30_000, "DKK") end) =~
               "300.00"
    end

    test "format_date renders the active locale's month names" do
      assert Localize.with_locale(:da, fn -> DisplayHelpers.format_date(~D[2026-06-05]) end) =~
               "jun"

      assert Localize.with_locale(:en, fn -> DisplayHelpers.format_date(~D[2026-06-05]) end) =~
               "Jun"
    end
  end

  describe "locale resolution" do
    test "defaults to Danish and switches to English via the locale controller", %{conn: conn} do
      conn = get(conn, "/")
      assert html_response(conn, 200) =~ "Alt samlet ét sted"

      conn = get(conn, "/locale/en", %{"return_to" => "/"})
      assert redirected_to(conn) == "/"
      assert get_session(conn, "localize_locale") == "en"

      conn = get(conn, "/")
      assert html_response(conn, 200) =~ "Everything in one place"
    end

    test "rejects an unsafe return_to and falls back to the front page", %{conn: conn} do
      conn = get(conn, "/locale/da", %{"return_to" => "http://evil.example.com"})
      assert redirected_to(conn) == "/"
    end
  end
end
