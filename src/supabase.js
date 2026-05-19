import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY
const supabaseServiceKey = import.meta.env.VITE_SUPABASE_SERVICE_KEY

export const supabase = createClient(supabaseUrl, supabaseKey)

// Client admin — utilise la service key pour les opérations d'administration
// (création / suppression de comptes via auth.admin.*)
// Note : VITE_* variables sont exposées dans le bundle client.
// L'usage de ce client doit rester strictement limité aux pages /admin/*
// accessibles uniquement aux utilisateurs avec service = 'admin'.
export const supabaseAdmin = supabaseServiceKey
  ? createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })
  : null
