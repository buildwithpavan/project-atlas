<script setup lang="ts">
import { ABadge } from '@/components/ui'
import { computed } from 'vue'

const props = defineProps<{
  priority: string | null
}>()

const label = computed(() => props.priority ?? 'Unknown')

const variant = computed(() => {
  switch (props.priority) {
    case 'high': return 'error'
    case 'medium': return 'warning'
    case 'low': return 'success'
    default: return 'default'
  }
})
</script>

<template>
  <ABadge :variant="variant">
    {{ label }}
  </ABadge>
</template>
