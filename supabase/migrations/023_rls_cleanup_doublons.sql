-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 023 — Nettoyage des policies RLS en doublon (suite migration 022 / audit)
-- ───────────────────────────────────────────────────────────────────────────
-- Constat (après 022) : les tables du module Production avaient DÉJÀ des policies
-- (créées par l'app tierce d'origine, noms variés et CMD incomplets — ex.
-- production_sessions avait SELECT/INSERT mais pas UPDATE → bug 020). La migration 022
-- a ajouté les 4 policies `rls_<table>_*` PAR-DESSUS → cumul (6 à 8 policies/table).
--
-- Ce DO block supprime TOUTES les policies existantes de chaque table du module et
-- recrée EXACTEMENT les 4 policies standard (authenticated, USING true) → état propre,
-- déterministe et reproductible. (L'app fonctionne entièrement en rôle `authenticated`.)
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  t text;
  pol record;
  tbls text[] := ARRAY[
    'services',
    'equipements_conditionnement', 'plan_rooms', 'cadences', 'operations_master',
    'product_flux', 'processus', 'ateliers',
    'suivi_fabrication', 'suivi_conditionnement',
    'production_sessions', 'production_comptages', 'production_arrets', 'session_cadences',
    'shifts', 'equipes', 'arret_familles', 'arret_sous_familles', 'arret_types',
    'shift_planning', 'app_settings'
  ];
BEGIN
  FOREACH t IN ARRAY tbls LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = t) THEN
      -- 1. supprimer TOUTES les policies existantes de la table (quel que soit leur nom)
      FOR pol IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = t LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol.policyname, t);
      END LOOP;
      -- 2. recréer les 4 policies standard
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
      EXECUTE format('CREATE POLICY "rls_%s_select" ON public.%I FOR SELECT TO authenticated USING (true)', t, t);
      EXECUTE format('CREATE POLICY "rls_%s_insert" ON public.%I FOR INSERT TO authenticated WITH CHECK (true)', t, t);
      EXECUTE format('CREATE POLICY "rls_%s_update" ON public.%I FOR UPDATE TO authenticated USING (true) WITH CHECK (true)', t, t);
      EXECUTE format('CREATE POLICY "rls_%s_delete" ON public.%I FOR DELETE TO authenticated USING (true)', t, t);
    END IF;
  END LOOP;
END $$;

-- ── Vérification : doit afficher 4 pour CHAQUE table ──
SELECT tablename, count(*) AS nb_policies
FROM pg_policies
WHERE tablename = ANY (ARRAY['services','equipements_conditionnement','plan_rooms','cadences','operations_master','product_flux','processus','ateliers','suivi_fabrication','suivi_conditionnement','production_sessions','production_comptages','production_arrets','session_cadences','shifts','equipes','arret_familles','arret_sous_familles','arret_types','shift_planning','app_settings'])
GROUP BY tablename ORDER BY tablename;
