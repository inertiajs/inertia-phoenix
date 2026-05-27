defmodule Inertia.MixProject do
  use Mix.Project

  @version "3.0.0-rc1"

  def project do
    [
      app: :inertia,
      version: @version,
      elixir: ">= 1.14.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      name: "Inertia",
      source_url: links()["GitHub"],
      homepage_url: links()["GitHub"],
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      dialyzer: [ignore_warnings: "dialyzer.ignore-warnings", plt_add_apps: [:mix]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phx_new, "~> 1.0", only: [:test]},
      {:phoenix, "~> 1.7"},
      {:phoenix_html, ">= 3.0.0"},
      {:phoenix_live_view, "~> 1.0"},
      {:plug, ">= 1.5.0 and < 2.0.0"},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.2", only: :test},
      {:phoenix_view, "~> 2.0", only: :test},
      {:plug_cowboy, "~> 2.1", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.7", optional: true},
      {:nodejs, "~> 3.0"},
      {:ecto, ">= 3.0.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: [
        "README.md",
        # Bundler-prefixed output names (e.g. esbuild_svelte.html) leave room for
        # a future guides/vite/svelte.md -> vite_svelte.html without colliding.
        {"guides/esbuild/svelte.md", filename: "esbuild_svelte"},
        {"guides/esbuild/vue.md", filename: "esbuild_vue"},
        "guides/upgrading_to_v3.md",
        "CHANGELOG.md",
        "LICENSE.md"
      ],
      # Group the framework setup guides under their bundler so we can add other
      # bundlers (e.g. a Vite section) later without reshuffling the sidebar.
      groups_for_extras: [
        "Bundling with esbuild": ~r"guides/esbuild/"
      ]
    ]
  end

  defp description do
    "The Inertia.js adapter for Elixir/Phoenix."
  end

  defp package do
    [
      maintainers: ["Derrick Reimer"],
      licenses: ["MIT"],
      links: links()
    ]
  end

  def links do
    %{
      "GitHub" => "https://github.com/inertiajs/inertia-phoenix",
      "Changelog" =>
        "https://github.com/inertiajs/inertia-phoenix/blob/v#{@version}/CHANGELOG.md",
      "Readme" => "https://github.com/inertiajs/inertia-phoenix/blob/v#{@version}/README.md"
    }
  end
end
