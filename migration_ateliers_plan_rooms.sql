-- =============================================================================
-- MIGRATION COMPLÈTE — Ateliers & Operations Master
-- Basée sur la table officielle P004 (PJ)
-- Exécuter dans Supabase → SQL Editor
-- =============================================================================

-- ══════════════════════════════════════════════════════════════════════════════
-- ÉTAPE 1 : RENOMMER les ateliers existants avec noms incorrects
-- ══════════════════════════════════════════════════════════════════════════════

-- PESÉE
-- "Salle pesée -02" existe déjà et est correct (N°464) → conserver
-- "Atelier Pesée A" → Salle pesée -03 (N°471)
UPDATE ateliers SET nom_atelier = 'Salle pesée -03'
WHERE nom_atelier = 'Atelier Pesée A';

-- "Atelier Pesée B" → doublon non référencé dans PJ → désactiver
UPDATE ateliers SET actif = false
WHERE nom_atelier = 'Atelier Pesée B';

-- GRANULATION
UPDATE ateliers SET nom_atelier = 'Salle de granulation et séchage 01'
WHERE nom_atelier = 'Atelier Granulation A';

-- COMPRESSION
UPDATE ateliers SET nom_atelier = 'Salle de compression 01'
WHERE nom_atelier = 'Atelier Compression A';

UPDATE ateliers SET nom_atelier = 'Salle de compression 02'
WHERE nom_atelier = 'Atelier Compression B';

-- ══════════════════════════════════════════════════════════════════════════════
-- ÉTAPE 2 : INSÉRER les ateliers manquants (avec lien processus dynamique)
-- ══════════════════════════════════════════════════════════════════════════════

-- Helper : résoudre processus_id par nom (insensible à la casse)
-- Pesée (op 210)
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de granulation et séchage 02',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%granul%' LIMIT 1),
       true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de granulation et séchage 02');

-- Mélange (op 230)
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de mélange 01 (Tamisage & Mélange)',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%mélange%' OR LOWER(nom_process) LIKE '%melange%' LIMIT 1),
       true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier LIKE '%mélange 01%');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de mélange 02 (Tamisage & Mélange)',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%mélange%' OR LOWER(nom_process) LIKE '%melange%' LIMIT 1),
       true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier LIKE '%mélange 02%');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de mélange 03',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%mélange%' OR LOWER(nom_process) LIKE '%melange%' LIMIT 1),
       true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de mélange 03');

-- FAB Crème/Pommade (op 270)
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de mélange homogénéisateur',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%creme%' OR LOWER(nom_process) LIKE '%crème%' OR LOWER(nom_process) LIKE '%pommade%' LIMIT 1),
       true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de mélange homogénéisateur');

-- Compression (op 240) — salles 03 et 04
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de compression 03',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%compression%' LIMIT 1),
       true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de compression 03');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de compression 04',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%compression%' LIMIT 1),
       true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de compression 04');

-- Pelliculage (op 250)
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de pelliculage 01',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%pellic%' LIMIT 1),
       true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 01');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de pelliculage 02',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%pellic%' LIMIT 1),
       true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 02');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de pelliculage 03',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%pellic%' LIMIT 1),
       true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 03');

-- Mise en gélule / Encapsulation (op 260)
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de remplissage gélules 02',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%gélule%' OR LOWER(nom_process) LIKE '%gelule%' OR LOWER(nom_process) LIKE '%encapsul%' LIMIT 1),
       true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de remplissage gélules 02');

-- OTC (op à définir)
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle OTC 01', NULL, true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle OTC 01');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle OTC 02', NULL, true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle OTC 02');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle OTC 03', NULL, true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle OTC 03');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle OTC 04', NULL, true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle OTC 04');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle OTC 05', NULL, true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle OTC 05');

-- Stockage
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'SAS livraison produit fini', NULL, true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'SAS livraison produit fini');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Stock intermédiaire', NULL, true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Stock intermédiaire');

-- ══════════════════════════════════════════════════════════════════════════════
-- ÉTAPE 3 : METTRE À JOUR operations_master avec la nomenclature officielle
-- (utilisé pour auto-résolution plan_rooms dans le schéma production)
-- ══════════════════════════════════════════════════════════════════════════════

-- Mise à jour des noms de salles dans operations_master
-- Format : (op_number, room_code utilisé dans SVG, op_code, room_name officiel, equipment_name)

-- On ne touche aux lignes existantes que pour les noms
-- Compression
UPDATE operations_master SET room_name = 'Salle de compression 01' WHERE room_name ILIKE '%compression%' AND equipment_name ILIKE '%compression 1%';
UPDATE operations_master SET room_name = 'Salle de compression 02' WHERE room_name ILIKE '%compression%' AND equipment_name ILIKE '%compression 2%';
UPDATE operations_master SET room_name = 'Salle de compression 03' WHERE room_name ILIKE '%compression%' AND equipment_name ILIKE '%compression 3%';
UPDATE operations_master SET room_name = 'Salle de compression 04' WHERE room_name ILIKE '%compression%' AND equipment_name ILIKE '%compression 4%';

-- Granulation
UPDATE operations_master SET room_name = 'Salle de granulation et séchage 01' WHERE room_name ILIKE '%granul%' AND equipment_name ILIKE '%1%';
UPDATE operations_master SET room_name = 'Salle de granulation et séchage 02' WHERE room_name ILIKE '%granul%' AND equipment_name ILIKE '%2%';

-- Mélange
UPDATE operations_master SET room_name = 'Salle de mélange 01 (Tamisage & Mélange)' WHERE room_name ILIKE '%mélange%' AND equipment_name ILIKE '%mélange 1%';
UPDATE operations_master SET room_name = 'Salle de mélange 02 (Tamisage & Mélange)' WHERE room_name ILIKE '%mélange%' AND equipment_name ILIKE '%mélange 2%';
UPDATE operations_master SET room_name = 'Salle de mélange 03' WHERE room_name ILIKE '%mélange%' AND equipment_name ILIKE '%mélange 3%';
UPDATE operations_master SET room_name = 'Salle de mélange homogénéisateur' WHERE room_name ILIKE '%mélange%' AND equipment_name ILIKE '%pateux%';

-- Pelliculage
UPDATE operations_master SET room_name = 'Salle de pelliculage 01' WHERE room_name ILIKE '%pellic%' AND equipment_name ILIKE '%pelliculage 1%';
UPDATE operations_master SET room_name = 'Salle de pelliculage 02' WHERE room_name ILIKE '%pellic%' AND equipment_name ILIKE '%pelliculage 2%';
UPDATE operations_master SET room_name = 'Salle de pelliculage 03' WHERE room_name ILIKE '%pellic%' AND equipment_name ILIKE '%pelliculage 3%';

-- Gélules
UPDATE operations_master SET room_name = 'Salle de remplissage gélules 02' WHERE room_name ILIKE '%gélule%' OR room_name ILIKE '%gelule%' OR room_name ILIKE '%encapsul%';

-- Pesée
UPDATE operations_master SET room_name = 'Salle pesée -02' WHERE room_name ILIKE '%pesée%' AND equipment_name ILIKE '%pesée 1%';
UPDATE operations_master SET room_name = 'Salle pesée -03' WHERE room_name ILIKE '%pesée%' AND equipment_name ILIKE '%pesée 2%';

-- Conditionnement (si des entrées existent)
UPDATE operations_master SET room_name = 'Salle Conditionnement Primaire 01' WHERE room_name ILIKE '%cond%' AND equipment_name ILIKE '%marchesini mb421%';
UPDATE operations_master SET room_name = 'Salle Conditionnement Primaire 02' WHERE room_name ILIKE '%cond%' AND equipment_name ILIKE '%ima tr100%';
UPDATE operations_master SET room_name = 'Salle Conditionnement Primaire 03' WHERE room_name ILIKE '%cond%' AND equipment_name ILIKE '%integra 300%';
UPDATE operations_master SET room_name = 'Salle Conditionnement Primaire 04' WHERE room_name ILIKE '%cond%' AND equipment_name ILIKE '%ima pg super 1%';
UPDATE operations_master SET room_name = 'Salle de conditionnement primaire 05' WHERE room_name ILIKE '%cond%' AND equipment_name ILIKE '%marchesini r,p%';
UPDATE operations_master SET room_name = 'Salle de conditionnement primaire 06' WHERE room_name ILIKE '%cond%' AND equipment_name ILIKE '%integra 520%';
UPDATE operations_master SET room_name = 'Salle de conditionnement primaire 07' WHERE room_name ILIKE '%cond%' AND equipment_name ILIKE '%ima pg super 2%';
UPDATE operations_master SET room_name = 'Salle de remplissage des tubes' WHERE room_name ILIKE '%tube%' OR equipment_name ILIKE '%marchesini r,t%';

-- ══════════════════════════════════════════════════════════════════════════════
-- ÉTAPE 4 : VÉRIFICATION
-- ══════════════════════════════════════════════════════════════════════════════

SELECT a.id, a.nom_atelier, p.nom_process AS processus, a.actif
FROM ateliers a
LEFT JOIN processus p ON p.id = a.processus_id
ORDER BY p.nom_process NULLS LAST, a.nom_atelier;
