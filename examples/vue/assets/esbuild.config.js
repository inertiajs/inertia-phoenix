// Vue single-file components must be compiled before the browser can run them,
// and that compilation happens through the unplugin-vue esbuild plugin. esbuild
// plugins can only be used through esbuild's JS API (not its CLI), which is why
// this project drives esbuild from Node here instead of using the `esbuild` Hex
// package.
//
// This builds two bundles:
//   - the client bundle (js/app.js -> priv/static/assets/js), and
//   - the SSR bundle (js/ssr.js -> priv/ssr.js), a Node/CommonJS module the
//     Inertia.SSR pool loads to pre-render pages on the server.
//
// Run directly: `node esbuild.config.js` (one-off build),
//               `node esbuild.config.js --watch` (rebuild on change, used by the
//               Phoenix dev watcher), or
//               `node esbuild.config.js --deploy` (minified production build).
const esbuild = require("esbuild");

const args = process.argv.slice(2);
const watch = args.includes("--watch");
const deploy = args.includes("--deploy");

// Shared across both bundles. unplugin-vue is instantiated per build below.
const shared = {
  bundle: true,
  logLevel: "info",
  target: "es2022",
  minify: deploy,
  sourcemap: watch ? "inline" : false,
  // Vue's bundler build reads these compile-time feature flags; defining them
  // avoids runtime warnings and drops dev-only code from production builds.
  define: {
    __VUE_OPTIONS_API__: "true",
    __VUE_PROD_DEVTOOLS__: "false",
    __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: "false",
  },
};

async function run() {
  // unplugin-vue ships as ESM only, so load it with a dynamic import from this
  // CommonJS file. sourceMap: false avoids an inline CSS sourcemap that esbuild's
  // CSS loader can't parse ("Unknown word sourceMappingURL").
  const { default: vue } = await import("unplugin-vue/esbuild");

  const client = {
    ...shared,
    entryPoints: ["js/app.js"],
    format: "esm",
    splitting: true,
    chunkNames: "chunks/[name]-[hash]",
    outdir: "../priv/static/assets/js",
    external: ["/fonts/*", "/images/*"],
    plugins: [vue({ sourceMap: false })],
  };

  // The SSR bundle runs under Node, so it targets the node platform and emits a
  // single CommonJS module that exports `render(page)`.
  const ssr = {
    ...shared,
    entryPoints: ["js/ssr.js"],
    platform: "node",
    format: "cjs",
    outfile: "../priv/ssr.js",
    plugins: [vue({ sourceMap: false })],
  };

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
