-- ═══════════════════════════════════════════════════════════
-- MIGRATION V2 — Exécuter dans Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════

-- 1. Simplifier déviations
ALTER TABLE deviations DROP COLUMN IF EXISTS gravite;

-- 2. Table notifications
CREATE TABLE IF NOT EXISTS notifications (
  id BIGSERIAL PRIMARY KEY,
  service service_type NOT NULL,
  lot_id BIGINT REFERENCES lots(id) ON DELETE CASCADE,
  document_id BIGINT REFERENCES liberation_documents(id) ON DELETE SET NULL,
  message TEXT NOT NULL,
  event_type TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notif_service ON notifications(service, is_read, created_at DESC);
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read_notif" ON notifications FOR SELECT TO authenticated USING (true);
CREATE POLICY "write_notif" ON notifications FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "update_notif" ON notifications FOR UPDATE TO authenticated USING (true);

-- 3. Permissions admin + RVP
INSERT INTO permissions (service, action, allowed) VALUES
  ('admin','modifier_lot',true),('admin','supprimer_lot',true),('admin','creer_lot',true),
  ('admin','mettre_en_circuit_of',true),('admin','mettre_en_circuit_oc',true),
  ('admin','valider_quantites_of',true),('admin','valider_quantites_oc',true),
  ('admin','valider_of',true),('admin','valider_oc',true),('admin','autoriser_lancement',true),
  ('admin','remettre_ordre_production',true),('admin','accuser_reception_of',true),('admin','accuser_reception_oc',true),
  ('admin','realiser_aql',true),('admin','declarer_nc',true),('admin','cloturer_deviation',true),
  ('admin','emettre_if',true),('admin','emettre_ic',true),('admin','emettre_da_pc',true),('admin','emettre_da_micro',true),
  ('admin','emettre_rvp',true),('admin','verifier_if',true),('admin','verifier_ic',true),
  ('admin','verifier_da_pc',true),('admin','verifier_da_micro',true),('admin','verifier_rvp',true),
  ('admin','retourner_document',true),('admin','rectifier_document',true),
  ('admin','approuver_if',true),('admin','approuver_ic',true),('admin','approuver_da_pc',true),
  ('admin','approuver_da_micro',true),('admin','approuver_rvp',true),
  ('admin','transferer_dossier_dt',true),('admin','liberer_lot',true),
  ('admin','demander_aql_fab',true),('admin','demander_aql_cond',true),
  ('admin','declarer_etape_fab',true),('admin','declarer_fin_sf',true),('admin','declarer_fin_pf',true),
  ('admin','voir_dashboard',true),('admin','voir_lots',true),('admin','voir_timeline',true),('admin','voir_kpi',true),
  ('fabrication','emettre_rvp',true),('conditionnement','emettre_rvp',true),('lcq','emettre_rvp',true),
  ('aq','verifier_rvp',true),('dt','approuver_rvp',true)
ON CONFLICT (service, action) DO NOTHING;

-- 4. Lots acceptés = tout approuvé
UPDATE liberation_documents SET statut = 'approuve_dt', approved_at = NOW()
WHERE is_applicable = true AND lot_id IN (SELECT id FROM lots WHERE statut_sap = 'accepte') AND statut != 'approuve_dt';
UPDATE liberation_dossiers SET statut = 'libere', if_approved = true, ic_approved = true, da_pc_approved = true, deviations_closed = true, pieces_complementaires_ok = true
WHERE lot_id IN (SELECT id FROM lots WHERE statut_sap = 'accepte');
UPDATE liberation_dossiers SET da_micro_approved = true WHERE da_micro_applicable = true AND lot_id IN (SELECT id FROM lots WHERE statut_sap = 'accepte');

-- 5. Correction OF/OC
UPDATE orders_of SET statut = 'termine', etape_circuit = 'production' WHERE lot_id IN (SELECT lot_id FROM liberation_documents WHERE type_document IN ('if','da_pc') AND statut != 'non_emis');
UPDATE orders_oc SET statut = 'termine', etape_circuit = 'production' WHERE lot_id IN (SELECT lot_id FROM liberation_documents WHERE type_document = 'ic' AND statut != 'non_emis');
UPDATE orders_of SET statut = 'termine', etape_circuit = 'production' WHERE lot_id IN (SELECT id FROM lots WHERE statut_sap IN ('quarantaine','sous_investigation','accepte'));
UPDATE orders_oc SET statut = 'termine', etape_circuit = 'production' WHERE lot_id IN (SELECT id FROM lots WHERE statut_sap IN ('quarantaine','sous_investigation','accepte'));
UPDATE orders_of SET statut = 'planifie', etape_circuit = 'planification' WHERE lot_id IN (SELECT l.id FROM lots l WHERE l.statut_sap = 'vide' AND NOT EXISTS (SELECT 1 FROM liberation_documents d WHERE d.lot_id = l.id AND d.type_document IN ('if','da_pc') AND d.statut != 'non_emis') AND NOT EXISTS (SELECT 1 FROM order_validations v WHERE v.order_type = 'of' AND v.order_id = (SELECT id FROM orders_of WHERE lot_id = l.id)));
UPDATE orders_oc SET statut = 'planifie', etape_circuit = 'planification' WHERE lot_id IN (SELECT l.id FROM lots l WHERE l.statut_sap = 'vide' AND NOT EXISTS (SELECT 1 FROM liberation_documents d WHERE d.lot_id = l.id AND d.type_document = 'ic' AND d.statut != 'non_emis') AND NOT EXISTS (SELECT 1 FROM order_validations v WHERE v.order_type = 'oc' AND v.order_id = (SELECT id FROM orders_oc WHERE lot_id = l.id)));
