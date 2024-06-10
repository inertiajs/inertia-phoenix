defmodule Inertia.Plug do
  @moduledoc """
  The plug module for detecting Inertia.js requests.
  """

  import Inertia.Controller, only: [inertia_always: 1]
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    conn
    |> put_private(:inertia_version, compute_version())
    |> put_private(:inertia_shared, %{errors: inertia_always(%{})})
    |> assign(:inertia_head, [])
    |> detect_inertia()
  end

  defp detect_inertia(conn) do
    case get_req_header(conn, "x-inertia") do
      ["true"] ->
        conn
        |> put_private(:inertia_version, compute_version())
        |> put_private(:inertia_request, true)
        |> detect_partial_reload()
        |> convert_redirects()
        |> check_version()

      _ ->
        conn
    end
  end

  defp detect_partial_reload(conn) do
    case get_req_header(conn, "x-inertia-partial-component") do
      [component] when is_binary(component) ->
        conn
        |> put_private(:inertia_partial_component, component)
        |> put_private(:inertia_partial_only, get_partial_only(conn))
        |> put_private(:inertia_partial_except, get_partial_except(conn))

      _ ->
        conn
    end
  end

  defp get_partial_only(conn) do
    case get_req_header(conn, "x-inertia-partial-data") do
      [stringified_list] when is_binary(stringified_list) ->
        String.split(stringified_list, ",")

      _ ->
        []
    end
  end

  defp get_partial_except(conn) do
    case get_req_header(conn, "x-inertia-partial-except") do
      [stringified_list] when is_binary(stringified_list) ->
        String.split(stringified_list, ",")

      _ ->
        []
    end
  end

  defp convert_redirects(conn) do
    register_before_send(conn, fn %{method: method, status: status} = conn ->
      if method in ["PUT", "PATCH", "DELETE"] and status in [301, 302] do
        put_status(conn, 303)
      else
        conn
      end
    end)
  end

  defp check_version(%{private: %{inertia_version: current_version}} = conn) do
    if conn.method == "GET" && get_req_header(conn, "x-inertia-version") != [current_version] do
      force_refresh(conn)
    else
      conn
    end
  end

  defp compute_version do
    if is_atom(endpoint()) and length(static_paths()) > 0 do
      hash_static_paths(endpoint(), static_paths())
    else
      default_version()
    end
  end

  defp hash_static_paths(endpoint, paths) do
    paths
    |> Enum.map_join(&endpoint.static_path(&1))
    |> then(&Base.encode16(:crypto.hash(:md5, &1), case: :lower))
  end

  defp force_refresh(conn) do
    conn
    |> put_resp_header("x-inertia-location", request_url(conn))
    |> put_resp_content_type("text/html")
    |> send_resp(:conflict, "")
    |> halt()
  end

  defp static_paths do
    Application.get_env(:inertia, :static_paths, [])
  end

  defp endpoint do
    Application.get_env(:inertia, :endpoint, nil)
  end

  defp default_version do
    Application.get_env(:inertia, :default_version, "1")
  end
end
