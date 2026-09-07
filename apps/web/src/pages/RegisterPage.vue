<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { ApiError } from '@/api/errors'
import { AButton, AInput, ACard, ALogo } from '@/components/ui'

const router = useRouter()
const authStore = useAuthStore()

const firstName = ref('')
const lastName = ref('')
const email = ref('')
const password = ref('')
const passwordConfirmation = ref('')
const organizationName = ref('')
const loading = ref(false)
const error = ref('')
const fieldErrors = ref<Record<string, string>>({})

function validate(): boolean {
  fieldErrors.value = {}
  if (!firstName.value.trim()) fieldErrors.value.first_name = 'First name is required'
  if (!lastName.value.trim()) fieldErrors.value.last_name = 'Last name is required'
  if (!email.value.trim()) fieldErrors.value.email = 'Email is required'
  if (!password.value) fieldErrors.value.password = 'Password is required'
  else if (password.value.length < 8) fieldErrors.value.password = 'Password must be at least 8 characters'
  if (password.value !== passwordConfirmation.value) {
    fieldErrors.value.password_confirmation = 'Passwords do not match'
  }
  if (!organizationName.value.trim()) fieldErrors.value.organization_name = 'Organization name is required'
  return Object.keys(fieldErrors.value).length === 0
}

function applyServerErrors(errors: Record<string, string[]>) {
  for (const [field, messages] of Object.entries(errors)) {
    fieldErrors.value[field] = messages[0]
  }
}

async function handleSubmit() {
  error.value = ''
  if (!validate()) return

  loading.value = true
  try {
    await authStore.register({
      first_name: firstName.value.trim(),
      last_name: lastName.value.trim(),
      email: email.value.trim(),
      password: password.value,
      password_confirmation: passwordConfirmation.value,
      organization_name: organizationName.value.trim(),
    })
    // Registration successful — redirect to login
    router.push({ name: 'login', query: { registered: 'true' } })
  } catch (err) {
    if (err instanceof ApiError) {
      error.value = err.detail
      if (err.errors) {
        applyServerErrors(err.errors)
      }
    } else {
      error.value = 'An unexpected error occurred'
    }
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-voceive-background px-4 py-8">
    <div class="w-full max-w-sm">
      <div class="mb-8 flex flex-col items-center">
        <ALogo variant="full" height="36px" class="mb-2" />
        <h1 class="sr-only">Create a Voceive account</h1>
        <p class="mt-1 text-sm text-voceive-text-secondary">
          Create your account
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

            <div class="grid grid-cols-2 gap-3">
              <AInput
                v-model="firstName"
                label="First name"
                placeholder="Jane"
                autocomplete="given-name"
                :error="fieldErrors.first_name"
                :disabled="loading"
              />
              <AInput
                v-model="lastName"
                label="Last name"
                placeholder="Doe"
                autocomplete="family-name"
                :error="fieldErrors.last_name"
                :disabled="loading"
              />
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
              placeholder="At least 8 characters"
              autocomplete="new-password"
              :error="fieldErrors.password"
              :disabled="loading"
            />

            <AInput
              v-model="passwordConfirmation"
              label="Confirm password"
              type="password"
              placeholder="Repeat your password"
              autocomplete="new-password"
              :error="fieldErrors.password_confirmation"
              :disabled="loading"
            />

            <AInput
              v-model="organizationName"
              label="Organization name"
              placeholder="Acme Inc"
              autocomplete="organization"
              :error="fieldErrors.organization_name"
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
              Create account
            </AButton>
          </div>
        </form>
      </ACard>

      <p class="mt-6 text-center text-sm text-voceive-text-muted">
        Already have an account?
        <RouterLink
          to="/login"
          class="voceive-focus-ring rounded font-medium text-voceive-brand hover:text-voceive-brand-hover transition-colors"
        >
          Sign in
        </RouterLink>
      </p>
    </div>
  </div>
</template>
