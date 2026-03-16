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

  @doc """
  Fetches the Inertia flash data (if applicable) for the current request.

  Returns the flash map from the top-level page object, or falls back
  to the conn flash assigns.

  ## Example

      use MyAppWeb.ConnCase

      import Inertia.Testing

      describe "PUT /" do
        test "flashes a success message", %{conn: conn} do
          conn = put("/")
          assert %{"info" => "Updated"} = inertia_flash(conn)
        end
      end
  """
  @doc since: "3.0.0"
  @spec inertia_flash(Plug.Conn.t()) :: map()
  def inertia_flash(conn) do
    case conn.private[:inertia_page] do
      %{flash: flash} -> flash
      _ -> conn.assigns[:flash] || %{}
    end
  end

  @doc """
  Fetches the shared prop keys (if applicable) for the current request.

  Returns the list of string keys that were marked as shared props.

  ## Example

      use MyAppWeb.ConnCase

      import Inertia.Testing

      describe "GET /" do
        test "includes shared props", %{conn: conn} do
          conn = get("/")
          assert "currentUser" in inertia_shared_props(conn)
        end
      end
  """
  @doc since: "3.0.0"
  @spec inertia_shared_props(Plug.Conn.t()) :: list(String.t())
  def inertia_shared_props(conn) do
    page = conn.private[:inertia_page] || %{}
    page[:shared_props] || []
  end

  @doc """
  Fetches the full Inertia page object map for the current request.

  Returns the complete page data including component, props, url, version,
  and any metadata like mergeProps, deferredProps, etc.
  """
  @doc since: "3.0.0"
  @spec inertia_page(Plug.Conn.t()) :: map() | nil
  def inertia_page(conn) do
    conn.private[:inertia_page]
  end

  @doc """
  Fetches the deferred prop groups for the current request.

  Returns a map of group name to list of deferred prop paths.
  """
  @doc since: "3.0.0"
  @spec inertia_deferred_props(Plug.Conn.t()) :: map()
  def inertia_deferred_props(conn) do
    page = conn.private[:inertia_page] || %{}
    page[:deferred_props] || %{}
  end

  @doc """
  Fetches the merge prop keys for the current request.

  Returns the list of prop paths that are configured for client-side merging.
  """
  @doc since: "3.0.0"
  @spec inertia_merge_props(Plug.Conn.t()) :: list(String.t())
  def inertia_merge_props(conn) do
    page = conn.private[:inertia_page] || %{}
    page[:merge_props] || []
  end

  @doc """
  Fetches the scroll prop metadata for the current request.

  Returns a map of prop paths to their scroll pagination metadata.
  """
  @doc since: "3.0.0"
  @spec inertia_scroll_props(Plug.Conn.t()) :: map()
  def inertia_scroll_props(conn) do
    page = conn.private[:inertia_page] || %{}
    page[:scroll_props] || %{}
  end

  @doc """
  Fetches the once prop metadata for the current request.

  Returns a map of once-prop keys to their metadata (prop path and expiration).
  """
  @doc since: "3.0.0"
  @spec inertia_once_props(Plug.Conn.t()) :: map()
  def inertia_once_props(conn) do
    page = conn.private[:inertia_page] || %{}
    page[:once_props] || %{}
  end
end
