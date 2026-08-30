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
      class="text-sm font-medium text-voceive-text-primary"
    >
      {{ label }}
    </label>
    <select
      v-model="model"
      :disabled="disabled"
      class="voceive-focus-ring block w-full rounded-voceive border bg-voceive-surface px-3 py-2 text-sm text-voceive-text-primary transition-colors appearance-none"
      :class="[
        error
          ? 'border-voceive-error'
          : 'border-voceive-border hover:border-voceive-border-strong',
        { 'cursor-not-allowed bg-voceive-surface-muted text-voceive-text-disabled': disabled },
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
      class="text-xs text-voceive-error"
    >
      {{ error }}
    </p>
  </div>
</template>
