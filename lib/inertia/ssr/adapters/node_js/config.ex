defmodule Inertia.SSR.Adapters.NodeJS.Config do
  @moduledoc false

  @enforce_keys [:path]
  defstruct [:path, :module, :esm, :pool_size]

  @default_module "ssr"
  @default_esm false
  @default_pool_size 4

  @type t :: %__MODULE__{
          path: String.t(),
          module: String.t(),
          esm: boolean(),
          pool_size: pos_integer()
        }

  @spec build(keyword()) :: t()
  def build(opts) do
    %__MODULE__{
      path: Keyword.fetch!(opts, :path),
      module: Keyword.get(opts, :module, @default_module),
      esm: Keyword.get(opts, :esm, @default_esm),
      pool_size: Keyword.get(opts, :pool_size, @default_pool_size)
    }
  end
end
