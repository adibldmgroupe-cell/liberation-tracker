-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 027 — PDP Conditionnement : colonnes de saisie + de calcul
-- ───────────────────────────────────────────────────────────────────────────
-- Le PDP (plan directeur) doit : (1) contenir des lignes « produit prévu sans lot »,
-- (2) porter les paramètres du calcul de charge (taille, cadence, shift, VDLT/VDLP,
-- retard, date fin fab) et (3) stocker les résultats calculés (TP, THP, TOTAL, cumul,
-- date de libération). Cible RÉELLE : planification_conditionnement (PDP cond) +
-- suivi_fabrication (PDP fab). Le produit venait uniquement du lot → on ajoute product_id.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── PDP Conditionnement : planification_conditionnement ──
ALTER TABLE public.planification_conditionnement
  ADD COLUMN IF NOT EXISTS product_id        bigint,
  ADD COLUMN IF NOT EXISTS taille_lot        integer,        -- Prévisionnel [UN]
  ADD COLUMN IF NOT EXISTS cadence_bh        numeric,        -- Boîtes / heure
  ADD COLUMN IF NOT EXISTS nb_shift          integer,        -- Shift
  ADD COLUMN IF NOT EXISTS nbre_vdlt         integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nbre_vdlp         integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS retard_jours      numeric DEFAULT 0,   -- Retard [Jr] (arrêt non planifié)
  ADD COLUMN IF NOT EXISTS date_fin_fab      date,               -- entrée du calcul (dispo après fab)
  -- résultats calculés :
  ADD COLUMN IF NOT EXISTS tp_jours          numeric,        -- temps util (j)
  ADD COLUMN IF NOT EXISTS thp_jours         numeric,        -- temps hors-prod / arrêts planifiés (j)
  ADD COLUMN IF NOT EXISTS total_prod_jours  numeric,        -- TP + THP
  ADD COLUMN IF NOT EXISTS total_cml         numeric,        -- cumul (charge machine)
  ADD COLUMN IF NOT EXISTS date_liberation   date;           -- fin condt + délai, ajustée
ALTER TABLE public.planification_conditionnement ALTER COLUMN lot_id DROP NOT NULL;
-- (lot_id reste UNIQUE : PostgreSQL autorise plusieurs NULL → OK pour les lignes sans lot)

-- ── PDP Fabrication : suivi_fabrication ──
ALTER TABLE public.suivi_fabrication ADD COLUMN IF NOT EXISTS product_id bigint;
ALTER TABLE public.suivi_fabrication ALTER COLUMN lot_id DROP NOT NULL;

-- ── FK product_id → products (NOT VALID) ──
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'planification_conditionnement_product_id_fkey') THEN
    ALTER TABLE public.planification_conditionnement
      ADD CONSTRAINT planification_conditionnement_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'suivi_fabrication_product_id_fkey') THEN
    ALTER TABLE public.suivi_fabrication
      ADD CONSTRAINT suivi_fabrication_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) NOT VALID;
  END IF;
END $$;

-- ── Backfill product_id depuis le lot lié ──
UPDATE public.planification_conditionnement pc SET product_id = l.product_id
  FROM public.lots l WHERE pc.lot_id = l.id AND pc.product_id IS NULL;
UPDATE public.suivi_fabrication sf SET product_id = l.product_id
  FROM public.lots l WHERE sf.lot_id = l.id AND sf.product_id IS NULL;

-- ── Vérification ──
SELECT column_name FROM information_schema.columns
WHERE table_name = 'planification_conditionnement' ORDER BY ordinal_position;
