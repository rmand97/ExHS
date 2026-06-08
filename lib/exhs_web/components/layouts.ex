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
          <.link navigate={~p"/"} class="flex items-center gap-2.5">
            <.exhs_logo />
            <span class="text-base-content text-lg font-semibold tracking-tight">Exhs</span>
          </.link>
          <div class="flex items-center gap-3">
            <.link :if={!@current_user} navigate={~p"/sign-in"} class="btn btn-ghost btn-sm">
              {gettext("Sign in")}
            </.link>
            <.link :if={!@current_user} navigate={~p"/register"} class="btn btn-primary btn-sm">
              {gettext("Create account")}
            </.link>
            <.link :if={@current_user} navigate={~p"/dashboard"} class="btn btn-ghost btn-sm">
              {gettext("Your page")}
            </.link>
          </div>
        </div>
      </nav>

      <main>
        {render_slot(@inner_block)}
      </main>

      <footer class="border-base-content/5 border-t px-4 py-8 sm:px-6">
        <div class="text-base-content/40 mx-auto max-w-7xl space-y-3 text-center text-sm">
          <p>&copy; {DateTime.utc_now().year} Exhs</p>
          <.locale_switcher />
        </div>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc "Language switcher linking to the locale controller, returning to the given path."
  attr :return_to, :string, default: "/"

  def locale_switcher(assigns) do
    ~H"""
    <div class="text-base-content/40 flex items-center justify-center gap-2 text-xs">
      <.link href={~p"/locale/da?#{[return_to: @return_to]}"} class="hover:text-base-content">
        Dansk
      </.link>
      <span class="text-base-content/20">·</span>
      <.link href={~p"/locale/en?#{[return_to: @return_to]}"} class="hover:text-base-content">
        English
      </.link>
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
  attr :current_role, :atom, default: nil
  slot :inner_block, required: true

  def public(assigns) do
    ~H"""
    <div class="bg-base-200 min-h-screen" style={forening_css_vars(@current_forening)}>
      <nav class="bg-base-100/80 border-base-content/5 sticky top-0 z-50 border-b backdrop-blur-xl">
        <div class="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div class="flex items-center gap-3">
            <.link navigate={~p"/"} class="flex items-center gap-2.5">
              <.forening_logo forening={@current_forening} />
              <span class="text-base-content hidden text-lg font-semibold tracking-tight sm:inline">
                {@current_forening.name}
              </span>
            </.link>
            <div class="hidden items-center gap-1 sm:flex">
              <.nav_link href="/" label={gettext("Home")} current_path={@current_path} />
              <.nav_link href="/events" label="Events" current_path={@current_path} />
              <.nav_link href="/join" label={gettext("Become a member")} current_path={@current_path} />
            </div>
          </div>
          <div class="flex items-center gap-3">
            <.link
              :if={@current_role in [:admin, :board]}
              navigate={~p"/admin"}
              class="btn btn-primary btn-sm"
            >
              <.icon name="hero-cog-6-tooth" class="size-4" /> Admin
            </.link>
            <.link :if={!@current_user} navigate={~p"/sign-in"} class="btn btn-ghost btn-sm">
              {gettext("Sign in")}
            </.link>
            <.link :if={@current_user} navigate={~p"/dashboard"} class="btn btn-ghost btn-sm">
              <.icon name="hero-squares-2x2" class="size-4" /> {gettext("Your page")}
            </.link>
          </div>
        </div>
        <div class="border-base-content/5 flex items-center gap-1 border-t px-4 py-2 sm:hidden">
          <.nav_link href="/" label={gettext("Home")} current_path={@current_path} />
          <.nav_link href="/events" label="Events" current_path={@current_path} />
          <.nav_link href="/join" label={gettext("Become a member")} current_path={@current_path} />
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
          <p class="text-base-content/30 mt-1 text-xs">{gettext("Powered by Exhs")}</p>
          <div class="mt-3">
            <.locale_switcher return_to={@current_path || "/"} />
          </div>
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
  attr :my_foreninger, :list, default: []
  slot :inner_block, required: true

  def member(assigns) do
    ~H"""
    <div class="bg-base-200 min-h-screen">
      <nav class="bg-base-100/80 border-base-content/5 sticky top-0 z-50 border-b backdrop-blur-xl">
        <div class="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div class="flex items-center gap-4">
            <.link navigate="/dashboard" class="flex items-center gap-2.5">
              <.exhs_logo />
              <span class="text-base-content hidden font-semibold tracking-tight sm:inline">
                Exhs
              </span>
            </.link>
            <div class="hidden items-center gap-1 md:flex">
              <.nav_link href="/dashboard" label="Dashboard" current_path={@current_path} />
              <.nav_link
                href="/upcoming"
                label={gettext("Upcoming events")}
                current_path={@current_path}
              />
              <.nav_link
                href="/registrations"
                label={gettext("My events")}
                current_path={@current_path}
              />
              <.nav_link href="/payments" label={gettext("Payments")} current_path={@current_path} />
              <.nav_link href="/activity" label={gettext("Activity")} current_path={@current_path} />
            </div>
          </div>
          <div class="flex items-center gap-3">
            <.dropdown :if={@my_foreninger != []} id="my-foreninger-menu" class="dropdown-end">
              <:trigger>
                <span class="btn btn-ghost btn-sm gap-1.5">
                  <.icon name="hero-building-office-2" class="size-4" />
                  <span class="hidden sm:inline">{gettext("Your associations")}</span>
                  <.icon name="hero-chevron-down" class="size-3.5 opacity-60" />
                </span>
              </:trigger>
              <.dropdown_item
                :for={forening <- @my_foreninger}
                href={forening_url(forening)}
              >
                <.forening_logo forening={forening} /> {forening.name}
              </.dropdown_item>
            </.dropdown>
            <div class="dropdown dropdown-end">
              <div tabindex="0" role="button" aria-label={gettext("User menu")}>
                <.avatar initials={user_initials(@current_user)} size="sm" class="cursor-pointer" />
              </div>
              <ul
                tabindex="0"
                class="bg-base-100 border-base-content/10 dropdown-content z-50 mt-2 w-48 rounded-xl border p-1 shadow-lg"
              >
                <li>
                  <.link
                    navigate="/profile"
                    class="hover:bg-base-content/5 hover:text-base-content text-base-content/70 flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm"
                  >
                    <.icon name="hero-user" class="size-4" /> {gettext("Profile")}
                  </.link>
                </li>
                <li :if={@current_user && @current_user.is_superadmin}>
                  <.link
                    navigate="/superadmin"
                    class="hover:bg-base-content/5 hover:text-base-content text-base-content/70 flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm"
                  >
                    <.icon name="hero-shield-check" class="size-4" /> Superadmin
                  </.link>
                </li>
                <li>
                  <.link
                    href="/sign-out"
                    method="delete"
                    class="hover:bg-base-content/5 hover:text-base-content text-base-content/70 flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm"
                  >
                    <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> {gettext(
                      "Sign out"
                    )}
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
        <.nav_link href="/registrations" label={gettext("My events")} current_path={@current_path} />
        <.nav_link href="/payments" label={gettext("Payments")} current_path={@current_path} />
        <.nav_link href="/activity" label={gettext("Activity")} current_path={@current_path} />
        <.nav_link href="/profile" label={gettext("Profile")} current_path={@current_path} />
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
  # Admin layout (forening command center)
  # ──────────────────────────────────────────────

  defp admin_nav do
    [
      {"Dashboard", "/admin", "hero-squares-2x2", true},
      {gettext("Members"), "/admin/members", "hero-users", true},
      {gettext("Groups"), "/admin/groups", "hero-tag", true},
      {gettext("Events"), "/admin/events", "hero-calendar-days", true},
      {gettext("Shop"), "/admin/shop", "hero-shopping-bag", false},
      {gettext("Newsletters"), "/admin/newsletters", "hero-envelope", false},
      {gettext("Economy"), "/admin/economy", "hero-banknotes", true},
      {gettext("Audit"), "/admin/audit", "hero-clipboard-document-list", false},
      {gettext("Settings"), "/admin/settings", "hero-cog-6-tooth", true}
    ]
  end

  attr :flash, :map, required: true
  attr :current_forening, :map, required: true
  attr :current_user, :map, required: true
  attr :current_role, :atom, default: :admin
  attr :current_path, :string, default: nil
  slot :inner_block, required: true

  def admin(assigns) do
    assigns = assign(assigns, :nav, admin_nav())

    ~H"""
    <div class="bg-base-200 min-h-screen lg:grid lg:grid-cols-[16rem_1fr]">
      <%!-- Sidebar (desktop) --%>
      <aside class="bg-base-100 border-base-content/5 sticky top-0 hidden h-screen flex-col border-r lg:flex">
        <.admin_brand current_forening={@current_forening} />
        <nav class="flex-1 space-y-1 overflow-y-auto px-3 py-4">
          <.admin_nav_link
            :for={{label, href, icon, built} <- @nav}
            label={label}
            href={href}
            icon={icon}
            built={built}
            current_path={@current_path}
          />
        </nav>
        <.admin_role_badge current_role={@current_role} />
      </aside>

      <div class="flex min-h-screen flex-col">
        <%!-- Topbar --%>
        <header class="bg-base-100/80 border-base-content/5 sticky top-0 z-40 border-b backdrop-blur-xl">
          <div class="flex items-center justify-between gap-3 px-4 py-3 sm:px-6">
            <button
              class="btn btn-ghost btn-sm btn-square lg:hidden"
              phx-click={show_mobile_sidebar()}
              aria-label={gettext("Open menu")}
            >
              <.icon name="hero-bars-3" class="size-5" />
            </button>
            <span class="text-base-content truncate font-semibold tracking-tight lg:hidden">
              {@current_forening.name}
            </span>
            <div class="hidden lg:block"></div>
            <div class="flex items-center gap-3">
              <div class="dropdown dropdown-end">
                <div tabindex="0" role="button" aria-label={gettext("User menu")}>
                  <.avatar initials={user_initials(@current_user)} size="sm" class="cursor-pointer" />
                </div>
                <ul
                  tabindex="0"
                  class="bg-base-100 border-base-content/10 dropdown-content z-50 mt-2 w-52 rounded-xl border p-1 shadow-lg"
                >
                  <li class="border-base-content/5 mb-1 border-b px-3 py-2">
                    <p class="text-base-content/40 text-xs">{gettext("Signed in as")}</p>
                    <p class="text-base-content truncate text-sm font-medium">
                      {@current_user.email}
                    </p>
                  </li>
                  <li>
                    <.link
                      navigate="/dashboard"
                      class="hover:bg-base-content/5 hover:text-base-content text-base-content/70 flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm"
                    >
                      <.icon name="hero-arrow-left-on-rectangle" class="size-4" />
                      {gettext("Back to your page")}
                    </.link>
                  </li>
                  <li>
                    <.link
                      href="/sign-out"
                      method="delete"
                      class="hover:bg-base-content/5 hover:text-base-content text-base-content/70 flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm"
                    >
                      <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> {gettext(
                        "Sign out"
                      )}
                    </.link>
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </header>

        <main class="flex-1 px-4 py-6 sm:px-6 lg:px-8">
          <div class="mx-auto max-w-7xl">
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>

      <%!-- Mobile sidebar (slide-over) --%>
      <div id="mobile-sidebar" class="relative z-50 hidden lg:hidden" role="dialog" aria-modal="true">
        <div
          class="bg-base-content/40 fixed inset-0 backdrop-blur-sm"
          phx-click={hide_mobile_sidebar()}
        >
        </div>
        <aside class="bg-base-100 fixed inset-y-0 left-0 flex w-64 flex-col shadow-xl">
          <.admin_brand current_forening={@current_forening} />
          <nav class="flex-1 space-y-1 overflow-y-auto px-3 py-4">
            <.admin_nav_link
              :for={{label, href, icon, built} <- @nav}
              label={label}
              href={href}
              icon={icon}
              built={built}
              current_path={@current_path}
            />
          </nav>
          <.admin_role_badge current_role={@current_role} />
        </aside>
      </div>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp show_mobile_sidebar(js \\ %JS{}) do
    JS.show(js, to: "#mobile-sidebar")
  end

  defp hide_mobile_sidebar(js \\ %JS{}) do
    JS.hide(js, to: "#mobile-sidebar")
  end

  attr :current_forening, :map, required: true

  defp admin_brand(assigns) do
    ~H"""
    <div class="border-base-content/5 flex h-16 shrink-0 items-center gap-2.5 border-b px-5">
      <.forening_logo forening={@current_forening} />
      <div class="min-w-0">
        <p class="text-base-content truncate text-sm font-semibold">{@current_forening.name}</p>
        <p class="text-base-content/40 text-xs">Administration</p>
      </div>
    </div>
    """
  end

  attr :current_role, :atom, required: true

  defp admin_role_badge(assigns) do
    ~H"""
    <div class="border-base-content/5 border-t px-5 py-3">
      <span class="text-base-content/40 text-xs">
        {gettext("Role:")}
        <span class="text-base-content/70 font-medium">{role_label(@current_role)}</span>
        <span :if={@current_role == :board}>{gettext("(read-only)")}</span>
      </span>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :built, :boolean, default: true
  attr :current_path, :string, default: nil

  defp admin_nav_link(%{built: false} = assigns) do
    ~H"""
    <span class="text-base-content/25 flex cursor-not-allowed items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium">
      <.icon name={@icon} class="size-5" />
      {@label}
      <span class="bg-base-content/5 text-base-content/40 ml-auto rounded px-1.5 py-0.5 text-[10px]">
        {gettext("soon")}
      </span>
    </span>
    """
  end

  defp admin_nav_link(assigns) do
    active =
      case {assigns.current_path, assigns.href} do
        {nil, _} -> false
        {"/admin", "/admin"} -> true
        {_path, "/admin"} -> false
        {path, href} -> String.starts_with?(path, href)
      end

    assigns = assign(assigns, :active, active)

    ~H"""
    <.link
      navigate={@href}
      class={[
        "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition",
        if(@active,
          do: "bg-primary/10 text-primary",
          else: "hover:bg-base-content/5 hover:text-base-content text-base-content/60"
        )
      ]}
    >
      <.icon name={@icon} class="size-5" />
      {@label}
    </.link>
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
          <.link navigate={~p"/"} class="flex items-center gap-2.5">
            <.exhs_logo />
            <span class="text-base-content hidden font-semibold tracking-tight sm:inline">Exhs</span>
          </.link>
        </div>
        <div class="flex flex-none items-center gap-3">
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
        "rounded-lg px-2.5 py-1.5 text-xs font-medium whitespace-nowrap transition sm:px-3 sm:text-sm",
        if(@active,
          do: "bg-base-content/8 text-base-content",
          else: "hover:bg-base-content/5 hover:text-base-content/80 text-base-content/50"
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

  @safe_css_color_re ~r/\A(#[0-9a-fA-F]{3,8}|oklch\([0-9a-zA-Z.,% ]+\)|[a-z]{3,20})\z/

  defp safe_css_color(value) when is_binary(value) do
    if Regex.match?(@safe_css_color_re, String.trim(value)), do: String.trim(value)
  end

  defp safe_css_color(_value), do: nil

  defp forening_css_vars(forening) do
    branding = forening.branding || %{}
    primary = safe_css_color(branding["primary_color"])
    accent = safe_css_color(branding["accent_color"])

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
      <div class="bg-base-100 border-base-200 absolute left-0 h-full w-1/3 rounded-full border brightness-200 transition-[left] in-data-[theme-pref=dark]:left-2/3 in-data-[theme-pref=light]:left-1/3" />

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
