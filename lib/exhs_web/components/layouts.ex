defmodule ExhsWeb.Layouts do
  @moduledoc false
  use ExhsWeb, :html

  embed_templates "layouts/*"

  # ──────────────────────────────────────────────
  # Marketing layout (main domain, no forening)
  # ──────────────────────────────────────────────

  attr :flash, :map, required: true
  attr :current_user, :map, default: nil
  slot :inner_block, required: true

  def marketing(assigns) do
    ~H"""
    <div class="bg-base-200 min-h-screen">
      <nav class="bg-base-100/80 border-base-content/5 sticky top-0 z-50 border-b backdrop-blur-xl">
        <div class="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <a href="/" class="flex items-center gap-2.5">
            <.exhs_logo />
            <span class="text-base-content text-lg font-semibold tracking-tight">Exhs</span>
          </a>
          <div class="flex items-center gap-3">
            <.theme_toggle />
            <a :if={!@current_user} href="/sign-in" class="btn btn-ghost btn-sm">Log ind</a>
            <a :if={!@current_user} href="/register" class="btn btn-primary btn-sm">Opret konto</a>
            <a :if={@current_user} href="/dashboard" class="btn btn-ghost btn-sm">Din side</a>
          </div>
        </div>
      </nav>

      <main>
        {render_slot(@inner_block)}
      </main>

      <footer class="border-base-content/5 border-t px-4 py-8 sm:px-6">
        <div class="text-base-content/40 mx-auto max-w-7xl text-center text-sm">
          <p>&copy; {DateTime.utc_now().year} Exhs</p>
        </div>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  # ──────────────────────────────────────────────
  # Public forening layout
  # ──────────────────────────────────────────────

  attr :flash, :map, required: true
  attr :current_forening, :map, required: true
  attr :current_user, :map, default: nil
  attr :current_path, :string, default: nil
  slot :inner_block, required: true

  def public(assigns) do
    ~H"""
    <div class="bg-base-200 min-h-screen" style={forening_css_vars(@current_forening)}>
      <nav class="bg-base-100/80 border-base-content/5 sticky top-0 z-50 border-b backdrop-blur-xl">
        <div class="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div class="flex items-center gap-3">
            <a href="/" class="flex items-center gap-2.5">
              <.forening_logo forening={@current_forening} />
              <span class="text-base-content hidden text-lg font-semibold tracking-tight sm:inline">
                {@current_forening.name}
              </span>
            </a>
            <div class="hidden items-center gap-1 sm:flex">
              <.nav_link href="/" label="Hjem" current_path={@current_path} />
              <.nav_link href="/events" label="Events" current_path={@current_path} />
              <.nav_link href="/join" label="Bliv medlem" current_path={@current_path} />
            </div>
          </div>
          <div class="flex items-center gap-3">
            <.theme_toggle />
            <a :if={!@current_user} href="/sign-in" class="btn btn-ghost btn-sm">Log ind</a>
            <a :if={@current_user} href="/dashboard" class="btn btn-ghost btn-sm">
              <.icon name="hero-squares-2x2" class="size-4" /> Din side
            </a>
          </div>
        </div>
        <div class="border-base-content/5 flex items-center gap-1 border-t px-4 py-2 sm:hidden">
          <.nav_link href="/" label="Hjem" current_path={@current_path} />
          <.nav_link href="/events" label="Events" current_path={@current_path} />
          <.nav_link href="/join" label="Bliv medlem" current_path={@current_path} />
        </div>
      </nav>

      <main>
        {render_slot(@inner_block)}
      </main>

      <footer class="border-base-content/5 border-t px-4 py-8 sm:px-6">
        <div class="mx-auto max-w-7xl text-center">
          <p class="text-base-content/40 text-sm">
            &copy; {DateTime.utc_now().year} {@current_forening.name}
          </p>
          <p class="text-base-content/30 mt-1 text-xs">Drevet af Exhs</p>
        </div>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  # ──────────────────────────────────────────────
  # Member layout (authenticated pages)
  # ──────────────────────────────────────────────

  attr :flash, :map, required: true
  attr :current_user, :map, required: true
  attr :current_path, :string, default: nil
  slot :inner_block, required: true

  def member(assigns) do
    ~H"""
    <div class="bg-base-200 min-h-screen">
      <nav class="bg-base-100/80 border-base-content/5 sticky top-0 z-50 border-b backdrop-blur-xl">
        <div class="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div class="flex items-center gap-4">
            <.link navigate="/dashboard" class="flex items-center gap-2.5">
              <.exhs_logo />
              <span class="text-base-content hidden font-semibold tracking-tight sm:inline">Exhs</span>
            </.link>
            <div class="hidden items-center gap-1 md:flex">
              <.nav_link href="/dashboard" label="Dashboard" current_path={@current_path} />
              <.nav_link href="/upcoming" label="Kommende events" current_path={@current_path} />
              <.nav_link href="/registrations" label="Mine events" current_path={@current_path} />
              <.nav_link href="/payments" label="Betalinger" current_path={@current_path} />
            </div>
          </div>
          <div class="flex items-center gap-3">
            <.theme_toggle />
            <div class="dropdown dropdown-end">
              <div tabindex="0" role="button">
                <.avatar initials={user_initials(@current_user)} size="sm" class="cursor-pointer" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content bg-base-100 border-base-content/10 z-50 mt-2 w-48 rounded-xl border p-1 shadow-lg"
              >
                <li>
                  <.link
                    navigate="/profile"
                    class="hover:bg-base-content/5 text-base-content/70 hover:text-base-content flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm"
                  >
                    <.icon name="hero-user" class="size-4" /> Profil
                  </.link>
                </li>
                <li>
                  <.link
                    href="/sign-out"
                    method="delete"
                    class="hover:bg-base-content/5 text-base-content/70 hover:text-base-content flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm"
                  >
                    <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> Log ud
                  </.link>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </nav>

      <div class="border-base-content/5 flex items-center gap-1 overflow-x-auto border-b px-4 py-2 md:hidden">
        <.nav_link href="/dashboard" label="Dashboard" current_path={@current_path} />
        <.nav_link href="/upcoming" label="Events" current_path={@current_path} />
        <.nav_link href="/registrations" label="Mine events" current_path={@current_path} />
        <.nav_link href="/payments" label="Betalinger" current_path={@current_path} />
        <.nav_link href="/profile" label="Profil" current_path={@current_path} />
      </div>

      <main class="px-4 py-6 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-7xl">
          {render_slot(@inner_block)}
        </div>
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  # ──────────────────────────────────────────────
  # Dev-only app layout (component showcase)
  # ──────────────────────────────────────────────

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="bg-base-200 min-h-screen">
      <nav class="bg-base-100/80 border-base-content/5 navbar sticky top-0 z-50 border-b px-4 backdrop-blur-xl sm:px-6">
        <div class="flex-1 gap-4">
          <a href="/" class="flex items-center gap-2.5">
            <.exhs_logo />
            <span class="text-base-content hidden font-semibold tracking-tight sm:inline">Exhs</span>
          </a>
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

  # ──────────────────────────────────────────────
  # Shared nav link (active-state aware)
  # ──────────────────────────────────────────────

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :current_path, :string, default: nil

  defp nav_link(assigns) do
    active =
      case {assigns.current_path, assigns.href} do
        {nil, _} -> false
        {"/", "/"} -> true
        {_path, "/"} -> false
        {path, href} -> String.starts_with?(path, href)
      end

    assigns = assign(assigns, :active, active)

    ~H"""
    <.link
      navigate={@href}
      class={[
        "rounded-lg px-3 py-1.5 text-sm font-medium transition whitespace-nowrap",
        if(@active,
          do: "bg-base-content/8 text-base-content",
          else: "text-base-content/50 hover:bg-base-content/5 hover:text-base-content/80"
        )
      ]}
    >
      {@label}
    </.link>
    """
  end

  # ──────────────────────────────────────────────
  # Private components
  # ──────────────────────────────────────────────

  defp exhs_logo(assigns) do
    ~H"""
    <div class="from-primary text-primary-content to-secondary flex size-9 items-center justify-center rounded-xl bg-linear-to-br text-sm font-bold">
      E
    </div>
    """
  end

  defp forening_logo(assigns) do
    ~H"""
    <div :if={@forening.logo_url} class="size-9 overflow-hidden rounded-xl">
      <img src={@forening.logo_url} alt={@forening.name} class="size-full object-cover" />
    </div>
    <div
      :if={!@forening.logo_url}
      class="from-primary text-primary-content to-secondary flex size-9 items-center justify-center rounded-xl bg-linear-to-br text-sm font-bold"
    >
      {String.first(@forening.name)}
    </div>
    """
  end

  defp user_initials(nil), do: "?"

  defp user_initials(user) do
    first = (user.first_name || "") |> String.first() || ""
    last = (user.last_name || "") |> String.first() || ""

    case String.upcase(first <> last) do
      "" -> user.email |> to_string() |> String.first() |> String.upcase()
      initials -> initials
    end
  end

  defp forening_css_vars(forening) do
    branding = forening.branding || %{}
    primary = branding["primary_color"]
    accent = branding["accent_color"]

    vars =
      [
        primary && "--color-primary: #{primary}",
        accent && "--color-accent: #{accent}"
      ]
      |> Enum.reject(&is_nil/1)

    case vars do
      [] -> nil
      list -> Enum.join(list, "; ")
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
