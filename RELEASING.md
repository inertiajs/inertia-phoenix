# Releasing

1. Update the `## Unreleased` heading in `CHANGELOG.md` to `## #{@version} - YYYY-MM-DD`
2. Update the `@version` variable in `mix.exs`
3. Update the version under Installation in `README.md`
4. Run `mix hex.publish`
5. Tag a release on GitHub under the name `v#{@version}`

