defmodule Inertia.SSR.NodeJS do
  @moduledoc """
  SSR adapter using NodeJS. Invokes the `render` function from your `ssr.js` file.

  The `ssr.js` must export a named `render` function that accepts the Inertia `page`
  payload and returns `{ head: [], body: "..." }`.
  """

  @behaviour Inertia.SSRAdapter

  alias Inertia.SSR.Config

  @impl true
  def render(page) when is_map(page) do
    module = GenServer.call(Config, :module)
    esm = GenServer.call(Config, :esm)

    case NodeJS.call({module, :render}, [page], name: supervisor_name(), binary: true, esm: esm) do
      {:ok, %{"head" => _head, "body" => _body} = result} ->
        {:ok, result}

      {:ok, other} ->
        {:error, "SSR returned unexpected format: #{inspect(other)}"}

      {:error, reason} ->
        {:error, Exception.format(:error, reason)}
    end
  end

  defp supervisor_name do
    Module.concat(Inertia.SSR, Supervisor)
  end
end
