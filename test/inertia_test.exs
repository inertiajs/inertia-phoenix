defmodule InertiaTest do
  use MyAppWeb.ConnCase
  use Phoenix.Component

  import Plug.Conn

  @current_version "db137d38dc4b6ee57d5eedcf0182de8a"

  setup do
    # Disable SSR by default, selectively enable it when testing
    Application.put_env(:inertia, :ssr, false)
    # Reset history config that may be leaked by install tests
    Application.delete_env(:inertia, :history)
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
             "props" => %{"text" => "Hello World", "errors" => %{}},
             "flash" => %{},
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
               "errors" => %{}
             },
             "flash" => %{},
             "url" => "/shared",
             "version" => @current_version
           } = json_response(conn, 200)
  end

  test "renders HTML without x-inertia", %{conn: conn} do
    conn =
      conn
      |> get(~p"/")

    body = html_response(conn, 200)

    assert body =~ ~s("component":"Home")
    assert body =~ ~s("version":"db137d38dc4b6ee57d5eedcf0182de8a")
  end

  test "tags the <title> tag with inertia", %{conn: conn} do
    conn =
      conn
      |> get(~p"/")

    body = html_response(conn, 200)

    assert body =~ "<title data-inertia>"
  end

  test "sets the nonce on the page script tag when configured", %{conn: conn} do
    Application.put_env(:inertia, :csp_nonce_assign_key, :csp_nonce)
    on_exit(fn -> Application.delete_env(:inertia, :csp_nonce_assign_key) end)

    conn =
      conn
      |> Plug.Conn.assign(:csp_nonce, "abc123")
      |> get(~p"/")

    body = html_response(conn, 200)

    assert body =~ ~s(<script data-page="app" type="application/json" nonce="abc123">)
  end

  test "omits the nonce when no assign key is configured", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.assign(:csp_nonce, "abc123")
      |> get(~p"/")

    body = html_response(conn, 200)

    refute body =~ "nonce="
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

    assert body =~ ~r/<title data-inertia>(\s*)New title(\s*)<\/title>/
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

    assert body =~ ~r/<title data-inertia>(\s*)New title from ESM(\s*)<\/title>/
    assert body =~ ~s(<meta name="description" content="Head stuff" />)
    assert body =~ ~s(<div id="ssr"></div>)
  end

  test "preserves explicit .js extension on :module when esm: true", %{conn: conn} do
    path =
      __ENV__.file
      |> Path.dirname()
      |> Path.join("js/esm")

    start_supervised({Inertia.SSR, path: path, module: "ssr.js", esm: true})

    Application.put_env(:inertia, :ssr, true)

    body = conn |> get(~p"/") |> html_response(200)

    assert body =~ ~r/<title data-inertia>(\s*)New title from ESM(\s*)<\/title>/
  end

  test "auto-detects ESM from a .mjs module extension", %{conn: conn} do
    path =
      __ENV__.file
      |> Path.dirname()
      |> Path.join("js/mjs")

    start_supervised({Inertia.SSR, path: path, module: "ssr.mjs"})

    Application.put_env(:inertia, :ssr, true)

    body = conn |> get(~p"/") |> html_response(200)

    assert body =~ ~r/<title data-inertia>(\s*)New title from MJS(\s*)<\/title>/
  end

  describe "ssr_adapter option" do
    test "raises when the adapter module cannot be loaded" do
      assert_raise ArgumentError, ~r/could not be loaded/, fn ->
        Inertia.SSR.init(path: "/tmp", ssr_adapter: Nonexistent.Adapter)
      end
    end

    test "raises when the adapter module does not implement the behaviour" do
      assert_raise ArgumentError, ~r/does not implement the Inertia.SSR.Adapter behaviour/, fn ->
        Inertia.SSR.init(path: "/tmp", ssr_adapter: String)
      end
    end

    test "raises when the option is not a module atom" do
      assert_raise ArgumentError, ~r/expected a module/, fn ->
        Inertia.SSR.init(path: "/tmp", ssr_adapter: "not-a-module")
      end
    end
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

    assert body =~ ~r/<title data-inertia>(\s*)New title(\s*)<\/title>/
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

    assert body =~ ~r/<title data-inertia>(\s*)New title(\s*)<\/title>/
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
    assert body =~ ~s("component":"Home")
  end

  @tag :capture_log
  test "falls back to CSR if SSR worker crashes with non-string error", %{conn: conn} do
    path =
      __ENV__.file
      |> Path.dirname()
      |> Path.join("js")

    start_supervised({Inertia.SSR, path: path, module: "ssr-crash"})

    Application.put_env(:inertia, :ssr, true)
    Application.put_env(:inertia, :raise_on_ssr_failure, false)

    conn =
      conn
      |> get(~p"/")

    body = html_response(conn, 200)
    assert body =~ ~s("component":"Home")
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
               "errors" => %{}
             },
             "flash" => %{},
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
             "props" => %{"errors" => %{}, "b" => "b", "important" => "stuff"},
             "flash" => %{},
             "url" => "/always",
             "version" => @current_version
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
             "props" => %{"a" => "a", "errors" => %{}, "important" => "stuff"},
             "flash" => %{},
             "url" => "/always",
             "version" => @current_version
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
             "props" => %{"a" => "a", "important" => "stuff", "errors" => %{}},
             "flash" => %{},
             "url" => "/always",
             "version" => @current_version
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
               "b" => "b",
               "important" => "stuff"
             },
             "flash" => %{},
             "url" => "/always",
             "version" => @current_version
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
             "props" => %{"b" => "b", "errors" => %{}},
             "flash" => %{},
             "url" => "/tagged_lazy",
             "version" => @current_version
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
             "props" => %{"a" => "a", "errors" => %{}},
             "flash" => %{},
             "url" => "/tagged_lazy",
             "version" => @current_version
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
               "errors" => %{"settings.theme" => "can't be blank", "name" => "can't be blank"}
             },
             "flash" => %{},
             "url" => "/changeset_errors",
             "version" => @current_version
           }
  end

  test "does not wrap empty errors in bag", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-error-bag", "task")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/")

    assert %{"props" => %{"errors" => errors}} = json_response(conn, 200)
    assert errors == %{}
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
               }
             },
             "flash" => %{},
             "url" => "/changeset_errors",
             "version" => @current_version
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
    assert html_response(conn, 200) =~ ~s("errors":{"groceries")

    # Subsequent requests should now have the errors
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ ~s("errors":{})
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

    assert html_response(conn, 200) =~ ~s("flash":{"info":"Patched")
  end

  test "does not clobber the flash prop if manually set", %{conn: conn} do
    conn =
      conn
      |> get(~p"/overridden_flash")

    assert html_response(conn, 200) =~ ~s("flash":{"foo":"bar")
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

    assert html_response(conn, 200) =~ ~s("flash":{"info":"Patched")
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
             "props" => %{"errors" => %{}, "a" => "a", "b" => "b", "c" => "c"},
             "flash" => %{},
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
             "props" => %{"errors" => %{}, "a" => "a", "b" => "b", "c" => "c"},
             "flash" => %{},
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
               "a" => %{"a" => %{"b" => %{"c" => 1}}},
               "b" => ["a", "b"],
               "c" => "c",
               "d" => "d"
             },
             "flash" => %{},
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
               "a" => %{"a" => %{"b" => %{"c" => 1}}},
               "b" => ["a", "b"],
               "c" => "c",
               "d" => "d"
             },
             "flash" => %{},
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
             "props" => %{"errors" => %{}, "d" => "d"},
             "flash" => %{},
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
             "props" => %{"errors" => %{}, "a" => "a", "b" => "b", "c" => "c"},
             "flash" => %{},
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
             "props" => %{"errors" => %{}},
             "flash" => %{},
             "url" => "/encrypted_history",
             "version" => @current_version,
             "encryptHistory" => true
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
             "props" => %{"errors" => %{}},
             "flash" => %{},
             "url" => "/cleared_history",
             "version" => @current_version,
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
               "firstName" => "Bob",
               "items" => [%{"itemName" => "Foo"}]
             },
             "flash" => %{},
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
               "deferredItems" => [%{"itemName" => "Foo"}]
             },
             "flash" => %{},
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
               "first_name" => "Bob",
               "lastName" => "Jones",
               "profile" => %{"birth_year" => "Foo"}
             },
             "flash" => %{},
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

  # Shared Props Tests

  describe "shared props" do
    test "assign_shared_prop tags props and they appear in sharedProps JSON response", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> get(~p"/shared_props_via_assign")

      body = json_response(conn, 200)

      assert body["props"]["current_user"] == %{"id" => 1, "name" => "Alice"}
      assert body["props"]["other"] == "value"
      assert body["sharedProps"] == ["current_user"]
    end

    test "inertia_share in inline prop maps", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> get(~p"/shared_props_via_inline")

      body = json_response(conn, 200)

      assert body["props"]["current_user"] == %{"id" => 1}
      assert body["props"]["other"] == "value"
      assert body["sharedProps"] == ["current_user"]
    end

    test "sharedProps appears in HTML (CSR) page data", %{conn: conn} do
      conn = get(conn, ~p"/shared_props_via_assign")
      body = html_response(conn, 200)
      props = extract_page_data_from_html(body)

      assert props["props"]["current_user"] == %{"id" => 1, "name" => "Alice"}
      assert props["sharedProps"] == ["current_user"]
    end

    test "composability with inertia_merge", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> get(~p"/shared_props_with_merge")

      body = json_response(conn, 200)

      assert body["props"]["items"] == ["a", "b"]
      assert body["sharedProps"] == ["items"]
      assert body["mergeProps"] == ["items"]
    end

    test "composability with inertia_defer", %{conn: conn} do
      conn = get(conn, ~p"/shared_props_with_defer")
      body = html_response(conn, 200)
      props = extract_page_data_from_html(body)

      assert props["sharedProps"] == ["items"]
      assert props["deferredProps"]["default"] == ["items"]
    end

    test "sharedProps respects camelization of keys", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> get(~p"/shared_props_camelized")

      body = json_response(conn, 200)

      assert body["props"]["currentUser"] == %{"id" => 1}
      assert body["props"]["otherThing"] == "value"
      assert body["sharedProps"] == ["currentUser"]
    end

    test "sharedProps is omitted from response when empty", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> get(~p"/shared_props_empty")

      body = json_response(conn, 200)

      refute Map.has_key?(body, "sharedProps")
    end

    test "inertia_shared_props/1 test helper", %{conn: conn} do
      conn = get(conn, ~p"/shared_props_via_assign")

      assert Inertia.Testing.inertia_shared_props(conn) == ["current_user"]
    end

    test "inertia_shared_props/1 returns empty list when no shared props", %{conn: conn} do
      conn = get(conn, ~p"/shared_props_empty")

      assert Inertia.Testing.inertia_shared_props(conn) == []
    end
  end

  # Preserve Fragment Tests

  test "includes preserveFragment in JSON response when preserve_fragment is called", %{
    conn: conn
  } do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/preserved_fragment")

    body = json_response(conn, 200)
    assert body["preserveFragment"] == true
  end

  test "does not include preserveFragment by default", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/")

    body = json_response(conn, 200)
    refute Map.has_key?(body, "preserveFragment")
  end

  test "preserveFragment survives redirect and is consumed after one use", %{conn: conn} do
    # First, trigger a redirect with preserve_fragment
    conn =
      conn
      |> get(~p"/redirect_with_preserved_fragment")

    assert redirected_to(conn) == ~p"/"

    # After the redirect, the session flag should carry over
    conn =
      conn
      |> recycle()
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/")

    body = json_response(conn, 200)
    assert body["preserveFragment"] == true

    # On the next request, the flag should be consumed (one-shot)
    conn =
      conn
      |> recycle()
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/")

    body = json_response(conn, 200)
    refute Map.has_key?(body, "preserveFragment")
  end

  test "includes preserveFragment in HTML response when preserve_fragment is called", %{
    conn: conn
  } do
    conn = get(conn, ~p"/preserved_fragment")
    body = html_response(conn, 200)
    props = extract_page_data_from_html(body)

    assert props["preserveFragment"] == true
  end

  # Nested Prop Tests

  describe "nested prop types" do
    test "nested optional inside closure is excluded on initial load", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> get(~p"/nested_optional")

      body = json_response(conn, 200)

      # User should be included, but nested optional token should be excluded
      assert body["props"]["auth"]["user"] == "Alice"
      refute Map.has_key?(body["props"]["auth"], "token")
    end

    test "nested optional is included when explicitly requested in partial reload", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "auth.token")
        |> get(~p"/nested_optional")

      body = json_response(conn, 200)

      assert body["props"]["auth"]["token"] == "secret-token"
      refute Map.has_key?(body["props"]["auth"], "user")
    end

    test "nested defer inside closure generates deferredProps with dot-path", %{conn: conn} do
      conn = get(conn, ~p"/nested_defer")
      body = html_response(conn, 200)
      props = extract_page_data_from_html(body)

      # User should be present, permissions should be deferred
      assert props["props"]["auth"]["user"] == "Alice"
      refute Map.has_key?(props["props"]["auth"], "permissions")
      assert props["deferredProps"]["default"] == ["auth.permissions"]
    end

    test "nested defer is resolved on partial reload", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "auth.permissions")
        |> get(~p"/nested_defer")

      body = json_response(conn, 200)

      assert body["props"]["auth"]["permissions"] == ["read", "write"]
      refute Map.has_key?(body["props"]["auth"], "user")
    end

    test "nested merge inside closure generates mergeProps with dot-path", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> get(~p"/nested_merge")

      body = json_response(conn, 200)

      assert body["props"]["feed"]["posts"] == ["post1", "post2"]
      assert body["props"]["feed"]["meta"] == "info"
      assert body["mergeProps"] == ["feed.posts"]
    end

    test "nested deep_merge inside closure generates deepMergeProps with dot-path", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> get(~p"/nested_deep_merge")

      body = json_response(conn, 200)

      assert body["props"]["feed"]["posts"] == %{"items" => [1, 2]}
      assert body["props"]["feed"]["meta"] == "info"
      assert body["deepMergeProps"] == ["feed.posts"]
    end

    test "nested always prop is included when requesting specific sibling in partial", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "auth.user")
        |> get(~p"/nested_always")

      body = json_response(conn, 200)

      # The requested child
      assert body["props"]["auth"]["user"] == "Alice"
      # The always prop should be included even though only auth.user was requested
      assert body["props"]["auth"]["role"] == "admin"
      refute Map.has_key?(body["props"], "other")
    end

    test "dot-path partial filtering returns only the requested nested key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "auth.permissions")
        |> get(~p"/nested_partial_dot_path")

      body = json_response(conn, 200)

      assert body["props"]["auth"]["permissions"] == ["read", "write"]
      refute Map.has_key?(body["props"]["auth"], "user")
      refute Map.has_key?(body["props"]["auth"], "token")
    end

    test "requesting parent key returns full map including all children", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "auth")
        |> get(~p"/nested_partial_dot_path")

      body = json_response(conn, 200)

      assert body["props"]["auth"] == %{
               "user" => "Alice",
               "permissions" => ["read", "write"],
               "token" => "secret"
             }

      refute Map.has_key?(body["props"], "other")
    end

    test "parent_was_resolved: closure returns all children without individual listing", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "auth")
        |> get(~p"/nested_parent_resolved")

      body = json_response(conn, 200)

      # Since auth is a closure, requesting "auth" should return ALL children
      assert body["props"]["auth"] == %{"user" => "Alice", "token" => "secret"}
      refute Map.has_key?(body["props"], "other")
    end

    test "two-level unwrapping generates both deferred and merge metadata", %{conn: conn} do
      conn = get(conn, ~p"/nested_two_level_unwrap")
      body = html_response(conn, 200)
      props = extract_page_data_from_html(body)

      assert props["deferredProps"]["default"] == ["stats"]
      assert "stats" in props["mergeProps"]
    end

    test "nested once prop generates onceProps with dot-path", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> get(~p"/nested_once")

      body = json_response(conn, 200)

      assert body["props"]["auth"]["user"] == "Alice"
      assert body["props"]["auth"]["plans"] == ["basic", "pro"]

      assert body["onceProps"] == %{
               "auth.plans" => %{"prop" => "auth.plans", "expiresAt" => nil}
             }
    end

    test "camelization with nested prop types uses camelized dot-paths", %{conn: conn} do
      conn = get(conn, ~p"/nested_camelized")
      body = html_response(conn, 200)
      props = extract_page_data_from_html(body)

      assert props["props"]["userProfile"]["fullName"] == "Alice"
      refute Map.has_key?(props["props"]["userProfile"], "accessLevel")
      assert props["deferredProps"]["default"] == ["userProfile.accessLevel"]
    end

    test "nested scroll prop generates correct dot-path merge paths", %{conn: conn} do
      conn = get(conn, ~p"/nested_scroll")
      body = html_response(conn, 200)
      props = extract_page_data_from_html(body)

      assert props["props"]["feed"]["posts"]["data"] == [%{"id" => 1}]
      assert props["props"]["feed"]["title"] == "My Feed"
      assert "feed.posts.data" in props["mergeProps"]

      assert props["scrollProps"] == %{
               "feed.posts" => %{
                 "pageName" => "page",
                 "currentPage" => 1,
                 "previousPage" => nil,
                 "nextPage" => 2
               }
             }
    end

    test "plain nested map does NOT set parent_was_resolved", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "auth.user")
        |> get(~p"/nested_plain_map_partial")

      body = json_response(conn, 200)

      # Only the specifically requested nested key should be present
      assert body["props"]["auth"]["user"] == "Alice"
      refute Map.has_key?(body["props"]["auth"], "token")
    end

    test "nested except filtering with dot-paths excludes only the specified key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-except", "auth.token")
        |> get(~p"/nested_partial_dot_path")

      body = json_response(conn, 200)

      assert body["props"]["auth"]["user"] == "Alice"
      assert body["props"]["auth"]["permissions"] == ["read", "write"]
      refute Map.has_key?(body["props"]["auth"], "token")
    end

    test "reset with nested merge props excludes path from mergeProps", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-reset", "feed.posts")
        |> get(~p"/nested_merge")

      body = json_response(conn, 200)

      assert body["props"]["feed"]["posts"] == ["post1", "post2"]
      refute body["mergeProps"]
    end

    test "nested once with except-once-props dot-path excludes value but keeps metadata", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-except-once-props", "auth.plans")
        |> get(~p"/nested_once")

      body = json_response(conn, 200)

      assert body["props"]["auth"]["user"] == "Alice"
      refute Map.has_key?(body["props"]["auth"], "plans")

      assert body["onceProps"] == %{
               "auth.plans" => %{"prop" => "auth.plans", "expiresAt" => nil}
             }
    end

    test "partial reload excluding nested once parent preserves once metadata", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "regular")
        |> get(~p"/nested_once")

      body = json_response(conn, 200)

      assert body["props"]["regular"] == "value"
      refute Map.has_key?(body["props"], "auth")

      assert body["onceProps"] == %{
               "auth.plans" => %{"prop" => "auth.plans", "expiresAt" => nil}
             }
    end

    test "except-once-props bypassed when parent path is in partial data", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "auth")
        |> put_req_header("x-inertia-except-once-props", "auth.plans")
        |> get(~p"/nested_once")

      body = json_response(conn, 200)

      assert body["props"]["auth"]["user"] == "Alice"
      assert body["props"]["auth"]["plans"] == ["basic", "pro"]
    end

    test "except-once-props bypassed when exact path is in partial data", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "auth.plans")
        |> put_req_header("x-inertia-except-once-props", "auth.plans")
        |> get(~p"/nested_once")

      body = json_response(conn, 200)

      assert body["props"]["auth"]["plans"] == ["basic", "pro"]
    end

    test "two-level unwrap resolves deferred value on partial reload", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", @current_version)
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "stats")
        |> get(~p"/nested_two_level_unwrap")

      body = json_response(conn, 200)

      assert body["props"]["stats"] == "data"
    end
  end

  # Vary header tests

  test "sets Vary: X-Inertia header on all responses", %{conn: conn} do
    # Non-Inertia HTML response
    conn = get(conn, ~p"/")
    assert "X-Inertia" in get_resp_header(conn, "vary")
  end

  test "sets Vary: X-Inertia on Inertia JSON responses", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/")

    assert "X-Inertia" in get_resp_header(conn, "vary")
  end

  test "sets Vary: X-Inertia on non-Inertia responses", %{conn: conn} do
    conn = get(conn, ~p"/non_inertia")
    assert "X-Inertia" in get_resp_header(conn, "vary")
  end

  # clearHistory session persistence tests

  test "clearHistory survives redirect and is consumed after one use", %{conn: conn} do
    conn = get(conn, ~p"/redirect_with_clear_history")
    assert redirected_to(conn) == ~p"/"

    # After the redirect, clearHistory should carry over
    conn =
      conn
      |> recycle()
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/")

    body = json_response(conn, 200)
    assert body["clearHistory"] == true

    # On the next request, the flag should be consumed (one-shot)
    conn =
      conn
      |> recycle()
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/")

    body = json_response(conn, 200)
    refute Map.has_key?(body, "clearHistory")
  end

  # Flash as top-level key tests

  test "flash appears at top level of JSON response", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/")

    body = json_response(conn, 200)
    assert body["flash"] == %{}
    refute Map.has_key?(body["props"], "flash")
  end

  test "flash appears at top level of HTML response", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    props = extract_page_data_from_html(body)

    assert props["flash"] == %{}
    refute Map.has_key?(props["props"], "flash")
  end

  test "overridden flash prop is extracted to top level", %{conn: conn} do
    conn = get(conn, ~p"/overridden_flash")
    body = html_response(conn, 200)
    props = extract_page_data_from_html(body)

    assert props["flash"] == %{"foo" => "bar"}
    refute Map.has_key?(props["props"], "flash")
  end

  test "inertia_flash/1 testing helper", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert Inertia.Testing.inertia_flash(conn) == %{}
  end

  # Hash fragment redirect tests

  test "redirects with fragment return 409 with X-Inertia-Redirect header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/redirect_with_fragment")

    assert response(conn, 409)
    assert get_resp_header(conn, "x-inertia-redirect") == ["/page#section"]
  end

  test "fragment redirect skipped for prefetch requests", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-purpose", "prefetch")
      |> get(~p"/redirect_with_fragment")

    # Should be a normal 303 redirect (PUT/PATCH/DELETE) or 302 (GET)
    assert response(conn, 302)
  end

  # Empty response handling tests

  test "empty Inertia response redirects back to referer path", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("referer", "http://localhost/previous")
      |> get(~p"/empty_response")

    assert response(conn, 303)
    assert get_resp_header(conn, "location") == ["/previous"]
  end

  test "empty Inertia response redirects to / when no referer", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/empty_response")

    assert response(conn, 303)
    assert get_resp_header(conn, "location") == ["/"]
  end

  test "non-Inertia empty response is not redirected", %{conn: conn} do
    conn = get(conn, ~p"/empty_response")
    assert response(conn, 200)
  end

  # Prepend merge support tests

  test "prepend props appear in both mergeProps and prependProps", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/prepend_props")

    body = json_response(conn, 200)

    assert body["props"]["a"] == "a"
    assert body["props"]["b"] == "b"
    assert body["props"]["c"] == "c"

    merge_props = body["mergeProps"]
    assert "a" in merge_props
    assert "b" in merge_props

    assert body["prependProps"] == ["a"]
  end

  # matchPropsOn tests

  test "matchPropsOn includes match keys for merge/prepend/deep_merge props", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/match_props_on")

    body = json_response(conn, 200)

    assert body["props"]["users"] == [%{"id" => 1}]
    assert body["props"]["items"] == [%{"id" => 2}]
    assert body["props"]["data"] == %{"a" => 1}

    assert body["matchPropsOn"] == %{
             "users" => "id",
             "items" => "id",
             "data" => "key"
           }
  end

  # Scroll prop reset field tests

  test "scroll props include reset: true when data path is in reset header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-reset", "users.data")
      |> get(~p"/scroll_props_with_reset")

    body = json_response(conn, 200)

    # Reset should be present in scroll metadata
    assert body["scrollProps"]["users"]["reset"] == true

    # mergeProps should NOT include the reset path
    refute body["mergeProps"]
  end

  test "scroll props do not include reset when data path is not in reset header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> get(~p"/scroll_props_with_reset")

    body = json_response(conn, 200)

    refute Map.has_key?(body["scrollProps"]["users"], "reset")
    assert "users.data" in body["mergeProps"]
  end

  # SSR path exclusion tests

  test "excludes paths from SSR based on string prefix config", %{conn: conn} do
    Application.put_env(:inertia, :ssr_exclude_paths, ["/ssr_excluded"])

    on_exit(fn -> Application.delete_env(:inertia, :ssr_exclude_paths) end)

    # Since SSR server isn't running, this verifies that SSR detection is disabled
    # for excluded paths (no SSR error raised)
    conn = get(conn, ~p"/ssr_excluded")
    assert html_response(conn, 200)
  end

  test "excludes paths from SSR based on regex pattern config", %{conn: conn} do
    Application.put_env(:inertia, :ssr_exclude_paths, [~r/^\/ssr_/])

    on_exit(fn -> Application.delete_env(:inertia, :ssr_exclude_paths) end)

    conn = get(conn, ~p"/ssr_excluded")
    assert html_response(conn, 200)
  end

  # Scroll props with prepend merge intent

  test "scroll props use prependProps when merge intent is prepend", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-infinite-scroll-merge-intent", "prepend")
      |> get(~p"/scroll_props_prepend")

    body = json_response(conn, 200)

    assert "users.data" in body["mergeProps"]
    assert "users.data" in body["prependProps"]
  end

  test "scroll props do not use prependProps when merge intent is append", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-inertia", "true")
      |> put_req_header("x-inertia-version", @current_version)
      |> put_req_header("x-inertia-infinite-scroll-merge-intent", "append")
      |> get(~p"/scroll_props_prepend")

    body = json_response(conn, 200)

    assert "users.data" in body["mergeProps"]
    refute body["prependProps"]
  end

  # Testing utilities tests

  test "inertia_page/1 returns the full page object", %{conn: conn} do
    conn = get(conn, ~p"/")
    page = Inertia.Testing.inertia_page(conn)

    assert page[:component] == "Home"
    assert is_map(page[:props])
    assert page[:flash] == %{}
  end

  test "inertia_deferred_props/1 returns deferred prop groups", %{conn: conn} do
    conn = get(conn, ~p"/deferred_props")
    deferred = Inertia.Testing.inertia_deferred_props(conn)

    assert Map.has_key?(deferred, "default")
  end

  test "inertia_merge_props/1 returns merge prop keys", %{conn: conn} do
    conn = get(conn, ~p"/merge_props")
    merge = Inertia.Testing.inertia_merge_props(conn)

    assert "a" in merge
    assert "b" in merge
  end

  test "inertia_scroll_props/1 returns scroll metadata", %{conn: conn} do
    conn = get(conn, ~p"/scroll_props")
    scroll = Inertia.Testing.inertia_scroll_props(conn)

    assert Map.has_key?(scroll, "users")
    assert scroll["users"]["currentPage"] == 1
  end

  test "inertia_once_props/1 returns once prop metadata", %{conn: conn} do
    conn = get(conn, ~p"/once_props")
    once = Inertia.Testing.inertia_once_props(conn)

    assert Map.has_key?(once, "plans")
    assert once["plans"]["prop"] == "plans"
  end

  defp extract_page_data_from_html(raw_html) do
    {:ok, html} = Floki.parse_document(raw_html)

    json_data =
      html
      |> Floki.find("script[data-page=app]")
      |> Floki.text(js: true)

    Jason.decode!(json_data)
  end
end
