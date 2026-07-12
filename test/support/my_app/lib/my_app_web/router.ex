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
    get "/non_inertia", PageController, :non_inertia
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
    get "/deep_merge_props", PageController, :deep_merge_props
    get "/deferred_props", PageController, :deferred_props
    get "/rescued_deferred_props", PageController, :rescued_deferred_props
    get "/nested_rescue_deferred_props", PageController, :nested_rescue_deferred_props

    get "/nested_unrescuable_failure_deferred_props",
        PageController,
        :nested_unrescuable_failure_deferred_props
    get "/unrescued_deferred_props", PageController, :unrescued_deferred_props
    get "/encrypted_history", PageController, :encrypted_history
    get "/cleared_history", PageController, :cleared_history
    get "/preserved_fragment", PageController, :preserved_fragment
    get "/redirect_with_preserved_fragment", PageController, :redirect_with_preserved_fragment
    get "/camelized_props", PageController, :camelized_props
    get "/camelized_deferred_props", PageController, :camelized_deferred_props
    get "/preserved_case_props", PageController, :preserved_case_props
    get "/local_ssr", PageController, :local_ssr
    get "/escaped_title", PageController, :escaped_title
    get "/force_redirect", PageController, :force_redirect
    get "/once_props", PageController, :once_props
    get "/once_props_fresh", PageController, :once_props_fresh
    get "/once_props_with_expiration", PageController, :once_props_with_expiration
    get "/once_props_with_custom_key", PageController, :once_props_with_custom_key
    get "/once_props_camelized", PageController, :once_props_camelized
    get "/once_props_with_deferred", PageController, :once_props_with_deferred
    get "/scroll_props", PageController, :scroll_props
    get "/scroll_props_with_custom_wrapper", PageController, :scroll_props_with_custom_wrapper
    get "/scroll_props_with_custom_page_name", PageController, :scroll_props_with_custom_page_name
    get "/scroll_props_lazy", PageController, :scroll_props_lazy
    get "/scroll_props_camelized", PageController, :scroll_props_camelized
    get "/scroll_props_with_custom_metadata", PageController, :scroll_props_with_custom_metadata
    get "/scroll_props_scrivener", PageController, :scroll_props_scrivener
    get "/scroll_props_flop", PageController, :scroll_props_flop
    get "/scroll_props_with_transform", PageController, :scroll_props_with_transform
    get "/scroll_props_with_meta", PageController, :scroll_props_with_meta
    get "/scroll_props_invalid_meta", PageController, :scroll_props_invalid_meta
    get "/scroll_props_legacy_transform", PageController, :scroll_props_legacy_transform
    get "/scroll_props_camelized_wrapper", PageController, :scroll_props_camelized_wrapper

    get "/scroll_props_flop_cursor_custom_metadata",
        PageController,
        :scroll_props_flop_cursor_custom_metadata

    get "/scroll_props_invalid_tuple", PageController, :scroll_props_invalid_tuple
    get "/shared_props_via_assign", PageController, :shared_props_via_assign
    get "/shared_props_via_inline", PageController, :shared_props_via_inline
    get "/shared_props_with_merge", PageController, :shared_props_with_merge
    get "/shared_props_with_defer", PageController, :shared_props_with_defer
    get "/shared_props_camelized", PageController, :shared_props_camelized
    get "/shared_props_empty", PageController, :shared_props_empty
    get "/nested_optional", PageController, :nested_optional
    get "/nested_defer", PageController, :nested_defer
    get "/nested_merge", PageController, :nested_merge
    get "/nested_deep_merge", PageController, :nested_deep_merge
    get "/nested_always", PageController, :nested_always
    get "/nested_partial_dot_path", PageController, :nested_partial_dot_path
    get "/nested_parent_resolved", PageController, :nested_parent_resolved
    get "/nested_two_level_unwrap", PageController, :nested_two_level_unwrap
    get "/nested_once", PageController, :nested_once
    get "/nested_camelized", PageController, :nested_camelized
    get "/nested_scroll", PageController, :nested_scroll
    get "/nested_plain_map_partial", PageController, :nested_plain_map_partial
    get "/redirect_with_clear_history", PageController, :redirect_with_clear_history
    get "/redirect_with_fragment", PageController, :redirect_with_fragment
    get "/empty_response", PageController, :empty_response
    get "/prepend_props", PageController, :prepend_props
    get "/match_props_on", PageController, :match_props_on
    get "/scroll_props_with_reset", PageController, :scroll_props_with_reset
    get "/ssr_excluded", PageController, :ssr_excluded
    get "/scroll_props_prepend", PageController, :scroll_props_prepend
    put "/", PageController, :update
    patch "/", PageController, :patch
    delete "/", PageController, :delete
  end
end
