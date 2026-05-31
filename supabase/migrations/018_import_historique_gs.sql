-- ═══════════════════════════════════════════════════════════
-- MIGRATION 018 — Import Historique (Google Sheets) depuis LotsPage
-- Prérequis pour : upsert batch des documents + bouton « Vider & réimporter ».
-- À exécuter UNE SEULE FOIS dans Supabase SQL Editor (un seul bloc, pas d'enum).
-- ═══════════════════════════════════════════════════════════

-- 1. Dédoublonnage défensif de liberation_documents
--    (garde la ligne la plus récente par couple lot_id + type_document)
--    avant d'ajouter la contrainte d'unicité.
DELETE FROM liberation_documents a
USING liberation_documents b
WHERE a.lot_id = b.lot_id
  AND a.type_document = b.type_document
  AND a.id < b.id;

-- 2. Contrainte UNIQUE(lot_id, type_document) — nécessaire pour l'upsert batch
--    des documents lors de l'import Historique. Idempotent.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uq_libdoc_lot_type'
  ) THEN
    ALTER TABLE liberation_documents
      ADD CONSTRAINT uq_libdoc_lot_type UNIQUE (lot_id, type_document);
  END IF;
END $$;

-- 3. Policies DELETE manquantes (RLS) pour le vidage « propre ».
--    Règle N°13 : ces tables n'avaient qu'une policy INSERT, donc Supabase
--    bloquait silencieusement leur suppression côté application.
--    (lots possède déjà une policy FOR ALL ; son cascade gère le reste.)
DROP POLICY IF EXISTS "delete_auth" ON order_validations;
CREATE POLICY "delete_auth" ON order_validations
  FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "delete_auth" ON notifications;
CREATE POLICY "delete_auth" ON notifications
  FOR DELETE TO authenticated USING (true);

-- Vérification rapide (optionnel) :
-- SELECT conname FROM pg_constraint WHERE conname = 'uq_libdoc_lot_type';
-- SELECT policyname, cmd FROM pg_policies WHERE tablename IN ('order_validations','notifications');
