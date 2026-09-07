<template>
  <div class="flex flex-col items-center justify-center py-16 text-center">
    <div class="size-16 rounded-full bg-voceive-ai-subtle flex items-center justify-center mb-4">
      <svg
        class="size-8 text-voceive-ai"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.5"
        aria-hidden="true"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5m.75-9l3-3 2.148 2.148A12.061 12.061 0 0116.5 7.605"
        />
      </svg>
    </div>
    <h2 class="text-lg font-semibold text-voceive-text-primary">
      No AI usage yet
    </h2>
    <p class="mt-2 max-w-sm text-sm text-voceive-text-muted">
      Start using Ask Voceive to see your organization's AI usage here.
    </p>
    <RouterLink
      to="/app/ask"
      class="voceive-focus-ring mt-5 inline-flex items-center rounded-voceive px-4 py-2 text-sm font-medium bg-voceive-ai text-white hover:opacity-90 transition-colors"
    >
      Try Ask Voceive
    </RouterLink>
  </div>
</template>
