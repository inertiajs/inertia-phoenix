# Inertia.js + Vue + Phoenix (esbuild)

A minimal, runnable reference for using **Vue 3** on the front end of a Phoenix
app with Inertia.js, bundled with **esbuild**.

It was generated with `mix phx.new vue --no-ecto --no-mailer` (Phoenix 1.8) and
then wired up for Inertia + Vue by hand. The app depends on the inertia-phoenix
checkout two directories up via `{:inertia, path: "../.."}`.

```bash
cd examples/vue
mix setup          # deps.get + assets.setup + assets.build
mix phx.server     # visit http://localhost:4000
```

You should see a Vue page rendered through Inertia, with working client-side
navigation between `/` and `/about`.

This example demonstrates both **client-side rendering** and **server-side
rendering** (SSR) — see the [Server-side rendering](#server-side-rendering)
section below.

## Why Vue needs a different setup than React

React ships plain JS/JSX that esbuild bundles directly, so the standard
[`esbuild` Hex package](https://github.com/phoenixframework/esbuild) (which runs
the esbuild **CLI**) is enough.

Vue is different: a `.vue` single-file component must be **compiled** to
JavaScript, and that compilation runs as an
[esbuild plugin](https://github.com/unplugin/unplugin-vue). esbuild plugins are
only available through esbuild's **JavaScript API**, never its CLI
([evanw/esbuild#884](https://github.com/evanw/esbuild/issues/884)). So we can't
use the `esbuild` Hex package for Vue. Instead we:

1. Install `esbuild` (and `unplugin-vue`) as npm packages.
2. Drive esbuild from a small Node script, [`assets/esbuild.config.js`](assets/esbuild.config.js).
3. Drop the `esbuild` Hex dependency, its `config :esbuild` block, and point the
   dev watcher / mix aliases at `node esbuild.config.js` instead.

This is the same shape as the [Svelte example](../svelte); the Vue-specific
pieces are the plugin, the boot code, and CSS handling.

> **Note:** This is the setup for staying on Phoenix's default esbuild pipeline.
> Vue's ecosystem-standard tooling is now Vite (`@vitejs/plugin-vue`); reach for
> that if you'd rather use the canonical Vue toolchain.

### About unplugin-vue

`@vitejs/plugin-vue` is the official Vue plugin, but it targets Vite/Rollup, not
raw esbuild. [`unplugin-vue`](https://github.com/unplugin/unplugin-vue) is the
maintained community plugin that supports esbuild and syncs from
`@vitejs/plugin-vue`, which makes it the most defensible choice here. Worth
knowing:

- It is **not** an official Vue package.
- It currently requires **Node >= 20.19.0**.
- It pulls in Vite as an internal dependency, even though the build runs through
  esbuild.
- There's no Vite-style HMR; the dev story is the Phoenix watcher plus
  `phoenix_live_reload`.

## What's actually required

The complete set of changes relative to a fresh `mix phx.new` app:

**Elixir / Phoenix** — identical to the Svelte example: add `{:inertia, ...}`,
remove `{:esbuild, ...}`, repoint the `assets.*` aliases and the dev watcher at
`node esbuild.config.js`, add `config :inertia`, `import Inertia.Controller` /
`import Inertia.HTML`, `plug Inertia.Plug`, and an Inertia root layout.

**Assets (npm)**

- Dependencies: `vue`, `@inertiajs/vue3`, `esbuild`, `unplugin-vue`.
- [`assets/js/app.js`](assets/js/app.js) — the Inertia boot (`createApp` + the
  Inertia `plugin`).
- [`assets/esbuild.config.js`](assets/esbuild.config.js) — the Node build.
- `assets/js/pages/*.vue` — your page components.

## Two Vue-specific gotchas (proven out in this example)

1. **`unplugin-vue` is ESM-only.** Its esbuild entry (`unplugin-vue/esbuild`) is
   shipped as `.mjs`, so a CommonJS `require` won't load it. This config keeps
   the `esbuild.config.js` filename (so it matches the Svelte setup and the
   watcher/aliases) and loads the plugin with a dynamic `import()` instead.

2. **`sourceMap: false` on the plugin.** With sourcemaps enabled, unplugin-vue
   emits an inline CSS sourcemap that esbuild's CSS loader rejects with
   `Unknown word sourceMappingURL`. Disabling the plugin's sourcemaps avoids it;
   esbuild still produces its own bundle sourcemaps.

## A note on component CSS

esbuild bundles the `<style>` blocks from every reachable component into a
single `app.css` next to the JS bundle, which the root layout links. Unlike
Svelte (which can inject component CSS through JS via `css: "injected"`), Vue's
esbuild path emits CSS files — esbuild also writes a redundant per-chunk `.css`
for each page, but the linked `app.css` already contains every component's
styles, so a single `<link>` is all that's needed.

The Vue feature flags (`__VUE_OPTIONS_API__`, etc.) are set via esbuild's
`define` to silence runtime warnings and drop dev-only code in production.

## Server-side rendering

With SSR enabled, Phoenix pre-renders the initial page to HTML on the server
(via a pool of Node workers managed by `Inertia.SSR`) and the client then
**hydrates** it, instead of rendering from an empty `<div id="app">`. Subsequent
navigation is still client-side. You can see it working by viewing source on a
full-page load — the `#app` div already contains the rendered markup
(`data-server-rendered="true"`).

The SSR-specific pieces, on top of the CSR setup:

- **[`assets/js/ssr.js`](assets/js/ssr.js)** — a second entry point that exports
  `render(page)`. It uses `@vue/server-renderer`'s `renderToString` and builds
  the app with `createSSRApp`. (Unlike the Inertia.js docs, there's no
  `createServer` — inertia-phoenix manages the Node workers itself, so we just
  export `render`.)
- **[`assets/esbuild.config.js`](assets/esbuild.config.js)** — also builds the
  SSR bundle to `priv/ssr.js` as a Node/CommonJS module (`platform: "node"`,
  `format: "cjs"`).
- **[`assets/js/app.js`](assets/js/app.js)** — uses `createSSRApp` (not
  `createApp`) so the client hydrates the server-rendered markup.
- **[`lib/vue/application.ex`](lib/vue/application.ex)** — starts
  `{Inertia.SSR, path: ...}` (the Node pool that loads `priv/ssr.js`).
- **[`config/config.exs`](config/config.exs)** — `config :inertia, ssr: true`.
  `config/test.exs` turns it back off so the test suite doesn't need the Node
  pool.

`@vue/server-renderer` doesn't need to be installed separately — it ships as a
dependency of `vue` at the exact same version, and esbuild bundles it into
`priv/ssr.js`.
