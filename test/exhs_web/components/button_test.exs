defmodule ExhsWeb.Components.ButtonTest do
  use ExhsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import ExhsWeb.Components.Button

  test "applies the variant's btn classes" do
    html = render_component(&button/1, variant: "destructive", inner_block: slot("Delete"))

    assert html =~ "btn"
    assert html =~ "btn-error"
  end

  test "keeps the btn classes when a custom class is also passed" do
    html =
      render_component(&button/1,
        variant: "primary",
        class: "w-full",
        inner_block: slot("Activate")
      )

    assert html =~ "btn"
    assert html =~ "btn-primary"
    assert html =~ "w-full"
  end

  test "renders a link when an href is given" do
    html = render_component(&button/1, navigate: "/x", inner_block: slot("Go"))

    assert html =~ "<a"
    assert html =~ "btn"
  end

  defp slot(text) do
    [%{inner_block: fn _, _ -> text end}]
  end
end
