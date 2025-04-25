defmodule Inertia.Testing do
  @moduledoc """
  Helpers for testing Inertia responses.
  """

  @doc """
  Fetches the Inertia component (if applicable) for the current request.

  ## Example

      use MyAppWeb.ConnCase

      import Inertia.Testing

      describe "GET /" do
        test "renders the home page", %{conn: conn} do
          conn = get("/")
          assert inertia_component(conn) == "Home"
        end
      end
  """
  @spec inertia_component(Plug.Conn.t()) :: String.t() | nil
  def inertia_component(conn) do
    page = conn.private[:inertia_page] || %{}
    page[:component]
  end

  @doc """
  Fetches the Inertia props (if applicable) for the current request.

  ## Example

      use MyAppWeb.ConnCase

      import Inertia.Testing

      describe "GET /" do
        test "renders the home page", %{conn: conn} do
          conn = get("/")
          assert %{user: %{id: 1}} = inertia_props(conn)
        end
      end
  """
  @spec inertia_props(Plug.Conn.t()) :: map() | nil
  def inertia_props(conn) do
    page = conn.private[:inertia_page] || %{}
    page[:props]
  end

  @doc """
  Fetches the Inertia errors (if applicable) for the current request.

  If there are errors available in the current page props, they will be returned.
  Otherwise, errors that have been stored in the session will be retrieved.

  ## Example

      use MyAppWeb.ConnCase

      import Inertia.Testing

      describe "POST /users" do
        test "fails when name empty", %{conn: conn} do
          conn = post("/users", %{"name" => ""})

          assert %{user: %{id: 1}} = inertia_props(conn)
          assert redirected_to(conn) == ~p"/users"
          assert inertia_errors(conn) == %{"name" => "can't be blank"}
        end
      end
  """
  @doc since: "2.4.0"
  @spec inertia_errors(Plug.Conn.t()) :: map()
  def inertia_errors(conn) do
    page = conn.private[:inertia_page] || %{}

    case page[:props] do
      %{errors: errors} -> errors
      _ -> Plug.Conn.get_session(conn, "inertia_errors", %{})
    end
  end
end
