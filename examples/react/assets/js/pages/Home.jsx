import React from "react";
import { Link } from "@inertiajs/react";

const container = {
  maxWidth: "40rem",
  margin: "4rem auto",
  fontFamily: "system-ui, sans-serif",
};

const link = { color: "#1d4ed8", textDecoration: "underline" };

export default function Home({ name }) {
  return (
    <main style={container}>
      <h1 style={{ color: "#149eca" }}>Hello from {name}! 👋</h1>
      <p>This page is a React component rendered through Inertia.js.</p>
      <Link href="/about" style={link}>Go to the About page →</Link>
    </main>
  );
}
