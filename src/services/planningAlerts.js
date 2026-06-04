import { supabase } from '../supabase'
import { createNotification } from './notifications'

var DATE_DEFS = [
  { key: 'lcq', cible: 'date_lcq_cible', revisee: 'date_lcq_revisee', service: 'lcq', label: 'LCQ' },
  { key: 'aq',  cible: 'date_aq_cible',  revisee: 'date_aq_revisee',  service: 'aq',  label: 'AQ'  },
  { key: 'dt',  cible: 'date_dt_cible',  revisee: 'date_dt_revisee',  service: 'dt',  label: 'DT'  },
]

export async function checkPlanningAlerts() {
  var today = new Date()
  today.setHours(0, 0, 0, 0)
  var todayStr    = today.toISOString().split('T')[0]
  var tomorrow    = new Date(today); tomorrow.setDate(tomorrow.getDate() + 1)
  var tomorrowStr = tomorrow.toISOString().split('T')[0]

  var res = await supabase.from('lot_planning')
    .select('lot_id, date_lcq_cible, date_lcq_revisee, date_aq_cible, date_aq_revisee, date_dt_cible, date_dt_revisee, lots(numero_lot, statut_sap)')
  if (!res.data || !res.data.length) return

  for (var i = 0; i < res.data.length; i++) {
    var row = res.data[i]
    var lotNum = row.lots ? row.lots.numero_lot : ('Lot #' + row.lot_id)

    // Pas d'alerte de libération si le lot est déjà accepté (libéré), refusé, ou sous investigation :
    // dans ces états la date prévisionnelle de libération n'a plus de sens (libération faite/abandonnée/suspendue).
    var statutSap = row.lots ? row.lots.statut_sap : null
    if (statutSap === 'accepte' || statutSap === 'refuse' || statutSap === 'sous_investigation') continue

    for (var j = 0; j < DATE_DEFS.length; j++) {
      var def = DATE_DEFS[j]
      var targetDate = row[def.revisee] || row[def.cible]
      if (!targetDate) continue

      var level
      if (targetDate < todayStr)    level = 'depasse'
      else if (targetDate === todayStr)    level = 'jour_j'
      else if (targetDate === tomorrowStr) level = 'j_moins_1'
      else continue

      // Vérification déduplication (une seule alerte par lot/type/niveau/jour)
      var logCheck = await supabase.from('planning_alert_log')
        .select('id')
        .eq('lot_id',   row.lot_id)
        .eq('date_type', def.key)
        .eq('level',    level)
        .eq('alert_day', todayStr)
        .maybeSingle()
      if (logCheck.data) continue

      // Envoi de la notification
      var levelLabel = level === 'depasse'   ? '⛔ Dépassé'
                     : level === 'jour_j'    ? '🔴 Aujourd\'hui'
                     :                         '🟡 J-1 (demain)'
      var dateStr = new Date(targetDate + 'T00:00:00').toLocaleDateString('fr-FR')
      await createNotification(
        def.service, row.lot_id, null,
        'Lot ' + lotNum + ' — Libération ' + def.label + ' : ' + levelLabel + ' (' + dateStr + ')',
        'planning_alert'
      )

      // Log pour éviter les doublons
      await supabase.from('planning_alert_log').insert({
        lot_id: row.lot_id, date_type: def.key, target_date: targetDate,
        level: level, alert_day: todayStr
      })
    }
  }
}
