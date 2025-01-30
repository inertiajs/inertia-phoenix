defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Inertia.Plug
  end

  scope "/", MyAppWeb do
    pipe_through(:browser)

    get "/", PageController, :index
    get "/shared", PageController, :shared
    get "/lazy", PageController, :lazy
    get "/nested", PageController, :nested
    get "/always", PageController, :always
    get "/tagged_lazy", PageController, :tagged_lazy
    get "/changeset_errors", PageController, :changeset_errors
    get "/redirect_on_error", PageController, :redirect_on_error
    get "/bad_error_map", PageController, :bad_error_map
    match :*, "/external_redirect", PageController, :external_redirect
    get "/overridden_flash", PageController, :overridden_flash
    get "/struct_props", PageController, :struct_props
    get "/binary_props", PageController, :binary_props
    get "/merge_props", PageController, :merge_props
    get "/deferred_props", PageController, :deferred_props
    get "/encrypted_history", PageController, :encrypted_history
    get "/cleared_history", PageController, :cleared_history
    get "/camelized_props", PageController, :camelized_props
    get "/camelized_deferred_props", PageController, :camelized_deferred_props
    get "/preserved_case_props", PageController, :preserved_case_props
    get "/local_ssr", PageController, :local_ssr
    put "/", PageController, :update
    patch "/", PageController, :patch
    delete "/", PageController, :delete
  end
end
