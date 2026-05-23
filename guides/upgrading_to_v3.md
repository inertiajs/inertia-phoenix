# Upgrading from v2 to v3

This guide covers the breaking changes when upgrading the `inertia` package from 2.x to 3.x.

The 3.0 release aligns the server-side adapter with the [Inertia.js v3 protocol](https://inertiajs.com/). Before upgrading `inertia`, upgrade your client-side `@inertiajs/*` packages to v3 — see the [Inertia.js upgrade guide](https://inertiajs.com/upgrade-guide).

## Breaking changes

### Flash data is now a top-level page key

Flash data is no longer nested inside `props`. It is now a top-level key on the page object, matching the Inertia.js frontend convention and the Laravel adapter.

**Before (v2):**

```javascript
const { flash } = usePage().props;
```

**After (v3):**

```javascript
const { flash } = usePage();
```

### `inertia_lazy` has been removed

The `inertia_lazy/1` function, deprecated in v2.0.0, has been removed. Replace any remaining uses with `inertia_optional/1`:

```elixir
# Before
conn |> assign_prop(:thing, inertia_lazy(fn -> ... end))

# After
conn |> assign_prop(:thing, inertia_optional(fn -> ... end))
```

### Title tag marker attribute renamed

The `<title>` tag rendered by `<.inertia_title>` now uses `data-inertia` instead of `inertia` as the marker attribute. If you use the provided `<.inertia_title>` component, no action is required.

If you render the title tag yourself in a custom root layout, update the marker attribute:

```html
<!-- Before -->
<title inertia>...</title>

<!-- After -->
<title data-inertia>...</title>
```

### Initial page payload moved to a `<script>` tag

The initial page object is no longer rendered as a `data-page` attribute on the container `<div>`. It is now rendered as a `<script type="application/json">` tag, matching the only mode supported by Inertia.js v3.

If you have custom client-side bootstrap code that reads `data-page` from the container element, switch to reading from the `<script>` tag instead. The standard `createInertiaApp` flow from `@inertiajs/*` handles this automatically.

### Axios is no longer required

Inertia.js v3 ships with a built-in HTTP client and no longer depends on Axios. You can remove `axios` from your `package.json` if it was only there for Inertia.

If you previously configured the Phoenix CSRF header via `axios.defaults.xsrfHeaderName`, switch to the new `http` option on `createInertiaApp`:

```javascript
// Before
import axios from "axios";
axios.defaults.xsrfHeaderName = "x-csrf-token";

// After
createInertiaApp({
  http: {
    xsrfHeaderName: "x-csrf-token",
  },
  // ...
});
```

See the [CSRF protection](readme.html#csrf-protection) section of the README for details.

## New features worth adopting

These are not required for upgrading, but new in 3.0:

- **`assign_shared_prop/3` / `inertia_share/1`** — Mark props as shared so their keys are exposed in the `sharedProps` page metadata.
- **`preserve_fragment/1,2`** — Preserve the URL hash fragment across server-side redirects.
- **`inertia_prepend/1,2`** — Prepend merged list data (e.g. new chat messages at the top) instead of appending.
- **`match_on:` option** on `inertia_merge`, `inertia_prepend`, and `inertia_deep_merge` — Client-side deduplication of merged items.
- **`ssr_exclude_paths`** config option — Disable SSR for specific paths via string prefixes or regex.
- **Nested prop type wrappers** — `inertia_defer`, `inertia_merge`, `inertia_deep_merge`, `inertia_optional`, `inertia_once`, and `inertia_scroll` now work at any nesting depth, including inside closures.

See the [CHANGELOG](changelog.html) for the full list of additions.
