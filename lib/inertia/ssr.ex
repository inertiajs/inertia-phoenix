defmodule Inertia.SSR do
  @moduledoc """
  A supervisor that provides SSR support for Inertia views.
  """

  use Supervisor

  require Logger

  @default_pool_size 4

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    path = Keyword.fetch!(opts, :path)
    pool_size = Keyword.get(opts, :pool_size, @default_pool_size)

    children = [
      {NodeJS.Supervisor, name: name(), path: path, pool_size: pool_size}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def call!(page, opts) do
    module = opts[:module] || "ssr"
    NodeJS.call!({module, :render}, [page], name: name())
  end

  defp name do
    Module.concat(__MODULE__, Supervisor)
  end
end
