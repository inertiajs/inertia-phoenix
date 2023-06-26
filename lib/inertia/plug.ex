defmodule Inertia.Plug do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    conn
    |> detect_inertia()
    |> convert_redirects()
  end

  defp detect_inertia(conn) do
    case get_req_header(conn, "x-inertia") do
      ["true"] -> put_private(conn, :inertia_request, true)
      _ -> conn
    end
  end

  defp convert_redirects(%{private: %{inertia_request: true}} = conn) do
    register_before_send(conn, fn %{method: method, status: status} = conn ->
      if method in ["PUT", "PATCH", "DELETE"] and status in [301, 302] do
        put_status(conn, 303)
      else
        conn
      end
    end)
  end

  defp convert_redirects(conn), do: conn
end
