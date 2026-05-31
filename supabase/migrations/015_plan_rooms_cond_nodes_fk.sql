-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 015 — Nœuds cond dans plan_rooms + FK suivi_conditionnement
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 1. Insérer les nœuds conditionnement dans plan_rooms ────────────────────
-- equipement_id lié par nom depuis equipements_conditionnement

INSERT INTO plan_rooms (code, nom, zone, type, equipement_id)
VALUES ('c149', 'MB421',          'cond_primaire', 'cond', (SELECT id FROM equipements_conditionnement WHERE nom_equipement ILIKE '%MB421%' OR nom_equipement ILIKE '%MARCHESINI%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id WHERE plan_rooms.equipement_id IS NULL;

INSERT INTO plan_rooms (code, nom, zone, type, equipement_id)
VALUES ('c148', 'IMA TR100L',     'cond_primaire', 'cond', (SELECT id FROM equipements_conditionnement WHERE nom_equipement ILIKE '%TR100%' OR nom_equipement ILIKE '%IMA TR%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id WHERE plan_rooms.equipement_id IS NULL;

INSERT INTO plan_rooms (code, nom, zone, type, equipement_id)
VALUES ('c147', 'INTEGRA 300',    'cond_primaire', 'cond', (SELECT id FROM equipements_conditionnement WHERE nom_equipement ILIKE '%INTEGRA 300%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id WHERE plan_rooms.equipement_id IS NULL;

INSERT INTO plan_rooms (code, nom, zone, type, equipement_id)
VALUES ('c146', 'IMA PG SUPER 1', 'cond_primaire', 'cond', (SELECT id FROM equipements_conditionnement WHERE nom_equipement ILIKE '%PG SUPER 1%' OR nom_equipement ILIKE '%SUPER 1%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id WHERE plan_rooms.equipement_id IS NULL;

INSERT INTO plan_rooms (code, nom, zone, type, equipement_id)
VALUES ('c220', 'MARCH. R,P',     'cond_primaire', 'cond', (SELECT id FROM equipements_conditionnement WHERE nom_equipement ILIKE '%MARCHESINI%' OR nom_equipement ILIKE '%R,P%' OR nom_equipement ILIKE '%R.P%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id WHERE plan_rooms.equipement_id IS NULL;

INSERT INTO plan_rooms (code, nom, zone, type, equipement_id)
VALUES ('c222', 'INTEGRA 520',    'cond_primaire', 'cond', (SELECT id FROM equipements_conditionnement WHERE nom_equipement ILIKE '%INTEGRA 520%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id WHERE plan_rooms.equipement_id IS NULL;

INSERT INTO plan_rooms (code, nom, zone, type, equipement_id)
VALUES ('c223', 'IMA PG SUPER 2', 'cond_primaire', 'cond', (SELECT id FROM equipements_conditionnement WHERE nom_equipement ILIKE '%PG SUPER 2%' OR nom_equipement ILIKE '%SUPER 2%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id WHERE plan_rooms.equipement_id IS NULL;

-- ─── 2. FK suivi_conditionnement ─────────────────────────────────────────────
-- lot_id → lots.id  (nécessaire pour le join lots() dans PostgREST)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_suivi_cond_lot'
  ) THEN
    ALTER TABLE suivi_conditionnement
      ADD CONSTRAINT fk_suivi_cond_lot FOREIGN KEY (lot_id) REFERENCES lots(id) ON DELETE CASCADE;
  END IF;
END$$;

-- equipement_id → equipements_conditionnement.id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_suivi_cond_equip'
  ) THEN
    ALTER TABLE suivi_conditionnement
      ADD CONSTRAINT fk_suivi_cond_equip FOREIGN KEY (equipement_id) REFERENCES equipements_conditionnement(id) ON DELETE SET NULL;
  END IF;
END$$;

-- ─── 3. Vérification ─────────────────────────────────────────────────────────
SELECT code, nom, equipement_id FROM plan_rooms WHERE type = 'cond' ORDER BY code;
