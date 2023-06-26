import Config

config :inertia, MyAppWeb.Endpoint,
  url: [host: "localhost"],
  cache_static_manifest: "priv/static/cache_manifest.json",
  render_errors: [
    formats: [html: MyAppWeb.ErrorHTML, json: MyAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MyApp.PubSub,
  live_view: [signing_salt: "+r1ZDDS5"]

config :inertia,
  endpoint: MyAppWeb.Endpoint,
  static_paths: ["/assets/app.js"],
  default_version: "1"

config :phoenix, :json_library, Jason

if Mix.env() == :test do
  import_config "test.exs"
end
