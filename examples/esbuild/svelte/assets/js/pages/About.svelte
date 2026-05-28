<script>
  import { inertia } from "@inertiajs/svelte";

  let { framework } = $props();
</script>

<main class="container">
  <h1>About</h1>
  <p>
    A tiny Phoenix + Inertia.js + {framework} example, bundled with esbuild and
    the esbuild-svelte plugin.
  </p>
  <a href="/" use:inertia>← Back home</a>
</main>

<style>
  .container {
    max-width: 40rem;
    margin: 4rem auto;
    font-family: system-ui, sans-serif;
  }

  h1 {
    color: rebeccapurple;
  }

  a {
    color: #1d4ed8;
    text-decoration: underline;
  }
</style>
