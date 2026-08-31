<template>
  <div>
    <!-- Header skeleton -->
    <div>
      <div class="h-7 w-40 animate-pulse rounded bg-voceive-surface-muted" />
      <div class="mt-2 h-4 w-72 animate-pulse rounded bg-voceive-surface-muted" />
    </div>

    <!-- Quota cards skeleton -->
    <div class="mt-6 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <div
        v-for="i in 3"
        :key="i"
        class="bg-voceive-surface border border-voceive-border rounded-voceive-lg p-5 shadow-voceive-sm"
      >
        <div class="h-4 w-24 animate-pulse rounded bg-voceive-surface-muted" />
        <div class="mt-3 h-8 w-20 animate-pulse rounded bg-voceive-surface-muted" />
        <div class="mt-3 h-2 w-full animate-pulse rounded-full bg-voceive-surface-muted" />
        <div class="mt-2 h-3 w-32 animate-pulse rounded bg-voceive-surface-muted" />
      </div>
    </div>

    <!-- Breakdown skeleton -->
    <div class="mt-6 grid grid-cols-1 lg:grid-cols-2 gap-4">
      <div class="bg-voceive-surface border border-voceive-border rounded-voceive-lg p-5 shadow-voceive-sm">
        <div class="h-4 w-36 animate-pulse rounded bg-voceive-surface-muted" />
        <div class="mt-4 space-y-3">
          <div v-for="i in 3" :key="i">
            <div class="h-3 w-28 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="mt-1 h-6 w-16 animate-pulse rounded bg-voceive-surface-muted" />
          </div>
        </div>
      </div>
      <div class="bg-voceive-surface border border-voceive-border rounded-voceive-lg p-5 shadow-voceive-sm">
        <div class="h-4 w-32 animate-pulse rounded bg-voceive-surface-muted" />
        <div class="mt-4 space-y-3">
          <div v-for="i in 2" :key="i">
            <div class="h-3 w-24 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="mt-1 h-6 w-20 animate-pulse rounded bg-voceive-surface-muted" />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
