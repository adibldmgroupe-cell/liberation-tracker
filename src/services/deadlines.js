// Service : délais de traitement (SLA) par service × type d'item.
// Table document_deadlines (migration 033). type_key ∈ of, oc, if, ic, da_pc, rvp, aql_fab, aql_cond.
import { supabase } from '../supabase'

// Types gérés + libellés (colonnes de la table de management)
export var DEADLINE_TYPES = [
  { key: 'of',       label: 'OF' },
  { key: 'oc',       label: 'OC' },
  { key: 'if',       label: 'IF' },
  { key: 'ic',       label: 'IC' },
  { key: 'da_pc',    label: 'DA PC' },
  { key: 'rvp',      label: 'RVP' },
  { key: 'aql_fab',  label: 'AQL Fab' },
  { key: 'aql_cond', label: 'AQL Cond' },
]

// Services qui traitent chaque type (cellules pertinentes de la grille)
export var DEADLINE_SERVICES = [
  { key: 'planification',   label: 'Planification',   types: ['of','oc'] },
  { key: 'stock',           label: 'Stock',           types: ['of','oc'] },
  { key: 'aq',              label: 'AQ',              types: ['of','oc','if','ic','da_pc','rvp'] },
  { key: 'dt',              label: 'DT',              types: ['of','oc','if','ic','da_pc','rvp'] },
  { key: 'aq_dap',          label: 'AQ DAP',          types: ['of','oc'] },
  { key: 'fabrication',     label: 'Fabrication',     types: ['if','rvp','aql_fab'] },
  { key: 'conditionnement', label: 'Conditionnement', types: ['ic','rvp','aql_cond'] },
  { key: 'lcq',             label: 'LCQ',             types: ['da_pc','rvp','aql_fab','aql_cond'] },
]

var _cache = null

export async function loadDeadlines() {
  var res = await supabase.from('document_deadlines').select('service,type_key,delai_jours')
  _cache = {}
  ;(res.data || []).forEach(function(d) { _cache[d.service + '|' + d.type_key] = d.delai_jours })
  return _cache
}

// Délai (jours) configuré pour (service, type) — null si non défini
export function getDelai(service, typeKey) {
  if (!_cache) return null
  var v = _cache[service + '|' + typeKey]
  return (v === undefined || v === null) ? null : v
}

// Calcule l'échéance à partir d'une date de départ + délai.
// Renvoie null si pas de délai/date. Sinon { dueStr, daysLeft, level, label, cls }.
export function computeDeadline(startDate, delaiJours) {
  if (delaiJours === null || delaiJours === undefined || !startDate) return null
  var start = new Date(startDate)
  if (isNaN(start.getTime())) return null
  var due = new Date(start.getTime())
  due.setDate(due.getDate() + delaiJours)
  due.setHours(0, 0, 0, 0)
  var today = new Date()
  today.setHours(0, 0, 0, 0)
  var daysLeft = Math.round((due.getTime() - today.getTime()) / 86400000)
  var level = daysLeft < 0 ? 'overdue' : daysLeft === 0 ? 'today' : 'ok'
  var label = daysLeft < 0 ? ('En retard (J+' + (-daysLeft) + ')')
            : daysLeft === 0 ? 'Aujourd’hui'
            : ('J-' + daysLeft)
  return { dueStr: due.toLocaleDateString('fr-FR'), daysLeft: daysLeft, level: level, label: label, cls: 'dl-' + level }
}
