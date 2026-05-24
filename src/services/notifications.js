import { supabase } from '../supabase'

export async function check48hDeviations() {
  var cutoff = new Date(Date.now() - 48 * 3600 * 1000).toISOString()
  var res = await supabase.from('deviations')
    .select('id, lot_id, declared_service, lots(numero_lot)')
    .in('statut', ['ouverte', 'en_cours'])
    .eq('notified_48h', false)
    .lte('declared_at', cutoff)
  if (!res.data || !res.data.length) return
  for (var i = 0; i < res.data.length; i++) {
    var dev = res.data[i]
    var svc = dev.declared_service || 'admin'
    var lotNum = dev.lots ? dev.lots.numero_lot : ''
    await createNotification(svc, dev.lot_id, null,
      'Lot ' + lotNum + ' — Déviation ouverte depuis plus de 48h',
      'deviation_48h')
    await supabase.from('deviations').update({ notified_48h: true }).eq('id', dev.id)
  }
}

export async function createNotification(targetService, lotId, documentId, message, eventType) {
  await supabase.from('notifications').insert({
    service: targetService,
    lot_id: lotId,
    document_id: documentId,
    message: message,
    event_type: eventType,
    created_at: new Date().toISOString()
  })
}

export async function getNotifications(service, isAdmin, limit) {
  var query = supabase.from('notifications')
    .select('*, lots(numero_lot)')
    .order('created_at', { ascending: false })
    .limit(limit || 50)

  // Admin voit toutes les notifications
  if (!isAdmin) {
    query = query.eq('service', service)
  }

  var res = await query
  return res.data || []
}

export async function getUnreadCount(service, isAdmin) {
  var query = supabase.from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('is_read', false)

  if (!isAdmin) {
    query = query.eq('service', service)
  }

  var res = await query
  return res.count || 0
}

export async function markAsRead(notifId) {
  await supabase.from('notifications').update({ is_read: true }).eq('id', notifId)
}

export async function markAllAsRead(service, isAdmin) {
  var query = supabase.from('notifications').update({ is_read: true }).eq('is_read', false)
  if (!isAdmin) {
    query = query.eq('service', service)
  }
  await query
}

// Check for new notifications since last check
export async function getNewNotifications(service, isAdmin, sinceTimestamp) {
  var query = supabase.from('notifications')
    .select('*, lots(numero_lot)')
    .eq('is_read', false)
    .gt('created_at', sinceTimestamp)
    .order('created_at', { ascending: false })
    .limit(5)

  if (!isAdmin) {
    query = query.eq('service', service)
  }

  var res = await query
  return res.data || []
}
