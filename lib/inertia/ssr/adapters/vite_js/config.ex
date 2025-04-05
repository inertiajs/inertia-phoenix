defmodule Inertia.SSR.Adapters.ViteJS.Config do
  @moduledoc false

  defstruct [:vite_host]
  @default_vite_host "http://localhost:5173"

  @type t :: %__MODULE__{vite_host: String.t() | nil}

  @spec build(keyword()) :: t()
  def build(opts) do
    %__MODULE__{
      vite_host: Keyword.get(opts, :vite_host, @default_vite_host)
    }
  end
end

