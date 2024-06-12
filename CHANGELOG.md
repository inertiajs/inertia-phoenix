# Changelog

## Unreleased

- Support for propagating errors via an `assign_errors` helper ([#10](https://github.com/svycal/inertia-phoenix/issues/10))
- Preservation of assigned errors across redirects ([#10](https://github.com/svycal/inertia-phoenix/issues/10))
- Setup external redirects properly for Inertia requests ([#11](https://github.com/svycal/inertia-phoenix/issues/11))
- Forward flash contents across forced refreshes ([#13](https://github.com/svycal/inertia-phoenix/issues/13))
- Automatically pass Phoenix flash data via the `flash` prop

## 0.4.0

- Support for partial reloads ([#6](https://github.com/svycal/inertia-phoenix/issues/6))
- Support lazy data evaluation ([#7](https://github.com/svycal/inertia-phoenix/issues/7))

## 0.3.0

- Add `raise_on_ssr_failure` configuration

## 0.2.0

- Add SSR support
- Add `<.inertia_head>` component for rendering head elements provided by SSR

## 0.1.0

- Initial release
