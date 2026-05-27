defmodule Mix.Tasks.Inertia.Install.Docs do
  @moduledoc false

  def short_doc do
    "Installs and configures the Inertia.js adapter in a Phoenix application."
  end

  def example do
    "mix inertia.install"
  end

  def long_doc do
    """
    Installs and configures the Inertia.js adapter in a Phoenix application.

    This installer:
    1. Updates controller and HTML components to import Inertia functions
    2. Adds the Inertia plug to the browser pipeline
    3. Adds basic configuration in config.exs
    4. Updates esbuild and configures code splitting
    5. Set up the client-side integration packages
    6. Creates the pages directory for your Inertia pages

    ## Usage

    ```bash
    mix inertia.install
    ```

    ## Options

        --client-framework FRAMEWORK  Framework to use for the client-side integration
                                      (react, vue, or svelte). Default is react.
        --camelize-props              Enable camelCase for props
        --history-encrypt             Enable history encryption
        --typescript                  Enable TypeScript
        --yes                         Don't prompt for confirmations
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Inertia.Install do
    @shortdoc __MODULE__.Docs.short_doc()

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Libs.Phoenix
    alias Igniter.Project.Application
    alias Igniter.Project.Config
    alias Igniter.Project.Deps
    alias Igniter.Project.Module
    alias Igniter.Project.TaskAliases
    alias Sourceror.Zipper

    require Common

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        schema: [
          client_framework: :string,
          camelize_props: :boolean,
          history_encrypt: :boolean,
          typescript: :boolean,
          yes: :boolean
        ],
        example: __MODULE__.Docs.example(),
        defaults: [client_framework: "react"],
        positional: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> setup_controller_helpers()
      |> setup_html_helpers()
      |> setup_router()
      |> add_inertia_config()
      |> update_root_layout()
      |> update_esbuild_config()
      |> setup_client()
      |> create_starter_page()
      |> print_next_steps()
    end

    @doc false
    def setup_controller_helpers(igniter) do
      update_web_ex_helper(igniter, :controller, fn zipper ->
        import_code = "import Inertia.Controller"

        with {:ok, zipper} <- move_to_last_import(zipper) do
          {:ok, Common.add_code(zipper, import_code)}
        end
      end)
    end

    @doc false
    def setup_html_helpers(igniter) do
      update_web_ex_helper(igniter, :html, fn zipper ->
        import_code = """
            import Inertia.HTML
        """

        with {:ok, zipper} <- move_to_last_import(zipper) do
          {:ok, Common.add_code(zipper, import_code)}
        end
      end)
    end

    # Run an update function within the quote do ... end block inside a *web.ex helper function
    # update_fun must return {:ok, zipper} or :error.
    defp update_web_ex_helper(igniter, helper_name, update_fun) do
      web_module = Phoenix.web_module(igniter)

      Module.find_and_update_module!(igniter, web_module, fn zipper ->
        with {:ok, zipper} <- Function.move_to_def(zipper, helper_name, 0),
             {:ok, zipper} <- Common.move_to_do_block(zipper) do
          Common.within(zipper, update_fun)
        end
      end)
    end

    defp move_to_last_import(zipper) do
      Common.move_to_last(zipper, &Function.function_call?(&1, :import))
    end

    @doc false
    def setup_router(igniter) do
      Phoenix.append_to_pipeline(igniter, :browser, "plug Inertia.Plug")
    end

    @doc false
    def add_inertia_config(igniter) do
      # Get endpoint module name based on app name
      {igniter, endpoint_module} = Phoenix.select_endpoint(igniter)

      # Determine configuration based on options
      camelize_props = igniter.args.options[:camelize_props] || false
      history_encryption = igniter.args.options[:history_encrypt] || false

      config_options = [
        endpoint: endpoint_module
      ]

      # Add camelize_props config if specified
      config_options =
        if camelize_props do
          Keyword.put(config_options, :camelize_props, true)
        else
          config_options
        end

      # Add history encryption config if specified
      config_options =
        if history_encryption do
          Keyword.put(config_options, :history, encrypt: true)
        else
          config_options
        end

      # Add the configuration to config.exs
      Enum.reduce(config_options, igniter, fn {key, value}, igniter ->
        Config.configure(igniter, "config.exs", :inertia, [key], value)
      end)
    end

    @doc false
    def update_root_layout(igniter) do
      file_path =
        Path.join([
          "lib",
          web_dir(igniter),
          "components",
          "layouts",
          "root.html.heex"
        ])

      content = inertia_root_html(client_framework(igniter))

      Igniter.create_new_file(igniter, file_path, content, on_exists: :overwrite)
    end

    defp web_dir(igniter) do
      igniter
      |> Phoenix.web_module()
      |> inspect()
      |> Macro.underscore()
    end

    defp inertia_root_html(framework) do
      # Vue's esbuild build bundles component <style> blocks into a separate
      # app.css next to the JS; React (no CSS output) and Svelte (CSS injected
      # via JS) don't need this extra stylesheet link.
      component_css =
        if framework == "vue" do
          ~s(\n    <link phx-track-static rel="stylesheet" href={~p"/assets/js/app.css"} />)
        else
          ""
        end

      """
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta name="csrf-token" content={get_csrf_token()} />
          <.inertia_title><%= assigns[:page_title] %></.inertia_title>
          <.inertia_head content={@inertia_head} />
          <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />#{component_css}
          <script type="module" defer phx-track-static src={~p"/assets/js/app.js"} />
        </head>
        <body>
          {@inner_content}
        </body>
      </html>
      """
    end

    @doc false
    def update_esbuild_config(igniter) do
      case client_framework(igniter) do
        framework when framework in ["svelte", "vue"] -> configure_node_esbuild(igniter)
        _ -> configure_cli_esbuild(igniter)
      end
    end

    # React bundles plain JS, so the esbuild Hex package (which runs the esbuild
    # CLI) is sufficient. We just point it at the JSX entrypoint and enable code
    # splitting. We also teach `assets.setup` to `npm install` the client
    # packages, so the assets build is reproducible on a fresh checkout/CI.
    defp configure_cli_esbuild(igniter) do
      igniter
      |> Config.configure("config.exs", :esbuild, [:version], "0.27.3")
      |> Config.configure(
        "config.exs",
        :esbuild,
        [Application.app_name(igniter)],
        {:code,
         Sourceror.parse_string!("""
         [
          args:
            ~w(js/app.jsx --bundle --chunk-names=chunks/[name]-[hash] --splitting --format=esm --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
          cd: Path.expand("../assets", __DIR__),
          env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
         ]
         """)}
      )
      |> Igniter.add_task("esbuild.install")
      |> replace_alias("assets.setup", [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "cmd --cd assets npm install"
      ])
    end

    # Svelte and Vue components must be compiled by an esbuild plugin, which only
    # works through esbuild's JS API (not the CLI). So we drop the esbuild Hex
    # package entirely and drive esbuild from Node via assets/esbuild.config.js
    # (created in setup_client/1), repointing the dev watcher and asset aliases.
    defp configure_node_esbuild(igniter) do
      app_name = Application.app_name(igniter)
      {igniter, endpoint} = Phoenix.select_endpoint(igniter)

      igniter
      |> Config.remove_application_configuration("config.exs", :esbuild)
      |> Config.configure(
        "dev.exs",
        app_name,
        [endpoint, :watchers],
        {:code,
         Sourceror.parse_string!("""
         [
           node: ["esbuild.config.js", "--watch", cd: Path.expand("../assets", __DIR__)],
           tailwind: {Tailwind, :install_and_run, [#{inspect(app_name)}, ~w(--watch)]}
         ]
         """)}
      )
      |> Deps.remove_dep(:esbuild)
      |> replace_alias("assets.setup", [
        "tailwind.install --if-missing",
        "cmd --cd assets npm install"
      ])
      |> replace_alias("assets.build", [
        "compile",
        "tailwind #{app_name}",
        "cmd --cd assets node esbuild.config.js"
      ])
      |> replace_alias("assets.deploy", [
        "tailwind #{app_name} --minify",
        "cmd --cd assets node esbuild.config.js --deploy",
        "phx.digest"
      ])
    end

    defp replace_alias(igniter, name, value) do
      TaskAliases.modify_existing_alias(igniter, name, fn zipper ->
        Zipper.update(zipper, fn _ -> value end)
      end)
    end

    defp client_framework(igniter) do
      igniter.args.options[:client_framework] || "react"
    end

    @doc false
    def setup_client(igniter) do
      case igniter.args.options[:client_framework] do
        "react" ->
          igniter
          |> install_client_package()
          |> maybe_create_typescript_config()
          |> Igniter.create_new_file("assets/js/app.jsx", inertia_app_jsx(),
            on_exists: :overwrite
          )

        "svelte" ->
          igniter
          |> install_client_package()
          |> maybe_create_typescript_config()
          |> Igniter.create_new_file("assets/js/app.js", inertia_app_svelte(),
            on_exists: :overwrite
          )
          |> Igniter.create_new_file("assets/esbuild.config.js", svelte_esbuild_config(),
            on_exists: :overwrite
          )

        "vue" ->
          igniter
          |> install_client_package()
          |> maybe_create_typescript_config()
          |> Igniter.create_new_file("assets/js/app.js", inertia_app_vue(), on_exists: :overwrite)
          |> Igniter.create_new_file("assets/esbuild.config.js", vue_esbuild_config(),
            on_exists: :overwrite
          )

        _ ->
          igniter
      end
    end

    @doc false
    def create_starter_page(igniter) do
      # A starter page does double duty: it scaffolds the pages directory (an
      # empty .gitkeep is never written to disk) and gives esbuild at least one
      # file to resolve, so the page glob import doesn't fail an initial build.
      case client_framework(igniter) do
        "react" -> create_page(igniter, "Home.jsx", starter_page_react())
        "vue" -> create_page(igniter, "Home.vue", starter_page_vue())
        "svelte" -> create_page(igniter, "Home.svelte", starter_page_svelte())
        _ -> igniter
      end
    end

    defp create_page(igniter, filename, content) do
      Igniter.create_new_file(igniter, "assets/js/pages/#{filename}", content, on_exists: :skip)
    end

    defp maybe_create_typescript_config(igniter) do
      if igniter.args.options[:typescript] do
        Igniter.create_new_file(igniter, "assets/tsconfig.json", tsconfig_json(igniter),
          on_exists: :overwrite
        )
      else
        igniter
      end
    end

    defp tsconfig_json(igniter) do
      case client_framework(igniter) do
        "svelte" -> svelte_tsconfig_json()
        "vue" -> vue_tsconfig_json()
        _ -> react_tsconfig_json()
      end
    end

    defp install_client_package(igniter) do
      typescript = igniter.args.options[:typescript] || false
      client_framework = igniter.args.options[:client_framework]

      igniter
      |> install_client_main_packages(client_framework)
      |> maybe_install_typescript_deps(client_framework, typescript)
    end

    defp install_client_main_packages(igniter, "react") do
      Igniter.add_task(igniter, "cmd", [
        "npm install --prefix assets @inertiajs/react react react-dom"
      ])
    end

    defp install_client_main_packages(igniter, "vue") do
      Igniter.add_task(igniter, "cmd", [
        "npm install --prefix assets @inertiajs/vue3 vue esbuild unplugin-vue"
      ])
    end

    defp install_client_main_packages(igniter, "svelte") do
      Igniter.add_task(igniter, "cmd", [
        "npm install --prefix assets @inertiajs/svelte svelte esbuild esbuild-svelte"
      ])
    end

    defp maybe_install_typescript_deps(igniter, _, false), do: igniter

    defp maybe_install_typescript_deps(igniter, "react", true) do
      Igniter.add_task(igniter, "cmd", ["npm install --prefix assets --save-dev @types/react"])
    end

    defp maybe_install_typescript_deps(igniter, "vue", true) do
      # esbuild strips the types from `<script lang="ts">` blocks during the
      # build; vue-tsc + typescript are for editor support and type-checking.
      Igniter.add_task(igniter, "cmd", [
        "npm install --prefix assets --save-dev typescript vue-tsc"
      ])
    end

    defp maybe_install_typescript_deps(igniter, "svelte", true) do
      # esbuild strips the types from type-only `<script lang="ts">` during the
      # build; typescript is for editor support and type-checking. Non-type-only
      # TS (e.g. enums) additionally needs svelte-preprocess — see the guide.
      Igniter.add_task(igniter, "cmd", [
        "npm install --prefix assets --save-dev typescript"
      ])
    end

    defp react_tsconfig_json do
      """
      {
        "compilerOptions": {
          "target": "ES2020",
          "useDefineForClassFields": true,
          "lib": ["ES2020", "DOM", "DOM.Iterable"],
          "module": "ESNext",
          "skipLibCheck": true,
          "moduleResolution": "bundler",
          "allowImportingTsExtensions": true,
          "resolveJsonModule": true,
          "isolatedModules": true,
          "noEmit": true,
          "jsx": "react-jsx",
          "strict": true,
          "noUnusedLocals": true,
          "noUnusedParameters": true,
          "noFallthroughCasesInSwitch": true,
          "allowJs": true,
          "forceConsistentCasingInFileNames": true,
          "esModuleInterop": true,
          "baseUrl": ".",
          "paths": {
            "@/*": ["./js/*"]
          }
        },
        "include": ["js/**/*.ts", "js/**/*.tsx", "js/**/*.js", "js/**/*.jsx"],
        "exclude": ["node_modules"]
      }
      """
    end

    defp inertia_app_jsx do
      """
      import React from "react";
      import { createInertiaApp } from "@inertiajs/react";
      import { createRoot } from "react-dom/client";

      createInertiaApp({
        resolve: (name) => import(`./pages/${name}.jsx`),
        setup({ el, App, props }) {
          createRoot(el).render(<App {...props} />);
        },
        http: {
          xsrfHeaderName: "x-csrf-token",
        },
      });
      """
    end

    defp inertia_app_svelte do
      """
      import { createInertiaApp } from "@inertiajs/svelte";
      import { mount } from "svelte";

      createInertiaApp({
        resolve: (name) => import(`./pages/${name}.svelte`),
        setup({ el, App, props }) {
          mount(App, { target: el, props });
        },
        http: {
          xsrfHeaderName: "x-csrf-token",
        },
      });
      """
    end

    defp inertia_app_vue do
      """
      import { createInertiaApp } from "@inertiajs/vue3";
      import { createApp, h } from "vue";

      createInertiaApp({
        resolve: (name) => import(`./pages/${name}.vue`),
        setup({ el, App, props, plugin }) {
          createApp({ render: () => h(App, props) })
            .use(plugin)
            .mount(el);
        },
        http: {
          xsrfHeaderName: "x-csrf-token",
        },
      });
      """
    end

    defp starter_page_react do
      """
      import React from "react";

      export default function Home() {
        return (
          <main>
            <h1>Welcome to Inertia.js + React</h1>
            <p>
              This page is rendered from <code>assets/js/pages/Home.jsx</code>.
            </p>
          </main>
        );
      }
      """
    end

    defp starter_page_vue do
      """
      <template>
        <main>
          <h1>Welcome to Inertia.js + Vue</h1>
          <p>
            This page is rendered from <code>assets/js/pages/Home.vue</code>.
          </p>
        </main>
      </template>

      <style scoped>
      /* Component styles are bundled into app.css (linked from the root layout). */
      main {
        font-family: system-ui, sans-serif;
      }
      </style>
      """
    end

    defp starter_page_svelte do
      """
      <main>
        <h1>Welcome to Inertia.js + Svelte</h1>
        <p>
          This page is rendered from <code>assets/js/pages/Home.svelte</code>.
        </p>
      </main>
      """
    end

    # Svelte is compiled by the esbuild-svelte plugin, which only works through
    # esbuild's JS API. This config is run via `node esbuild.config.js`.
    #
    # This handles type-only TypeScript in `<script lang="ts">` out of the box
    # (esbuild strips the types). TS features that need real transpilation, like
    # enums, additionally require svelte-preprocess — see guides/svelte.md.
    defp svelte_esbuild_config do
      """
      const esbuild = require("esbuild");
      const sveltePlugin = require("esbuild-svelte");

      const args = process.argv.slice(2);
      const watch = args.includes("--watch");
      const deploy = args.includes("--deploy");

      const options = {
        entryPoints: ["js/app.js"],
        bundle: true,
        format: "esm",
        splitting: true,
        chunkNames: "chunks/[name]-[hash]",
        outdir: "../priv/static/assets/js",
        logLevel: "info",
        target: "es2022",
        external: ["/fonts/*", "/images/*"],
        minify: deploy,
        sourcemap: watch ? "inline" : false,
        // Required so esbuild resolves Svelte's `svelte` export condition.
        conditions: ["svelte", "browser"],
        mainFields: ["svelte", "browser", "module", "main"],
        plugins: [
          sveltePlugin({
            // Inject component CSS through JS instead of emitting separate .css
            // files, which code-split page chunks would never load.
            compilerOptions: { css: "injected", dev: !deploy },
          }),
        ],
      };

      async function run() {
        if (watch) {
          const ctx = await esbuild.context(options);
          await ctx.watch();
          console.log("esbuild: watching for changes...");
        } else {
          await esbuild.build(options);
        }
      }

      run().catch((error) => {
        console.error(error);
        process.exit(1);
      });
      """
    end

    defp svelte_tsconfig_json do
      """
      {
        "compilerOptions": {
          "target": "ES2020",
          "module": "ESNext",
          "lib": ["ES2020", "DOM", "DOM.Iterable"],
          "moduleResolution": "bundler",
          "resolveJsonModule": true,
          "isolatedModules": true,
          "allowJs": true,
          "checkJs": false,
          "noEmit": true,
          "strict": true,
          "skipLibCheck": true,
          "esModuleInterop": true,
          "forceConsistentCasingInFileNames": true
        },
        "include": ["js/**/*.ts", "js/**/*.js", "js/**/*.svelte"],
        "exclude": ["node_modules"]
      }
      """
    end

    # Vue single-file components are compiled by the unplugin-vue esbuild plugin,
    # which only works through esbuild's JS API. This config is run via
    # `node esbuild.config.js`.
    defp vue_esbuild_config do
      """
      const esbuild = require("esbuild");

      const args = process.argv.slice(2);
      const watch = args.includes("--watch");
      const deploy = args.includes("--deploy");

      async function run() {
        // unplugin-vue ships as ESM only, so load it with a dynamic import from
        // this CommonJS file.
        const { default: vue } = await import("unplugin-vue/esbuild");

        const options = {
          entryPoints: ["js/app.js"],
          bundle: true,
          format: "esm",
          splitting: true,
          chunkNames: "chunks/[name]-[hash]",
          outdir: "../priv/static/assets/js",
          logLevel: "info",
          target: "es2022",
          external: ["/fonts/*", "/images/*"],
          minify: deploy,
          sourcemap: watch ? "inline" : false,
          // Vue's bundler build reads these compile-time feature flags.
          define: {
            __VUE_OPTIONS_API__: "true",
            __VUE_PROD_DEVTOOLS__: "false",
            __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: "false",
          },
          // sourceMap: false avoids an inline CSS sourcemap that esbuild's CSS
          // loader can't parse ("Unknown word sourceMappingURL").
          plugins: [vue({ sourceMap: false })],
        };

        if (watch) {
          const ctx = await esbuild.context(options);
          await ctx.watch();
          console.log("esbuild: watching for changes...");
        } else {
          await esbuild.build(options);
        }
      }

      run().catch((error) => {
        console.error(error);
        process.exit(1);
      });
      """
    end

    defp vue_tsconfig_json do
      """
      {
        "compilerOptions": {
          "target": "ES2020",
          "module": "ESNext",
          "lib": ["ES2020", "DOM", "DOM.Iterable"],
          "moduleResolution": "bundler",
          "resolveJsonModule": true,
          "isolatedModules": true,
          "allowJs": true,
          "checkJs": false,
          "noEmit": true,
          "strict": true,
          "skipLibCheck": true,
          "esModuleInterop": true,
          "jsx": "preserve",
          "forceConsistentCasingInFileNames": true
        },
        "include": ["js/**/*.ts", "js/**/*.js", "js/**/*.vue"],
        "exclude": ["node_modules"]
      }
      """
    end

    defp print_next_steps(igniter) do
      client_framework = igniter.args.options[:client_framework]

      next_steps = []

      next_steps =
        if client_framework do
          client_setup_steps = """
          To finish setting up the client side integration:
          1. Create your Inertia pages in the assets/js/pages directory
          2. Set up your entry point file to initialize Inertia and default layout
          """

          next_steps ++ [client_setup_steps]
        else
          next_steps
        end

      next_steps =
        next_steps ++
          [
            """
            For more information on using Inertia with Phoenix, refer to:
            https://hexdocs.pm/inertia/readme.html
            """
          ]

      # Add completion notice to the Igniter
      Enum.reduce(next_steps, igniter, fn step, igniter -> Igniter.add_notice(igniter, step) end)
    end
  end
else
  defmodule Mix.Tasks.Inertia.Install do
    @shortdoc "Install `igniter` in order to install Inertia."

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'inertia.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
