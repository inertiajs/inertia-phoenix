defmodule Svelte.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SvelteWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:svelte, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Svelte.PubSub},
      # Start the SSR Node.js pool. `path` is the directory holding the compiled
      # ssr.js bundle (built by assets/esbuild.config.js into priv/).
      {Inertia.SSR, path: Path.join([Application.app_dir(:svelte), "priv"])},
      # Start to serve requests, typically the last entry
      SvelteWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Svelte.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SvelteWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
