<script setup lang="ts">
withDefaults(defineProps<{
  padding?: boolean
}>(), {
  padding: true,
})
</script>

<template>
  <div
    class="bg-atlas-surface border border-atlas-border rounded-atlas-lg shadow-atlas-sm"
    :class="{ 'p-5': padding }"
  >
    <slot />
  </div>
</template>
