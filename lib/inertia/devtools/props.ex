defmodule Inertia.DevTools.Props do
  @moduledoc false

  # Builds the per-prop metadata DevTools renders in its props tree, keyed by
  # dotted prop path. Every top-level prop is listed; nested paths only appear
  # when they carry metadata of their own (e.g. a nested deferred prop).

  alias Inertia.DevTools.Redact
  alias Inertia.DevTools.Source

  @doc """
  Returns `{props, prop_values}` for an entry.

  `render` is the render info captured by `render_inertia/4`, `page` is the
  `conn.private.inertia_page` map, and `props` the page props as the client
  received them (JSON-decoded).
  """
  @spec build(map(), map(), map(), boolean()) :: {map(), map()}
  def build(render, page, props, deferred_request?) do
    deferred_groups = invert_groups(page.deferred_props)
    once_paths = page.once_props |> Map.values() |> Enum.map(& &1["prop"])

    paths =
      (Map.keys(props) ++ Map.keys(render.prop_types) ++ once_paths)
      |> Enum.filter(&has_path?(props, &1))
      |> Enum.concat(page.rescued_props)
      |> Enum.uniq()

    inline_lines = inline_key_lines(render)

    meta =
      Map.new(paths, fn path ->
        tags = Map.get(render.prop_types, path, [])

        {path,
         %{"shared" => path in render.shared_keys, "inertiaType" => type(tags, deferred_request?)}
         |> put_if("deferGroup", deferred_request? && Map.get(deferred_groups, path))
         |> put_if("reset", path in render.reset)
         |> put_if("once", :once in tags or path in once_paths)
         |> put_if("mergeDirection", merge_direction(path, tags, page))
         |> put_if("deepMerge", deep_merge?(path, page))
         |> put_if("rescued", path in page.rescued_props)
         |> put_if("shareSource", render.share_sources[path])
         |> put_if("renderSource", render_source(path, render, inline_lines))}
      end)

    values =
      paths
      |> Enum.filter(&has_path?(props, &1))
      |> Map.new(&{&1, Redact.prop(&1, get_path(props, &1))})

    {meta, values}
  end

  # A deferred prop only reads as deferred when it is delivered by the
  # automatic deferred follow-up. Loaded by a manual partial reload, it is just
  # a regular prop.
  defp type(tags, deferred_request?) do
    cond do
      :keep in tags -> "always"
      :defer in tags -> if deferred_request?, do: "defer"
      :optional in tags -> "optional"
      :merge in tags -> "merge"
      :scroll in tags -> "scroll"
      :once in tags -> "once"
      true -> nil
    end
  end

  # Scroll props record their merge path under the wrapper key (e.g.
  # `posts.data`), so a scroll prop merges in the direction of that child.
  defp merge_direction(path, tags, page) do
    targets = if :scroll in tags, do: &(parent_path(&1) == path), else: &(&1 == path)

    cond do
      Enum.any?(page.prepend_props, targets) -> "prepend"
      Enum.any?(page.merge_props ++ page.deep_merge_props, targets) -> "append"
      true -> nil
    end
  end

  defp deep_merge?(path, page) do
    path in page.deep_merge_props or
      Enum.any?(page.match_props_on, &(parent_path(&1) == path))
  end

  defp parent_path(path) do
    case String.split(path, ".") do
      [_] -> nil
      segments -> segments |> Enum.drop(-1) |> Enum.join(".")
    end
  end

  defp render_source(path, render, inline_lines) do
    cond do
      path in render.shared_keys -> nil
      source = render.render_sources[path] -> source
      line = inline_lines[path] -> %{render.render_source | line: line}
      true -> nil
    end
  end

  # Locates the props passed inline to `render_inertia`, reading the render
  # call's source once for all of them.
  defp inline_key_lines(%{render_source: nil}), do: %{}

  defp inline_key_lines(render) do
    raw_lines = Source.key_lines(render.render_source, Map.values(render.inline_keys))

    for {path, raw} <- render.inline_keys, line = raw_lines[raw], into: %{}, do: {path, line}
  end

  defp invert_groups(groups) do
    for {group, paths} <- groups, path <- paths, into: %{}, do: {path, group}
  end

  defp has_path?(props, path) do
    match?({:ok, _}, fetch_path(props, String.split(path, ".")))
  end

  defp get_path(props, path) do
    {:ok, value} = fetch_path(props, String.split(path, "."))
    value
  end

  defp fetch_path(value, []), do: {:ok, value}

  defp fetch_path(map, [key | rest]) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} -> fetch_path(value, rest)
      :error -> :error
    end
  end

  defp fetch_path(_value, _path), do: :error

  defp put_if(map, _key, value) when value in [nil, false], do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)
end
