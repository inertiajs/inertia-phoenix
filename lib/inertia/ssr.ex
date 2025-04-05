defmodule Inertia.SSR do
  @moduledoc """
  Supervisor for SSR support in Inertia views.
  """

  use Supervisor

  alias Inertia.SSR.Adapter

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(opts) do
    adapter = set_adapter(opts)
    Supervisor.init(adapter.children(), strategy: :one_for_one)
  end

  @spec call(Adapter.page()) :: Adapter.ssr_result()
  def call(page) do
    adapter().call(page)
  end

  defp set_adapter(opts) do
    adapter = Adapter.init(opts)
    :persistent_term.put({__MODULE__, :adapter}, adapter)
    adapter
  end

  defp adapter do
    :persistent_term.get({__MODULE__, :adapter})
  end
end
