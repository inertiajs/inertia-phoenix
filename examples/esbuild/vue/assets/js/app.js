import { createInertiaApp } from "@inertiajs/vue3";
import { createSSRApp, h } from "vue";

createInertiaApp({
  // esbuild bundles every file matching this glob into its own chunk, so the
  // dynamic page name resolves at runtime. Pages live in assets/js/pages/<name>.vue.
  resolve: (name) => import(`./pages/${name}.vue`),
  setup({ el, App, props, plugin }) {
    // createSSRApp hydrates the server-rendered markup (see assets/js/ssr.js).
    createSSRApp({ render: () => h(App, props) })
      .use(plugin)
      .mount(el);
  },
  http: {
    xsrfHeaderName: "x-csrf-token",
  },
});
