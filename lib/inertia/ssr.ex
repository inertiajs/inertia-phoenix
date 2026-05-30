defmodule Inertia.SSR do
  @moduledoc """
  Supervisor that provides server-side rendering support for Inertia views.

  By default SSR is performed by a pool of Node.js workers
  (`Inertia.SSR.NodeJSAdapter`), which requires the optional `:nodejs`
  dependency. You can plug in an alternative runtime by implementing the
  `Inertia.SSR.Adapter` behaviour and passing the module as the `:ssr_adapter`
  option (in which case `:nodejs` is not needed).
  """
  use Supervisor

  alias Inertia.SSR.Adapter
  alias Inertia.SSR.NodeJSAdapter

  @doc """
  Starts the SSR supervisor and its adapter children.

  ## Options

  - `:ssr_adapter` - (optional) a module implementing the
    `Inertia.SSR.Adapter` behaviour. Defaults to `Inertia.SSR.NodeJSAdapter`.

  Any additional options are forwarded to the adapter's
  `c:Inertia.SSR.Adapter.init/1` callback. The default Node.js adapter
  accepts:

  - `:path` - (required) the path to the directory where your `ssr.js` file lives.
  - `:module` - (optional) the name of the Node.js module file. Defaults to `"ssr"`.
  - `:esm` - (optional) whether the SSR entrypoint is an ESM module. If unset,
    ESM is auto-detected from a `.mjs` module extension.
  - `:pool_size` - (optional) the number of Node.js workers. Defaults to `4`.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  @doc false
  def init(opts) do
    adapter = resolve_adapter(Keyword.get(opts, :ssr_adapter), NodeJSAdapter)
    config = adapter.init(opts)
    :persistent_term.put({__MODULE__, :adapter}, {adapter, config})
    Supervisor.init(adapter.children(config), strategy: :one_for_one)
  end

  @doc false
  @spec call(Adapter.page()) :: Adapter.ssr_result()
  def call(page) do
    {adapter, config} = :persistent_term.get({__MODULE__, :adapter})
    adapter.call(page, config)
  end

  defp resolve_adapter(nil, default) do
    if Code.ensure_loaded?(default) do
      default
    else
      raise ArgumentError, """
      The default Inertia SSR adapter (#{inspect(default)}) is unavailable because \
      the optional :nodejs dependency is not installed.

      Add it to your deps to use Node.js-based SSR:

          {:nodejs, "~> 3.0"}

      Or pass a custom module via the :ssr_adapter option.
      """
    end
  end

  defp resolve_adapter(custom, _default) do
    cond do
      not is_atom(custom) ->
        raise ArgumentError,
              "invalid :ssr_adapter — expected a module, got: #{inspect(custom)}"

      not Code.ensure_loaded?(custom) ->
        raise ArgumentError,
              "invalid :ssr_adapter — module #{inspect(custom)} could not be loaded"

      not adapter?(custom) ->
        raise ArgumentError,
              "invalid :ssr_adapter — module #{inspect(custom)} does not implement the Inertia.SSR.Adapter behaviour"

      true ->
        custom
    end
  end

  defp adapter?(module) do
    function_exported?(module, :init, 1) and
      function_exported?(module, :children, 1) and
      function_exported?(module, :call, 2)
  end
end
