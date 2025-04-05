defmodule Inertia.SSR.Adapters.ViteJS do
  alias Inertia.SSR.Adapters.ViteJS.Config

  @moduledoc """
  SSR adapter that sends a POST request to the Vite dev server at `/ssr_render`.
  Not recomended for production use, but useful for development.

  Example Vite config:
      import react from '@vitejs/plugin-react'
      import inertiaVitePlugin from '@inertia-phoenix/vitePlugin'

      export default {
        plugins: [react(), inertiaVitePlugin({ entrypoint: './js/ssr.tsx' })],
      }

  Optionaly you can change vite_host in your `config/dev.exs`, set the host:

      config :inertia, :vite_host, "http://localhost:5167"

  By default it points to the Vite dev server to localhost:5173.
  """

  use Inertia.SSR.Adapters.Macro, Inertia.SSR.Adapters.ViteJS.Config

  @impl true
  def children(), do: []

  @impl true
  def call(page) when is_map(page) do
    %Config{vite_host: vite_host} = config()
    vite_path = "#{vite_host}/ssr_render"
    body = Jason.encode!(page)

    headers = [{~c"Content-Type", ~c"application/json"}]
    request = {vite_path, headers, ~c"application/json", body}

    case :httpc.request(:post, request, [], []) do
      {:ok, {{_, 200, _}, _headers, response_body}} ->
        with {:ok, %{"head" => _head, "body" => _body} = result} <- Jason.decode(response_body) do
          {:ok, result}
        else
          _ -> {:error, "Invalid JSON response from Vite SSR"}
        end

      {:ok, {{_, 500, _}, _headers, response_body}} ->
        decode_vite_error(response_body)

      {:ok, {{_, status, reason_phrase}, _headers, _body}} ->
        {:error, "Unexpected Vite SSR response: #{status} #{reason_phrase}"}

      {:error, {:failed_connect, [{:to_address, {host, port}}, {_, _, reason}]}} ->
        {:error, "Unable to connect to Vite dev server at #{host}:#{port}: #{reason}"}

      {:error, other} ->
        {:error, "HTTP error contacting Vite: #{inspect(other)}"}
    end
  end

  defp decode_vite_error(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => %{"message" => msg, "loc" => loc, "frame" => frame}}} ->
        {:error, "#{msg}\n#{loc["file"]}:#{loc["line"]}:#{loc["column"]}\n#{frame}"}

      {:ok, %{"error" => %{"stack" => stack}}} ->
        {:error, stack}

      _ ->
        {:error, "Unexpected 500 error from Vite SSR: #{body}"}
    end
  end
end
