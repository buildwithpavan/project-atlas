<template>
  <div class="flex flex-col items-center justify-center py-16 text-center">
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
      No customer feedback yet
    </h2>
    <p class="mt-2 max-w-sm text-sm text-atlas-text-muted">
      Import customer tickets to see sentiment analysis, category insights, and actionable signals on your dashboard.
    </p>
    <RouterLink
      to="/app/import"
      class="atlas-focus-ring mt-5 inline-flex items-center rounded-atlas px-4 py-2 text-sm font-medium bg-atlas-brand text-white hover:bg-atlas-brand-hover transition-colors"
    >
      Import Data
    </RouterLink>
  </div>
</template>
