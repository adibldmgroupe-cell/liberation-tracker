// Opérations d'administration des comptes via l'API REST Supabase
// (le SDK JS bloque l'usage de la service key en navigateur depuis les nouvelles versions ;
//  fetch() appelle directement le serveur sans cette restriction côté client)

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const serviceKey = import.meta.env.VITE_SUPABASE_SERVICE_KEY

function authHeaders() {
  return {
    'Content-Type': 'application/json',
    'apikey': serviceKey,
    'Authorization': 'Bearer ' + serviceKey
  }
}

export async function adminCreateUser({ email, password, nom, prenom, service, role }) {
  if (!serviceKey) throw new Error('VITE_SUPABASE_SERVICE_KEY non configurée')
  const res = await fetch(supabaseUrl + '/auth/v1/admin/users', {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { nom, prenom, service, role }
    })
  })
  const data = await res.json()
  if (!res.ok) throw new Error(data.message || data.msg || 'Erreur lors de la création du compte')
  return data
}

export async function adminDeleteUser(userId) {
  if (!serviceKey) throw new Error('VITE_SUPABASE_SERVICE_KEY non configurée')
  const res = await fetch(supabaseUrl + '/auth/v1/admin/users/' + userId, {
    method: 'DELETE',
    headers: authHeaders()
  })
  if (!res.ok) {
    const data = await res.json()
    throw new Error(data.message || data.msg || 'Erreur lors de la suppression du compte')
  }
}
