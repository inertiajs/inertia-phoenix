import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :inertia, MyAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "/O3KVxcR9F1pdBacw1BiK4RQUs6lE6fEeCoND85ebDK6+x8VoKgbojn7lMkRF1ft",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
