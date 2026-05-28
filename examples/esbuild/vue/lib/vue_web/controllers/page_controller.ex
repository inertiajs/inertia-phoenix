defmodule VueWeb.PageController do
  use VueWeb, :controller

  def home(conn, _params) do
    conn
    |> assign_prop(:name, "Vue")
    |> render_inertia("Home")
  end

  def about(conn, _params) do
    conn
    |> assign_prop(:framework, "Vue")
    |> render_inertia("About")
  end
end
