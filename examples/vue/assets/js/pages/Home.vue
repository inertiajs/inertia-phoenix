<script setup>
import { Link } from "@inertiajs/vue3";

defineProps({ name: String });
</script>

<template>
  <main class="container">
    <h1>Hello from {{ name }}! 👋</h1>
    <p>This page is a Vue single-file component rendered through Inertia.js.</p>
    <Link href="/about">Go to the About page →</Link>
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
