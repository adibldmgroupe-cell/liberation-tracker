-- ═══════════════════════════════════════════════════════════════
-- Migration 013 — Ajouter deleted_at à suivi_conditionnement
-- Nécessaire pour le soft-delete (même pattern que suivi_fabrication)
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE suivi_conditionnement
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_suivi_cond_deleted ON suivi_conditionnement(deleted_at)
  WHERE deleted_at IS NULL;
