-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 009 — Historique des cadences par session TRS
-- Chaque changement de cadence = nouvelle ligne (calcul segmenté possible)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS session_cadences (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id  bigint NOT NULL REFERENCES production_sessions(id) ON DELETE CASCADE,
  cadence_bpm numeric(6,1) NOT NULL,   -- boîtes/min saisi par l'opérateur
  colisage    int,                     -- boîtes par colis (snapshot au moment de la saisie)
  started_at  timestamptz NOT NULL DEFAULT now(),
  created_at  timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_session_cadences_session_started
  ON session_cadences(session_id, started_at);

-- colisage_confirme sur production_sessions (saisi/confirmé au démarrage)
ALTER TABLE production_sessions
  ADD COLUMN IF NOT EXISTS colisage_confirme int;

-- Vérification
SELECT 'session_cadences créée' AS status;
