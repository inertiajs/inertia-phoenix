defmodule DevToolsTestApp do
  @moduledoc false

  # Stands in for app code calling Inertia (DevTools ignores frames from
  # Inertia's own modules, test modules included). The call is not in tail
  # position, so it leaves a stack frame behind.
  def assign_prop(conn, key, value) do
    {:ok, Inertia.Controller.assign_prop(conn, key, value)}
  end
end

defmodule Inertia.DevToolsTest do
  use MyAppWeb.ConnCase

  import Plug.Conn

  alias Inertia.DevTools.Store

  @current_version "db137d38dc4b6ee57d5eedcf0182de8a"
  @controller_file "test/support/my_app/lib/my_app_web/controllers/page_controller.ex"

  setup do
    Application.put_env(:inertia, :ssr, false)
    Application.put_env(:inertia, :devtools, enabled: true)
    on_exit(fn -> Application.delete_env(:inertia, :devtools) end)

    start_supervised!(Inertia.DevTools)
    :ok
  end

  describe "recording" do
    test "stamps the entry id and batch root on the response", %{conn: conn} do
      conn = get(conn, ~p"/")

      assert [id] = get_resp_header(conn, "x-inertia-devtools-id")
      assert Inertia.DevTools.ULID.valid?(id)
      assert get_resp_header(conn, "x-inertia-devtools-parent-out") == [id]
      assert get_resp_header(conn, "x-inertia-devtools-base-path") == []
    end

    test "renders the entry id into the initial page load", %{conn: conn} do
      conn = get(conn, ~p"/")
      [id] = get_resp_header(conn, "x-inertia-devtools-id")

      assert [tag] = conn |> html_response(200) |> Floki.find("script[data-inertia-devtools-id]")
      assert Floki.attribute(tag, "type") == ["application/json"]
      assert tag |> Floki.text(js: true) |> String.trim() == ~s("#{id}")
    end

    test "records the initial page load", %{conn: conn} do
      entry = conn |> get(~p"/?foo=bar") |> fetch_entry()

      assert %{
               "requestType" => "initial",
               "method" => "GET",
               "url" => "http://www.example.com/?foo=bar",
               "component" => "Home",
               "status" => 200,
               "tabUuid" => nil,
               "batchId" => nil,
               "redirectLocation" => nil
             } = entry["__meta"]

      assert is_float(entry["__meta"]["serverTimingMs"])

      assert entry["http"]["requestBody"] == %{
               "status" => "present",
               "value" => %{"foo" => "bar"}
             }

      assert %{"status" => "present", "value" => %{"component" => "Home", "url" => "/?foo=bar"}} =
               entry["http"]["responseBody"]
    end

    test "records Inertia visits", %{conn: conn} do
      entry = conn |> inertia_conn() |> get(~p"/") |> fetch_entry()

      assert entry["__meta"]["requestType"] == "navigate"
      assert entry["http"]["requestHeaders"]["x-inertia"] == "true"
      assert entry["http"]["responseHeaders"]["x-inertia"] == "true"

      assert %{"status" => "present", "value" => %{"props" => props}} =
               entry["http"]["responseBody"]

      assert props["text"] == "Hello World"
    end

    test "records requests that render no Inertia page", %{conn: conn} do
      entry = conn |> get(~p"/non_inertia") |> fetch_entry()

      assert %{"requestType" => "http", "component" => nil} = entry["__meta"]
      assert %{"status" => "present", "value" => html} = entry["http"]["responseBody"]
      assert is_binary(html)
      assert entry["props"] == %{}
    end

    test "omits large response bodies", %{conn: conn} do
      entry = conn |> get(~p"/devtools_large") |> fetch_entry()

      assert entry["http"]["responseBody"] == %{"status" => "omitted", "reason" => "too-large"}
    end

    test "never fails the request when tracking a prop fails" do
      # A malformed recording state makes tracking raise once it finds the
      # app's call site
      conn = %Plug.Conn{private: %{inertia_devtools: %{}}}

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:ok, conn} = DevToolsTestApp.assign_prop(conn, :a, 1)
          assert conn.private.inertia_shared == %{a: 1}
        end)

      assert log =~ "Inertia DevTools failed to record"
    end

    test "derives the request type of each kind of visit", %{conn: conn} do
      partial = [{"x-inertia-partial-component", "Home"}, {"x-inertia-partial-data", "a"}]

      assert request_type(conn, ~p"/deferred_props", [
               {"x-inertia-devtools-deferred", "1"} | partial
             ]) == "deferred"

      assert request_type(conn, ~p"/", [{"x-inertia-devtools-poll", "1"}]) == "poll"
      assert request_type(conn, ~p"/deferred_props", partial) == "partial"
      assert request_type(conn, ~p"/", [{"purpose", "prefetch"}]) == "prefetch"
      assert request_type(conn, ~p"/", []) == "navigate"
    end

    test "records the client's tab and visit ids", %{conn: conn} do
      entry =
        conn
        |> inertia_conn()
        |> put_req_header("x-inertia-devtools-tab", "tab-1")
        |> put_req_header("x-inertia-devtools-visit", "visit-1")
        |> get(~p"/")
        |> fetch_entry()

      assert %{"tabUuid" => "tab-1", "visitId" => "visit-1"} = entry["__meta"]
    end

    test "records redirects after Inertia's rewrites", %{conn: conn} do
      conn =
        conn
        |> inertia_conn()
        |> put_req_header("content-type", "application/json")
        |> put(~p"/devtools", Jason.encode!(%{name: "Alice", password: "hunter2"}))

      entry = fetch_entry(conn)

      assert %{"status" => 303, "redirectLocation" => "/"} = entry["__meta"]

      assert entry["http"]["requestBody"] == %{
               "status" => "present",
               "value" => %{"name" => "Alice", "password" => "[REDACTED]"}
             }
    end

    test "records external redirects", %{conn: conn} do
      entry = conn |> inertia_conn() |> get(~p"/external_redirect") |> fetch_entry()

      assert %{"status" => 409, "redirectLocation" => "http://www.example.com/"} =
               entry["__meta"]
    end

    test "omits the bodies of non-Inertia form submissions", %{conn: conn} do
      entry = conn |> put(~p"/devtools", %{password: "hunter2"}) |> fetch_entry()

      assert entry["http"]["requestBody"] == %{
               "status" => "omitted",
               "reason" => "non-inertia-request"
             }
    end

    test "records version mismatches", %{conn: conn} do
      entry =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("x-inertia-version", "stale")
        |> get(~p"/")
        |> fetch_entry()

      assert %{"status" => 409, "requestType" => "navigate"} = entry["__meta"]
    end

    # The endpoint sets the script name from its own config, so this is checked
    # below the endpoint, where the header and the id tag read it from.
    test "reports the mount path of an app not served from the root" do
      conn = %Plug.Conn{script_name: ["app"], private: %{inertia_devtools: %{id: "01ID"}}}

      assert Inertia.DevTools.Recorder.tag(conn) == %{id: "01ID", base_path: "/app"}
      assert Inertia.DevTools.Recorder.tag(%{conn | script_name: []}).base_path == nil
    end
  end

  describe "batching" do
    test "continues the batch named by the client", %{conn: conn} do
      conn =
        conn
        |> inertia_conn()
        |> put_req_header("x-inertia-devtools-parent", "01ROOT")
        |> get(~p"/")

      assert get_resp_header(conn, "x-inertia-devtools-parent-out") == ["01ROOT"]
      assert fetch_entry(conn)["__meta"]["batchId"] == "01ROOT"
    end

    test "starts a new batch for a prefetch", %{conn: conn} do
      conn =
        conn
        |> inertia_conn()
        |> put_req_header("purpose", "prefetch")
        |> put_req_header("x-inertia-devtools-parent", "01ROOT")
        |> get(~p"/")

      [id] = get_resp_header(conn, "x-inertia-devtools-id")

      assert get_resp_header(conn, "x-inertia-devtools-parent-out") == [id]
      assert fetch_entry(conn)["__meta"]["batchId"] == "01ROOT"
    end

    test "ignores the batch header on full page loads", %{conn: conn} do
      conn = conn |> put_req_header("x-inertia-devtools-parent", "01ROOT") |> get(~p"/")
      [id] = get_resp_header(conn, "x-inertia-devtools-id")

      assert get_resp_header(conn, "x-inertia-devtools-parent-out") == [id]
      assert fetch_entry(conn)["__meta"]["batchId"] == nil
    end
  end

  describe "props" do
    test "records prop values and sources", %{conn: conn} do
      entry = conn |> inertia_conn() |> get(~p"/devtools") |> fetch_entry()
      file = Path.expand(@controller_file)

      assert entry["propValues"] == %{
               "assigned" => "assigned",
               "inline" => "inline",
               "password" => "[REDACTED]",
               "important" => "stuff",
               "current_user" => %{"name" => "Alice"},
               "errors" => %{}
             }

      assert entry["renderSource"] == %{"file" => file, "line" => 15}
      assert entry["props"]["assigned"]["renderSource"] == %{"file" => file, "line" => 13}
      assert entry["props"]["inline"]["renderSource"] == %{"file" => file, "line" => 16}
      assert entry["props"]["important"]["inertiaType"] == "always"

      assert %{
               "uri" => "/devtools",
               "name" => nil,
               "action" => "MyAppWeb.PageController.devtools",
               "actionSource" => %{"file" => ^file, "line" => 10}
             } = entry["route"]
    end

    test "marks props assigned outside the controller as shared", %{conn: conn} do
      entry = conn |> inertia_conn() |> get(~p"/devtools") |> fetch_entry()

      assert entry["props"]["current_user"] == %{
               "shared" => true,
               "inertiaType" => nil,
               "shareSource" => %{
                 "file" => Path.expand("test/support/my_app/lib/my_app_web/plugs/share_user.ex"),
                 "line" => 11
               }
             }

      # Assigned by Inertia.Plug, whose caller (the router pipeline) is code
      # generated by a macro, which has no meaningful location
      assert entry["props"]["errors"] == %{"shared" => true, "inertiaType" => "always"}
      assert entry["props"]["assigned"]["shared"] == false
      assert entry["props"]["inline"]["shared"] == false
    end

    test "marks props tagged as shared", %{conn: conn} do
      entry = conn |> inertia_conn() |> get(~p"/shared_props_via_assign") |> fetch_entry()

      assert %{"shared" => true, "shareSource" => %{"line" => _}} =
               entry["props"]["current_user"]

      assert entry["props"]["other"]["shared"] == false
    end

    test "records merge props", %{conn: conn} do
      entry = conn |> inertia_conn() |> get(~p"/prepend_props") |> fetch_entry()

      assert %{"inertiaType" => "merge", "mergeDirection" => "prepend"} = entry["props"]["a"]
      assert %{"inertiaType" => "merge", "mergeDirection" => "append"} = entry["props"]["b"]
      assert %{"inertiaType" => nil} = entry["props"]["c"]
      refute Map.has_key?(entry["props"]["c"], "mergeDirection")

      entry = conn |> inertia_conn() |> get(~p"/match_props_on") |> fetch_entry()

      assert %{"deepMerge" => true, "mergeDirection" => "append"} = entry["props"]["users"]
      assert %{"deepMerge" => true, "mergeDirection" => "prepend"} = entry["props"]["items"]
    end

    test "records deferred props only when delivered by a deferred visit", %{conn: conn} do
      partial = fn conn ->
        conn
        |> inertia_conn()
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "b")
      end

      entry =
        conn
        |> partial.()
        |> put_req_header("x-inertia-devtools-deferred", "1")
        |> get(~p"/deferred_props")
        |> fetch_entry()

      assert %{"inertiaType" => "defer", "deferGroup" => "dashboard"} = entry["props"]["b"]

      entry = conn |> partial.() |> get(~p"/deferred_props") |> fetch_entry()

      assert entry["props"]["b"]["inertiaType"] == nil
      refute Map.has_key?(entry["props"]["b"], "deferGroup")
    end

    test "leaves out deferred props the initial load does not resolve", %{conn: conn} do
      entry = conn |> inertia_conn() |> get(~p"/deferred_props") |> fetch_entry()

      assert Map.keys(entry["props"]) |> Enum.sort() == ["d", "errors"]
    end

    @tag :capture_log
    test "records rescued deferred props", %{conn: conn} do
      entry =
        conn
        |> inertia_conn()
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "ok,boom,auth.permissions")
        |> put_req_header("x-inertia-devtools-deferred", "1")
        |> get(~p"/rescued_deferred_props")
        |> fetch_entry()

      assert %{"inertiaType" => "defer", "rescued" => true} = entry["props"]["boom"]
      assert %{"inertiaType" => "defer", "rescued" => true} = entry["props"]["auth.permissions"]
      refute Map.has_key?(entry["props"]["ok"], "rescued")
      refute Map.has_key?(entry["propValues"], "boom")
    end

    test "records optional props", %{conn: conn} do
      entry =
        conn
        |> inertia_conn()
        |> put_req_header("x-inertia-partial-component", "Home")
        |> put_req_header("x-inertia-partial-data", "a")
        |> get(~p"/tagged_lazy")
        |> fetch_entry()

      assert entry["props"]["a"]["inertiaType"] == "optional"
    end

    test "records once and scroll props", %{conn: conn} do
      entry = conn |> inertia_conn() |> get(~p"/once_props") |> fetch_entry()

      assert %{"inertiaType" => "once", "once" => true} = entry["props"]["plans"]

      entry = conn |> inertia_conn() |> get(~p"/scroll_props") |> fetch_entry()

      assert %{"inertiaType" => "scroll", "mergeDirection" => "append"} = entry["props"]["users"]
      refute Map.has_key?(entry["props"], "users.data")
    end

    test "uses camelized prop paths", %{conn: conn} do
      entry = conn |> inertia_conn() |> get(~p"/camelized_props") |> fetch_entry()

      assert Map.keys(entry["props"]) == Map.keys(entry["propValues"])
      assert Enum.all?(Map.keys(entry["props"]), &(not String.contains?(&1, "_")))
    end

    test "records reset props", %{conn: conn} do
      entry =
        conn
        |> inertia_conn()
        |> put_req_header("x-inertia-reset", "a")
        |> get(~p"/merge_props")
        |> fetch_entry()

      assert entry["props"]["a"]["reset"] == true
    end

    test "links components to their source files", %{conn: conn} do
      dir = Path.join(System.tmp_dir!(), "inertia_devtools_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "Home.tsx"), "")
      on_exit(fn -> File.rm_rf!(dir) end)

      Application.put_env(:inertia, :devtools,
        enabled: true,
        component_path: [Path.join(dir, "{component}.jsx"), Path.join(dir, "{component}.tsx")]
      )

      entry = conn |> get(~p"/") |> fetch_entry()

      assert entry["componentPath"] == Path.join(dir, "Home.tsx")
    end
  end

  describe "redaction" do
    test "redacts camelized keys, Phoenix-filtered keys, and nested props", %{conn: conn} do
      entry = conn |> inertia_conn() |> get(~p"/devtools_secrets") |> fetch_entry()

      # `auth.token` is listed on its own because it carries metadata (it is
      # an always prop), so it is redacted by its path
      assert %{
               "apiKey" => "[REDACTED]",
               "newPassword" => "[REDACTED]",
               "auth" => %{"user" => "Alice", "token" => "[REDACTED]"},
               "auth.token" => "[REDACTED]"
             } = entry["propValues"]

      assert %{
               "apiKey" => "[REDACTED]",
               "newPassword" => "[REDACTED]",
               "auth" => %{"user" => "Alice", "token" => "[REDACTED]"}
             } = entry["http"]["responseBody"]["value"]["props"]
    end

    test "redacts query strings in the page object and URL headers", %{conn: conn} do
      entry =
        conn
        |> put_req_header("referer", "http://www.example.com/reset?token=abc")
        |> get(~p"/?token=abc")
        |> fetch_entry()

      assert entry["http"]["responseBody"]["value"]["url"] == "/?token=[REDACTED]"

      assert entry["http"]["requestHeaders"]["referer"] ==
               "http://www.example.com/reset?token=[REDACTED]"
    end

    test "redacts sensitive headers, params, and query strings", %{conn: conn} do
      entry =
        conn
        |> put_req_header("authorization", "Bearer secret")
        |> put_req_header("cookie", "_session=secret")
        |> get(~p"/?token=abc&page=2")
        |> fetch_entry()

      assert entry["http"]["requestHeaders"]["authorization"] == "[REDACTED]"
      assert entry["http"]["requestHeaders"]["cookie"] == "[REDACTED]"
      assert entry["__meta"]["url"] == "http://www.example.com/?token=[REDACTED]&page=2"

      assert entry["http"]["requestBody"]["value"] == %{"token" => "[REDACTED]", "page" => "2"}
    end

    test "redacts configured keys", %{conn: conn} do
      Application.put_env(:inertia, :devtools, enabled: true, redact_keys: ["Inline"])

      entry = conn |> inertia_conn() |> get(~p"/devtools") |> fetch_entry()

      assert entry["propValues"]["inline"] == "[REDACTED]"

      assert %{"status" => "present", "value" => %{"props" => %{"inline" => "[REDACTED]"}}} =
               entry["http"]["responseBody"]
    end
  end

  describe "entries endpoint" do
    test "returns 404 for unknown entries", %{conn: conn} do
      assert conn
             |> get("/_inertia/devtools/entries/01HZZZZZZZZZZZZZZZZZZZZZZZ")
             |> json_response(404)

      assert conn |> get("/_inertia/devtools/entries/../../etc") |> response(404)
    end

    test "lists entries newest first, filtered by type", %{conn: conn} do
      initial = conn |> get(~p"/") |> entry_id()
      navigate = conn |> inertia_conn() |> get(~p"/") |> entry_id()
      http = conn |> get(~p"/non_inertia") |> entry_id()

      ids = fn query ->
        conn
        |> get("/_inertia/devtools/entries?#{query}")
        |> json_response(200)
        |> Enum.map(& &1["id"])
      end

      assert ids.("") == [http, navigate, initial]
      assert ids.("type=initial,navigate") == [navigate, initial]
      assert ids.("exclude=http") == [navigate, initial]
      assert ids.("limit=1&offset=1") == [navigate]
    end

    test "evicts the oldest entries of a tab beyond the limit", %{conn: conn} do
      stop_supervised!(Inertia.DevTools)
      Application.put_env(:inertia, :devtools, enabled: true, limit: 2)
      start_supervised!(Inertia.DevTools)

      tab = fn conn, id -> put_req_header(conn, "x-inertia-devtools-tab", id) end

      [first, second, third] = for _ <- 1..3, do: conn |> tab.("a") |> get(~p"/") |> entry_id()
      other = conn |> tab.("b") |> get(~p"/") |> entry_id()

      # Eviction happens asynchronously in the store process
      :sys.get_state(Store)

      assert Store.fetch(first) == :error
      assert {:ok, _} = Store.fetch(second)
      assert {:ok, _} = Store.fetch(third)
      assert {:ok, _} = Store.fetch(other)
    end
  end

  describe "store" do
    test "does not queue an entry twice when a prune rebuilds the queues first" do
      id = Inertia.DevTools.ULID.generate()

      # Insert the row as Store.put/4 does, but let a prune rebuild the tab
      # queues from the table before the insert's cast is handled
      :ets.insert(Store, {id, "tab", System.monotonic_time(:second), %{}, "{}"})
      send(Store, :prune)
      GenServer.cast(Store, {:inserted, id, "tab"})

      assert Store |> :sys.get_state() |> get_in([:tabs, "tab"]) |> :queue.to_list() == [id]
    end
  end

  describe "ULID" do
    test "generates valid ids that sort by creation" do
      ids = for _ <- 1..100, do: Inertia.DevTools.ULID.generate()

      assert Enum.all?(ids, &Inertia.DevTools.ULID.valid?/1)
      assert Enum.sort(ids) == ids
    end

    test "rejects malformed ids" do
      refute Inertia.DevTools.ULID.valid?("01HZZZZZZZZZZZZZZZZZZZZZZU")
      refute Inertia.DevTools.ULID.valid?("01hzzzzzzzzzzzzzzzzzzzzzzz")
      refute Inertia.DevTools.ULID.valid?("01HZZ")
      refute Inertia.DevTools.ULID.valid?(nil)
    end
  end

  describe "when disabled" do
    test "does not record requests", %{conn: conn} do
      Application.put_env(:inertia, :devtools, enabled: false)

      conn = get(conn, ~p"/")

      assert get_resp_header(conn, "x-inertia-devtools-id") == []
      assert conn |> html_response(200) |> Floki.find("script[data-inertia-devtools-id]") == []
    end

    test "does not record requests while the store is not running", %{conn: conn} do
      stop_supervised!(Inertia.DevTools)

      assert conn |> get(~p"/") |> get_resp_header("x-inertia-devtools-id") == []
    end

    test "does not start the store", %{conn: _conn} do
      stop_supervised!(Inertia.DevTools)
      Application.put_env(:inertia, :devtools, enabled: false)

      assert Inertia.DevTools.start_link() == :ignore
    end

    test "does not serve entries", %{conn: conn} do
      id = conn |> get(~p"/") |> entry_id()
      Application.put_env(:inertia, :devtools, enabled: false)

      assert conn |> get("/_inertia/devtools/entries/#{id}") |> json_response(404)
    end
  end

  defp inertia_conn(conn) do
    conn
    |> put_req_header("x-inertia", "true")
    |> put_req_header("x-inertia-version", @current_version)
  end

  defp request_type(conn, path, headers) do
    conn
    |> inertia_conn()
    |> then(&Enum.reduce(headers, &1, fn {k, v}, conn -> put_req_header(conn, k, v) end))
    |> get(path)
    |> fetch_entry()
    |> get_in(["__meta", "requestType"])
  end

  defp entry_id(conn) do
    [id] = get_resp_header(conn, "x-inertia-devtools-id")
    id
  end

  # Fetches the recorded entry through the endpoint, as the extension does.
  defp fetch_entry(conn) do
    build_conn()
    |> get("/_inertia/devtools/entries/#{entry_id(conn)}")
    |> json_response(200)
  end
end
