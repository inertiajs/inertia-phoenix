defmodule ReactViteWeb.PageController do
  use ReactViteWeb, :controller

  def home(conn, _params) do
    conn
    |> assign_prop(:name, "React")
    |> render_inertia("Home")
  end

  def about(conn, _params) do
    conn
    |> assign_prop(:framework, "React")
    |> render_inertia("About")
  end
end
