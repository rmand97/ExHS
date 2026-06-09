defmodule ExhsWeb.Dev.ComponentShowcaseLive do
  use ExhsWeb, :live_view

  import ExhsWeb.Components.Modal, only: [modal: 1, show_modal: 1]

  # Sample data backing the <.live_select> demos in the Forms tab.
  @cities ~w(København Aarhus Odense Aalborg Esbjerg Randers Kolding Horsens Vejle Roskilde)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Component Showcase",
        active_tab: "overview",
        select_form: to_form(%{"city" => nil, "cities" => []})
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, active_tab: params["tab"] || "overview")}
  end

  @impl true
  def handle_event("open-modal", _params, socket) do
    {:noreply, socket}
  end

  # LiveSelect sends this whenever the user types in the search box. Reply by
  # pushing filtered options back into the component via send_update/2.
  def handle_event("live_select_change", %{"text" => text, "id" => live_select_id}, socket) do
    matches = Enum.filter(@cities, &String.contains?(String.downcase(&1), String.downcase(text)))
    send_update(LiveSelect.Component, id: live_select_id, options: matches)
    {:noreply, socket}
  end

  def handle_event("select_demo_change", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
        <.header>
          Component Showcase
          <:subtitle>All design system components in one place</:subtitle>
        </.header>

        <.tabs id="showcase-tabs">
          <:tab
            label="Overview"
            active={@active_tab == "overview"}
            patch="/dev/components?tab=overview"
          />
          <:tab label="Data Display" active={@active_tab == "data"} patch="/dev/components?tab=data" />
          <:tab
            label="Feedback"
            active={@active_tab == "feedback"}
            patch="/dev/components?tab=feedback"
          />
          <:tab label="Forms" active={@active_tab == "forms"} patch="/dev/components?tab=forms" />
          <:tab
            label="Branding"
            active={@active_tab == "branding"}
            patch="/dev/components?tab=branding"
          />
        </.tabs>

        <div :if={@active_tab == "overview"}>
          <.section_overview />
        </div>
        <div :if={@active_tab == "data"}>
          <.section_data />
        </div>
        <div :if={@active_tab == "feedback"}>
          <.section_feedback />
        </div>
        <div :if={@active_tab == "forms"}>
          <.section_forms select_form={@select_form} />
        </div>
        <div :if={@active_tab == "branding"}>
          <.section_branding />
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp section_overview(assigns) do
    ~H"""
    <div class="space-y-10">
      <%!-- Buttons --%>
      <.showcase title="Buttons">
        <div class="flex flex-wrap gap-3">
          <.button variant="primary">Primary</.button>
          <.button variant="secondary">Secondary</.button>
          <.button variant="ghost">Ghost</.button>
          <.button variant="destructive">Destructive</.button>
          <.button variant="primary" disabled>Disabled</.button>
        </div>
      </.showcase>

      <%!-- Badges --%>
      <.showcase title="Badges">
        <div class="flex flex-wrap gap-2">
          <.badge>Default</.badge>
          <.badge variant="primary">Primary</.badge>
          <.badge variant="secondary">Secondary</.badge>
          <.badge variant="accent">Accent</.badge>
          <.badge variant="success">Success</.badge>
          <.badge variant="warning">Warning</.badge>
          <.badge variant="error">Error</.badge>
        </div>
      </.showcase>

      <%!-- Avatars --%>
      <.showcase title="Avatars">
        <div class="flex items-end gap-4">
          <.avatar initials="XS" size="xs" />
          <.avatar initials="SM" size="sm" />
          <.avatar initials="MD" size="md" />
          <.avatar initials="LG" size="lg" />
          <.avatar src="https://i.pravatar.cc/100?u=showcase" size="lg" />
        </div>
      </.showcase>

      <%!-- Icons --%>
      <.showcase title="Icons">
        <div class="flex items-center gap-4">
          <.icon name="hero-home" class="size-5" />
          <.icon name="hero-user" class="size-5" />
          <.icon name="hero-cog-6-tooth" class="size-5" />
          <.icon name="hero-bell" class="size-5" />
          <.icon name="hero-chart-bar" class="text-primary size-5" />
          <.icon name="hero-heart" class="text-error size-5" />
          <.icon name="hero-check-circle" class="text-success size-5" />
          <.icon name="hero-exclamation-triangle" class="text-warning size-5" />
        </div>
      </.showcase>

      <%!-- Cards --%>
      <.showcase title="Cards">
        <div class="grid grid-cols-1 gap-4 md:grid-cols-3">
          <.card class="p-5">
            <h3 class="mb-2 font-semibold">Basic Card</h3>
            <p class="text-base-content/60 text-sm">Glass-surface card with rounded corners.</p>
          </.card>
          <.card class="p-5">
            <h3 class="mb-2 font-semibold">Another Card</h3>
            <p class="text-base-content/60 text-sm">Cards work for any content block.</p>
          </.card>
          <.card class="p-0">
            <div class="from-primary/30 to-secondary/30 h-24 bg-linear-to-br" />
            <div class="p-5">
              <h3 class="font-semibold">With Image Area</h3>
            </div>
          </.card>
        </div>
      </.showcase>

      <%!-- Stat Cards --%>
      <.showcase title="Stat Cards">
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.stat_card
            label={gettext("Members")}
            value="1,247"
            change="+12%"
            change_type="positive"
            icon="hero-users"
            color="primary"
          />
          <.stat_card
            label={gettext("Active events")}
            value="8"
            change="+2"
            change_type="positive"
            icon="hero-calendar"
            color="secondary"
          />
          <.stat_card
            label={gettext("Revenue")}
            value="48.290 kr"
            change="-3%"
            change_type="negative"
            icon="hero-banknotes"
            color="accent"
          />
          <.stat_card
            label={gettext("Waitlist")}
            value="23"
            icon="hero-clock"
            color="warning"
          />
        </div>
      </.showcase>

      <%!-- Skeleton --%>
      <.showcase title="Skeleton Loaders">
        <div class="max-w-md space-y-3">
          <.skeleton class="h-4 w-3/4" />
          <.skeleton class="h-4 w-full" />
          <.skeleton class="h-4 w-5/6" />
          <.skeleton class="h-20 w-full" />
        </div>
      </.showcase>

      <%!-- Dropdown --%>
      <.showcase title="Dropdown">
        <.dropdown id="demo-dropdown">
          <:trigger>
            <.button variant="secondary">
              Open Menu <.icon name="hero-chevron-down" class="ml-1 size-4" />
            </.button>
          </:trigger>
          <.dropdown_item>
            <.icon name="hero-user" class="size-4" /> Profile
          </.dropdown_item>
          <.dropdown_item>
            <.icon name="hero-cog-6-tooth" class="size-4" /> Settings
          </.dropdown_item>
          <.dropdown_item>
            <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> Log out
          </.dropdown_item>
        </.dropdown>
      </.showcase>

      <%!-- Modal --%>
      <.showcase title="Modal">
        <.button variant="secondary" phx-click={show_modal("demo-modal")}>
          Open Modal
        </.button>
        <.modal id="demo-modal">
          <h3 class="mb-2 text-lg font-semibold">Modal Title</h3>
          <p class="text-base-content/60 mb-4 text-sm">
            This is a modal dialog with glass-surface styling and backdrop blur.
          </p>
          <.button variant="primary">Confirm</.button>
        </.modal>
      </.showcase>

      <%!-- Empty State --%>
      <.showcase title="Empty State">
        <.card>
          <.empty_state icon="hero-calendar" title={gettext("No events yet")}>
            {gettext("Create your first event to get started.")}
            <:action>
              <.button variant="primary">
                <.icon name="hero-plus" class="mr-1 size-4" /> {gettext("Create event")}
              </.button>
            </:action>
          </.empty_state>
        </.card>
      </.showcase>
    </div>
    """
  end

  defp section_data(assigns) do
    ~H"""
    <div class="space-y-10">
      <%!-- Table --%>
      <.showcase title="Table">
        <.card>
          <.table id="demo-table" rows={sample_members()}>
            <:col :let={m} label={gettext("Name")}>{m.name}</:col>
            <:col :let={m} label="Email">{m.email}</:col>
            <:col :let={m} label={gettext("Role")}>
              <.badge variant={m.badge}>{m.role}</.badge>
            </:col>
            <:action :let={_m}>
              <.button variant="ghost">{gettext("View")}</.button>
            </:action>
          </.table>
        </.card>
      </.showcase>

      <%!-- List --%>
      <.showcase title="List">
        <.card>
          <.list>
            <:item title={gettext("Name")}>Rolf Andersen</:item>
            <:item title="Email">rolf@example.com</:item>
            <:item title={gettext("Role")}>Administrator</:item>
            <:item title={gettext("Created")}>27. maj 2026</:item>
          </.list>
        </.card>
      </.showcase>

      <%!-- Tabs --%>
      <.showcase title="Tabs">
        <.tabs id="demo-tabs">
          <:tab label={gettext("Overview")} active />
          <:tab label={gettext("Members")} />
          <:tab label="Events" />
          <:tab label={gettext("Settings")} />
        </.tabs>
      </.showcase>
    </div>
    """
  end

  defp section_feedback(assigns) do
    ~H"""
    <div class="space-y-10">
      <%!-- Header --%>
      <.showcase title="Header">
        <.header>
          Page Title
          <:subtitle>A subtitle describing this page</:subtitle>
          <:actions>
            <.button variant="primary">Action</.button>
          </:actions>
        </.header>
      </.showcase>

      <%!-- Flash (static preview) --%>
      <.showcase title="Flash Messages">
        <div class="space-y-4">
          <div class="alert alert-info w-96">
            <.icon name="hero-information-circle" class="size-5 shrink-0" />
            <div>
              <p class="font-semibold">Info</p>
              <p>This is an informational message.</p>
            </div>
          </div>
          <div class="alert alert-error w-96">
            <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
            <div>
              <p class="font-semibold">Error</p>
              <p>Something went wrong.</p>
            </div>
          </div>
        </div>
      </.showcase>

      <%!-- Empty states --%>
      <.showcase title="Empty States">
        <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
          <.card>
            <.empty_state icon="hero-users" title={gettext("No members")}>
              {gettext("Invite members to your association.")}
            </.empty_state>
          </.card>
          <.card>
            <.empty_state icon="hero-document-text" title={gettext("No documents")}>
              {gettext("Upload files to get started.")}
              <:action>
                <.button variant="secondary">Upload</.button>
              </:action>
            </.empty_state>
          </.card>
        </div>
      </.showcase>
    </div>
    """
  end

  attr :select_form, :map, required: true

  defp section_forms(assigns) do
    ~H"""
    <div class="space-y-10">
      <.showcase title="Form Inputs">
        <.card class="max-w-md p-6">
          <form class="space-y-4">
            <.input
              name="name"
              label={gettext("Name")}
              value=""
              placeholder={gettext("Enter your name")}
            />
            <.input name="email" label="Email" type="email" value="" placeholder="din@email.dk" />
            <.input name="password" label={gettext("Password")} type="password" value="" />
            <.input
              name="role"
              label={gettext("Role")}
              type="select"
              options={[
                {gettext("Member"), "member"},
                {gettext("Board"), "board"},
                {"Admin", "admin"}
              ]}
              value="member"
            />
            <.input
              name="bio"
              label="Bio"
              type="textarea"
              value=""
              placeholder={gettext("Tell us a bit about yourself...")}
            />
            <.input name="accept" label={gettext("Accept terms")} type="checkbox" value="false" />
            <div class="pt-2">
              <.button variant="primary" type="submit">{gettext("Save")}</.button>
            </div>
          </form>
        </.card>
      </.showcase>

      <.showcase title="Combobox / Multiselect (live_select)">
        <.card class="max-w-md space-y-6 p-6">
          <.form for={@select_form} phx-change="select_demo_change">
            <div class="space-y-1">
              <label class="text-sm font-medium">{gettext("City (single)")}</label>
              <.live_select
                field={@select_form[:city]}
                placeholder={gettext("Search city...")}
                style={:daisyui}
              />
            </div>
            <div class="mt-4 space-y-1">
              <label class="text-sm font-medium">{gettext("Cities (multiselect)")}</label>
              <.live_select
                field={@select_form[:cities]}
                mode={:tags}
                placeholder={gettext("Search cities...")}
                style={:daisyui}
              />
            </div>
          </.form>
        </.card>
      </.showcase>

      <.showcase title="Input with Errors">
        <.card class="max-w-md p-6">
          <.input
            name="email"
            label="Email"
            type="email"
            value="not-an-email"
            errors={["is not a valid email address"]}
          />
          <.input name="name" label={gettext("Name")} value="" errors={["can't be blank"]} />
        </.card>
      </.showcase>
    </div>
    """
  end

  defp section_branding(assigns) do
    ~H"""
    <div class="space-y-10">
      <.showcase title="Branding Override Demo">
        <p class="text-base-content/60 mb-6 text-sm">
          Each forening can override the primary color via CSS custom properties.
          Below, two cards simulate different forening brands.
        </p>
        <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
          <div style="--color-primary: oklch(65% 0.24 25); --color-primary-content: oklch(98% 0.01 25);">
            <.card class="p-6">
              <div class="mb-4 flex items-center gap-3">
                <.avatar initials="RF" size="md" />
                <div>
                  <h3 class="font-semibold">Rødovre Forening</h3>
                  <p class="text-base-content/50 text-xs">Red brand</p>
                </div>
              </div>
              <.button variant="primary" class="w-full">Join forening</.button>
              <div class="mt-3 flex gap-2">
                <.badge variant="primary">Aktiv</.badge>
                <.badge variant="success">Betalt</.badge>
              </div>
            </.card>
          </div>
          <div style="--color-primary: oklch(70% 0.18 155); --color-primary-content: oklch(15% 0.03 155);">
            <.card class="p-6">
              <div class="mb-4 flex items-center gap-3">
                <.avatar initials="GS" size="md" />
                <div>
                  <h3 class="font-semibold">Grøn Spejder</h3>
                  <p class="text-base-content/50 text-xs">Green brand</p>
                </div>
              </div>
              <.button variant="primary" class="w-full">Join forening</.button>
              <div class="mt-3 flex gap-2">
                <.badge variant="primary">Aktiv</.badge>
                <.badge variant="success">Betalt</.badge>
              </div>
            </.card>
          </div>
        </div>
      </.showcase>

      <.showcase title="How It Works">
        <.card class="p-6">
          <pre class="text-base-content/70 overflow-x-auto text-sm"><code>&lt;!-- In layout, driven by forening.branding --&gt;
            &lt;div style="--color-primary: oklch(65% 0.24 25);"&gt;
              &lt;!-- All primary-colored components inside adapt --&gt;
              &lt;.button variant="primary"&gt;Branded&lt;/.button&gt;
              &lt;.badge variant="primary"&gt;Branded&lt;/.badge&gt;
              &lt;.avatar initials="AB" /&gt;
            &lt;/div&gt;</code></pre>
        </.card>
      </.showcase>
    </div>
    """
  end

  defp showcase(assigns) do
    ~H"""
    <div>
      <h2 class="text-base-content/80 mb-4 text-base font-semibold">{@title}</h2>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp sample_members do
    [
      %{name: "Anna Jensen", email: "anna@example.dk", role: "Admin", badge: "primary"},
      %{name: "Lars Petersen", email: "lars@example.dk", role: "Bestyrelse", badge: "secondary"},
      %{name: "Mette Olsen", email: "mette@example.dk", role: "Medlem", badge: "default"},
      %{name: "Erik Sørensen", email: "erik@example.dk", role: "Medlem", badge: "default"}
    ]
  end
end
