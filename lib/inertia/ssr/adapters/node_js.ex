defmodule Inertia.SSR.Adapters.NodeJS do
  @moduledoc """
  Default SSR adapter — invokes a pool of Node.js processes to render Inertia
  pages. See `Inertia.SSR.start_link/1` for the accepted options.
  """

  @behaviour Inertia.SSR.Adapter

  # Registered name of the underlying NodeJS.Supervisor pool process.
  @pool_name Inertia.SSR.Supervisor

  defmodule Config do
    @moduledoc false

    @enforce_keys [:path]
    defstruct [:path, :module, :esm, :pool_size]

    @type t :: %__MODULE__{
            path: String.t(),
            module: String.t(),
            esm: boolean(),
            pool_size: pos_integer()
          }
  end

  @impl true
  def init(opts) do
    %Config{
      path: Keyword.fetch!(opts, :path),
      module: Keyword.get(opts, :module, "ssr"),
      esm: Keyword.get(opts, :esm, false),
      pool_size: Keyword.get(opts, :pool_size, 4)
    }
  end

  @impl true
  def children(%Config{path: path, pool_size: pool_size}) do
    [
      {NodeJS.Supervisor, name: @pool_name, path: path, pool_size: pool_size}
    ]
  end

  @impl true
  def call(page, %Config{module: module, esm: esm}) when is_map(page) do
    # ESM module needs the `.js` extension
    module = if(esm, do: "#{module}.js", else: module)

    NodeJS.call({module, :render}, [page],
      name: @pool_name,
      binary: true,
      esm: esm
    )
  end
end
