defmodule ExhsWeb.Components.Dropdown do
  @moduledoc false
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  slot :trigger, required: true
  slot :inner_block, required: true

  def dropdown(assigns) do
    ~H"""
    <div id={@id} class={["dropdown", @class]}>
      <div tabindex="0" role="button">
        {render_slot(@trigger)}
      </div>
      <ul
        tabindex="0"
        class="dropdown-content glass-surface z-10 mt-2 min-w-48 rounded-xl p-1 shadow-xl"
      >
        {render_slot(@inner_block)}
      </ul>
    </div>
    """
  end

  attr :rest, :global, include: ~w(href navigate patch method)
  slot :inner_block, required: true

  def dropdown_item(assigns) do
    ~H"""
    <li>
      <.link
        class="hover:bg-base-content/5 hover:text-base-content text-base-content/70 flex items-center gap-2 rounded-lg px-3 py-2 text-sm transition"
        {@rest}
      >
        {render_slot(@inner_block)}
      </.link>
    </li>
    """
  end
end
