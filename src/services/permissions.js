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

// Map valeur action en masse → clé permission DB
export function getPermissionForBulkAction(action) {
  const map = {
    of_planification:'mettre_en_circuit_of', of_stock:'valider_quantites_of', of_aq:'valider_of',
    of_dt:'autoriser_lancement', of_aq_dap:'remettre_ordre_production', of_production:'accuser_reception_of',
    oc_planification:'mettre_en_circuit_oc', oc_stock:'valider_quantites_oc', oc_aq:'valider_oc',
    oc_dt:'autoriser_lancement', oc_aq_dap:'remettre_ordre_production', oc_production:'accuser_reception_oc',
    doc_if:'emettre_if', doc_ic:'emettre_ic', doc_da_pc:'emettre_da_pc', doc_da_micro:'emettre_da_micro',
    doc_if_verifier:'verifier_if', doc_ic_verifier:'verifier_ic',
    doc_da_pc_verifier:'verifier_da_pc', doc_da_micro_verifier:'verifier_da_micro',
    doc_if_approuver:'approuver_if', doc_ic_approuver:'approuver_ic',
    doc_da_pc_approuver:'approuver_da_pc', doc_da_micro_approuver:'approuver_da_micro',
    doc_if_retour_emetteur:'retourner_document', doc_ic_retour_emetteur:'retourner_document',
    doc_da_pc_retour_emetteur:'retourner_document', doc_da_micro_retour_emetteur:'retourner_document',
    doc_if_retour_aq:'retourner_document', doc_ic_retour_aq:'retourner_document',
    doc_da_pc_retour_aq:'retourner_document', doc_da_micro_retour_aq:'retourner_document',
    aql_fab_demander:'demander_aql_fab', aql_fab_relancer:'demander_aql_fab',
    aql_fab_conforme:'realiser_aql', aql_fab_non_conforme:'realiser_aql',
    aql_cond_demander:'demander_aql_cond', aql_cond_relancer:'demander_aql_cond',
    aql_cond_conforme:'realiser_aql', aql_cond_non_conforme:'realiser_aql',
    rvp_fab_emettre:'emettre_rvp', rvp_cond_emettre:'emettre_rvp', rvp_lcq_emettre:'emettre_rvp',
    rvp_fab_verifier:'verifier_rvp', rvp_cond_verifier:'verifier_rvp', rvp_lcq_verifier:'verifier_rvp',
    rvp_fab_approuver:'approuver_rvp', rvp_cond_approuver:'approuver_rvp', rvp_lcq_approuver:'approuver_rvp',
    rvp_fab_retour_emetteur:'retourner_document', rvp_cond_retour_emetteur:'retourner_document',
    rvp_lcq_retour_emetteur:'retourner_document', rvp_fab_retour_aq:'retourner_document',
    rvp_cond_retour_aq:'retourner_document', rvp_lcq_retour_aq:'retourner_document',
    dev_declarer:'declarer_nc', dev_cloture:'cloturer_deviation',
    plan_lcq:'modifier_planning', plan_aq:'modifier_planning', plan_dt1:'modifier_planning', plan_dt2:'modifier_planning',
  }
  return map[action] || null
}
