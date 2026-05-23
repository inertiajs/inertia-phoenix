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
    |> assign(:page_title, "Home")
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
    |> assign(:page_title, "Home")
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

  def deep_merge_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:a, inertia_deep_merge(%{a: %{b: %{c: 1}}}))
    |> assign_prop(:b, inertia_deep_merge([:a, :b]))
    |> assign_prop(:c, inertia_merge("c"))
    |> assign_prop(:d, "d")
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
    |> assign_prop(:deferred_items, inertia_defer(fn -> [%{item_name: "Foo"}] end))
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

  def once_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:plans, inertia_once(fn -> ["basic", "pro"] end))
    |> assign_prop(:regular, "value")
    |> render_inertia("Home")
  end

  def once_props_fresh(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:plans, inertia_once(fn -> ["basic", "pro"] end, fresh: true))
    |> render_inertia("Home")
  end

  def once_props_with_expiration(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:rates, inertia_once(fn -> [1.0, 1.5] end, until: 3600))
    |> render_inertia("Home")
  end

  def once_props_with_custom_key(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:member_roles, inertia_once(fn -> ["admin", "user"] end, as: "roles"))
    |> render_inertia("Home")
  end

  def once_props_camelized(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:user_plans, inertia_once(fn -> ["basic", "pro"] end))
    |> camelize_props()
    |> render_inertia("Home")
  end

  def once_props_with_deferred(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:permissions, inertia_once(inertia_defer(fn -> ["read", "write"] end)))
    |> render_inertia("Home")
  end

  def scroll_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(
      :users,
      inertia_scroll(%{
        data: [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}],
        meta: %{current_page: 1, next_page: 2, previous_page: nil, page_name: "page"}
      })
    )
    |> assign_prop(:regular, "value")
    |> render_inertia("Home")
  end

  def scroll_props_with_custom_wrapper(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(
      :users,
      inertia_scroll(
        %{
          items: [%{id: 1, name: "Alice"}],
          meta: %{current_page: 1, next_page: 2, previous_page: nil}
        },
        wrapper: "items"
      )
    )
    |> render_inertia("Home")
  end

  def scroll_props_with_custom_page_name(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(
      :users,
      inertia_scroll(
        %{
          data: [%{id: 1}],
          meta: %{current_page: 1}
        },
        page_name: "users_page"
      )
    )
    |> render_inertia("Home")
  end

  def scroll_props_lazy(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(
      :users,
      inertia_scroll(fn ->
        %{
          data: [%{id: 1}],
          meta: %{current_page: 1, next_page: nil, previous_page: nil, page_name: "page"}
        }
      end)
    )
    |> render_inertia("Home")
  end

  def scroll_props_camelized(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(
      :user_list,
      inertia_scroll(%{
        data: [%{id: 1}],
        meta: %{current_page: 1, next_page: 2, previous_page: nil}
      })
    )
    |> camelize_props()
    |> render_inertia("Home")
  end

  def scroll_props_with_custom_metadata(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(
      :users,
      inertia_scroll(
        %{
          entries: [%{id: 1}]
        },
        wrapper: "entries",
        metadata: fn _data ->
          %{page_name: "p", current_page: 5, next_page: 6, previous_page: 4}
        end
      )
    )
    |> render_inertia("Home")
  end

  def preserved_fragment(conn, _params) do
    conn |> assign(:page_title, "Home") |> preserve_fragment() |> render_inertia("Home")
  end

  def redirect_with_preserved_fragment(conn, _params) do
    conn |> preserve_fragment() |> redirect(to: ~p"/")
  end

  def shared_props_via_assign(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_shared_prop(:current_user, %{id: 1, name: "Alice"})
    |> assign_prop(:other, "value")
    |> render_inertia("Home")
  end

  def shared_props_via_inline(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> render_inertia("Home", %{current_user: inertia_share(%{id: 1}), other: "value"})
  end

  def shared_props_with_merge(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_shared_prop(:items, inertia_merge(["a", "b"]))
    |> assign_prop(:other, "value")
    |> render_inertia("Home")
  end

  def shared_props_with_defer(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_shared_prop(:items, inertia_defer(fn -> ["a", "b"] end))
    |> assign_prop(:other, "value")
    |> render_inertia("Home")
  end

  def shared_props_camelized(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_shared_prop(:current_user, %{id: 1})
    |> assign_prop(:other_thing, "value")
    |> camelize_props()
    |> render_inertia("Home")
  end

  def shared_props_empty(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:other, "value")
    |> render_inertia("Home")
  end

  # Nested prop test actions

  def nested_optional(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:auth, fn ->
      %{
        user: "Alice",
        token: inertia_optional(fn -> "secret-token" end)
      }
    end)
    |> render_inertia("Home")
  end

  def nested_defer(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:auth, fn ->
      %{
        user: "Alice",
        permissions: inertia_defer(fn -> ["read", "write"] end)
      }
    end)
    |> render_inertia("Home")
  end

  def nested_merge(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:feed, fn ->
      %{
        posts: inertia_merge(["post1", "post2"]),
        meta: "info"
      }
    end)
    |> render_inertia("Home")
  end

  def nested_deep_merge(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:feed, fn ->
      %{
        posts: inertia_deep_merge(%{items: [1, 2]}),
        meta: "info"
      }
    end)
    |> render_inertia("Home")
  end

  def nested_always(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:auth, fn ->
      %{
        user: "Alice",
        role: inertia_always("admin")
      }
    end)
    |> assign_prop(:other, "value")
    |> render_inertia("Home")
  end

  def nested_partial_dot_path(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:auth, fn ->
      %{
        user: "Alice",
        permissions: ["read", "write"],
        token: "secret"
      }
    end)
    |> assign_prop(:other, "value")
    |> render_inertia("Home")
  end

  def nested_parent_resolved(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:auth, fn ->
      %{
        user: "Alice",
        token: "secret"
      }
    end)
    |> assign_prop(:other, "value")
    |> render_inertia("Home")
  end

  def nested_two_level_unwrap(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:stats, fn -> inertia_defer(fn -> "data" end) |> inertia_merge() end)
    |> render_inertia("Home")
  end

  def nested_once(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:auth, fn ->
      %{
        user: "Alice",
        plans: inertia_once(fn -> ["basic", "pro"] end)
      }
    end)
    |> assign_prop(:regular, "value")
    |> render_inertia("Home")
  end

  def nested_camelized(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:user_profile, fn ->
      %{
        full_name: "Alice",
        access_level: inertia_defer(fn -> "admin" end)
      }
    end)
    |> camelize_props()
    |> render_inertia("Home")
  end

  def nested_scroll(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:feed, fn ->
      %{
        posts:
          inertia_scroll(%{
            data: [%{id: 1}],
            meta: %{current_page: 1, next_page: 2, previous_page: nil, page_name: "page"}
          }),
        title: "My Feed"
      }
    end)
    |> render_inertia("Home")
  end

  def nested_plain_map_partial(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:auth, %{user: "Alice", token: "secret"})
    |> assign_prop(:other, "value")
    |> render_inertia("Home")
  end

  # clearHistory across redirect
  def redirect_with_clear_history(conn, _params) do
    conn |> clear_history() |> redirect(to: ~p"/")
  end

  # Hash fragment redirect
  def redirect_with_fragment(conn, _params) do
    redirect(conn, to: "/page#section")
  end

  # Empty response
  def empty_response(conn, _params) do
    send_resp(conn, 200, "")
  end

  # Prepend merge
  def prepend_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:a, inertia_prepend("a"))
    |> assign_prop(:b, inertia_merge("b"))
    |> assign_prop(:c, "c")
    |> render_inertia("Home")
  end

  # matchPropsOn
  def match_props_on(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(:users, inertia_merge([%{id: 1}], match_on: "id"))
    |> assign_prop(:items, inertia_prepend([%{id: 2}], match_on: "id"))
    |> assign_prop(:data, inertia_deep_merge(%{a: 1}, match_on: "key"))
    |> render_inertia("Home")
  end

  # Scroll prop with reset
  def scroll_props_with_reset(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(
      :users,
      inertia_scroll(%{
        data: [%{id: 1}],
        meta: %{current_page: 1, next_page: 2, previous_page: nil, page_name: "page"}
      })
    )
    |> render_inertia("Home")
  end

  # SSR path exclusion test
  def ssr_excluded(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> render_inertia("Home", ssr: true)
  end

  # Scroll props with prepend merge intent
  def scroll_props_prepend(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> assign_prop(
      :users,
      inertia_scroll(%{
        data: [%{id: 1}],
        meta: %{current_page: 1, next_page: 2, previous_page: nil, page_name: "page"}
      })
    )
    |> render_inertia("Home")
  end

  defp lazy_3 do
    "lazy_3"
  end
end
