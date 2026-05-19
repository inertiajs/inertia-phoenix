defmodule Inertia.SSR do
  @moduledoc """
  Supervisor that provides server-side rendering support for Inertia views.

  By default SSR is performed by a pool of Node.js workers
  (`Inertia.SSR.Adapters.NodeJS`). You can plug in an alternative runtime by
  implementing the `Inertia.SSR.Adapter` behaviour and passing the module as
  the `:ssr_adapter` option.
  """
  use Supervisor

  alias Inertia.SSR.Adapter
  alias Inertia.SSR.Adapters.{Bootstrap, NodeJS}

  @doc """
  Starts the SSR supervisor and its adapter children.

  ## Options

  - `:ssr_adapter` - (optional) a module implementing the
    `Inertia.SSR.Adapter` behaviour. Defaults to `Inertia.SSR.Adapters.NodeJS`.

  Any additional options are forwarded to the adapter's
  `c:Inertia.SSR.Adapter.init/1` callback. The default Node.js adapter
  accepts:

  - `:path` - (required) the path to the directory where your `ssr.js` file lives.
  - `:module` - (optional) the name of the Node.js module file. Defaults to `"ssr"`.
  - `:esm` - (optional) whether the SSR entrypoint is an ESM module. Defaults to `false`.
  - `:pool_size` - (optional) the number of Node.js workers. Defaults to `4`.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  @doc false
  def init(opts) do
    {adapter, config} = Bootstrap.fetch_adapter(opts: opts, default_adapter: NodeJS)
    :persistent_term.put({__MODULE__, :adapter}, {adapter, config})
    Supervisor.init(adapter.children(config), strategy: :one_for_one)
  end

  @doc false
  @spec call(Adapter.page()) :: Adapter.ssr_result()
  def call(page) do
    {adapter, config} = :persistent_term.get({__MODULE__, :adapter})
    adapter.call(page, config)
  end
end
