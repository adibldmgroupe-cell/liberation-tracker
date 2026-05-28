-- ═══════════════════════════════════════════════════════════
-- MIGRATION 011 — Circuit CCL — ÉTAPE 1 : enum uniquement
-- ⚠ EXÉCUTER EN PREMIER, SEUL, dans le SQL Editor.
--   PostgreSQL ne permet pas d'utiliser une nouvelle valeur
--   d'enum dans la même transaction que son ALTER TYPE.
--   Exécutez ensuite 012_ccl_data.sql dans une 2e exécution.
-- ═══════════════════════════════════════════════════════════

ALTER TYPE doc_type ADD VALUE IF NOT EXISTS 'ccl';
