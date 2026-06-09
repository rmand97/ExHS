defmodule ExhsWeb.Components.Button do
  @moduledoc false
  use Phoenix.Component

  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary secondary ghost destructive)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" => "btn-primary",
      "secondary" => "btn-secondary btn-soft",
      "ghost" => "btn-ghost",
      "destructive" => "btn-error",
      nil => "btn-primary btn-soft"
    }

    assigns =
      assign(assigns, :class, [
        "btn",
        Map.fetch!(variants, assigns[:variant]),
        Map.get(assigns, :class)
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end
end
