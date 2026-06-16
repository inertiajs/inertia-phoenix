defmodule ReactVite.MixProject do
  use Mix.Project

  def project do
    [
      app: :react_vite,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ReactVite.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      # Uses the local inertia-phoenix checkout (three directories up). In a real
      # app this would be `{:inertia, "~> 3.0"}` from Hex.
      {:inertia, path: "../../.."},
      # inertia lists :nodejs as an optional dep, so apps that use the default
      # Node.js SSR adapter (Inertia.SSR.NodeJSAdapter) must require it themselves.
      {:nodejs, "~> 3.0"},
      # phoenix_vite drives Vite as the asset build tool: it provides the HEEx
      # component that loads assets from the Vite dev server (dev) or the Vite
      # manifest (prod), plus the `mix phoenix_vite.npm` task used by the aliases
      # below. The esbuild/tailwind Hex CLIs are not used here.
      {:phoenix_vite, "~> 0.4.3"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      # `npm install` in the assets dir (pulls in React, Inertia, Vite, and the
      # phoenix_vite npm plugin via `file:../deps/phoenix_vite`).
      "assets.setup": ["phoenix_vite.npm assets install"],
      # `vite build` writes the client bundle + manifest to priv/static, and
      # `vite build --ssr` writes the self-contained Node SSR bundle to priv/ssr.
      "assets.build": [
        "phoenix_vite.npm vite build",
        "phoenix_vite.npm vite build --ssr js/ssr.jsx"
      ],
      # Vite's manifest replaces phx.digest (see PhoenixVite.cache_static_manifest_latest
      # in config/runtime.exs), so deploy just runs the production build.
      "assets.deploy": ["assets.build"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
