defmodule ExhsWeb.Dev.ComponentShowcaseLiveTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "component showcase" do
    test "mounts and renders overview tab", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/dev/components")

      assert html =~ "Component Showcase"
      assert html =~ "Buttons"
      assert html =~ "Badges"
      assert html =~ "Stat Cards"
    end

    test "navigates between tabs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dev/components")

      html = view |> element(~s|a[href="/dev/components?tab=data"]|) |> render_click()
      assert html =~ "Table"

      html = view |> element(~s|a[href="/dev/components?tab=forms"]|) |> render_click()
      assert html =~ "Form Inputs"

      html = view |> element(~s|a[href="/dev/components?tab=branding"]|) |> render_click()
      assert html =~ "Branding Override Demo"
    end
  end
end
