defmodule Inertia.SSR.Adapters.Bootstrap do
  @moduledoc false

  alias Inertia.SSR.Adapter

  @spec fetch_adapter(
          opts: keyword(),
          default_adapter: module()
        ) :: {module(), Adapter.adapter_config()}
  def fetch_adapter(opts: opts, default_adapter: default_adapter) do
    custom_adapter = Keyword.get(opts, :ssr_adapter, nil)
    adapter = resolve_adapter(default_adapter, custom_adapter)
    config = adapter.init(opts)
    {adapter, config}
  end

  @spec resolve_adapter(module(), module() | nil) :: module()
  defp resolve_adapter(default_adapter, custom_adapter) do
    if is_atom(custom_adapter) and
         Code.ensure_loaded?(custom_adapter) and
         function_exported?(custom_adapter, :init, 1) do
      custom_adapter
    else
      default_adapter
    end
  end
end
