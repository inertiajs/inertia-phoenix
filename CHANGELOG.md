# Changelog

## Unreleased

### Fixed

- Fixed duplicate `<title>` tags on server-rendered pages. The v3 JavaScript adapters emit the SSR title as `<title data-inertia="">`, but the pattern used to absorb it into the layout's `<.inertia_title>` only matched a bare `data-inertia` attribute — so the SSR title passed through `inertia_head` untouched and rendered as a second `<title>` tag. The pattern now accepts the attribute with or without a value (including head-key values).
- The page title extracted from the SSR head is now HTML-unescaped before being placed in the `page_title` assign, since HEEx escapes it again when rendering `<.inertia_title>`. Previously (once extraction matched), a title like `Fish & Chips` would render as `Fish &amp; Chips`.

## 3.0.0-rc3 - 2026-05-30

### Added

- First-party pagination support for `inertia_scroll/2`. Pass a `Scrivener.Page` struct or a Flop `{records, %Flop.Meta{}}` tuple directly and the entries are placed under the `:wrapper` key (default `"data"`) with pagination metadata extracted automatically. Extensible to other libraries via the `Inertia.Paginated` protocol, whose `to_scroll/1` returns a metadata map that optionally carries the page's `:entries`. Also adds a `:transform` option for serializing each entry before it is rendered, and a `:meta` option (a function whose returned map is placed under a `"meta"` key in the prop, alongside the entries) for surfacing extra pagination data to the page.
- Add a `:csp_nonce_assign_key` config option. When set, the library reads a Content-Security-Policy nonce from the given connection assign and applies it to the `<script>` tag used to bootstrap the page data.
- The `:match_on` option on `inertia_merge/2`, `inertia_prepend/2`, and `inertia_deep_merge/2` now accepts a list of keys (in addition to a single key) for matching on multiple fields, producing one `matchPropsOn` entry per key.
- Add an `on_error: :ignore` option to `inertia_defer/2,3` for graceful failure of deferred props. When a rescued deferred prop's resolver fails during a partial reload, the prop is omitted, its path is reported in the `rescuedProps` page metadata, and the failure is logged and emitted as a `[:inertia, :deferred_prop, :rescue]` telemetry event ([#75](https://github.com/inertiajs/inertia-phoenix/issues/75)).

### Changed

- **(Breaking)** `inertia_scroll/2` now always shapes the prop value as `%{<wrapper> => entries}`. Previously a `%{data:, meta:}` map was passed through verbatim; now only the entries under the wrapper key are kept, and any other top-level keys (including `meta` and any sibling fields like `total_count`) are dropped from the prop. Pagination metadata is surfaced via `scrollProps` instead — read pagination state from there.
- **(Breaking)** Renamed the `inertia_scroll/2` `:metadata` option (added in 2.6.0) to `:scroll_metadata`, to distinguish it from the new `:meta` option (which adds display data to the prop value). `:scroll_metadata` still produces the `scrollProps` the client component uses.
- **(Breaking)** `ecto` is now an optional dependency. The `Ecto.Changeset` error serializer is only available when Ecto is present. Apps that pass changesets to `assign_errors` and don't already depend on Ecto should add `{:ecto, "~> 3.10"}` (most Phoenix apps already do). Bare error maps work without Ecto.
- **(Breaking)** `nodejs` is now an optional dependency. It's only needed by the default Node.js SSR adapter, so apps using SSR with the default adapter should add `{:nodejs, "~> 3.0"}`. Apps that don't use SSR (or use a custom `:ssr_adapter`) no longer pull it in.
- **(Breaking)** Raised minimum versions: Elixir `>= 1.15.0` and `phoenix_html ~> 4.0`.

### Removed

- **(Breaking)** Removed the `Inertia.ScrollMetadata` protocol (added in 2.6.0). Pagination extensibility is now provided by the single `Inertia.Paginated` protocol — implement `to_scroll/1` (which returns a metadata map, optionally carrying `:entries`) instead of `to_scroll_metadata/1`.

### Fixed

- Emit `matchPropsOn` as a list of `"path.field"` strings (e.g. `["users.id"]`) instead of a `%{path => field}` map. The Inertia.js client expects an array and calls `Array.prototype.find` on it, so the previous map shape caused a client-side error when merging props with a `match_on` key.

## 3.0.0-rc2 - 2026-05-27

### Added

- Add a pluggable SSR adapter system. Server-side rendering is now performed through an `Inertia.SSR.Adapter` behaviour, so you can plug in an alternative JavaScript runtime (Bun, a Vite dev server, etc.) in place of the default Node.js process pool by passing a module via the `:ssr_adapter` option to `Inertia.SSR`. The default `Inertia.SSR.NodeJSAdapter` preserves the existing behavior ([#44](https://github.com/inertiajs/inertia-phoenix/pull/44)).
- Add an `:esm` option to `Inertia.SSR` for using an ECMAScript Module SSR entrypoint. ESM is also auto-detected from a `.mjs` module extension ([#44](https://github.com/inertiajs/inertia-phoenix/pull/44)).
- The `inertia.install` task now produces a complete, buildable setup for **Svelte** and **Vue**, not just React. Because Svelte and Vue single-file components must be compiled by an esbuild plugin — which the `esbuild` Hex package's CLI can't load — the installer drives esbuild from Node (`assets/esbuild.config.js`) via `esbuild-svelte` / `unplugin-vue`, generates the framework's Inertia entry point, and installs the client packages.
- `inertia.install` now scaffolds a starter page (`Home.jsx` / `Home.vue` / `Home.svelte`) in place of an empty `.gitkeep`, so `mix assets.build` succeeds immediately after install.
- Add step-by-step front-end setup guides for [React](guides/esbuild/react.md), [Svelte](guides/esbuild/svelte.md), and [Vue](guides/esbuild/vue.md), each covering both client-side and server-side rendering with esbuild and backed by runnable example apps under `examples/`.

### Changed

- The `inertia.install` task's React setup now adds `npm install` to the `assets.setup` alias, so client dependencies are restored on a fresh checkout or CI build.
- The README no longer centers its client-side and SSR instructions on React. Framework-specific setup (including SSR) now lives in the per-framework guides, while the README covers the shared, framework-agnostic pieces.

### Fixed

- The root layout generated by `inertia.install` now loads the JS bundle from `/assets/js/app.js`, matching esbuild's output directory (previously `/assets/app.js`, which did not exist).

## 3.0.0-rc1 - 2026-05-18

### Added

- Add nested prop type support with a single recursive resolver. Prop type wrappers (`inertia_defer`, `inertia_merge`, `inertia_deep_merge`, `inertia_optional`, `inertia_once`, `inertia_scroll`) now work at any nesting depth, including inside closures. For example, `inertia_defer` inside a closure now correctly generates `deferredProps` metadata with dot-notation paths (e.g., `auth.permissions`).
- Add `assign_shared_prop/3` and `inertia_share/1` to mark props as shared, exposing their keys in the `sharedProps` page metadata for the Inertia v3 protocol ([#69](https://github.com/inertiajs/inertia-phoenix/issues/69)).
- Add `preserve_fragment/1` and `preserve_fragment/2` functions to instruct the client-side to preserve the URL fragment across server-side redirects ([#68](https://github.com/inertiajs/inertia-phoenix/issues/68)).
- Add `inertia_prepend/1` and `inertia_prepend/2` for prepending (instead of appending) data during client-side merges. Prepend props appear in both `mergeProps` and `prependProps` in the page response. Scroll props also respect the `X-Inertia-Infinite-Scroll-Merge-Intent: prepend` header ([#67](https://github.com/inertiajs/inertia-phoenix/issues/67)).
- Add `match_on:` option to `inertia_merge/2`, `inertia_prepend/2`, and `inertia_deep_merge/2` for client-side deduplication of merged items. Match keys are included in `matchPropsOn` page metadata ([#67](https://github.com/inertiajs/inertia-phoenix/issues/67)).
- Add `ssr_exclude_paths` config option to disable SSR for specific paths. Supports string prefixes and `~r//` regex patterns ([#67](https://github.com/inertiajs/inertia-phoenix/issues/67)).
- Add `inertia_flash/1`, `inertia_page/1`, `inertia_deferred_props/1`, `inertia_merge_props/1`, `inertia_scroll_props/1`, and `inertia_once_props/1` test helpers in `Inertia.Testing` ([#67](https://github.com/inertiajs/inertia-phoenix/issues/67)).

### Changed

- **Breaking:** Flash data is now a top-level key in the Inertia page object (`usePage().flash`) instead of being nested inside props (`usePage().props.flash`). This aligns with the Inertia.js frontend conventions and the Laravel adapter ([#67](https://github.com/inertiajs/inertia-phoenix/issues/67)).
- **Breaking:** The `<title>` tag marker attribute has been renamed from `inertia` to `data-inertia`. If you use the provided `<.inertia_title>` component, no action is required. If you render the title tag yourself in a custom root layout, update the marker attribute.
- **Breaking:** The initial page payload is now rendered as a `<script type="application/json">` tag instead of a `data-page` attribute on the container `<div>`. This matches the only mode supported by Inertia.js v3 ([#66](https://github.com/inertiajs/inertia-phoenix/pull/66)).
- Set the `Vary: X-Inertia` response header on all requests (not just Inertia JSON responses), so HTTP caches can properly differentiate responses ([#67](https://github.com/inertiajs/inertia-phoenix/issues/67)).
- Remove `axios` from the Igniter installer template, since Inertia.js v3 ships with a built-in HTTP client ([#66](https://github.com/inertiajs/inertia-phoenix/pull/66)).

### Removed

- **Breaking:** Remove `inertia_lazy/1` (deprecated since v2.0.0). Use `inertia_optional/1` instead ([#66](https://github.com/inertiajs/inertia-phoenix/pull/66)).

### Fixed

- Persist `clearHistory` across redirects via the session, matching the existing behavior of `preserve_fragment`. Previously, `clear_history(conn)` was lost on redirect ([#67](https://github.com/inertiajs/inertia-phoenix/issues/67)).
- Handle redirects containing URL hash fragments by returning 409 with `X-Inertia-Redirect` header, so the client can perform a full navigation that preserves the fragment ([#67](https://github.com/inertiajs/inertia-phoenix/issues/67)).
- Redirect Inertia requests that receive a 200 with an empty body back to the referer (or `/`), instead of rendering a blank page ([#67](https://github.com/inertiajs/inertia-phoenix/issues/67)).
- Include `"reset": true` in scroll prop metadata when the scroll data path is in the `X-Inertia-Reset` header ([#67](https://github.com/inertiajs/inertia-phoenix/issues/67)).

## 2.6.2

### Fixed

- Fix CSR fallback crash when SSR returns non-string error ([#73](https://github.com/inertiajs/inertia-phoenix/pull/73)).

## 2.6.1

### Fixed

- Fix `onSuccess` not being called when `errorBag` is set and there are no validation errors ([#72](https://github.com/inertiajs/inertia-phoenix/issues/72)).

## 2.6.0

### Added

- Add `inertia_scroll/2` function to support infinite scroll pagination. Automatically configures merge behavior and extracts pagination metadata for the client-side `InfiniteScroll` component. Includes `Inertia.ScrollMetadata` protocol for extensible pagination library support ([#63](https://github.com/inertiajs/inertia-phoenix/issues/63)).
- Add `inertia_once/2` function to support once props, which are cached on the client-side and reused across page navigations. Supports `fresh`, `until`, and `as` options for controlling refresh behavior, expiration, and custom keys ([#62](https://github.com/inertiajs/inertia-phoenix/issues/62)).
- Create an `assets/js/pages` directory in the Igniter install task and fix the documentation ([#57](https://github.com/inertiajs/inertia-phoenix/pull/57)).

### Fixed

- Properly camelize keys in `deferredProps` metadata when `camelize_props` is enabled.

## 2.5.1

### Fixed

- Treat Igniter as an optional dependency in the `mix inertia.install` task definition. Previously, compilation would fail if Igniter was not installed.

## 2.5.0

### Added

- Add `inertia_deep_merge/1` function to support deep merging props on the client side (https://github.com/inertiajs/inertia/pull/2069) ([#54](https://github.com/inertiajs/inertia-phoenix/pull/54)).
- Add Igniter installer task ([#51](https://github.com/inertiajs/inertia-phoenix/pull/51)).

## 2.4.0

### Added

- Add `inertia_errors/1` test helper to fetch Inertia errors ([#43](https://github.com/inertiajs/inertia-phoenix/pull/43)).

## 2.3.0

### Added

- Add a `force_inertia_redirect` plug function to instruct the client-side to always perform a full browser redirect when a redirect response is sent ([#35](https://github.com/inertiajs/inertia-phoenix/issues/35)).

### Changed

- Define an `Inertia.Errors` protocol with default implementations for `Ecto.Changeset` and `Map`.

## 2.2.0

### Added

- Add `preserve_case` helper to prevent auto-camelization of specified prop keys.
- Add `Inertia.Controller.inertia_response?/1` helper to determine if a response is Inertia-rendered.

### Fixed

- Ensure prop keys are compared in the proper casing (for partial reloads) when `camelize_props` is enabled.
- Fix prop resolution for deferred/optional props.

## 2.1.0

### Fixed

- Include new Inertia v2 attributes in the initial page object (`mergeProps`, `deferredProps`, `encryptHistory`, `clearHistory`).
- Mark internal component functions in `Inertia.HTML` as private.

## 2.0.0

### Added

- Add support new Inertia.js v2.0.0.
  - Add `encrypt_history` function to instruct the client-side to encrypt the history entry.
  - Add `clear_history` function to instruct the client-side to clear history.
  - Add `inertia_optional` function, to replace the now-deprecated `inertia_lazy` function.
  - Add `inertia_merge` function to instruct the client-side to merge the prop value with existing data.
  - Add `inertia_defer` function to instruct the client-side to fetch the prop value immediately after initial page load.
- Add helpers for testing Inertia-based controller responses via the `Inertia.Testing` module.
- Add a `camelize_props` global config option and a `camelize_props` function (to use on a per-request basis) to automatically convert prop keys from snake case to camel case.
- Accept an `ssr` option on the `render_inertia` function.

### Changed

- Update Phoenix LiveView to v1.0.
- The errors serializer (for `Ecto.Changeset` structs) has been adjusted to better align with the behavior in the Laravel adapter in cases when there are **multiple validation errors for a single field**.

**Old behavior for errors serializer**

Previously, the serializer would include each error under a separate key, with a `[0]` index suffix, like this:

```javascript
{
  "name[0]": "is too long",
  "name[1]": "is not real"
}
```

While this retains maximal information about all the errors for a field, in practice it's difficult to target the right error records for display in the UI.

**New behavior for errors serializer**

Now, the serializer simply takes the _first error message_ and returns it under the field name, without any added suffix:

```javascript
{
  "name": "is too long"
}
```

### Fixed

- Allow for external redirects from `PUT` / `PATCH` / `DELETE` requests ([#22](https://github.com/inertiajs/inertia-phoenix/pull/22))
- Camelize prop names inside lists (e.g. `assign_prop(:items, [%{item_name: "..."}])`).

### Deprecated

- The `inertia_lazy/1` function has been deprecated in favor of `inertia_optional/1`

## 0.10.0

### Bug Fixes

- Remove unsupported dot-notation in partial requests (related to [inertiajs/inertia-laravel#641](https://github.com/inertiajs/inertia-laravel/pull/641))

## 0.9.0

### Bug Fixes

- Fix improper elimination of nested props when using only partials

## 0.8.0

### Features

- Support unicode props (by using the `binary` flag on Node function calls)

## 0.7.0

### Bug Fixes

- Fix exception when assigning structs as prop values (like `DateTime`)

## 0.6.0

### Bug Fixes

- Prevent overly greedy empty object elimination ([#14](https://github.com/inertiajs/inertia-phoenix/pull/14))

## 0.5.0

- Assign errors via an `assign_errors` helper ([#10](https://github.com/inertiajs/inertia-phoenix/issues/10))
- Preserve assigned errors across redirects ([#10](https://github.com/inertiajs/inertia-phoenix/issues/10))
- Set up external redirects properly for Inertia requests ([#11](https://github.com/inertiajs/inertia-phoenix/issues/11))
- Pass CSRF tokens via cookies ([#12](https://github.com/inertiajs/inertia-phoenix/issues/12))
- Forward flash contents across forced refreshes ([#13](https://github.com/inertiajs/inertia-phoenix/issues/13))
- Automatically pass Phoenix flash data via the `flash` prop

## 0.4.0

- Support for partial reloads ([#6](https://github.com/inertiajs/inertia-phoenix/issues/6))
- Support lazy data evaluation ([#7](https://github.com/inertiajs/inertia-phoenix/issues/7))

## 0.3.0

- Add `raise_on_ssr_failure` configuration

## 0.2.0

- Add SSR support
- Add `<.inertia_head>` component for rendering head elements provided by SSR

## 0.1.0

- Initial release
