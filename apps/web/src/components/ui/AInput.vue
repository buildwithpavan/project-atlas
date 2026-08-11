<script setup lang="ts">
const model = defineModel<string>({ default: '' })

withDefaults(defineProps<{
  label?: string
  placeholder?: string
  type?: string
  error?: string
  disabled?: boolean
}>(), {
  label: '',
  placeholder: '',
  type: 'text',
  error: '',
  disabled: false,
})
</script>

<template>
  <div class="flex flex-col gap-1.5">
    <label
      v-if="label"
      class="text-sm font-medium text-atlas-text-primary"
    >
      {{ label }}
    </label>
    <input
      v-model="model"
      :type="type"
      :placeholder="placeholder"
      :disabled="disabled"
      class="atlas-focus-ring block w-full rounded-atlas border bg-atlas-surface px-3 py-2 text-sm text-atlas-text-primary placeholder:text-atlas-text-muted transition-colors"
      :class="[
        error
          ? 'border-atlas-error'
          : 'border-atlas-border hover:border-atlas-border-strong',
        { 'cursor-not-allowed bg-atlas-surface-muted text-atlas-text-disabled': disabled },
      ]"
    >
    <p
      v-if="error"
      class="text-xs text-atlas-error"
    >
      {{ error }}
    </p>
  </div>
</template>
