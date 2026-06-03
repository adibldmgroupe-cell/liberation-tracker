// Service : chargement des données de référence (ateliers / équipements / opérations / cadences)
// depuis les feuilles Google Sheets publiées en CSV.
//
// Onglet 1 (gid=1383871669) — référentiel ateliers / opérations
//   0  Processus
//   1  N°_atelier
//   2  id_supabase            → FK ateliers.id Supabase
//   3  Désignation_de_l'atelier
//   4  Numéro_opération
//   5  Opération
//   6  Equipement
//   7  TRS_cible_%
//   8  Temps_util             → heures utiles/jour (PDP capacité)
//   9  TO_shift_min
//   10 Pause_min
//   11 VDLP_min
//   12 VDLC_min
//   13 Chgt_format_min
//   14 Reglage_lancement_min
//   15 Micro_arrets_shift_min
//   16 Maint_curative_shift_min
//
// Onglet 2 (gid=5050608) — cadences par (salle × article × taille de lot)
//   0  N°_atelier
//   1  code_article
//   2  description
//   3  Equipement
//   4  Taille_lot
//   5  Cadence_objectif_b_min
//
// Convention IDs :
//   N°_atelier (col 1) = numéro de salle (ex. 149, 131, 464)
//   id_supabase (col 2) = ateliers.id Supabase (ex. 23, 4, 6)
//   plan_rooms.code = 'c'/'p'/'n' + N°_atelier  (ex. 'c149', 'n131', 'p464')

var SHEET_URL   = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vQqKb5_i0U7YeQYMiNEDy4X2gq6W_78NA2EuC2gRqSVXOKuBcBuXR8ASrE9Eq3admceATv4_gdAUppc/pub?gid=1383871669&single=true&output=csv'
var SHEET_URL_2 = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vQqKb5_i0U7YeQYMiNEDy4X2gq6W_78NA2EuC2gRqSVXOKuBcBuXR8ASrE9Eq3admceATv4_gdAUppc/pub?gid=5050608&single=true&output=csv'

var CACHE_TTL      = 5 * 60 * 1000   // 5 minutes
var _cache         = null
var _cacheTs       = 0
var _cacheCadences = null
var _cacheCadTs    = 0

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

var _num  = function(v) { var n = parseFloat((v || '').trim()); return isNaN(n) ? null : n }
var _int  = function(v) { var n = parseInt((v || '').trim());   return isNaN(n) ? null : n }

var _empty = function() {
  return { processus: [], ateliers: [], operationsMaster: [], planRooms: [] }
}

var _parse = function(text) {
  var lines = text.split(/\r?\n/).filter(function(l) { return l.trim() })
  if (lines.length < 2) return _empty()

  var rows = []
  for (var i = 1; i < lines.length; i++) {
    var cols   = _parseLine(lines[i])
    var atelId = parseInt((cols[1] || '').trim())
    var opNum  = parseInt((cols[4] || '').trim())
    if (isNaN(atelId)) continue
    rows.push({
      processus_nom:            (cols[0]  || '').trim(),
      atelier_id:               atelId,
      id_supabase:              _int(cols[2]),
      atelier_nom:              (cols[3]  || '').trim(),
      op_number:                isNaN(opNum) ? null : opNum,
      op_code:                  (cols[5]  || '').trim(),
      equipment_name:           (cols[6]  || '').trim(),
      trs_cible_pct:            _num(cols[7]),
      temps_util:               _num(cols[8]),    // heures utiles/jour (PDP capacité) — inséré entre TRS_cible et TO_shift
      to_shift_min:             _int(cols[9]),
      pause_min:                _int(cols[10]),
      vdlp_min:                 _int(cols[11]),
      vdlc_min:                 _int(cols[12]),
      chgt_format_min:          _int(cols[13]),
      reglage_lancement_min:    _int(cols[14]),
      micro_arrets_shift_min:   _int(cols[15]),
      maint_curative_shift_min: _int(cols[16]),
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
  // id = id_supabase → FK ateliers.id Supabase (compatible suivi_fabrication.atelier_id)
  // numero_atelier = N°_atelier (numéro de salle, ex. 131)
  var ateliers = rows.map(function(r) {
    return {
      id:                       r.id_supabase || r.atelier_id,
      numero_atelier:           r.atelier_id,
      nom_atelier:              r.atelier_nom,
      processus_id:             procMap[r.processus_nom] ? procMap[r.processus_nom].id : null,
      processus_nom:            r.processus_nom,
      actif:                    true,
      trs_cible_pct:            r.trs_cible_pct,
      to_shift_min:             r.to_shift_min,
      pause_min:                r.pause_min,
      vdlp_min:                 r.vdlp_min,
      vdlc_min:                 r.vdlc_min,
      chgt_format_min:          r.chgt_format_min,
      reglage_lancement_min:    r.reglage_lancement_min,
      micro_arrets_shift_min:   r.micro_arrets_shift_min,
      maint_curative_shift_min: r.maint_curative_shift_min
    }
  }).sort(function(a, b) { return (a.nom_atelier || '').localeCompare(b.nom_atelier || '') })

  // ── operations_master ──
  var operationsMaster = rows
    .filter(function(r) { return r.op_number !== null })
    .map(function(r) {
      return {
        id:             r.id_supabase || r.atelier_id,
        op_number:      r.op_number,
        op_code:        r.op_code,
        equipment_name: r.equipment_name,
        room_code:      _prefix(r.processus_nom, r.op_number) + r.atelier_id,
        room_name:      r.atelier_nom,
        processus:      r.processus_nom,
        trs_cible_pct:            r.trs_cible_pct,
        temps_util:               r.temps_util,
        to_shift_min:             r.to_shift_min,
        pause_min:                r.pause_min,
        vdlp_min:                 r.vdlp_min,
        vdlc_min:                 r.vdlc_min,
        chgt_format_min:          r.chgt_format_min,
        reglage_lancement_min:    r.reglage_lancement_min,
        micro_arrets_shift_min:   r.micro_arrets_shift_min,
        maint_curative_shift_min: r.maint_curative_shift_min
      }
    }).sort(function(a, b) { return (a.op_number || 0) - (b.op_number || 0) })

  // ── plan_rooms ──
  var planRooms = rows.map(function(r) {
    return {
      id:            r.atelier_id,
      id_supabase:   r.id_supabase,
      code:          _prefix(r.processus_nom, r.op_number) + r.atelier_id,
      nom:           r.equipment_name || r.atelier_nom,
      zone:          _zone(r.processus_nom, r.op_number),
      type:          r.processus_nom === 'Conditionnement' ? 'cond' : 'fab',
      op_number:     r.op_number,
      actif:         true,
      atelier_id:    null,
      equipement_id: null,
      trs_cible_pct:            r.trs_cible_pct,
      temps_util:               r.temps_util,
      to_shift_min:             r.to_shift_min,
      pause_min:                r.pause_min,
      vdlp_min:                 r.vdlp_min,
      vdlc_min:                 r.vdlc_min,
      chgt_format_min:          r.chgt_format_min,
      reglage_lancement_min:    r.reglage_lancement_min,
      micro_arrets_shift_min:   r.micro_arrets_shift_min,
      maint_curative_shift_min: r.maint_curative_shift_min
    }
  })

  return { processus, ateliers, operationsMaster, planRooms }
}

// ── Onglet 2 : cadences par (N°_atelier × code_article × taille_lot) ──
var _parseCadences = function(text) {
  var lines = text.split(/\r?\n/).filter(function(l) { return l.trim() })
  if (lines.length < 2) return []
  var result = []
  for (var i = 1; i < lines.length; i++) {
    var cols = _parseLine(lines[i])
    var numAtelier = parseInt((cols[0] || '').trim())
    if (isNaN(numAtelier)) continue
    result.push({
      numero_atelier:         numAtelier,
      code_article:           (cols[1] || '').trim(),
      description:            (cols[2] || '').trim(),
      equipment_name:         (cols[3] || '').trim(),
      taille_lot:             _int(cols[4]),
      cadence_objectif_b_min: _num(cols[5])
    })
  }
  return result
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
    console.warn('[googleSheets] Erreur chargement onglet 1 :', e.message)
    return _cache || _empty()
  }
}

var _fetchCadences = async function() {
  var now = Date.now()
  if (_cacheCadences && (now - _cacheCadTs) < CACHE_TTL) return _cacheCadences
  try {
    var r = await fetch(SHEET_URL_2)
    if (!r.ok) throw new Error('HTTP ' + r.status)
    var text = await r.text()
    _cacheCadences = _parseCadences(text)
    _cacheCadTs    = now
    return _cacheCadences
  } catch (e) {
    console.warn('[googleSheets] Erreur chargement cadences (onglet 2) :', e.message)
    return _cacheCadences || []
  }
}

// getAll() retourne onglet 1 + cadences onglet 2 en parallèle
export var getAll = async function() {
  var results = await Promise.all([_fetch(), _fetchCadences()])
  return Object.assign({}, results[0], { cadences: results[1] })
}

export var getProcessus        = async function() { var d = await _fetch(); return d.processus }
export var getAteliers         = async function() { var d = await _fetch(); return d.ateliers }
export var getOperationsMaster = async function() { var d = await _fetch(); return d.operationsMaster }
export var getPlanRooms        = async function() { var d = await _fetch(); return d.planRooms }
export var getCadences         = function()       { return _fetchCadences() }

// Forcer un rechargement depuis les feuilles (invalide les deux caches)
export var clearCache = function() {
  _cache = null; _cacheTs = 0
  _cacheCadences = null; _cacheCadTs = 0
}
