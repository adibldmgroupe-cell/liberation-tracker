-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 020 — RLS complet du module TRS (production live)
-- ───────────────────────────────────────────────────────────────────────────
-- BUG (règle CLAUDE.md N°13) :
--   `production_sessions` avait une policy INSERT (le démarrage de session marche,
--   POST → 201) mais PAS de policy UPDATE.
--   En RLS PostgreSQL, un UPDATE sans policy ne lève AUCUNE erreur : la clause
--   USING vaut FALSE par défaut → l'UPDATE voit 0 ligne → PostgREST renvoie 204
--   (succès apparent) mais 0 ligne modifiée.
--   Symptôme observé : saisie comptage (colis_produits), clôture, arrêt, reprise
--   « réussissent » côté UI (modale se ferme) mais ne persistent rien.
--
-- CAPA : garantir les 4 policies (SELECT/INSERT/UPDATE/DELETE) sur TOUTES les
--        tables du module TRS, de façon idempotente.
--        Tables créées hors migrations versionnées → on (ré)applique ici.
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  t text;
  tbls text[] := ARRAY[
    'production_sessions',
    'production_comptages',
    'production_arrets',
    'session_cadences'
  ];
BEGIN
  FOREACH t IN ARRAY tbls LOOP
    -- la table existe ? (sécurité si un nom évolue)
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

-- ── Vérification : doit lister 4 lignes (SELECT/INSERT/UPDATE/DELETE) par table ──
SELECT tablename, cmd, policyname
FROM pg_policies
WHERE tablename IN ('production_sessions','production_comptages','production_arrets','session_cadences')
ORDER BY tablename, cmd;
