defmodule Exhs.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExhsWeb.Telemetry,
      Exhs.Repo,
      {DNSCluster, query: Application.get_env(:exhs, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Exhs.PubSub},
      # Start a worker by calling: Exhs.Worker.start_link(arg)
      # {Exhs.Worker, arg},
      # Start to serve requests, typically the last entry
      ExhsWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :exhs]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Exhs.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExhsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
