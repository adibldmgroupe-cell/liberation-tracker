-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 016 — Restaurer plan_rooms.op_number (écrasé par syncRefToSupabase)
-- Root cause : syncRefToSupabase utilisait op_number du GS (codes SAP machines)
--              au lieu des codes process flux production (migration 008)
-- CAPA       : op_number retiré du payload de syncRefToSupabase (AdminAteliersPage)
-- ═══════════════════════════════════════════════════════════════════════════

-- Reset au mapping correct (identique à migration 008)
UPDATE plan_rooms SET op_number = 210 WHERE code IN ('p464','p471');
UPDATE plan_rooms SET op_number = 220 WHERE code IN ('n140','n425');
UPDATE plan_rooms SET op_number = 230 WHERE code IN ('n138','n137','n448','n442');
UPDATE plan_rooms SET op_number = 240 WHERE code IN ('n131','n128','n134','n445');
UPDATE plan_rooms SET op_number = 250 WHERE code IN ('n143','n136','n429');
UPDATE plan_rooms SET op_number = 260 WHERE code IN ('n436');
UPDATE plan_rooms SET op_number = 270 WHERE code IN ('n200');
UPDATE plan_rooms SET op_number = 310 WHERE code IN ('c149','c148','c147','c146','c220','c222','c223','n206');
UPDATE plan_rooms SET op_number = 320 WHERE code IN ('c153','c154');
UPDATE plan_rooms SET op_number = 330 WHERE code IN ('i521');

-- OTC
UPDATE plan_rooms SET op_number = 280 WHERE code IN ('n101','n102','n103','n104','n105');

-- Vérification
SELECT code, nom, op_number FROM plan_rooms WHERE op_number IS NOT NULL ORDER BY op_number, code;
