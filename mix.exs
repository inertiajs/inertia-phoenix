defmodule Inertia.MixProject do
  use Mix.Project

  def project do
    [
      app: :inertia,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:plug_cowboy, "~> 2.1", only: :test},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
