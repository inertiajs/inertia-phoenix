// A dummy module to simulate Inertia SSR rendering errors
module.exports = {
  render: (_page) => {
    throw new Error("SSR failed");
  },
};
