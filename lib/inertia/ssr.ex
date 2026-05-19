defmodule Inertia.SSR do
  @moduledoc """
  Supervisor for SSR support in Inertia views.
  """
  use Supervisor

  alias Inertia.SSR.Adapter
  alias Inertia.SSR.Adapters.{Bootstrap, NodeJS}

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {adapter, config} = Bootstrap.fetch_adapter(opts: opts, default_adapter: NodeJS)
    :persistent_term.put({__MODULE__, :adapter}, {adapter, config})
    Supervisor.init(adapter.children(config), strategy: :one_for_one)
  end

  @spec call(Adapter.page()) :: Adapter.ssr_result()
  def call(page) do
    {adapter, config} = :persistent_term.get({__MODULE__, :adapter})
    adapter.call(page, config)
  end
end
