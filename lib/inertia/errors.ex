defprotocol Inertia.Errors do
  @moduledoc """
  Converts a value to Inertia.js-compatible [validation
  errors](https://inertiajs.com/validation).

  This library includes a default implementation for `Ecto.Changeset` structs
  and bare maps.
  """

  @spec to_errors(term()) :: map()
  @spec to_errors(term(), msg_func :: function()) :: map()
  def to_errors(value, msg_func \\ nil)
end

defimpl Inertia.Errors, for: Ecto.Changeset do
  def to_errors(%Ecto.Changeset{} = changeset) do
    to_errors(changeset, &default_msg_func/1)
  end

  def to_errors(%Ecto.Changeset{} = changeset, msg_func) do
    changeset
    |> Ecto.Changeset.traverse_errors(msg_func || (&default_msg_func/1))
    |> process_changeset_errors()
    |> Map.new()
  end

  defp process_changeset_errors(value, path \\ nil)

  defp process_changeset_errors(%{} = map, path) do
    map
    |> Map.to_list()
    |> Enum.map(fn {key, value} ->
      path = if path, do: "#{path}.#{key}", else: key
      process_changeset_errors(value, path)
    end)
    |> List.flatten()
  end

  defp process_changeset_errors([%{} | _] = maps, path) do
    maps
    |> Enum.with_index()
    |> Enum.map(fn {map, idx} ->
      path = "#{path}[#{idx}]"
      process_changeset_errors(map, path)
    end)
    |> List.flatten()
  end

  defp process_changeset_errors([message], path) when is_binary(message) do
    {path, message}
  end

  defp process_changeset_errors([first_message | _], path) when is_binary(first_message) do
    {path, first_message}
  end

  # The default message function to call when traversing Ecto errors
  defp default_msg_func({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end

defimpl Inertia.Errors, for: Map do
  def to_errors(value) do
    validate_error_map!(value)
  end

  def to_errors(value, _msg_func) do
    validate_error_map!(value)
  end

  defp validate_error_map!(map) do
    values = Map.values(map)

    # Check to see if these are "bagged" errors
    # e.g. `%{"updateCompany" => %{"name" => "is invalid"}}`.
    # If we are dealing with bagged errors, then validate the bags.
    # Otherwise, validate the map as an unbagged collection of errors.
    if Enum.all?(values, &is_map/1) do
      Enum.each(values, &validate_error_map!/1)
    else
      Enum.each(map, fn {key, value} ->
        if !is_atom(key) && !is_binary(key) do
          raise ArgumentError, message: "expected atom or string key, got #{inspect(key)}"
        end

        if !is_binary(value) do
          raise ArgumentError,
            message: "expected string value for #{to_string(key)}, got #{inspect(value)}"
        end
      end)
    end

    map
  end
end
