defmodule ExhsWeb.Components.StatCard do
  @moduledoc false
  use Phoenix.Component

  import ExhsWeb.Components.Card
  import ExhsWeb.Components.Icon

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :change, :string, default: nil
  attr :change_type, :string, default: "neutral", values: ~w(positive negative neutral)
  attr :icon, :string, default: nil

  attr :color, :string,
    default: "primary",
    values: ~w(primary secondary accent success warning error)

  def stat_card(assigns) do
    color_map = %{
      "primary" => {"bg-primary/20", "text-primary"},
      "secondary" => {"bg-secondary/20", "text-secondary"},
      "accent" => {"bg-accent/20", "text-accent"},
      "success" => {"bg-success/20", "text-success"},
      "warning" => {"bg-warning/20", "text-warning"},
      "error" => {"bg-error/20", "text-error"}
    }

    change_colors = %{
      "positive" => "text-success",
      "negative" => "text-error",
      "neutral" => "text-base-content/40"
    }

    {bg, fg} = Map.fetch!(color_map, assigns.color)

    assigns =
      assigns
      |> assign(:icon_bg, bg)
      |> assign(:icon_fg, fg)
      |> assign(:change_color, Map.fetch!(change_colors, assigns.change_type))

    ~H"""
    <.card>
      <div class="p-5">
        <div class="flex items-center justify-between">
          <div :if={@icon} class={["flex size-10 items-center justify-center rounded-xl", @icon_bg]}>
            <.icon name={@icon} class={["size-5", @icon_fg]} />
          </div>
          <span :if={@change} class={["text-xs font-medium", @change_color]}>{@change}</span>
        </div>
        <div class="mt-4 text-3xl font-bold">{@value}</div>
        <div class="text-base-content/40 mt-1 text-sm">{@label}</div>
      </div>
    </.card>
    """
  end
end
