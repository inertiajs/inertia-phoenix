# React

This guide walks through configuring a Phoenix + Inertia.js app to render
[React](https://react.dev/) pages, bundled with esbuild.

> #### Scope {: .info}
>
> The bulk of this guide sets up **client-side rendering**.
> [Server-side rendering](#server-side-rendering) is covered at the end.

## React is the simple case

Svelte and Vue single-file components must be compiled by a framework-specific
esbuild plugin, which forces a Node-driven esbuild build (see those guides).
React is easier: components are plain JS/JSX that esbuild compiles natively, so
you can keep Phoenix's default [`esbuild` Hex
package](https://github.com/phoenixframework/esbuild). You only need to point it
at a `.jsx` entrypoint and enable code splitting.

> #### This is the esbuild path, not the canonical Inertia path {: .info}
>
> Inertia's own documentation uses Vite. React runs cleanly on Phoenix's default
> esbuild pipeline, which is what this guide uses and what stays closest to a
> stock `mix phx.new` app. If you'd rather adopt the canonical Inertia toolchain,
> set up Vite instead.

## Install with Igniter

The [Igniter installer](readme.html#using-igniter) performs every step below for
you — including the server-side wiring — in one command:

```sh
mix inertia.install --client-framework react
```

Pass `--typescript` to set up TypeScript as well. The rest of this guide
documents the same setup by hand.

## Manual setup

These steps assume the server-side adapter is already installed (the
`Inertia.Plug`, the `Inertia.Controller` / `Inertia.HTML` imports, and
`config :inertia`) per the [Installation](readme.html#installation) section.

### 1. Install the npm packages

From your app's `assets` directory:

```bash
npm install @inertiajs/react react react-dom
```

Since esbuild now needs these `node_modules` to bundle, add `npm install` to the
`assets.setup` alias in `mix.exs` so a fresh checkout (or CI) installs them:

```diff
- "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
+ "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing", "cmd --cd assets npm install"],
```

### 2. Set up the Inertia entry point

Rename `assets/js/app.js` to `assets/js/app.jsx` (since it now contains JSX) and
replace its contents with the Inertia boot code:

```javascript
// assets/js/app.jsx
import React from "react";
import { createInertiaApp } from "@inertiajs/react";
import { createRoot } from "react-dom/client";

createInertiaApp({
  resolve: (name) => import(`./pages/${name}.jsx`),
  setup({ el, App, props }) {
    createRoot(el).render(<App {...props} />);
  },
  http: {
    // Phoenix expects the CSRF token via the `x-csrf-token` header. See the
    // CSRF protection section of the README.
    xsrfHeaderName: "x-csrf-token",
  },
});
```

The dynamic import of `./pages/${name}.jsx` tells esbuild to bundle every file
under `assets/js/pages` into its own chunk, so a page name like `"Home"`
resolves to `assets/js/pages/Home.jsx` at runtime.

### 3. Point esbuild at the JSX entrypoint

Update the `config :esbuild` profile to build `app.jsx` instead of `app.js`, and
turn on code splitting so the per-page chunks above are emitted. In
`config/config.exs`:

```diff
  config :esbuild,
    version: "0.25.4",
    my_app: [
      args:
-       ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
+       ~w(js/app.jsx --bundle --chunk-names=chunks/[name]-[hash] --splitting --format=esm --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
    ]
```

- Glob-style page imports require esbuild **>= 0.19**; the Phoenix 1.8 default
  (`0.25.4`) is fine. If you bump the version, run `mix esbuild.install` to fetch
  the new binary.
- `--splitting --format=esm` are what let esbuild emit shared chunks; the
  `--chunk-names` flag just controls their output paths.

### 4. Load the bundle as an ES module

Code splitting produces ES modules, so the root layout must load the bundle with
`type="module"`. In `lib/my_app_web/components/layouts/root.html.heex`:

```heex
<.inertia_title>{assigns[:page_title]}</.inertia_title>
<.inertia_head content={@inertia_head} />
<link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
<script type="module" defer phx-track-static src={~p"/assets/js/app.js"}>
</script>
```

### 5. Create a page and render it

Add a React page at `assets/js/pages/Home.jsx`:

```jsx
import React from "react";

export default function Home({ name }) {
  return <h1>Hello from {name}!</h1>;
}
```

Render it from a controller with `render_inertia/2`:

```elixir
def home(conn, _params) do
  conn
  |> assign_prop(:name, "React")
  |> render_inertia("Home")
end
```

### 6. Build and run

```bash
mix assets.build
mix phx.server
```

Visit your page and you should see the React component rendered through Inertia.

> #### TypeScript {: .tip}
>
> esbuild compiles `.tsx` natively, so TypeScript needs no extra build step —
> just write your pages as `.tsx` and update the esbuild entrypoint/glob
> accordingly. Install `@types/react` for editor support and add a `tsconfig.json`
> with `"jsx": "react-jsx"`.

## Server-side rendering

With SSR, Phoenix pre-renders the initial page to HTML through a pool of Node
workers and the client **hydrates** it, instead of rendering into an empty
`<div id="app">`. Subsequent navigation stays client-side.

The steps below are the React-specific pieces; enabling SSR itself — starting
the `Inertia.SSR` pool and setting `config :inertia, ssr: true` — is covered in
the README's [Server-side rendering](readme.html#server-side-rendering) section.

### 1. Add the SSR entry point

Create a second entry point, `assets/js/ssr.jsx`, that exports a `render`
function. Unlike the Inertia.js docs (which wrap this in a Node server), you
just export `render` — inertia-phoenix manages the Node workers itself:

```jsx
// assets/js/ssr.jsx
import React from "react";
import ReactDOMServer from "react-dom/server";
import { createInertiaApp } from "@inertiajs/react";

export function render(page) {
  return createInertiaApp({
    page,
    render: ReactDOMServer.renderToString,
    resolve: (name) => import(`./pages/${name}.jsx`),
    setup: ({ App, props }) => <App {...props} />,
  });
}
```

### 2. Build the SSR bundle

Add a second `esbuild` profile that compiles `ssr.jsx` to a Node/CommonJS module
at `priv/ssr.js` (the path the `Inertia.SSR` pool loads):

```diff
  config :esbuild,
    version: "0.27.3",
    my_app: [
      args:
        ~w(js/app.jsx --bundle --chunk-names=chunks/[name]-[hash] --splitting --format=esm --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
-   ]
+   ],
+   ssr: [
+     args: ~w(js/ssr.jsx --bundle --platform=node --outdir=../priv --format=cjs --alias:@=.),
+     cd: Path.expand("../assets", __DIR__),
+     env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
+   ]
```

Add the `ssr` build to the dev watcher and the asset aliases so it's built
alongside the client bundle:

```diff
  # config/dev.exs
    watchers: [
      esbuild: {Esbuild, :install_and_run, [:my_app, ~w(--sourcemap=inline --watch)]},
+     ssr: {Esbuild, :install_and_run, [:ssr, ~w(--sourcemap=inline --watch)]},
      tailwind: {Tailwind, :install_and_run, [:my_app, ~w(--watch)]}
    ]
```

```diff
  # mix.exs
-     "assets.build": ["compile", "tailwind my_app", "esbuild my_app"],
+     "assets.build": ["compile", "tailwind my_app", "esbuild my_app", "esbuild ssr"],
      "assets.deploy": [
        "tailwind my_app --minify",
        "esbuild my_app --minify",
+       "esbuild ssr",
        "phx.digest"
      ],
```

`priv/ssr.js` is generated, so add it to your `.gitignore`.

### 3. Hydrate on the client

Switch `assets/js/app.jsx` from `createRoot` to `hydrateRoot` so the client
hydrates the server-rendered markup instead of replacing it:

```diff
- import { createRoot } from "react-dom/client";
+ import { hydrateRoot } from "react-dom/client";

  createInertiaApp({
    resolve: (name) => import(`./pages/${name}.jsx`),
    setup({ el, App, props }) {
-     createRoot(el).render(<App {...props} />);
+     hydrateRoot(el, <App {...props} />);
    },
    // ...
  });
```

### 4. Enable SSR

Start the `Inertia.SSR` pool and set `config :inertia, ssr: true` per the
README's [Server-side rendering](readme.html#server-side-rendering) section.
Disable it in `config/test.exs` (`config :inertia, ssr: false`) so your test
suite doesn't need the Node pool.
