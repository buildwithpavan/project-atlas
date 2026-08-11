import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { setTokenAccessor } from '@/api/client'

/**
 * Minimal auth store — holds the JWT access token and refresh token.
 *
 * The access token is kept in memory only (not localStorage) to reduce
 * XSS exposure. The refresh token is stored so the user can remain
 * authenticated across API calls within a session.
 *
 * On creation the store registers a token accessor with the API client
 * so every authenticated request automatically receives the current JWT.
 */
export const useAuthStore = defineStore('auth', () => {
  const accessToken = ref<string | null>(null)
  const refreshToken = ref<string | null>(null)

  const isAuthenticated = computed(() => accessToken.value !== null)

  function setTokens(access: string, refresh: string): void {
    accessToken.value = access
    refreshToken.value = refresh
  }

  function clearAuth(): void {
    accessToken.value = null
    refreshToken.value = null
  }

  // Wire token accessor so the API client can read the current JWT
  setTokenAccessor(() => accessToken.value)

  return {
    accessToken,
    refreshToken,
    isAuthenticated,
    setTokens,
    clearAuth,
  }
})
