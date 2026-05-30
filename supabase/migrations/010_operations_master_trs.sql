-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 010 — operations_master : colonnes TRS + contrainte UNIQUE room_code
-- Exécuter dans Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Supprimer les lignes avec room_code au format numérique ancien (ex: '149')
--    Le nouveau format importé depuis GS utilise un préfixe lettre (ex: 'c149')
DELETE FROM operations_master WHERE room_code ~ '^[0-9]+$';

-- 2. Ajouter les colonnes TRS (identiques à plan_rooms, noms courts)
ALTER TABLE operations_master ADD COLUMN IF NOT EXISTS trs_cible_pct    numeric;
ALTER TABLE operations_master ADD COLUMN IF NOT EXISTS to_shift_min      int;
ALTER TABLE operations_master ADD COLUMN IF NOT EXISTS pause_min         int;
ALTER TABLE operations_master ADD COLUMN IF NOT EXISTS vdlp_min          int;
ALTER TABLE operations_master ADD COLUMN IF NOT EXISTS vdlc_min          int;
ALTER TABLE operations_master ADD COLUMN IF NOT EXISTS chgt_format_min   int;
ALTER TABLE operations_master ADD COLUMN IF NOT EXISTS reglage_min        int;
ALTER TABLE operations_master ADD COLUMN IF NOT EXISTS micro_arrets_min  int;
ALTER TABLE operations_master ADD COLUMN IF NOT EXISTS maint_min          int;
ALTER TABLE operations_master ADD COLUMN IF NOT EXISTS updated_at         timestamptz DEFAULT now();

-- 3. Contrainte UNIQUE sur room_code pour permettre l'upsert depuis GS
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uq_opmaster_roomcode'
  ) THEN
    ALTER TABLE operations_master ADD CONSTRAINT uq_opmaster_roomcode UNIQUE (room_code);
  END IF;
END$$;

-- 4. RLS (lecture pour tous les authentifiés, écriture admin uniquement via service role)
ALTER TABLE operations_master ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rls_opmaster_select" ON operations_master;
CREATE POLICY "rls_opmaster_select" ON operations_master FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "rls_opmaster_all" ON operations_master;
CREATE POLICY "rls_opmaster_all"    ON operations_master FOR ALL    TO authenticated USING (true) WITH CHECK (true);

-- Vérification
SELECT room_code, processus, op_number, equipment_name FROM operations_master ORDER BY op_number LIMIT 10;
