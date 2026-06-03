-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 029 — suivi_fabrication.statut : autoriser 'Planifié'
-- ───────────────────────────────────────────────────────────────────────────
-- BUG latent (règle N°17 — échec silencieux) :
--   La contrainte CHECK « suivi_fabrication_statut_check » n'autorisait que
--   ['En cours','Clôturé','Arrêt']. Or le PDP Fabrication (vue « Gérer PDP »),
--   le modal « Nouveau FAB » et l'import Google Sheets insèrent statut='Planifié'.
--   → tout INSERT 'Planifié' renvoyait 23514 ; l'import GS ne vérifiait pas
--     res.error → lignes FAB planifiées SILENCIEUSEMENT perdues (PDP fab vide).
--
-- Vérifié en live le 03/06/2026 : INSERT statut='Planifié' → 400 / 23514.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.suivi_fabrication DROP CONSTRAINT IF EXISTS suivi_fabrication_statut_check;
ALTER TABLE public.suivi_fabrication
  ADD CONSTRAINT suivi_fabrication_statut_check
  CHECK (statut = ANY (ARRAY['Planifié'::text, 'En cours'::text, 'Clôturé'::text, 'Arrêt'::text]));

-- ── Vérification ──
SELECT conname, pg_get_constraintdef(oid) AS def
FROM pg_constraint
WHERE conrelid = 'public.suivi_fabrication'::regclass AND contype = 'c';
