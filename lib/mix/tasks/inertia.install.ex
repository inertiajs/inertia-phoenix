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
    alias Sourceror.Zipper

    use Igniter.Mix.Task
    require Igniter.Code.Common

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
      |> create_pages_directory()
      |> print_next_steps()
    end

    @doc false
    def setup_controller_helpers(igniter) do
      update_web_ex_helper(igniter, :controller, fn zipper ->
        import_code = "import Inertia.Controller"

        with {:ok, zipper} <- move_to_last_import(zipper) do
          {:ok, Igniter.Code.Common.add_code(zipper, import_code)}
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
          {:ok, Igniter.Code.Common.add_code(zipper, import_code)}
        end
      end)
    end

    # Run an update function within the quote do ... end block inside a *web.ex helper function
    # update_fun must return {:ok, zipper} or :error.
    defp update_web_ex_helper(igniter, helper_name, update_fun) do
      web_module = Igniter.Libs.Phoenix.web_module(igniter)

      Igniter.Project.Module.find_and_update_module!(igniter, web_module, fn zipper ->
        with {:ok, zipper} <- Igniter.Code.Function.move_to_def(zipper, helper_name, 0),
             {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper) do
          Igniter.Code.Common.within(zipper, update_fun)
        end
      end)
    end

    defp move_to_last_import(zipper) do
      Igniter.Code.Common.move_to_last(zipper, &Igniter.Code.Function.function_call?(&1, :import))
    end

    @doc false
    def setup_router(igniter) do
      Igniter.Libs.Phoenix.append_to_pipeline(igniter, :browser, "plug Inertia.Plug")
    end

    @doc false
    def add_inertia_config(igniter) do
      # Get endpoint module name based on app name
      {igniter, endpoint_module} = Igniter.Libs.Phoenix.select_endpoint(igniter)

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
        Igniter.Project.Config.configure(
          igniter,
          "config.exs",
          :inertia,
          [key],
          value
        )
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

      framework = igniter.args.options[:client_framework] || "react"
      content = inertia_root_html(framework)
      Igniter.create_new_file(igniter, file_path, content, on_exists: :overwrite)
    end

    defp web_dir(igniter) do
      igniter
      |> Igniter.Libs.Phoenix.web_module()
      |> inspect()
      |> Macro.underscore()
    end

    defp inertia_root_html(framework) do
      # svelte also generates a css file from the css in the components
      svelte_css =
        if framework == "svelte",
          do: "\n<link phx-track-static rel=\"stylesheet\" href={~p\"/assets/app.css\"} />",
          else: ""

      """
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta name="csrf-token" content={get_csrf_token()} />
          <.inertia_title><%= assigns[:page_title] %></.inertia_title>
          <.inertia_head content={@inertia_head} />
          <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
          <script type="module" defer phx-track-static src={~p"/assets/app.js"} />#{svelte_css}
        </head>
        <body>
          {@inner_content}
        </body>
      </html>
      """
    end

    @doc false
    def update_esbuild_config(igniter) do
      case igniter.args.options[:client_framework] do
        framework when framework in ["react", "vue"] ->
          igniter
          |> Igniter.Project.Config.configure(
            "config.exs",
            :esbuild,
            [:version],
            "0.25.4"
          )
          |> Igniter.Project.Config.configure(
            "config.exs",
            :esbuild,
            [Igniter.Project.Application.app_name(igniter)],
            {:code,
             Sourceror.parse_string!("""
             [
              args:
                ~w(js/app.jsx --bundle --chunk-names=chunks/[name]-[hash] --splitting --format=esm  --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
              cd: Path.expand("../assets", __DIR__),
              env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
             ]
             """)}
          )
          |> Igniter.add_task("esbuild.install")

        "svelte" ->
          {_, endpoint} = Igniter.Libs.Phoenix.select_endpoint(igniter)

          igniter
          |> Igniter.Project.Config.remove_application_configuration("config.exs", :esbuild)
          |> Igniter.Project.Config.configure(
            "dev.exs",
            Igniter.Project.Application.app_name(igniter),
            [endpoint, :watchers],
            {:code,
             Sourceror.parse_string!("""
              [
                node: ["esbuild.config.js", "--watch", cd: Path.expand("../assets", __DIR__)],
                tailwind: {Tailwind, :install_and_run, [#{inspect(Igniter.Project.Application.app_name(igniter))}, ~w(--watch)]}
              ]
             """)}
          )
          |> Igniter.Project.Deps.remove_dep(:esbuild)
          |> Igniter.Project.TaskAliases.modify_existing_alias("assets.setup", fn zipper ->
            Zipper.update(zipper, fn _ ->
              ["tailwind.install --if-missing", "cmd --cd assets npm install"]
            end)
          end)
          |> Igniter.Project.TaskAliases.modify_existing_alias(
            "assets.build",
            fn zipper ->
              Zipper.update(zipper, fn _ ->
                ["compile", "tailwind demo", "cmd --cd assets node esbuild.config.js --deploy"]
              end)
            end
          )
          |> Igniter.Project.TaskAliases.modify_existing_alias(
            "assets.deploy",
            fn zipper ->
              Zipper.update(zipper, fn _ ->
                [
                  "tailwind demo --minify",
                  "cmd --cd assets node esbuild.config.js --deploy",
                  "phx.digest"
                ]
              end)
            end
          )

        _ ->
          igniter
      end
    end

    @doc false
    def setup_client(igniter) do
      case igniter.args.options[:client_framework] do
        "react" ->
          igniter
          |> install_client_package()
          |> Igniter.create_new_file("assets/js/app.jsx", inertia_app_jsx(),
            on_exists: :overwrite
          )
          |> maybe_create_typescript_config()

        "vue" ->
          igniter
          |> install_client_package()
          |> maybe_create_typescript_config()

        "svelte" ->
          typescript = igniter.args.options[:typescript] || false

          igniter
          |> install_client_package()
          |> maybe_create_typescript_config()
          |> Igniter.create_new_file("assets/js/app.js", inertia_app_svelte(),
            on_exists: :overwrite
          )
          |> Igniter.create_new_file(
            "assets/esbuild.config.js",
            svelte_esbuild_config(typescript),
            on_exists: :overwrite
          )

        _ ->
          igniter
      end
    end

    @doc false
    def create_pages_directory(igniter) do
      Igniter.create_new_file(igniter, "assets/js/pages/.gitkeep", "", on_exists: :skip)
    end

    defp maybe_create_typescript_config(igniter) do
      framework = igniter.args.options[:client_framework] || "react"
      typescript = igniter.args.options[:typescript] || false

      if typescript do
        Igniter.create_new_file(igniter, "assets/tsconfig.json", tsconfig(framework),
          on_exists: :overwrite
        )
      else
        igniter
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
        "npm install --prefix assets @inertiajs/vue3 vue vue-loader"
      ])
    end

    defp install_client_main_packages(igniter, "svelte") do
      Igniter.add_task(igniter, "cmd", [
        "npm install --prefix assets svelte @inertiajs/svelte esbuild-svelte esbuild"
      ])
    end

    defp maybe_install_typescript_deps(igniter, _, false), do: igniter

    defp maybe_install_typescript_deps(igniter, "react", true) do
      Igniter.add_task(igniter, "cmd", ["npm install --prefix assets --save-dev @types/react"])
    end

    defp maybe_install_typescript_deps(igniter, "vue", true) do
      Igniter.add_task(igniter, "cmd", [
        "npm install --prefix assets --save-dev @vue/compiler-sfc vue-tsc typescript"
      ])
    end

    defp maybe_install_typescript_deps(igniter, "svelte", true) do
      Igniter.add_task(igniter, "cmd", [
        "npm install --prefix assets --save-dev svelte-loader svelte-preprocess typescript"
      ])
    end

    defp tsconfig(framework) do
      case framework do
        "react" -> react_tsconfig_json()
        "svelte" -> svelte_tsconfig_json()
        _ -> ""
      end
    end

    defp svelte_tsconfig_json() do
      """
      {
        "compilerOptions": {
          "target": "ES2020",
          "module": "ESNext",
          "lib": ["ES2020", "DOM", "DOM.Iterable"],
          "allowJs": true,
          "checkJs": false,

          "jsx": "preserve",
          "moduleResolution": "bundler",
          "resolveJsonModule": true,
          "isolatedModules": true,
          "noEmit": true,
          "strict": true,
          "noUnusedLocals": true,
          "noUnusedParameters": true,
          "noFallthroughCasesInSwitch": true,
          "forceConsistentCasingInFileNames": true,
          "esModuleInterop": true,
          "skipLibCheck": true,
          "baseUrl": ".",
        },
        "include": ["js/**/*.ts", "js/**/*.js", "js/**/*.svelte"],
        "exclude": ["node_modules"]
      }
      """
    end

    defp react_tsconfig_json() do
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

    defp inertia_app_jsx() do
      """
      import React from "react";
      import axios from "axios";

      import { createInertiaApp } from "@inertiajs/react";
      import { createRoot } from "react-dom/client";

      axios.defaults.xsrfHeaderName = "x-csrf-token";

      createInertiaApp({
        resolve: async (name) => {
          return await import(`./pages/${name}.jsx`);
        },
        setup({ App, el, props }) {
          createRoot(el).render(<App {...props} />);
        },
      });
      """
    end

    defp inertia_app_svelte() do
      """
      import { createInertiaApp } from '@inertiajs/svelte'
      import { mount } from 'svelte'

      createInertiaApp({
        resolve: async (name) => {
          let page = await import(`../js/pages/${name}.svelte`);
          return page;
        },
        setup({ el, App, props }) {
          mount(App, { target: el, props })
        },
      });
      """
    end

    defp svelte_esbuild_config(typescript) do
      additional =
        if typescript do
          """
          tsconfig: "tsconfig.json",
          """
        else
          ""
        end

      """
      // esbuild.config.js
      const esbuild = require("esbuild");
      const sveltePlugin = require("esbuild-svelte");
      const sveltePreprocess = require("svelte-preprocess");

      const args = process.argv.slice(2);
      const watch = args.includes("--watch");
      const deploy = args.includes("--deploy");

      const svelte = sveltePlugin({
        preprocess: sveltePreprocess(),
        compilerOptions: {
          dev: watch,
        },
      });

      const options = {
        entryPoints: ['js/app.js'],
        bundle: true,
        outdir: '../priv/static/assets',
        chunkNames: 'chunks/[name]-[hash]',
        splitting: true,
        format: 'esm',
        target: ['es2020'],
        external: ['/fonts/*', '/images/*'],
        plugins: [svelte],
        #{additional}
        conditions: ['svelte', 'browser']
      }

      if (watch) {
        esbuild.context(options).then((ctx) => ctx.watch());
      } else {
        esbuild.build(options);
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
