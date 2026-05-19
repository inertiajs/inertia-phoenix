defmodule Inertia.SSR.Adapter do
  @moduledoc """
  Behaviour for Inertia SSR adapters.

  An adapter is responsible for taking an Inertia page payload and producing
  the rendered `head` and `body` strings. The default adapter
  (`Inertia.SSR.Adapters.NodeJS`) calls into a Node.js process pool, but
  alternative runtimes (e.g. Bun, a Vite dev server) can be plugged in by
  implementing this behaviour and passing the module as the `:ssr_adapter`
  option to `Inertia.SSR`.

  ## Callbacks

  - `c:init/1` — build adapter configuration from the supervisor's options.
    Called once at startup. The returned term is passed back to `c:children/1`
    and `c:call/2` on every render.
  - `c:children/1` — return any child specs the adapter needs added to the
    `Inertia.SSR` supervision tree (e.g. a Node.js worker pool).
  - `c:call/2` — render a page payload. Called from the request process, so
    avoid serializing work through a singleton process.
  """

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
