import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseKey)

// Les opérations d'administration (création/suppression de comptes) passent
// par src/services/adminAuth.js qui utilise fetch() directement sur l'API REST
// Supabase, contournant la restriction du SDK sur les clés sb_secret_* en navigateur.
