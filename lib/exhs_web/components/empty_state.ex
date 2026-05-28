defmodule ExhsWeb.Components.EmptyState do
  @moduledoc false
  use Phoenix.Component

  import ExhsWeb.Components.Icon

  attr :icon, :string, default: "hero-inbox"
  attr :title, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class={["flex flex-col items-center justify-center py-12 text-center", @class]}>
      <div class="bg-base-content/5 mb-4 flex size-14 items-center justify-center rounded-2xl">
        <.icon name={@icon} class="text-base-content/30 size-7" />
      </div>
      <h3 class="text-base-content/70 font-semibold">{@title}</h3>
      <div :if={@inner_block != []} class="text-base-content/40 mt-1 max-w-sm text-sm">
        {render_slot(@inner_block)}
      </div>
      <div :if={@action != []} class="mt-5">
        {render_slot(@action)}
      </div>
    </div>
    """
  end
end
