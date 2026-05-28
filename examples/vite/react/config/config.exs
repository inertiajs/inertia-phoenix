# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :react_vite,
  generators: [timestamp_type: :utc_datetime]

config :inertia, endpoint: ReactViteWeb.Endpoint, ssr: true

# Configure the endpoint
config :react_vite, ReactViteWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ReactViteWeb.ErrorHTML, json: ReactViteWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ReactVite.PubSub,
  live_view: [signing_salt: "CpN8Uq9L"]

# Vite is invoked through the `mix phoenix_vite.npm <profile> <args>` task
# (PhoenixVite.Npm), which shells out to `npm` in the assets directory. The
# `assets` profile runs bare `npm` (e.g. `npm install`); the `vite` profile runs
# the locally installed Vite CLI (e.g. `npm exec -- vite dev|build`).
config :phoenix_vite, PhoenixVite.Npm,
  assets: [args: [], cd: Path.expand("../assets", __DIR__)],
  vite: [args: ~w(exec -- vite), cd: Path.expand("../assets", __DIR__)]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
