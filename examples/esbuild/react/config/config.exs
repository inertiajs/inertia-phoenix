# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :react,
  generators: [timestamp_type: :utc_datetime]

config :inertia, endpoint: ReactWeb.Endpoint, ssr: true

# Configure the endpoint
config :react, ReactWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ReactWeb.ErrorHTML, json: ReactWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: React.PubSub,
  live_view: [signing_salt: "P3w+2qI3"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  react: [
    args:
      ~w(js/app.jsx --bundle --chunk-names=chunks/[name]-[hash] --splitting --format=esm --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ],
  # SSR bundle: a Node/CommonJS module at priv/ssr.js that the Inertia.SSR pool
  # loads to pre-render pages on the server.
  ssr: [
    args:
      ~w(js/ssr.jsx --bundle --platform=node --outdir=../priv --format=cjs --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  react: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
