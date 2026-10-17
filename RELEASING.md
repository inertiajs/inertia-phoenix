# Releasing

Releases are run by the `release` agent skill in [`.agents/skills/release`](.agents/skills/release/SKILL.md). In Claude Code, run `/release`. Other agents can be pointed at the skill file.

The skill picks the version from the `Unreleased` changelog entries, bumps it, runs the tests, and commits. It then stops for your approval before pushing and tagging. You run `mix hex.publish` yourself, since it needs your Hex credentials. After you confirm the publish, the skill creates the GitHub release.

## Manual

If you're releasing without the skill, follow these steps:

1. Make sure `main` is clean and up to date, CI is passing, and every user-facing change since the last tag is under `## Unreleased` in `CHANGELOG.md`
2. Pick the version: a minor bump if anything was added, a patch bump for fixes only, and a major bump for breaking changes
3. Update the `## Unreleased` heading in `CHANGELOG.md` to `## #{@version} - YYYY-MM-DD`
4. Update the `@version` variable in `mix.exs`
5. For a major version, update the `~>` requirement under Installation in `README.md` and in the upgrade guide
6. Run `mix test` and commit as `Version #{@version}`
7. Push `main`, then create and push a lightweight tag named `v#{@version}`
8. Run `mix hex.publish`
9. Create a GitHub release for the tag, titled `Version #{@version}`, with that version's `CHANGELOG.md` section as the notes. Mark release candidates as pre-releases.
