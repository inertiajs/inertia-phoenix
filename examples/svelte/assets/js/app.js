import { createInertiaApp } from "@inertiajs/svelte";
import { mount } from "svelte";

createInertiaApp({
  // esbuild bundles every file matching this glob into its own chunk, so the
  // dynamic page name resolves at runtime. Pages live in assets/js/pages/<name>.svelte.
  resolve: (name) => import(`./pages/${name}.svelte`),
  setup({ el, App, props }) {
    mount(App, { target: el, props });
  },
  // Phoenix expects the CSRF token via the `x-csrf-token` header, while Inertia's
  // built-in client sends it as `x-xsrf-token` by default. See the CSRF section
  // of the inertia-phoenix README.
  http: {
    xsrfHeaderName: "x-csrf-token",
  },
});
