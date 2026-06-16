# Inertia.js + React + Phoenix (Vite)

A minimal, runnable reference for using **React** on the front end of a Phoenix
app with Inertia.js, built with **[Vite](https://vite.dev)** (driven by the
[`phoenix_vite`](https://hex.pm/packages/phoenix_vite) package) instead of
Phoenix's default esbuild pipeline.

It was generated with `mix phx.new react --app react_vite --module ReactVite
--no-ecto --no-mailer` (Phoenix 1.8) and then wired up for Inertia + React + Vite
by hand. The app depends on the inertia-phoenix checkout three directories up via
`{:inertia, path: "../../.."}`.

```bash
cd examples/vite/react
mix setup          # deps.get + npm install + vite build (client + SSR)
mix phx.server     # visit http://localhost:4000
```

You should see a React page rendered through Inertia, with working client-side
navigation between `/` and `/about`. The initial load is **server-rendered** and
the client **hydrates** it (view source: the `#app` div already contains markup
with `data-server-rendered="true"`).

> Compare with the esbuild [`react`](../../react) example, which uses the same
> Inertia + React setup but stays on Phoenix's default **esbuild** toolchain.
> The Elixir/Inertia wiring is identical; everything below is about swapping the
> asset build to Vite.

## How Vite fits in

In **development**, Vite runs its own dev server on `:5173` (started as a Phoenix
watcher) while Phoenix serves the app on `:4000`. The root layout loads the
JS/CSS straight from the Vite dev server, so you get Vite's fast HMR. This works
because:

- `config/dev.exs` points the endpoint's `static_url` at `http://localhost:5173`,
  so `static_url(@conn, "/js/app.jsx")` resolves to the dev server.
- `vite.config.mjs` allows CORS from `http://localhost:4000` (the module scripts
  are loaded cross-origin) and sets `server.origin` so code-split chunks resolve
  back to `:5173`.

In **production**, `vite build` writes hashed files plus a manifest to
`priv/static`, and the layout reads that manifest to emit the right `<script>` /
`<link>` tags. `PhoenixVite.cache_static_manifest_latest/1` (in
`config/runtime.exs`) replaces `phx.digest`.

The switch between the two is automatic: `PhoenixVite.Components.assets` checks
whether the endpoint has a `:vite` watcher.

## What's actually required

The complete set of changes relative to a fresh `mix phx.new` app:

**Elixir / Phoenix**

- `mix.exs` — drop the `esbuild`/`tailwind`/`heroicons` Hex deps; add
  `{:inertia, ...}` and `{:phoenix_vite, "~> 0.4.3"}`. The `assets.*` aliases now
  shell out to Vite via `mix phoenix_vite.npm`.
- `config/config.exs` — `config :inertia, ...`; replace the `esbuild`/`tailwind`
  config with `config :phoenix_vite, PhoenixVite.Npm, ...` (the `assets`/`vite`
  npm profiles).
- `config/dev.exs` — `static_url: [host: "localhost", port: 5173]`; replace the
  esbuild/tailwind watchers with `vite`/`ssr` watchers; drop the `priv/static`
  live-reload pattern (Vite handles asset reloads).
- `config/prod.exs` + `config/runtime.exs` — drop `cache_static_manifest`; add
  `cache_static_manifest_latest: PhoenixVite.cache_static_manifest_latest(:react_vite)`.
- `lib/react_vite_web.ex` — `import Inertia.Controller` (controller) and
  `import Inertia.HTML` (html).
- `router.ex` — `plug Inertia.Plug` in the `:browser` pipeline.
- `root.html.heex` — use `<.inertia_title>` / `<.inertia_head>` and the
  `<PhoenixVite.Components.assets>` component (see the React Fast Refresh note
  below).

**Assets (npm + Vite)**

- [`package.json`](assets/package.json) — `@inertiajs/react`, `react`,
  `react-dom`, plus the dev deps `vite`, `@vitejs/plugin-react`,
  `@tailwindcss/vite`, `tailwindcss`, and `phoenix_vite`
  (`file:../deps/phoenix_vite` — the Hex package ships its npm plugin).
- [`vite.config.mjs`](assets/vite.config.mjs) — the React, Tailwind, and
  phoenix_vite plugins, with separate client and SSR build outputs.
- [`assets/js/app.jsx`](assets/js/app.jsx) — the Inertia boot. Pages are resolved
  with Vite's `import.meta.glob`, which code-splits each page into its own chunk.
- [`assets/js/pages/*.jsx`](assets/js/pages) — your page components.

### The React Fast Refresh preamble (development only)

`@vitejs/plugin-react` injects a guard into every module that throws unless a
small **React Refresh preamble** has run first. In an HTML-templated app (no
`index.html` for the plugin to transform) you must add it yourself. See the
`<script>` block in [`root.html.heex`](lib/react_vite_web/components/layouts/root.html.heex):
it imports `/@react-refresh` from the dev server and is rendered only when the
Vite watcher is running. Omitting it gives a blank page and a
`@vitejs/plugin-react can't detect preamble` error in dev.

## Server-side rendering

This example uses **two different SSR runtimes**, selected by environment, both
plugged in through inertia-phoenix's `Inertia.SSR.Adapter` behaviour (added in
[#44](https://github.com/inertiajs/inertia-phoenix/pull/44)):

- **Development** renders through the **running Vite dev server**
  (`ReactVite.SSR.ViteAdapter`) — no separate SSR build.
- **Production** renders through the stock **`Inertia.SSR.NodeJSAdapter`** and a
  pre-built bundle.

Both reuse the same SSR entry, **[`assets/js/ssr.jsx`](assets/js/ssr.jsx)**, which
exports `render(page)` using `ReactDOMServer.renderToString`.

### Development: the Vite dev-server adapter

In dev, the SSR entry is loaded straight from Vite's module graph — the same
graph that powers HMR — so editing `ssr.jsx` or any page is reflected on the next
request with no rebuild and no Phoenix restart.

- **[`assets/vite-plugin-inertia-ssr.mjs`](assets/vite-plugin-inertia-ssr.mjs)** —
  a dev-only Vite plugin that mounts a `/__inertia_ssr` endpoint on the dev
  server. It loads the SSR entry via `server.ssrLoadModule(...)`, calls
  `render(page)`, and returns `{ head, body }` as JSON. `apply: "serve"` makes it
  a no-op for `vite build`.
- **[`lib/react_vite/ssr/vite_adapter.ex`](lib/react_vite/ssr/vite_adapter.ex)** —
  implements `Inertia.SSR.Adapter` by POSTing the page payload to that endpoint
  (using the built-in `:httpc` client, so no extra dep). Its `children/1` is
  empty — the dev server is already running as a Phoenix watcher.
- **[`config/dev.exs`](config/dev.exs)** — sets
  `config :react_vite, :ssr_adapter, ReactVite.SSR.ViteAdapter` and has **no
  `ssr` watcher** (the old `vite build --ssr --watch` is gone). It also sets
  `config :inertia, raise_on_ssr_failure: false`, so a request that beats the dev
  server to startup falls back to CSR instead of raising.

### Production: the Node.js bundle adapter

In prod there is no dev server, so SSR uses the default Node pool and a
self-contained bundle:

- **[`vite.config.mjs`](assets/vite.config.mjs)** — the `isSsrBuild` branch builds
  `js/ssr.jsx` into a single **self-contained CommonJS** module at
  `priv/ssr/ssr.cjs` (`ssr.noExternal: true` bundles `react`/`@inertiajs/react`
  in, so the file needs no `node_modules` at runtime). `mix assets.build` runs
  this `--ssr` step.
- **[`lib/react_vite/application.ex`](lib/react_vite/application.ex)** — when
  `:ssr_adapter` is unset (prod/test) it starts
  `{Inertia.SSR, path: ".../priv/ssr", module: "ssr.cjs"}`; when set (dev) it
  starts `{Inertia.SSR, ssr_adapter: ...}`.
- **`config :inertia, ssr: true`** — `config/test.exs` turns it back off so the
  test suite doesn't need either runtime.

Why CommonJS and not ESM for the prod bundle? The Node pool busts its `require`
cache between renders but **caches** dynamic `import()`s. (The companion `.cjs`
extension keeps Node happy even though `package.json` sets `"type": "module"`.)

## Notes / gotchas

- **`phoenix_vite` ≥ 0.4.2** is required: earlier versions only emitted dev
  `<script>` tags for `.js`/`.css`, not `.jsx`, so the entry tag would be missing
  in development.
- This example keeps committed static files (`favicon.ico`, `robots.txt`,
  `images/`) in `priv/static` and sets Vite's `build.emptyOutDir: false` so the
  client build doesn't wipe them. phoenix_vite's installer instead moves those
  into `assets/public`; either approach works.
- The Inertia React pages use inline styles, so `assets/css/app.css` is a minimal
  Tailwind setup included mainly to demonstrate the `@tailwindcss/vite`
  integration.
