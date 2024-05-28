defmodule Inertia.SSR do
  @moduledoc """
  A supervisor that provides SSR support for Inertia views.
  """

  use Supervisor

  require Logger

  alias Inertia.SSR.Config

  @default_pool_size 4
  @default_module "ssr"

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
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

  def call(page) do
    module = GenServer.call(Config, :module)
    NodeJS.call({module, :render}, [page], name: supervisor_name())
  end

  defp supervisor_name do
    Module.concat(__MODULE__, Supervisor)
  end
end
