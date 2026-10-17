---
name: release
description: Cut a new release of the inertia Hex package. Picks the version from the Unreleased changelog entries, bumps it, commits, pushes, tags, and creates the GitHub release once the maintainer has published to Hex. Use when asked to prepare, cut, or ship a release.
disable-model-invocation: true
---

# Release

Releases are a single "Version X.Y.Z" commit on `main`, a lightweight
`vX.Y.Z` tag, a Hex publish, and a GitHub release whose notes are that
version's changelog section. Stop at each **checkpoint** below and wait for
the maintainer before continuing.

## 1. Check the starting state

```sh
git status -sb
git log --oneline $(git describe --tags --abbrev=0)..HEAD
gh run list --branch main --limit 3
```

- Be on `main`, clean, and up to date with `origin/main`.
- CI on `main` should be green.
- `CHANGELOG.md` must have a `## Unreleased` section covering the commits
  since the last tag. If a user-facing change is missing from it, stop and
  say so rather than writing the entry yourself.

## 2. Pick the version

Read the `## Unreleased` section and apply semver to the current
`@version` in `mix.exs`:

- Anything under **Added**, or a new option or function: minor (3.0.1 → 3.1.0).
- Only **Fixed**, **Security**, or non-breaking **Changed**: patch (3.1.0 → 3.1.1).
- Breaking changes: major. Don't pick this yourself; ask.
- Release candidates use `X.Y.Z-rcN`, e.g. `3.0.0-rc5`.

State the version you chose and why.

## 3. Bump and commit

Edit exactly two lines:

- `CHANGELOG.md`: `## Unreleased` → `## X.Y.Z - YYYY-MM-DD` (today's date)
- `mix.exs`: `@version "<old>"` → `@version "X.Y.Z"`

The install snippets in `README.md` and `guides/upgrading_to_v3.md` use
`~> 3.0`, so they only change on a major version.

```sh
mix test
git commit -am "Version X.Y.Z"
```

**Checkpoint:** show the diff and test result, and give the remaining
commands. Don't push until asked.

## 4. Push and tag

Tags are lightweight, not annotated, and point at the version commit.

```sh
git push origin main
git tag vX.Y.Z
git push origin vX.Y.Z
```

**Checkpoint:** the maintainer runs `mix hex.publish` themselves, since it
needs their Hex credentials. Don't run it. Suggest `! mix hex.publish` and
wait for them to confirm it's published.

## 5. Create the GitHub release

The title is `Version X.Y.Z` and the body is the version's changelog
section without its heading. Write the notes to the scratchpad, not the repo.

```sh
awk '/^## X\.Y\.Z /{f=1;next} /^## /{f=0} f' CHANGELOG.md | sed '/./,$!d' > <scratchpad>/notes.md
cat <scratchpad>/notes.md
gh release create vX.Y.Z --title "Version X.Y.Z" --notes-file <scratchpad>/notes.md --latest
```

For a release candidate, pass `--prerelease` instead of `--latest`.

Finish by giving the release URL.
