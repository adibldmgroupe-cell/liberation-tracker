-- ═══════════════════════════════════════════════════════════
-- MIGRATION 010 — Initialisation liberation_documents manquants
-- Crée les entrées IF/IC/DA PC/DA Micro pour tous les lots
-- qui n'en ont pas encore. Idempotent (WHERE NOT EXISTS).
-- ═══════════════════════════════════════════════════════════

-- 1. IF manquants
INSERT INTO liberation_documents (lot_id, type_document, statut, is_applicable, is_required, service_emetteur)
SELECT l.id, 'if', 'non_emis', true, true, 'fabrication'
FROM lots l
WHERE NOT EXISTS (
  SELECT 1 FROM liberation_documents ld
  WHERE ld.lot_id = l.id AND ld.type_document = 'if'
);

-- 2. IC manquants
INSERT INTO liberation_documents (lot_id, type_document, statut, is_applicable, is_required, service_emetteur)
SELECT l.id, 'ic', 'non_emis', true, true, 'conditionnement'
FROM lots l
WHERE NOT EXISTS (
  SELECT 1 FROM liberation_documents ld
  WHERE ld.lot_id = l.id AND ld.type_document = 'ic'
);

-- 3. DA PC manquants
INSERT INTO liberation_documents (lot_id, type_document, statut, is_applicable, is_required, service_emetteur)
SELECT l.id, 'da_pc', 'non_emis', true, true, 'lcq'
FROM lots l
WHERE NOT EXISTS (
  SELECT 1 FROM liberation_documents ld
  WHERE ld.lot_id = l.id AND ld.type_document = 'da_pc'
);

-- 4. DA Micro manquants (non applicable par défaut)
INSERT INTO liberation_documents (lot_id, type_document, statut, is_applicable, is_required, service_emetteur)
SELECT l.id, 'da_micro', 'non_emis', false, false, 'lcq'
FROM lots l
WHERE NOT EXISTS (
  SELECT 1 FROM liberation_documents ld
  WHERE ld.lot_id = l.id AND ld.type_document = 'da_micro'
);

-- 5. liberation_dossiers manquants
INSERT INTO liberation_dossiers (lot_id, da_micro_applicable)
SELECT l.id, false
FROM lots l
WHERE NOT EXISTS (
  SELECT 1 FROM liberation_dossiers ld
  WHERE ld.lot_id = l.id
);

-- 6. Lots ACCEPTÉS : marquer les documents (y compris nouvellement créés) comme approuvés
UPDATE liberation_documents
SET statut = 'approuve_dt', approved_at = NOW(), updated_at = NOW()
WHERE statut != 'approuve_dt'
  AND is_applicable = true
  AND lot_id IN (SELECT id FROM lots WHERE statut_sap = 'accepte');

-- 7. Lots ACCEPTÉS : mettre à jour le dossier de libération
UPDATE liberation_dossiers
SET if_approved = true, ic_approved = true, da_pc_approved = true,
    deviations_closed = true, pieces_complementaires_ok = true,
    statut = 'libere', updated_at = NOW()
WHERE lot_id IN (SELECT id FROM lots WHERE statut_sap = 'accepte');

UPDATE liberation_dossiers
SET da_micro_approved = true, updated_at = NOW()
WHERE da_micro_applicable = true
  AND lot_id IN (SELECT id FROM lots WHERE statut_sap = 'accepte');
