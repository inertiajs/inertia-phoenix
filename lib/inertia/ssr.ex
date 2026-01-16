defmodule Inertia.SSR do
  alias Inertia.SSR.{Config, Adapter}
  alias Inertia.SSR.Adapters.{Bootstrap, NodeJS}

  @moduledoc """
  Supervisor for SSR support in Inertia views.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(opts) do
    {adapter, config} = Bootstrap.fetch_adapter(opts: opts, default_adapter: NodeJS)
    children = [{Config, adapter: adapter, config: config}] ++ adapter.children(config)
    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec call(Adapter.page()) :: Adapter.ssr_result()
  def call(page) do
    Config.call(page)
  end
end
