// Server-side rendering entry point. esbuild compiles this to priv/ssr.js (a
// Node/CommonJS module via the `ssr` profile in config/config.exs), which the
// Inertia.SSR Node pool loads and calls as `render(page)` to produce the
// initial HTML on the server.
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
    resolve: (name) => import(`./pages/${name}.jsx`),
    setup: ({ App, props }) => <App {...props} />,
  });
}
