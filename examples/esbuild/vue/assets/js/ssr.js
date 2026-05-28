// Server-side rendering entry point. esbuild bundles this to priv/ssr.js (a
// Node/CommonJS module), which the Inertia.SSR Node pool loads and calls as
// `render(page)` to produce the initial HTML on the server.
//
// Unlike the Inertia.js docs (which wrap this in `createServer` to run a
// standalone Node server), inertia-phoenix manages the Node workers itself, so
// we just export a `render` function.
import { createInertiaApp } from "@inertiajs/vue3";
import { renderToString } from "@vue/server-renderer";
import { createSSRApp, h } from "vue";

export function render(page) {
  return createInertiaApp({
    page,
    render: renderToString,
    resolve: (name) => import(`./pages/${name}.vue`),
    setup({ App, props, plugin }) {
      return createSSRApp({ render: () => h(App, props) }).use(plugin);
    },
  });
}
