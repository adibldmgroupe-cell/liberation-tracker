-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 032 — planning_alert_log : compléter les policies RLS + purge
-- ───────────────────────────────────────────────────────────────────────────
-- La table planning_alert_log (migration 004) n'avait QUE les policies SELECT et
-- INSERT → tout DELETE était bloqué SILENCIEUSEMENT (0 ligne supprimée, sans
-- erreur), impossible de purger les entrées obsolètes. Règle N°13 : toute table
-- avec RLS doit avoir ses 4 policies.
--
-- Contexte : checkPlanningAlerts() pouvait journaliser des alertes de libération
-- pour des lots déjà accepté / refusé / sous_investigation (corrigé côté code).
-- On purge ces entrées sans objet, désormais que le DELETE est autorisé.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Policies manquantes (UPDATE + DELETE) ──
DROP POLICY IF EXISTS "rls_alert_log_update" ON planning_alert_log;
CREATE POLICY "rls_alert_log_update" ON planning_alert_log FOR UPDATE TO authenticated USING (true);

DROP POLICY IF EXISTS "rls_alert_log_delete" ON planning_alert_log;
CREATE POLICY "rls_alert_log_delete" ON planning_alert_log FOR DELETE TO authenticated USING (true);

-- ── 2. Purge des entrées obsolètes : lots déjà accepté / refusé / sous investigation ──
-- (alertes de libération sans objet — la date prévisionnelle n'a plus de sens)
DELETE FROM planning_alert_log
WHERE lot_id IN (
  SELECT id FROM lots WHERE statut_sap IN ('accepte','refuse','sous_investigation')
);

-- ── Vérification ──
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'planning_alert_log' ORDER BY cmd;
