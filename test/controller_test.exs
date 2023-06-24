defmodule Inertia.ControllerTest do
  use MyAppWeb.ConnCase
  use Phoenix.Component

  import Plug.Conn

  test "renders JSON response with x-inertia header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> get(~p"/")

    assert %{
             "component" => "Home",
             "props" => %{"text" => "Hello World"},
             "url" => "/",
             "version" => 1
           } = json_response(conn, 200)
  end

  test "renders HTML without x-inertia", %{conn: conn} do
    conn =
      conn
      |> get(~p"/")

    body = html_response(conn, 200) |> String.trim()

    assert body =~ """
           <main><div id=\"app\" data-page=\"{&quot;component&quot;:&quot;Home&quot;,&quot;props&quot;:{&quot;text&quot;:&quot;Hello World&quot;}}\"></div></main>
           """
  end
end
