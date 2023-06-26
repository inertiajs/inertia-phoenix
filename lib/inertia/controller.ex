defmodule Inertia.Controller do
  import Phoenix.Controller
  import Plug.Conn

  def render_inertia(conn, component, props) do
    conn
    |> put_private(:inertia, %{component: component, props: props})
    |> send_response()
  end

  # Private helpers

  defp send_response(%{private: %{inertia_request: true}} = conn) do
    conn
    |> put_status(200)
    |> put_resp_header("x-inertia", "true")
    |> json(inertia_payload(conn))
  end

  defp send_response(conn) do
    conn
    |> put_view(html: Inertia.HTML)
    |> render(:page, inertia_payload(conn))
  end

  defp inertia_payload(conn) do
    %{
      component: conn.private.inertia.component,
      props: conn.private.inertia.props,
      url: request_path(conn),
      version: 1
    }
  end

  defp request_path(conn) do
    IO.iodata_to_binary([conn.request_path, request_url_qs(conn.query_string)])
  end

  defp request_url_qs(""), do: ""
  defp request_url_qs(qs), do: [??, qs]
end
