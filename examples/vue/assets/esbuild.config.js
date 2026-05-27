// Vue single-file components must be compiled before the browser can run them,
// and that compilation happens through the unplugin-vue esbuild plugin. esbuild
// plugins can only be used through esbuild's JS API (not its CLI), which is why
// this project drives esbuild from Node here instead of using the `esbuild` Hex
// package.
//
// Run directly: `node esbuild.config.js` (one-off build),
//               `node esbuild.config.js --watch` (rebuild on change, used by the
//               Phoenix dev watcher), or
//               `node esbuild.config.js --deploy` (minified production build).
const esbuild = require("esbuild");

const args = process.argv.slice(2);
const watch = args.includes("--watch");
const deploy = args.includes("--deploy");

async function run() {
  // unplugin-vue ships as ESM only, so load it with a dynamic import from this
  // CommonJS file.
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
    // Vue's bundler build reads these compile-time feature flags; defining them
    // avoids runtime warnings and drops dev-only code from production builds.
    define: {
      __VUE_OPTIONS_API__: "true",
      __VUE_PROD_DEVTOOLS__: "false",
      __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: "false",
    },
    // sourceMap: false avoids an inline CSS sourcemap that esbuild's CSS loader
    // can't parse ("Unknown word sourceMappingURL"); esbuild still emits its own
    // bundle sourcemaps via the `sourcemap` option above.
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
