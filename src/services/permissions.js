import { supabase } from '../supabase'

let cachedPermissions = null

export async function loadPermissions(service) {
  const { data } = await supabase
    .from('permissions')
    .select('action')
    .eq('service', service)
    .eq('allowed', true)
  cachedPermissions = data?.map(p => p.action) || []
  return cachedPermissions
}

export function canPerform(action) {
  return cachedPermissions?.includes(action) || false
}

export function getPermissions() {
  return cachedPermissions || []
}

// Map étape circuit → permission requise
export function getPermissionForEtape(etape, orderType) {
  const map = {
    planification: `mettre_en_circuit_${orderType}`,
    stock: `valider_quantites_${orderType}`,
    aq: `valider_${orderType}`,
    dt: 'autoriser_lancement',
    aq_dap: 'remettre_ordre_production',
    production: orderType === 'of' ? 'accuser_reception_of' : 'accuser_reception_oc',
  }
  return map[etape]
}
