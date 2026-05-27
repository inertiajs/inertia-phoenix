# React

This guide walks through configuring a Phoenix + Inertia.js app to render
[React](https://react.dev/) pages, bundled with esbuild. It picks up where the
[client-side setup](readme.html#setting-up-the-client-side) section of the README
leaves off, and it assumes you have already installed and configured the
server-side adapter (the `Inertia.Plug`, `import Inertia.Controller` /
`import Inertia.HTML`, and `config :inertia`).

> #### Scope {: .info}
>
> This guide covers **client-side rendering**. Server-side rendering (SSR) is
> covered in the README's
> [Server-side rendering](readme.html#server-side-rendering) section.

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

If you'd rather not do this by hand, `mix inertia.install --client-framework react`
scaffolds everything below.

## 1. Install the npm packages

From your app's `assets` directory:

```bash
npm install @inertiajs/react react react-dom
```

## 2. Set up the Inertia entry point

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

## 3. Point esbuild at the JSX entrypoint

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

## 4. Load the bundle as an ES module

Code splitting produces ES modules, so the root layout must load the bundle with
`type="module"`. In `lib/my_app_web/components/layouts/root.html.heex`:

```heex
<.inertia_title>{assigns[:page_title]}</.inertia_title>
<.inertia_head content={@inertia_head} />
<link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
<script type="module" defer phx-track-static src={~p"/assets/js/app.js"}>
</script>
```

## 5. Create a page and render it

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

## 6. Build and run

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
