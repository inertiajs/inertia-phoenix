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
  def handle_call(:esm_cache_busting, _from, state) do
    {:reply, state[:esm_cache_busting], state}
  end

  @impl true
  def handle_call(:esm_module_extension, _from, state) do
    {:reply, state[:esm_module_extension], state}
  end
end
