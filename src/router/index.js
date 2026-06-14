import { createRouter, createWebHashHistory } from 'vue-router'
import { supabase } from '../supabase'
import { loadPermissions, canPerform } from '../services/permissions'

const routes = [
  { path: '/login', name: 'Login', component: () => import('../pages/LoginPage.vue') },
  { path: '/changer-mot-de-passe', name: 'ChangePassword', component: () => import('../pages/ChangePasswordPage.vue'), meta: { requiresAuth: true } },
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
      { path: 'lots/:lotId/circuit/:type', name: 'CircuitDetail', component: () => import('../pages/CircuitDetailPage.vue') },
      { path: 'lots/:lotId/aql/:type', name: 'AqlDetail', component: () => import('../pages/AqlDetailPage.vue') },
      { path: 'planifier', name: 'Planifier', component: () => import('../pages/PlanifierPage.vue') },
{ path: 'notifications', name: 'Notifications', component: () => import('../pages/NotificationsPage.vue') },
      { path: 'tasks', name: 'Tasks', component: () => import('../pages/TasksPage.vue') },
      { path: 'peremption', name: 'Peremption', component: () => import('../pages/peremption/MatricePeremptionPage.vue'), meta: { hideHeaderSearch: true } },
      { path: 'peremption/:productId', name: 'PeremptionEval', component: () => import('../pages/peremption/PeremptionEvalPage.vue'), meta: { hideHeaderSearch: true } },
      // Routes administration — réservées au service 'admin'
      { path: 'admin/referentiel', name: 'AdminReferentiel', component: () => import('../pages/admin/AdminRefPage.vue'), meta: { requiresAdmin: true } },
      { path: 'admin/users', name: 'AdminUsers', component: () => import('../pages/AdminUsersPage.vue'), meta: { requiresAdmin: true } },
      { path: 'admin/permissions', name: 'AdminPermissions', component: () => import('../pages/AdminPermissionsPage.vue'), meta: { requiresAdmin: true } },
      { path: 'admin/deadlines', name: 'AdminDeadlines', component: () => import('../pages/admin/AdminDeadlinesPage.vue') },
      { path: 'admin/products', name: 'AdminProducts', component: () => import('../pages/ProductsCatalogPage.vue'), meta: { requiresAdmin: true } },
      { path: 'production/flux',  name: 'ProductionFlux',  component: () => import('../pages/production/ProductionFlowPage.vue') },
      { path: 'production/pdp',   name: 'PdpProduction',   component: () => import('../pages/production/PdpProductionPage.vue') },
      { path: 'admin/flux', name: 'AdminFlux', component: () => import('../pages/admin/AdminFluxPage.vue'), meta: { requiresAdmin: true } },
      { path: 'tracking/trs',       name: 'TrsLive',       component: () => import('../pages/tracking/TrsLivePage.vue') },
      { path: 'tracking/analytics', name: 'TrsAnalytics',  component: () => import('../pages/tracking/TrsAnalyticsPage.vue') },
      { path: 'tracking/pdp-fab',   name: 'SuiviPDPFab',  component: () => import('../pages/tracking/SuiviPDPFabPage.vue') },
      { path: 'tracking/trs-sessions', name: 'SuiviTRSCond', component: () => import('../pages/tracking/SuiviTRSCondPage.vue') },
      { path: 'admin/ateliers', name: 'AdminAteliers', component: () => import('../pages/admin/AdminAteliersPage.vue'), meta: { requiresAdmin: true } },
      { path: 'admin/arret-types', name: 'AdminArretTypes', component: () => import('../pages/admin/AdminArretTypesPage.vue'), meta: { requiresAdmin: true } },
      { path: 'admin/equipements', name: 'AdminEquipements', component: () => import('../pages/admin/AdminEquipementsPage.vue'), meta: { requiresAdmin: true } },
      { path: 'admin/shifts', name: 'AdminShifts', component: () => import('../pages/admin/AdminShiftsPage.vue'), meta: { requiresAdmin: true } },
    ],
  },
]

// Route (name) → permission « voir la page ». Vérifiée dans le garde-fou ci-dessous.
// Admin = bypass (canPerform). Dashboard volontairement absent du blocage (toujours atteignable).
const ROUTE_PERM = {
  Dashboard: 'voir_dashboard',
  Products: 'voir_produits', ProductDetail: 'voir_produits',
  Lots: 'voir_lots', LotDetail: 'voir_lots', DocumentDetail: 'voir_lots', CircuitDetail: 'voir_lots', AqlDetail: 'voir_lots',
  Planifier: 'voir_planification',
  Notifications: 'voir_notifications',
  Tasks: 'voir_taches',
  Peremption: 'voir_peremption', PeremptionEval: 'voir_peremption',
  ProductionFlux: 'voir_production_schema',
  PdpProduction: 'voir_pdp',
  TrsLive: 'voir_trs_live',
  TrsAnalytics: 'voir_trs_analytics',
  SuiviPDPFab: 'voir_suivi_fab',
  SuiviTRSCond: 'voir_suivi_cond',
  AdminReferentiel: 'voir_referentiel',
  AdminUsers: 'voir_admin_comptes',
  AdminPermissions: 'voir_admin_permissions',
  AdminDeadlines: 'voir_admin_delais',
  AdminProducts: 'voir_admin_produits',
  AdminFlux: 'voir_admin_flux',
  AdminAteliers: 'voir_admin_ateliers',
  AdminArretTypes: 'voir_admin_arrets',
  AdminEquipements: 'voir_admin_equipements',
  AdminShifts: 'voir_admin_shifts',
}

const router = createRouter({ history: createWebHashHistory(), routes })

router.beforeEach(async (to) => {
  if (!to.meta.requiresAuth) return

  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return '/login'

  // Vérification du profil : compte actif + service admin + 1re connexion
  // select('*') → robuste si la colonne must_change_password n'existe pas encore (avant migration 037)
  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', session.user.id)
    .single()

  // Compte désactivé : déconnexion et redirection
  if (!profile || !profile.is_active) {
    await supabase.auth.signOut()
    return '/login'
  }

  // 1re connexion : changement de mot de passe obligatoire (cf. migration 037)
  // Tant que la colonne n'existe pas, must_change_password est undefined → rien n'est forcé.
  if (profile.must_change_password && to.name !== 'ChangePassword') {
    return '/changer-mot-de-passe'
  }
  if (!profile.must_change_password && to.name === 'ChangePassword') {
    return '/dashboard'
  }

  // Charger les permissions du service courant (pour canPerform : contrôle route + sidebar)
  await loadPermissions(profile.service)

  // Route admin réservée au service 'admin' (double verrou conservé — décision utilisateur)
  if (to.meta.requiresAdmin && profile.service !== 'admin') {
    return '/dashboard'
  }

  // « Voir la page » : permission de vue requise pour cette route.
  // Admin bypass (canPerform). Dashboard exclu du blocage → jamais de boucle de redirection.
  var perm = ROUTE_PERM[to.name]
  if (perm && to.name !== 'Dashboard' && !canPerform(perm)) {
    return '/dashboard'
  }
})

export default router
