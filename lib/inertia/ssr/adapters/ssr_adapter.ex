defmodule Inertia.SSRAdapter do
  @moduledoc """
  Defines the contract for Server-Side Rendering (SSR) adapters in Inertia.

  The `render/1` function receives the full page map generated from a Phoenix
  controller, as returned by `inertia_assigns(conn)`.
  """

  @typedoc "Full Inertia SSR input payload"
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

  @typedoc "Result of rendering HTML via SSR"
  @type ssr_result :: {:ok, %{head: list(String.t()), body: String.t()}} | {:error, String.t()}

  @callback render(page()) :: ssr_result()
end

