defmodule Inertia.Errors do
  @moduledoc false

  def compile_errors(%Ecto.Changeset{} = changeset, msg_func \\ &default_msg_func/1) do
    changeset
    |> Ecto.Changeset.traverse_errors(msg_func)
    |> process_changeset_errors()
    |> Map.new()
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
end
