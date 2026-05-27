-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 007 — Pré-remplissage plan_rooms pour TOUS les nœuds du schéma
-- Basée sur NODES_DEF dans ProductionFlowPage.vue + nomenclature PJ P004
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- ÉTAPE 0 : Contrainte UNIQUE sur code (nécessaire pour l'upsert)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  -- Dédupliquer si nécessaire
  DELETE FROM plan_rooms WHERE id NOT IN (
    SELECT MIN(id) FROM plan_rooms GROUP BY code
  );
  -- Ajouter la contrainte si absente
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
-- ÉTAPE 2 : Upsert plan_rooms — nœuds FAB
-- INSERT si absent (avec nom/zone/type complets), UPDATE atelier_id si présent
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('p464', 'Pesée 1', 'pesee', 'pesee', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle pesée -02' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('p471', 'Pesée 2', 'pesee', 'pesee', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle pesée -03' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n140', 'Gran. Séchage 01', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de granulation et séchage 01' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n425', 'Gran. Séchage 02', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de granulation et séchage 02' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n138', 'Mélange 01', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier LIKE '%mélange 01%' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n137', 'Mélange 02', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier LIKE '%mélange 02%' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n448', 'Mélange 03', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de mélange 03' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n131', 'Compression 01', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de compression 01' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n128', 'Compression 02', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de compression 02' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n134', 'Compression 03', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de compression 03' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n445', 'Compression 04', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de compression 04' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n143', 'Pelliculage 01', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 01' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n136', 'Pelliculage 03', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 03' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n429', 'Pelliculage 02', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 02' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n436', 'Remplissage Gélules', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de remplissage gélules 02' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n442', 'Formulation', 'formes_seches', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle Formulation' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n200', 'Mélange Homogén.', 'formes_semi', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de mélange homogénéisateur' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('n206', 'Remplissage Tubes', 'formes_semi', 'fab', (SELECT id FROM ateliers WHERE nom_atelier = 'Salle de remplissage des tubes' LIMIT 1), NULL)
ON CONFLICT (code) DO UPDATE SET atelier_id = EXCLUDED.atelier_id, equipement_id = NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- ÉTAPE 3 : Upsert plan_rooms — nœuds CONDITIONNEMENT
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('c149', 'MB421', 'cond_primaire', 'cond', NULL, (SELECT id FROM equipements_conditionnement WHERE room_code = '149' OR nom_equipement ILIKE '%marchesini mb421%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id, atelier_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('c148', 'IMA TR100L', 'cond_primaire', 'cond', NULL, (SELECT id FROM equipements_conditionnement WHERE room_code = '148' OR nom_equipement ILIKE '%ima tr100%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id, atelier_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('c147', 'INTEGRA 300', 'cond_primaire', 'cond', NULL, (SELECT id FROM equipements_conditionnement WHERE room_code = '147' OR nom_equipement ILIKE '%integra 300%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id, atelier_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('c146', 'IMA PG SUPER 1', 'cond_primaire', 'cond', NULL, (SELECT id FROM equipements_conditionnement WHERE room_code = '146' OR nom_equipement ILIKE '%ima pg super 1%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id, atelier_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('c220', 'MARCH. R,P', 'cond_primaire', 'cond', NULL, (SELECT id FROM equipements_conditionnement WHERE room_code = '220' OR nom_equipement ILIKE '%marchesini r%p%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id, atelier_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('c222', 'INTEGRA 520', 'cond_primaire', 'cond', NULL, (SELECT id FROM equipements_conditionnement WHERE room_code = '222' OR nom_equipement ILIKE '%integra 520%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id, atelier_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('c223', 'IMA PG SUPER 2', 'cond_primaire', 'cond', NULL, (SELECT id FROM equipements_conditionnement WHERE room_code = '223' OR nom_equipement ILIKE '%ima pg super 2%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id, atelier_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('c153', 'Cond. Sec.', 'cond_secondaire', 'cond', NULL, (SELECT id FROM equipements_conditionnement WHERE room_code = '153' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id, atelier_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('c154', 'Cond. Sec. Ext.', 'cond_secondaire', 'cond', NULL, (SELECT id FROM equipements_conditionnement WHERE room_code = '154' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id, atelier_id = NULL;

INSERT INTO plan_rooms (code, nom, zone, type, atelier_id, equipement_id)
VALUES ('i521', 'Réception Injectables', 'injectable', 'cond', NULL, (SELECT id FROM equipements_conditionnement WHERE room_code = '521' OR nom_equipement ILIKE '%inject%' LIMIT 1))
ON CONFLICT (code) DO UPDATE SET equipement_id = EXCLUDED.equipement_id, atelier_id = NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- VÉRIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  pr.code,
  pr.nom,
  CASE WHEN pr.atelier_id IS NOT NULL THEN 'FAB' ELSE 'COND' END AS type_node,
  COALESCE(a.nom_atelier, ec.nom_equipement, '⚠ NON RÉSOLU') AS designation
FROM plan_rooms pr
LEFT JOIN ateliers a ON a.id = pr.atelier_id
LEFT JOIN equipements_conditionnement ec ON ec.id = pr.equipement_id
WHERE pr.code IN ('p464','p471','n140','n425','n138','n137','n448','n131','n128','n134','n445',
                  'n143','n136','n429','n436','n442','n200','n206',
                  'c149','c148','c147','c146','c220','c222','c223','c153','c154','i521')
ORDER BY type_node, pr.code;
