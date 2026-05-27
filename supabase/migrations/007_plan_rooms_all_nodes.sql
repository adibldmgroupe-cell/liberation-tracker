-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 007 — Pré-remplissage plan_rooms pour TOUS les nœuds du schéma
-- Basée sur NODES_DEF dans ProductionFlowPage.vue + nomenclature PJ P004
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- ÉTAPE 0 : Ajouter contrainte UNIQUE sur code si elle n'existe pas
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'plan_rooms_code_key' AND conrelid = 'plan_rooms'::regclass
  ) THEN
    ALTER TABLE plan_rooms ADD CONSTRAINT plan_rooms_code_key UNIQUE (code);
  END IF;
END$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- ÉTAPE 1 : S'assurer que tous les ateliers FAB existent
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle pesée -02',                          (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%pesée%' OR LOWER(nom_process) LIKE '%pesee%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle pesée -02');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle pesée -03',                          (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%pesée%' OR LOWER(nom_process) LIKE '%pesee%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle pesée -03');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de granulation et séchage 01',       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%granul%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de granulation et séchage 01');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de granulation et séchage 02',       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%granul%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de granulation et séchage 02');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de mélange 01 (Tamisage & Mélange)', (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%mélange%' OR LOWER(nom_process) LIKE '%melange%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier LIKE '%mélange 01%');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de mélange 02 (Tamisage & Mélange)', (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%mélange%' OR LOWER(nom_process) LIKE '%melange%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier LIKE '%mélange 02%');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de mélange 03',                      (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%mélange%' OR LOWER(nom_process) LIKE '%melange%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de mélange 03');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de compression 01',                  (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%compression%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de compression 01');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de compression 02',                  (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%compression%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de compression 02');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de compression 03',                  (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%compression%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de compression 03');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de compression 04',                  (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%compression%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de compression 04');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de pelliculage 01',                  (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%pellic%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 01');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de pelliculage 02',                  (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%pellic%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 02');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de pelliculage 03',                  (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%pellic%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 03');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de remplissage gélules 02',          (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%gélule%' OR LOWER(nom_process) LIKE '%gelule%' OR LOWER(nom_process) LIKE '%encapsul%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de remplissage gélules 02');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de mélange homogénéisateur',         (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%creme%' OR LOWER(nom_process) LIKE '%crème%' OR LOWER(nom_process) LIKE '%pommade%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de mélange homogénéisateur');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle de remplissage des tubes',           (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%cond%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de remplissage des tubes');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle Formulation',                        (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%mélange%' OR LOWER(nom_process) LIKE '%melange%' LIMIT 1), true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle Formulation');

-- ─────────────────────────────────────────────────────────────────────────────
-- ÉTAPE 2 : Peupler plan_rooms pour les nœuds FAB
-- Stratégie : DELETE si existe déjà + INSERT propre
-- ─────────────────────────────────────────────────────────────────────────────

DELETE FROM plan_rooms WHERE code = 'p464';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'p464', id, NULL FROM ateliers WHERE nom_atelier = 'Salle pesée -02' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'p471';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'p471', id, NULL FROM ateliers WHERE nom_atelier = 'Salle pesée -03' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n140';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n140', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de granulation et séchage 01' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n425';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n425', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de granulation et séchage 02' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n138';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n138', id, NULL FROM ateliers WHERE nom_atelier LIKE '%mélange 01%' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n137';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n137', id, NULL FROM ateliers WHERE nom_atelier LIKE '%mélange 02%' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n448';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n448', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de mélange 03' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n131';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n131', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de compression 01' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n128';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n128', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de compression 02' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n134';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n134', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de compression 03' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n445';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n445', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de compression 04' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n143';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n143', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 01' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n136';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n136', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 03' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n429';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n429', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 02' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n436';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n436', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de remplissage gélules 02' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n442';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n442', id, NULL FROM ateliers WHERE nom_atelier = 'Salle Formulation' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n200';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n200', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de mélange homogénéisateur' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'n206';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'n206', id, NULL FROM ateliers WHERE nom_atelier = 'Salle de remplissage des tubes' LIMIT 1;

-- ─────────────────────────────────────────────────────────────────────────────
-- ÉTAPE 3 : Peupler plan_rooms pour les nœuds CONDITIONNEMENT
-- ─────────────────────────────────────────────────────────────────────────────

DELETE FROM plan_rooms WHERE code = 'c149';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'c149', NULL, id FROM equipements_conditionnement WHERE room_code = '149' OR nom_equipement ILIKE '%marchesini mb421%' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'c148';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'c148', NULL, id FROM equipements_conditionnement WHERE room_code = '148' OR nom_equipement ILIKE '%ima tr100%' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'c147';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'c147', NULL, id FROM equipements_conditionnement WHERE room_code = '147' OR nom_equipement ILIKE '%integra 300%' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'c146';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'c146', NULL, id FROM equipements_conditionnement WHERE room_code = '146' OR nom_equipement ILIKE '%ima pg super 1%' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'c220';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'c220', NULL, id FROM equipements_conditionnement WHERE room_code = '220' OR nom_equipement ILIKE '%marchesini r%p%' OR nom_equipement ILIKE '%marchesini rp%' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'c222';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'c222', NULL, id FROM equipements_conditionnement WHERE room_code = '222' OR nom_equipement ILIKE '%integra 520%' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'c223';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'c223', NULL, id FROM equipements_conditionnement WHERE room_code = '223' OR nom_equipement ILIKE '%ima pg super 2%' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'c153';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'c153', NULL, id FROM equipements_conditionnement WHERE room_code = '153' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'c154';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'c154', NULL, id FROM equipements_conditionnement WHERE room_code = '154' LIMIT 1;

DELETE FROM plan_rooms WHERE code = 'i521';
INSERT INTO plan_rooms (code, atelier_id, equipement_id) SELECT 'i521', NULL, id FROM equipements_conditionnement WHERE room_code = '521' OR nom_equipement ILIKE '%inject%' OR nom_equipement ILIKE '%réception%' LIMIT 1;

-- ─────────────────────────────────────────────────────────────────────────────
-- VÉRIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  pr.code,
  CASE WHEN pr.atelier_id IS NOT NULL THEN 'FAB' ELSE 'COND' END AS type_node,
  COALESCE(a.nom_atelier, ec.nom_equipement, '⚠ NON RÉSOLU') AS designation,
  CASE WHEN pr.atelier_id IS NOT NULL THEN pr.atelier_id::text ELSE pr.equipement_id::text END AS ref_id
FROM plan_rooms pr
LEFT JOIN ateliers a ON a.id = pr.atelier_id
LEFT JOIN equipements_conditionnement ec ON ec.id = pr.equipement_id
ORDER BY type_node, pr.code;
