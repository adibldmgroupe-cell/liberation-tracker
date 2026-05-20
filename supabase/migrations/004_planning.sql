-- ═══════════════════════════════════════════════════════════
-- MIGRATION 004 — Dates prévisionnelles de libération
-- Exécuter dans Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════

-- 1. Table lot_planning (1 ligne par lot, upsert on conflict lot_id)
CREATE TABLE IF NOT EXISTS lot_planning (
  id          BIGSERIAL PRIMARY KEY,
  lot_id      BIGINT REFERENCES lots(id) ON DELETE CASCADE,
  date_lcq_cible    DATE,
  date_lcq_revisee  DATE,
  date_aq_cible     DATE,
  date_aq_revisee   DATE,
  date_dt_cible     DATE,
  date_dt_revisee   DATE,
  updated_at  TIMESTAMPTZ DEFAULT now(),
  updated_by  UUID REFERENCES auth.users(id),
  UNIQUE (lot_id)
);
CREATE INDEX IF NOT EXISTS idx_lot_planning_lot ON lot_planning(lot_id);
ALTER TABLE lot_planning ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rls_lot_planning_select" ON lot_planning FOR SELECT TO authenticated USING (true);
CREATE POLICY "rls_lot_planning_insert" ON lot_planning FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "rls_lot_planning_update" ON lot_planning FOR UPDATE TO authenticated USING (true);
CREATE POLICY "rls_lot_planning_delete" ON lot_planning FOR DELETE TO authenticated USING (true);

-- 2. Table planning_alert_log (déduplication inter-sessions)
CREATE TABLE IF NOT EXISTS planning_alert_log (
  id          BIGSERIAL PRIMARY KEY,
  lot_id      BIGINT REFERENCES lots(id) ON DELETE CASCADE,
  date_type   TEXT NOT NULL,   -- 'lcq' | 'aq' | 'dt'
  target_date DATE NOT NULL,
  level       TEXT NOT NULL,   -- 'j_moins_1' | 'jour_j' | 'depasse'
  alert_day   DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (lot_id, date_type, level, alert_day)
);
ALTER TABLE planning_alert_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rls_alert_log_select" ON planning_alert_log FOR SELECT TO authenticated USING (true);
CREATE POLICY "rls_alert_log_insert" ON planning_alert_log FOR INSERT TO authenticated WITH CHECK (true);

-- 3. Ajouter la permission modifier_planning à tous les services qui ont modifier_lot
INSERT INTO permissions (service, action, allowed)
SELECT service, 'modifier_planning', true FROM permissions WHERE action = 'modifier_lot'
ON CONFLICT (service, action) DO NOTHING;
