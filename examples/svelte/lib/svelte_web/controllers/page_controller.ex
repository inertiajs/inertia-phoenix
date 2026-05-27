defmodule SvelteWeb.PageController do
  use SvelteWeb, :controller

  def home(conn, _params) do
    conn
    |> assign_prop(:name, "Svelte")
    |> render_inertia("Home")
  end

  def about(conn, _params) do
    conn
    |> assign_prop(:framework, "Svelte")
    |> render_inertia("About")
  end
end
