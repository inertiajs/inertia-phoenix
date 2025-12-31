defmodule Inertia.SSR.Config do
  @moduledoc false

  alias Inertia.SSR.Adapter

  use GenServer

  @type state :: %{adapter: module(), config: struct()}

  def start_link(opts) do
    adapter = Keyword.fetch!(opts, :adapter)
    config = Keyword.fetch!(opts, :config)

    GenServer.start_link(
      __MODULE__,
      %{
        adapter: adapter,
        config: config
      },
      name: __MODULE__
    )
  end

  @doc "Stores the adapter module and its config"
  def set_adapter(adapter_module, config) do
    GenServer.call(__MODULE__, {:set_adapter, adapter_module, config})
  end

  @doc "Forwards the page call to the adapter"
  def call(page) do
    GenServer.call(__MODULE__, {:call, page})
  end

  @impl true
  @spec init(state()) :: {:ok, state()}
  def init(state), do: {:ok, state}

  @impl true
  @spec handle_call(
          {:call, Adapter.page()},
          GenServer.from(),
          state()
        ) :: {:reply, Adapter.ssr_result(), state()}
  def handle_call({:call, page}, _from, %{adapter: adapter, config: config} = state) do
    {:reply, adapter.call(page, config), state}
  end

  @impl true
  def handle_call({:set_adapter, adapter_module, config}, _from, _state) do
    {:reply, :ok, %{adapter: adapter_module, config: config}}
  end
end
