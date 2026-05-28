import { createInertiaApp } from "@inertiajs/svelte";

createInertiaApp({
  // esbuild bundles every file matching this glob into its own chunk, so the
  // dynamic page name resolves at runtime. Pages live in assets/js/pages/<name>.svelte.
  resolve: (name) => import(`./pages/${name}.svelte`),
  // With no custom `setup`, createInertiaApp hydrates the server-rendered markup
  // when it's present (SSR) and mounts a fresh app otherwise (CSR).
  http: {
    // Phoenix expects the CSRF token via the `x-csrf-token` header, while Inertia's
    // built-in client sends it as `x-xsrf-token` by default. See the CSRF section
    // of the inertia-phoenix README.
    xsrfHeaderName: "x-csrf-token",
  },
});
