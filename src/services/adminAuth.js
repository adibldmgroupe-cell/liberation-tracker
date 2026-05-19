// Opérations d'administration des comptes via une Supabase Edge Function.
// L'Edge Function tourne côté serveur et utilise la service key sans restriction navigateur.

import { supabase } from '../supabase'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

async function callAdminFunction(body) {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) throw new Error('Non authentifié')

  const res = await fetch(supabaseUrl + '/functions/v1/clever-task', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + session.access_token,
      'apikey': anonKey
    },
    body: JSON.stringify(body)
  })

  const data = await res.json()
  if (!res.ok) throw new Error(data.error || 'Erreur lors de l\'opération')
  return data
}

export async function adminCreateUser({ email, password, nom, prenom, service, role }) {
  return callAdminFunction({ action: 'create', email, password, nom, prenom, service, role })
}

export async function adminDeleteUser(userId) {
  return callAdminFunction({ action: 'delete', userId })
}
