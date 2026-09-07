<script setup lang="ts">
import { ABadge } from '@/components/ui'
import { computed } from 'vue'

const props = defineProps<{
  status: string | null
}>()

const label = computed(() => props.status ?? 'Unknown')

const variant = computed(() => {
  switch (props.status) {
    case 'open': return 'info'
    case 'closed': return 'default'
    case 'pending': return 'warning'
    case 'resolved': return 'success'
    default: return 'default'
  }
})
</script>

<template>
  <ABadge :variant="variant">
    {{ label }}
  </ABadge>
</template>
