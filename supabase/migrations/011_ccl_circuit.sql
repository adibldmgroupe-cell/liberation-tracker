-- ═══════════════════════════════════════════════════════════
-- MIGRATION 011 — Circuit CCL (Certificat de Conformité du Lot)
-- AQ transmet → DT accuse réception → DT libère (ou retourne)
-- Idempotent (ON CONFLICT DO NOTHING, WHERE NOT EXISTS)
-- ═══════════════════════════════════════════════════════════

-- 1. Ajouter le type 'ccl' à l'enum doc_type
ALTER TYPE doc_type ADD VALUE IF NOT EXISTS 'ccl';

-- 2. Permissions
INSERT INTO permissions (service, action, allowed) VALUES
  ('aq',    'emettre_ccl',   true),
  ('aq',    'accuser_reception_document', true),
  ('dt',    'approuver_ccl', true),
  ('dt',    'retourner_document', true),
  ('admin', 'emettre_ccl',   true),
  ('admin', 'approuver_ccl', true)
ON CONFLICT (service, action) DO NOTHING;

-- 3. CCL manquants pour tous les lots
INSERT INTO liberation_documents (lot_id, type_document, statut, is_applicable, is_required, service_emetteur)
SELECT l.id, 'ccl', 'non_emis', true, true, 'aq'
FROM lots l
WHERE NOT EXISTS (
  SELECT 1 FROM liberation_documents ld
  WHERE ld.lot_id = l.id AND ld.type_document = 'ccl'
);

-- 4. Lots ACCEPTÉS : marquer le CCL comme approuvé
UPDATE liberation_documents
SET statut = 'approuve_dt', approved_at = NOW(), updated_at = NOW()
WHERE type_document = 'ccl'
  AND statut != 'approuve_dt'
  AND lot_id IN (SELECT id FROM lots WHERE statut_sap = 'accepte');
