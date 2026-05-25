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
      { path: 'admin/products', name: 'AdminProducts', component: () => import('../pages/ProductsCatalogPage.vue'), meta: { requiresAdmin: true } },
      { path: 'production/plan', name: 'ProductionPlan', component: () => import('../pages/production/ProductionPlanPage.vue') },
      { path: 'tracking/pdp-fab',   name: 'SuiviPDPFab',   component: () => import('../pages/tracking/SuiviPDPFabPage.vue') },
      { path: 'tracking/pdp-cond',  name: 'SuiviPDPCond',  component: () => import('../pages/tracking/SuiviPDPCondPage.vue') },
      { path: 'tracking/trs',       name: 'TrsLive',       component: () => import('../pages/tracking/TrsLivePage.vue') },
      { path: 'tracking/analytics', name: 'TrsAnalytics',  component: () => import('../pages/tracking/TrsAnalyticsPage.vue') },
      { path: 'admin/ateliers', name: 'AdminAteliers', component: () => import('../pages/admin/AdminAteliersPage.vue'), meta: { requiresAdmin: true } },
      { path: 'admin/arret-types', name: 'AdminArretTypes', component: () => import('../pages/admin/AdminArretTypesPage.vue'), meta: { requiresAdmin: true } },
      { path: 'admin/equipements', name: 'AdminEquipements', component: () => import('../pages/admin/AdminEquipementsPage.vue'), meta: { requiresAdmin: true } },
      { path: 'admin/shifts', name: 'AdminShifts', component: () => import('../pages/admin/AdminShiftsPage.vue'), meta: { requiresAdmin: true } },
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
