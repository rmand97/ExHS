defmodule ExhsWeb.Components.Header do
  @moduledoc false
  use Phoenix.Component

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-3 sm:gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg/8 font-semibold">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-base-content/70 text-sm">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end
end
