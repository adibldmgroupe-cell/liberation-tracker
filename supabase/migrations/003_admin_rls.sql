-- ═══════════════════════════════════════════════════════════
-- MIGRATION 003 — Admin RLS sur profiles et permissions
-- Exécuter dans Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════

-- Fonction helper : vérifie si l'utilisateur courant a service = 'admin'
-- SECURITY DEFINER : s'exécute en tant que owner (postgres) pour éviter
-- la récursion RLS lors de la lecture de la table profiles elle-même.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND service = 'admin'
  );
$$;

-- Permettre à l'admin de modifier n'importe quel profil
-- (la politique "write_auth" existante permet déjà à chacun de modifier son propre profil)
CREATE POLICY "admin_update_any" ON profiles
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Permettre à l'admin de lire, insérer, modifier et supprimer les permissions
CREATE POLICY "admin_write_permissions" ON permissions
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
