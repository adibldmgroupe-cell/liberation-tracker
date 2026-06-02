-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 025 — Comptage en BOÎTES EXACTES (fin de l'arrondi au colis plein)
-- ───────────────────────────────────────────────────────────────────────────
-- Bug (test 02/06/2026, MB421 lot 26421) : saisir 100 boîtes affichait 96 / 1 colis.
-- Cause : production_sessions.colis_produits est un ENTIER en COLIS ; le comptage faisait
-- colis_produits = floor(boîtes/colisage) puis réaffichait colis × colisage → toute saisie
-- non multiple du colisage était tronquée vers le bas (100 → 96, perte de 4 boîtes).
--
-- Correctif : on stocke désormais les BOÎTES exactes. colis_produits reste rempli
-- (rétrocompat = round(boîtes/colisage)). L'affichage lit boites_produites (fallback
-- colis × colisage pour les anciennes sessions), et les colis sont affichés en décimal.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.production_sessions  ADD COLUMN IF NOT EXISTS boites_produites      integer;
ALTER TABLE public.production_sessions  ADD COLUMN IF NOT EXISTS boites_rebuts         integer;
ALTER TABLE public.production_comptages ADD COLUMN IF NOT EXISTS boites_cumules        integer;
ALTER TABLE public.production_comptages ADD COLUMN IF NOT EXISTS boites_rebuts_cumules integer;

-- Backfill : dériver les boîtes des colis existants (colis × colisage)
UPDATE public.production_sessions
   SET boites_produites = COALESCE(colis_produits,0) * COALESCE(colisage_confirme,1)
 WHERE boites_produites IS NULL;
UPDATE public.production_sessions
   SET boites_rebuts = COALESCE(colis_rebuts,0) * COALESCE(colisage_confirme,1)
 WHERE boites_rebuts IS NULL;
UPDATE public.production_comptages
   SET boites_cumules = COALESCE(colis_cumules,0) *
       COALESCE((SELECT colisage_confirme FROM public.production_sessions s WHERE s.id = production_comptages.session_id), 1)
 WHERE boites_cumules IS NULL;

-- (RLS déjà garanti par migrations 022/023 — ADD COLUMN ne modifie pas les policies.)

-- ── Vérification ──
SELECT id, colis_produits, colisage_confirme, boites_produites
FROM public.production_sessions
ORDER BY id DESC LIMIT 5;
