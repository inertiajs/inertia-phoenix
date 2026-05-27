# Setting up Svelte with esbuild

This guide walks through configuring a Phoenix + Inertia.js app to render
[Svelte](https://svelte.dev/) pages, bundled with esbuild. It picks up where the
[client-side setup](readme.html#setting-up-the-client-side) section of the README
leaves off, and it assumes you have already:

- Installed and configured the server-side adapter (the `Inertia.Plug`,
  `import Inertia.Controller` / `import Inertia.HTML`, and `config :inertia`).
- A standard `mix phx.new` app that bundles assets with esbuild.

A complete, runnable version of everything below lives in
[`examples/svelte`](https://github.com/inertiajs/inertia-phoenix/tree/main/examples/svelte).

> #### Scope {: .info}
>
> This guide covers **client-side rendering**. Server-side rendering (SSR) for
> Svelte requires an additional bundle and the `Inertia.SSR` supervisor, and is
> not covered here.

## Why Svelte is different from React and Vue

React and Vue ship JavaScript that esbuild can bundle as-is, so the
[`esbuild` Hex package](https://github.com/phoenixframework/esbuild) — which runs
the esbuild **command-line tool** — is all you need.

Svelte is different. A `.svelte` file must be **compiled** to JavaScript first,
and that compilation step runs as an
[esbuild plugin](https://github.com/EMH333/esbuild-svelte). esbuild plugins are
only available through esbuild's **JavaScript API**, never its CLI
([evanw/esbuild#884](https://github.com/evanw/esbuild/issues/884)).

That single constraint drives the whole setup: instead of the `esbuild` Hex
package, you install esbuild from npm and drive it from a small Node script. The
steps below remove the Hex package and wire Phoenix's watcher and asset aliases
to that script.

## 1. Install the npm packages

From your app's `assets` directory:

```bash
npm install svelte @inertiajs/svelte esbuild esbuild-svelte
```

- `svelte` — the framework and its compiler.
- `@inertiajs/svelte` — the Inertia client adapter for Svelte.
- `esbuild` — the bundler, now as a Node dependency.
- `esbuild-svelte` — the plugin that compiles `.svelte` files during bundling.

> #### TypeScript {: .tip}
>
> `svelte-preprocess` is only needed if you write TypeScript (or another
> preprocessed language) **inside** your `.svelte` files. For plain Svelte you
> can skip it. If you do need it, install `svelte-preprocess` and `typescript`,
> then pass `preprocess: sveltePreprocess()` to the plugin in step 2.

## 2. Add the esbuild build script

Create `assets/esbuild.config.js`:

```javascript
// assets/esbuild.config.js
const esbuild = require("esbuild");
const sveltePlugin = require("esbuild-svelte");

const args = process.argv.slice(2);
const watch = args.includes("--watch");
const deploy = args.includes("--deploy");

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
  // Required so esbuild resolves Svelte's `svelte` export condition.
  conditions: ["svelte", "browser"],
  mainFields: ["svelte", "browser", "module", "main"],
  plugins: [
    sveltePlugin({
      // Inject component CSS through JS instead of emitting separate .css files.
      compilerOptions: { css: "injected", dev: !deploy },
    }),
  ],
};

async function run() {
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

Two options in here are easy to miss and will silently break your build if
omitted:

- **`conditions: ["svelte", ...]` (and `mainFields`)** — `@inertiajs/svelte`'s
  `package.json` only exposes a `svelte` export condition. Without these,
  esbuild cannot resolve the package at all.
- **`compilerOptions: { css: "injected" }`** — With code splitting enabled,
  esbuild emits a separate `.css` file for each lazily-imported page chunk, and
  ESM dynamic imports never load those sibling stylesheets, so your page styles
  silently disappear. Injecting the CSS through JS keeps styling correct for
  lazily-loaded pages and means your root layout needs **no** extra
  `<link rel="stylesheet">` for component styles.

## 3. Set up the Inertia entry point

Replace the contents of `assets/js/app.js` with the Inertia boot code:

```javascript
// assets/js/app.js
import { createInertiaApp } from "@inertiajs/svelte";
import { mount } from "svelte";

createInertiaApp({
  resolve: (name) => import(`./pages/${name}.svelte`),
  setup({ el, App, props }) {
    mount(App, { target: el, props });
  },
  http: {
    // Phoenix expects the CSRF token via the `x-csrf-token` header. See the
    // CSRF protection section of the README.
    xsrfHeaderName: "x-csrf-token",
  },
});
```

The dynamic import of `./pages/${name}.svelte` tells esbuild to bundle every
file under `assets/js/pages` into its own chunk, so a page name like `"Home"`
resolves to `assets/js/pages/Home.svelte` at runtime. `mount` is the Svelte 5
mounting API.

## 4. Remove the esbuild Hex package

Since esbuild now runs from Node, drop the Hex package and its configuration.

In `mix.exs`, remove the `:esbuild` dependency:

```diff
- {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
  {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
```

In `config/config.exs`, remove the entire `config :esbuild` block:

```diff
- # Configure esbuild (the version is required)
- config :esbuild,
-   version: "0.25.4",
-   my_app: [
-     args: ~w(js/app.js --bundle ...),
-     cd: Path.expand("../assets", __DIR__),
-     env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
-   ]
```

## 5. Point the dev watcher at Node

In `config/dev.exs`, replace the `esbuild` watcher with a `node` watcher that
runs the build script in watch mode:

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

## 7. Load the bundle as an ES module

Code splitting produces ES modules, so the root layout must load the bundle with
`type="module"`. In `lib/my_app_web/components/layouts/root.html.heex`, make sure
the `<head>` uses the Inertia components and a module script:

```heex
<.inertia_title>{assigns[:page_title]}</.inertia_title>
<.inertia_head content={@inertia_head} />
<link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
<script type="module" defer phx-track-static src={~p"/assets/js/app.js"}>
</script>
```

## 8. Create a page and render it

Add a Svelte page at `assets/js/pages/Home.svelte`:

```svelte
<script>
  let { name } = $props();
</script>

<h1>Hello from {name}!</h1>
```

Render it from a controller with `render_inertia/2`:

```elixir
def home(conn, _params) do
  conn
  |> assign_prop(:name, "Svelte")
  |> render_inertia("Home")
end
```

## 9. Build and run

```bash
mix assets.build
mix phx.server
```

Visit your page and you should see the Svelte component rendered through Inertia.
In development, the `node` watcher rebuilds the bundle whenever you edit a
`.svelte` file.
