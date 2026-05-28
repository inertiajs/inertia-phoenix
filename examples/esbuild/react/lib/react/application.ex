defmodule React.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ReactWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:react, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: React.PubSub},
      # Start the SSR Node.js pool. `path` is the directory holding the compiled
      # ssr.js bundle (built by the `ssr` esbuild profile into priv/).
      {Inertia.SSR, path: Path.join([Application.app_dir(:react), "priv"])},
      # Start to serve requests, typically the last entry
      ReactWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: React.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ReactWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
