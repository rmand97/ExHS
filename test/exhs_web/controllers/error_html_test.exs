defmodule ExhsWeb.ErrorHTMLTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html with Danish text" do
    html = render_to_string(ExhsWeb.ErrorHTML, "404", "html", [])
    assert html =~ "404"
    assert html =~ "Siden blev ikke fundet"
    assert html =~ "Gå til forsiden"
  end

  test "renders 500.html with Danish text" do
    html = render_to_string(ExhsWeb.ErrorHTML, "500", "html", [])
    assert html =~ "500"
    assert html =~ "Noget gik galt"
  end

  test "unknown template falls back to status message" do
    assert render_to_string(ExhsWeb.ErrorHTML, "503", "html", []) == "Service Unavailable"
  end
end
