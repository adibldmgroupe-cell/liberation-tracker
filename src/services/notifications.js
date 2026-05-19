import { supabase } from '../supabase'

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
