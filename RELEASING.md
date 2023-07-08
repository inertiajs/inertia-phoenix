# Releasing

1. Update the `@version` variable in `mix.exs`
2. Update the version under Installation in `README.md`
3. Run `mix hex.publish`
4. Tag an release on GitHub under the name `v#{@version}` 
