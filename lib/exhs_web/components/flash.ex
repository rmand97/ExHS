defmodule ExhsWeb.Components.Flash do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: ExhsWeb.Gettext

  import ExhsWeb.Components.Icon
  import ExhsWeb.CoreComponents, only: [hide: 2]

  alias Phoenix.LiveView.JS

  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      phx-hook=".AutoDismiss"
      data-dismiss-after={if @kind == :error, do: "6000", else: "4000"}
      role="alert"
      class="toast toast-end toast-top z-50"
      {@rest}
    >
      <div class={[
        "alert relative w-80 max-w-80 overflow-hidden text-wrap sm:w-96 sm:max-w-96",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group cursor-pointer self-start" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
        <span
          data-progress
          class="absolute bottom-0 left-0 h-1 w-full origin-left bg-current/40"
        />
      </div>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".AutoDismiss">
        export default {
          mounted() {
            this.duration = parseInt(this.el.dataset.dismissAfter, 10) || 4000
            this.bar = this.el.querySelector("[data-progress]")
            this.start()
            this.el.addEventListener("mouseenter", () => this.pause())
            this.el.addEventListener("mouseleave", () => this.start())
          },
          // A re-sent flash (same key, new message) restarts the countdown.
          updated() {
            this.start()
          },
          destroyed() {
            this.clear()
          },
          start() {
            this.clear()
            if (this.bar) {
              // Restart the draining-bar animation in sync with the timer.
              this.bar.style.animation = "none"
              void this.bar.offsetWidth
              this.bar.style.animation = `flash-countdown ${this.duration}ms linear forwards`
            }
            this.timer = setTimeout(() => this.el.click(), this.duration)
          },
          pause() {
            this.clear()
            if (this.bar) this.bar.style.animationPlayState = "paused"
          },
          clear() {
            if (this.timer) clearTimeout(this.timer)
          }
        }
      </script>
    </div>
    """
  end
end
