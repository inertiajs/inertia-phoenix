defmodule Inertia.DevTools.Source do
  @moduledoc false

  # Resolves the file and line locations that power DevTools' "open in editor"
  # links. Every lookup here is best-effort: a location that cannot be resolved
  # is reported as `nil`, never as an error.

  @type location :: %{file: String.t(), line: pos_integer()}

  # How far below a function definition (or render call) to scan for the
  # render call (or an inline prop's key).
  @max_scan_lines 100

  @doc """
  Returns the nearest caller outside of Inertia (and Phoenix and Plug) as
  `{module, function, location}`.

  Calls in tail position leave no stack frame behind, so the caller found here
  may be further up the stack than the code that made the call (e.g. the
  router pipeline running a plug, rather than the plug itself).
  """
  @spec caller() :: {module(), atom(), location()} | nil
  def caller do
    {:current_stacktrace, frames} = Process.info(self(), :current_stacktrace)

    root = File.cwd!()

    Enum.find_value(frames, fn {module, fun, _arity, location} ->
      with true <- app_module?(module),
           file when not is_nil(file) <- location[:file],
           line when is_integer(line) and line > 1 <- location[:line],
           source when is_binary(source) <- own_source(module, List.to_string(file)),
           true <- project_source?(source, root) do
        {module, fun, %{file: source, line: line}}
      else
        _ -> nil
      end
    end)
  end

  @doc """
  Returns the location where a controller action is defined.
  """
  @spec action(module() | nil, atom() | nil) :: location() | nil
  def action(module, action) when is_atom(module) and is_atom(action) and not is_nil(action) do
    with file when is_binary(file) <- module_source(module),
         line when is_integer(line) <- doc_line(module, action) || def_line(file, action) do
      %{file: file, line: line}
    else
      _ -> nil
    end
  end

  def action(_module, _action), do: nil

  @doc """
  Returns the location of the `render_inertia` call within a controller
  action, scanning down from the action's definition (as returned by
  `action/2`).
  """
  @spec render_call(location() | nil) :: location() | nil
  def render_call(%{} = action_location) do
    case scan(action_location, ~r/\brender_inertia\b/) do
      nil -> nil
      line -> %{action_location | line: line}
    end
  end

  def render_call(nil), do: nil

  @doc """
  Finds the lines of prop keys written in a map literal, scanning down from
  the given line (the call that passed the map). Returns a map of each key
  found to its line.
  """
  @spec key_lines(location(), [String.t()]) :: %{String.t() => pos_integer()}
  def key_lines(_location, []), do: %{}

  def key_lines(location, keys) do
    lines = window(location)

    for key <- keys,
        pattern = ~r/(?:\b#{Regex.escape(key)}:|[:"]#{Regex.escape(key)}"?\s*=>)/,
        line = Enum.find_value(lines, fn {text, line} -> if text =~ pattern, do: line end),
        into: %{},
        do: {key, line}
  end

  @doc """
  Resolves the frontend file of a page component from the configured
  `:component_path` template(s), returning the first that exists.
  """
  @spec component_path(String.t()) :: String.t() | nil
  def component_path(component) do
    :inertia
    |> Application.get_env(:devtools, [])
    |> Keyword.get(:component_path, [])
    |> List.wrap()
    |> Enum.map(&Path.expand(String.replace(&1, "{component}", component)))
    |> Enum.find(&File.regular?/1)
  end

  defp scan(location, pattern) do
    location
    |> window()
    |> Enum.find_value(fn {text, line} -> if text =~ pattern, do: line end)
  end

  # The lines of a file from the given line onwards, paired with their line
  # numbers. An unreadable file has no lines.
  defp window(%{file: file, line: start}) do
    file
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.drop(start - 1)
    |> Enum.take(@max_scan_lines)
  rescue
    _ -> []
  end

  defp doc_line(module, action) do
    with {:docs_v1, _, _, _, _, _, docs} <- Code.fetch_docs(module),
         {_, anno, _, _, _} <- List.keyfind(docs, {:function, action, 2}, 0),
         line when is_integer(line) and line > 0 <- :erl_anno.line(anno) do
      line
    else
      _ -> nil
    end
  end

  defp def_line(file, action) do
    scan(%{file: file, line: 1}, ~r/^\s*def\s+#{Regex.escape(Atom.to_string(action))}\b/)
  end

  defp app_module?(module) do
    case Atom.to_string(module) do
      "Elixir.Inertia." <> _ -> false
      "Elixir.Phoenix." <> _ -> false
      "Elixir.Plug." <> _ -> false
      "Elixir.Process" -> false
      "Elixir." <> _ -> true
      _ -> false
    end
  end

  # Only the app's own code is a useful place to link to, never a dependency
  # (such as the web server running the request).
  defp project_source?(source, root) do
    String.starts_with?(source, root <> "/") and not String.contains?(source, "/deps/")
  end

  # Stacktrace paths are relative to the directory the module was compiled
  # from, so the absolute path the module records for its source is used.
  #
  # Code a macro injects into a module (such as the action dispatch `use
  # Phoenix.Controller` adds, or a router's pipelines) says nothing about where
  # the app made a call. Such frames either carry the macro's own file, which
  # this skips, or the module's file at line 1, which `caller/0` skips. The
  # whole path is compared, since the macro's file may share the module's file
  # name (Phoenix's own `lib/phoenix/router.ex` against an app's router.ex).
  defp own_source(module, file) do
    case module_source(module) do
      source when is_binary(source) ->
        if source == file or String.ends_with?(source, "/" <> file), do: source

      nil ->
        nil
    end
  end

  defp module_source(module) do
    case module.module_info(:compile)[:source] do
      source when is_list(source) -> List.to_string(source)
      _ -> nil
    end
  rescue
    _ -> nil
  end
end
