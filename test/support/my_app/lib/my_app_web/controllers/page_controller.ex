defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> render_inertia("Home", %{text: "Hello World"})
  end

  def shared(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:foo, "bar")
    |> assign_prop(:text, "I should be overriden")
    |> render_inertia("Home", %{text: "Hello World"})
  end

  def lazy(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:lazy_1, fn -> "lazy_1" end)
    |> assign_prop(:nested, %{lazy_2: fn -> "lazy_2" end})
    |> render_inertia("Home", %{lazy_3: &lazy_3/0})
  end

  def nested(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:a, %{b: %{c: "c", d: "d", e: %{f: "f", g: "g", h: %{}}}})
    |> render_inertia("Home")
  end

  def always(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:a, "a")
    |> assign_prop(:b, "b")
    |> assign_prop(:important, inertia_always("stuff"))
    |> render_inertia("Home")
  end

  def tagged_lazy(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:a, inertia_optional(fn -> "a" end))
    |> assign_prop(:b, "b")
    |> render_inertia("Home")
  end

  def changeset_errors(conn, _params) do
    changeset = MyApp.User.changeset(%MyApp.User{}, %{settings: %{}})

    conn
    |> assign_errors(changeset)
    |> render_inertia("Home")
  end

  def redirect_on_error(conn, _params) do
    changeset = MyApp.User.changeset(%MyApp.User{}, %{settings: %{}})

    conn
    |> assign_errors(changeset)
    |> redirect(to: ~p"/")
  end

  def bad_error_map(conn, _params) do
    conn
    |> assign_errors(%{user: %{name: ["is required"]}})
    |> render_inertia("Home")
  end

  def external_redirect(conn, _params) do
    redirect(conn, external: "http://www.example.com/")
  end

  def overridden_flash(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:flash, %{foo: "bar"})
    |> render_inertia("Home")
  end

  def struct_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:now, ~U[2024-07-04 00:00:00Z])
    |> render_inertia("Home")
  end

  def binary_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:content, "’")
    |> render_inertia("Home")
  end

  def merge_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:a, inertia_merge("a"))
    |> assign_prop(:b, "b")
    |> render_inertia("Home")
  end

  def update(conn, _params) do
    conn
    |> put_flash(:info, "Updated")
    |> redirect(to: "/")
  end

  def patch(conn, _params) do
    conn
    |> put_flash(:info, "Patched")
    |> redirect(to: "/")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Deleted")
    |> redirect(to: "/")
  end

  defp lazy_3 do
    "lazy_3"
  end
end
