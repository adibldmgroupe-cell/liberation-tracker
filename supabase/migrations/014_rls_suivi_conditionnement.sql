-- ═══════════════════════════════════════════════════════════════
-- Migration 014 — RLS policies suivi_conditionnement
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE suivi_conditionnement ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rls_suivi_cond_select" ON suivi_conditionnement;
DROP POLICY IF EXISTS "rls_suivi_cond_insert" ON suivi_conditionnement;
DROP POLICY IF EXISTS "rls_suivi_cond_update" ON suivi_conditionnement;
DROP POLICY IF EXISTS "rls_suivi_cond_delete" ON suivi_conditionnement;

CREATE POLICY "rls_suivi_cond_select" ON suivi_conditionnement FOR SELECT TO authenticated USING (true);
CREATE POLICY "rls_suivi_cond_insert" ON suivi_conditionnement FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "rls_suivi_cond_update" ON suivi_conditionnement FOR UPDATE TO authenticated USING (true);
CREATE POLICY "rls_suivi_cond_delete" ON suivi_conditionnement FOR DELETE TO authenticated USING (true);
