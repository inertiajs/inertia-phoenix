defmodule Inertia.Errors do
  @moduledoc false

  import Inertia.Controller, only: [inertia_always: 1]

  @doc """
  Compiles errors for into a format compatible with Inertia.js.
  """
  @spec compile_errors!(Plug.Conn.t(), map() | Ecto.Changeset.t()) :: map() | no_return()
  @spec compile_errors!(Plug.Conn.t(), Ecto.Changeset.t(), msg_func :: function()) ::
          map() | no_return()
  def compile_errors!(conn, %Ecto.Changeset{} = changeset) do
    compile_errors!(conn, changeset, &default_msg_func/1)
  end

  def compile_errors!(conn, map) when is_map(map) do
    map
    |> bag_errors(conn)
    |> inertia_always()
  end

  def compile_errors!(conn, %Ecto.Changeset{} = changeset, msg_func) do
    changeset
    |> Ecto.Changeset.traverse_errors(msg_func)
    |> process_changeset_errors()
    |> Map.new()
    |> bag_errors(conn)
    |> inertia_always()
  end

  def process_changeset_errors(value, path \\ nil)

  def process_changeset_errors(%{} = map, path) do
    map
    |> Map.to_list()
    |> Enum.map(fn {key, value} ->
      path = if path, do: "#{path}.#{key}", else: key
      process_changeset_errors(value, path)
    end)
    |> List.flatten()
  end

  def process_changeset_errors([%{} | _] = maps, path) do
    maps
    |> Enum.with_index()
    |> Enum.map(fn {map, idx} ->
      path = "#{path}.#{idx}"
      process_changeset_errors(map, path)
    end)
    |> List.flatten()
  end

  def process_changeset_errors([message], path) when is_binary(message) do
    {path, message}
  end

  def process_changeset_errors([msg | _] = messages, path) when is_binary(msg) do
    messages
    |> Enum.with_index()
    |> Enum.map(fn {message, idx} ->
      path = "#{path}.#{idx}"
      {path, message}
    end)
  end

  # The default message function to call when traversing Ecto errors
  defp default_msg_func({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  defp bag_errors(errors, conn) do
    if error_bag = conn.private[:inertia_error_bag] do
      %{error_bag => errors}
    else
      errors
    end
  end
end
