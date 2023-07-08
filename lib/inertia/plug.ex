defmodule Inertia.Plug do
  @moduledoc """
  The plug module for detecting Inertia.js requests.
  """

  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    conn
    |> put_private(:inertia_version, compute_version())
    |> detect_inertia()
  end

  defp detect_inertia(conn) do
    case get_req_header(conn, "x-inertia") do
      ["true"] ->
        conn
        |> put_private(:inertia_request, true)
        |> convert_redirects()
        |> check_version()

      _ ->
        conn
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
