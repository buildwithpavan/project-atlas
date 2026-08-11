<template>
  <div>
    <!-- Header skeleton -->
    <div>
      <div class="h-7 w-56 animate-pulse rounded bg-atlas-surface-muted" />
      <div class="mt-2 h-4 w-80 animate-pulse rounded bg-atlas-surface-muted" />
    </div>

    <!-- KPI cards skeleton -->
    <div class="mt-6 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <div
        v-for="i in 4"
        :key="i"
        class="bg-atlas-surface border border-atlas-border rounded-atlas-lg p-5 shadow-atlas-sm"
      >
        <div class="h-4 w-20 animate-pulse rounded bg-atlas-surface-muted" />
        <div class="mt-3 h-8 w-16 animate-pulse rounded bg-atlas-surface-muted" />
        <div class="mt-2 h-3 w-28 animate-pulse rounded bg-atlas-surface-muted" />
      </div>
    </div>

    <!-- Charts skeleton -->
    <div class="mt-6 grid grid-cols-1 lg:grid-cols-2 gap-4">
      <div class="bg-atlas-surface border border-atlas-border rounded-atlas-lg p-5 shadow-atlas-sm">
        <div class="h-4 w-32 animate-pulse rounded bg-atlas-surface-muted" />
        <div class="mt-6 flex items-center justify-center gap-8">
          <div class="size-36 animate-pulse rounded-full bg-atlas-surface-muted" />
          <div class="space-y-3">
            <div class="h-4 w-24 animate-pulse rounded bg-atlas-surface-muted" />
            <div class="h-4 w-20 animate-pulse rounded bg-atlas-surface-muted" />
            <div class="h-4 w-16 animate-pulse rounded bg-atlas-surface-muted" />
          </div>
        </div>
      </div>
      <div class="bg-atlas-surface border border-atlas-border rounded-atlas-lg p-5 shadow-atlas-sm">
        <div class="h-4 w-48 animate-pulse rounded bg-atlas-surface-muted" />
        <div class="mt-4 space-y-4">
          <div
            v-for="i in 4"
            :key="i"
          >
            <div class="h-3 w-24 animate-pulse rounded bg-atlas-surface-muted" />
            <div class="mt-1 h-2 w-full animate-pulse rounded bg-atlas-surface-muted" />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
