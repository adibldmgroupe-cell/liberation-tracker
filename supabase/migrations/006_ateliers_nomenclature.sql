-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 006 — Nomenclature officielle ateliers (P004)
-- Basée sur la table des ateliers PJ (Plan P004 Zone Production 09-2025)
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. RENOMMER les ateliers avec noms incorrects
-- ─────────────────────────────────────────────────────────────────────────────

-- PESÉE
-- "Salle pesée -02" existe déjà (correct, N°464) → conserver
-- "Atelier Pesée A" → Salle pesée -03 (N°471)
UPDATE ateliers SET nom_atelier = 'Salle pesée -03'
WHERE nom_atelier = 'Atelier Pesée A';

-- "Atelier Pesée B" → doublon (PJ n'a que 2 salles pesée) → désactiver
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

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. INSÉRER les ateliers manquants
-- ─────────────────────────────────────────────────────────────────────────────

-- GRANULATION (op 220)
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de granulation et séchage 02',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%granul%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de granulation et séchage 02');

-- MÉLANGE (op 230)
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de mélange 01 (Tamisage & Mélange)',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%mélange%' OR LOWER(nom_process) LIKE '%melange%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier LIKE '%mélange 01%');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de mélange 02 (Tamisage & Mélange)',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%mélange%' OR LOWER(nom_process) LIKE '%melange%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier LIKE '%mélange 02%');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de mélange 03',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%mélange%' OR LOWER(nom_process) LIKE '%melange%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de mélange 03');

-- FAB CRÈME/POMMADE (op 270)
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de mélange homogénéisateur',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%creme%' OR LOWER(nom_process) LIKE '%crème%' OR LOWER(nom_process) LIKE '%pommade%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de mélange homogénéisateur');

-- COMPRESSION (op 240) — salles 03 et 04
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de compression 03',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%compression%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de compression 03');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de compression 04',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%compression%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de compression 04');

-- PELLICULAGE (op 250)
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de pelliculage 01',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%pellic%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 01');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de pelliculage 02',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%pellic%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 02');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de pelliculage 03',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%pellic%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de pelliculage 03');

-- MISE EN GÉLULE / ENCAPSULATION (op 260)
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de remplissage gélules 02',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%gélule%' OR LOWER(nom_process) LIKE '%gelule%' OR LOWER(nom_process) LIKE '%encapsul%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de remplissage gélules 02');

-- OTC (op à définir)
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle OTC 01', NULL, true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle OTC 01');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle OTC 02', NULL, true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle OTC 02');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle OTC 03', NULL, true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle OTC 03');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle OTC 04', NULL, true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle OTC 04');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Salle OTC 05', NULL, true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle OTC 05');

-- CONDITIONNEMENT PRIMAIRE (op 310–380)
INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle Conditionnement Primaire 01',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%cond%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle Conditionnement Primaire 01');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle Conditionnement Primaire 02',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%cond%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle Conditionnement Primaire 02');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle Conditionnement Primaire 03',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%cond%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle Conditionnement Primaire 03');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle Conditionnement Primaire 04',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%cond%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle Conditionnement Primaire 04');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de conditionnement primaire 05',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%cond%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de conditionnement primaire 05');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de conditionnement primaire 06',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%cond%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de conditionnement primaire 06');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de conditionnement primaire 07',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%cond%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de conditionnement primaire 07');

INSERT INTO ateliers (nom_atelier, processus_id, actif)
SELECT 'Salle de remplissage des tubes',
       (SELECT id FROM processus WHERE LOWER(nom_process) LIKE '%cond%' LIMIT 1), true
WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Salle de remplissage des tubes');

-- STOCKAGE / TRANSIT
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'SAS livraison produit fini', NULL, true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'SAS livraison produit fini');
INSERT INTO ateliers (nom_atelier, processus_id, actif) SELECT 'Stock intermédiaire', NULL, true WHERE NOT EXISTS (SELECT 1 FROM ateliers WHERE nom_atelier = 'Stock intermédiaire');

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. METTRE À JOUR operations_master (noms officiels pour l'auto-résolution SVG)
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE operations_master SET room_name = 'Salle de compression 01' WHERE room_name ILIKE '%compression%' AND equipment_name ILIKE '%compression 1%';
UPDATE operations_master SET room_name = 'Salle de compression 02' WHERE room_name ILIKE '%compression%' AND equipment_name ILIKE '%compression 2%';
UPDATE operations_master SET room_name = 'Salle de compression 03' WHERE room_name ILIKE '%compression%' AND equipment_name ILIKE '%compression 3%';
UPDATE operations_master SET room_name = 'Salle de compression 04' WHERE room_name ILIKE '%compression%' AND equipment_name ILIKE '%compression 4%';

UPDATE operations_master SET room_name = 'Salle de granulation et séchage 01' WHERE room_name ILIKE '%granul%' AND (equipment_name ILIKE '%1%' OR equipment_name ILIKE '%séchage%') AND equipment_name NOT ILIKE '%2%';
UPDATE operations_master SET room_name = 'Salle de granulation et séchage 02' WHERE room_name ILIKE '%granul%' AND equipment_name ILIKE '%2%';

UPDATE operations_master SET room_name = 'Salle de mélange 01 (Tamisage & Mélange)' WHERE room_name ILIKE '%mélange%' AND equipment_name ILIKE '%mélange 1%';
UPDATE operations_master SET room_name = 'Salle de mélange 02 (Tamisage & Mélange)' WHERE room_name ILIKE '%mélange%' AND equipment_name ILIKE '%mélange 2%';
UPDATE operations_master SET room_name = 'Salle de mélange 03' WHERE room_name ILIKE '%mélange%' AND equipment_name ILIKE '%mélange 3%';
UPDATE operations_master SET room_name = 'Salle de mélange homogénéisateur' WHERE room_name ILIKE '%mélange%' AND equipment_name ILIKE '%pateux%';

UPDATE operations_master SET room_name = 'Salle de pelliculage 01' WHERE room_name ILIKE '%pellic%' AND equipment_name ILIKE '%pelliculage 1%';
UPDATE operations_master SET room_name = 'Salle de pelliculage 02' WHERE room_name ILIKE '%pellic%' AND equipment_name ILIKE '%pelliculage 2%';
UPDATE operations_master SET room_name = 'Salle de pelliculage 03' WHERE room_name ILIKE '%pellic%' AND equipment_name ILIKE '%pelliculage 3%';

UPDATE operations_master SET room_name = 'Salle de remplissage gélules 02' WHERE room_name ILIKE '%gélule%' OR room_name ILIKE '%gelule%' OR room_name ILIKE '%encapsul%';

UPDATE operations_master SET room_name = 'Salle pesée -02' WHERE room_name ILIKE '%pesée%' AND equipment_name ILIKE '%pesée 1%';
UPDATE operations_master SET room_name = 'Salle pesée -03' WHERE room_name ILIKE '%pesée%' AND equipment_name ILIKE '%pesée 2%';

UPDATE operations_master SET room_name = 'Salle Conditionnement Primaire 01' WHERE equipment_name ILIKE '%marchesini mb421%';
UPDATE operations_master SET room_name = 'Salle Conditionnement Primaire 02' WHERE equipment_name ILIKE '%ima tr100%';
UPDATE operations_master SET room_name = 'Salle Conditionnement Primaire 03' WHERE equipment_name ILIKE '%integra 300%';
UPDATE operations_master SET room_name = 'Salle Conditionnement Primaire 04' WHERE equipment_name ILIKE '%ima pg super 1%';
UPDATE operations_master SET room_name = 'Salle de conditionnement primaire 05' WHERE equipment_name ILIKE '%marchesini r,p%';
UPDATE operations_master SET room_name = 'Salle de conditionnement primaire 06' WHERE equipment_name ILIKE '%integra 520%';
UPDATE operations_master SET room_name = 'Salle de conditionnement primaire 07' WHERE equipment_name ILIKE '%ima pg super 2%';
UPDATE operations_master SET room_name = 'Salle de remplissage des tubes' WHERE equipment_name ILIKE '%marchesini r,t%';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. VÉRIFICATION — résultat final
-- ─────────────────────────────────────────────────────────────────────────────

SELECT a.id, a.nom_atelier, p.nom_process AS processus, a.actif
FROM ateliers a
LEFT JOIN processus p ON p.id = a.processus_id
ORDER BY p.nom_process NULLS LAST, a.nom_atelier;
