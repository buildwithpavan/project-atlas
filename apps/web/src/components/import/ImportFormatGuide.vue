<template>
  <div class="rounded-atlas border border-atlas-border bg-atlas-surface px-5 py-4">
    <h3 class="text-sm font-semibold text-atlas-text-primary mb-3">
      Expected CSV columns
    </h3>

    <div class="space-y-2">
      <div>
        <p class="text-xs font-medium text-atlas-text-secondary uppercase tracking-wide mb-1">
          Required
        </p>
        <span class="inline-block rounded-atlas-sm bg-atlas-brand-subtle px-2 py-0.5 text-xs font-medium text-atlas-brand">
          subject
        </span>
      </div>

      <div>
        <p class="text-xs font-medium text-atlas-text-secondary uppercase tracking-wide mb-1">
          Optional
        </p>
        <div class="flex flex-wrap gap-1.5">
          <span
            v-for="col in optionalColumns"
            :key="col"
            class="inline-block rounded-atlas-sm bg-atlas-surface-muted px-2 py-0.5 text-xs text-atlas-text-secondary"
          >
            {{ col }}
          </span>
        </div>
      </div>
    </div>

    <div class="mt-3 rounded-atlas-sm bg-atlas-surface-muted px-3 py-2">
      <p class="text-xs text-atlas-text-muted font-mono">
        subject,description,customer_name,customer_email,priority,status,category
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
const optionalColumns = [
  'description',
  'customer_name',
  'customer_email',
  'priority',
  'status',
  'category',
]
</script>
