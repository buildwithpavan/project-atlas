<script setup lang="ts">
import { computed } from 'vue'

const model = defineModel<string>({ default: '' })

const props = withDefaults(defineProps<{
  label?: string
  placeholder?: string
  type?: string
  error?: string
  disabled?: boolean
  autocomplete?: string
  id?: string
}>(), {
  label: '',
  placeholder: '',
  type: 'text',
  error: '',
  disabled: false,
  autocomplete: undefined,
  id: undefined,
})

let counter = 0
const inputId = computed(() => props.id ?? `a-input-${++counter}`)
</script>

<template>
  <div class="flex flex-col gap-1.5">
    <label
      v-if="label"
      :for="inputId"
      class="text-sm font-medium text-atlas-text-primary"
    >
      {{ label }}
    </label>
    <input
      :id="inputId"
      v-model="model"
      :type="type"
      :placeholder="placeholder"
      :disabled="disabled"
      :autocomplete="autocomplete"
      :aria-invalid="!!error"
      :aria-describedby="error ? `${inputId}-error` : undefined"
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
      :id="`${inputId}-error`"
      role="alert"
      class="text-xs text-atlas-error"
    >
      {{ error }}
    </p>
  </div>
</template>
