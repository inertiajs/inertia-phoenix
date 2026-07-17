// A dev-only Vite plugin that mounts an HTTP endpoint on the Vite dev server
// for server-side rendering Inertia pages.
//
// Instead of running a separate `vite build --ssr --watch` and loading the
// resulting bundle through a Node pool, this renders by asking the *running*
// dev server to load the SSR entry through its own module graph
// (`server.ssrLoadModule`). That transform is HMR-aware, so edits to ssr.jsx
// or any page are picked up with no rebuild and no Phoenix restart.
//
// The Elixir side (ReactVite.SSR.ViteAdapter) POSTs the Inertia page payload
// here and gets back `{ head, body }`. `apply: "serve"` makes this a no-op for
// `vite build`, so production builds are unaffected.
export function inertiaSsr({ entry = "/js/ssr.jsx", path = "/__inertia_ssr" } = {}) {
  return {
    name: "inertia-ssr-middleware",
    apply: "serve",
    configureServer(server) {
      server.middlewares.use(path, async (req, res) => {
        if (req.method !== "POST") {
          res.statusCode = 405;
          return res.end();
        }

        try {
          const chunks = [];
          for await (const chunk of req) chunks.push(chunk);
          const page = JSON.parse(Buffer.concat(chunks).toString("utf8"));

          // Load the SSR entry through Vite's module graph (transformed on
          // demand, invalidated by HMR), then render the page.
          const { render } = await server.ssrLoadModule(entry);
          const { head, body } = await render(page);

          res.setHeader("Content-Type", "application/json");
          res.end(JSON.stringify({ head, body }));
        } catch (err) {
          // Rewrite the stack trace to point back at the original source.
          server.ssrFixStacktrace(err);
          res.statusCode = 500;
          res.setHeader("Content-Type", "application/json");
          res.end(JSON.stringify({ error: err.stack || String(err) }));
        }
      });
    },
  };
}
