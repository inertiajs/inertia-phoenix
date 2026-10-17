defmodule Inertia.DevTools.EntriesPlug do
  @moduledoc false

  # Serves recorded entries to the DevTools extension. Mounted by
  # `Inertia.DevTools.Router.inertia_devtools/0`.

  @behaviour Plug

  import Plug.Conn

  alias Inertia.DevTools
  alias Inertia.DevTools.Store
  alias Inertia.DevTools.ULID

  @impl true
  def init(action) when action in [:index, :show], do: action

  @impl true
  def call(conn, action) do
    conn =
      conn
      |> ignore_session()
      |> put_resp_header("cache-control", "no-store")

    if DevTools.active?() do
      respond(conn, action)
    else
      not_found(conn)
    end
  end

  defp respond(conn, :show) do
    with id when is_binary(id) <- conn.path_params["id"],
         true <- ULID.valid?(id),
         {:ok, json} <- Store.fetch(id) do
      send_json(conn, 200, json)
    else
      _ -> not_found(conn)
    end
  end

  # The extension only fetches single entries for now, but the protocol also
  # defines this listing, filterable by component and request type.
  defp respond(conn, :index) do
    conn = fetch_query_params(conn)
    params = conn.query_params

    entries =
      Store.list()
      |> filter_component(params["component"])
      |> filter_types(params["type"], &Kernel.in/2)
      |> filter_types(params["exclude"], &(not Kernel.in(&1, &2)))
      |> Enum.drop(parse_int(params["offset"], 0))
      |> take(parse_int(params["limit"], nil))

    send_json(conn, 200, json_library().encode_to_iodata!(entries))
  end

  # The extension fetches each entry while the app is still following up on
  # the response that recorded it (e.g. the redirect after a failed form
  # submission). If the endpoint runs under a pipeline that fetches the flash,
  # writing the session back would consume the flash meant for that next page.
  defp ignore_session(conn) do
    if Map.has_key?(conn.private, :plug_session),
      do: configure_session(conn, ignore: true),
      else: conn
  end

  defp filter_component(entries, component) when is_binary(component) and component != "",
    do: Enum.filter(entries, &(&1["component"] == component))

  defp filter_component(entries, _component), do: entries

  defp filter_types(entries, types, matcher) when is_binary(types) and types != "" do
    types = types |> String.split(",") |> Enum.map(&String.trim/1)
    Enum.filter(entries, &matcher.(&1["requestType"], types))
  end

  defp filter_types(entries, _types, _matcher), do: entries

  defp take(entries, nil), do: entries
  defp take(entries, limit), do: Enum.take(entries, max(limit, 1))

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> max(int, 0)
      _ -> default
    end
  end

  defp parse_int(_value, default), do: default

  defp not_found(conn) do
    send_json(conn, 404, json_library().encode_to_iodata!(%{message: "Not found."}))
  end

  defp send_json(conn, status, json) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json)
  end

  defp json_library, do: Phoenix.json_library()
end
