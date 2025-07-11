# Changelog

## Unreleased

### Added

- Create an `assets/js/pages` directory in the Igniter install task and fix the documentation ([#57](https://github.com/inertiajs/inertia-phoenix/pull/57)).

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
