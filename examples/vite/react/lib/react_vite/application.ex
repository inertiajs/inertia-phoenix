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
      ssr_spec(),
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

  # Selects the SSR runtime. In development (config/dev.exs sets `:ssr_adapter`)
  # we render through the running Vite dev server, so no `--ssr` build or Node
  # pool is needed; otherwise (production/test) we load the pre-built CommonJS
  # bundle (priv/ssr/ssr.cjs) via the default Node.js pool.
  defp ssr_spec do
    case Application.get_env(:react_vite, :ssr_adapter) do
      nil ->
        {Inertia.SSR,
         path: Path.join([Application.app_dir(:react_vite), "priv", "ssr"]), module: "ssr.cjs"}

      adapter ->
        {Inertia.SSR, ssr_adapter: adapter}
    end
  end
end
