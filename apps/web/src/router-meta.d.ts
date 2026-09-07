import 'vue-router'

declare module 'vue-router' {
  interface RouteMeta {
    /** Route is accessible without authentication */
    public?: boolean
    /** Redirect authenticated users away (e.g. login/register pages) */
    authRedirect?: boolean
  }
}
