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

  test "checking if a response is Inertia-rendered", %{conn: conn} do
    conn = get(conn, "/")
    assert Inertia.Controller.inertia_response?(conn)

    conn = conn |> recycle() |> get("/non_inertia")
    refute Inertia.Controller.inertia_response?(conn)
  end

  test "renders JSON response with x-inertia header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/")

    assert %{
             "component" => "Home",
             "props" => %{"text" => "Hello World", "errors" => %{}, "flash" => %{}},
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
             "props" => %{
               "text" => "Hello World",
               "foo" => "bar",
               "errors" => %{},
               "flash" => %{}
             },
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

  test "renders ssr response for ESM module", %{conn: conn} do
    path =
      __ENV__.file
      |> Path.dirname()
      |> Path.join("js/esm")

    start_supervised({Inertia.SSR, path: path, esm: true})

    Application.put_env(:inertia, :ssr, true)

    conn =
      conn
      |> get(~p"/")

    body = html_response(conn, 200)

    assert body =~ ~r/<title inertia>(\s*)New title from ESM(\s*)<\/title>/
    assert body =~ ~s(<meta name="description" content="Head stuff" />)
    assert body =~ ~s(<div id="ssr"></div>)
  end

  test "renders ssr response when locally specified", %{conn: conn} do
    path =
      __ENV__.file
      |> Path.dirname()
      |> Path.join("js")

    start_supervised({Inertia.SSR, path: path})

    Application.put_env(:inertia, :ssr, false)

    conn =
      conn
      |> get(~p"/local_ssr")

    body = html_response(conn, 200)

    assert body =~ ~r/<title inertia>(\s*)New title(\s*)<\/title>/
    assert body =~ ~s(<meta name="description" content="Head stuff" />)
    assert body =~ ~s(<div id="ssr"></div>)
  end

  test "supports binary", %{conn: conn} do
    path =
      __ENV__.file
      |> Path.dirname()
      |> Path.join("js")

    start_supervised({Inertia.SSR, path: path})

    Application.put_env(:inertia, :ssr, true)

    conn =
      conn
      |> get(~p"/binary_props")

    body = html_response(conn, 200)

    assert body =~ ~r/<title inertia>(\s*)New title(\s*)<\/title>/
    assert body =~ ~s(<meta name="description" content="Head stuff" />)
    assert body =~ ~s(<div id="ssr">’</div>)
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

  test "evaluates optional props", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      # Allows us to make sure the "unwrapping" in `resolve_merge_props` doesn't affect optional props.
      |> put_req_header("x-inertia-reset", "a")
      |> get(~p"/lazy")

    assert %{
             "component" => "Home",
             "props" => %{
               "lazy_1" => "lazy_1",
               "lazy_3" => "lazy_3",
               "nested" => %{"lazy_2" => "lazy_2"},
               "errors" => %{},
               "flash" => %{}
             },
             "url" => "/lazy",
             "version" => @current_version
           } = json_response(conn, 200)
  end

  test "partial 'only' reloads", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-partial-component", "Home")
      |> put_req_header("x-inertia-partial-data", "b")
      |> get(~p"/always")

    assert json_response(conn, 200) == %{
             "component" => "Home",
             "props" => %{"errors" => %{}, "flash" => %{}, "b" => "b", "important" => "stuff"},
             "url" => "/always",
             "version" => @current_version,
             "encryptHistory" => false,
             "clearHistory" => false
           }
  end

  test "partial 'except' reloads", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-partial-component", "Home")
      |> put_req_header("x-inertia-partial-except", "b")
      |> get(~p"/always")

    assert json_response(conn, 200) == %{
             "component" => "Home",
             "props" => %{"a" => "a", "errors" => %{}, "flash" => %{}, "important" => "stuff"},
             "url" => "/always",
             "version" => @current_version,
             "encryptHistory" => false,
             "clearHistory" => false
           }
  end

  test "includes 'always' props in partial reloads", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-partial-component", "Home")
      |> put_req_header("x-inertia-partial-data", "a")
      |> get(~p"/always")

    assert json_response(conn, 200) == %{
             "component" => "Home",
             "props" => %{"a" => "a", "important" => "stuff", "errors" => %{}, "flash" => %{}},
             "url" => "/always",
             "version" => @current_version,
             "encryptHistory" => false,
             "clearHistory" => false
           }
  end

  test "ignores partial reload when component doesn't match", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-partial-component", "NonMatchingComponent")
      |> put_req_header("x-inertia-partial-data", "a")
      |> get(~p"/always")

    assert json_response(conn, 200) == %{
             "component" => "Home",
             "props" => %{
               "a" => "a",
               "errors" => %{},
               "flash" => %{},
               "b" => "b",
               "important" => "stuff"
             },
             "url" => "/always",
             "version" => @current_version,
             "encryptHistory" => false,
             "clearHistory" => false
           }
  end

  test "ignores tagged lazy props on initial page loads", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/tagged_lazy")

    assert json_response(conn, 200) == %{
             "component" => "Home",
             "props" => %{"b" => "b", "errors" => %{}, "flash" => %{}},
             "url" => "/tagged_lazy",
             "version" => @current_version,
             "encryptHistory" => false,
             "clearHistory" => false
           }
  end

  test "includes lazy props when explicitly requested", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-partial-component", "Home")
      |> put_req_header("x-inertia-partial-data", "a")
      |> get(~p"/tagged_lazy")

    assert json_response(conn, 200) == %{
             "component" => "Home",
             "props" => %{"a" => "a", "errors" => %{}, "flash" => %{}},
             "url" => "/tagged_lazy",
             "version" => @current_version,
             "encryptHistory" => false,
             "clearHistory" => false
           }
  end

  test "includes changeset-driven errors", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/changeset_errors")

    assert json_response(conn, 200) == %{
             "component" => "Home",
             "props" => %{
               "errors" => %{"settings.theme" => "can't be blank", "name" => "can't be blank"},
               "flash" => %{}
             },
             "url" => "/changeset_errors",
             "version" => @current_version,
             "encryptHistory" => false,
             "clearHistory" => false
           }
  end

  test "wraps errors in bag", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-error-bag", "groceries")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/changeset_errors")

    assert json_response(conn, 200) == %{
             "component" => "Home",
             "props" => %{
               "errors" => %{
                 "groceries" => %{
                   "settings.theme" => "can't be blank",
                   "name" => "can't be blank"
                 }
               },
               "flash" => %{}
             },
             "url" => "/changeset_errors",
             "version" => @current_version,
             "encryptHistory" => false,
             "clearHistory" => false
           }
  end

  test "carries errors over when full-page redirecting", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-error-bag", "groceries")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/redirect_on_error")

    assert redirected_to(conn) == ~p"/"

    # The next request should have the errors carried over
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ ~s("errors":{"groceries") |> html_escape()

    # Subsequent requests should now have the errors
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ ~s("errors":{}) |> html_escape()
  end

  test "validates error maps", %{conn: conn} do
    assert_raise ArgumentError, ~s(expected string value for name, got ["is required"]), fn ->
      get(conn, ~p"/bad_error_map")
    end
  end

  test "converts external redirects from GET to 409", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/external_redirect")

    assert html_response(conn, 409)
    refute get_resp_header(conn, "x-inertia") == ["true"]
    assert get_resp_header(conn, "x-inertia-location") == ["http://www.example.com/"]
  end

  test "converts external redirects from PUT to 409", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put(~p"/external_redirect")

    assert html_response(conn, 409)
    refute get_resp_header(conn, "x-inertia") == ["true"]
    assert get_resp_header(conn, "x-inertia-location") == ["http://www.example.com/"]
  end

  test "converts external redirects from PATCH to 409", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> patch(~p"/external_redirect")

    assert html_response(conn, 409)
    refute get_resp_header(conn, "x-inertia") == ["true"]
    assert get_resp_header(conn, "x-inertia-location") == ["http://www.example.com/"]
  end

  test "converts external redirects from DELETE to 409", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> delete(~p"/external_redirect")

    assert html_response(conn, 409)
    refute get_resp_header(conn, "x-inertia") == ["true"]
    assert get_resp_header(conn, "x-inertia-location") == ["http://www.example.com/"]
  end

  test "automatically includes flash in props", %{conn: conn} do
    conn =
      conn
      |> patch(~p"/")

    assert html_response(conn, 302)

    conn =
      conn
      |> recycle()
      |> get("/")

    assert html_response(conn, 200) =~ ~s("flash":{"info":"Patched") |> html_escape()
  end

  test "does not clobber the flash prop if manually set", %{conn: conn} do
    conn =
      conn
      |> get(~p"/overridden_flash")

    assert html_response(conn, 200) =~ ~s("flash":{"foo":"bar") |> html_escape()
  end

  test "forwards flash across forced refreshes", %{conn: conn} do
    conn =
      conn
      |> patch(~p"/")

    assert html_response(conn, 302)

    # The next redirect hop triggers a forced refresh...
    conn =
      conn
      |> recycle()
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", "different")
      |> get("/")

    assert html_response(conn, 409)
    assert get_resp_header(conn, "x-inertia-location") == ["http://www.example.com/"]

    # After the hop, flash should be present in the props
    conn =
      conn
      |> recycle()
      |> get("/")

    assert html_response(conn, 200) =~ ~s("flash":{"info":"Patched") |> html_escape()
  end

  test "includes XSRF-TOKEN cookie", %{conn: conn} do
    conn =
      conn
      |> get(~p"/")

    assert html_response(conn, 200)
    assert %{"XSRF-TOKEN" => %{value: "" <> _, http_only: false}} = conn.resp_cookies
  end

  test "preserves nested empty prop objects", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/nested")

    assert %{"props" => %{"a" => %{"b" => %{"e" => %{"h" => %{}}}}}} = json_response(conn, 200)
  end

  test "handles prop values that are serializable structs", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/struct_props")

    assert %{"props" => %{"now" => "2024-07-04T00:00:00Z"}} = json_response(conn, 200)
  end

  test "gathers merge prop keys", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/merge_props")

    assert %{
             "component" => "Home",
             "props" => %{"errors" => %{}, "flash" => %{}, "a" => "a", "b" => "b", "c" => "c"},
             "url" => "/merge_props",
             "mergeProps" => merge_props,
             "version" => @current_version
           } = json_response(conn, 200)

    # We need to assert prop keys separately because `Map` won't guarantee the expected order
    assert ["a", "b"] = Enum.sort(merge_props)
  end

  test "excludes reset props from merge props", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-reset", "a")
      |> get(~p"/merge_props")

    assert %{
             "component" => "Home",
             "props" => %{"errors" => %{}, "flash" => %{}, "a" => "a", "b" => "b", "c" => "c"},
             "url" => "/merge_props",
             # Excludes "a", since it was passed in the x-inertia-reset header
             "mergeProps" => ["b"],
             "version" => @current_version
           } = json_response(conn, 200)
  end

  test "gathers deep merge prop keys", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/deep_merge_props")

    assert %{
             "component" => "Home",
             "props" => %{
               "errors" => %{},
               "flash" => %{},
               "a" => %{"a" => %{"b" => %{"c" => 1}}},
               "b" => ["a", "b"],
               "c" => "c",
               "d" => "d"
             },
             "url" => "/deep_merge_props",
             "mergeProps" => ["c"],
             "deepMergeProps" => deep_merge_props,
             "version" => @current_version
           } = json_response(conn, 200)

    # We need to assert prop keys separately because `Map` won't guarantee the expected order
    assert ["a", "b"] = Enum.sort(deep_merge_props)
  end

  test "excludes reset props from deep merge props", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-reset", "a")
      |> get(~p"/deep_merge_props")

    assert %{
             "component" => "Home",
             "props" => %{
               "errors" => %{},
               "flash" => %{},
               "a" => %{"a" => %{"b" => %{"c" => 1}}},
               "b" => ["a", "b"],
               "c" => "c",
               "d" => "d"
             },
             "url" => "/deep_merge_props",
             # Excludes "a", since it was passed in the x-inertia-reset header
             "deepMergeProps" => ["b"],
             "mergeProps" => ["c"],
             "version" => @current_version
           } = json_response(conn, 200)
  end

  test "processes deferred props on initial page load", %{conn: conn} do
    conn =
      conn
      |> get(~p"/deferred_props")

    body = html_response(conn, 200)
    props = extract_page_data_from_html(body)

    assert props["deferredProps"]["default"]
           |> MapSet.new()
           |> MapSet.equal?(MapSet.new(["a", "c"]))

    conn =
      conn
      |> recycle()
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      # Allows us to make sure the "unwrapping" in `resolve_merge_props` doesn't affect deferred props.
      |> put_req_header("x-inertia-reset", "a")
      |> get(~p"/deferred_props")

    body = json_response(conn, 200)

    assert %{
             "component" => "Home",
             "props" => %{"errors" => %{}, "flash" => %{}, "d" => "d"},
             "url" => "/deferred_props",
             "mergeProps" => ["c"],
             "version" => @current_version
           } = body

    assert body["deferredProps"]["default"]
           |> MapSet.new()
           |> MapSet.equal?(MapSet.new(["a", "c"]))
  end

  test "loads deferred props on partial request", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-partial-component", "Home")
      |> put_req_header("x-inertia-partial-data", "a,b,c")
      |> get(~p"/deferred_props")

    body = json_response(conn, 200)

    assert %{
             "component" => "Home",
             "props" => %{"errors" => %{}, "flash" => %{}, "a" => "a", "b" => "b", "c" => "c"},
             "url" => "/deferred_props",
             "mergeProps" => ["c"],
             "version" => @current_version
           } = body

    # The deferred props list should not be returned on partial requests
    refute "deferredProps" in Map.keys(body)
  end

  test "instructs the client-side to encrypt history", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/encrypted_history")

    assert %{
             "component" => "Home",
             "props" => %{"errors" => %{}, "flash" => %{}},
             "url" => "/encrypted_history",
             "version" => @current_version,
             "encryptHistory" => true,
             "clearHistory" => false
           } = json_response(conn, 200)
  end

  test "instructs the client-side to clear history", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/cleared_history")

    assert %{
             "component" => "Home",
             "props" => %{"errors" => %{}, "flash" => %{}},
             "url" => "/cleared_history",
             "version" => @current_version,
             "encryptHistory" => false,
             "clearHistory" => true
           } = json_response(conn, 200)
  end

  test "camelizes props", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/camelized_props")

    assert %{
             "component" => "Home",
             "props" => %{
               "errors" => %{},
               "flash" => %{},
               "firstName" => "Bob",
               "items" => [%{"itemName" => "Foo"}]
             },
             "url" => "/camelized_props",
             "version" => @current_version
           } = json_response(conn, 200)
  end

  test "camelizes deferred props", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-partial-data", "deferredItems")
      |> put_req_header("x-inertia-partial-component", "Home")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/camelized_deferred_props")

    assert %{
             "component" => "Home",
             "props" => %{
               "errors" => %{},
               "flash" => %{},
               "deferredItems" => [%{"itemName" => "Foo"}]
             },
             "url" => "/camelized_deferred_props",
             "version" => @current_version
           } = json_response(conn, 200)
  end

  test "camelizes keys in deferredProps metadata on initial page load", %{conn: conn} do
    conn =
      conn
      |> get(~p"/camelized_deferred_props")

    body = html_response(conn, 200)
    props = extract_page_data_from_html(body)

    assert props["deferredProps"]["default"] == ["deferredItems"]
  end

  test "preserves tagged props from camelization", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/preserved_case_props")

    assert %{
             "component" => "Home",
             "props" => %{
               "errors" => %{},
               "flash" => %{},
               "first_name" => "Bob",
               "lastName" => "Jones",
               "profile" => %{"birth_year" => "Foo"}
             },
             "url" => "/preserved_case_props",
             "version" => @current_version
           } = json_response(conn, 200)
  end

  test "converts force redirects to 409", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/force_redirect")

    assert html_response(conn, 409)
    refute get_resp_header(conn, "x-inertia") == ["true"]
    assert get_resp_header(conn, "x-inertia-location") == ["/"]
  end

  # Once Props Tests

  test "includes once props on initial page load", %{conn: conn} do
    conn =
      conn
      |> get(~p"/once_props")

    body = html_response(conn, 200)
    props = extract_page_data_from_html(body)

    assert props["props"]["plans"] == ["basic", "pro"]
    assert props["props"]["regular"] == "value"

    assert props["onceProps"] == %{
             "plans" => %{"prop" => "plans", "expiresAt" => nil}
           }
  end

  test "includes once props on Inertia request without except header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/once_props")

    body = json_response(conn, 200)

    assert body["props"]["plans"] == ["basic", "pro"]
    assert body["props"]["regular"] == "value"

    assert body["onceProps"] == %{
             "plans" => %{"prop" => "plans", "expiresAt" => nil}
           }
  end

  test "excludes once props when key is in X-Inertia-Except-Once-Props header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-except-once-props", "plans")
      |> get(~p"/once_props")

    body = json_response(conn, 200)

    # plans should be excluded from props but metadata should still be present
    refute Map.has_key?(body["props"], "plans")
    assert body["props"]["regular"] == "value"

    assert body["onceProps"] == %{
             "plans" => %{"prop" => "plans", "expiresAt" => nil}
           }
  end

  test "includes once props when fresh: true is set", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-except-once-props", "plans")
      |> get(~p"/once_props_fresh")

    body = json_response(conn, 200)

    # plans should be included despite being in except header because fresh: true
    assert body["props"]["plans"] == ["basic", "pro"]

    assert body["onceProps"] == %{
             "plans" => %{"prop" => "plans", "expiresAt" => nil}
           }
  end

  test "includes once props when explicitly requested in partial reload", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-partial-component", "Home")
      |> put_req_header("x-inertia-partial-data", "plans")
      |> put_req_header("x-inertia-except-once-props", "plans")
      |> get(~p"/once_props")

    body = json_response(conn, 200)

    # plans should be included because it's explicitly requested
    assert body["props"]["plans"] == ["basic", "pro"]
  end

  test "includes expiration timestamp in onceProps", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/once_props_with_expiration")

    body = json_response(conn, 200)

    assert body["props"]["rates"] == [1.0, 1.5]

    # expiresAt should be a timestamp in milliseconds (approximately 1 hour from now)
    expires_at = body["onceProps"]["rates"]["expiresAt"]
    assert is_integer(expires_at)

    now_ms = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    one_hour_ms = 3600 * 1000

    # Allow 10 seconds of tolerance
    assert expires_at > now_ms + one_hour_ms - 10_000
    assert expires_at < now_ms + one_hour_ms + 10_000
  end

  test "uses custom key from as: option", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/once_props_with_custom_key")

    body = json_response(conn, 200)

    assert body["props"]["member_roles"] == ["admin", "user"]

    # The key in onceProps should be "roles" (the custom key)
    # but the prop name should still be "member_roles"
    assert body["onceProps"] == %{
             "roles" => %{"prop" => "member_roles", "expiresAt" => nil}
           }
  end

  test "excludes once prop when custom key is in except header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-except-once-props", "roles")
      |> get(~p"/once_props_with_custom_key")

    body = json_response(conn, 200)

    # member_roles should be excluded because "roles" (the custom key) is in except header
    refute Map.has_key?(body["props"], "member_roles")

    assert body["onceProps"] == %{
             "roles" => %{"prop" => "member_roles", "expiresAt" => nil}
           }
  end

  test "camelizes keys in onceProps metadata", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/once_props_camelized")

    body = json_response(conn, 200)

    assert body["props"]["userPlans"] == ["basic", "pro"]

    assert body["onceProps"] == %{
             "userPlans" => %{"prop" => "userPlans", "expiresAt" => nil}
           }
  end

  test "handles once prop combined with deferred", %{conn: conn} do
    conn =
      conn
      |> get(~p"/once_props_with_deferred")

    body = html_response(conn, 200)
    props = extract_page_data_from_html(body)

    # Deferred props are not included on initial load
    refute Map.has_key?(props["props"], "permissions")

    # But onceProps metadata should be present
    assert props["onceProps"] == %{
             "permissions" => %{"prop" => "permissions", "expiresAt" => nil}
           }

    # And deferredProps should list it
    assert props["deferredProps"]["default"] == ["permissions"]
  end

  test "resolves deferred once prop when requested in partial reload", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-partial-component", "Home")
      |> put_req_header("x-inertia-partial-data", "permissions")
      |> get(~p"/once_props_with_deferred")

    body = json_response(conn, 200)

    assert body["props"]["permissions"] == ["read", "write"]
  end

  # Scroll props tests

  describe "scroll props" do
    test "includes scroll props in initial page load", %{conn: conn} do
      conn = get(conn, ~p"/scroll_props")
      html = html_response(conn, 200)
      props = extract_page_data_from_html(html)

      # Props should include the paginated data
      assert props["props"]["users"] == %{
               "data" => [%{"id" => 1, "name" => "Alice"}, %{"id" => 2, "name" => "Bob"}],
               "meta" => %{
                 "current_page" => 1,
                 "next_page" => 2,
                 "previous_page" => nil,
                 "page_name" => "page"
               }
             }

      # Regular props should also be included
      assert props["props"]["regular"] == "value"

      # mergeProps should include the data path
      assert "users.data" in props["mergeProps"]

      # scrollProps should include pagination metadata
      assert props["scrollProps"] == %{
               "users" => %{
                 "pageName" => "page",
                 "currentPage" => 1,
                 "previousPage" => nil,
                 "nextPage" => 2
               }
             }
    end

    test "includes scroll props in XHR request", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> get(~p"/scroll_props")

      body = json_response(conn, 200)

      assert body["props"]["users"]["data"] == [
               %{"id" => 1, "name" => "Alice"},
               %{"id" => 2, "name" => "Bob"}
             ]

      assert "users.data" in body["mergeProps"]
      assert body["scrollProps"]["users"]["currentPage"] == 1
    end

    test "supports custom wrapper key", %{conn: conn} do
      conn = get(conn, ~p"/scroll_props_with_custom_wrapper")
      html = html_response(conn, 200)
      props = extract_page_data_from_html(html)

      # mergeProps should use the custom wrapper key
      assert "users.items" in props["mergeProps"]
    end

    test "supports custom page_name option", %{conn: conn} do
      conn = get(conn, ~p"/scroll_props_with_custom_page_name")
      html = html_response(conn, 200)
      props = extract_page_data_from_html(html)

      assert props["scrollProps"]["users"]["pageName"] == "users_page"
    end

    test "supports lazy evaluation with functions", %{conn: conn} do
      conn = get(conn, ~p"/scroll_props_lazy")
      html = html_response(conn, 200)
      props = extract_page_data_from_html(html)

      assert props["props"]["users"]["data"] == [%{"id" => 1}]
      assert "users.data" in props["mergeProps"]
      assert props["scrollProps"]["users"]["currentPage"] == 1
    end

    test "camelizes scroll prop keys when camelize_props is enabled", %{conn: conn} do
      conn = get(conn, ~p"/scroll_props_camelized")
      html = html_response(conn, 200)
      props = extract_page_data_from_html(html)

      # Prop key should be camelized
      assert Map.has_key?(props["props"], "userList")
      refute Map.has_key?(props["props"], "user_list")

      # mergeProps should use camelized key
      assert "userList.data" in props["mergeProps"]

      # scrollProps should use camelized key
      assert Map.has_key?(props["scrollProps"], "userList")
    end

    test "supports custom metadata function", %{conn: conn} do
      conn = get(conn, ~p"/scroll_props_with_custom_metadata")
      html = html_response(conn, 200)
      props = extract_page_data_from_html(html)

      assert props["scrollProps"]["users"] == %{
               "pageName" => "p",
               "currentPage" => 5,
               "previousPage" => 4,
               "nextPage" => 6
             }

      # Custom wrapper should be used
      assert "users.entries" in props["mergeProps"]
    end
  end

  defp html_escape(content) do
    content
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp extract_page_data_from_html(raw_html) do
    {:ok, html} = Floki.parse_document(raw_html)

    [json_data] =
      html
      |> Floki.find("div[data-page]")
      |> Floki.attribute("data-page")

    Jason.decode!(json_data)
  end
end
