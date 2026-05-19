defmodule Inertia.SSR.Adapters.Bootstrap do
  @moduledoc false

  alias Inertia.SSR.Adapter

  @spec fetch_adapter(keyword(), module()) :: {module(), Adapter.adapter_config()}
  def fetch_adapter(opts, default_adapter) do
    adapter = resolve_adapter(Keyword.get(opts, :ssr_adapter), default_adapter)
    {adapter, adapter.init(opts)}
  end

  defp resolve_adapter(nil, default_adapter), do: default_adapter

  defp resolve_adapter(custom_adapter, _default_adapter) do
    cond do
      not is_atom(custom_adapter) ->
        raise ArgumentError,
              "invalid :ssr_adapter — expected a module, got: #{inspect(custom_adapter)}"

      not Code.ensure_loaded?(custom_adapter) ->
        raise ArgumentError,
              "invalid :ssr_adapter — module #{inspect(custom_adapter)} could not be loaded"

      not adapter?(custom_adapter) ->
        raise ArgumentError,
              "invalid :ssr_adapter — module #{inspect(custom_adapter)} does not implement the Inertia.SSR.Adapter behaviour"

      true ->
        custom_adapter
    end
  end

  defp adapter?(module) do
    function_exported?(module, :init, 1) and
      function_exported?(module, :children, 1) and
      function_exported?(module, :call, 2)
  end
end
