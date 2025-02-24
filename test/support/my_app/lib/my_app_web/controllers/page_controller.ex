defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> render_inertia("Home", %{text: "Hello World"})
  end

  def non_inertia(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> render(:non_inertia)
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
    |> assign_prop(:b, inertia_merge("b"))
    |> assign_prop(:c, "c")
    |> render_inertia("Home")
  end

  def deferred_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:a, inertia_defer(fn -> "a" end))
    |> assign_prop(:b, inertia_defer(fn -> "b" end, "dashboard"))
    |> assign_prop(:c, inertia_defer(fn -> "c" end) |> inertia_merge())
    |> assign_prop(:d, "d")
    |> render_inertia("Home")
  end

  def encrypted_history(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> encrypt_history()
    |> render_inertia("Home")
  end

  def cleared_history(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> clear_history()
    |> render_inertia("Home")
  end

  def camelized_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:first_name, "Bob")
    |> assign_prop(:items, [%{item_name: "Foo"}])
    |> camelize_props()
    |> render_inertia("Home")
  end

  def camelized_deferred_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:first_name, "Bob")
    |> assign_prop(:items, inertia_defer(fn -> [%{item_name: "Foo"}] end))
    |> camelize_props()
    |> render_inertia("Home")
  end

  def preserved_case_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(preserve_case(:first_name), "Bob")
    |> assign_prop(:last_name, "Jones")
    |> assign_prop(:profile, %{preserve_case(:birth_year) => "Foo"})
    |> camelize_props()
    |> render_inertia("Home")
  end

  def force_redirect(conn, _params) do
    conn
    |> force_inertia_redirect()
    |> redirect(to: "/")
  end

  def local_ssr(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> render_inertia("Home", ssr: true)
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
