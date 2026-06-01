-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 021 — RLS de la table `cadences` (règle CLAUDE.md N°13)
-- ───────────────────────────────────────────────────────────────────────────
-- BUG observé (01/06/2026) :
--   Référentiel → Processus & Ateliers → onglet « GS Cadences » → « 💾 Synchroniser »
--   échoue avec :
--     « new row violates row-level security policy for table "cadences" »
--
--   La table `cadences` a RLS ACTIVÉ mais AUCUNE policy INSERT/UPDATE → l'upsert
--   GS → base est refusé → la table reste VIDE (0 ligne) → au démarrage de session
--   TRS, `cadence_objectif_snapshot` est null → Performance et TRS = « — ».
--   (Même piège que migration 020 sur production_sessions.)
--
--   `operations_master` (31 lignes) et `plan_rooms` (66 lignes) sont déjà peuplées
--   → leurs policies d'écriture existent → on n'y touche pas.
--
-- CAPA : garantir les 4 policies (SELECT/INSERT/UPDATE/DELETE) sur `cadences`.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.cadences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rls_cadences_select" ON public.cadences;
DROP POLICY IF EXISTS "rls_cadences_insert" ON public.cadences;
DROP POLICY IF EXISTS "rls_cadences_update" ON public.cadences;
DROP POLICY IF EXISTS "rls_cadences_delete" ON public.cadences;

CREATE POLICY "rls_cadences_select" ON public.cadences FOR SELECT TO authenticated USING (true);
CREATE POLICY "rls_cadences_insert" ON public.cadences FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "rls_cadences_update" ON public.cadences FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "rls_cadences_delete" ON public.cadences FOR DELETE TO authenticated USING (true);

-- ── Vérification : doit lister 4 lignes (SELECT/INSERT/UPDATE/DELETE) ──
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'cadences' ORDER BY cmd;
