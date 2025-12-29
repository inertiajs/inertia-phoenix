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
      project = phx_test_project() |> Map.put(:args, %{options: [client_framework: "react"]})

      # Run the install task
      project = Install.update_esbuild_config(project)

      assert_has_patch(project, "config/config.exs", """
      ...|
         |  test: [
         |    args:
       - |      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
       + |      ~w(js/app.jsx --bundle --chunk-names=chunks/[name]-[hash] --splitting --format=esm  --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
         |    cd: Path.expand("../assets", __DIR__),
       - |    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
       + |    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
         |  ]
         |
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
          <script type="module" defer phx-track-static src={~p"/assets/app.js"} />
        </head>
        <body>
          {@inner_content}
        </body>
      </html>
      """)
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
      """)
    end

    test "creates tsconfig.json when typescript option is specified" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "react", typescript: true]})
        |> Install.setup_client()

      # Assert that the tsconfig.json file is created

      # TODO: Re-enable this assertion lateron. Currently failing due to Igniter issue.
      # assert_creates(project, "assets/tsconfig.json")

      # Assert that @types/react is installed as a dev dependency
      assert_has_task(project, "cmd", [
        "npm install --prefix assets --save-dev @types/react"
      ])
    end

    test "does not create tsconfig.json when typescript option is not specified" do
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

      # Check that no file creation for tsconfig.json is in the creates
      refute_creates(project, "assets/tsconfig.json")

      # Assert that @types/react is NOT installed as a dev dependency
      Enum.each(project.tasks, fn {_task, [args]} ->
        refute args =~ ~r[@types/react]
      end)
    end
  end

  describe "Pages directory creation" do
    test "creates pages directory when client framework is specified" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "react"]})
        |> Install.create_pages_directory()

      assert_creates(project, "assets/js/pages/.gitkeep")
    end

    test "creates pages directory for vue framework" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "vue"]})
        |> Install.create_pages_directory()

      assert_creates(project, "assets/js/pages/.gitkeep")
    end

    test "creates pages directory for svelte framework" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "svelte"]})
        |> Install.setup_client()
        |> Install.create_pages_directory()

      assert_creates(project, "assets/js/pages/.gitkeep")
      assert_creates(project, "assets/esbuild.config.js")
    end

    test "removes esbuild config when svelte client framework is chosen" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "svelte"]})
        |> Install.update_esbuild_config()

      assert_has_patch(project, "config/config.exs", """
      ...|
         |
       - |# Configure esbuild (the version is required)
       - |config :esbuild,
       - |  version: "0.25.4",
       - |  test: [
       - |    args:
       - |      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
       - |    cd: Path.expand("../assets", __DIR__),
       - |    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
       - |  ]
       - |
      ...|
      """)
    end

    test "adds node watchers to dev config when using svelte framework" do
      project =
        phx_test_project()
        |> Map.put(:args, %{options: [client_framework: "svelte"]})
        |> Install.update_esbuild_config()

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
  end
end
