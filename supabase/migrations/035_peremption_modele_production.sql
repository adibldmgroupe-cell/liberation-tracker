-- ════════════════════════════════════════════════════════════════════════
-- 035 — Risques de péremption : 2ᵉ modèle de scoring « PRODUCTION » (LDM)
-- ════════════════════════════════════════════════════════════════════════
-- Le modèle PRODUCTION s'applique aux produits fabriqués par
-- « PRODUCTION LDM GROUPE » (génériques + OTC). Tout le reste (sous-licence
-- ABBOTT/SERVIER/… + REV revente) reste sur le modèle IMPORT (existant).
--
-- Modèle PRODUCTION : axes PRODUIT 40 / Commercial-Marketing 25 / MARCHÉ 35.
--   PRODUIT (4) : Shelf Life (binaire ≥3/<3 ans), Prix (<10/10-50/≥50 M DA),
--                 Historique, Profitabilité (Niv 1/2/3)
--   Commercial-Marketing (2) : Forecast accuracy (3 niv), Promotion & Offre (Niv 1/2/3)
--   MARCHÉ (3) : Croissance, Concurrence, Maturité (binaire)
--
-- ⚠️ Aucune nouvelle table → RLS déjà en place (migration 034). Aucun ALTER TYPE.
-- À exécuter dans Supabase SQL Editor (un seul bloc).

-- Modèle utilisé par chaque évaluation + 2 nouveaux sous-scores du modèle production
ALTER TABLE public.peremption_evaluations ADD COLUMN IF NOT EXISTS modele text DEFAULT 'import';
ALTER TABLE public.peremption_evaluations ADD COLUMN IF NOT EXISTS sc_profitabilite smallint;
ALTER TABLE public.peremption_evaluations ADD COLUMN IF NOT EXISTS sc_promotion smallint;

-- Pondérations du modèle production (les poids_* existants restent pour l'import)
ALTER TABLE public.peremption_config ADD COLUMN IF NOT EXISTS poids_prod_produit    numeric NOT NULL DEFAULT 40;
ALTER TABLE public.peremption_config ADD COLUMN IF NOT EXISTS poids_prod_commercial numeric NOT NULL DEFAULT 25;
ALTER TABLE public.peremption_config ADD COLUMN IF NOT EXISTS poids_prod_marche     numeric NOT NULL DEFAULT 35;
