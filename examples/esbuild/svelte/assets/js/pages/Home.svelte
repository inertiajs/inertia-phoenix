<script>
  import { inertia } from "@inertiajs/svelte";

  let { name } = $props();
</script>

<main class="container">
  <h1>Hello from {name}! 👋</h1>
  <p>This page is a Svelte component rendered through Inertia.js.</p>
  <a href="/about" use:inertia>Go to the About page →</a>
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
