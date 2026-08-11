<script setup lang="ts">
defineProps<{
  columns: { key: string; label: string; align?: 'left' | 'center' | 'right' }[]
  rows: Record<string, unknown>[]
}>()
</script>

<template>
  <div class="overflow-x-auto border border-atlas-border rounded-atlas-lg">
    <table class="min-w-full divide-y divide-atlas-border">
      <thead class="bg-atlas-surface-muted">
        <tr>
          <th
            v-for="col in columns"
            :key="col.key"
            class="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-atlas-text-muted"
            :class="{
              'text-left': !col.align || col.align === 'left',
              'text-center': col.align === 'center',
              'text-right': col.align === 'right',
            }"
          >
            {{ col.label }}
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-atlas-border bg-atlas-surface">
        <tr
          v-for="(row, idx) in rows"
          :key="idx"
          class="hover:bg-atlas-surface-muted transition-colors"
        >
          <td
            v-for="col in columns"
            :key="col.key"
            class="whitespace-nowrap px-4 py-3 text-sm text-atlas-text-primary"
            :class="{
              'text-left': !col.align || col.align === 'left',
              'text-center': col.align === 'center',
              'text-right': col.align === 'right',
            }"
          >
            <slot
              :name="`cell-${col.key}`"
              :row="row"
              :value="row[col.key]"
            >
              {{ row[col.key] }}
            </slot>
          </td>
        </tr>
        <tr v-if="rows.length === 0">
          <td
            :colspan="columns.length"
            class="px-4 py-8 text-center text-sm text-atlas-text-muted"
          >
            No data available
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
