<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { ApiError } from '@/api/errors'
import { AButton, AInput, ACard, ALogo } from '@/components/ui'

const router = useRouter()
const authStore = useAuthStore()

const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
const fieldErrors = ref<Record<string, string>>({})

function validate(): boolean {
  fieldErrors.value = {}
  if (!email.value.trim()) {
    fieldErrors.value.email = 'Email is required'
  }
  if (!password.value) {
    fieldErrors.value.password = 'Password is required'
  }
  return Object.keys(fieldErrors.value).length === 0
}

async function handleSubmit() {
  error.value = ''
  if (!validate()) return

  loading.value = true
  try {
    await authStore.login({ email: email.value.trim(), password: password.value })
    router.push({ name: 'dashboard' })
  } catch (err) {
    if (err instanceof ApiError) {
      error.value = err.detail
    } else {
      error.value = 'An unexpected error occurred'
    }
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-voceive-background px-4">
    <div class="w-full max-w-sm">
      <div class="mb-8 flex flex-col items-center">
        <ALogo variant="full" height="36px" class="mb-2" />
        <h1 class="sr-only">Sign in to Voceive</h1>
        <p class="mt-1 text-sm text-voceive-text-secondary">
          Sign in to your account
        </p>
      </div>

      <ACard>
        <form
          novalidate
          @submit.prevent="handleSubmit"
        >
          <div class="space-y-4">
            <div
              v-if="error"
              role="alert"
              class="rounded-voceive bg-voceive-error-subtle border border-voceive-error/20 px-4 py-3 text-sm text-voceive-error"
            >
              {{ error }}
            </div>

            <AInput
              v-model="email"
              label="Email address"
              type="email"
              placeholder="you@company.com"
              autocomplete="email"
              :error="fieldErrors.email"
              :disabled="loading"
            />

            <AInput
              v-model="password"
              label="Password"
              type="password"
              placeholder="Enter your password"
              autocomplete="current-password"
              :error="fieldErrors.password"
              :disabled="loading"
            />

            <AButton
              type="submit"
              variant="primary"
              size="lg"
              :loading="loading"
              :disabled="loading"
              class="w-full"
            >
              Sign in
            </AButton>
          </div>
        </form>
      </ACard>

      <p class="mt-6 text-center text-sm text-voceive-text-muted">
        Don't have an account?
        <RouterLink
          to="/register"
          class="voceive-focus-ring rounded font-medium text-voceive-brand hover:text-voceive-brand-hover transition-colors"
        >
          Create one
        </RouterLink>
      </p>
    </div>
  </div>
</template>
