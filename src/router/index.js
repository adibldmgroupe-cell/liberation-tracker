import { createRouter, createWebHashHistory } from 'vue-router'
import { supabase } from '../supabase'

const routes = [
  { path: '/login', name: 'Login', component: () => import('../pages/LoginPage.vue') },
  {
    path: '/',
    component: () => import('../layouts/AppLayout.vue'),
    meta: { requiresAuth: true },
    children: [
      { path: '', redirect: '/dashboard' },
      { path: 'dashboard', name: 'Dashboard', component: () => import('../pages/DashboardPage.vue') },
      { path: 'products', name: 'Products', component: () => import('../pages/ProductsPage.vue') },
      { path: 'products/:id', name: 'ProductDetail', component: () => import('../pages/ProductDetailPage.vue') },
      { path: 'lots', name: 'Lots', component: () => import('../pages/LotsPage.vue') },
      { path: 'lots/:id', name: 'LotDetail', component: () => import('../pages/LotDetailPage.vue') },
      { path: 'lots/:lotId/documents/:docId', name: 'DocumentDetail', component: () => import('../pages/DocumentDetailPage.vue') },
      { path: 'import', name: 'Import', component: () => import('../pages/ImportPage.vue') },
      { path: 'planifier', name: 'Planifier', component: () => import('../pages/PlanifierPage.vue') },
{ path: 'notifications', name: 'Notifications', component: () => import('../pages/NotificationsPage.vue') },
      { path: 'tasks', name: 'Tasks', component: () => import('../pages/TasksPage.vue') },
      // Routes administration — réservées au service 'admin'
      { path: 'admin/users', name: 'AdminUsers', component: () => import('../pages/AdminUsersPage.vue'), meta: { requiresAdmin: true } },
      { path: 'admin/permissions', name: 'AdminPermissions', component: () => import('../pages/AdminPermissionsPage.vue'), meta: { requiresAdmin: true } },
    ],
  },
]

const router = createRouter({ history: createWebHashHistory(), routes })

router.beforeEach(async (to) => {
  if (!to.meta.requiresAuth) return

  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return '/login'

  // Vérification du profil : compte actif + service admin si nécessaire
  const { data: profile } = await supabase
    .from('profiles')
    .select('is_active, service')
    .eq('id', session.user.id)
    .single()

  // Compte désactivé : déconnexion et redirection
  if (!profile || !profile.is_active) {
    await supabase.auth.signOut()
    return '/login'
  }

  // Route admin réservée au service 'admin'
  if (to.meta.requiresAdmin && profile.service !== 'admin') {
    return '/dashboard'
  }
})

export default router
