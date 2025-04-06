defmodule Inertia.SSR.Adapter do
  @moduledoc false

  @type adapter_config :: struct()
  @type page :: %{
          required(:component) => String.t(),
          required(:props) => map(),
          required(:url) => String.t(),
          optional(:version) => String.t(),
          optional(:encryptHistory) => boolean(),
          optional(:clearHistory) => boolean(),
          optional(:mergeProps) => list(String.t()),
          optional(:deferredProps) => map()
        }
  @type ssr_result :: {:ok, map()} | {:error, String.t()}

  @callback init(opts :: keyword()) :: adapter_config()
  @callback children(adapter_config()) :: [{module(), keyword()}]
  @callback call(page(), adapter_config()) :: ssr_result()
end
