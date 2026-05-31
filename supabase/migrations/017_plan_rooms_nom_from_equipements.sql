-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 017 — Mettre à jour plan_rooms.nom depuis equipements_conditionnement
-- Pour les nœuds cond, utiliser le nom complet de l'équipement (ex: MARCHESINI MB421)
-- au lieu du nom court du nœud SVG (ex: MB421)
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE plan_rooms pr
SET nom = ec.nom_equipement
FROM equipements_conditionnement ec
WHERE pr.equipement_id = ec.id
  AND pr.equipement_id IS NOT NULL;

-- Vérification
SELECT code, nom FROM plan_rooms WHERE type = 'cond' ORDER BY code;
