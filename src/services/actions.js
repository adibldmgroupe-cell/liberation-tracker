import { supabase } from '../supabase'
import { createNotification } from './notifications'

// ═══ CIRCUIT OF/OC VALIDATION ═══
export async function validateOrder(orderType, orderId, etape, userId, lotId) {
  var now = new Date().toISOString()
  await supabase.from('order_validations').insert({
    order_type: orderType, order_id: orderId, etape: etape,
    action: 'valide', validated_by: userId, validated_at: now
  })

  var flow = ['planification', 'stock', 'aq', 'dt', 'aq_dap', 'production']
  var idx = flow.indexOf(etape)
  var next = idx < flow.length - 1 ? flow[idx + 1] : null
  var table = orderType === 'of' ? 'orders_of' : 'orders_oc'

  await supabase.from(table).update({
    statut: next ? 'en_circuit' : 'termine',
    etape_circuit: next || etape, updated_at: now
  }).eq('id', orderId)

  var etapeLabels = { planification:'Planification', stock:'Stock', aq:'AQ', dt:'DT', aq_dap:'AQ DAP', production:'Réception Production' }
  var label = next ? etapeLabels[next] : 'Terminé'
  await supabase.from('lots').update({ statut_operationnel: orderType.toUpperCase() + ' — ' + label, updated_at: now }).eq('id', lotId)

  // Notification au service suivant
  var serviceMap = { stock:'stock', aq:'aq', dt:'dt', aq_dap:'aq_dap', production: orderType === 'of' ? 'fabrication' : 'conditionnement' }
  if (next && serviceMap[next]) {
    var lotRes = await supabase.from('lots').select('numero_lot').eq('id', lotId).single()
    var lotNum = lotRes.data ? lotRes.data.numero_lot : ''
    await createNotification(serviceMap[next], lotId, null,
      'Lot ' + lotNum + ' — ' + orderType.toUpperCase() + ' en attente de validation ' + (etapeLabels[next] || next),
      'validation_' + orderType)
  }

  await supabase.from('lot_events').insert({
    lot_id: lotId, event_type: 'validation_' + orderType,
    description: 'Circuit ' + orderType.toUpperCase() + ' — ' + etape + ' validé',
    triggered_by: userId, created_at: now
  })
}

// Permission check for circuit validation
export function getRequiredService(orderType, etape) {
  var map = {
    planification: 'planification',
    stock: 'stock',
    aq: 'aq',
    dt: 'dt',
    aq_dap: 'aq_dap',
    production: orderType === 'of' ? 'fabrication' : 'conditionnement'
  }
  return map[etape] || null
}

// ═══ DOCUMENT ACTIONS (IF, IC, DA, RVP) ═══
export async function documentAction(docId, action, userId, lotId, docType, serviceEmetteur, motif) {
  var now = new Date().toISOString()
  var statutMap = {
    emettre: 'emis', verifier_aq: 'approuve_aq', retourner: 'retour_emetteur',
    retourner_aq: 'verification_aq', rectifier: 'verification_aq', approuver_dt: 'approuve_dt'
  }

  var docUpdate = { statut: statutMap[action], updated_at: now }
  if (action === 'emettre') { docUpdate.emitted_at = now; docUpdate.emitted_by = userId }
  if (action === 'approuver_dt') { docUpdate.approved_at = now }

  if (action === 'emettre' && docType === 'da_micro') {
    docUpdate.is_applicable = true; docUpdate.is_required = true
    await supabase.from('liberation_dossiers').update({ da_micro_applicable: true, updated_at: now }).eq('lot_id', lotId)
  }

  await supabase.from('liberation_documents').update(docUpdate).eq('id', docId)

  // Mouvement
  var mvtMap = {
    emettre: { action: 'emission', from: serviceEmetteur, to: 'aq' },
    verifier_aq: { action: 'approbation', from: 'aq', to: 'dt' },
    retourner: { action: 'retour', from: 'aq', to: serviceEmetteur },
    retourner_aq: { action: 'retour', from: 'dt', to: 'aq' },
    rectifier: { action: 'rectification', from: serviceEmetteur, to: 'aq' },
    approuver_dt: { action: 'approbation', from: 'dt', to: null }
  }
  var mvt = mvtMap[action]
  await supabase.from('document_movements').insert({
    document_id: docId, action: mvt.action, from_service: mvt.from, to_service: mvt.to,
    motif_retour: (action === 'retourner' || action === 'retourner_aq') ? motif : null,
    performed_by: userId, performed_at: now
  })

  // Notifications
  var lotRes = await supabase.from('lots').select('numero_lot').eq('id', lotId).single()
  var lotNum = lotRes.data ? lotRes.data.numero_lot : ''
  var typeLabel = docType.toUpperCase().replace('_', ' ')

  if (action === 'emettre') {
    await createNotification('aq', lotId, docId, 'Lot ' + lotNum + ' — ' + typeLabel + ' émis, en attente de vérification', 'document_transmis')
  } else if (action === 'verifier_aq') {
    await createNotification('dt', lotId, docId, 'Lot ' + lotNum + ' — ' + typeLabel + ' vérifié AQ, en attente d\'approbation DT', 'document_transmis')
  } else if (action === 'retourner') {
    var svcMap = { fabrication:'fabrication', conditionnement:'conditionnement', lcq:'lcq' }
    await createNotification(svcMap[serviceEmetteur] || serviceEmetteur, lotId, docId, 'Lot ' + lotNum + ' — ' + typeLabel + ' retourné pour rectification', 'document_retourne')
  } else if (action === 'retourner_aq') {
    await createNotification('aq', lotId, docId, 'Lot ' + lotNum + ' — ' + typeLabel + ' retourné par le DT', 'document_retourne')
  } else if (action === 'rectifier') {
    await createNotification('aq', lotId, docId, 'Lot ' + lotNum + ' — ' + typeLabel + ' rectifié, en attente de vérification', 'document_transmis')
  } else if (action === 'approuver_dt') {
    await createNotification('aq', lotId, docId, 'Lot ' + lotNum + ' — ' + typeLabel + ' approuvé par le DT', 'document_approuve')
    // Aussi notifier l'émetteur
    var svcMap2 = { fabrication:'fabrication', conditionnement:'conditionnement', lcq:'lcq' }
    if (svcMap2[serviceEmetteur]) {
      await createNotification(svcMap2[serviceEmetteur], lotId, docId, 'Lot ' + lotNum + ' — ' + typeLabel + ' approuvé par le DT', 'document_approuve')
    }
  }

  // Si approuvé DT → maj dossier libération
  if (action === 'approuver_dt') {
    var fieldMap = { 'if': 'if_approved', ic: 'ic_approved', da_pc: 'da_pc_approved', da_micro: 'da_micro_approved' }
    var field = fieldMap[docType]
    if (field) {
      await supabase.from('liberation_dossiers').update({ [field]: true, updated_at: now }).eq('lot_id', lotId)
    }
    if (docType === 'rvp' || docType === 'rvp_fab' || docType === 'rvp_cond' || docType === 'rvp_lcq') {
      await supabase.from('liberation_dossiers').update({ pieces_complementaires_ok: true, updated_at: now }).eq('lot_id', lotId)
    }
  }

  await supabase.from('lot_events').insert({
    lot_id: lotId, event_type: 'document_' + action,
    description: typeLabel + ' — ' + action, triggered_by: userId, created_at: now
  })
}

// ═══ DÉVIATIONS ═══
export async function declareDeviation(lotId, observation, userId) {
  var now = new Date().toISOString()
  var countRes = await supabase.from('deviations').select('*', { count: 'exact', head: true })
  var numero = 'DEV-' + new Date().getFullYear() + '-' + String(((countRes.count || 0) + 1)).padStart(3, '0')
  await supabase.from('deviations').insert({
    lot_id: lotId, numero_deviation: numero, type: 'deviation',
    statut: 'ouverte', description: observation || '',
    declared_by: userId, declared_at: now
  })
  await supabase.from('liberation_dossiers').update({ deviations_closed: false, updated_at: now }).eq('lot_id', lotId)
  await supabase.from('lot_events').insert({
    lot_id: lotId, event_type: 'deviation_declaree',
    description: 'Déviation ' + numero + ' déclarée', triggered_by: userId, created_at: now
  })
}

export async function closeDeviation(deviationId, lotId, userId) {
  var now = new Date().toISOString()
  await supabase.from('deviations').update({ statut: 'cloturee', closed_at: now }).eq('id', deviationId)
  var openRes = await supabase.from('deviations').select('*', { count: 'exact', head: true }).eq('lot_id', lotId).in('statut', ['ouverte', 'en_cours'])
  if ((openRes.count || 0) === 0) {
    await supabase.from('liberation_dossiers').update({ deviations_closed: true, updated_at: now }).eq('lot_id', lotId)
  }
}

// ═══ RVP ═══
export async function declareRVP(lotId, rvpType, userId) {
  var now = new Date().toISOString()
  var serviceMap = { rvp_fab: 'fabrication', rvp_cond: 'conditionnement', rvp_lcq: 'lcq' }
  await supabase.from('liberation_documents').insert({
    lot_id: lotId, type_document: 'rvp', statut: 'non_emis',
    is_applicable: true, is_required: true,
    service_emetteur: serviceMap[rvpType] || 'fabrication'
  })
  await supabase.from('liberation_dossiers').update({ pieces_complementaires_ok: false, updated_at: now }).eq('lot_id', lotId)
  await supabase.from('lot_events').insert({
    lot_id: lotId, event_type: 'rvp_declare',
    description: 'RVP déclaré (' + rvpType + ')', triggered_by: userId, created_at: now
  })
}

// ═══ MÀJ DOCUMENTS (IF, IC, Nmcl OF, Nmcl OC) ═══
export async function declareMajDoc(lotId, docType, userId) {
  var now = new Date().toISOString()
  var svcMap = { maj_if: 'fabrication', maj_ic: 'conditionnement', maj_nmcl_of: 'planification', maj_nmcl_oc: 'planification' }
  var res = await supabase.from('liberation_documents').insert({
    lot_id: lotId, type_document: docType, statut: 'non_emis',
    is_applicable: true, is_required: false,
    service_emetteur: svcMap[docType] || 'planification'
  })
  if (res.error) throw new Error(res.error.message)
  var lotRes = await supabase.from('lots').select('numero_lot').eq('id', lotId).single()
  var lotNum = lotRes.data ? lotRes.data.numero_lot : ''
  var typeLabel = docType.replace(/_/g, ' ').toUpperCase()
  await createNotification(svcMap[docType] || 'planification', lotId, null,
    'Lot ' + lotNum + ' — ' + typeLabel + ' déclaré, à émettre', 'document_transmis')
  await supabase.from('lot_events').insert({
    lot_id: lotId, event_type: 'maj_doc_declare',
    description: typeLabel + ' déclaré', triggered_by: userId, created_at: now
  })
}

// ═══ CLÔTURE SAP ═══
export async function declareClotureSap(lotId, clotType, userId) {
  var now = new Date().toISOString()
  var svcMap = { cloture_sap_of: 'fabrication', cloture_sap_oc: 'conditionnement' }
  var res = await supabase.from('liberation_documents').insert({
    lot_id: lotId, type_document: clotType, statut: 'non_emis',
    is_applicable: true, is_required: false,
    service_emetteur: svcMap[clotType] || 'fabrication'
  })
  if (res.error) throw new Error(res.error.message)
  var lotRes = await supabase.from('lots').select('numero_lot').eq('id', lotId).single()
  var lotNum = lotRes.data ? lotRes.data.numero_lot : ''
  await supabase.from('lot_events').insert({
    lot_id: lotId, event_type: 'cloture_sap_declare',
    description: clotType + ' déclaré', triggered_by: userId, created_at: now
  })
}

// ═══ AQL ═══
export async function requestAql(lotId, type, userId) {
  var now = new Date().toISOString()
  await supabase.from('aql_inspections').insert({ lot_id: lotId, type: type, resultat: 'en_attente', requested_at: now })
  var lotRes = await supabase.from('lots').select('numero_lot').eq('id', lotId).single()
  var lotNum = lotRes.data ? lotRes.data.numero_lot : ''
  await createNotification('aq', lotId, null, 'Lot ' + lotNum + ' — Demande AQL ' + type, 'aql_demande')
  await supabase.from('lot_events').insert({
    lot_id: lotId, event_type: 'aql_demande', description: 'Demande AQL ' + type, triggered_by: userId, created_at: now
  })
}

export async function respondAql(aqlId, resultat, recommandations, userId, lotId) {
  var now = new Date().toISOString()
  await supabase.from('aql_inspections').update({
    resultat: resultat, avis_aq: recommandations, inspected_by: userId, inspected_at: now
  }).eq('id', aqlId)

  var typeRes = await supabase.from('aql_inspections').select('type').eq('id', aqlId).single()
  var type = typeRes.data ? typeRes.data.type : ''
  var targetService = type === 'fabrication' ? 'fabrication' : 'conditionnement'
  var lotRes = await supabase.from('lots').select('numero_lot').eq('id', lotId).single()
  var lotNum = lotRes.data ? lotRes.data.numero_lot : ''

  await createNotification(targetService, lotId, null,
    'Lot ' + lotNum + ' — AQL ' + type + ' — ' + (resultat === 'conforme' ? 'Conforme' : 'Non conforme'),
    'aql_resultat')
  await supabase.from('lot_events').insert({
    lot_id: lotId, event_type: 'aql_resultat',
    description: 'AQL ' + type + ' — ' + resultat + (recommandations ? ' — ' + recommandations : ''),
    triggered_by: userId, created_at: now
  })
}

export async function isAqlConforme(lotId, type) {
  var res = await supabase.from('aql_inspections').select('resultat')
    .eq('lot_id', lotId).eq('type', type).eq('resultat', 'conforme').limit(1)
  return (res.data && res.data.length > 0)
}

// ═══ LIBÉRER LOT ═══
export async function libererLot(lotId, userId) {
  var now = new Date().toISOString()
  await supabase.from('liberation_dossiers').update({
    statut: 'libere', liberated_by: userId, liberated_at: now, updated_at: now
  }).eq('lot_id', lotId)
  await supabase.from('lots').update({ statut_operationnel: 'Accepté', updated_at: now }).eq('id', lotId)

  var lotRes = await supabase.from('lots').select('numero_lot').eq('id', lotId).single()
  var lotNum = lotRes.data ? lotRes.data.numero_lot : ''
  await createNotification('aq', lotId, null, 'Lot ' + lotNum + ' — Libéré par le DT', 'lot_libere')
  await createNotification('planification', lotId, null, 'Lot ' + lotNum + ' — Libéré par le DT', 'lot_libere')

  await supabase.from('lot_events').insert({
    lot_id: lotId, event_type: 'lot_libere', description: 'Lot libéré par le DT',
    triggered_by: userId, created_at: now
  })
}

// ═══ ADMIN ═══
export async function modifyLot(lotId, newNumLot, newProductId) {
  await supabase.from('lots').update({ numero_lot: newNumLot, product_id: newProductId, updated_at: new Date().toISOString() }).eq('id', lotId)
}

export async function deleteLot(lotId) {
  await supabase.from('lots').delete().eq('id', lotId)
}

export async function deleteLots(lotIds) {
  await supabase.from('lots').delete().in('id', lotIds)
}
