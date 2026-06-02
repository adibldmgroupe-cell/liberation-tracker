-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 026 — Ordre d'affichage des machines (TRS Live + Mode Live + tableau)
-- ───────────────────────────────────────────────────────────────────────────
-- L'ordre des machines dans toutes les vues TRS vient de
-- equipements_conditionnement.ordre_affichage (loadAll : .order('ordre_affichage')).
-- Ordre métier demandé (02/06/2026) :
--   1 MB421 · 2 INTEGRA 300 · 3 INTEGRA 520 · 4 IMA TR100L
--   5 IMA PG SUPER 1 · 6 IMA PG SUPER 2 · 7 MARCHESINI R,P · 8 MARCHESINI R,T
-- (déjà appliqué en base le 02/06/2026 ; cette migration assure la reproductibilité.)
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE public.equipements_conditionnement SET ordre_affichage = 1 WHERE nom_equipement = 'MARCHESINI MB421';
UPDATE public.equipements_conditionnement SET ordre_affichage = 2 WHERE nom_equipement = 'INTEGRA 300';
UPDATE public.equipements_conditionnement SET ordre_affichage = 3 WHERE nom_equipement = 'INTEGRA 520';
UPDATE public.equipements_conditionnement SET ordre_affichage = 4 WHERE nom_equipement = 'IMA TR100L';
UPDATE public.equipements_conditionnement SET ordre_affichage = 5 WHERE nom_equipement = 'IMA PG SUPER 1';
UPDATE public.equipements_conditionnement SET ordre_affichage = 6 WHERE nom_equipement = 'IMA PG SUPER 2';
UPDATE public.equipements_conditionnement SET ordre_affichage = 7 WHERE nom_equipement = 'MARCHESINI R,P';
UPDATE public.equipements_conditionnement SET ordre_affichage = 8 WHERE nom_equipement = 'MARCHESINI R,T';

-- ── Vérification ──
SELECT nom_equipement, ordre_affichage
FROM public.equipements_conditionnement
WHERE actif = true
ORDER BY ordre_affichage;
