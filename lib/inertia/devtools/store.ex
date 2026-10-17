defmodule Inertia.DevTools.Store do
  @moduledoc false

  # Holds recorded entries in a public ETS table. Request processes write to the
  # table directly, so recording never waits on this process; it only keeps the
  # per-tab bookkeeping used to evict the oldest entries, and prunes expired ones.

  use GenServer

  @table __MODULE__
  @default_limit 100
  @default_ttl 3600
  @prune_interval :timer.minutes(1)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns whether the store is running.
  """
  @spec running?() :: boolean()
  def running? do
    :ets.whereis(@table) != :undefined
  end

  @doc """
  Stores an entry. The entry is held as pre-encoded JSON so the read endpoint
  never has to encode it, alongside its `__meta` for listing.
  """
  @spec put(String.t(), String.t() | nil, map(), iodata()) :: :ok
  def put(id, tab, meta, json) do
    :ets.insert(@table, {id, tab, System.monotonic_time(:second), meta, json})
    GenServer.cast(__MODULE__, {:inserted, id, tab})
  end

  @doc """
  Fetches an entry's encoded JSON by id.
  """
  @spec fetch(String.t()) :: {:ok, iodata()} | :error
  def fetch(id) do
    case :ets.lookup(@table, id) do
      [{^id, _tab, _inserted_at, _meta, json}] -> {:ok, json}
      [] -> :error
    end
  end

  @doc """
  Lists the `__meta` of every stored entry, newest first.
  """
  @spec list() :: [map()]
  def list do
    @table
    |> :ets.tab2list()
    |> Enum.sort_by(&elem(&1, 0), :desc)
    |> Enum.map(&elem(&1, 3))
  end

  @impl true
  def init(opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    schedule_prune()

    {:ok,
     %{
       limit: Keyword.get(opts, :limit, @default_limit),
       ttl: Keyword.get(opts, :ttl, @default_ttl),
       tabs: %{}
     }}
  end

  # Each tab (entries with no tab share one bucket) keeps a queue of its entry
  # ids, oldest first, so the oldest can be evicted once the tab is over limit.
  #
  # A prune rebuilds the queues from the table, so an entry inserted just
  # before it may already be queued by the time its cast arrives.
  @impl true
  def handle_cast({:inserted, id, tab}, state) do
    queue = Map.get(state.tabs, tab, :queue.new())

    if :queue.member(id, queue) do
      {:noreply, state}
    else
      queue = :queue.in(id, queue)
      {:noreply, %{state | tabs: Map.put(state.tabs, tab, evict(queue, state.limit))}}
    end
  end

  @impl true
  def handle_info(:prune, state) do
    cutoff = System.monotonic_time(:second) - state.ttl
    :ets.select_delete(@table, [{{:_, :_, :"$1", :_, :_}, [{:<, :"$1", cutoff}], [true]}])
    schedule_prune()

    {:noreply, %{state | tabs: rebuild_tabs()}}
  end

  defp evict(queue, limit) do
    if :queue.len(queue) > limit do
      {{:value, id}, queue} = :queue.out(queue)
      :ets.delete(@table, id)
      evict(queue, limit)
    else
      queue
    end
  end

  defp rebuild_tabs do
    @table
    |> :ets.select([{{:"$1", :"$2", :_, :_, :_}, [], [{{:"$2", :"$1"}}]}])
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {tab, ids} -> {tab, ids |> Enum.sort() |> :queue.from_list()} end)
  end

  defp schedule_prune do
    Process.send_after(self(), :prune, @prune_interval)
  end
end
