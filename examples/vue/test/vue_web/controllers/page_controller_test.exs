defmodule VueWeb.PageControllerTest do
  use VueWeb.ConnCase

  import Inertia.Testing

  test "GET / renders the Home page", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert inertia_component(conn) == "Home"
    assert %{name: "Vue"} = inertia_props(conn)
  end

  test "GET /about renders the About page", %{conn: conn} do
    conn = get(conn, ~p"/about")

    assert inertia_component(conn) == "About"
    assert %{framework: "Vue"} = inertia_props(conn)
  end
end
