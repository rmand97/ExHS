defmodule ExhsWeb.Components.Modal do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: ExhsWeb.Gettext

  import ExhsWeb.Components.Icon

  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}

  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-base-300/80 fixed inset-0 backdrop-blur-sm transition-opacity"
        aria-hidden="true"
      />
      <div class="fixed inset-0 overflow-y-auto" role="dialog" aria-modal="true" tabindex="0">
        <div class="flex min-h-full items-center justify-center p-4">
          <div
            id={"#{@id}-container"}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            class="glass-surface w-full max-w-lg rounded-2xl p-6 shadow-2xl"
          >
            <div class="absolute top-4 right-4">
              <button
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                type="button"
                class="bg-base-content/5 hover:bg-base-content/10 flex size-8 items-center justify-center rounded-lg transition"
                aria-label={gettext("close")}
              >
                <.icon name="hero-x-mark" class="text-base-content/40 size-5" />
              </button>
            </div>
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-container")
  end

  def hide_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      time: 200,
      transition: {"transition-all ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
    |> JS.hide(to: "##{id}", time: 200)
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
