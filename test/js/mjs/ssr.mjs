export function render(page) {
  return {
    head: [
      `<title inertia>New title from MJS</title>`,
      `<meta name="description" content="Head stuff" />`,
    ],
    body: `<div id="ssr">${page.props.content || ""}</div>`,
  };
}
