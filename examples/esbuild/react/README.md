# Inertia.js + React + Phoenix (esbuild)

A minimal, runnable reference for using **React** on the front end of a Phoenix
app with Inertia.js, bundled with **esbuild**.

It was generated with `mix phx.new react --no-ecto --no-mailer` (Phoenix 1.8)
and then wired up for Inertia + React by hand. The app depends on the
inertia-phoenix checkout three directories up via `{:inertia, path: "../../.."}`.

```bash
cd examples/esbuild/react
mix setup          # deps.get + assets.setup (incl. npm install) + assets.build
mix phx.server     # visit http://localhost:4000
```

You should see a React page rendered through Inertia, with working client-side
navigation between `/` and `/about`.

This example demonstrates both **client-side rendering** and **server-side
rendering** (SSR) — see the [Server-side rendering](#server-side-rendering)
section below.

## React is the simple case

Unlike the [Svelte](../svelte) and [Vue](../vue) examples — whose single-file
components need a compiler plugin and therefore a Node-driven esbuild build —
React components are plain JS/JSX that esbuild compiles natively. So this app
keeps Phoenix's default [`esbuild` Hex
package](https://github.com/phoenixframework/esbuild) (the CLI). The only build
changes versus a stock `mix phx.new` app are:

- point esbuild at a `.jsx` entrypoint and enable code splitting
  (`config :esbuild` in `config/config.exs`)
- add `cmd --cd assets npm install` to the `assets.setup` alias, since we now
  have npm dependencies (`@inertiajs/react`, `react`, `react-dom`) that esbuild
  needs to resolve

> **Note:** This is the setup for staying on Phoenix's default esbuild pipeline.
> Inertia's own [client-side docs](https://inertiajs.com/client-side-setup) use
> Vite; reach for that if you'd rather use the canonical Inertia toolchain.

## What's actually required

The complete set of changes relative to a fresh `mix phx.new` app:

**Elixir / Phoenix**

- `mix.exs` — add `{:inertia, ...}`; add `cmd --cd assets npm install` to the
  `assets.setup` alias. The `esbuild` Hex dependency stays.
- `config/config.exs` — add `config :inertia, endpoint: ...`; change the
  `config :esbuild` args to build `js/app.jsx` with `--splitting --format=esm`.
- `lib/<app>_web.ex` — `import Inertia.Controller` (controller) and
  `import Inertia.HTML` (html).
- `router.ex` — `plug Inertia.Plug` in the `:browser` pipeline.
- `root.html.heex` — use `<.inertia_title>` / `<.inertia_head>` and load the
  bundle as `<script type="module" ... src={~p"/assets/js/app.js"}>`.

**Assets (npm)**

- Dependencies: `@inertiajs/react`, `react`, `react-dom`.
- [`assets/js/app.jsx`](assets/js/app.jsx) — the Inertia boot (the esbuild
  entrypoint; the generated `app.js` is removed since it's no longer the entry).
- `assets/js/pages/*.jsx` — your page components.

No esbuild config script or framework plugin is needed — esbuild's built-in JSX
support handles React, and `.tsx` works the same way if you use TypeScript
(install `@types/react` and add a `tsconfig.json` with `"jsx": "react-jsx"`).

## Server-side rendering

With SSR enabled, Phoenix pre-renders the initial page to HTML on the server
(via a pool of Node workers managed by `Inertia.SSR`) and the client then
**hydrates** it. Subsequent navigation is still client-side. View source on a
full-page load and the `#app` div already contains the rendered markup
(`data-server-rendered="true"`).

The SSR-specific pieces, on top of the CSR setup:

- **[`assets/js/ssr.jsx`](assets/js/ssr.jsx)** — a second entry point that
  exports `render(page)` using `ReactDOMServer.renderToString`.
- **[`config/config.exs`](config/config.exs)** — a second `esbuild` profile
  (`ssr`) compiles it to `priv/ssr.js` as a Node/CommonJS module; this profile
  is added to the dev watcher and the `assets.build` / `assets.deploy` aliases.
- **[`assets/js/app.jsx`](assets/js/app.jsx)** — uses `hydrateRoot` (not
  `createRoot`) so the client hydrates the server-rendered markup.
- **[`lib/react/application.ex`](lib/react/application.ex)** — starts
  `{Inertia.SSR, path: ...}` (the Node pool that loads `priv/ssr.js`).
- **`config :inertia, ssr: true`** — `config/test.exs` turns it back off so the
  test suite doesn't need the Node pool.

`ReactDOMServer.renderToString` comes from `react-dom` (already a dependency), so
SSR needs no extra packages. Because React pages here use inline styles rather
than CSS imports, the SSR build emits only `priv/ssr.js` (no companion CSS).
