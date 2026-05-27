# Inertia.js + React + Phoenix (esbuild)

A minimal, runnable reference for using **React** on the front end of a Phoenix
app with Inertia.js, bundled with **esbuild**.

It was generated with `mix phx.new react --no-ecto --no-mailer` (Phoenix 1.8)
and then wired up for Inertia + React by hand. The app depends on the
inertia-phoenix checkout two directories up via `{:inertia, path: "../.."}`.

```bash
cd examples/react
mix setup          # deps.get + assets.setup (incl. npm install) + assets.build
mix phx.server     # visit http://localhost:4000
```

You should see a React page rendered through Inertia, with working client-side
navigation between `/` and `/about`.

> #### Scope
>
> This covers **client-side rendering only**. SSR is out of scope here.

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
