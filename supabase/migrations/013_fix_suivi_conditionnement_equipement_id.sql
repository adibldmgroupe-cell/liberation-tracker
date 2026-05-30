-- ═══════════════════════════════════════════════════════════════
-- Migration 013 — Corriger suivi_conditionnement.equipement_id
-- Problème : colonne créée en UUID au lieu de bigint
-- plan_rooms.equipement_id = bigint → FK doit être bigint
-- ═══════════════════════════════════════════════════════════════

-- Déjà exécuté manuellement le 2026-05-31 dans Supabase SQL Editor :
-- ALTER TABLE suivi_conditionnement ALTER COLUMN equipement_id TYPE bigint USING NULL;

-- Vérification
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'suivi_conditionnement'
ORDER BY ordinal_position;
