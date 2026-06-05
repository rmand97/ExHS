defmodule ExhsWeb.Components.Icon do
  @moduledoc false
  use Phoenix.Component

  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def icon(assigns) do
    ~H"""
    <span class={@class} />
    """
  end
end
