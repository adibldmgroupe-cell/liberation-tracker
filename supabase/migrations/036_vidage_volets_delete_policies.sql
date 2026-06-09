-- 036 : policies DELETE pour le « vidage par volet » (Module production + Risque péremption)
--
-- Contexte : le vidage est désormais découpé en 3 volets indépendants (Gestion lots /
-- Module production / Risque péremption). Les volets Production et Péremption suppriment
-- DIRECTEMENT leurs tables (pas via la cascade depuis `lots`). Or, sous RLS, un DELETE sans
-- policy FOR DELETE renvoie 204 mais supprime 0 ligne EN SILENCE (cf. CLAUDE.md règle N°13).
-- Cette migration garantit qu'une policy DELETE existe pour chacune de ces tables.
--
-- Idempotente : ré-exécutable sans risque (DROP POLICY IF EXISTS + CREATE), ignore les tables absentes.

DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'production_sessions','production_arrets','production_comptages','session_cadences',
    'suivi_fabrication','suivi_conditionnement','atelier_arrets','arret_conditionnement',
    'peremption_evaluations'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF to_regclass('public.' || t) IS NULL THEN
      RAISE NOTICE 'Table % absente — ignorée', t;
      CONTINUE;
    END IF;
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'rls_' || t || '_delete_vidage', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING (true)', 'rls_' || t || '_delete_vidage', t);
  END LOOP;
END $$;

-- Vérification (lecture seule) — doit renvoyer une ligne DELETE par table ci-dessus :
-- SELECT tablename, policyname, cmd FROM pg_policies
-- WHERE tablename = ANY(ARRAY[
--   'production_sessions','production_arrets','production_comptages','session_cadences',
--   'suivi_fabrication','suivi_conditionnement','atelier_arrets','arret_conditionnement',
--   'peremption_evaluations'
-- ]) AND cmd = 'DELETE'
-- ORDER BY tablename;
