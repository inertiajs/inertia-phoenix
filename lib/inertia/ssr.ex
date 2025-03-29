defmodule Inertia.SSR do
  @moduledoc """
  A supervisor that provides SSR support for Inertia views. This module is
  responsible for starting a pool of Node.js processes that can run the SSR
  rendering function for your application.
  """

  use Supervisor

  require Logger

  alias Inertia.SSR.Config
  alias Inertia.SSRAdapter, as: Adapter

  @default_pool_size 4
  @default_module "ssr"
  @default_esm false
  @default_ssr_adapter Inertia.SSR.NodeJS

  @doc """
  Starts the SSR supervisor and accompanying Node.js workers.

  ## Options

  - `:path` - (required) the path to the directory where your `ssr.js` file lives.
  - `:module` - (optional) the name of the Node.js module file. Defaults to "#{@default_module}".
  - `:esm` - (optional) Use ESM for the generated ssr.js file. Defaults to #{@default_esm}.
  - `:ssr_adapter` - (optional) the name of the Node.js module file. Defaults to "#{@default_ssr_adapter}
  - `:pool_size` - (optional) the number of Node.js workers. Defaults to #{@default_pool_size}.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  @doc false
  def init(opts) do
    path = Keyword.fetch!(opts, :path)
    module = Keyword.get(opts, :module, @default_module)
    esm = Keyword.get(opts, :esm, @default_esm)
    ssr_adapter = Keyword.get(opts, :ssr_adapter, @default_ssr_adapter)
    pool_size = Keyword.get(opts, :pool_size, @default_pool_size)

    children = [
      {Config, module: module, esm: esm, ssr_adapter: ssr_adapter},
      {NodeJS.Supervisor, name: supervisor_name(), path: path, pool_size: pool_size}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  @spec call(Adapter.page()) :: Adapter.ssr_result()
  def call(page) do
    ssr_adapter = GenServer.call(Config, :ssr_adapter)
    ssr_adapter.render(page)
    Config.adapter().render(page)
  end

  defp supervisor_name do
    Module.concat(__MODULE__, Supervisor)
  end
end
