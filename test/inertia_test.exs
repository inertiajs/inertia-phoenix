defmodule InertiaTest do
  use MyAppWeb.ConnCase
  use Phoenix.Component

  import Plug.Conn

  @current_version "db137d38dc4b6ee57d5eedcf0182de8a"

  test "renders JSON response with x-inertia header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/")

    assert %{
             "component" => "Home",
             "props" => %{"text" => "Hello World"},
             "url" => "/",
             "version" => @current_version
           } = json_response(conn, 200)

    assert get_resp_header(conn, "x-inertia") == ["true"]
  end

  test "merges shared data", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/shared")

    assert %{
             "component" => "Home",
             "props" => %{"text" => "Hello World", "page_title" => "Home"},
             "url" => "/shared",
             "version" => @current_version
           } = json_response(conn, 200)
  end

  test "renders HTML without x-inertia", %{conn: conn} do
    conn =
      conn
      |> get(~p"/")

    body = html_response(conn, 200) |> String.trim()

    assert body =~ """
           <main><div id=\"app\" data-page=\"{&quot;component&quot;:&quot;Home&quot;,&quot;props&quot;:{&quot;text&quot;:&quot;Hello World&quot;},&quot;url&quot;:&quot;/&quot;,&quot;version&quot;:&quot;#{@current_version}&quot;}\"></div></main>
           """
  end

  test "converts PUT redirects to 303", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put(~p"/")

    assert response(conn, 303)
  end

  test "converts PATCH redirects to 303", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> patch(~p"/")

    assert response(conn, 303)
  end

  test "converts DELETE redirects to 303", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> delete(~p"/")

    assert response(conn, 303)
  end

  test "redirects with conflict if mismatching version", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", "different")
      |> get(~p"/")

    assert html_response(conn, 409)
    assert get_resp_header(conn, "x-inertia") == ["true"]
    assert get_resp_header(conn, "x-inertia-location") == ["http://www.example.com/"]
  end
end
