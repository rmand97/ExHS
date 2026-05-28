defmodule ExhsWeb.Components.Card do
  @moduledoc false
  use Phoenix.Component

  attr :class, :any, default: nil
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={["glass-surface overflow-hidden rounded-2xl", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
