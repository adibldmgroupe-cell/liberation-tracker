-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 033 — document_deadlines : SLA de traitement par service × type
-- ───────────────────────────────────────────────────────────────────────────
-- Chaque service fixe un délai (en jours) de traitement pour chaque type d'item
-- une fois celui-ci à son niveau. Le compteur démarre :
--   • OF / OC                         → à l'arrivée à l'étape (updated_at)
--   • IF/IC/DA PC/RVP/AQL (émission)  → à la réception du lot (date_enregistrement)
--   • étapes aval (AQ/DT/LCQ)         → à l'accusé de réception (updated_at)
-- À l'échéance, la tâche correspondante est signalée (visuel) dans TasksPage.
-- type_key ∈ { of, oc, if, ic, da_pc, rvp, aql_fab, aql_cond }
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS document_deadlines (
  id          BIGSERIAL PRIMARY KEY,
  service     TEXT NOT NULL,
  type_key    TEXT NOT NULL,
  delai_jours INTEGER NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ DEFAULT now(),
  updated_by  UUID REFERENCES auth.users(id),
  UNIQUE (service, type_key)
);

CREATE INDEX IF NOT EXISTS idx_document_deadlines_service ON document_deadlines(service);

ALTER TABLE document_deadlines ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rls_doc_deadlines_select" ON document_deadlines FOR SELECT TO authenticated USING (true);
CREATE POLICY "rls_doc_deadlines_insert" ON document_deadlines FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "rls_doc_deadlines_update" ON document_deadlines FOR UPDATE TO authenticated USING (true);
CREATE POLICY "rls_doc_deadlines_delete" ON document_deadlines FOR DELETE TO authenticated USING (true);
