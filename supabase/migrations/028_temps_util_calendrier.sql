-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 028 — Temps util (référentiel) + Calendrier machine (PDP capacité)
-- ───────────────────────────────────────────────────────────────────────────
-- 1) temps_util : heures utiles par jour, alimenté par le GS Référentiel
--    (colonne entre TRS_CIBLE et TO_SHIFT). Sert au calcul : capacité/jour = cadence × temps_util.
-- 2) calendrier_machine : jours non ouvrés PAR MACHINE (fériés, arrêt annuel, fermeture).
--    Le WE reste géré par equipements_conditionnement.travaille_weekend.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Temps util (h/jour) au référentiel ──
ALTER TABLE public.operations_master ADD COLUMN IF NOT EXISTS temps_util numeric;
ALTER TABLE public.plan_rooms        ADD COLUMN IF NOT EXISTS temps_util numeric;   -- miroir d'affichage

-- ── 2. Calendrier par machine ──
CREATE TABLE IF NOT EXISTS public.calendrier_machine (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  equipement_id bigint REFERENCES public.equipements_conditionnement(id),  -- NULL = toutes les machines
  date_debut    date NOT NULL,
  date_fin      date NOT NULL,
  type          text NOT NULL DEFAULT 'ferie',   -- ferie | arret_annuel | fermeture | maintenance
  libelle       text,
  created_at    timestamptz DEFAULT now()
);

-- ── RLS (règle N°13 : 4 policies authenticated) ──
ALTER TABLE public.calendrier_machine ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rls_calendrier_machine_select" ON public.calendrier_machine;
DROP POLICY IF EXISTS "rls_calendrier_machine_insert" ON public.calendrier_machine;
DROP POLICY IF EXISTS "rls_calendrier_machine_update" ON public.calendrier_machine;
DROP POLICY IF EXISTS "rls_calendrier_machine_delete" ON public.calendrier_machine;
CREATE POLICY "rls_calendrier_machine_select" ON public.calendrier_machine FOR SELECT TO authenticated USING (true);
CREATE POLICY "rls_calendrier_machine_insert" ON public.calendrier_machine FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "rls_calendrier_machine_update" ON public.calendrier_machine FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "rls_calendrier_machine_delete" ON public.calendrier_machine FOR DELETE TO authenticated USING (true);

CREATE INDEX IF NOT EXISTS idx_calendrier_machine_equip ON public.calendrier_machine(equipement_id);
CREATE INDEX IF NOT EXISTS idx_calendrier_machine_dates ON public.calendrier_machine(date_debut, date_fin);

-- ── Vérification ──
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'calendrier_machine' ORDER BY policyname;
