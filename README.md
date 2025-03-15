# Inertia.js Phoenix Adapter [![Hex Package](https://img.shields.io/hexpm/v/inertia)](https://hex.pm/packages/inertia) [![Hex Docs](https://img.shields.io/badge/docs-green)](https://hexdocs.pm/inertia/readme.html)

The official Elixir/Phoenix adapter for [Inertia.js](https://inertiajs.com/).

## Table of Contents

- [Installation](#installation)
- [Rendering responses](#rendering-responses)
- [Setting up the client-side](#setting-up-the-client-side)
- [Lazy data evaluation](#lazy-data-evaluation)
- [Deferred props](#deferred-props)
- [Merge props](#merge-props)
- [Shared data](#shared-data)
- [Validations](#validations)
- [Flash messages](#flash-messages)
- [CSRF protection](#csrf-protection)
- [History](#history)
- [Testing](#testing)
- [Server-side rendering](#server-side-rendering)

## Installation

The package can be installed by adding `inertia` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:inertia, "~> 2.3.0"}
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
  static_paths: ["/assets/app.js"],

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
  raise_on_ssr_failure: config_env() != :prod
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

The [Inertia.js docs](https://inertiajs.com/client-side-setup) provide a good general walk-through on how to setup your JavaScript assets to boot your Inertia app. If you're new to Inertia, we recommend checking that out to familiarize yourself with how it all works. Here we'll provide some guidance on getting your Phoenix app with esbuild configured for basic client-side rendering (and further down, we'll delve into server-side rendering).

To get started, install the Inertia.js library for the frontend framework of your choice. In these instructions we'll use React, but the process is similar for other Inertia-compatible frameworks, like Vue or Svelte.

```
cd assets
npm install @inertiajs/react react react-dom
```

Replace the contents of your `app.js` file with the Inertia boot function and rename it to `app.jsx` (since we are using JSX).

```javascript
// assets/js/app.jsx

import React from "react";
import axios from "axios";

import { createInertiaApp } from "@inertiajs/react";
import { createRoot } from "react-dom/client";

axios.defaults.xsrfHeaderName = "x-csrf-token";

createInertiaApp({
  resolve: async (name) => {
    return await import(`./pages/${name}.jsx`);
  },
  setup({ App, el, props }) {
    createRoot(el).render(<App {...props} />);
  },
});
```

The example above assumes your pages live in the `assets/js/pages` directory and have a default export with page component, like this:

```javascript
// assets/js/pages/Dashboard.jsx

import React from "react";

const Dashboard = () => {
  return (
    <div>
      {/* ... page contents ...*/}
    </div>
  );
}

export default Dashboard;
```

Next, make some adjustments to your esbuild config:

- Ensure the version is >= 0.19.0 (this is required for glob-style imports for your pages)
- Update your entrypoint filename to the correct `.jsx` extension
- Ensure your build `--target` is at least `es2020`

```elixir
# config/config.exs

config :esbuild,
  version: "0.21.5",
  my_app: [
    args: ~w(js/app.jsx --bundle --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
```

If you updated your esbuild version, you'll need to run `mix esbuild.install` to fetch the new version.

Esbuild also supports code-splitting, which can be useful for larger applications. To enable it, you'll need to:

- Set the `format` as [`esm`](https://esbuild.github.io/api/#format-esm)
- Add the [`--splitting`](https://esbuild.github.io/api/#splitting) flag
- Optionally, set the [`chunk-names`](https://esbuild.github.io/api/#chunk-names) flag to customize the output filenames

```diff
  # config/config.exs

  config :esbuild,
    version: "0.21.5",
    my_app: [
-     args: ~w(js/app.jsx --bundle --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
+     args: ~w(js/app.jsx --bundle --chunk-names=chunks/[name]-[hash] --splitting --format=esm --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]
```

After that, we need to update our root layout to load the JavaScript bundle as an ESM module (by changing the `type` attribute from `text/javascript` to `module`):

```diff
  # lib/my_app_web/components/layouts/root.html.eex

-  <script type='text/javascript' defer phx-track-static src={~p"/assets/app.js"}></script>
+  <script type='module' defer phx-track-static src={~p"/assets/app.js"}></script>
```

> [!NOTE]
> ESM code splitting requires modern browser support.
> While most current browsers support ESM modules, you should verify compatibility requirements with your target audience.
> You can read more about how code-splitting works with esbuild in the [official documentation](https://esbuild.github.io/api/#chunk-names).

## Lazy data evaluation

If you have expensive data for your props that may not always be required (that is, if you plan to use [partial reloads](https://inertiajs.com/partial-reloads)), you can wrap your expensive computation in a function and pass the function reference when setting your Inertia props. You may use either an anonymous function (or named function reference) and optionally wrap it with the `Inertia.Controller.inertia_optional/1` function.

> [!NOTE]
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

**Requires Inertia v2.x on the client-side**.

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

## Merge props

**Requires Inertia v2.x on the client-side**.

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

## Shared data

To share data on every request, you can use the `assign_prop/2` function inside of a shared plug in your response pipeline. For example, suppose you have a `UserAuth` plug responsible for fetching the currently-logged in user and you want to be sure all your Inertia components receive that user data. Your plug might look something like this:

```elixir
defmodule MyApp.UserAuth do
  import Inertia.Controller
  import Phoenix.Controller
  import Plug.Conn

  def authenticate_user(conn, _opts) do
    user = get_user_from_session(conn)

    # Here we are storing the user in the conn assigns (so
    # we can use it for things like checking permissions later on),
    # AND we are assigning a serialized represention of the user
    # to our Inertia props.
    conn
    |> assign(:user, user)
    |> assign_prop(:user, serialize_user(user))
  end

  # ...
end
```

Anywhere this plug is used, the serialized `user` prop will be passed to the Inertia component.

## Validations

Validation errors follow some specific conventions to make wiring up with Inertia's form helpers seamless. The `errors` prop is managed by this library and is always included in the props object for Inertia components. (When there are no errors, the `errors` prop will be an empty object).

The `assign_errors` function is how you tell Inertia what errors should be represented on the front-end. By default, you can either pass an `Ecto.Changeset` struct or a bare map to the `assign_errors` function. For other error data types, you may implement the `Inertia.Errors` protocol (see the `Inertia.Errors` module docs for more information).

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

This library automatically includes Phoenix flash data in Inertia props, under the `flash` key.

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

When Inertia (or the browser) redirects to the `/settings` page, the Inertia component will receive the flash props:

```javascript
{
  "component": "...",
  "props": {
    "flash": {
      "info": "Settings updated"
    },
    // ...
  }
}
```

## CSRF protection

This library automatically sets the `XSRF-TOKEN` cookie for use by the Axios client on the front-end. Since Phoenix expects to receive the CSRF token via the `x-csrf-token` header, you'll need to configure Axios in your front-end JavaScript to use that header name:

```javascript
// assets/js/app.js

import axios from "axios";
axios.defaults.xsrfHeaderName = "x-csrf-token";

// the rest of your Inertia client code...
```

## History

**Requires Inertia v2.x on the client-side**.

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

The `Inertia.Testing` module includes helpers for testing your Inertia controller responses, such as the `inertia_component/1` and `inertia_props/1` functions.


```elixir
use MyAppWeb.ConnCase

import Inertia.Testing

describe "GET /" do
  test "renders the home page", %{conn: conn} do
    conn = get("/")
    assert inertia_component(conn) == "Home"
    assert %{user: %{id: 1}} = inertia_props(conn)
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

> [!NOTE]
> The steps for enabling SSR in Phoenix are similar to other backend frameworks, but instead of running a separate Node.js server process to render HTML, this library spins up a pool of Node.js process workers to handle SSR calls and manages the state of those node processes from your Elixir process tree. This is mostly just an implementation detail that you don't need to be concerned about, but we'll highlight how our `ssr.js` script differs from the Inertia.js docs.

### Add a server-side rendering module

You'll need to create a JavaScript module that exports a `render` function to perform the actual server-side rendering of pages. For the purpose of these instructions, we'll assume you're using React. The steps would be similar for other front-end environments supported by Inertia.js, such as [Vue](https://github.com/CallumVass/inertia_vue) and [Svelte](https://github.com/tonydangblog/phoenix-inertia-svelte).

Suppose your main `app.jsx` file looks something like this:

```js
// assets/js/app.jsx

import React from "react";
import { createInertiaApp } from "@inertiajs/react";
import { createRoot } from "react-dom/client";

createInertiaApp({
  resolve: async (name) => {
    return await import(`./pages/${name}.jsx`);
  },
  setup({ App, el, props }) {
    createRoot(el).render(<App {...props} />);
  },
});
```

You'll need to create a second JavaScript file (alongside your `app.jsx`) that exports a `render` function. Let's name it `ssr.jsx`.

```js
// assets/js/ssr.jsx

import React from "react";
import ReactDOMServer from "react-dom/server";
import { createInertiaApp } from "@inertiajs/react";

export function render(page) {
  return createInertiaApp({
    page,
    render: ReactDOMServer.renderToString,
    resolve: async (name) => {
      return await import(`./pages/${name}.jsx`);
    },
    setup: ({ App, props }) => <App {...props} />,
  });
}
```

This is similar to the server entry-point [documented here](https://inertiajs.com/server-side-rendering#add-server-entry-point), except we are simply **exporting a function called `render`**, instead of starting a Node.js server process.

Next, configure esbuild to compile the `ssr.jsx` bundle.

```diff
  # config/config.exs

  config :esbuild,
    version: "0.21.5",
    app: [
      args: ~w(js/app.jsx --bundle --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ],
+   ssr: [
+     args: ~w(js/ssr.jsx --bundle --platform=node --outdir=../priv --format=cjs),
+     cd: Path.expand("../assets", __DIR__),
+     env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
+   ]
```

Add the `ssr` build to the watchers in your dev environment, alongside the other asset watchers:

```diff
  # config/dev.exs
  config :my_app, MyAppWeb.Endpoint,
    # Binding to loopback ipv4 address prevents access from other machines.
    # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
    http: [ip: {127, 0, 0, 1}, port: 4000],
    check_origin: false,
    code_reloader: true,
    debug_errors: true,
    secret_key_base: "4Z2yyTu6Uy8AM+MguG3oldEf4aIdswR2BsCm1OtqDK0lEv++T02KktRaXfMbC/Zs",
    watchers: [
      esbuild: {Esbuild, :install_and_run, [:app, ~w(--sourcemap=inline --watch)]},
+     ssr: {Esbuild, :install_and_run, [:ssr, ~w(--sourcemap=inline --watch)]},
      tailwind: {Tailwind, :install_and_run, [:my_app, ~w(--watch)]}
    ]
```

Add the `ssr` build step to the asset build and deploy scripts.

```diff
  # mix.exs

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
-     "assets.build": ["tailwind app", "esbuild app"],
+     "assets.build": ["tailwind app", "esbuild app", "esbuild ssr"],
      "assets.deploy": [
        "tailwind app --minify",
        "esbuild app --minify",
+       "esbuild ssr",
        "phx.digest"
      ]
    ]
  end
```

As configured, this will place the generated `ssr.js` bundle into the `priv` directory. Since it's generated code, add it to your `.gitignore` file.

```diff
  # .gitignore

+ /priv/ssr.js
```

### Configuring your app for server-rendering

Now that you have a Node.js module capable of server-rendering your pages, youll need to tell the Inertia.js Phoenix library to perform SSR.

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
    static_paths: ["/assets/app.js"],

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

> [!IMPORTANT]
> **Be sure to set `NODE_ENV=production`**, so that the SSR script is cached in memory. Otherwise, your page rendering times will be very slow!

> [!NOTE]
This package supports generating JavaScript files using the **ECMAScript Module (ESM) format**. This is useful if your codebase or environment relies on native ESM imports rather than CommonJS.

```elixir
{Inertia.SSR,
  path: Path.join([Application.app_dir(:my_app), "priv"]),
  esm: true,
  esm_cache_busting: Mix.env() != :prod,
  esm_module_extension: "mjs" # No need to be set. This is the default value.
}
```
`:esm_cache_busting` Useful for forcing reloads of your ssr.js file in environments that use dynamic imports. Defaults to false. In most cases, you’ll want to keep this set to false in production, since the generated JS file doesn't change frequently

`:esm_module_extension` Sets the file extension for the generated ESM module. Defaults to "mjs". You’ll need to configure your JS bundler to output the ssr.js file with the .mjs extension so that Node.js recognizes it as an ESM module.
Alternatively, you can keep the .js extension by passing "js" to the :esm_module_extension option and creating a package.json at the root of your Phoenix project with the following content:

```json
{
  "type": "module"
}
```
This tells Node.js to treat `.js` files as ESM.

### Client side hydration

[Follow the instructions from the Inertia.js docs](https://inertiajs.com/server-side-rendering#client-side-hydration) for updating your client-side code to hydrate the pre-rendered HTML coming from the server.

Using our example React script from above, the adaptation looks like this:

```diff
  // assets/js/app.jsx

  import React from "react";
  import { createInertiaApp } from "@inertiajs/react";
- import { createRoot } from "react-dom/client";
+ import { hydrateRoot } from "react-dom/client";

  createInertiaApp({
    resolve: async (name) => {
      return await import(`./pages/${name}.jsx`);
    },
    setup({ App, el, props }) {
-     createRoot(el).render(<App {...props} />);
+     hydrateRoot(el, <App {...props} />);
    },
  });
```

---

Maintained by the team at [SavvyCal](https://savvycal.com)
