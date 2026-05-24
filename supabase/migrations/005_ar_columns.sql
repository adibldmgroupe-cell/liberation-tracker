-- ═══════════════════════════════════════════════════════
-- Migration 005 — Colonnes Accusé de Réception (AR)
-- ═══════════════════════════════════════════════════════

-- Circuit OF : service qui doit accuser réception de l'étape
ALTER TABLE orders_of
  ADD COLUMN IF NOT EXISTS pending_ar_service VARCHAR(50) DEFAULT NULL;

-- Circuit OC : service qui doit accuser réception de l'étape
ALTER TABLE orders_oc
  ADD COLUMN IF NOT EXISTS pending_ar_service VARCHAR(50) DEFAULT NULL;

-- Documents (IF/IC/DA/RVP) : service qui doit accuser réception du document
ALTER TABLE liberation_documents
  ADD COLUMN IF NOT EXISTS pending_ar_service VARCHAR(50) DEFAULT NULL;

-- AQL : accusé de réception de la demande (AQ/LCQ)
ALTER TABLE aql_inspections
  ADD COLUMN IF NOT EXISTS request_ar_pending BOOLEAN DEFAULT FALSE;

-- AQL : accusé de réception du résultat (Fabrication/Conditionnement)
ALTER TABLE aql_inspections
  ADD COLUMN IF NOT EXISTS result_ar_pending BOOLEAN DEFAULT FALSE;
