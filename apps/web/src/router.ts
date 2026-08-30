import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  // Public auth routes
  {
    path: '/login',
    name: 'login',
    component: () => import('@/pages/LoginPage.vue'),
    meta: { public: true, authRedirect: true },
  },
  {
    path: '/register',
    name: 'register',
    component: () => import('@/pages/RegisterPage.vue'),
    meta: { public: true, authRedirect: true },
  },
  // Design system (public, no auth redirect)
  {
    path: '/design-system',
    name: 'design-system',
    component: () => import('@/pages/DesignSystemPage.vue'),
    meta: { public: true },
  },
  // Protected app routes
  {
    path: '/app',
    component: () => import('@/layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        redirect: { name: 'dashboard' },
      },
      {
        path: 'dashboard',
        name: 'dashboard',
        component: () => import('@/pages/DashboardPage.vue'),
      },
      {
        path: 'tickets',
        name: 'tickets',
        component: () => import('@/pages/TicketsPage.vue'),
      },
      {
        path: 'tickets/:id',
        name: 'ticket-detail',
        component: () => import('@/pages/TicketDetailPage.vue'),
      },
      {
        path: 'reports',
        name: 'reports',
        component: () => import('@/pages/ReportsPage.vue'),
      },
      {
        path: 'themes',
        name: 'themes',
        component: () => import('@/pages/ThemesPage.vue'),
      },
      {
        path: 'themes/:id',
        name: 'theme-detail',
        component: () => import('@/pages/ThemeDetailPage.vue'),
      },
      {
        path: 'knowledge-base',
        name: 'knowledge-base',
        component: () => import('@/pages/KnowledgeBasePage.vue'),
      },
      {
        path: 'ask',
        name: 'ask-voceive',
        component: () => import('@/pages/AskVoceivePage.vue'),
      },
      {
        path: 'import',
        name: 'import',
        component: () => import('@/pages/ImportPage.vue'),
      },
    ],
  },
  // Root redirect
  {
    path: '/',
    redirect: '/app/dashboard',
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

/**
 * Navigation guard.
 *
 * - Public routes (meta.public) are always accessible.
 * - If an authenticated user visits a route with meta.authRedirect
 *   (login/register), redirect them into the app.
 * - All other routes require authentication. Unauthenticated users
 *   are redirected to /login.
 *
 * Auth state is read lazily via the callback set by initGuard()
 * so that the store does not need to be imported at module level
 * (which would create circular dependencies with Pinia).
 */
let getAuthState: (() => { isAuthenticated: boolean }) | null = null

export function initGuard(accessor: () => { isAuthenticated: boolean }): void {
  getAuthState = accessor
}

router.beforeEach((to) => {
  const auth = getAuthState?.()
  const isPublic = to.meta.public === true
  const authRedirect = to.meta.authRedirect === true

  if (isPublic) {
    // Authenticated user on login/register → redirect to app
    if (authRedirect && auth?.isAuthenticated) {
      return { name: 'dashboard' }
    }
    return true
  }

  // Protected route — require authentication
  if (!auth?.isAuthenticated) {
    return { name: 'login' }
  }

  return true
})

export default router
