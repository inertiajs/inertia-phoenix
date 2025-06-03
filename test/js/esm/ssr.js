// A dummy module to simulate Inertia SSR rendering responses
// NOTE: package.json with "type": "module" is needed for older
// NodeJS versions prior to NodeJS 22.x
//
// In CI we use
// Elixir 15 -> NodeJS 18
// Elxir 16 -> NodeJS 20
// These versions do not support ESM auto detection and a package.json
// is needed
export function render(page) {
  return {
    head: [
      `<title inertia>New title from ESM</title>`,
      `<meta name="description" content="Head stuff" />`,
    ],
    body: `<div id="ssr">${page.props.content || ""}</div>`,
  };
}
