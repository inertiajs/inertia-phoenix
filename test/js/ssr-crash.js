// A dummy module to simulate a Node.js worker crash (e.g. V8 OOM)
module.exports = {
  render: (_page) => {
    process.exit(134);
  },
};
