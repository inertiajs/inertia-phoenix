defmodule Inertia.Controller do
  import Phoenix.Controller
  import Plug.Conn

  @doc """
  Assigns shared data to a conn that will be automatically merged with Inertia page props.
  """
  @spec assign_shared(Plug.Conn.t(), atom(), any()) :: Plug.Conn.t()
  def assign_shared(conn, key, value) do
    shared = conn.assigns[:inertia_shared] || %{}
    assign(conn, :inertia_shared, Map.put(shared, key, value))
  end

  @doc """
  Renders an Inertia response.
  """
  @spec render_inertia(Plug.Conn.t(), String.t(), map()) :: Plug.Conn.t()
  def render_inertia(conn, component, props) do
    conn
    |> put_private(:inertia_page, %{component: component, props: props})
    |> assign(:is_inertia, true)
    |> send_response()
  end

  # Private helpers

  defp send_response(%{private: %{inertia_request: true}} = conn) do
    conn
    |> put_status(200)
    |> put_resp_header("x-inertia", "true")
    |> json(inertia_assigns(conn))
  end

  defp send_response(conn) do
    conn
    |> put_view(Inertia.HTML)
    |> render(:inertia_page, inertia_assigns(conn))
  end

  defp inertia_assigns(conn) do
    shared = conn.assigns[:inertia_shared] || %{}

    %{
      component: conn.private.inertia_page.component,
      props: Map.merge(shared, conn.private.inertia_page.props),
      url: request_path(conn),
      version: conn.private.inertia_version
    }
  end

  defp request_path(conn) do
    IO.iodata_to_binary([conn.request_path, request_url_qs(conn.query_string)])
  end

  defp request_url_qs(""), do: ""
  defp request_url_qs(qs), do: [??, qs]
end
