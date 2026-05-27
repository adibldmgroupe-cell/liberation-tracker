-- =============================================================================
-- MIGRATION : Synchronisation ateliers + plan_rooms depuis operations_master
-- Exécuter dans Supabase → SQL Editor
-- =============================================================================

-- 1. PEUPLER plan_rooms pour tous les nodes FAB (type 'fab') manquants
--    Résolution : operations_master.room_code → ateliers.nom_atelier (ou création)
-- ---------------------------------------------------------------------------

-- Étape 1a : Créer les ateliers manquants depuis operations_master
INSERT INTO ateliers (nom_atelier, actif)
SELECT DISTINCT om.room_name, true
FROM operations_master om
WHERE om.room_name IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM ateliers a WHERE LOWER(a.nom_atelier) = LOWER(om.room_name)
  );

-- Étape 1b : Insérer dans plan_rooms tous les room_codes FAB pas encore mappés
INSERT INTO plan_rooms (code, atelier_id, equipement_id)
SELECT
  om.room_code,
  a.id,
  NULL
FROM operations_master om
JOIN ateliers a ON LOWER(a.nom_atelier) = LOWER(om.room_name)
WHERE om.room_code IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM plan_rooms pr WHERE pr.code = om.room_code
  )
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- 2. PEUPLER plan_rooms pour les nodes COND (type 'cond') manquants
-- ---------------------------------------------------------------------------

INSERT INTO plan_rooms (code, atelier_id, equipement_id)
SELECT
  ec.room_code,
  NULL,
  ec.id
FROM equipements_conditionnement ec
WHERE ec.room_code IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM plan_rooms pr WHERE pr.code = ec.room_code
  )
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- 3. RENOMMER les ateliers dont le nom ne correspond pas à operations_master
--    (met à jour les noms existants pour les aligner sur room_name)
-- ---------------------------------------------------------------------------

UPDATE ateliers a
SET nom_atelier = om.room_name
FROM plan_rooms pr
JOIN operations_master om ON om.room_code = pr.code
WHERE pr.atelier_id = a.id
  AND LOWER(a.nom_atelier) <> LOWER(om.room_name);

-- =============================================================================
-- 4. VÉRIFICATION — afficher le résultat
-- ---------------------------------------------------------------------------

SELECT
  pr.code,
  a.nom_atelier   AS atelier_nom,
  ec.nom_equipement AS equipement_nom,
  CASE WHEN pr.atelier_id IS NOT NULL THEN 'FAB' ELSE 'COND' END AS type_node
FROM plan_rooms pr
LEFT JOIN ateliers a ON a.id = pr.atelier_id
LEFT JOIN equipements_conditionnement ec ON ec.id = pr.equipement_id
ORDER BY type_node, pr.code;
