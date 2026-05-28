// Server-side rendering entry point. `vite build --ssr` compiles this to
// priv/ssr/ssr.cjs (a self-contained Node/CommonJS module — see the SSR branch
// in vite.config.mjs), which the Inertia.SSR Node pool loads and calls as
// `render(page)` to produce the initial HTML on the server.
//
// Unlike the Inertia.js docs (which run a standalone Node server),
// inertia-phoenix manages the Node workers itself, so we just export `render`.
import React from "react";
import ReactDOMServer from "react-dom/server";
import { createInertiaApp } from "@inertiajs/react";

export function render(page) {
  return createInertiaApp({
    page,
    render: ReactDOMServer.renderToString,
    // Eager glob: every page is bundled into ssr.cjs, so resolve is synchronous
    // on the server (no per-page dynamic import like the client build).
    resolve: (name) => {
      const pages = import.meta.glob("./pages/*.jsx", { eager: true });
      return pages[`./pages/${name}.jsx`];
    },
    setup: ({ App, props }) => <App {...props} />,
  });
}
