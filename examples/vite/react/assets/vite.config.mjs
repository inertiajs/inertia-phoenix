import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { phoenixVitePlugin } from "phoenix_vite";

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
    // Generate absolute asset URLs pointing back at the dev server so that
    // code-split page chunks resolve against :5173, not the :4000 page origin.
    origin: "http://localhost:5173",
    // Module scripts are loaded cross-origin from the Phoenix app, so allow it.
    cors: { origin: "http://localhost:4000" },
  },
  // Bundle dependencies into the SSR output so priv/ssr/ssr.cjs is self-contained
  // and doesn't need to resolve node_modules at runtime from priv/.
  ssr: { noExternal: true },
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
    // Keeps phoenix_live_reload in charge of .ex/.heex changes instead of
    // triggering a full Vite page reload.
    phoenixVitePlugin({ pattern: /\.(ex|heex)$/ }),
  ],
}));
