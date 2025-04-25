defmodule Inertia.TestingTest do
  use MyAppWeb.ConnCase

  import Inertia.Testing

  setup do
    # Disable SSR by default, selectively enable it when testing
    Application.put_env(:inertia, :ssr, false)
    :ok
  end

  describe "inertia_component/1" do
    test "returns the component from the page", %{conn: conn} do
      conn = get(conn, "/")
      assert inertia_component(conn) == "Home"
    end
  end

  describe "inertia_props/1" do
    test "returns the props from the page", %{conn: conn} do
      conn = get(conn, "/")
      assert %{errors: %{}, flash: %{}, text: "Hello World"} = inertia_props(conn)
    end

    test "returns nil if there are no page props", %{conn: conn} do
      conn = get(conn, "/non_inertia")
      assert inertia_props(conn) == nil
    end
  end

  describe "inertia_errors/1" do
    test "returns an empty map when there are no errors", %{conn: conn} do
      conn = get(conn, "/")
      assert inertia_errors(conn) == %{}
    end

    test "returns the errors assigned to the current page", %{conn: conn} do
      conn = get(conn, "/changeset_errors")

      assert %{:name => "can't be blank", "settings.theme" => "can't be blank"} =
               inertia_errors(conn)
    end

    test "returns the errors preserved in the session", %{conn: conn} do
      conn = get(conn, "/redirect_on_error")

      assert %{:name => "can't be blank", "settings.theme" => "can't be blank"} =
               inertia_errors(conn)
    end

    test "returns empty map if the request is not an inertia request", %{conn: conn} do
      conn = get(conn, "/non_inertia")
      assert inertia_errors(conn) == %{}
    end
  end
end
