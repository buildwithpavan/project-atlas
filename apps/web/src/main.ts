import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router, { initGuard } from './router'
import { useAuthStore } from './stores/auth'
import App from './App.vue'
import './style.css'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)

// Initialize the auth store and wire the router guard
const authStore = useAuthStore()
initGuard(() => authStore)

// Attempt session restoration before the first navigation
router.isReady().then(async () => {
  await authStore.restoreSession()
})

app.mount('#app')
