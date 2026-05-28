import React from "react";
import { Link } from "@inertiajs/react";

const container = {
  maxWidth: "40rem",
  margin: "4rem auto",
  fontFamily: "system-ui, sans-serif",
};

const link = { color: "#1d4ed8", textDecoration: "underline" };

export default function About({ framework }) {
  return (
    <main style={container}>
      <h1 style={{ color: "#149eca" }}>About</h1>
      <p>A tiny Phoenix + Inertia.js + {framework} example, bundled with Vite.</p>
      <Link href="/" style={link}>← Back home</Link>
    </main>
  );
}
