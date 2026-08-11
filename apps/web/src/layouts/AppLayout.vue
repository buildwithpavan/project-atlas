<script setup lang="ts">
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const sidebarOpen = ref(false)

function toggleSidebar() {
  sidebarOpen.value = !sidebarOpen.value
}

function closeSidebar() {
  sidebarOpen.value = false
}

async function handleLogout() {
  await authStore.logout()
  router.push({ name: 'login' })
}

const navItems = [
  { name: 'dashboard', label: 'Dashboard', path: '/app/dashboard' },
  { name: 'tickets', label: 'Tickets', path: '/app/tickets' },
  { name: 'reports', label: 'Reports', path: '/app/reports' },
  { name: 'import', label: 'Import Data', path: '/app/import' },
]

function isActive(name: string): boolean {
  return route.name === name
}
</script>

<template>
  <div class="min-h-screen bg-atlas-background">
    <!-- Mobile backdrop -->
    <div
      v-if="sidebarOpen"
      class="fixed inset-0 z-30 bg-black/30 lg:hidden"
      @click="closeSidebar"
    />

    <!-- Sidebar -->
    <aside
      class="fixed inset-y-0 left-0 z-40 flex w-60 flex-col border-r border-atlas-border bg-atlas-surface transition-transform lg:translate-x-0"
      :class="sidebarOpen ? 'translate-x-0' : '-translate-x-full'"
      aria-label="Main navigation"
    >
      <!-- Logo -->
      <div class="flex h-14 items-center border-b border-atlas-border px-5">
        <span class="text-lg font-bold text-atlas-brand">Atlas</span>
      </div>

      <!-- Nav links -->
      <nav class="flex-1 px-3 py-4 space-y-1">
        <RouterLink
          v-for="item in navItems"
          :key="item.name"
          :to="item.path"
          class="atlas-focus-ring flex items-center gap-3 rounded-atlas px-3 py-2 text-sm font-medium transition-colors"
          :class="
            isActive(item.name)
              ? 'bg-atlas-brand-subtle text-atlas-brand'
              : 'text-atlas-text-secondary hover:bg-atlas-surface-muted hover:text-atlas-text-primary'
          "
          @click="closeSidebar"
        >
          {{ item.label }}
        </RouterLink>
      </nav>
    </aside>

    <!-- Main area -->
    <div class="lg:pl-60">
      <!-- Header -->
      <header class="sticky top-0 z-20 flex h-14 items-center border-b border-atlas-border bg-atlas-surface px-4 lg:px-6">
        <!-- Mobile menu button -->
        <button
          type="button"
          class="atlas-focus-ring -ml-1 mr-3 rounded-atlas p-1.5 text-atlas-text-secondary hover:bg-atlas-surface-muted lg:hidden"
          aria-label="Open navigation menu"
          @click="toggleSidebar"
        >
          <svg
            class="size-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 6h16M4 12h16M4 18h16"
            />
          </svg>
        </button>

        <div class="flex-1" />

        <!-- User area -->
        <button
          type="button"
          class="atlas-focus-ring rounded-atlas px-3 py-1.5 text-sm text-atlas-text-secondary hover:bg-atlas-surface-muted hover:text-atlas-text-primary transition-colors"
          @click="handleLogout"
        >
          Sign out
        </button>
      </header>

      <!-- Page content -->
      <main class="p-4 lg:p-6">
        <RouterView />
      </main>
    </div>
  </div>
</template>
