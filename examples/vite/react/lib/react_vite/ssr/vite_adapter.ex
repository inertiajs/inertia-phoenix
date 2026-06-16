defmodule ReactVite.SSR.ViteAdapter do
  @moduledoc """
  A development SSR adapter that renders Inertia pages through a running Vite
  dev server instead of a pre-built bundle.

  The default `Inertia.SSR.NodeJSAdapter` loads a self-contained `ssr.cjs`
  built by `vite build --ssr` and re-`require`s it per render. This adapter
  skips that second build entirely: it POSTs the page payload to an endpoint
  mounted on the Vite dev server (see `assets/vite-plugin-inertia-ssr.mjs`),
  which renders through Vite's HMR-aware `ssrLoadModule`. Edits to the SSR
  entry or any page are reflected on the next request — no rebuild, no restart.

  This is a development-only path: in production there is no dev server, so the
  app falls back to the Node.js bundle adapter (see `ReactVite.Application`).

  Implements the `Inertia.SSR.Adapter` behaviour. Uses Erlang's built-in
  `:httpc` client to avoid adding an HTTP dependency to the example.

  ## Options

  - `:vite_url` - base URL of the Vite dev server. Defaults to
    `"http://127.0.0.1:5173"`. (Use a literal IP rather than `localhost`: the
    `:httpc` client may resolve `localhost` to IPv6 `::1` while the Vite dev
    server listens on IPv4 only, causing `:econnrefused`.)
  - `:ssr_path` - path the SSR endpoint is mounted at. Defaults to
    `"/__inertia_ssr"`.
  - `:timeout` - render request timeout in milliseconds. Defaults to `10_000`.
  """

  @behaviour Inertia.SSR.Adapter

  @impl true
  def init(opts) do
    base = Keyword.get(opts, :vite_url, "http://127.0.0.1:5173")
    path = Keyword.get(opts, :ssr_path, "/__inertia_ssr")

    %{
      url: String.to_charlist(base <> path),
      timeout: Keyword.get(opts, :timeout, 10_000)
    }
  end

  # The Vite dev server runs as a Phoenix watcher, so there is nothing to
  # supervise here.
  @impl true
  def children(_config), do: []

  @impl true
  def call(page, %{url: url, timeout: timeout}) when is_map(page) do
    request = {url, [], ~c"application/json", Jason.encode!(page)}

    case :httpc.request(:post, request, [timeout: timeout], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        decode_render(body)

      {:ok, {{_, status, _}, _headers, body}} ->
        {:error, error_message(status, body)}

      {:error, reason} ->
        {:error, "could not reach Vite SSR dev server at #{url}: #{inspect(reason)}"}
    end
  end

  defp decode_render(body) do
    case Jason.decode(body) do
      {:ok, %{"head" => head, "body" => body}} -> {:ok, %{"head" => head, "body" => body}}
      {:ok, other} -> {:error, "unexpected Vite SSR response: #{inspect(other)}"}
      {:error, error} -> {:error, "invalid JSON from Vite SSR: #{inspect(error)}"}
    end
  end

  defp error_message(status, body) do
    case Jason.decode(body) do
      {:ok, %{"error" => error}} -> error
      _ -> "Vite SSR returned HTTP #{status}"
    end
  end
end
