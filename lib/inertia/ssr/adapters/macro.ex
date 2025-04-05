defmodule Inertia.SSR.Adapters.Macro do
  @moduledoc false

  defmacro __using__(config_module_ast) do
    quote do
      @behaviour Inertia.SSR.Adapter

      def init(opts) do
        config =  unquote(config_module_ast).build(opts)
        :persistent_term.put({__MODULE__, :config}, config)
        config
      end

      def config do
        :persistent_term.get({__MODULE__, :config})
      end
    end
  end
end
