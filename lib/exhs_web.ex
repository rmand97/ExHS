defmodule ExhsWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use ExhsWeb, :controller
      use ExhsWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: ExhsWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: ExhsWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import ExhsWeb.CoreComponents
      import ExhsWeb.Components.Icon
      import ExhsWeb.Components.Flash
      import ExhsWeb.Components.Button
      import ExhsWeb.Components.Input
      import ExhsWeb.Components.Header
      import ExhsWeb.Components.Table
      import ExhsWeb.Components.List
      import ExhsWeb.Components.Card
      import ExhsWeb.Components.Badge
      import ExhsWeb.Components.Avatar
      import ExhsWeb.Components.StatCard
      import ExhsWeb.Components.Tabs
      import ExhsWeb.Components.Modal
      import ExhsWeb.Components.EmptyState
      import ExhsWeb.Components.Skeleton
      import ExhsWeb.Components.Dropdown

      # Common modules used in templates
      alias ExhsWeb.Layouts
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: ExhsWeb.Endpoint,
        router: ExhsWeb.Router,
        statics: ExhsWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
