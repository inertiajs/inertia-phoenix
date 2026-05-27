defmodule ReactWeb.PageControllerTest do
  use ReactWeb.ConnCase

  import Inertia.Testing

  test "GET / renders the Home page", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert inertia_component(conn) == "Home"
    assert %{name: "React"} = inertia_props(conn)
  end

  test "GET /about renders the About page", %{conn: conn} do
    conn = get(conn, ~p"/about")

    assert inertia_component(conn) == "About"
    assert %{framework: "React"} = inertia_props(conn)
  end
end
