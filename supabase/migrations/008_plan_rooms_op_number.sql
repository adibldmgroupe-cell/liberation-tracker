-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 008 — Ajouter op_number sur plan_rooms
-- Mapping fixe : machine → opération (1-to-1)
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE plan_rooms ADD COLUMN IF NOT EXISTS op_number int;

-- Pesée
UPDATE plan_rooms SET op_number = 210 WHERE code IN ('p464','p471');
-- Granulation / Séchage
UPDATE plan_rooms SET op_number = 220 WHERE code IN ('n140','n425');
-- Mélange (incl. Formulation)
UPDATE plan_rooms SET op_number = 230 WHERE code IN ('n138','n137','n448','n442');
-- Compression
UPDATE plan_rooms SET op_number = 240 WHERE code IN ('n131','n128','n134','n445');
-- Pelliculage
UPDATE plan_rooms SET op_number = 250 WHERE code IN ('n143','n136','n429');
-- Mise en gélule
UPDATE plan_rooms SET op_number = 260 WHERE code IN ('n436');
-- Fab Crème / Pommade
UPDATE plan_rooms SET op_number = 270 WHERE code IN ('n200');
-- Conditionnement primaire (blisters, gélules, tubes)
UPDATE plan_rooms SET op_number = 310 WHERE code IN ('c149','c148','c147','c146','c220','c222','c223','n206');
-- Conditionnement secondaire
UPDATE plan_rooms SET op_number = 320 WHERE code IN ('c153','c154');
-- Injectables
UPDATE plan_rooms SET op_number = 330 WHERE code IN ('i521');

-- Vérification
SELECT code, nom, op_number, zone, actif
FROM plan_rooms
WHERE op_number IS NOT NULL
ORDER BY op_number, nom;
