defmodule ExhsWeb.Components.Badge do
  @moduledoc false
  use Phoenix.Component

  attr :variant, :string,
    default: "default",
    values: ~w(default primary secondary accent success warning error)

  attr :class, :any, default: nil
  slot :inner_block, required: true

  def badge(assigns) do
    colors = %{
      "default" => "bg-base-content/10 text-base-content/70",
      "primary" => "bg-primary/20 text-primary",
      "secondary" => "bg-secondary/20 text-secondary",
      "accent" => "bg-accent/20 text-accent",
      "success" => "bg-success/20 text-success",
      "warning" => "bg-warning/20 text-warning",
      "error" => "bg-error/20 text-error"
    }

    assigns = assign(assigns, :color_class, Map.fetch!(colors, assigns.variant))

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium",
      @color_class,
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end
end
