defprotocol Inertia.Errors do
  @moduledoc ~S"""
  Converts a value to Inertia.js-compatible [validation
  errors](https://inertiajs.com/validation).

  This protocol allows you to transform various error structures into the format
  expected by Inertia.js for client-side validation. The protocol converts error
  structures into a flat map where keys represent field paths and values are error
  messages.

  ## Built-in Implementations

  This library includes default implementations for:

  * `Ecto.Changeset` - Converts changeset errors to Inertia-compatible format
  * `Map` - Validates and passes through properly formatted error maps

  ## Usage with Ecto.Changeset

  ```elixir
  # In your controller action
  def create(conn, %{"post" => post_params}) do
    case Posts.create(post_params)
      # Handle successful validation
      {:ok, post} ->
        redirect(conn, to: ~p"/posts/#{post}")

      # Convert changeset errors and share them with Inertia
      {:error, changeset} ->
        conn
        |> assign_errors(changeset)
        |> redirect(conn, to: ~p"/posts/new")
    end
  end
  ```

  The `assign_errors/2` function is a convenience helper provided by `Inertia.Controller`
  that internally uses `Inertia.Errors.to_errors/1` to serialize the changeset errors
  and share them with the Inertia page under the `errors` key.

  ## Custom Error Formatting

  You can provide a custom message formatting function as the second argument to
  `to_errors/2`:

  ```elixir
  Inertia.Errors.to_errors(changeset, fn {msg, opts} ->
    # Custom error message formatting logic
    Gettext.dgettext(MyApp.Gettext, "errors", msg, opts)
  end)
  ```

  ## Implementing for Custom Types

  You can implement this protocol for your own error types:

  ```elixir
  defimpl Inertia.Errors, for: MyApp.ValidationError do
    def to_errors(validation_error) do
      # Convert your custom error structure to a map of field paths to error
      # messages
      %{
        "field_name" => validation_error.message,
        "nested.field" => "Another error message"
      }
    end

    def to_errors(validation_error, _msg_func) do
      # Custom implementation with message function
      to_errors(validation_error)
    end
  end
  ```
  """

  @spec to_errors(term()) :: map() | no_return()
  @spec to_errors(term(), msg_func :: function()) :: map() | no_return()
  def to_errors(value)
  def to_errors(value, msg_func)
end

defimpl Inertia.Errors, for: Ecto.Changeset do
  def to_errors(%Ecto.Changeset{} = changeset) do
    to_errors(changeset, &default_msg_func/1)
  end

  def to_errors(%Ecto.Changeset{} = changeset, msg_func) do
    changeset
    |> Ecto.Changeset.traverse_errors(msg_func)
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
