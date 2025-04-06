defmodule Inertia.SSR.Adapters.ViteJS do
  @moduledoc false

  alias Inertia.SSR.Adapters.ViteJS.Config
  use Inertia.SSR.Adapters.Config, name: :vitejs, config: Config

  @impl true
  def children(_config), do: []

  @impl true
  def call(page, %Config{vite_host: vite_host}) when is_map(page) do
    vite_path = "#{vite_host}/ssr_render"
    body = Jason.encode!(page)

    headers = [{~c"Content-Type", ~c"application/json"}]
    request = {vite_path, headers, ~c"application/json", body}

    case :httpc.request(:post, request, [], []) do
      {:ok, {{_, 200, _}, _headers, response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"head" => _head, "body" => _body} = result} ->
            {:ok, result}

          _ ->
            {:error, "Invalid JSON response from Vite SSR"}
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
