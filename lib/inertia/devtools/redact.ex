defmodule Inertia.DevTools.Redact do
  @moduledoc false

  # Strips sensitive values from everything an entry records: request and
  # response bodies, prop values, headers, and URL query strings.
  #
  # Keys are compared ignoring case, underscores, and dashes, so `api_key`
  # also matches a camelized `apiKey` prop or an `API-Key` form field.

  @redacted "[REDACTED]"

  @default_keys ~w(
    password password_confirmation current_password token _token _csrf_token
    access_token refresh_token secret client_secret api_key
  )

  @default_headers ~w(
    cookie set-cookie authorization proxy-authorization x-xsrf-token x-csrf-token
  )

  # Headers whose values are URLs, which may carry sensitive query params.
  @url_headers ~w(referer location x-inertia-location x-inertia-redirect)

  @doc """
  Replaces the value of every sensitive key in a (nested) map or list.
  """
  @spec data(term()) :: term()
  def data(value), do: redact(value, keys())

  @doc """
  Redacts the value of a prop recorded under a dotted path, such as
  `auth.token`, which is sensitive when any segment of its path is.
  """
  @spec prop(String.t(), term()) :: term()
  def prop(path, value) do
    keys = keys()

    if path |> String.split(".") |> Enum.any?(&sensitive_key?(&1, keys)),
      do: @redacted,
      else: redact(value, keys)
  end

  @doc """
  Converts a list of header tuples to a map, joining repeated headers and
  redacting sensitive ones.
  """
  @spec headers([{String.t(), String.t()}]) :: %{String.t() => String.t()}
  def headers(headers) do
    sensitive = MapSet.new(header_names())

    headers
    |> Enum.group_by(&String.downcase(elem(&1, 0)), &elem(&1, 1))
    |> Map.new(fn {name, values} ->
      cond do
        MapSet.member?(sensitive, name) -> {name, @redacted}
        name in @url_headers -> {name, Enum.map_join(values, ", ", &url/1)}
        true -> {name, Enum.join(values, ", ")}
      end
    end)
  end

  @doc """
  Redacts sensitive query parameters, leaving the rest of the URL untouched.
  """
  @spec url(String.t() | nil) :: String.t() | nil
  def url(url) when is_binary(url) do
    case String.split(url, "?", parts: 2) do
      [base, query] ->
        keys = keys()
        base <> "?" <> Enum.map_join(String.split(query, "&"), "&", &redact_pair(&1, keys))

      [_] ->
        url
    end
  end

  def url(url), do: url

  # Rewrites only the value of a sensitive `key=value` pair, so every other
  # pair keeps its original encoding.
  defp redact_pair(pair, keys) do
    [key | _] = String.split(pair, "=", parts: 2)

    if sensitive_query_key?(URI.decode_www_form(key), keys),
      do: key <> "=" <> @redacted,
      else: pair
  rescue
    ArgumentError -> pair
  end

  defp redact(map, keys) when is_map(map) and not is_struct(map) do
    Map.new(map, fn {key, value} ->
      if sensitive_key?(key, keys), do: {key, @redacted}, else: {key, redact(value, keys)}
    end)
  end

  defp redact(list, keys) when is_list(list), do: Enum.map(list, &redact(&1, keys))
  defp redact(value, _keys), do: value

  defp sensitive_key?(key, {exact, contained}) when is_binary(key) do
    key = normalize(key)
    MapSet.member?(exact, key) or Enum.any?(contained, &String.contains?(key, &1))
  end

  defp sensitive_key?(key, keys) when is_atom(key), do: sensitive_key?(Atom.to_string(key), keys)
  defp sensitive_key?(_key, _keys), do: false

  # Matches `secret` as well as nested query keys like `filter[secret]`.
  defp sensitive_query_key?(key, keys) do
    innermost = key |> String.split(["[", "]"], trim: true) |> List.last()
    sensitive_key?(key, keys) or sensitive_key?(innermost || key, keys)
  end

  # Phoenix filters any param whose key contains one of its
  # `:filter_parameters` (so `password` also filters `new_password`), so those
  # match the same way. The rest match whole keys.
  defp keys do
    exact = MapSet.new(@default_keys ++ config(:redact_keys), &normalize/1)
    contained = phoenix_filter_parameters() |> Enum.map(&normalize/1) |> Enum.reject(&(&1 == ""))
    {exact, contained}
  end

  defp header_names do
    Enum.map(
      @default_headers ++ config(:redact_headers),
      &(&1 |> to_string() |> String.downcase())
    )
  end

  # The parameters Phoenix filters from its logs (`["password"]` unless
  # configured), except when given in the `{:keep, params}` form, which lists
  # what to keep instead.
  defp phoenix_filter_parameters do
    case Application.get_env(:phoenix, :filter_parameters, ["password"]) do
      params when is_list(params) -> params
      _ -> []
    end
  end

  defp config(key) do
    :inertia |> Application.get_env(:devtools, []) |> Keyword.get(key, [])
  end

  defp normalize(key) do
    key |> to_string() |> String.downcase() |> String.replace(["_", "-"], "")
  end
end
