<script setup lang="ts">
/**
 * Centralized Voceive logo component.
 *
 * Variants:
 *   full    – primary logo with V mark + wordmark (default)
 *   mark    – standalone V mark only (collapsed sidebar, small spaces)
 *   wordmark – VOCEIVE text wordmark only
 *   icon    – app icon (rounded square)
 */

withDefaults(
  defineProps<{
    variant?: 'full' | 'mark' | 'wordmark' | 'icon'
    theme?: 'light' | 'dark'
    height?: string
  }>(),
  {
    variant: 'full',
    theme: 'light',
    height: '32px',
  },
)

const BASE = '/branding/voceive'

const assets = {
  full: {
    light: `${BASE}/logo-primary-light.png`,
    dark: `${BASE}/logo-primary-dark.png`,
  },
  mark: {
    light: `${BASE}/logo-mark.png`,
    dark: `${BASE}/logo-mark.png`,
  },
  wordmark: {
    light: `${BASE}/wordmark.png`,
    dark: `${BASE}/wordmark-dark.png`,
  },
  icon: {
    light: `${BASE}/app-icon-light.png`,
    dark: `${BASE}/app-icon-dark.png`,
  },
} as const
</script>

<template>
  <img
    :src="assets[variant][theme]"
    alt="Voceive"
    :style="{ height, width: 'auto' }"
    class="block"
  />
</template>
