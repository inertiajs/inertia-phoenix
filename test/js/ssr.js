// A dummy module to simulate Inertia SSR rendering responses
//
// Mirrors how the client-side adapters render the <title> tag: a
// `data-inertia=""` attribute and HTML-escaped contents.
const escape = (value) =>
  value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");

module.exports = {
  render: (page) => {
    return {
      head: [
        `<title data-inertia="">${escape(page.props.title || "New title")}</title>`,
        `<meta name="description" content="Head stuff" />`,
      ],
      body: `<div id="ssr">${page.props.content || ""}</div>`,
    };
  },
};
