import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { phoenixVitePlugin } from "phoenix_vite";
import { inertiaSsr } from "./vite-plugin-inertia-ssr.mjs";

// Vite runs as a dev server on :5173 alongside Phoenix on :4000. The Phoenix
// root layout loads assets from this dev server in development (see
// root.html.heex + the endpoint's static_url in config/dev.exs), and from the
// build manifest below in production.
//
// `isSsrBuild` is true for `vite build --ssr js/ssr.jsx`, which produces the
// Node SSR bundle; otherwise this is the client build.
export default defineConfig(({ isSsrBuild }) => ({
  server: {
    port: 5173,
    strictPort: true,
    // Bind IPv4 explicitly (Vite's default `localhost` can resolve to IPv6-only
    // `::1`). This matches Phoenix's 127.0.0.1 binding, so the SSR adapter's
    // server-to-server request reaches the dev server; browsers still reach it
    // via `localhost` through their IPv4 fallback.
    host: "127.0.0.1",
    // Generate absolute asset URLs pointing back at the dev server so that
    // code-split page chunks resolve against :5173, not the :4000 page origin.
    origin: "http://localhost:5173",
    // Module scripts are loaded cross-origin from the Phoenix app, so allow it.
    cors: { origin: "http://localhost:4000" },
  },
  // For the SSR *build*, bundle dependencies into the output so priv/ssr/ssr.cjs
  // is self-contained and needs no node_modules at runtime. In dev, the Vite
  // adapter renders via the dev server's module runner, which must externalize
  // CommonJS deps like react (bundling them there breaks with "module is not
  // defined"), so leave noExternal off when serving.
  ssr: isSsrBuild ? { noExternal: true } : {},
  build: isSsrBuild
    ? {
        // A single self-contained CommonJS module the Inertia.SSR Node pool loads.
        // CJS (rather than ESM) lets the pool hot-reload it in development.
        outDir: "../priv/ssr",
        emptyOutDir: true,
        rollupOptions: {
          output: {
            format: "cjs",
            entryFileNames: "ssr.cjs",
          },
        },
      }
    : {
        // Emit priv/static/.vite/manifest.json so Phoenix can map logical asset
        // names to their hashed filenames in production.
        manifest: true,
        outDir: "../priv/static",
        // priv/static also holds committed files (favicon.ico, robots.txt,
        // images), so leave them in place rather than wiping on each build.
        emptyOutDir: false,
        rollupOptions: {
          input: ["js/app.jsx"],
        },
      },
  plugins: [
    react(),
    tailwindcss(),
    // Mounts the /__inertia_ssr endpoint on the dev server so SSR can render
    // through ssrLoadModule (no --ssr build). Dev only; a no-op for `vite build`.
    inertiaSsr(),
    // Keeps phoenix_live_reload in charge of .ex/.heex changes instead of
    // triggering a full Vite page reload.
    phoenixVitePlugin({ pattern: /\.(ex|heex)$/ }),
  ],
}));
