defmodule Inertia.DevTools do
  @moduledoc """
  Server-side support for [Inertia DevTools](https://inertiajs.com/docs/devtools),
  the browser extension for inspecting Inertia requests, props, and page state.

  When enabled, `Inertia.Plug` records each request it handles, and the
  extension fetches the recorded entries from an endpoint mounted in your
  router.

  ## Setup

  Enable DevTools in your development config:

      # config/dev.exs
      config :inertia, :devtools, enabled: true

  Add `Inertia.DevTools` to your application's supervision tree. It holds the
  recorded entries, and does not start at all when DevTools is disabled, so it
  can be added unconditionally:

      children = [
        # ...
        Inertia.DevTools
      ]

  Mount the endpoint the extension reads entries from. The generated
  `dev_routes` block in your router is a good place for it:

      if Application.compile_env(:my_app, :dev_routes) do
        import Inertia.DevTools.Router

        scope "/" do
          inertia_devtools()
        end

        # ...
      end

  Do not pipe the DevTools routes through your `:browser` pipeline. The
  extension fetches each entry the moment its response arrives, racing the
  app's own next request, and a pipeline that fetches the flash or runs
  `Inertia.Plug` could consume the flash and errors meant for the next page.
  Under any other pipeline, the endpoint leaves the session untouched.

  Finally, make sure the client's development integrations are enabled. The
  extension relies on them to group related requests and to identify deferred
  and polling visits. They are controlled by the `dev` option of
  `createInertiaApp`, which defaults to `import.meta.env.DEV`. Vite defines it
  in development, but esbuild does not, so esbuild apps should define it in
  their development watcher:

      # config/dev.exs
      config :my_app, MyAppWeb.Endpoint,
        watchers: [
          esbuild:
            {Esbuild, :install_and_run,
             [:my_app, ~w(--sourcemap=inline --watch --define:import.meta.env.DEV=true)]}
        ]

  Left undefined in production builds, `import.meta.env.DEV` reads as false.

  ## Configuration

  The following options are available under `config :inertia, :devtools`:

    * `:enabled` - whether requests are recorded. Defaults to `false`.
    * `:limit` - the maximum number of entries kept per browser tab. Defaults
      to `100`.
    * `:ttl` - how long entries are kept, in seconds. Defaults to `3600`.
    * `:redact_keys` - additional param and prop keys whose values are
      redacted. Passwords, tokens, and secrets are redacted by default, as are
      the keys in Phoenix's `:filter_parameters` config.
    * `:redact_headers` - additional headers whose values are redacted.
      Cookies, authorization, and CSRF headers are redacted by default.
    * `:component_path` - a path template (or list of templates) used to link
      page components to their source files, with `{component}` replaced by
      the component name. For example, `"assets/js/pages/{component}.tsx"`.

  ## Production

  DevTools is meant for development. If you enable it anywhere else, protect
  the endpoint behind a pipeline that authorizes the developer. Entries are
  held in memory on each node, so the extension can only read entries
  recorded by the node that serves its request.
  """

  alias Inertia.DevTools.Store

  @doc false
  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  @doc """
  Starts the DevTools entry store, or returns `:ignore` when DevTools is
  disabled.
  """
  @spec start_link(keyword()) :: GenServer.on_start() | :ignore
  def start_link(opts \\ []) do
    if enabled?() do
      config = Application.get_env(:inertia, :devtools, [])
      Store.start_link(Keyword.merge(Keyword.take(config, [:limit, :ttl]), opts))
    else
      :ignore
    end
  end

  @doc """
  Returns whether DevTools is enabled.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    :inertia |> Application.get_env(:devtools, []) |> Keyword.get(:enabled, false) == true
  end

  @doc false
  @spec active?() :: boolean()
  def active? do
    enabled?() and Store.running?()
  end
end
