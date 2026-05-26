defmodule ExhsWeb.Router do
  use ExhsWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :mcp do
    plug AshAuthentication.Strategy.ApiKey.Plug,
      resource: Exhs.Accounts.User,
      # Use `required?: false` to allow unauthenticated
      # users to connect, for example if some tools
      # are publicly accessible.
      required?: true
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExhsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    plug ExhsWeb.Plugs.Subdomain
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user

    plug AshAuthentication.Strategy.ApiKey.Plug,
      resource: Exhs.Accounts.User,
      # if you want to require an api key to be supplied, set `required?` to true
      required?: false
  end

  pipeline :stripe_webhook do
    plug :accepts, ["json"]
  end

  scope "/webhook", ExhsWeb do
    pipe_through :stripe_webhook

    post "/stripe", StripeWebhookController, :create
  end

  scope "/mcp" do
    pipe_through :mcp

    forward "/", AshAi.Mcp.Router,
      tools: [
        # list your tools here
        # :tool1,
        # :tool2,
        # For many tools, you will need to set the `protocol_version_statement` to the older version.
      ],
      protocol_version_statement: "2024-11-05",
      otp_app: :exhs
  end

  scope "/", ExhsWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes do
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {ExhsWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {ExhsWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {ExhsWeb.LiveUserAuth, :live_no_user}
    end
  end

  scope "/", ExhsWeb do
    pipe_through :browser

    get "/", PageController, :home
    auth_routes AuthController, Exhs.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{ExhsWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    ExhsWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  ExhsWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route Exhs.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [ExhsWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Exhs.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [ExhsWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", ExhsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:exhs, :dev_routes) do
    import Phoenix.LiveDashboard.Router
    import Oban.Web.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ExhsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
      oban_dashboard "/oban"
    end
  end

  if Application.compile_env(:exhs, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
