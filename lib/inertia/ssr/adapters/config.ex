defmodule Inertia.SSR.Adapters.Config do
  @moduledoc false

  defmacro __using__(opts) do
    name = Keyword.fetch!(opts, :name)
    config_module = Keyword.fetch!(opts, :config)

    quote do
      @behaviour Inertia.SSR.Adapter
      @name unquote(name)

      def init(opts) do
        config = unquote(config_module).build(opts)
        config
      end
    end
  end
end
