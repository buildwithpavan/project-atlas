<script setup lang="ts">
type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger'
type ButtonSize = 'sm' | 'md' | 'lg'

withDefaults(defineProps<{
  variant?: ButtonVariant
  size?: ButtonSize
  disabled?: boolean
  loading?: boolean
}>(), {
  variant: 'primary',
  size: 'md',
  disabled: false,
  loading: false,
})
</script>

<template>
  <button
    :disabled="disabled || loading"
    class="atlas-btn voceive-focus-ring inline-flex items-center justify-center font-medium transition-colors"
    :class="[
      // Variant
      {
        'bg-voceive-brand text-white hover:bg-voceive-brand-hover active:bg-voceive-brand-active disabled:bg-voceive-text-disabled':
          variant === 'primary',
        'bg-voceive-surface text-voceive-text-primary border border-voceive-border hover:bg-voceive-surface-muted active:bg-voceive-surface-muted disabled:text-voceive-text-disabled disabled:bg-voceive-surface-muted':
          variant === 'secondary',
        'bg-transparent text-voceive-text-secondary hover:bg-voceive-surface-muted active:bg-voceive-surface-muted disabled:text-voceive-text-disabled':
          variant === 'ghost',
        'bg-voceive-error text-white hover:bg-red-700 active:bg-red-800 disabled:bg-voceive-text-disabled':
          variant === 'danger',
      },
      // Size
      {
        'text-sm px-3 py-1.5 rounded-voceive-sm gap-1.5': size === 'sm',
        'text-sm px-4 py-2 rounded-voceive gap-2': size === 'md',
        'text-base px-5 py-2.5 rounded-voceive-md gap-2': size === 'lg',
      },
      // State
      {
        'cursor-not-allowed opacity-60': disabled || loading,
      },
    ]"
  >
    <svg
      v-if="loading"
      class="animate-spin -ml-0.5 size-4"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      aria-hidden="true"
    >
      <circle
        class="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        stroke-width="4"
      />
      <path
        class="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
      />
    </svg>
    <slot />
  </button>
</template>
