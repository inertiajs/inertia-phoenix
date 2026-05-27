// Server-side rendering entry point. esbuild bundles this to priv/ssr.js (a
// Node/CommonJS module), which the Inertia.SSR Node pool loads and calls as
// `render(page)` to produce the initial HTML on the server.
//
// Unlike the Inertia.js docs (which wrap this in `createServer`), inertia-phoenix
// manages the Node workers itself, so we just export a `render` function. We
// alias Svelte's server renderer to avoid clashing with that export name.
import { createInertiaApp } from "@inertiajs/svelte";
import { render as renderToHTML } from "svelte/server";

export function render(page) {
  return createInertiaApp({
    page,
    resolve: (name) => import(`./pages/${name}.svelte`),
    setup({ App, props }) {
      return renderToHTML(App, { props });
    },
  });
}
