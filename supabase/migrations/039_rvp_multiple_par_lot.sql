-- ═══════════════════════════════════════════════════════════
-- MIGRATION 039 — RVP multiple par lot (Fabrication / Conditionnement / LCQ)
--
-- PROBLÈME
-- La contrainte uq_libdoc_lot_type UNIQUE(lot_id, type_document) (migration 018,
-- pour l'upsert de l'import historique) empêche d'avoir plus d'UN document
-- type_document='rvp' par lot. Or un lot a jusqu'à 3 RVP (Fabrication,
-- Conditionnement, LCQ), TOUS type_document='rvp', distingués par service_emetteur.
-- Symptôme : RVP Fab passe, RVP Cond/LCQ rejetés avec
--   « duplicate key value violates unique constraint "uq_libdoc_lot_type" ».
--
-- FIX
-- Remplacer la contrainte par UNIQUE(lot_id, type_document, service_emetteur).
--  • Types non-RVP (if/ic/da_pc/da_micro/ccl/maj_*/cloture_sap_*) : chaque type a un
--    service_emetteur FIXE → (lot,type,service) reste équivalent à (lot,type) (1/lot).
--  • RVP : autorise (lot,'rvp','fabrication') + (...'conditionnement') + (...'lcq').
-- L'import (src/services/import.js) passe son upsert sur
--   onConflict = lot_id,type_document,service_emetteur (commit applicatif lié).
--
-- À EXÉCUTER UNE FOIS dans Supabase SQL Editor (un seul bloc — pas d'enum, règle N°12 OK).
-- ═══════════════════════════════════════════════════════════

-- 1. Backfill défensif : garantir service_emetteur non-null sur les types
--    importables (sinon l'upsert 3-colonnes de l'import créerait des doublons
--    NULL vs service). Aligné sur le SVC map de l'import et SVC_MAP applicatif.
UPDATE liberation_documents SET service_emetteur = 'fabrication'     WHERE service_emetteur IS NULL AND type_document = 'if';
UPDATE liberation_documents SET service_emetteur = 'conditionnement' WHERE service_emetteur IS NULL AND type_document = 'ic';
UPDATE liberation_documents SET service_emetteur = 'lcq'             WHERE service_emetteur IS NULL AND type_document IN ('da_pc','da_micro');
UPDATE liberation_documents SET service_emetteur = 'aq'              WHERE service_emetteur IS NULL AND type_document = 'ccl';

-- 2. Remplacer la contrainte 2-colonnes par la 3-colonnes (idempotent).
ALTER TABLE liberation_documents DROP CONSTRAINT IF EXISTS uq_libdoc_lot_type;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uq_libdoc_lot_type_svc'
  ) THEN
    ALTER TABLE liberation_documents
      ADD CONSTRAINT uq_libdoc_lot_type_svc UNIQUE (lot_id, type_document, service_emetteur);
  END IF;
END $$;

-- Vérification rapide (optionnel) :
-- SELECT conname FROM pg_constraint
--   WHERE conrelid = 'liberation_documents'::regclass AND contype = 'u';
-- Attendu : uq_libdoc_lot_type_svc (et plus uq_libdoc_lot_type).
