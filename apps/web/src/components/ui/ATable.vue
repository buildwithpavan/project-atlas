<script setup lang="ts">
defineProps<{
  columns: { key: string; label: string; align?: 'left' | 'center' | 'right' }[]
  rows: Record<string, unknown>[]
}>()
</script>

<template>
  <div class="overflow-x-auto border border-voceive-border rounded-voceive-lg">
    <table class="min-w-full divide-y divide-voceive-border">
      <thead class="bg-voceive-surface-muted">
        <tr>
          <th
            v-for="col in columns"
            :key="col.key"
            class="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-voceive-text-muted"
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
      <tbody class="divide-y divide-voceive-border bg-voceive-surface">
        <tr
          v-for="(row, idx) in rows"
          :key="idx"
          class="hover:bg-voceive-surface-muted transition-colors"
        >
          <td
            v-for="col in columns"
            :key="col.key"
            class="whitespace-nowrap px-4 py-3 text-sm text-voceive-text-primary"
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
            class="px-4 py-8 text-center text-sm text-voceive-text-muted"
          >
            No data available
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
