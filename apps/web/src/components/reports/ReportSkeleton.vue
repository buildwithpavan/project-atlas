<template>
  <div>
    <!-- Header skeleton -->
    <div>
      <div class="h-7 w-64 animate-pulse rounded bg-voceive-surface-muted" />
      <div class="mt-2 h-4 w-80 animate-pulse rounded bg-voceive-surface-muted" />
    </div>

    <!-- Executive overview skeleton -->
    <div class="mt-6 grid grid-cols-1 sm:grid-cols-3 gap-4">
      <div
        v-for="i in 3"
        :key="i"
        class="bg-voceive-surface border border-voceive-border rounded-voceive-lg p-5 shadow-voceive-sm"
      >
        <div class="h-4 w-20 animate-pulse rounded bg-voceive-surface-muted" />
        <div class="mt-3 h-8 w-16 animate-pulse rounded bg-voceive-surface-muted" />
        <div class="mt-2 h-3 w-28 animate-pulse rounded bg-voceive-surface-muted" />
      </div>
    </div>

    <!-- Sentiment + categories skeleton -->
    <div class="mt-6 grid grid-cols-1 lg:grid-cols-2 gap-4">
      <div class="bg-voceive-surface border border-voceive-border rounded-voceive-lg p-5 shadow-voceive-sm">
        <div class="h-4 w-32 animate-pulse rounded bg-voceive-surface-muted" />
        <div class="mt-6 flex items-center justify-center gap-8">
          <div class="size-36 animate-pulse rounded-full bg-voceive-surface-muted" />
          <div class="space-y-3">
            <div class="h-4 w-24 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="h-4 w-20 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="h-4 w-16 animate-pulse rounded bg-voceive-surface-muted" />
          </div>
        </div>
      </div>
      <div class="bg-voceive-surface border border-voceive-border rounded-voceive-lg p-5 shadow-voceive-sm">
        <div class="h-4 w-48 animate-pulse rounded bg-voceive-surface-muted" />
        <div class="mt-4 space-y-4">
          <div
            v-for="i in 4"
            :key="i"
          >
            <div class="h-3 w-24 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="mt-1 h-2 w-full animate-pulse rounded bg-voceive-surface-muted" />
          </div>
        </div>
      </div>
    </div>

    <!-- Signals skeleton -->
    <div class="mt-6 grid grid-cols-1 sm:grid-cols-3 gap-4">
      <div
        v-for="i in 3"
        :key="i"
        class="bg-voceive-surface border border-voceive-border rounded-voceive-lg p-5 shadow-voceive-sm"
      >
        <div class="h-4 w-24 animate-pulse rounded bg-voceive-surface-muted" />
        <div class="mt-3 h-7 w-12 animate-pulse rounded bg-voceive-surface-muted" />
        <div class="mt-2 h-3 w-32 animate-pulse rounded bg-voceive-surface-muted" />
      </div>
    </div>

    <!-- Status/priority skeleton -->
    <div class="mt-6 grid grid-cols-1 lg:grid-cols-2 gap-4">
      <div
        v-for="i in 2"
        :key="i"
        class="bg-voceive-surface border border-voceive-border rounded-voceive-lg p-5 shadow-voceive-sm"
      >
        <div class="h-4 w-36 animate-pulse rounded bg-voceive-surface-muted" />
        <div class="mt-4 space-y-3">
          <div
            v-for="j in 3"
            :key="j"
          >
            <div class="h-3 w-20 animate-pulse rounded bg-voceive-surface-muted" />
            <div class="mt-1 h-2 w-full animate-pulse rounded bg-voceive-surface-muted" />
          </div>
        </div>
      </div>
    </div>

    <!-- Timeline skeleton -->
    <div class="mt-6 bg-voceive-surface border border-voceive-border rounded-voceive-lg p-5 shadow-voceive-sm">
      <div class="h-4 w-28 animate-pulse rounded bg-voceive-surface-muted" />
      <div class="mt-4 flex items-end gap-1 h-32">
        <div
          v-for="i in 8"
          :key="i"
          class="flex-1 animate-pulse rounded-t bg-voceive-surface-muted"
          :style="{ height: `${20 + (i % 3) * 25}%` }"
        />
      </div>
    </div>
  </div>
</template>
