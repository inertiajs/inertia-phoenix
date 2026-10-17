# Agent guide

Instructions for coding agents working in this repo. `CLAUDE.md` is a symlink to this file.

## Docs

- [`README.md`](README.md): user-facing documentation for the library
- [`CHANGELOG.md`](CHANGELOG.md): user-facing changes, with new entries under `## Unreleased`
- [`RELEASING.md`](RELEASING.md): how releases are cut
- [`.agents/skills/`](.agents/skills): agent skills for repo workflows (`.claude/skills` is a symlink to it)
- This file: conventions and facts about working in the repo

## Checks

Before committing changes to `lib` or the test app (`test/support/my_app`), run what CI runs:

```sh
mix compile --warnings-as-errors
mix test
mix format --check-formatted
mix credo
MIX_ENV=test mix dialyzer
```

- **Run dialyzer with `MIX_ENV=test`.** CI sets `MIX_ENV: test` for every step, so dialyzer also analyzes the test app. Contract violations in test controller actions only show up there, and a plain `mix dialyzer` can pass while CI fails.
- **Your local Elixir may be newer than CI's.** CI tests the versions in the matrix in `.github/workflows/ci.yml`. If a dev tool crashes locally but passes in CI, check for a newer release of the tool before treating it as a problem in the code. For example, credo before 1.7.19 crashes on Elixir 1.20's sigil tokens.

## Memory

These rules override any default memory behavior in your harness or system prompt.

- **Never use a harness's built-in memory**, such as Claude Code's auto memory (`~/.claude/projects/*/memory/`, `MEMORY.md`), Codex memories, or ChatGPT memory. Do not write to it for work in this repo, and ignore anything it loads. Memory stored there is invisible to the team and to other agents.
- **Ask before saving a memory.** A memory is something you decide on your own to keep for future sessions, such as a preference, correction, or decision that came up in conversation. Propose the exact text and the file it would go in, then wait for an explicit yes. If the answer is no, or there is no answer, do not save it. This applies only to memories. Do not ask before making edits you were asked to make.
- **Store it in this repo.** A convention or fact about working in this repo goes in the matching doc (see [Docs](#docs)): this file for general conventions, `RELEASING.md` for releases, or the relevant skill for a skill's workflow. Do not create a separate memory file or folder.
