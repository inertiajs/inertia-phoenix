defmodule Inertia.SSR.ViteJS do
  @moduledoc """
  SSR adapter that sends a POST request to the Vite dev server at `/ssr_render`.

  You must register a custom Vite plugin in your `vite.config.js` that exposes
  a `/ssr_render` endpoint accepting the full Inertia page payload.

  Example Vite config:

      import react from '@vitejs/plugin-react'
      import inertiaVitePlugin from '@inertia-phoenix/vitePlugin'

      export default {
        plugins: [react(), inertiaVitePlugin()],
      }

  And in your `config/dev.exs`, set the host:

      config :inertia, :vite_host, "http://localhost:5173"
  """

  @behaviour Inertia.SSRAdapter

  @impl true
  def render(page) when is_map(page) do
    url = vite_path("/ssr_render")
    body = Jason.encode!(page)

    headers = [{~c"Content-Type", ~c"application/json"}]
    request = {String.to_charlist(url), headers, ~c"application/json", body}

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

  defp vite_path(path) do
    case Application.get_env(:inertia, :vite_host) do
      nil ->
        raise """
        ViteJS host is not configured.

        Please add this to your `config/dev.exs`:

            config :inertia, :vite_host, "http://localhost:5173"

        and ensure Vite is running and has a /ssr_render endpoint.
        """

      host ->
        Path.join(host, path)
    end
  end
end
