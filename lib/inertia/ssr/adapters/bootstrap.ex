defmodule Inertia.SSR.Adapters.Bootstrap do
  @moduledoc false

  require Logger
  alias Inertia.SSR.Adapter

  @adapters %{
    nodejs: Inertia.SSR.Adapters.NodeJS,
    vitejs: Inertia.SSR.Adapters.ViteJS
  }

  @spec fetch_adapter(
          opts: keyword(),
          default_adapter: module()
        ) :: {module(), Adapter.adapter_config()}
  def fetch_adapter(opts: opts, default_adapter: default_adapter) do
    adapter = resolve_adapter(default_adapter)
    config = adapter.init(opts)
    {adapter, config}
  end

  defp resolve_adapter(default_adapter) do
    name =
      case Application.get_env(:inertia, :ssr_adapter, nil) do
        nil -> nil
        string when is_binary(string) -> String.to_atom(string)
        atom when is_atom(atom) -> atom
      end

    @adapters[name] || default_adapter
  end
end
