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
      { path: 'actions', name: 'Actions', component: () => import('../pages/BulkPage.vue') },
      { path: 'notifications', name: 'Notifications', component: () => import('../pages/NotificationsPage.vue') },
    ],
  },
]

const router = createRouter({ history: createWebHashHistory(), routes })

router.beforeEach(async (to) => {
  if (to.meta.requiresAuth) {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) return '/login'
  }
})

export default router
