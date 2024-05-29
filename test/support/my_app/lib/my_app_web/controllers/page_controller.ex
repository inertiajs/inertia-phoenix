defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> render_inertia("Home", %{text: "Hello World"})
  end

  def shared(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:foo, "bar")
    |> assign_prop(:text, "I should be overriden")
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
