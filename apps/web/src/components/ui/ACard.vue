<script setup lang="ts">
withDefaults(defineProps<{
  padding?: boolean
}>(), {
  padding: true,
})
</script>

<template>
  <div
    class="bg-voceive-surface border border-voceive-border rounded-voceive-lg shadow-voceive-sm"
    :class="{ 'p-5': padding }"
  >
    <slot />
  </div>
</template>
