// Svelte components must be compiled before the browser can run them, and that
// compilation happens through the esbuild-svelte plugin. esbuild plugins can
// only be used through esbuild's JS API (not its CLI), which is why this project
// drives esbuild from Node here instead of using the `esbuild` Hex package.
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
