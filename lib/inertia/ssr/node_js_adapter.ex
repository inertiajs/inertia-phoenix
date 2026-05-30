# The default SSR adapter relies on the optional :nodejs dependency, so it is
# only compiled when that package is available. Apps using Node.js-based SSR add
# `{:nodejs, "~> 3.0"}` to their deps.
if match?({:module, _}, Code.ensure_compiled(NodeJS)) do
  defmodule Inertia.SSR.NodeJSAdapter do
    @moduledoc """
    Default SSR adapter — invokes a pool of Node.js processes to render Inertia
    pages. See `Inertia.SSR.start_link/1` for the accepted options.

    Requires the optional `:nodejs` dependency.
    """

    @behaviour Inertia.SSR.Adapter

    # Registered name of the underlying NodeJS.Supervisor pool process.
    @pool_name Inertia.SSR.Supervisor

    @impl true
    def init(opts) do
      %{
        path: Keyword.fetch!(opts, :path),
        module: Keyword.get(opts, :module, "ssr"),
        esm: Keyword.get(opts, :esm),
        pool_size: Keyword.get(opts, :pool_size, 4)
      }
    end

    @impl true
    def children(%{path: path, pool_size: pool_size}) do
      [
        {NodeJS.Supervisor, name: @pool_name, path: path, pool_size: pool_size}
      ]
    end

    @impl true
    def call(page, %{module: module, esm: esm}) when is_map(page) do
      module = ensure_extension(module, esm)
      NodeJS.call({module, :render}, [page], call_opts(esm))
    end

    # When ESM is explicitly enabled and the module has no extension, append .js
    # so Node can resolve the file (e.g. a `.js` entrypoint with a `package.json`
    # declaring `"type": "module"`). Pre-extensioned modules pass through as-is.
    defp ensure_extension(module, true) do
      if Path.extname(module) == "", do: "#{module}.js", else: module
    end

    defp ensure_extension(module, _), do: module

    # Only forward :esm when the user explicitly set it. Otherwise leave it off
    # so the underlying nodejs package auto-detects ESM from a `.mjs` extension.
    defp call_opts(nil), do: [name: @pool_name, binary: true]
    defp call_opts(esm), do: [name: @pool_name, binary: true, esm: esm]
  end
end
