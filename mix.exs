defmodule Inertia.MixProject do
  use Mix.Project

  @version "1.0.0-beta.1"

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
      dialyzer: [ignore_warnings: "dialyzer.ignore-warnings"]
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
      {:phoenix, "~> 1.7"},
      {:phoenix_html, ">= 3.0.0"},
      {:phoenix_live_view, "~> 0.18"},
      {:plug, ">= 1.5.0 and < 2.0.0"},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.2", only: :test},
      {:phoenix_view, "~> 2.0", only: :test},
      {:plug_cowboy, "~> 2.1", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
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
        "CHANGELOG.md",
        "LICENSE.md"
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
