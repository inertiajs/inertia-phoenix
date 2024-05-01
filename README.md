# Inertia.js Phoenix Adapter [![Hex Docs](https://img.shields.io/hexpm/v/inertia)](https://hexdocs.pm/inertia/readme.html)

An Elixir/Phoenix adapter for [Inertia.js](https://inertiajs.com/).

## Installation

The package can be installed by adding `inertia` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:inertia, "~> 0.1.0"}
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
  default_version: "1"
```

This library includes a few modules to help render Inertia responses:

- [`Inertia.Plug`](https://github.com/svycal/inertia-phoenix/blob/main/lib/inertia/plug.ex): a plug for detecting Inertia.js requests and preparing the connection accordingly.
- [`Inertia.Controller`](https://github.com/svycal/inertia-phoenix/blob/main/lib/inertia/controller.ex): controller functions for rendering Inertia.js-compatible responses.
- [`Inertia.HTML`](https://github.com/svycal/inertia-phoenix/blob/main/lib/inertia/html.ex): HTML components for Inertia-powered views.

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

Next, replace the title tag in your layout with the `<.inertia_title>` component, so that the client-side library will keep the title in sync:

```diff
  # lib/my_app_web/components/layouts/root.html.heex
  <!DOCTYPE html>
  <html lang="en" class="[scrollbar-gutter:stable]">
    <head>
-     <.live_title><%= assigns[:page_title] %></.live_title>
+     <.inertia_title><%= assigns[:page_title] %></.inertia_title>
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

The `assign_prop` function allows you defined props that should be passed in to the component. The `render_inertia` function accepts the conn, the name of the component to render, and an optional map containing more initial props to pass to the page component.

This action will render an HTML page containing a `<div>` element with the name of the component and the initial props, following Inertia.js conventions. On subsequent requests dispatched by the Inertia.js client library, this action will return a JSON response with the data necessary for rendering the page.

---

Maintained by the team at [SavvyCal](https://savvycal.com)
