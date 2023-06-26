defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    conn
    |> render_inertia("Home", %{text: "Hello World"})
  end

  def update(conn, _params) do
    conn
    |> redirect(to: "/")
  end

  def patch(conn, _params) do
    conn
    |> redirect(to: "/")
  end

  def delete(conn, _params) do
    conn
    |> redirect(to: "/")
  end
end
