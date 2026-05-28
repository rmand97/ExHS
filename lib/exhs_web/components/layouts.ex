defmodule ExhsWeb.Layouts do
  @moduledoc false
  use ExhsWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="bg-base-200 min-h-screen">
      <nav class="bg-base-100/80 border-base-content/5 navbar sticky top-0 z-50 border-b px-4 backdrop-blur-xl sm:px-6">
        <div class="flex-1 gap-4">
          <a href="/" class="flex items-center gap-2.5">
            <div class="from-primary text-primary-content to-secondary flex size-8 items-center justify-center rounded-lg bg-linear-to-br text-sm font-bold">
              E
            </div>
            <span class="text-base-content hidden font-semibold tracking-tight sm:inline">
              Exhs
            </span>
          </a>
          <div :if={@current_scope} class="hidden items-center gap-1 md:flex">
            <.nav_link href="/" label="Oversigt" />
            <.nav_link href="#" label="Medlemmer" />
            <.nav_link href="#" label="Events" />
            <.nav_link href="#" label="Kontingent" />
          </div>
        </div>
        <div class="flex flex-none items-center gap-3">
          <.theme_toggle />
          <div :if={@current_scope} class="flex items-center gap-3">
            <.avatar initials={user_initials(@current_scope.actor)} size="sm" />
          </div>
        </div>
      </nav>

      <main class="px-4 py-6 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-7xl">
          {render_slot(@inner_block)}
        </div>
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="hover:bg-base-content/5 hover:text-base-content/80 text-base-content/50 rounded-lg px-3 py-1.5 text-sm font-medium transition"
    >
      {@label}
    </a>
    """
  end

  defp user_initials(nil), do: "?"

  defp user_initials(user) do
    first = (user.first_name || "") |> String.first() || ""
    last = (user.last_name || "") |> String.first() || ""

    case String.upcase(first <> last) do
      "" -> String.first(user.email || "?") |> String.upcase()
      initials -> initials
    end
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="bg-base-300 border-base-300 card relative flex flex-row items-center rounded-full border-2">
      <div class="bg-base-100 border-base-200 absolute left-0 h-full w-1/3 rounded-full border brightness-200 transition-[left] in-data-[theme=dark]:left-2/3 in-data-[theme=light]:left-1/3" />

      <button
        class="flex w-1/3 cursor-pointer p-2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex w-1/3 cursor-pointer p-2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex w-1/3 cursor-pointer p-2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
