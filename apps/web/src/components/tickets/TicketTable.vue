<script setup lang="ts">
import type { Ticket } from '@/api/types'
import TicketStatusBadge from './TicketStatusBadge.vue'
import TicketPriorityBadge from './TicketPriorityBadge.vue'

defineProps<{
  tickets: Ticket[]
}>()

defineEmits<{
  select: [ticket: Ticket]
}>()

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    })
  } catch {
    return iso
  }
}
</script>

<template>
  <!-- Desktop table -->
  <div class="hidden md:block overflow-x-auto border border-atlas-border rounded-atlas-lg">
    <table class="min-w-full divide-y divide-atlas-border">
      <thead class="bg-atlas-surface-muted">
        <tr>
          <th
            class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-atlas-text-muted"
          >
            Subject
          </th>
          <th
            class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-atlas-text-muted"
          >
            Customer
          </th>
          <th
            class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-atlas-text-muted"
          >
            Status
          </th>
          <th
            class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-atlas-text-muted"
          >
            Priority
          </th>
          <th
            class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-atlas-text-muted"
          >
            Category
          </th>
          <th
            class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-atlas-text-muted"
          >
            Created
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-atlas-border bg-atlas-surface">
        <tr
          v-for="ticket in tickets"
          :key="ticket.id"
          class="atlas-focus-ring cursor-pointer hover:bg-atlas-surface-muted transition-colors"
          tabindex="0"
          role="link"
          :aria-label="`View ticket: ${ticket.subject}`"
          @click="$emit('select', ticket)"
          @keydown.enter="$emit('select', ticket)"
          @keydown.space.prevent="$emit('select', ticket)"
        >
          <td class="px-4 py-3 text-sm font-medium text-atlas-text-primary max-w-xs truncate">
            {{ ticket.subject }}
          </td>
          <td class="px-4 py-3 text-sm text-atlas-text-secondary">
            {{ ticket.customer_name || '—' }}
          </td>
          <td class="px-4 py-3">
            <TicketStatusBadge :status="ticket.status" />
          </td>
          <td class="px-4 py-3">
            <TicketPriorityBadge :priority="ticket.priority" />
          </td>
          <td class="px-4 py-3 text-sm text-atlas-text-secondary capitalize">
            {{ ticket.category || '—' }}
          </td>
          <td class="px-4 py-3 text-sm text-atlas-text-muted whitespace-nowrap">
            {{ formatDate(ticket.created_at) }}
          </td>
        </tr>
      </tbody>
    </table>
  </div>

  <!-- Mobile card list -->
  <div class="md:hidden space-y-3">
    <button
      v-for="ticket in tickets"
      :key="ticket.id"
      type="button"
      class="atlas-focus-ring w-full text-left bg-atlas-surface border border-atlas-border rounded-atlas-lg p-4 hover:bg-atlas-surface-muted transition-colors"
      @click="$emit('select', ticket)"
    >
      <p class="text-sm font-medium text-atlas-text-primary truncate">
        {{ ticket.subject }}
      </p>
      <p class="mt-1 text-xs text-atlas-text-secondary">
        {{ ticket.customer_name || 'Unknown customer' }}
      </p>
      <div class="mt-2 flex flex-wrap items-center gap-2">
        <TicketStatusBadge :status="ticket.status" />
        <TicketPriorityBadge :priority="ticket.priority" />
        <span
          v-if="ticket.category"
          class="text-xs text-atlas-text-muted capitalize"
        >
          {{ ticket.category }}
        </span>
      </div>
      <p class="mt-2 text-xs text-atlas-text-muted">
        {{ formatDate(ticket.created_at) }}
      </p>
    </button>
  </div>
</template>
