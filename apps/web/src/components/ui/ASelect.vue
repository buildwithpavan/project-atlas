<script setup lang="ts">
const model = defineModel<string>({ default: '' })

withDefaults(defineProps<{
  label?: string
  options: { value: string; label: string }[]
  placeholder?: string
  error?: string
  disabled?: boolean
}>(), {
  label: '',
  placeholder: '',
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
    <select
      v-model="model"
      :disabled="disabled"
      class="atlas-focus-ring block w-full rounded-atlas border bg-atlas-surface px-3 py-2 text-sm text-atlas-text-primary transition-colors appearance-none"
      :class="[
        error
          ? 'border-atlas-error'
          : 'border-atlas-border hover:border-atlas-border-strong',
        { 'cursor-not-allowed bg-atlas-surface-muted text-atlas-text-disabled': disabled },
      ]"
    >
      <option
        v-if="placeholder"
        value=""
        disabled
      >
        {{ placeholder }}
      </option>
      <option
        v-for="opt in options"
        :key="opt.value"
        :value="opt.value"
      >
        {{ opt.label }}
      </option>
    </select>
    <p
      v-if="error"
      class="text-xs text-atlas-error"
    >
      {{ error }}
    </p>
  </div>
</template>
