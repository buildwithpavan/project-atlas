import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { setTokenAccessor, setRefreshHandler } from '@/api/client'
import * as authApi from '@/api/auth'
import type { LoginParams, RegisterParams } from '@/api/types'

export const useAuthStore = defineStore('auth', () => {
  const accessToken = ref<string | null>(null)
  const refreshToken = ref<string | null>(null)
  const isRestoring = ref(false)

  const isAuthenticated = computed(() => accessToken.value !== null)

  function setTokens(access: string, refresh: string): void {
    accessToken.value = access
    refreshToken.value = refresh
  }

  function clearAuth(): void {
    accessToken.value = null
    refreshToken.value = null
  }

  async function login(params: LoginParams): Promise<void> {
    const { data } = await authApi.login(params)
    setTokens(data.access_token, data.refresh_token)
  }

  async function register(params: RegisterParams): Promise<void> {
    await authApi.register(params)
    // Backend does not return tokens on register — user must login after
  }

  async function logout(): Promise<void> {
    const token = refreshToken.value
    clearAuth()
    if (token) {
      try {
        await authApi.logout(token)
      } catch {
        // Ignore errors — tokens are already cleared locally
      }
    }
  }

  /**
   * Attempt to restore the session by refreshing the access token.
   * Called on app mount. Returns true if restoration succeeded.
   */
  async function restoreSession(): Promise<boolean> {
    const token = refreshToken.value
    if (!token) return false

    isRestoring.value = true
    try {
      const { data } = await authApi.refresh(token)
      setTokens(data.access_token, data.refresh_token)
      return true
    } catch {
      clearAuth()
      return false
    } finally {
      isRestoring.value = false
    }
  }

  /**
   * Attempt a single token refresh. Used by the API client's 401 handler.
   * Returns true if refresh succeeded and new tokens are set.
   */
  async function attemptRefresh(): Promise<boolean> {
    const token = refreshToken.value
    if (!token) return false

    try {
      const { data } = await authApi.refresh(token)
      setTokens(data.access_token, data.refresh_token)
      return true
    } catch {
      clearAuth()
      return false
    }
  }

  // Wire the API client integrations
  setTokenAccessor(() => accessToken.value)
  setRefreshHandler(() => attemptRefresh())

  return {
    accessToken,
    refreshToken,
    isAuthenticated,
    isRestoring,
    setTokens,
    clearAuth,
    login,
    register,
    logout,
    restoreSession,
    attemptRefresh,
  }
})
