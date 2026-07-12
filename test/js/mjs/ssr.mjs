export function render(page) {
  return {
    head: [
      `<title data-inertia="">New title from MJS</title>`,
      `<meta name="description" content="Head stuff" />`,
    ],
    body: `<div id="ssr">${page.props.content || ""}</div>`,
  };
}
