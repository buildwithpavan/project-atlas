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
    class="inline-flex items-center rounded-atlas-full px-2.5 py-0.5 text-xs font-medium"
    :class="{
      'bg-atlas-surface-muted text-atlas-text-secondary': variant === 'default',
      'bg-atlas-success-subtle text-atlas-success': variant === 'success',
      'bg-atlas-warning-subtle text-atlas-warning': variant === 'warning',
      'bg-atlas-error-subtle text-atlas-error': variant === 'error',
      'bg-atlas-info-subtle text-atlas-info': variant === 'info',
      'bg-atlas-ai-subtle text-atlas-ai': variant === 'ai',
    }"
  >
    <slot />
  </span>
</template>
