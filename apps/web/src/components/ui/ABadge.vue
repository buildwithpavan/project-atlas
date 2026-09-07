<script setup lang="ts">
type BadgeVariant = 'default' | 'success' | 'warning' | 'error' | 'info' | 'ai'

withDefaults(defineProps<{
  variant?: BadgeVariant
}>(), {
  variant: 'default',
})
</script>

<template>
  <span
    class="inline-flex items-center rounded-voceive-full px-2.5 py-0.5 text-xs font-medium"
    :class="{
      'bg-voceive-surface-muted text-voceive-text-secondary': variant === 'default',
      'bg-voceive-success-subtle text-voceive-success': variant === 'success',
      'bg-voceive-warning-subtle text-voceive-warning': variant === 'warning',
      'bg-voceive-error-subtle text-voceive-error': variant === 'error',
      'bg-voceive-info-subtle text-voceive-info': variant === 'info',
      'bg-voceive-ai-subtle text-voceive-ai': variant === 'ai',
    }"
  >
    <slot />
  </span>
</template>
