defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  def home(conn, _params) do
    conn
    |> render_inertia("Home", %{text: "Hello World"})
  end
end
