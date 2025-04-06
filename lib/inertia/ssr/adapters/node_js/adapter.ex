defmodule Inertia.SSR.Adapters.NodeJS do
  alias Inertia.SSR.Supervisor, as: SSRSupervisor
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

  use Inertia.SSR.Adapters.Config, name: :nodejs, config: Config

  @impl true
  def children(%Config{path: path, pool_size: pool_size}) do
    [
      {NodeJS.Supervisor, name: SSRSupervisor, path: path, pool_size: pool_size}
    ]
  end

  @impl true
  def call(page, %Config{module: module, esm: esm}) when is_map(page) do
    NodeJS.call({module, :render}, [page],
      name: SSRSupervisor,
      binary: true,
      esm: esm
    )
  end
end
