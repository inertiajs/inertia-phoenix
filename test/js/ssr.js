// A dummy module to simulate Inertia SSR rendering responses
module.exports = {
  render: (_page) => {
    return {
      head: [
        `<title>New title</title>`,
        `<meta name="description" content="Head stuff" />`,
      ],
      body: `<div id="ssr"></div>`,
    };
  },
};
