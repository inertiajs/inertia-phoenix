defmodule Inertia.SSR do
  @moduledoc """
  A supervisor that provides SSR support for Inertia views. This module is
  responsible for starting a pool of Node.js processes that can run the SSR
  rendering function for your application.
  """

  use Supervisor

  require Logger

  alias Inertia.SSR.Config

  @default_pool_size 4
  @default_module "ssr"

  @doc """
  Starts the SSR supervisor and accompanying Node.js workers.

  ## Options

  - `:path` - (required) the path to the directory where your `ssr.js` file lives.
  - `:module` - (optional) the name of the Node.js module file. Defaults to "#{@default_module}".
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
    pool_size = Keyword.get(opts, :pool_size, @default_pool_size)

    children = [
      {Config, module: module},
      {NodeJS.Supervisor, name: supervisor_name(), path: path, pool_size: pool_size}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def call(page) do
    module = GenServer.call(Config, :module)
    NodeJS.call({module, :render}, [page], name: supervisor_name(), binary: true)
  end

  defp supervisor_name do
    Module.concat(__MODULE__, Supervisor)
  end
end
