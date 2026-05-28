<script setup>
import { Link } from "@inertiajs/vue3";

defineProps({ framework: String });
</script>

<template>
  <main class="container">
    <h1>About</h1>
    <p>
      A tiny Phoenix + Inertia.js + {{ framework }} example, bundled with esbuild
      and the unplugin-vue plugin.
    </p>
    <Link href="/">← Back home</Link>
  </main>
</template>

<style scoped>
.container {
  max-width: 40rem;
  margin: 4rem auto;
  font-family: system-ui, sans-serif;
}

h1 {
  color: #41b883;
}

a {
  color: #1d4ed8;
  text-decoration: underline;
}
</style>
