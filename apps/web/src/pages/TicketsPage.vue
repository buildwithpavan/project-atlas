<script setup lang="ts">
import { ref, watch, onMounted, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import * as ticketsApi from '@/api/tickets'
import type { Ticket, PaginationMeta } from '@/api/types'
import { ApiError } from '@/api/errors'
import { AButton } from '@/components/ui'
import TicketFilters from '@/components/tickets/TicketFilters.vue'
import TicketTable from '@/components/tickets/TicketTable.vue'
import TicketPagination from '@/components/tickets/TicketPagination.vue'

const router = useRouter()
const route = useRoute()

// -- Filter state from URL query params ------------------------------------
const search = ref((route.query.search as string) || '')
const status = ref((route.query.status as string) || '')
const priority = ref((route.query.priority as string) || '')
const page = ref(Number(route.query.page) || 1)

// -- Data ------------------------------------------------------------------
const tickets = ref<Ticket[]>([])
const meta = ref<PaginationMeta | null>(null)
const loading = ref(true)
const error = ref<string | null>(null)

const hasActiveFilters = computed(() =>
  !!(search.value || status.value || priority.value),
)

const isFilteredEmpty = computed(() =>
  !loading.value && !error.value && tickets.value.length === 0 && hasActiveFilters.value,
)

const isOrgEmpty = computed(() =>
  !loading.value && !error.value && tickets.value.length === 0 && !hasActiveFilters.value,
)

// -- Fetch -----------------------------------------------------------------
async function fetchTickets() {
  loading.value = true
  error.value = null
  try {
    const res = await ticketsApi.list({
      search: search.value || undefined,
      status: status.value || undefined,
      priority: priority.value || undefined,
      page: page.value,
      per_page: 20,
    })
    tickets.value = res.data
    meta.value = res.meta
  } catch (err) {
    if (err instanceof ApiError) {
      error.value = err.detail
    } else {
      error.value = 'Unable to load tickets.'
    }
  } finally {
    loading.value = false
  }
}

// -- URL sync --------------------------------------------------------------
function syncUrl() {
  const query: Record<string, string> = {}
  if (search.value) query.search = search.value
  if (status.value) query.status = status.value
  if (priority.value) query.priority = priority.value
  if (page.value > 1) query.page = String(page.value)
  router.replace({ query })
}

// -- Debounced search ------------------------------------------------------
let debounceTimer: number | undefined

function onSearchChange(val: string) {
  search.value = val
  page.value = 1
  globalThis.clearTimeout(debounceTimer)
  debounceTimer = globalThis.setTimeout(() => {
    syncUrl()
    fetchTickets()
  }, 300)
}

// -- Filter/page handlers --------------------------------------------------
function onStatusChange(val: string) {
  status.value = val
  page.value = 1
  syncUrl()
  fetchTickets()
}

function onPriorityChange(val: string) {
  priority.value = val
  page.value = 1
  syncUrl()
  fetchTickets()
}

function onPageChange(p: number) {
  page.value = p
  syncUrl()
  fetchTickets()
}

function clearFilters() {
  search.value = ''
  status.value = ''
  priority.value = ''
  page.value = 1
  syncUrl()
  fetchTickets()
}

function onSelectTicket(ticket: Ticket) {
  router.push({ name: 'ticket-detail', params: { id: ticket.id } })
}

// -- Init ------------------------------------------------------------------
onMounted(fetchTickets)

// Watch for browser back/forward
watch(
  () => route.query,
  (q) => {
    const newSearch = (q.search as string) || ''
    const newStatus = (q.status as string) || ''
    const newPriority = (q.priority as string) || ''
    const newPage = Number(q.page) || 1

    if (
      newSearch !== search.value
      || newStatus !== status.value
      || newPriority !== priority.value
      || newPage !== page.value
    ) {
      search.value = newSearch
      status.value = newStatus
      priority.value = newPriority
      page.value = newPage
      fetchTickets()
    }
  },
)
</script>

<template>
  <div>
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-2 mb-6">
      <div>
        <h1 class="text-2xl font-semibold text-atlas-text-primary">
          Tickets
        </h1>
        <p class="mt-1 text-sm text-atlas-text-muted">
          Explore the customer conversations behind your insights.
        </p>
      </div>
    </div>

    <!-- Filters -->
    <TicketFilters
      :search="search"
      :status="status"
      :priority="priority"
      :has-active-filters="hasActiveFilters"
      @update:search="onSearchChange"
      @update:status="onStatusChange"
      @update:priority="onPriorityChange"
      @clear="clearFilters"
    />

    <!-- Loading skeleton -->
    <div
      v-if="loading"
      class="mt-4"
    >
      <div class="hidden md:block border border-atlas-border rounded-atlas-lg overflow-hidden">
        <div class="bg-atlas-surface-muted px-4 py-3">
          <div class="h-3 w-full animate-pulse rounded bg-atlas-surface-muted" />
        </div>
        <div class="divide-y divide-atlas-border">
          <div
            v-for="i in 8"
            :key="i"
            class="flex gap-4 px-4 py-3"
          >
            <div class="h-4 flex-[3] animate-pulse rounded bg-atlas-surface-muted" />
            <div class="h-4 flex-[2] animate-pulse rounded bg-atlas-surface-muted" />
            <div class="h-4 flex-1 animate-pulse rounded bg-atlas-surface-muted" />
            <div class="h-4 flex-1 animate-pulse rounded bg-atlas-surface-muted" />
            <div class="h-4 flex-1 animate-pulse rounded bg-atlas-surface-muted" />
            <div class="h-4 flex-1 animate-pulse rounded bg-atlas-surface-muted" />
          </div>
        </div>
      </div>
      <div class="md:hidden space-y-3">
        <div
          v-for="i in 5"
          :key="i"
          class="bg-atlas-surface border border-atlas-border rounded-atlas-lg p-4"
        >
          <div class="h-4 w-3/4 animate-pulse rounded bg-atlas-surface-muted" />
          <div class="mt-2 h-3 w-1/3 animate-pulse rounded bg-atlas-surface-muted" />
          <div class="mt-2 flex gap-2">
            <div class="h-5 w-12 animate-pulse rounded-atlas-full bg-atlas-surface-muted" />
            <div class="h-5 w-14 animate-pulse rounded-atlas-full bg-atlas-surface-muted" />
          </div>
        </div>
      </div>
    </div>

    <!-- Error state -->
    <div
      v-else-if="error"
      role="alert"
      class="mt-4 flex flex-col items-center justify-center py-16 text-center"
    >
      <div class="size-16 rounded-full bg-atlas-error-subtle flex items-center justify-center mb-4">
        <svg
          class="size-8 text-atlas-error"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
          />
        </svg>
      </div>
      <h2 class="text-lg font-semibold text-atlas-text-primary">
        Unable to load tickets
      </h2>
      <p class="mt-2 max-w-sm text-sm text-atlas-text-muted">
        {{ error }}
      </p>
      <AButton
        variant="secondary"
        size="md"
        class="mt-4"
        @click="fetchTickets"
      >
        Try again
      </AButton>
    </div>

    <!-- Empty: organization has no tickets -->
    <div
      v-else-if="isOrgEmpty"
      class="mt-4 flex flex-col items-center justify-center py-16 text-center"
    >
      <div class="size-16 rounded-full bg-atlas-brand-subtle flex items-center justify-center mb-4">
        <svg
          class="size-8 text-atlas-brand"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
          />
        </svg>
      </div>
      <h2 class="text-lg font-semibold text-atlas-text-primary">
        No tickets yet
      </h2>
      <p class="mt-2 max-w-sm text-sm text-atlas-text-muted">
        Import customer tickets to start exploring customer conversations and AI insights.
      </p>
    </div>

    <!-- Empty: filters returned nothing -->
    <div
      v-else-if="isFilteredEmpty"
      class="mt-4 flex flex-col items-center justify-center py-16 text-center"
    >
      <h2 class="text-lg font-semibold text-atlas-text-primary">
        No tickets match your filters
      </h2>
      <p class="mt-2 text-sm text-atlas-text-muted">
        Try adjusting your search or filters.
      </p>
      <AButton
        variant="secondary"
        size="md"
        class="mt-4"
        @click="clearFilters"
      >
        Clear filters
      </AButton>
    </div>

    <!-- Ticket list + pagination -->
    <template v-else>
      <div class="mt-4">
        <TicketTable
          :tickets="tickets"
          @select="onSelectTicket"
        />
      </div>
      <div
        v-if="meta"
        class="mt-4"
      >
        <TicketPagination
          :meta="meta"
          @page="onPageChange"
        />
      </div>
    </template>
  </div>
</template>
