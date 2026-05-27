import React from "react";
import { createInertiaApp } from "@inertiajs/react";
import { hydrateRoot } from "react-dom/client";

createInertiaApp({
  // esbuild bundles every file matching this glob into its own chunk, so the
  // dynamic page name resolves at runtime. Pages live in assets/js/pages/<name>.jsx.
  resolve: (name) => import(`./pages/${name}.jsx`),
  setup({ el, App, props }) {
    // hydrateRoot hydrates the server-rendered markup (see assets/js/ssr.jsx).
    hydrateRoot(el, <App {...props} />);
  },
  http: {
    xsrfHeaderName: "x-csrf-token",
  },
});
