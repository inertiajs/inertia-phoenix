[
  import_deps: [:phoenix, :plug],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib}/**/*.{heex,ex,exs}",
    "test/*.exs",
    "test/{inertia,js,mix}/**/*.{heex,ex,exs}",
    "test/support/*.{ex,exs}"
  ]
]
