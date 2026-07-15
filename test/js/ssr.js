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
    // Mirrors the `buildSSRBody` helper from @inertiajs/core: the page data
    // <script> tag followed by the server-rendered root element. When the
    // `ssr_script_nonce` prop is set, a nonce attribute is included to
    // simulate a client-side adapter that supports nonces natively.
    const json = JSON.stringify(page).replace(/\//g, "\\/");
    const nonceAttr = page.props.ssr_script_nonce
      ? ` nonce="${page.props.ssr_script_nonce}"`
      : "";

    return {
      head: [
        `<title data-inertia="">${escape(page.props.title || "New title")}</title>`,
        `<meta name="description" content="Head stuff" />`,
      ],
      body: `<script data-page="ssr" type="application/json"${nonceAttr}>${json}</script><div id="ssr">${page.props.content || ""}</div>`,
    };
  },
};
