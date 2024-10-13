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
end
