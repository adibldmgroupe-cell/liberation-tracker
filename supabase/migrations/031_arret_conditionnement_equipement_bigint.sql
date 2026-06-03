-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 031 — arret_conditionnement.equipement_id : uuid → bigint + FK
-- ───────────────────────────────────────────────────────────────────────────
-- BUG de type (signalé migration 024) : equipement_id était en uuid alors que
-- l'équipement = equipements_conditionnement.id (bigint) → impossible d'y poser
-- la FK, et tout INSERT avec un equipement_id bigint échouait. Conséquence :
-- les arrêts de conditionnement (motif horodaté) ne pouvaient pas être stockés.
--
-- Table VIDE au 03/06/2026 (0 ligne) → conversion sans perte.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.arret_conditionnement
  ALTER COLUMN equipement_id TYPE bigint USING (NULL::bigint);

-- FK vers l'équipement (impossible avant, type uuid)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'arret_conditionnement_equipement_id_fkey') THEN
    ALTER TABLE public.arret_conditionnement
      ADD CONSTRAINT arret_conditionnement_equipement_id_fkey
      FOREIGN KEY (equipement_id) REFERENCES public.equipements_conditionnement(id);
  END IF;
END $$;

-- ── Vérification ──
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'arret_conditionnement' AND column_name = 'equipement_id';
