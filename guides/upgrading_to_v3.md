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

### Infinite scroll pagination has been reworked

The `inertia_scroll/2` infinite-scroll support (added in 2.6.0) was reworked in 3.0. If you don't use `inertia_scroll`, no action is required.

**The scroll prop now contains only the entries.** Previously a `%{data: [...], meta: %{...}}` map was passed through verbatim, so the `meta` key (and any other sibling keys) appeared in the prop. The prop is now uniformly shaped as `%{<wrapper> => entries}`, and pagination state is surfaced via the page's `scrollProps` instead.

If a component read pagination state off the prop, read it from `scrollProps` (or the component's pagination metadata) instead:

```javascript
// Before (v2) — meta rode along in the prop
const { data, meta } = usePage().props.users;

// After (v3) — entries only; pagination state comes from the InfiniteScroll component
const { data } = usePage().props.users;
```

If you specifically need extra data (totals, etc.) on the prop, opt back in with the new `:meta` option:

```elixir
inertia_scroll(Flop.run(query, params),
  meta: fn {_records, meta} -> %{total: meta.total_count} end
)
# => %{users: %{data: [...], meta: %{total: 42}}}
```

**The `Inertia.ScrollMetadata` protocol has been removed**, replaced by the single `Inertia.Paginated` protocol. Its `to_scroll/1` returns a metadata map that optionally carries the page's `:entries`.

[Scrivener](https://hex.pm/packages/scrivener) and [Flop](https://hex.pm/packages/flop) are now supported out of the box, so a hand-written `defimpl` for them can be **deleted** — just pass the value directly:

```elixir
# Before (v2) — custom defimpl required
defimpl Inertia.ScrollMetadata, for: Scrivener.Page do
  def to_scroll_metadata(page) do
    %{page_name: "page", current_page: page.page_number, ...}
  end
end

inertia_scroll(page, wrapper: "entries")

# After (v3) — first-party; no defimpl needed
inertia_scroll(MyApp.Repo.paginate(query))
```

For other libraries, migrate the `defimpl` from `Inertia.ScrollMetadata.to_scroll_metadata/1` to `Inertia.Paginated.to_scroll/1`, including the entries under an `:entries` key when the struct carries them:

```elixir
defimpl Inertia.Paginated, for: MyPaginator.Page do
  def to_scroll(page) do
    %{
      entries: page.entries,
      current_page: page.page_number,
      previous_page: if(page.page_number > 1, do: page.page_number - 1),
      next_page: if(page.page_number < page.total_pages, do: page.page_number + 1)
    }
  end
end
```

**The `:metadata` option was renamed to `:scroll_metadata`** (to distinguish it from the new prop-level `:meta` option):

```elixir
# Before (v2)
inertia_scroll(data, metadata: fn data -> %{current_page: 1, next_page: 2} end)

# After (v3)
inertia_scroll(data, scroll_metadata: fn data -> %{current_page: 1, next_page: 2} end)
```

See the [Scroll props](readme.html#scroll-props) section of the README for the full API.

### Some dependencies are now optional

To avoid imposing dependencies on apps that don't need them, `ecto` and `nodejs` are now optional. If you use the features that rely on them, add them to your own deps:

- **`ecto`** — required only for passing an `Ecto.Changeset` to `assign_errors/2`. Most Phoenix apps already depend on Ecto, so no action is needed. If yours doesn't (and you rely on changeset errors), add `{:ecto, "~> 3.10"}`. Bare error maps work without Ecto.
- **`nodejs`** — required only by the default Node.js SSR adapter. If you use server-side rendering with the default adapter, add `{:nodejs, "~> 3.0"}`. Apps that don't use SSR, or use a custom `:ssr_adapter` (Bun, Vite, etc.), don't need it.

```elixir
def deps do
  [
    {:inertia, "~> 3.0"},
    # add only what you use:
    {:ecto, "~> 3.10"},
    {:nodejs, "~> 3.0"}
  ]
end
```

### Minimum versions raised

3.0 requires **Elixir 1.15+** and **phoenix_html 4.0+**. Upgrade these if you're on older versions.

## New features worth adopting

These are not required for upgrading, but new in 3.0:

- **`assign_shared_prop/3` / `inertia_share/1`** — Mark props as shared so their keys are exposed in the `sharedProps` page metadata.
- **`preserve_fragment/1,2`** — Preserve the URL hash fragment across server-side redirects.
- **`inertia_prepend/1,2`** — Prepend merged list data (e.g. new chat messages at the top) instead of appending.
- **`match_on:` option** on `inertia_merge`, `inertia_prepend`, and `inertia_deep_merge` — Client-side deduplication of merged items.
- **`ssr_exclude_paths`** config option — Disable SSR for specific paths via string prefixes or regex.
- **Nested prop type wrappers** — `inertia_defer`, `inertia_merge`, `inertia_deep_merge`, `inertia_optional`, `inertia_once`, and `inertia_scroll` now work at any nesting depth, including inside closures.
- **First-party pagination support** — `inertia_scroll/2` accepts a `Scrivener.Page` or a Flop `{records, %Flop.Meta{}}` tuple directly, extensible to other libraries via the `Inertia.Paginated` protocol. Plus `:transform` (shape each entry) and `:meta` (surface extra data under a `"meta"` key) options.

See the [CHANGELOG](changelog.html) for the full list of additions.
