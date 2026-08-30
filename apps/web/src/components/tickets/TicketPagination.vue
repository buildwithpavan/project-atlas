<script setup lang="ts">
import { AButton } from '@/components/ui'
import type { PaginationMeta } from '@/api/types'

const props = defineProps<{
  meta: PaginationMeta
}>()

const emit = defineEmits<{
  page: [page: number]
}>()

function prevPage() {
  if (props.meta.page > 1) emit('page', props.meta.page - 1)
}

function nextPage() {
  if (props.meta.page < props.meta.total_pages) emit('page', props.meta.page + 1)
}
</script>

<template>
  <nav
    v-if="meta.total_pages > 1"
    class="flex items-center justify-between"
    aria-label="Pagination"
  >
    <p class="text-sm text-voceive-text-muted">
      Page {{ meta.page }} of {{ meta.total_pages }}
      <span class="hidden sm:inline">
        &middot; {{ meta.total }} {{ meta.total === 1 ? 'ticket' : 'tickets' }}
      </span>
    </p>
    <div class="flex gap-2">
      <AButton
        variant="secondary"
        size="sm"
        :disabled="meta.page <= 1"
        @click="prevPage"
      >
        Previous
      </AButton>
      <AButton
        variant="secondary"
        size="sm"
        :disabled="meta.page >= meta.total_pages"
        @click="nextPage"
      >
        Next
      </AButton>
    </div>
  </nav>
</template>
