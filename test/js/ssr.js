// A dummy module to simulate Inertia SSR rendering responses
module.exports = {
  render: (_page) => {
    return {
      head: [],
      body: `<div id="ssr"></div>`,
    };
  },
};
