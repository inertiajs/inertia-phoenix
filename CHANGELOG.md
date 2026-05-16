# Changelog

## Unreleased

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
- Set the `Vary: X-Inertia` response header on all requests (not just Inertia JSON responses), so HTTP caches can properly differentiate responses ([#67](https://github.com/inertiajs/inertia-phoenix/issues/67)).

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
