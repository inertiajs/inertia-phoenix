defmodule Inertia.SSR.Adapter do
  require Logger

  @moduledoc """
  Defines the contract for Server-Side Rendering (SSR) adapters in Inertia.


  ## Adapter contract

  Each adapter **must** implement:

    * `render/1` — Renders a page and returns either `{:ok, %{head, body}}` or `{:error, reason}`.

  Adapters **may optionally** implement:

    * `init/1` — Boot-time hook to initialize runtime configuration.
    * `children/1` — Supervision tree for adapter-specific processes.

  """

  @default_adapter Adapters.NodeJS.Adapter

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
  @type ssr_result :: {:ok, %{head: list(String.t()), body: String.t()}} | {:error, String.t()}

  @callback init(opts :: keyword()) :: adapter_config()
  @callback children() :: [{module(), keyword()}]
  @callback call(page()) :: ssr_result()

  def children(), do: adapter().children()

  def init(opts) do
    adapter =
      case Application.get_env(:inertia, :ssr_adapter) do
        "vitejs" ->
          Inertia.SSR.Adapters.ViteJS

        nil ->
          @default_adapter

        other ->
          Logger.warning("""
          Unknown SSR adapter: #{inspect(other)}.
          Falling back to nodejs adapter
          """)

          @default_adapter
      end

    :persistent_term.put({__MODULE__, :impl_adapter}, adapter)
    adapter.init(opts)
  end

  @spec call(page()) :: ssr_result()
  def call(page) do
    adapter().call(page)
  end

  defp adapter do
    :persistent_term.get({__MODULE__, :impl_adapter})
  end
end
