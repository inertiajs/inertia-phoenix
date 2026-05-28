# Inertia.js + Svelte + Phoenix (esbuild)

A minimal, runnable reference for using **Svelte** on the front end of a Phoenix
app with Inertia.js, bundled with **esbuild**.

It was generated with `mix phx.new svelte --no-ecto --no-mailer` (Phoenix 1.8)
and then wired up for Inertia + Svelte by hand. The app depends on the
inertia-phoenix checkout three directories up via `{:inertia, path: "../../.."}`.

```bash
cd examples/esbuild/svelte
mix setup          # deps.get + assets.setup + assets.build
mix phx.server     # visit http://localhost:4000
```

You should see a Svelte page rendered through Inertia, with working client-side
navigation between `/` and `/about`.

This example demonstrates both **client-side rendering** and **server-side
rendering** (SSR) — see the [Server-side rendering](#server-side-rendering)
section below.

## Why Svelte needs more than the esbuild CLI

React components written as JS/JSX are the easy case: esbuild bundles them
directly, so the standard
[`esbuild` Hex package](https://github.com/phoenixframework/esbuild) (which runs
the esbuild **CLI**) is enough.

Svelte and Vue are different: their components must be **compiled** to JS first.
For Svelte, that compilation runs as an
[esbuild **plugin**](https://github.com/EMH333/esbuild-svelte), and esbuild
plugins are only available through esbuild's **JS API**, never its CLI
([evanw/esbuild#884](https://github.com/evanw/esbuild/issues/884)). So we can't
use the `esbuild` Hex package for Svelte. Instead we:

1. Install `esbuild` (and `esbuild-svelte`) as npm packages.
2. Drive esbuild from a small Node script, [`assets/esbuild.config.js`](assets/esbuild.config.js).
3. Drop the `esbuild` Hex dependency, its `config :esbuild` block, and point the
   dev watcher / mix aliases at `node esbuild.config.js` instead.

> **Note:** This is the setup for staying on Phoenix's default esbuild pipeline.
> Svelte's ecosystem-standard tooling is now Vite; reach for that if you'd rather
> use the canonical Svelte toolchain.

## What's actually required

The complete set of changes relative to a fresh `mix phx.new` app:

**Elixir / Phoenix**

- `mix.exs` — add `{:inertia, ...}`; **remove** `{:esbuild, ...}`; point the
  `assets.setup` / `assets.build` / `assets.deploy` aliases at
  `cmd --cd assets node esbuild.config.js` (and `npm install`) instead of the
  `esbuild` tasks.
- `config/config.exs` — add `config :inertia, endpoint: ...`; **remove** the
  `config :esbuild` block.
- `config/dev.exs` — replace the `esbuild` watcher with a `node` watcher:
  `node: ["esbuild.config.js", "--watch", cd: Path.expand("../assets", __DIR__)]`.
- `lib/<app>_web.ex` — `import Inertia.Controller` (controller) and
  `import Inertia.HTML` (html).
- `router.ex` — `plug Inertia.Plug` in the `:browser` pipeline.
- `root.html.heex` — use `<.inertia_title>` / `<.inertia_head>` and load the
  bundle as `<script type="module" ... src={~p"/assets/js/app.js"}>`.

**Assets (npm)**

- Dependencies: `svelte`, `@inertiajs/svelte`, `esbuild`, `esbuild-svelte`.
  That's it — type-only TypeScript in `<script lang="ts">` works without a
  preprocessor (esbuild strips the types). `svelte-preprocess` is only needed
  for TS that requires real transpilation (e.g. `enum`s) or another preprocessed
  language.
- [`assets/js/app.js`](assets/js/app.js) — the Inertia boot (Svelte 5 `mount`).
- [`assets/esbuild.config.js`](assets/esbuild.config.js) — the Node build.
- `assets/js/pages/*.svelte` — your page components.

## Two non-obvious gotchas (proven out in this example)

These are easy to get wrong and are the reason a working reference is useful:

1. **`conditions: ["svelte"]` is mandatory, not optional.** `@inertiajs/svelte`'s
   `package.json` only exposes a `svelte` export condition (no `import`/`require`/
   `default`). Without `conditions: ["svelte", "browser"]` (and matching
   `mainFields`) in the esbuild config, esbuild cannot resolve the package at all.

2. **Component CSS is injected, not emitted as a file.** With code splitting on,
   esbuild emits a separate `.css` file per lazily-imported page chunk — and ESM
   dynamic imports never load those sibling stylesheets, so page styles silently
   disappear. Setting `compilerOptions: { css: "injected" }` in the esbuild-svelte
   plugin makes each page bundle inject its own styles at mount time, which is
   correct for a client-rendered SPA and means the root layout needs **no** extra
   `<link rel="stylesheet">`.

## Server-side rendering

With SSR enabled, Phoenix pre-renders the initial page to HTML on the server
(via a pool of Node workers managed by `Inertia.SSR`) and the client then
**hydrates** it. Subsequent navigation is still client-side. View source on a
full-page load and the `#app` div already contains the rendered markup
(`data-server-rendered="true"`); the component's scoped styles are inlined into
the `<head>`.

The SSR-specific pieces, on top of the CSR setup:

- **[`assets/js/ssr.js`](assets/js/ssr.js)** — a second entry point that exports
  `render(page)`, using Svelte 5's `render` from `svelte/server` (aliased to
  avoid clashing with the export name).
- **[`assets/esbuild.config.js`](assets/esbuild.config.js)** — also builds the
  SSR bundle to `priv/ssr.js` (`platform: "node"`, `format: "cjs"`), compiling
  components with `generate: "server"` and `dev: false` (Svelte 5's dev-mode
  server instrumentation errors during SSR).
- **[`assets/js/app.js`](assets/js/app.js)** — drops the custom `setup` so
  `createInertiaApp` hydrates the server-rendered markup automatically (and
  still mounts a fresh app when SSR is off).
- **[`lib/svelte/application.ex`](lib/svelte/application.ex)** — starts
  `{Inertia.SSR, path: ...}`.
- **`config :inertia, ssr: true`** — `config/test.exs` turns it back off so the
  test suite doesn't need the Node pool.

`svelte/server` is part of `svelte`, so SSR needs no extra packages. With
injected CSS, the server render inlines component styles into the `head`, so
there's no companion `ssr.css`.
