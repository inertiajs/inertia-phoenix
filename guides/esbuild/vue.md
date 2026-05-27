# Setting up Vue with esbuild

This guide walks through configuring a Phoenix + Inertia.js app to render
[Vue 3](https://vuejs.org/) pages, bundled with esbuild. It picks up where the
[client-side setup](readme.html#setting-up-the-client-side) section of the README
leaves off, and it assumes you have already:

- Installed and configured the server-side adapter (the `Inertia.Plug`,
  `import Inertia.Controller` / `import Inertia.HTML`, and `config :inertia`).
- A standard `mix phx.new` app that bundles assets with esbuild.

A complete, runnable version of everything below lives in
[`examples/vue`](https://github.com/inertiajs/inertia-phoenix/tree/main/examples/vue).

> #### Scope {: .info}
>
> This guide covers **client-side rendering**. Server-side rendering (SSR) for
> Vue requires an additional bundle and the `Inertia.SSR` supervisor, and is not
> covered here.

## Why Vue is different from React

React ships JavaScript that esbuild can bundle as-is, so the
[`esbuild` Hex package](https://github.com/phoenixframework/esbuild) — which runs
the esbuild **command-line tool** — is all you need.

Vue is different. A `.vue` single-file component must be **compiled** to
JavaScript first, and that compilation step runs as an
[esbuild plugin](https://github.com/unplugin/unplugin-vue). esbuild plugins are
only available through esbuild's **JavaScript API**, never its CLI
([evanw/esbuild#884](https://github.com/evanw/esbuild/issues/884)).

That single constraint drives the whole setup: instead of the `esbuild` Hex
package, you install esbuild from npm and drive it from a small Node script. The
steps below remove the Hex package and wire Phoenix's watcher and asset aliases
to that script. (If you've seen the [Svelte guide](esbuild_svelte.html), this is the
same shape — only the plugin, the boot code, and CSS handling differ.)

> #### This is the esbuild path, not the canonical Vue path {: .info}
>
> Vue's ecosystem-standard tooling is now Vite (`@vitejs/plugin-vue`). This guide
> keeps you on Phoenix's default **esbuild** pipeline. If you'd rather adopt the
> canonical Vue toolchain, set up Vite instead.

## 1. Install the npm packages

From your app's `assets` directory:

```bash
npm install vue @inertiajs/vue3 esbuild unplugin-vue
```

- `vue` — the framework and its single-file-component compiler.
- `@inertiajs/vue3` — the Inertia client adapter for Vue 3.
- `esbuild` — the bundler, now as a Node dependency.
- `unplugin-vue` — the plugin that compiles `.vue` files during bundling.

> #### About unplugin-vue {: .info}
>
> `@vitejs/plugin-vue` is the official Vue plugin, but it targets Vite/Rollup,
> not raw esbuild. [`unplugin-vue`](https://github.com/unplugin/unplugin-vue) is
> the maintained community plugin that supports esbuild and syncs from
> `@vitejs/plugin-vue`, which makes it the most defensible choice here. A few
> things to know:
>
> - It is **not** an official Vue package.
> - It currently requires **Node >= 20.19.0**.
> - It pulls in Vite as an internal dependency, even though the build still runs
>   through esbuild.
> - There's no Vite-style HMR; the dev story is the Phoenix watcher plus
>   `phoenix_live_reload` doing a full reload on change.

## 2. Add the esbuild build script

Create `assets/esbuild.config.js`:

```javascript
// assets/esbuild.config.js
const esbuild = require("esbuild");

const args = process.argv.slice(2);
const watch = args.includes("--watch");
const deploy = args.includes("--deploy");

async function run() {
  // unplugin-vue ships as ESM only, so load it with a dynamic import.
  const { default: vue } = await import("unplugin-vue/esbuild");

  const options = {
    entryPoints: ["js/app.js"],
    bundle: true,
    format: "esm",
    splitting: true,
    chunkNames: "chunks/[name]-[hash]",
    outdir: "../priv/static/assets/js",
    logLevel: "info",
    target: "es2022",
    external: ["/fonts/*", "/images/*"],
    minify: deploy,
    sourcemap: watch ? "inline" : false,
    // Vue's bundler build reads these compile-time feature flags.
    define: {
      __VUE_OPTIONS_API__: "true",
      __VUE_PROD_DEVTOOLS__: "false",
      __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: "false",
    },
    // sourceMap: false avoids an inline CSS sourcemap that esbuild's CSS loader
    // can't parse ("Unknown word sourceMappingURL").
    plugins: [vue({ sourceMap: false })],
  };

  if (watch) {
    const ctx = await esbuild.context(options);
    await ctx.watch();
    console.log("esbuild: watching for changes...");
  } else {
    await esbuild.build(options);
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
```

Three details here are easy to miss:

- **`unplugin-vue/esbuild` is ESM-only**, so it's loaded with a dynamic
  `import()` from this CommonJS file rather than `require`.
- **`sourceMap: false`** on the plugin — otherwise unplugin-vue emits an inline
  CSS sourcemap that fails the build with `Unknown word sourceMappingURL`.
  esbuild still produces its own bundle sourcemaps via the `sourcemap` option.
- **`define`** sets Vue's compile-time feature flags, which silences runtime
  warnings and drops dev-only code from production builds.

## 3. Set up the Inertia entry point

Replace the contents of `assets/js/app.js` with the Inertia boot code:

```javascript
// assets/js/app.js
import { createInertiaApp } from "@inertiajs/vue3";
import { createApp, h } from "vue";

createInertiaApp({
  resolve: (name) => import(`./pages/${name}.vue`),
  setup({ el, App, props, plugin }) {
    createApp({ render: () => h(App, props) })
      .use(plugin)
      .mount(el);
  },
  http: {
    // Phoenix expects the CSRF token via the `x-csrf-token` header. See the
    // CSRF protection section of the README.
    xsrfHeaderName: "x-csrf-token",
  },
});
```

The dynamic import of `./pages/${name}.vue` tells esbuild to bundle every file
under `assets/js/pages` into its own chunk, so a page name like `"Home"`
resolves to `assets/js/pages/Home.vue` at runtime.

## 4. Remove the esbuild Hex package

Since esbuild now runs from Node, drop the Hex package and its configuration.

In `mix.exs`, remove the `:esbuild` dependency:

```diff
- {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
  {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
```

In `config/config.exs`, remove the entire `config :esbuild` block.

## 5. Point the dev watcher at Node

In `config/dev.exs`, replace the `esbuild` watcher with a `node` watcher:

```diff
  watchers: [
-   esbuild: {Esbuild, :install_and_run, [:my_app, ~w(--sourcemap=inline --watch)]},
+   node: ["esbuild.config.js", "--watch", cd: Path.expand("../assets", __DIR__)],
    tailwind: {Tailwind, :install_and_run, [:my_app, ~w(--watch)]}
  ]
```

## 6. Update the asset mix aliases

In `mix.exs`, point the `assets.*` aliases at the build script (and `npm install`)
instead of the `esbuild` tasks:

```diff
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
-     "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
+     "assets.setup": ["tailwind.install --if-missing", "cmd --cd assets npm install"],
-     "assets.build": ["compile", "tailwind my_app", "esbuild my_app"],
+     "assets.build": ["compile", "tailwind my_app", "cmd --cd assets node esbuild.config.js"],
      "assets.deploy": [
        "tailwind my_app --minify",
-       "esbuild my_app --minify",
+       "cmd --cd assets node esbuild.config.js --deploy",
        "phx.digest"
      ],
      # ...
    ]
  end
```

(Replace `my_app` with your app's name.)

## 7. Load the bundle and component styles

Code splitting produces ES modules, so the root layout must load the bundle with
`type="module"`. esbuild also bundles the `<style>` blocks from your Vue
components into `app.css` next to the JS, so link that too. In
`lib/my_app_web/components/layouts/root.html.heex`:

```heex
<.inertia_title>{assigns[:page_title]}</.inertia_title>
<.inertia_head content={@inertia_head} />
<link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
<link phx-track-static rel="stylesheet" href={~p"/assets/js/app.css"} />
<script type="module" defer phx-track-static src={~p"/assets/js/app.js"}>
</script>
```

## 8. Create a page and render it

Add a Vue page at `assets/js/pages/Home.vue`:

```vue
<script setup>
defineProps({ name: String });
</script>

<template>
  <h1>Hello from {{ name }}!</h1>
</template>
```

Render it from a controller with `render_inertia/2`:

```elixir
def home(conn, _params) do
  conn
  |> assign_prop(:name, "Vue")
  |> render_inertia("Home")
end
```

## 9. Build and run

```bash
mix assets.build
mix phx.server
```

Visit your page and you should see the Vue component rendered through Inertia.
In development, the `node` watcher rebuilds the bundle whenever you edit a
`.vue` file.
