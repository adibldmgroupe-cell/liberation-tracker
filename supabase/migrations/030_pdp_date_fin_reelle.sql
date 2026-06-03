-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 030 — Date de fin réelle sur le PDP conditionnement
-- ───────────────────────────────────────────────────────────────────────────
-- L'équipe planification saisit quotidiennement la date de fin RÉELLE du lot en
-- cours. Le PDP s'en sert pour :
--   • calculer le retard (jours ouvrés : fin réelle − fin estimée),
--   • aligner la date estimée sur la réelle pour les lots terminés,
--   • décaler tout l'aval du retard cumulé (les lots suivants repartent après
--     la dernière fin réelle).
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.planification_conditionnement
  ADD COLUMN IF NOT EXISTS date_fin_reelle date;

-- ── Vérification ──
SELECT column_name FROM information_schema.columns
WHERE table_name = 'planification_conditionnement' AND column_name = 'date_fin_reelle';
