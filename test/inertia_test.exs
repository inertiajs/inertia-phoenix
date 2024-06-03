defmodule InertiaTest do
  use MyAppWeb.ConnCase
  use Phoenix.Component

  import Plug.Conn

  @current_version "db137d38dc4b6ee57d5eedcf0182de8a"

  setup do
    # Disable SSR by default, selectively enable it when testing
    Application.put_env(:inertia, :ssr, false)
    :ok
  end

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
             "props" => %{"text" => "Hello World", "foo" => "bar"},
             "url" => "/shared",
             "version" => @current_version
           } = json_response(conn, 200)
  end

  test "renders HTML without x-inertia", %{conn: conn} do
    conn =
      conn
      |> get(~p"/")

    body = html_response(conn, 200)

    assert body =~ ~s("component":"Home") |> html_escape()
    assert body =~ ~s("version":"db137d38dc4b6ee57d5eedcf0182de8a") |> html_escape()
  end

  test "tags the <title> tag with inertia", %{conn: conn} do
    conn =
      conn
      |> get(~p"/")

    body = html_response(conn, 200)

    assert body =~ "<title inertia>"
  end

  test "renders ssr response", %{conn: conn} do
    path =
      __ENV__.file
      |> Path.dirname()
      |> Path.join("js")

    start_supervised({Inertia.SSR, path: path})

    Application.put_env(:inertia, :ssr, true)

    conn =
      conn
      |> get(~p"/")

    body = html_response(conn, 200)

    assert body =~ ~r/<title inertia>(\s*)New title(\s*)<\/title>/
    assert body =~ ~s(<meta name="description" content="Head stuff" />)
    assert body =~ ~s(<div id="ssr"></div>)
  end

  @tag :capture_log
  test "falls back to CSR if SSR fails and failure mode set to csr", %{conn: conn} do
    path =
      __ENV__.file
      |> Path.dirname()
      |> Path.join("js")

    start_supervised({Inertia.SSR, path: path, module: "ssr-failure"})

    Application.put_env(:inertia, :ssr, true)
    Application.put_env(:inertia, :raise_on_ssr_failure, false)

    conn =
      conn
      |> get(~p"/")

    body = html_response(conn, 200)
    assert body =~ ~s("component":"Home") |> html_escape()
  end

  test "raises on SSR failure when failure mode is set to raise", %{conn: conn} do
    path =
      __ENV__.file
      |> Path.dirname()
      |> Path.join("js")

    start_supervised({Inertia.SSR, path: path, module: "ssr-failure"})

    Application.put_env(:inertia, :ssr, true)
    Application.put_env(:inertia, :raise_on_ssr_failure, true)

    assert_raise(Inertia.SSR.RenderError, fn ->
      conn
      |> get(~p"/")
    end)
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
    refute get_resp_header(conn, "x-inertia") == ["true"]
    assert get_resp_header(conn, "x-inertia-location") == ["http://www.example.com/"]
  end

  defp html_escape(content) do
    content
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
