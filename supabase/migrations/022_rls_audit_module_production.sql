-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 022 — RLS exhaustif du module Production / Référentiel TRS (CAPA audit juin 2026)
-- ───────────────────────────────────────────────────────────────────────────
-- Contexte : la partie Production provient d'une app tierce importée → tables créées
-- directement dans Supabase (hors migrations), RLS souvent absent → écritures bloquées
-- en silence (cf. règles N°13 et N°17, bugs cadences/production_sessions).
--
-- Cette migration GARANTIT les 4 policies (SELECT/INSERT/UPDATE/DELETE) `authenticated`
-- sur toutes les tables du module, de façon idempotente. NE crée PAS les tables
-- (DDL à versionner séparément via export du schéma Supabase).
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  t text;
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
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
      EXECUTE format('DROP POLICY IF EXISTS "rls_%s_select" ON public.%I', t, t);
      EXECUTE format('DROP POLICY IF EXISTS "rls_%s_insert" ON public.%I', t, t);
      EXECUTE format('DROP POLICY IF EXISTS "rls_%s_update" ON public.%I', t, t);
      EXECUTE format('DROP POLICY IF EXISTS "rls_%s_delete" ON public.%I', t, t);
      EXECUTE format('CREATE POLICY "rls_%s_select" ON public.%I FOR SELECT TO authenticated USING (true)', t, t);
      EXECUTE format('CREATE POLICY "rls_%s_insert" ON public.%I FOR INSERT TO authenticated WITH CHECK (true)', t, t);
      EXECUTE format('CREATE POLICY "rls_%s_update" ON public.%I FOR UPDATE TO authenticated USING (true) WITH CHECK (true)', t, t);
      EXECUTE format('CREATE POLICY "rls_%s_delete" ON public.%I FOR DELETE TO authenticated USING (true)', t, t);
    END IF;
  END LOOP;
END $$;

-- ── Vérification : 4 lignes (SELECT/INSERT/UPDATE/DELETE) par table ──
SELECT tablename, count(*) AS nb_policies
FROM pg_policies
WHERE tablename = ANY (ARRAY['services','equipements_conditionnement','plan_rooms','cadences','operations_master','product_flux','processus','ateliers','suivi_fabrication','suivi_conditionnement','production_sessions','production_comptages','production_arrets','session_cadences','shifts','equipes','arret_familles','arret_sous_familles','arret_types','shift_planning','app_settings'])
GROUP BY tablename ORDER BY tablename;
