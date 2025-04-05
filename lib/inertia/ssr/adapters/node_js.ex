defmodule Inertia.SSR.NodeJS do
  @moduledoc """
  SSR adapter using NodeJS invoked from Elixir.
  """

  @behaviour Inertia.SSRAdapter

  alias Inertia.SSR.Config

  @impl true
  def render(page) when is_map(page) do
    module = GenServer.call(Config, :module)
    esm = GenServer.call(Config, :esm)
    NodeJS.call({module, :render}, [page], name: supervisor_name(), binary: true, esm: esm)
  end

  defp supervisor_name do
    Module.concat(Inertia.SSR, Supervisor)
  end
end
