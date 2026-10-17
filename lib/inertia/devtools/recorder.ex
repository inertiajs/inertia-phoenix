defmodule Inertia.DevTools.Recorder do
  @moduledoc false

  # Records each request that passes through `Inertia.Plug` as a DevTools
  # entry. `start/1` runs first in the plug and registers the before-send
  # callback that builds the entry. Registered first, that callback runs last,
  # so it sees the final status and headers after Inertia's own rewrites (such
  # as turning redirects into 303s or 409s).

  import Plug.Conn

  require Logger

  alias Inertia.DevTools
  alias Inertia.DevTools.Props
  alias Inertia.DevTools.Redact
  alias Inertia.DevTools.Source
  alias Inertia.DevTools.Store
  alias Inertia.DevTools.ULID

  # Larger non-Inertia response bodies are not recorded.
  @raw_body_limit 256_000

  @doc """
  Starts recording the request, if DevTools is active.
  """
  @spec start(Plug.Conn.t()) :: Plug.Conn.t()
  def start(conn) do
    if DevTools.active?() do
      conn
      |> put_private(:inertia_devtools, %{
        id: ULID.generate(),
        started_at: System.monotonic_time(),
        sources: %{},
        render: nil,
        page: nil
      })
      |> register_before_send(&record/1)
    else
      conn
    end
  end

  @doc """
  Records where a prop was assigned, for the editor link to its source.
  """
  @spec track_prop(Plug.Conn.t(), term()) :: Plug.Conn.t()
  def track_prop(%{private: %{inertia_devtools: devtools}} = conn, key) do
    case Source.caller() do
      nil ->
        conn

      {module, _fun, location} ->
        put_devtools(conn, %{
          devtools
          | sources: Map.put(devtools.sources, key, {module, location})
        })
    end
  rescue
    exception ->
      warn(conn, exception, __STACKTRACE__)
      conn
  end

  def track_prop(conn, _key), do: conn

  @doc """
  Stores the render info captured by `render_inertia/4`.
  """
  @spec put_render(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def put_render(%{private: %{inertia_devtools: devtools}} = conn, render) do
    put_devtools(conn, %{devtools | render: render})
  end

  def put_render(conn, _render), do: conn

  @doc """
  Stores the page object as it is sent to the client.
  """
  @spec put_page(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def put_page(%{private: %{inertia_devtools: devtools}} = conn, page) do
    put_devtools(conn, %{devtools | page: page})
  end

  def put_page(conn, _page), do: conn

  @doc """
  Returns the assigns for the entry id tag rendered into the initial page
  load, or `nil` when the request is not being recorded.
  """
  @spec tag(Plug.Conn.t()) :: %{id: String.t(), base_path: String.t() | nil} | nil
  def tag(%{private: %{inertia_devtools: %{id: id}}} = conn),
    do: %{id: id, base_path: base_path(conn)}

  def tag(_conn), do: nil

  defp put_devtools(conn, devtools), do: put_private(conn, :inertia_devtools, devtools)

  # Recording is a passive observer: an unencodable value or a bug in here must
  # never break the app's response, so a failure drops the entry instead. The
  # headers are only added once the entry is stored, so the extension is never
  # pointed at an entry that does not exist.
  defp record(%{private: %{inertia_devtools: devtools}} = conn) do
    batch_id = if inertia_request?(conn), do: header(conn, "x-inertia-devtools-parent")

    # A prefetch is speculative, so it starts its own batch rather than
    # continuing the current one.
    parent_out = if prefetch?(conn), do: devtools.id, else: batch_id || devtools.id

    conn =
      conn
      |> put_resp_header("x-inertia-devtools-id", devtools.id)
      |> put_resp_header("x-inertia-devtools-parent-out", parent_out)
      |> put_base_path_header()

    entry = build_entry(conn, devtools, batch_id)
    json = json_library().encode_to_iodata!(entry)

    :ok = Store.put(devtools.id, entry["__meta"]["tabUuid"], entry["__meta"], json)
    conn
  rescue
    exception ->
      warn(conn, exception, __STACKTRACE__)
      conn
  end

  @doc """
  Logs a failure to record a request. Recording never fails the request
  itself, so a failure is reported here and the entry is dropped (or left
  incomplete).
  """
  @spec warn(Plug.Conn.t(), Exception.t(), Exception.stacktrace()) :: :ok
  def warn(conn, exception, stacktrace) do
    Logger.warning(
      "Inertia DevTools failed to record #{conn.method} #{conn.request_path}:\n" <>
        Exception.format(:error, exception, stacktrace)
    )
  end

  defp build_entry(conn, devtools, batch_id) do
    page = devtools.page && normalize(devtools.page)
    render = devtools.render
    deferred? = inertia_request?(conn) and header(conn, "x-inertia-devtools-deferred") != nil

    {props, prop_values} =
      if render && page,
        do: Props.build(render, conn.private.inertia_page, page["props"] || %{}, deferred?),
        else: {%{}, %{}}

    %{
      "__meta" => %{
        "id" => devtools.id,
        "tabUuid" => header(conn, "x-inertia-devtools-tab"),
        "batchId" => batch_id,
        "visitId" => header(conn, "x-inertia-devtools-visit"),
        "timestamp" => timestamp(),
        "utime" => System.os_time(:microsecond) / 1_000_000,
        "method" => conn.method,
        "url" => Redact.url(request_url(conn)),
        "component" => render && render.component,
        "requestType" => request_type(conn, render),
        "status" => conn.status,
        "redirectLocation" => Redact.url(redirect_location(conn)),
        "serverTimingMs" => elapsed_ms(devtools.started_at)
      },
      "http" => %{
        "requestHeaders" => Redact.headers(conn.req_headers),
        "responseHeaders" => Redact.headers(conn.resp_headers),
        "requestBody" => request_body(conn),
        "responseBody" => response_body(conn, page)
      },
      "props" => props,
      "propValues" => prop_values,
      "route" => route(conn, render),
      "renderSource" => render && render.render_source,
      "componentPath" => render && Source.component_path(render.component)
    }
  end

  # The request types, in the order the protocol derives them. Deferred and
  # poll visits look like any other partial reload on the wire, so the client
  # flags them with DevTools headers.
  defp request_type(conn, render) do
    cond do
      not inertia_request?(conn) -> if render, do: "initial", else: "http"
      header(conn, "x-inertia-devtools-deferred") -> "deferred"
      header(conn, "x-inertia-devtools-poll") -> "poll"
      header(conn, "x-inertia-partial-component") -> "partial"
      prefetch?(conn) -> "prefetch"
      true -> "navigate"
    end
  end

  defp redirect_location(conn) do
    location =
      Enum.find_value(["x-inertia-location", "x-inertia-redirect"], &resp_header(conn, &1))

    cond do
      location -> location
      conn.status in 300..399 -> resp_header(conn, "location")
      true -> nil
    end
  end

  defp route(conn, render) do
    controller = conn.private[:phoenix_controller]
    action = conn.private[:phoenix_action]

    uri =
      with router when is_atom(router) and not is_nil(router) <- conn.private[:phoenix_router],
           %{route: route} <-
             Phoenix.Router.route_info(router, conn.method, conn.path_info, conn.host) do
        route
      else
        _ -> ""
      end

    route = %{
      "name" => nil,
      "uri" => uri,
      "action" => if(controller && action, do: "#{inspect(controller)}.#{action}")
    }

    action_source = if render, do: render.action_source, else: Source.action(controller, action)

    case action_source do
      nil -> route
      source -> Map.put(route, "actionSource", source)
    end
  end

  # Form submissions that are not Inertia visits are left out, since they are
  # not part of the Inertia request flow DevTools inspects.
  defp request_body(conn) do
    if conn.method in ~w(POST PUT PATCH DELETE) and not inertia_request?(conn) do
      omitted("non-inertia-request")
    else
      body = fetched(conn.body_params)
      params = if json_request?(conn), do: body, else: Map.merge(fetched(conn.query_params), body)

      if params == %{},
        do: %{"status" => "empty"},
        else: present(params |> summarize_uploads() |> Redact.data())
    end
  end

  defp response_body(_conn, page) when is_map(page) do
    page |> Redact.data() |> Map.update("url", nil, &Redact.url/1) |> present()
  end

  defp response_body(conn, nil) do
    content_type = conn |> resp_header("content-type") |> to_string() |> String.downcase()

    cond do
      not textual?(content_type) ->
        omitted("non-textual")

      conn.state != :set or is_nil(conn.resp_body) ->
        omitted("streamed")

      # Checked before the body is copied into a single binary
      IO.iodata_length(conn.resp_body) > @raw_body_limit ->
        omitted("too-large")

      true ->
        conn.resp_body |> IO.iodata_to_binary() |> raw_body(content_type)
    end
  end

  defp raw_body("", _content_type), do: %{"status" => "empty"}

  defp raw_body(body, content_type) do
    with true <- String.contains?(content_type, "json"),
         {:ok, decoded} when is_map(decoded) or is_list(decoded) <- decode(body) do
      present(Redact.data(decoded))
    else
      _ -> if String.valid?(body), do: present(body), else: omitted("binary")
    end
  end

  defp textual?(content_type) do
    String.contains?(content_type, ["json", "text/", "xml", "javascript"])
  end

  defp summarize_uploads(%Plug.Upload{} = upload) do
    size =
      case File.stat(upload.path) do
        {:ok, %{size: size}} -> size
        _ -> nil
      end

    %{"name" => upload.filename, "size" => size, "mimeType" => upload.content_type}
  end

  defp summarize_uploads(map) when is_map(map) and not is_struct(map),
    do: Map.new(map, fn {key, value} -> {key, summarize_uploads(value)} end)

  defp summarize_uploads(list) when is_list(list), do: Enum.map(list, &summarize_uploads/1)
  defp summarize_uploads(value), do: value

  # Round-trips the page through JSON, so recorded values are exactly what the
  # client received (structs encoded by their JSON implementations, and so on).
  defp normalize(page) do
    page
    |> json_library().encode_to_iodata!()
    |> IO.iodata_to_binary()
    |> json_library().decode!()
  end

  defp decode(body) do
    {:ok, json_library().decode!(body)}
  rescue
    _ -> :error
  end

  defp present(value), do: %{"status" => "present", "value" => value}
  defp omitted(reason), do: %{"status" => "omitted", "reason" => reason}

  defp fetched(%Plug.Conn.Unfetched{}), do: %{}
  defp fetched(params), do: params

  defp put_base_path_header(conn) do
    case base_path(conn) do
      nil -> conn
      path -> put_resp_header(conn, "x-inertia-devtools-base-path", path)
    end
  end

  # The path the app is mounted on, so the extension can find the entry
  # endpoint when the app is not served from the root of its origin.
  defp base_path(%{script_name: []}), do: nil
  defp base_path(%{script_name: segments}), do: "/" <> Enum.join(segments, "/")

  defp inertia_request?(conn), do: conn.private[:inertia_request] == true

  defp prefetch?(conn) do
    Enum.any?(["purpose", "sec-purpose"], fn name ->
      conn |> get_req_header(name) |> Enum.any?(&String.contains?(&1, "prefetch"))
    end)
  end

  defp json_request?(conn) do
    conn |> get_req_header("content-type") |> Enum.any?(&String.contains?(&1, "json"))
  end

  defp header(conn, name) do
    case get_req_header(conn, name) do
      [value | _] when value != "" -> value
      _ -> nil
    end
  end

  defp resp_header(conn, name) do
    case get_resp_header(conn, name) do
      [value | _] when value != "" -> value
      _ -> nil
    end
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.truncate(:millisecond) |> DateTime.to_iso8601()
  end

  defp elapsed_ms(started_at) do
    System.convert_time_unit(System.monotonic_time() - started_at, :native, :microsecond) / 1000
  end

  defp json_library, do: Phoenix.json_library()
end
