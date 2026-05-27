defmodule Mix.Tasks.Inertia.InstallTest do
  use ExUnit.Case

  alias Mix.Tasks.Inertia.Install
  import Igniter.Test

  describe "Web helpers setup" do
    test "adds import Inertia.Controller to controller function" do
      project = phx_test_project() |> Install.setup_controller_helpers()

      # Assert that the controller function has been updated
      assert_has_patch(project, "lib/test_web.ex", """
      ...|
         |      import Plug.Conn
         |
       + |      import Inertia.Controller
         |      unquote(verified_routes())
         |    end
      ...|
      """)
    end

    test "adds import Inertia.HTML to html function" do
      project = phx_test_project() |> Install.setup_html_helpers()

      # Assert that the html function has been updated
      assert_has_patch(project, "lib/test_web.ex", """
      ...|
         |        only: [get_csrf_token: 0, view_module: 1, view_template: 1]
         |
       + |      import Inertia.HTML
       + |
         |      # Include general helpers for rendering HTML
         |      unquote(html_helpers())
      ...|
      """)
    end
  end

  describe "Router setup" do
    test "adds Inertia.Plug to browser pipeline" do
      # Setup a test project with a router file
      project = phx_test_project() |> Install.setup_router()

      # Assert that the browser pipeline has been updated
      assert_has_patch(project, "lib/test_web/router.ex", """
      ...|
         |    plug(:protect_from_forgery)
         |    plug(:put_secure_browser_headers)
       + |    plug Inertia.Plug
         |  end
      ...|
      """)
    end
  end

  describe "Configuration" do
    test "adds basic inertia configuration" do
      project = Igniter.Test.phx_test_project() |> Install.add_inertia_config()

      # Assert that the configuration has been added
      assert_has_patch(project, "config/config.exs", """
      ...|
         |import Config
         |
       + |config :inertia, endpoint: TestWeb.Endpoint
       + |
         |config :test,
         |  ecto_repos: [Test.Repo],
      ...|
      """)
    end

    test "adds camelize_props configuration when --camelize is specified" do
      # Setup a test project with a config file
      project = Igniter.Test.phx_test_project()

      # Run the install task with camelize option
      project =
        project
        |> Map.put(:args, %{options: [camelize_props: true]})
        |> Install.add_inertia_config()

      # Assert that the camelize_props configuration has been added
      assert_has_patch(project, "config/config.exs", """
        |import Config
        |
      + |config :inertia, camelize_props: true, endpoint: TestWeb.Endpoint
      + |
      """)
    end

    test "adds history encryption configuration when --encryption is specified" do
      # Setup a test project with a config file
      project = Igniter.Test.phx_test_project()

      # Run the install task with encryption option
      project =
        project
        |> Map.put(:args, %{options: [history_encrypt: true]})
        |> Install.add_inertia_config()

      # Assert that the history encryption configuration has been added
      assert_has_patch(project, "config/config.exs", """
        |import Config
        |
      + |config :inertia, history: [encrypt: true], endpoint: TestWeb.Endpoint
      + |
      """)
    end

    test "updates esbuild configuration for code splitting" do
      project = phx_test_project()

      # Run the install task
      project = Install.update_esbuild_config(project)

      assert_has_patch(project, "config/config.exs", """
      ...|
         |# Configure esbuild (the version is required)
         |config :esbuild,
       - |  version: "0.25.4",
       + |  version: "0.27.3",
         |  test: [
         |    args:
       - |      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
       + |      ~w(js/app.jsx --bundle --chunk-names=chunks/[name]-[hash] --splitting --format=esm  --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
         |    cd: Path.expand("../assets", __DIR__),
         |    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
      ...|
      """)

      assert_has_task(project, "esbuild.install", [])
    end
  end

  describe "Layout updates" do
    test "creates root.html.heex file with inertia components" do
      project = phx_test_project() |> Install.update_root_layout()

      # Assert that the root layout file has been created with inertia components
      layout_path = "lib/test_web/components/layouts/root.html.heex"

      assert_content_equals(project, layout_path, """
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta name="csrf-token" content={get_csrf_token()} />
          <.inertia_title><%= assigns[:page_title] %></.inertia_title>
          <.inertia_head content={@inertia_head} />
          <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
          <script type="module" defer phx-track-static src={~p"/assets/js/app.js"} />
        </head>
        <body>
          {@inner_content}
        </body>
      </html>
      """)
    end

    test "links the bundled component CSS for the vue framework" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "vue"]})
        |> Install.update_root_layout()

      assert_content_equals(
        project,
        "lib/test_web/components/layouts/root.html.heex",
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
            <link phx-track-static rel="stylesheet" href={~p"/assets/js/app.css"} />
            <script type="module" defer phx-track-static src={~p"/assets/js/app.js"} />
          </head>
          <body>
            {@inner_content}
          </body>
        </html>
        """
      )
    end
  end

  describe "Client setup" do
    test "adds React client when specified" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "react"]})
        |> Install.setup_client()

      # Assert that the React client setup task is added
      assert_has_task(project, "cmd", [
        "npm install --prefix assets @inertiajs/react react react-dom"
      ])

      # Assert the app.jsx file is created
      assert_creates(project, "assets/js/app.jsx", """
      import React from "react";

      import { createInertiaApp } from "@inertiajs/react";
      import { createRoot } from "react-dom/client";

      createInertiaApp({
        resolve: async (name) => {
          return await import(`./pages/${name}.jsx`);
        },
        setup({ App, el, props }) {
          createRoot(el).render(<App {...props} />);
        },
        http: {
          xsrfHeaderName: "x-csrf-token",
        },
      });
      """)
    end

    test "overwrites tsconfig.json when typescript option is specified" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "react", typescript: true]})
        |> Install.setup_client()

      # Assert that tsconfig.json is overwritten with our config
      source = project.rewrite.sources["assets/tsconfig.json"]
      assert source != nil

      # Assert that @types/react is installed as a dev dependency
      assert_has_task(project, "cmd", [
        "npm install --prefix assets --save-dev @types/react"
      ])
    end

    test "does not modify tsconfig.json when typescript option is not specified" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "react"]})
        |> Install.setup_client()

      # Check that the React client setup task is added (as a control)
      assert_has_task(project, "cmd", [
        "npm install --prefix assets @inertiajs/react react react-dom"
      ])

      # Verify app.jsx is created (confirming setup is working)
      assert_creates(project, "assets/js/app.jsx")

      # Assert that tsconfig.json is not modified
      assert_unchanged(project, "assets/tsconfig.json")

      # Assert that @types/react is NOT installed as a dev dependency
      Enum.each(project.tasks, fn {_task, [args]} ->
        refute args =~ ~r[@types/react]
      end)
    end
  end

  describe "Starter page creation" do
    test "creates a React starter page" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "react"]})
        |> Install.create_starter_page()

      assert_creates(project, "assets/js/pages/Home.jsx")
    end

    test "creates a Vue starter page" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "vue"]})
        |> Install.create_starter_page()

      assert_creates(project, "assets/js/pages/Home.vue")
    end

    test "creates a Svelte starter page" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "svelte"]})
        |> Install.create_starter_page()

      assert_creates(project, "assets/js/pages/Home.svelte")
    end
  end

  describe "Svelte esbuild configuration" do
    setup do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "svelte"]})
        |> Install.update_esbuild_config()

      %{project: project}
    end

    test "removes the esbuild config block from config.exs", %{project: project} do
      content = file_content(project, "config/config.exs")

      refute content =~ "config :esbuild"
      refute content =~ ~s|version: "0.25.4"|
    end

    test "swaps the esbuild dev watcher for a node watcher", %{project: project} do
      assert_has_patch(project, "config/dev.exs", """
      ...|
         |  watchers: [
       - |    esbuild: {Esbuild, :install_and_run, [:test, ~w(--sourcemap=inline --watch)]},
       + |    node: ["esbuild.config.js", "--watch", cd: Path.expand("../assets", __DIR__)],
         |    tailwind: {Tailwind, :install_and_run, [:test, ~w(--watch)]}
         |  ]
      ...|
      """)
    end

    test "removes the esbuild dependency from mix.exs", %{project: project} do
      assert_has_patch(project, "mix.exs", """
      ...|
       - |    {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      ...|
      """)
    end

    test "rewrites the asset aliases to drive esbuild from node", %{project: project} do
      content = file_content(project, "mix.exs")

      assert content =~ ~s|"assets.setup": ["tailwind.install --if-missing", "cmd --cd assets npm install"]|
      assert content =~ ~s|"cmd --cd assets node esbuild.config.js"|
      assert content =~ ~s|"cmd --cd assets node esbuild.config.js --deploy"|

      refute content =~ "esbuild.install --if-missing"
      refute content =~ ~s|"esbuild test"|
      refute content =~ ~s|"esbuild test --minify"|
    end

    test "does not add the esbuild.install task", %{project: project} do
      refute Enum.any?(project.tasks, fn {task, _args} -> task == "esbuild.install" end)
    end
  end

  describe "Svelte client setup" do
    test "installs the svelte client packages" do
      project = svelte_setup_client()

      assert_has_task(project, "cmd", [
        "npm install --prefix assets @inertiajs/svelte svelte esbuild esbuild-svelte"
      ])
    end

    test "creates the svelte entry point" do
      project = svelte_setup_client()

      # Phoenix already ships an assets/js/app.js (the LiveView boot), so the
      # installer overwrites it rather than creating it.
      assert_content_equals(project, "assets/js/app.js", """
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
      """)
    end

    test "creates the node esbuild config with the load-bearing options" do
      project = svelte_setup_client()

      assert_creates(project, "assets/esbuild.config.js")

      content = file_content(project, "assets/esbuild.config.js")
      assert content =~ ~s|entryPoints: ["js/app.js"]|
      assert content =~ ~s|outdir: "../priv/static/assets/js"|
      assert content =~ ~s|conditions: ["svelte", "browser"]|
      assert content =~ ~s|compilerOptions: { css: "injected", dev: !deploy }|
      refute content =~ "svelte-preprocess"
    end

    test "leaves tsconfig untouched without the typescript option" do
      project = svelte_setup_client()

      # Phoenix ships a default assets/tsconfig.json; without --typescript we
      # leave it alone.
      assert_unchanged(project, "assets/tsconfig.json")
    end

    test "overwrites tsconfig with a svelte config and adds the ts toolchain with --typescript" do
      project = svelte_setup_client(typescript: true)

      # The svelte tsconfig includes .svelte files; the Phoenix default does not.
      assert file_content(project, "assets/tsconfig.json") =~ ~s|"js/**/*.svelte"|

      assert_has_task(project, "cmd", [
        "npm install --prefix assets --save-dev svelte-preprocess typescript"
      ])

      esbuild = file_content(project, "assets/esbuild.config.js")
      assert esbuild =~ ~s|const sveltePreprocess = require("svelte-preprocess")|
      assert esbuild =~ "preprocess: sveltePreprocess()"
      assert esbuild =~ ~s|tsconfig: "tsconfig.json"|
    end
  end

  describe "Vue esbuild configuration" do
    setup do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "vue"]})
        |> Install.update_esbuild_config()

      %{project: project}
    end

    test "routes vue to the node esbuild build instead of the CLI", %{project: project} do
      # The node watcher replaces the esbuild watcher...
      assert_has_patch(project, "config/dev.exs", """
      ...|
         |  watchers: [
       - |    esbuild: {Esbuild, :install_and_run, [:test, ~w(--sourcemap=inline --watch)]},
       + |    node: ["esbuild.config.js", "--watch", cd: Path.expand("../assets", __DIR__)],
         |    tailwind: {Tailwind, :install_and_run, [:test, ~w(--watch)]}
         |  ]
      ...|
      """)

      # ...and the CLI install task is not scheduled.
      refute Enum.any?(project.tasks, fn {task, _args} -> task == "esbuild.install" end)
    end

    test "removes the esbuild config block and dependency", %{project: project} do
      refute file_content(project, "config/config.exs") =~ "config :esbuild"

      assert_has_patch(project, "mix.exs", """
      ...|
       - |    {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      ...|
      """)
    end

    test "rewrites the asset aliases to drive esbuild from node", %{project: project} do
      content = file_content(project, "mix.exs")

      assert content =~ ~s|"cmd --cd assets node esbuild.config.js"|
      assert content =~ ~s|"cmd --cd assets node esbuild.config.js --deploy"|
      refute content =~ ~s|"esbuild test"|
    end
  end

  describe "Vue client setup" do
    test "installs the vue client packages" do
      project = vue_setup_client()

      assert_has_task(project, "cmd", [
        "npm install --prefix assets @inertiajs/vue3 vue esbuild unplugin-vue"
      ])
    end

    test "creates the vue entry point" do
      project = vue_setup_client()

      assert_content_equals(project, "assets/js/app.js", """
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
      """)
    end

    test "creates the node esbuild config with the load-bearing options" do
      project = vue_setup_client()

      assert_creates(project, "assets/esbuild.config.js")

      content = file_content(project, "assets/esbuild.config.js")
      assert content =~ ~s|entryPoints: ["js/app.js"]|
      assert content =~ ~s|outdir: "../priv/static/assets/js"|
      assert content =~ ~s|await import("unplugin-vue/esbuild")|
      assert content =~ ~s|vue({ sourceMap: false })|
      assert content =~ "__VUE_OPTIONS_API__"
    end

    test "leaves tsconfig untouched without the typescript option" do
      project = vue_setup_client()

      assert_unchanged(project, "assets/tsconfig.json")
    end

    test "overwrites tsconfig with a vue config and adds the ts toolchain with --typescript" do
      project = vue_setup_client(typescript: true)

      assert file_content(project, "assets/tsconfig.json") =~ ~s|"js/**/*.vue"|

      assert_has_task(project, "cmd", [
        "npm install --prefix assets --save-dev typescript vue-tsc"
      ])
    end
  end

  defp svelte_setup_client(opts \\ []) do
    setup_client_for("svelte", opts)
  end

  defp vue_setup_client(opts \\ []) do
    setup_client_for("vue", opts)
  end

  defp setup_client_for(framework, opts) do
    options = Keyword.merge([client_framework: framework], opts)

    phx_test_project()
    |> Map.put(:args, %{options: options})
    |> Install.setup_client()
  end

  defp file_content(project, path) do
    project.rewrite.sources[path] |> Rewrite.Source.get(:content)
  end
end
