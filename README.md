# Inertia.js Phoenix Adapter [![Hex Package](https://img.shields.io/hexpm/v/inertia)](https://hex.pm/packages/inertia) [![Hex Docs](https://img.shields.io/badge/docs-green)](https://hexdocs.pm/inertia/readme.html)

The official Elixir/Phoenix adapter for [Inertia.js](https://inertiajs.com/).

## Table of Contents

- [Installation](#installation)
- [Rendering responses](#rendering-responses)
- [Setting up the client-side](#setting-up-the-client-side)
- [Lazy data evaluation](#lazy-data-evaluation)
- [Deferred props](#deferred-props)
- [Merge props](#merge-props)
- [Prepend props](#prepend-props)
- [Once props](#once-props)
- [Scroll props](#scroll-props)
- [Shared data](#shared-data)
- [Validations](#validations)
- [Flash messages](#flash-messages)
- [CSRF protection](#csrf-protection)
- [History](#history)
- [Testing](#testing)
- [Server-side rendering](#server-side-rendering)

## Installation

### Using Igniter

The easiest way to get started is to use the [Igniter](https://hexdocs.pm/igniter) installer.

```sh
mix archive.install hex igniter_new
mix igniter.install inertia
```

The following options can be used to customize the installation:

```sh
--client-framework [react|vue|svelte] # Configures the client-side framework in `assets/package.json`
--camelize-props                      # Sets `camelize_props: true` in `config.exs` (See below)
--history-encrypt                     # Sets `history: [encrypt: true]` in `config.exs` (See below)
--typescript                          # Creates a TypeScript config file and installs dev dependencies
```

### Manually

The package can be installed by adding `inertia` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:inertia, "~> 3.0.0-rc"}
  ]
end
```

Add your desired configuration in your `config.exs` file:

```elixir
# config/config.exs

config :inertia,
  # The Phoenix Endpoint module for your application. This is used for building
  # asset URLs to compute a unique version hash to track when something has
  # changed (and a reload is required on the frontend).
  endpoint: MyAppWeb.Endpoint,

  # An optional list of static file paths to track for changes. You'll generally
  # want to include any JavaScript assets that may require a page refresh when
  # modified.
  static_paths: ["/assets/js/app.js"],

  # The default version string to use (if you decide not to track any static
  # assets using the `static_paths` config). Defaults to "1".
  default_version: "1",

  # Enable automatic conversion of prop keys from snake case (e.g. `inserted_at`),
  # which is conventional in Elixir, to camel case (e.g. `insertedAt`), which is
  # conventional in JavaScript. Defaults to `false`.
  camelize_props: false,

  # Instruct the client side whether to encrypt the page object in the window history
  # state. This can also be set/overridden on a per-request basis, using the `encrypt_history`
  # controller helper. Defaults to `false`.
  history: [encrypt: false],

  # Enable server-side rendering for page responses (requires some additional setup,
  # see instructions below). Defaults to `false`.
  ssr: false,

  # Whether to raise an exception when server-side rendering fails (only applies
  # when SSR is enabled). Defaults to `true`.
  #
  # Recommended: enable in non-production environments and disable in production,
  # so that SSR failures will not cause 500 errors (but instead will fallback to
  # CSR).
  raise_on_ssr_failure: config_env() != :prod,

  # The connection assign key to read a Content-Security-Policy nonce from. When
  # set, and the assign contains a value, the nonce will be applied to the
  # `<script>` tag that the library injects to bootstrap the page data. Use this
  # if you serve your app with a strict CSP that disallows inline scripts without
  # a nonce. Defaults to `nil` (no nonce).
  csp_nonce_assign_key: :csp_nonce
```

This library includes a few modules to help render Inertia responses:

- [`Inertia.Plug`](https://hexdocs.pm/inertia/Inertia.Plug.html): a plug for detecting Inertia.js requests and preparing the connection accordingly.
- [`Inertia.Controller`](https://hexdocs.pm/inertia/Inertia.Controller.html): controller functions for rendering Inertia.js-compatible responses.
- [`Inertia.HTML`](https://hexdocs.pm/inertia/Inertia.HTML.html): HTML components for Inertia-powered views.

To get started, import `Inertia.Controller` in your controller helper and `Inertia.HTML` in your html helper:

```diff
  # lib/my_app_web.ex
  defmodule MyAppWeb do
    def controller do
      quote do
        use Phoenix.Controller, namespace: MyAppWeb

+       import Inertia.Controller
      end
    end

    def html do
      quote do
        use Phoenix.Component

+       import Inertia.HTML
      end
    end
  end
```

Then, install the plug in your browser pipeline:

```diff
  # lib/my_app_web/router.ex
  defmodule MyAppWeb.Router do
    use MyAppWeb, :router

    pipeline :browser do
      plug :accepts, ["html"]

+     plug Inertia.Plug
    end
  end
```

Next, replace the title tag in your layout with the `<.inertia_title>` component, so that the client-side library will keep the title in sync, and add the `<.inertia_head>` component:

```diff
  # lib/my_app_web/components/layouts/root.html.heex
  <!DOCTYPE html>
  <html lang="en" class="[scrollbar-gutter:stable]">
    <head>
-     <.live_title>{@page_title}</.live_title>
+     <.inertia_title>{@page_title}</.inertia_title>
+     <.inertia_head content={@inertia_head} />
    </head>
```

You're now ready to start rendering inertia responses!

## Rendering responses

Rendering an Inertia.js response looks like this:

```elixir
defmodule MyAppWeb.ProfileController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    conn
    |> assign_prop(:text, "Hello world")
    |> render_inertia("ProfilePage")
  end
end
```

The `assign_prop` function allows you to define props that should be passed in to the component. The `render_inertia` function accepts the conn, the name of the component to render, and an optional map containing more initial props to pass to the page component.

This action will render an HTML page containing a `<div>` element with the name of the component and the initial props, following Inertia.js conventions. On subsequent requests dispatched by the Inertia.js client library, this action will return a JSON response with the data necessary for rendering the page.

If you want to automatically convert your prop keys from snake case (conventional in Elixir) to camel case to keep with JavaScript conventions (e.g. `first_name` to `firstName`), you can configure that globally or enable/disable it on a per-request basis.

```elixir
import Config

config :inertia,
  endpoint: MyAppWeb.Endpoint,
  camelize_props: true
```

```elixir
defmodule MyAppWeb.ProfileController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    conn
    |> assign_prop(:first_name, "Bob")
    |> camelize_props()
    |> render_inertia("ProfilePage")
  end
end
```

## Setting up the client-side

Inertia needs a small JavaScript entry point that boots your front-end framework
and resolves your page components. The
[Inertia.js docs](https://inertiajs.com/client-side-setup) are a good general
introduction to how that works.

The quickest way to set it up is the [Igniter installer](#using-igniter), which
scaffolds the entry point, the esbuild build, and a starter page for your chosen
framework:

```sh
mix inertia.install --client-framework [react|vue|svelte]
```

To wire things up by hand — or to understand what the installer generates —
follow the guide for your framework. They all use Phoenix's default **esbuild**
pipeline:

- [React](guides/esbuild/react.md) — the simple case; keeps the standard `esbuild` Hex package.
- [Svelte](guides/esbuild/svelte.md) — Node-driven esbuild with the `esbuild-svelte` plugin.
- [Vue](guides/esbuild/vue.md) — Node-driven esbuild with the `unplugin-vue` plugin.

> #### Note {: .info}
>
> These guides target Phoenix's default esbuild pipeline. The Vue and Svelte
> ecosystems now lean on Vite, and Inertia's own
> [client-side setup docs](https://inertiajs.com/client-side-setup) assume it; if
> you want the most ecosystem-standard toolchain, set up Vite instead.

## Lazy data evaluation

If you have expensive data for your props that may not always be required (that is, if you plan to use [partial reloads](https://inertiajs.com/partial-reloads)), you can wrap your expensive computation in a function and pass the function reference when setting your Inertia props. You may use either an anonymous function (or named function reference) and optionally wrap it with the `Inertia.Controller.inertia_optional/1` function.

> #### Note {: .info}
>
> `inertia_optional` props will _only_ be included the when explicitly requested in a partial
> reload. If you want to include the prop on first visit, you'll want to use a
> bare anonymous function or named function reference instead. See below for
> examples of how prop assignment behaves.

Here are some specific examples of how the methods of lazy data evaluation differ:

```elixir
conn
# ALWAYS included on first visit...
# OPTIONALLY included on partial reloads...
# ALWAYS evaluated...
|> assign_prop(:cheap_thing, cheap_thing())

# ALWAYS included on first visit...
# OPTIONALLY included on partial reloads...
# ONLY evaluated when needed...
|> assign_prop(:expensive_thing, fn -> calculate_thing() end)
|> assign_prop(:another_expensive_thing, &calculate_another_thing/0)

# NEVER included on first visit...
# OPTIONALLY included on partial reloads...
# ONLY evaluated when needed...
|> assign_prop(:super_expensive_thing, inertia_optional(fn -> calculate_thing() end))
```

## Deferred props

**Requires Inertia v2.x or later on the client-side**.

If you have expensive data that you'd like to automatically fetch (from the client-side via an async background request) after the page is initially rendered, you can mark the prop as deferred:

```elixir
conn
|> assign_prop(:expensive_thing, inertia_defer(fn -> calculate_thing() end))
```

The `inertia_defer/1` helper accepts a function argument in the first position. You may optionally use the `inertia_defer/2` helper, which accepts a "group" name in the second position:

```elixir
conn
|> assign_prop(:expensive_thing, inertia_defer(fn -> calculate_thing() end, "dashboard"))
```

If no group names are specified, then the client-side will issue a single async request to fetch all the deferred props. If there are multiple group names, then the client-side will issue one async request per group instead. This is useful if you have some very expensive data that you'd prefer fetch in parallel alongside other expensive data.

### Graceful failure with `on_error: :ignore`

By default, if a deferred prop's resolver raises while the client is fetching its group, the error propagates and the partial reload fails. Pass `on_error: :ignore` to degrade gracefully instead: the error is contained, the prop is omitted from the response, and its path is reported in the `rescuedProps` page metadata so the client can render a fallback.

```elixir
conn
|> assign_prop(:stats, inertia_defer(fn -> expensive_stats() end, on_error: :ignore))

# With a custom group
|> assign_prop(:stats, inertia_defer(fn -> expensive_stats() end, "dashboard", on_error: :ignore))
```

Rescued failures are logged and emit a `[:inertia, :deferred_prop, :rescue]` telemetry event with the following metadata, so you can report them to your error tracker:

```elixir
:telemetry.attach("inertia-rescue", [:inertia, :deferred_prop, :rescue], fn _event, _measurements, metadata, _config ->
  # metadata: %{prop: "stats", kind: :error | :throw | :exit, reason: term(), stacktrace: [...]}
  MyApp.ErrorReporter.report(metadata)
end, nil)
```

## Merge props

**Requires Inertia v2.x or later on the client-side**.

If you have prop data that should get merged with the existing data on the client-side on subsequent requests (for example, an array of paginated data being presented in an "infinite scroll" interface), then you can tag the prop value using the `inertia_merge/1` helper:

```elixir
conn
|> assign_prop(:paginated_list, inertia_merge(["a", "b", "c"]))
```

Merge props can also accept deferred props:

```elixir
conn
|> assign_prop(:paginated_list, inertia_defer(&calculate_next_page/0) |> inertia_merge())
```

If you are working with complex data structures or nested objects you can use `inertia_deep_merge(value)`

```elixir
conn
|> assign_prop(:complex_object, inertia_deep_merge(%{a: %{b: %{c: %{d: 1}}}}))
```

### Deduplication with `match_on`

When merging list data, you can provide a `match_on` key to enable client-side deduplication of items. This is useful for infinite scroll interfaces where the same item might appear in multiple pages of data:

```elixir
conn
|> assign_prop(:users, inertia_merge(users, match_on: "id"))
```

The `match_on` option is also supported by `inertia_prepend/2` and `inertia_deep_merge/2`. The key is included in the `matchPropsOn` metadata in the page response.

You can match on multiple keys by passing a list, and each key may be a dot-path into the merged items:

```elixir
conn
|> assign_prop(:users, inertia_merge(users, match_on: ["id", "email"]))
```

## Prepend props

If you want merged data to be prepended (instead of appended) to the existing client-side data, use `inertia_prepend/1`:

```elixir
conn
|> assign_prop(:messages, inertia_prepend(new_messages))
```

Prepend props appear in both `mergeProps` and `prependProps` in the page response. This is useful for scenarios like chat interfaces where new messages should appear at the top.

Like `inertia_merge`, prepend props also support the `match_on` option for deduplication:

```elixir
conn
|> assign_prop(:messages, inertia_prepend(new_messages, match_on: "id"))
```

## Once props

**Requires Inertia v2.x or later on the client-side**.

Some data rarely changes, is expensive to compute, or is simply large. Rather than including this data in every response, you can use once props. These props are cached on the client-side and reused on subsequent pages that include the same prop, making them ideal for shared data like user roles or configuration.

```elixir
conn
|> assign_prop(:plans, inertia_once(fn -> Plans.list_all() end))
```

The client will remember the prop value and reuse it on subsequent page visits. Navigating to a page without the once prop will clear the cached value.

### Forcing a refresh

You can force a once prop to be refreshed using the `fresh` option:

```elixir
conn
|> assign_prop(:plans, inertia_once(fn -> Plans.list_all() end, fresh: true))
```

This also accepts a boolean condition:

```elixir
conn
|> assign_prop(:plans, inertia_once(fn -> Plans.list_all() end, fresh: plans_changed?))
```

### Expiration

You can set an expiration time using the `until` option. This accepts a `DateTime` or an integer representing seconds from now:

```elixir
conn
# Expires in 1 hour
|> assign_prop(:rates, inertia_once(fn -> ExchangeRates.current() end, until: 3600))

# Expires at a specific time
|> assign_prop(:rates, inertia_once(fn -> ExchangeRates.current() end,
  until: DateTime.utc_now() |> DateTime.add(1, :day)
))
```

### Custom keys

You can assign a custom key using the `as` option. This is useful when you want to share data across multiple pages with different prop names:

```elixir
# Team member list page
conn
|> assign_prop(:member_roles, inertia_once(fn -> Roles.list_all() end, as: "roles"))

# Invite form page
conn
|> assign_prop(:available_roles, inertia_once(fn -> Roles.list_all() end, as: "roles"))
```

Both pages share the same cached data because they use the same custom key.

### Combining with other prop types

Once props can be combined with deferred, merge, and optional props:

```elixir
conn
# Deferred + once: loaded after initial render, then cached
|> assign_prop(:permissions, inertia_once(inertia_defer(fn -> Permissions.for_user(user) end)))

# Merge + once: merged with existing data and cached
|> assign_prop(:activity, inertia_once(inertia_merge(fn -> Activity.recent(user) end)))
```

## Scroll props

**Requires Inertia v2.x or later on the client-side**.

For infinite scroll pagination, you can use `inertia_scroll/1` to wrap paginated data. This automatically configures merge behavior so new data is appended to existing content, and extracts pagination metadata for the client-side `<InfiniteScroll>` component.

```elixir
conn
|> assign_prop(:users, inertia_scroll(paginated_users))
|> render_inertia("Users/Index")
```

`inertia_scroll` accepts a few shapes of paginated data:

- A struct from a [supported pagination library](#pagination-libraries) (e.g. `Scrivener.Page`)
- A `{entries, meta}` tuple (e.g. Flop's `{records, %Flop.Meta{}}`)
- A plain map with the entries under the wrapper key (default `data`) and a `meta` map:

```elixir
%{
  data: [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}],
  meta: %{
    current_page: 1,
    next_page: 2,
    previous_page: nil,
    page_name: "page"  # optional, defaults to "page"
  }
}
```

In every case the entries are placed under the wrapper key, producing a uniformly-shaped response:

- The entries in `props` under the wrapper key
- The data path (e.g., `"users.data"`) added to `mergeProps`
- Pagination metadata in `scrollProps`

```json
{
  "props": {
    "users": {
      "data": [...]
    }
  },
  "mergeProps": ["users.data"],
  "scrollProps": {
    "users": {
      "pageName": "page",
      "currentPage": 1,
      "previousPage": null,
      "nextPage": 2
    }
  }
}
```

> #### Note {: .info}
>
> Pagination metadata is surfaced via `scrollProps`, so it is not echoed in the prop value by default — only the entries under the wrapper key are kept. (If you pass the plain `%{data:, meta:}` map, the `meta` key is dropped from the rendered prop.) To surface extra data to the page alongside the entries, use the [`:meta` option](#including-extra-metadata-in-the-prop).

### Options

The `inertia_scroll/2` function accepts the following options:

- `:wrapper` - The key the data items are placed under (default: `"data"`)
- `:page_name` - Override the page query parameter name
- `:scroll_metadata` - Custom metadata extraction function for `scrollProps`, the pagination state the client component uses (receives the original value; a per-call override of the `Inertia.Paginated` protocol)
- `:transform` - A 1-arity function applied to each entry before serialization (see [Serializing entries](#serializing-entries))
- `:meta` - A 1-arity function whose returned map is placed under a `"meta"` key in the prop, alongside the entries (see [Including extra metadata in the prop](#including-extra-metadata-in-the-prop))

```elixir
# Custom wrapper key (for data structures that use "items" instead of "data")
conn
|> assign_prop(:users, inertia_scroll(data, wrapper: "items"))

# Custom page name for multiple scroll containers on one page
conn
|> assign_prop(:users, inertia_scroll(users, page_name: "users_page"))
|> assign_prop(:orders, inertia_scroll(orders, page_name: "orders_page"))
```

### Lazy evaluation

Like other prop helpers, `inertia_scroll` supports lazy evaluation with functions:

```elixir
conn
|> assign_prop(:users, inertia_scroll(fn -> User.paginate(params) end))
```

### Pagination libraries

`inertia_scroll` has first-party support for popular pagination libraries. When given a recognized pagination result, it pulls out the entries, places them under the `:wrapper` key (default `"data"`), and extracts the pagination metadata — so the prop is uniformly shaped regardless of which library you use.

[Scrivener](https://hex.pm/packages/scrivener) returns a `Scrivener.Page` struct, which you can pass directly:

```elixir
conn
|> assign_prop(:users, inertia_scroll(MyApp.Repo.paginate(query)))
|> render_inertia("Users/Index")
```

[Flop](https://hex.pm/packages/flop) returns a `{records, %Flop.Meta{}}` tuple, which you can also pass directly:

```elixir
conn
|> assign_prop(:users, inertia_scroll(Flop.run(query, params)))
|> render_inertia("Users/Index")
```

In both cases the entries end up under `props.users.data` and `"users.data"` is added to `mergeProps`.

> #### Note {: .info}
>
> Flop's page query parameter is assumed to be `"page"`; override it with `:page_name` if you've configured a different name. Cursor-based Flop pagination (which uses `:after`/`:before` cursors rather than page numbers) is not supported out of the box — provide a custom `:scroll_metadata` function for that case.

### Serializing entries

By default, each entry is serialized by your JSON library (e.g. via a `Jason.Encoder` implementation on your schema). If you'd rather shape entries into a prop-friendly form explicitly, pass a `:transform` function — it's applied to each entry before serialization:

```elixir
conn
|> assign_prop(:users, inertia_scroll(Flop.run(query, params),
  transform: fn user -> %{id: user.id, name: user.name} end
))
```

### Including extra metadata in the prop

The scroll prop holds only the entries by default. If your page needs additional pagination data (totals, etc.), pass a `:meta` function — its returned map is placed under a `"meta"` key alongside the entries:

```elixir
conn
|> assign_prop(:users, inertia_scroll(Flop.run(query, params),
  meta: fn {_records, meta} -> %{total: meta.total_count, pages: meta.total_pages} end
))

# => %{users: %{data: [...], meta: %{total: 42, pages: 5}}}
```

The function receives the original value (e.g. the `{records, meta}` tuple for Flop, or the `Scrivener.Page` struct), so you can surface whatever your paginator exposes. This is independent of `scrollProps` (which drives the `<InfiniteScroll>` component) — use `:meta` for data the page itself renders.

### Custom scroll metadata

For a one-off pagination shape without first-party support (or to override an existing one), provide a `:scroll_metadata` function — a per-call alternative to implementing the [`Inertia.Paginated` protocol](#the-inertiapaginated-protocol). It produces the `scrollProps` the client component uses:

```elixir
conn
|> assign_prop(:users, inertia_scroll(page,
  wrapper: "entries",
  scroll_metadata: fn page ->
    %{
      page_name: "page",
      current_page: page.page_number,
      previous_page: if(page.page_number > 1, do: page.page_number - 1),
      next_page: if(page.page_number < page.total_pages, do: page.page_number + 1)
    }
  end
))
```

> #### Note {: .info}
>
> `:scroll_metadata` drives `scrollProps` (the paging state the `<InfiniteScroll>` component reads). Don't confuse it with [`:meta`](#including-extra-metadata-in-the-prop), which adds display data to the prop value itself.

### The `Inertia.Paginated` protocol

To add reusable support for another pagination library, implement the `Inertia.Paginated` protocol. Its `to_scroll/1` returns a metadata map; omitted keys fall back to defaults (`page_name` defaults to `"page"`; the rest to `nil`).

For libraries whose struct **carries its own entries** (like `Scrivener.Page`), include an `:entries` key:

```elixir
defimpl Inertia.Paginated, for: MyPaginator.Page do
  def to_scroll(%{entries: entries, page_number: page, total_pages: total}) do
    %{
      entries: entries,
      current_page: page,
      previous_page: if(page > 1, do: page - 1),
      next_page: if(page < total, do: page + 1)
    }
  end
end

# used as: inertia_scroll(page)
```

For libraries that return entries **separately** from their metadata (like Flop's `{records, meta}` tuple), implement the protocol for the metadata struct and **omit** `:entries` — the entries come from the tuple you pass to `inertia_scroll`:

```elixir
defimpl Inertia.Paginated, for: MyPaginator.Meta do
  def to_scroll(meta) do
    %{
      current_page: meta.current_page,
      previous_page: meta.previous_page,
      next_page: meta.next_page
    }
  end
end

# used as: inertia_scroll({entries, meta})
```

## Shared data

To share data on every request, you can use the `assign_shared_prop/3` function inside of a shared plug in your response pipeline. This marks the prop as "shared", which tells the Inertia.js client which props are set globally so it can carry them forward optimistically during instant visits.

For example, suppose you have a `UserAuth` plug responsible for fetching the currently-logged in user and you want to be sure all your Inertia components receive that user data. Your plug might look something like this:

```elixir
defmodule MyApp.UserAuth do
  import Inertia.Controller
  import Phoenix.Controller
  import Plug.Conn

  def authenticate_user(conn, _opts) do
    user = get_user_from_session(conn)

    conn
    |> assign(:user, user)
    |> assign_shared_prop(:user, serialize_user(user))
  end

  # ...
end
```

Anywhere this plug is used, the serialized `user` prop will be passed to the Inertia component, and the key `"user"` will appear in the `sharedProps` array in the page response.

You can also use `inertia_share/1` to mark a prop as shared when using inline prop maps:

```elixir
conn
|> render_inertia("Home", %{
  current_user: inertia_share(serialize_user(user)),
  other: "value"
})
```

Shared props are composable with other prop types like `inertia_merge/1` and `inertia_defer/1`:

```elixir
conn
|> assign_shared_prop(:notifications, inertia_merge(notifications))
|> assign_shared_prop(:permissions, inertia_defer(fn -> fetch_permissions() end))
```

> #### Note {: .info}
>
> You can still use `assign_prop/3` for shared data if you don't need the `sharedProps` metadata.
> The `assign_shared_prop/3` function is a convenience wrapper that additionally tags the prop
> for inclusion in the `sharedProps` page metadata.

## Validations

Validation errors follow some specific conventions to make wiring up with Inertia's form helpers seamless. The `errors` prop is managed by this library and is always included in the props object for Inertia components. (When there are no errors, the `errors` prop will be an empty object).

The `assign_errors` function is how you tell Inertia what errors should be represented on the front-end. By default, you can either pass an `Ecto.Changeset` struct or a bare map to the `assign_errors` function. For other error data types, you may implement the `Inertia.Errors` protocol (see the `Inertia.Errors` module docs for more information).

> #### Note {: .info}
>
> `Ecto.Changeset` support requires the optional [`ecto`](https://hex.pm/packages/ecto) dependency. Most Phoenix apps already depend on it; if yours doesn't (and you want to pass changesets to `assign_errors`), add `{:ecto, "~> 3.10"}` to your deps. Bare error maps work without Ecto.

```elixir
def update(conn, params) do
  case MyApp.Settings.update(params) do
    {:ok, _settings} ->
      conn
      |> put_flash(:info, "Settings updated")
      |> redirect(to: ~p"/settings")

    {:error, changeset} ->
      conn
      |> assign_errors(changeset)
      |> redirect(to: ~p"/settings")
  end
end
```

The `assign_errors` function will automatically convert the changeset errors into a shape compatible with the client-side adapter. Since Inertia.js expects a flat map of key-value pairs, the error serializer will flatten nested errors down to compound keys:

```javascript
{
  "name" => "can't be blank",

  // Nested errors keys are flattened with a dot separator (`.`)
  "team.name" => "must be at least 3 characters long",

  // Nested arrays are zero-based and indexed using bracket notation (`[0]`)
  "items[1].price" => "must be greater than 0"
}
```

Errors are automatically preserved across redirects, so you can safely respond with a redirect back to page where the form lives to display form errors.

If you need to construct your own map of errors (rather than pass in a changeset), be sure it's a flat mapping of atom (or string) keys to string values like this:

```elixir
conn
|> assign_errors(%{
  name: "Name can't be blank",
  password: "Password must be at least 5 characters"
})
```

## Flash messages

This library automatically includes Phoenix flash data in the Inertia page object as a top-level `flash` key (alongside `component`, `props`, `url`, and `version`).

For example, given the following controller action:

```elixir
def update(conn, params) do
  case MyApp.Settings.update(params) do
    {:ok, _settings} ->
      conn
      |> put_flash(:info, "Settings updated")
      |> redirect(to: ~p"/settings")

    {:error, changeset} ->
      conn
      |> assign_errors(changeset)
      |> redirect(to: ~p"/settings")
  end
end
```

When Inertia (or the browser) redirects to the `/settings` page, the Inertia component will receive the flash data:

```javascript
{
  "component": "...",
  "props": {
    // ...
  },
  "flash": {
    "info": "Settings updated"
  }
}
```

On the client-side, you can access flash data via `usePage().flash`.

## CSRF protection

This library automatically sets the `XSRF-TOKEN` cookie on each response. Inertia's built-in HTTP client reads this cookie and forwards the value on subsequent requests, but it sends it via the `X-XSRF-TOKEN` header by default. Since Phoenix expects to receive the CSRF token via the `x-csrf-token` header, override the header name when initializing your Inertia app:

```javascript
// assets/js/app.js

createInertiaApp({
  http: {
    xsrfHeaderName: "x-csrf-token",
  },
  // the rest of your Inertia client setup...
})
```

## History

**Requires Inertia v2.x or later on the client-side**.

### Encryption

If your page props contain sensitive data (such as information about the currently-authenticated user), you can opt to encrypt the history data that's cached in the browser.

```elixir
conn
|> encrypt_history()
```

You can also enable history encryption globally in your application config:

```elixir
config :inertia,
  history: [encrypt: true]
```

### Clearing history

To instruct the client to clear this history (for example, when a user logs out), you can use the `clear_history/1` helper when building your response.

```elixir
conn
|> clear_history()
```

## Testing

The `Inertia.Testing` module includes helpers for testing your Inertia controller responses. The following helpers are available:

| Helper                     | Description                                       |
| -------------------------- | ------------------------------------------------- |
| `inertia_component/1`      | Returns the component name                        |
| `inertia_props/1`          | Returns the props map                             |
| `inertia_errors/1`         | Returns validation errors (from props or session) |
| `inertia_flash/1`          | Returns the flash map                             |
| `inertia_page/1`           | Returns the full page object                      |
| `inertia_shared_props/1`   | Returns shared prop keys                          |
| `inertia_deferred_props/1` | Returns deferred prop groups                      |
| `inertia_merge_props/1`    | Returns merge prop paths                          |
| `inertia_scroll_props/1`   | Returns scroll pagination metadata                |
| `inertia_once_props/1`     | Returns once prop metadata                        |

```elixir
use MyAppWeb.ConnCase

import Inertia.Testing

describe "GET /" do
  test "renders the home page", %{conn: conn} do
    conn = get("/")
    assert inertia_component(conn) == "Home"
    assert %{user: %{id: 1}} = inertia_props(conn)
    assert inertia_flash(conn) == %{}
  end
end
```

```elixir
use MyAppWeb.ConnCase

import Inertia.Testing

describe "POST /users" do
  test "fails when name empty", %{conn: conn} do
    conn = post("/users", %{"name" => ""})

    assert redirected_to(conn) == ~p"/users"
    assert inertia_errors(conn) == %{"name" => "can't be blank"}
  end
end
```

We recommend importing `Inertia.Testing` in your `ConnCase` helper, so that it will be at the ready for all your controller tests:

```elixir
defmodule MyApp.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Inertia.Testing

      # ...
    end
  end
end
```

## Server-side rendering

The Inertia.js client library comes with with server-side rendering (SSR) support, which means you can have your Inertia-powered client hydrate HTML that has been pre-rendered on the server (instead of performing the initial DOM rendering).

> #### Note {: .info}
>
> The steps for enabling SSR in Phoenix are similar to other backend frameworks, but instead of running a separate Node.js server process to render HTML, this library spins up a pool of Node.js process workers to handle SSR calls and manages the state of those node processes from your Elixir process tree.

SSR has two parts: a framework-specific **server entry point** (`ssr.js`) plus the build step that compiles it to `priv/ssr.js`, and the **`Inertia.SSR` machinery** that runs it. The entry point and build are covered in your framework's guide:

- [React](guides/esbuild/react.md#server-side-rendering)
- [Svelte](guides/esbuild/svelte.md#server-side-rendering)
- [Vue](guides/esbuild/vue.md#server-side-rendering)

The rest of this section covers the machinery, which is the same regardless of framework.

### Configuring your app for server-rendering

Now that you have a Node.js module capable of server-rendering your pages, youll need to tell the Inertia.js Phoenix library to perform SSR.

The default SSR adapter uses the [`nodejs`](https://hex.pm/packages/nodejs) package, which is an optional dependency. Add it to your deps:

```elixir
def deps do
  [
    {:inertia, "~> 3.0"},
    {:nodejs, "~> 3.0"}
  ]
end
```

(If you supply a custom `:ssr_adapter`, e.g. for Bun or a Vite dev server, you don't need `nodejs`.)

First, add the `Inertia.SSR` module to your application's supervision tree.

```diff
  # lib/my_app/application.ex

  defmodule MyApp.Application do
    use Application

    @impl true
    def start(_type, _args) do
      children = [
        MyAppWeb.Telemetry,
        MyApp.Repo,
        {DNSCluster, query: Application.get_env(:MyApp, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: MyApp.PubSub},
        # Start the Finch HTTP client for sending emails
        {Finch, name: MyApp.Finch},
        # Start a worker by calling: MyApp.Worker.start_link(arg)
        # {MyApp.Worker, arg},

+       # Start the SSR process pool
+       # You must specify a `path` option to locate the directory where the `ssr.js` file lives.
+       {Inertia.SSR, path: Path.join([Application.app_dir(:my_app), "priv"])},

        # Start to serve requests, typically the last entry
        MyAppWeb.Endpoint,
      ]
```

Then, update your config to enable SSR (if you'd like to enable it globally).

```diff
  # config/config.exs

  config :inertia,
    # The Phoenix Endpoint module for your application. This is used for building
    # asset URLs to compute a unique version hash to track when something has
    # changed (and a reload is required on the frontend).
    endpoint: MyAppWeb.Endpoint,

    # An optional list of static file paths to track for changes. You'll generally
    # want to include any JavaScript assets that may require a page refresh when
    # modified.
    static_paths: ["/assets/js/app.js"],

    # The default version string to use (if you decide not to track any static
    # assets using the `static_paths` config). Defaults to "1".
    default_version: "1",

    # Enable server-side rendering for page responses (requires some additional setup,
    # see instructions below). Defaults to `false`.
-   ssr: false
+   ssr: true

    # Whether to raise an exception when server-side rendering fails (only applies
    # when SSR is enabled). Defaults to `true`.
    #
    # Recommended: enable in non-production environments and disable in production,
    # so that SSR failures will not cause 500 errors (but instead will fallback to
    # CSR).
    raise_on_ssr_failure: config_env() != :prod
```

### Using ESM (ECMAScript Modules) on SSR entrypoint

By default this library uses CommonJS modules for SSR. If you want to use ESM (ECMAScript Modules) set `esm: true` in your config.

```elixir
  {Inertia.SSR, path: Path.join([Application.app_dir(:my_app), "priv"]), esm: true},
```

### Custom SSR adapter

By default SSR is performed by invoking a Node.js process. You can plug in a different runtime (Bun, a Vite dev server, etc.) by implementing the `Inertia.SSR.Adapter` behaviour and passing it as the `:ssr_adapter` option to the supervisor:

```elixir
{Inertia.SSR,
  path: Path.join([Application.app_dir(:my_app), "priv"]),
  ssr_adapter: MyApp.SSR.MyAdapter}
```

Any additional options you pass to `Inertia.SSR` are forwarded to the adapter's `init/1` callback, so adapters can define their own configuration keys.

A minimal adapter looks like:

```elixir
defmodule MyApp.SSR.MyAdapter do
  @behaviour Inertia.SSR.Adapter

  @impl true
  def init(opts), do: %{path: Keyword.fetch!(opts, :path)}

  @impl true
  def children(_config), do: []

  @impl true
  def call(page, config) do
    # Render the page and return {:ok, %{"head" => head, "body" => body}}
    # or {:error, message} on failure.
  end
end
```

See `Inertia.SSR.Adapter` for full callback docs.

### Excluding paths from SSR

If you want to disable SSR for certain paths (e.g. pages that don't need SEO or are too expensive to server-render), you can configure `ssr_exclude_paths`:

```elixir
config :inertia,
  ssr: true,
  ssr_exclude_paths: [
    "/admin",             # String prefix: matches /admin, /admin/users, etc.
    ~r/^\/dashboard\//    # Regex: matches /dashboard/stats, /dashboard/reports, etc.
  ]
```

### Installing Node.js in your production

You need to have Node.js installed in your production server environment, so that we can call the SSR script when serving pages. These steps assume you are deploying your application using a Dockerfile and releases.

If you haven't installed node into your runner image, add the following command to your Dockerfile (after the `FROM ${RUNNER_IMAGE}` step).

```diff
  FROM ${RUNNER_IMAGE}

  # install curl (and a few other packages)
  RUN apt-get update -y && \
-     apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates && \
+     apt-get install -y libstdc++6 openssl curl libncurses5 locales ca-certificates && \
      apt-get clean && rm -f /var/lib/apt/lists/*_*

  # install Node.js
+ RUN curl -fsSL https://deb.nodesource.com/setup_x.x | bash - && \
+    apt-get update && \
+    apt-get install -y nodejs

  # ...

  ENV MIX_ENV="prod"

  # ensure node is running in production mode
+ ENV NODE_ENV="production"
```

> #### Important {: .warning}
>
> **Be sure to set `NODE_ENV=production`**, so that the SSR script is cached in memory. Otherwise, your page rendering times will be very slow!

---

Maintained by the team at [SavvyCal](https://savvycal.com)
