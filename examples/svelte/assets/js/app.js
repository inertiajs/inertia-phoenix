import { createInertiaApp } from "@inertiajs/svelte";
import { mount } from "svelte";

createInertiaApp({
  // esbuild bundles every file matching this glob into its own chunk, so the
  // dynamic page name resolves at runtime. Pages live in assets/js/pages/<name>.svelte.
  resolve: (name) => import(`./pages/${name}.svelte`),
  setup({ el, App, props }) {
    mount(App, { target: el, props });
  },
});
