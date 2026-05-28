defmodule ExhsWeb.Components.Tabs do
  @moduledoc false
  use Phoenix.Component

  attr :id, :string, default: nil
  attr :class, :any, default: nil

  slot :tab, required: true do
    attr :label, :string, required: true
    attr :active, :boolean
    attr :patch, :string
    attr :navigate, :string
  end

  def tabs(assigns) do
    ~H"""
    <div id={@id} class={["flex gap-1", @class]}>
      <.link
        :for={tab <- @tab}
        patch={tab[:patch]}
        navigate={tab[:navigate]}
        class={[
          "rounded-lg px-3 py-1.5 text-sm font-medium transition",
          tab[:active] && "bg-base-content/10 text-base-content",
          !tab[:active] && "hover:bg-base-content/5 hover:text-base-content/80 text-base-content/50"
        ]}
      >
        {tab.label}
      </.link>
    </div>
    """
  end
end
