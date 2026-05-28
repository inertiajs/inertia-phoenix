defmodule ReactVite.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ReactViteWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:react_vite, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ReactVite.PubSub},
      # Start the SSR Node.js pool. It loads the self-contained CommonJS bundle
      # built by `vite build --ssr` (priv/ssr/ssr.cjs) and calls its `render`
      # export to pre-render Inertia pages on the server.
      {Inertia.SSR,
       path: Path.join([Application.app_dir(:react_vite), "priv", "ssr"]), module: "ssr.cjs"},
      # Start to serve requests, typically the last entry
      ReactViteWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ReactVite.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ReactViteWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
