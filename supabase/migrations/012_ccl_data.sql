-- ═══════════════════════════════════════════════════════════
-- MIGRATION 012 — Circuit CCL — ÉTAPE 2 : permissions + données
-- ⚠ À exécuter APRÈS 011_ccl_circuit.sql (enum déjà commité)
-- Idempotent (ON CONFLICT DO NOTHING, WHERE NOT EXISTS)
-- ═══════════════════════════════════════════════════════════

-- 1. Permissions
INSERT INTO permissions (service, action, allowed) VALUES
  ('aq',    'emettre_ccl',             true),
  ('aq',    'accuser_reception_document', true),
  ('dt',    'approuver_ccl',           true),
  ('dt',    'retourner_document',      true),
  ('admin', 'emettre_ccl',             true),
  ('admin', 'approuver_ccl',           true)
ON CONFLICT (service, action) DO NOTHING;

-- 2. CCL manquants pour tous les lots existants
INSERT INTO liberation_documents (lot_id, type_document, statut, is_applicable, is_required, service_emetteur)
SELECT l.id, 'ccl', 'non_emis', true, true, 'aq'
FROM lots l
WHERE NOT EXISTS (
  SELECT 1 FROM liberation_documents ld
  WHERE ld.lot_id = l.id AND ld.type_document = 'ccl'
);

-- 3. Lots ACCEPTÉS : marquer le CCL comme approuvé
UPDATE liberation_documents
SET statut = 'approuve_dt', approved_at = NOW(), updated_at = NOW()
WHERE type_document = 'ccl'
  AND statut != 'approuve_dt'
  AND lot_id IN (SELECT id FROM lots WHERE statut_sap = 'accepte');
