// Polyfill for `<link rel="modulepreload">`, which the production asset tags
// emit for code-split chunks. https://vite.dev/guide/backend-integration
import "vite/modulepreload-polyfill";
// Importing the CSS here lets Vite inject it (with HMR) in development and emit
// a hashed stylesheet that the manifest links in production.
import "../css/app.css";
import React from "react";
import { createInertiaApp } from "@inertiajs/react";
import { hydrateRoot } from "react-dom/client";

createInertiaApp({
  // Vite turns this glob into per-page dynamic imports, so each page is loaded
  // (and code-split) on demand. Pages live in assets/js/pages/<name>.jsx.
  resolve: (name) => {
    const pages = import.meta.glob("./pages/*.jsx");
    return pages[`./pages/${name}.jsx`]();
  },
  setup({ el, App, props }) {
    // hydrateRoot hydrates the server-rendered markup (see assets/js/ssr.jsx).
    hydrateRoot(el, <App {...props} />);
  },
  http: {
    xsrfHeaderName: "x-csrf-token",
  },
});
