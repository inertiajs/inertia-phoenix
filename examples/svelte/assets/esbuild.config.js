// Svelte components must be compiled before the browser can run them, and that
// compilation happens through the esbuild-svelte plugin. esbuild plugins can
// only be used through esbuild's JS API (not its CLI), which is why this project
// drives esbuild from Node here instead of using the `esbuild` Hex package.
//
// This builds two bundles:
//   - the client bundle (js/app.js -> priv/static/assets/js), compiled for the
//     browser, and
//   - the SSR bundle (js/ssr.js -> priv/ssr.js), a Node/CommonJS module compiled
//     with `generate: "server"` that the Inertia.SSR pool loads to pre-render
//     pages on the server.
//
// Run directly: `node esbuild.config.js` (one-off build),
//               `node esbuild.config.js --watch` (rebuild on change, used by the
//               Phoenix dev watcher), or
//               `node esbuild.config.js --deploy` (minified production build).
const esbuild = require("esbuild");
const sveltePlugin = require("esbuild-svelte");

const args = process.argv.slice(2);
const watch = args.includes("--watch");
const deploy = args.includes("--deploy");

const shared = {
  bundle: true,
  logLevel: "info",
  target: "es2022",
  minify: deploy,
  sourcemap: watch ? "inline" : false,
};

const client = {
  ...shared,
  entryPoints: ["js/app.js"],
  format: "esm",
  splitting: true,
  chunkNames: "chunks/[name]-[hash]",
  outdir: "../priv/static/assets/js",
  external: ["/fonts/*", "/images/*"],
  // Required so esbuild resolves Svelte's `svelte` export condition (Svelte 5
  // ships its runtime behind it).
  conditions: ["svelte", "browser"],
  mainFields: ["svelte", "browser", "module", "main"],
  plugins: [
    sveltePlugin({
      // Inject each component's compiled CSS through JS rather than emitting
      // separate .css files. With code splitting, esbuild would otherwise spray
      // page styles across per-chunk .css files that dynamic imports never load.
      // Injecting keeps styling correct for lazily-loaded pages and means the
      // root layout needs no extra stylesheet <link>.
      compilerOptions: { css: "injected", dev: !deploy },
    }),
  ],
};

// The SSR bundle runs under Node and renders components to strings, so it
// targets the node platform, emits CommonJS, and compiles components with
// `generate: "server"`.
const ssr = {
  ...shared,
  entryPoints: ["js/ssr.js"],
  platform: "node",
  format: "cjs",
  outfile: "../priv/ssr.js",
  conditions: ["svelte"],
  mainFields: ["svelte", "module", "main"],
  plugins: [
    sveltePlugin({
      // dev: false even outside deploy — Svelte 5's dev-mode server
      // instrumentation (push_element/filename tracking) errors during SSR, and
      // the server bundle gains nothing from dev mode.
      compilerOptions: { generate: "server", css: "injected", dev: false },
    }),
  ],
};

async function run() {
  if (watch) {
    const contexts = await Promise.all([
      esbuild.context(client),
      esbuild.context(ssr),
    ]);
    await Promise.all(contexts.map((ctx) => ctx.watch()));
    console.log("esbuild: watching for changes...");
  } else {
    await Promise.all([esbuild.build(client), esbuild.build(ssr)]);
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
