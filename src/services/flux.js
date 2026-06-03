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
