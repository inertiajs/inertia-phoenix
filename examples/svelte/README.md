# Inertia.js + Svelte + Phoenix (esbuild)

A minimal, runnable reference for using **Svelte** on the front end of a Phoenix
app with Inertia.js, bundled with **esbuild**.

It was generated with `mix phx.new svelte --no-ecto --no-mailer` (Phoenix 1.8)
and then wired up for Inertia + Svelte by hand. The app depends on the
inertia-phoenix checkout two directories up via `{:inertia, path: "../.."}`.

```bash
cd examples/svelte
mix setup          # deps.get + assets.setup + assets.build
mix phx.server     # visit http://localhost:4000
```

You should see a Svelte page rendered through Inertia, with working client-side
navigation between `/` and `/about`.

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

## Scope

This example covers **client-side rendering only**. Server-side rendering (SSR)
for Svelte would need a second bundle and the `Inertia.SSR` node pool, and is out
of scope here.
