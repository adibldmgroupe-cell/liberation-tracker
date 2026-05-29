// Service : chargement des données de référence (ateliers / équipements / opérations)
// depuis la feuille Google Sheets publiée en CSV.
//
// Convention IDs :
//   N°_atelier (colonne 2) = ateliers.id en base Supabase
//   plan_rooms.code = 'p' + N°_atelier (ex. 'p149')
//
// Colonnes CSV attendues :
//   0 Processus
//   1 N°_atelier
//   2 Désignation_de_l'atelier
//   3 Numéro_opération
//   4 Opération
//   5 Equipement

var SHEET_URL = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vQqKb5_i0U7YeQYMiNEDy4X2gq6W_78NA2EuC2gRqSVXOKuBcBuXR8ASrE9Eq3admceATv4_gdAUppc/pub?gid=1383871669&single=true&output=csv'

var CACHE_TTL = 5 * 60 * 1000   // 5 minutes
var _cache    = null
var _cacheTs  = 0

// Couleurs par défaut pour les processus connus
var PROC_COLORS = {
  'Fabrication':                      '#7c3aed',
  'Conditionnement':                  '#059669',
  'PF en attente de livraison':       '#d97706',
  'SF en attente de conditionnement': '#2563eb',
}

// Zone SVG déduite du processus + numéro d'opération
var _zone = function(procNom, opNum) {
  if (procNom === 'Conditionnement') {
    return (opNum >= 300 && opNum < 400) ? 'cond_primaire' : 'cond_secondaire'
  }
  if (opNum === 210) return 'pesee'
  if (opNum === 270) return 'formes_semi'
  if (opNum >= 310)  return 'cond_secondaire'
  return 'formes_seches'
}

// Préfixe de code salle — doit correspondre aux IDs définis dans NODES_DEF (ProductionFlowPage)
// Règle : 'c' Conditionnement · 'p' Pesée (op 210) · 'n' tout autre Fabrication
var _prefix = function(procNom, opNum) {
  if (procNom === 'Conditionnement') return 'c'
  if (opNum === 210) return 'p'
  return 'n'
}

// Parse une ligne CSV en gérant les guillemets et les virgules internes
var _parseLine = function(line) {
  var result = []
  var inQuote = false
  var current = ''
  for (var i = 0; i < line.length; i++) {
    var c = line[i]
    if (c === '"' && inQuote && line[i + 1] === '"') { current += '"'; i++ }
    else if (c === '"') { inQuote = !inQuote }
    else if (c === ',' && !inQuote) { result.push(current); current = '' }
    else { current += c }
  }
  result.push(current)
  return result
}

var _empty = function() {
  return { processus: [], ateliers: [], operationsMaster: [], planRooms: [] }
}

var _parse = function(text) {
  var lines = text.split(/\r?\n/).filter(function(l) { return l.trim() })
  if (lines.length < 2) return _empty()

  var rows = []
  for (var i = 1; i < lines.length; i++) {
    var cols    = _parseLine(lines[i])
    var atelId  = parseInt((cols[1] || '').trim())
    var opNum   = parseInt((cols[3] || '').trim())
    if (isNaN(atelId)) continue
    rows.push({
      processus_nom:  (cols[0] || '').trim(),
      atelier_id:     atelId,
      atelier_nom:    (cols[2] || '').trim(),
      op_number:      isNaN(opNum) ? null : opNum,
      op_code:        (cols[4] || '').trim(),
      equipment_name: (cols[5] || '').trim(),
    })
  }

  // ── processus (unique, IDs séquentiels stables par ordre d'apparition) ──
  var procMap = {}
  var procIdx = 0
  rows.forEach(function(r) {
    if (!procMap[r.processus_nom]) {
      procIdx++
      procMap[r.processus_nom] = {
        id:          procIdx,
        nom_process: r.processus_nom,
        ordre:       procIdx,
        actif:       true,
        couleur:     PROC_COLORS[r.processus_nom] || '#888888'
      }
    }
  })
  var processus = Object.values(procMap).sort(function(a, b) { return a.ordre - b.ordre })

  // ── ateliers ──
  var ateliers = rows.map(function(r) {
    return {
      id:          r.atelier_id,
      nom_atelier: r.atelier_nom,
      processus_id: procMap[r.processus_nom] ? procMap[r.processus_nom].id : null,
      actif:       true
    }
  }).sort(function(a, b) { return (a.nom_atelier || '').localeCompare(b.nom_atelier || '') })

  // ── operations_master (une entrée par salle / équipement) ──
  // room_code = préfixe + N°_atelier → correspond aux codes de NODES_DEF (ex. 'n131', 'c149', 'p464')
  var operationsMaster = rows
    .filter(function(r) { return r.op_number !== null })
    .map(function(r) {
      return {
        id:             r.atelier_id,
        op_number:      r.op_number,
        op_code:        r.op_code,
        equipment_name: r.equipment_name,
        room_code:      _prefix(r.processus_nom, r.op_number) + r.atelier_id,
        room_name:      r.atelier_nom,
        processus:      r.processus_nom
      }
    }).sort(function(a, b) { return (a.op_number || 0) - (b.op_number || 0) })

  // ── plan_rooms ──
  // code = préfixe + N°_atelier → correspond aux IDs de NODES_DEF dans ProductionFlowPage
  // atelier_id est ABSENT ici : le FK Supabase est fourni par la requête plan_rooms Supabase (ProductionFlowPage)
  var planRooms = rows.map(function(r) {
    return {
      id:            r.atelier_id,
      code:          _prefix(r.processus_nom, r.op_number) + r.atelier_id,
      nom:           r.equipment_name || r.atelier_nom,
      zone:          _zone(r.processus_nom, r.op_number),
      type:          r.processus_nom === 'Conditionnement' ? 'cond' : 'fab',
      op_number:     r.op_number,
      actif:         true,
      atelier_id:    null,      // fourni par Supabase plan_rooms dans ProductionFlowPage
      equipement_id: null       // idem
    }
  })

  return { processus, ateliers, operationsMaster, planRooms }
}

var _fetch = async function() {
  var now = Date.now()
  if (_cache && (now - _cacheTs) < CACHE_TTL) return _cache
  try {
    var r = await fetch(SHEET_URL)
    if (!r.ok) throw new Error('HTTP ' + r.status)
    var text = await r.text()
    _cache   = _parse(text)
    _cacheTs = now
    return _cache
  } catch (e) {
    console.warn('[googleSheets] Erreur chargement :', e.message)
    return _cache || _empty()
  }
}

export var getAll             = function() { return _fetch() }
export var getProcessus       = async function() { var d = await _fetch(); return d.processus }
export var getAteliers        = async function() { var d = await _fetch(); return d.ateliers }
export var getOperationsMaster = async function() { var d = await _fetch(); return d.operationsMaster }
export var getPlanRooms       = async function() { var d = await _fetch(); return d.planRooms }

// Forcer un rechargement depuis la feuille (invalide le cache)
export var clearCache = function() { _cache = null; _cacheTs = 0 }
