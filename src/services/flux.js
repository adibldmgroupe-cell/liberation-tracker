// Service : règle BPF « flux produit » — un produit ne peut être lancé sur une salle/équipement
// que s'il y est autorisé dans product_flux (coché spécifiquement, ou flexible sur l'opération).
//
// product_flux : (product_code, route, op_number, room_code)
//   - room_code renseigné  → salle SPÉCIFIQUE cochée pour cette op
//   - room_code null        → FLEXIBLE : toutes les salles de l'op
//   - si une salle spécifique existe pour un op, les flexibles de cet op sont ignorés (salle imposée)
//
// Politique d'échec : fail-OPEN sur erreur réseau (ne pas bloquer la prod sur un incident),
// fail-CLOSED si le produit n'a pas ce flux (c'est précisément ce qu'on veut interdire).

import { supabase } from '../supabase'

// cache léger operations_master (equipment_name → {room_code, op_number})
var _omCache = null
var _loadOm = async function() {
  if (_omCache) return _omCache
  var r = await supabase.from('operations_master').select('room_code,op_number,equipment_name')
  _omCache = (r.error ? [] : (r.data || []))
  return _omCache
}
export var clearFluxCache = function() { _omCache = null }

// Cœur : le produit est-il autorisé sur la salle room_code (de l'opération opNumber) ?
export var checkProductFluxRoom = async function(productCode, roomCode, opNumber) {
  if (!productCode || !roomCode) return { allowed: true }
  var r = await supabase.from('product_flux').select('room_code,op_number').eq('product_code', productCode)
  if (r.error) return { allowed: true }   // réseau : ne pas bloquer
  var rows = r.data || []
  // 1) salle explicitement cochée pour ce produit → autorisé
  if (rows.some(function(f) { return f.room_code === roomCode })) return { allowed: true }
  // 2) flexible sur l'op, sans salle spécifique imposée pour cet op → autorisé (toutes salles de l'op)
  var opRows = rows.filter(function(f) { return opNumber != null && Number(f.op_number) === Number(opNumber) })
  var hasFlex = opRows.some(function(f) { return !f.room_code })
  var hasSpecificForOp = opRows.some(function(f) { return f.room_code })
  if (hasFlex && !hasSpecificForOp) return { allowed: true }
  return { allowed: false, reason: 'Flux produit : ' + productCode + ' n\'est pas autorisé sur ' + roomCode + ' — cocher le flux (Flux produits) avant de le lancer.' }
}

// Variante par nom d'équipement (TRS / PDP) : résout room_code + op via operations_master
export var checkProductFluxEquipName = async function(productCode, equipNom) {
  if (!productCode || !equipNom) return { allowed: true }
  var om = await _loadOm()
  var key = (equipNom || '').toLowerCase().trim()
  var row = om.find(function(o) { return (o.equipment_name || '').toLowerCase().trim() === key })
  if (!row) return { allowed: true }   // équipement non mappé au référentiel → ne pas bloquer
  return await checkProductFluxRoom(productCode, row.room_code, row.op_number)
}

// ═══════════════════════════════════════════════════════════════════════════
// FLUX PHARMA RÉEL — source unique (l'op NE reflète PAS l'ordre du procédé)
// ═══════════════════════════════════════════════════════════════════════════
// Étape → salles (room_code)
export var FLOW_STAGES = {
  pesee:          ['p464', 'p471'],
  granulation:    ['n140', 'n425'],
  melange:        ['n138', 'n137', 'n448'],
  compression:    ['n131', 'n128', 'n134', 'n445'],
  pelliculage:    ['n143', 'n429', 'n136'],
  remplissage:    ['n436'],
  melange_pateux: ['n200'],
  cond:           ['c149', 'c148', 'c147', 'c146', 'c223', 'c220', 'c222'],
  cond_pateux:    ['c206']
}
// Transitions valides entre étapes (dérivées des 9 routes possibles)
export var FLOW_EDGES = [
  ['pesee', 'granulation'], ['pesee', 'melange'], ['pesee', 'compression'], ['pesee', 'melange_pateux'],
  ['granulation', 'melange'],
  ['melange', 'remplissage'], ['melange', 'compression'],
  ['compression', 'pelliculage'], ['compression', 'cond'],
  ['pelliculage', 'cond'],
  ['remplissage', 'cond'],
  ['melange_pateux', 'cond_pateux']
]
// room_code → étape
export var ROOM_STAGE = {}
Object.keys(FLOW_STAGES).forEach(function(s) { FLOW_STAGES[s].forEach(function(rc) { ROOM_STAGE[rc] = s }) })
// op_number → étape (pour les lignes product_flux FLEXIBLES, room_code null)
var OP_STAGE = { 210: 'pesee', 220: 'granulation', 230: 'melange', 240: 'compression', 250: 'pelliculage', 260: 'remplissage', 270: 'melange_pateux', 310: 'cond', 320: 'cond', 330: 'cond', 340: 'cond', 360: 'cond_pateux', 370: 'cond', 380: 'cond' }
// Ordre canonique du flux (pour déterminer l'amont). Les branches (remplissage / mélange pâteux)
// sont placées avant compression : sans incidence car elles n'apparaissent jamais dans la même route que compression.
var STAGE_ORDER = ['pesee', 'granulation', 'melange', 'melange_pateux', 'remplissage', 'compression', 'pelliculage', 'cond', 'cond_pateux']
export var STAGE_LABELS = { pesee: 'Pesée', granulation: 'Granulation', melange: 'Mélange', melange_pateux: 'Mélange pâteux', remplissage: 'Remplissage gélules', compression: 'Compression', pelliculage: 'Pelliculage', cond: 'Conditionnement', cond_pateux: 'Cond. pâteux' }

// cache plan_rooms (atelier_id / equipement_id → room_code → étape)
var _prCache = null
var _loadPlanRooms = async function() {
  if (_prCache) return _prCache
  var r = await supabase.from('plan_rooms').select('code,atelier_id,equipement_id')
  _prCache = (r.error ? [] : (r.data || []))
  return _prCache
}

// ── Contrôle de séquence (anti-saut d'étape amont — règle N°23) ──
// Retourne { missing: [stageKeys] } = étapes de la route du produit, situées AVANT targetStage,
// pour lesquelles le lot n'a AUCUN suivi enregistré. Vide si rien manque ou produit/étape inconnus.
export var checkUpstreamStages = async function(lotId, productCode, targetStage) {
  if (!lotId || !productCode || !targetStage) return { missing: [] }
  var ti = STAGE_ORDER.indexOf(targetStage)
  if (ti <= 0) return { missing: [] }   // pesée (ou inconnu) → pas d'amont
  // 1) étapes de la route du produit
  var pf = await supabase.from('product_flux').select('room_code,op_number').eq('product_code', productCode)
  if (pf.error) return { missing: [] }
  var routeStages = {}
  ;(pf.data || []).forEach(function(f) {
    var st = f.room_code ? ROOM_STAGE[f.room_code] : OP_STAGE[f.op_number]
    if (st) routeStages[st] = true
  })
  // 2) étapes amont attendues (dans la route, avant la cible)
  var upstream = STAGE_ORDER.filter(function(s, i) { return i < ti && routeStages[s] })
  if (!upstream.length) return { missing: [] }
  // 3) étapes déjà enregistrées pour le lot
  var pr = await _loadPlanRooms()
  var atStage = {}, eqStage = {}
  pr.forEach(function(p) { var st = ROOM_STAGE[p.code]; if (st) { if (p.atelier_id != null) atStage[p.atelier_id] = st; if (p.equipement_id != null) eqStage[p.equipement_id] = st } })
  var sf = await supabase.from('suivi_fabrication').select('atelier_id').eq('lot_id', lotId).is('deleted_at', null)
  var sc = await supabase.from('suivi_conditionnement').select('equipement_id').eq('lot_id', lotId).is('deleted_at', null)
  var recorded = {}
  ;(sf.data || []).forEach(function(r) { var s = atStage[r.atelier_id]; if (s) recorded[s] = true })
  ;(sc.data || []).forEach(function(r) { var s = eqStage[r.equipement_id]; if (s) recorded[s] = true })
  // 4) amont manquant
  return { missing: upstream.filter(function(s) { return !recorded[s] }) }
}

// Variantes pratiques (résolvent targetStage depuis l'équipement/atelier via plan_rooms)
export var checkUpstreamForEquip = async function(lotId, productCode, equipementId) {
  var pr = await _loadPlanRooms()
  var room = pr.find(function(p) { return p.equipement_id === equipementId })
  return room && ROOM_STAGE[room.code] ? await checkUpstreamStages(lotId, productCode, ROOM_STAGE[room.code]) : { missing: [] }
}
export var checkUpstreamForAtelier = async function(lotId, productCode, atelierId) {
  var pr = await _loadPlanRooms()
  var room = pr.find(function(p) { return p.atelier_id === atelierId })
  return room && ROOM_STAGE[room.code] ? await checkUpstreamStages(lotId, productCode, ROOM_STAGE[room.code]) : { missing: [] }
}
// Libellés lisibles d'une liste de stageKeys
export var stageLabels = function(keys) { return (keys || []).map(function(k) { return STAGE_LABELS[k] || k }).join(', ') }
