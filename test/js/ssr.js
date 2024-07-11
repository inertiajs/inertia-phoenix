// A dummy module to simulate Inertia SSR rendering responses
module.exports = {
  render: (page) => {
    return {
      head: [
        `<title inertia>New title</title>`,
        `<meta name="description" content="Head stuff" />`,
      ],
      body: `<div id="ssr">${page.props.content || ""}</div>`,
    };
  },
};
