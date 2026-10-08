---
name: laravel-parity-review
description: Review recent changes to the canonical inertia-laravel adapter and identify functionality, protocol, or security fixes this Phoenix adapter is missing. Use when asked to check for gaps against inertia-laravel, sync with upstream, or find what Laravel has shipped since our last release.
disable-model-invocation: true
---

# Laravel parity review

`inertiajs/inertia-laravel` is the reference server-side adapter. Protocol
changes, new prop types, and security fixes usually land there first. This
skill finds the ones that apply to this adapter and reports them as a ranked
list of gaps.

## 1. Get an up-to-date copy of inertia-laravel

Look for a sibling checkout at `../inertia-laravel`. If there isn't one,
clone it into a scratch directory, not into this repo.

```sh
git -C ../inertia-laravel fetch origin
git -C ../inertia-laravel branch -r
```

Read from the **remote release branch that matches our major version**, for
example `origin/3.x` for this adapter's 3.x line. Don't trust the local
checkout:

- `origin/HEAD` usually points at an older major (e.g. `2.x`).
- The local branch may be months behind. Use `git log origin/3.x` and
  `git show origin/3.x:<path>`, not the working tree.

## 2. Pick the review window

Find the last point we synced against. Good anchors:

- The date of the oldest release in our `CHANGELOG.md` that hasn't been
  checked against Laravel yet. If unsure, use the date of our latest
  release's first release candidate.
- Any Laravel PR or version number mentioned in our `CHANGELOG.md` or recent
  commits.

Then list everything since:

```sh
git -C ../inertia-laravel show origin/3.x:CHANGELOG.md | head -200
git -C ../inertia-laravel log origin/3.x --since=<date> --pretty='%h %ad %s' --date=short
```

The changelog groups changes by release and links PRs. The log catches
anything that isn't released yet.

## 3. Triage and read the diffs

Skip dependency bumps, CI changes, code-style commits, facade docblock
updates, and reverted work. For everything else, read the source diff:

```sh
git -C ../inertia-laravel show <sha> --format='%s%n%b' -- src config
```

Put each change into one of these buckets:

- **Protocol or behavior**: page object keys, request/response headers,
  status codes, prop types, partial reload rules. These almost always apply.
- **Security**: escaping, header handling, session leaks. Always check these.
- **Configuration or API surface**: new options or helpers, such as
  disabling SSR for one response or transforming component names. These
  often apply in an Elixir form.
- **Laravel-specific**: session previous-URL tracking, `defer()` callbacks,
  Blade, Boost, Artisan commands, Guzzle, Octane, static-analysis types.
  These usually don't apply. Note them briefly so the reader knows they were
  considered.

## 4. Compare against this adapter

Where Laravel concepts live here:

| Laravel                                                               | Phoenix                                  |
| --------------------------------------------------------------------- | ---------------------------------------- |
| `Middleware.php`, version checks, redirects                           | `lib/inertia/plug.ex`                    |
| `Response.php`, `ResponseFactory.php`, `PropsResolver.php`            | `lib/inertia/controller.ex`              |
| Blade directive and `App` component (page JSON, `<script data-page>`) | `lib/inertia/html.ex`                    |
| `Ssr/HttpGateway.php`                                                 | `lib/inertia/ssr.ex`, `lib/inertia/ssr/` |
| `Testing/AssertableInertia.php`                                       | `lib/inertia/testing.ex`                 |

For each candidate, find the equivalent code and decide whether it's
missing, partial, or already covered. **Verify, don't assume.** Examples:

- For escaping fixes, encode a hostile value with the configured JSON
  library and look at the output:
  `mix run --no-start -e 'IO.puts Phoenix.json_library().encode!(%{"x" => "</script>"})'`
- For option handling, read the actual expression. For example,
  `opts[:x] || global` silently ignores `x: false`.
- Check the Phoenix `CHANGELOG.md`. The feature may have shipped under a
  different name.

## 5. Report

Report the gaps ranked by severity. Usually that means security issues
first, then protocol or behavior bugs, then missing features, then
nice-to-haves. For each gap, give:

- the Laravel PR number and release (e.g. "#911, v3.3.4")
- what Laravel does, in a sentence
- what this adapter does instead, with a `file:line` reference
- the size of the fix, if it's obvious

End with a short list of the changes you judged not applicable, each with a
one-line reason.

Don't change any code as part of the review. Offer to fix the top items, and
when fixing them, add a regression test for each and confirm it fails
without the fix.
