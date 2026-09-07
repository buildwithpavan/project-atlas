<script setup lang="ts">
import { AInput, AButton } from '@/components/ui'

const search = defineModel<string>('search', { default: '' })
const status = defineModel<string>('status', { default: '' })
const priority = defineModel<string>('priority', { default: '' })

defineProps<{
  hasActiveFilters: boolean
}>()

defineEmits<{
  clear: []
}>()

const statusOptions = [
  { value: '', label: 'All statuses' },
  { value: 'open', label: 'Open' },
  { value: 'closed', label: 'Closed' },
  { value: 'pending', label: 'Pending' },
  { value: 'resolved', label: 'Resolved' },
]

const priorityOptions = [
  { value: '', label: 'All priorities' },
  { value: 'low', label: 'Low' },
  { value: 'medium', label: 'Medium' },
  { value: 'high', label: 'High' },
]
</script>

<template>
  <div class="flex flex-col sm:flex-row gap-3">
    <div class="flex-1">
      <AInput
        v-model="search"
        type="search"
        placeholder="Search tickets…"
        aria-label="Search tickets"
      />
    </div>

    <div class="flex gap-3">
      <select
        :value="status"
        class="voceive-focus-ring rounded-voceive border border-voceive-border bg-voceive-surface px-3 py-2 text-sm text-voceive-text-primary hover:border-voceive-border-strong transition-colors appearance-none"
        aria-label="Filter by status"
        @change="status = ($event.target as HTMLSelectElement).value"
      >
        <option
          v-for="opt in statusOptions"
          :key="opt.value"
          :value="opt.value"
        >
          {{ opt.label }}
        </option>
      </select>

      <select
        :value="priority"
        class="voceive-focus-ring rounded-voceive border border-voceive-border bg-voceive-surface px-3 py-2 text-sm text-voceive-text-primary hover:border-voceive-border-strong transition-colors appearance-none"
        aria-label="Filter by priority"
        @change="priority = ($event.target as HTMLSelectElement).value"
      >
        <option
          v-for="opt in priorityOptions"
          :key="opt.value"
          :value="opt.value"
        >
          {{ opt.label }}
        </option>
      </select>

      <AButton
        v-if="hasActiveFilters"
        variant="ghost"
        size="sm"
        class="shrink-0 self-center"
        @click="$emit('clear')"
      >
        Clear filters
      </AButton>
    </div>
  </div>
</template>
