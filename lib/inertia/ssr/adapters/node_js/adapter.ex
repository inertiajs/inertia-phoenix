defmodule Inertia.SSR.Adapters.NodeJS do
  alias Inertia.SSR.Adapters.NodeJS.Config

  @moduledoc """
  ## Options

  - `:path` - (required) the path to the directory where your `ssr.js` file lives.
  - `:module` - (optional) the name of the Node.js module file
  - `:esm` - (optional) Use ESM for the generated ssr.js file
  - `:ssr_adapter` - (optional) adapter determining how nodejs is executed in elixir
  - `:pool_size` - (optional) the number of Node.js workers

  SSR adapter using NodeJS invoked from Elixir.
  """

  use Inertia.SSR.Adapters.Macro, Inertia.SSR.Adapters.NodeJS.Config

  @impl true
  def children() do
    %Config{path: path, pool_size: pool_size} = config()

    [
      {NodeJS.Supervisor, name: supervisor_name(), path: path, pool_size: pool_size}
    ]
  end

  @impl true
  def call(page) when is_map(page) do
    %Config{module: module, esm: esm} = config()

    NodeJS.call({module, :render}, [page],
      name: supervisor_name(),
      binary: true,
      esm: esm
    )
  end

  defp supervisor_name do
    Module.concat(Inertia.SSR, Supervisor)
  end
end
