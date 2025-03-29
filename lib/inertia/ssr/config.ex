defmodule Inertia.SSR.Config do
  @moduledoc false

  use GenServer

  # Client

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def module(pid) do
    GenServer.call(pid, :module)
  end

  def adapter, do: GenServer.call(__MODULE__, :ssr_adapter)

  # Server (callbacks)

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:module, _from, state) do
    {:reply, state[:module], state}
  end

  @impl true
  def handle_call(:esm, _from, state) do
    {:reply, state[:esm], state}
  end

  @impl true
  def handle_call(:ssr_adapter, _from, state) do
    {:reply, state[:ssr_adapter], state}
  end
end
