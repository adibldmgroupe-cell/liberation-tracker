-- ═══════════════════════════════════════════════════════════
-- LDM GROUPE — SUIVI LIBÉRATION PF
-- Supabase PostgreSQL Migration
-- ═══════════════════════════════════════════════════════════

-- ── ENUM TYPES ──
CREATE TYPE service_type AS ENUM (
  'planification','stock','aq','aq_dap','dt',
  'fabrication','conditionnement','lcq','admin'
);
CREATE TYPE role_type AS ENUM ('operateur','responsable','admin');
CREATE TYPE statut_sap_type AS ENUM ('vide','quarantaine','sous_investigation','accepte');
CREATE TYPE order_statut_type AS ENUM ('planifie','en_circuit','reception','fabrication','conditionnement','termine');
CREATE TYPE etape_circuit_type AS ENUM ('planification','stock','aq','dt','aq_dap','production');
CREATE TYPE validation_action_type AS ENUM ('valide','refuse','retour');
CREATE TYPE fab_etape_type AS ENUM ('pesee','granulation_sechage','melange','compression','pelliculage','remplissage_gelules','melanges_pateux');
CREATE TYPE fab_statut_type AS ENUM ('en_attente','en_cours','termine');
CREATE TYPE aql_type AS ENUM ('fabrication','conditionnement');
CREATE TYPE aql_resultat_type AS ENUM ('en_attente','conforme','non_conforme');
CREATE TYPE doc_type AS ENUM ('if','ic','da_pc','da_micro','rvp','deviation','analyse_risque','autorisation_partenaire','autre');
CREATE TYPE doc_statut_type AS ENUM ('non_emis','emis','verification_aq','retour_emetteur','rectification','approuve_aq','approbation_dt','approuve_dt');
CREATE TYPE mvt_action_type AS ENUM ('emission','transmission','reception','retour','rectification','approbation');
CREATE TYPE dev_type AS ENUM ('nc','regularisation','triage','deviation');
CREATE TYPE dev_statut_type AS ENUM ('ouverte','en_cours','cloturee');
CREATE TYPE dev_gravite_type AS ENUM ('mineure','majeure','critique');
CREATE TYPE dossier_statut_type AS ENUM ('incomplet','complet','transfere_dt','libere');

-- ── PROFILES (extends Supabase auth.users) ──
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nom TEXT NOT NULL,
  prenom TEXT NOT NULL,
  email TEXT NOT NULL,
  service service_type NOT NULL,
  role role_type NOT NULL DEFAULT 'operateur',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── PRODUCTS ──
CREATE TABLE products (
  id BIGSERIAL PRIMARY KEY,
  code_article TEXT UNIQUE NOT NULL,
  description TEXT NOT NULL,
  forme_galenique TEXT,
  is_semi_solide BOOLEAN DEFAULT false,
  prix_vente DECIMAL(12,2) DEFAULT 0,
  ppa DECIMAL(12,2) DEFAULT 0,
  quantite_par_colis INTEGER DEFAULT 0,
  shp DECIMAL(4,1) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ── LOTS ──
CREATE TABLE lots (
  id BIGSERIAL PRIMARY KEY,
  numero_lot TEXT NOT NULL,
  product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  num_document_sap TEXT,
  quantite INTEGER DEFAULT 0,
  statut_sap statut_sap_type DEFAULT 'vide',
  statut_operationnel TEXT,
  date_enregistrement DATE,
  date_declaration DATE,
  date_liberation DATE,
  ddf DATE,
  ddp DATE,
  is_lot_validation BOOLEAN DEFAULT false,
  synced_from_excel_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(numero_lot, num_document_sap)
);
CREATE INDEX idx_lots_statut ON lots(statut_sap);
CREATE INDEX idx_lots_product ON lots(product_id);

-- ── ORDERS OF ──
CREATE TABLE orders_of (
  id BIGSERIAL PRIMARY KEY,
  lot_id BIGINT NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
  numero_of TEXT,
  statut order_statut_type DEFAULT 'planifie',
  etape_circuit etape_circuit_type,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(lot_id)
);

-- ── ORDERS OC ──
CREATE TABLE orders_oc (
  id BIGSERIAL PRIMARY KEY,
  lot_id BIGINT NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
  numero_oc TEXT,
  statut order_statut_type DEFAULT 'planifie',
  etape_circuit etape_circuit_type,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(lot_id)
);

-- ── ORDER VALIDATIONS ──
CREATE TABLE order_validations (
  id BIGSERIAL PRIMARY KEY,
  order_type TEXT NOT NULL CHECK (order_type IN ('of','oc')),
  order_id BIGINT NOT NULL,
  etape etape_circuit_type NOT NULL,
  action validation_action_type DEFAULT 'valide',
  validated_by UUID NOT NULL REFERENCES profiles(id),
  commentaire TEXT,
  validated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_ov_order ON order_validations(order_type, order_id);

-- ── FABRICATION STEPS ──
CREATE TABLE fabrication_steps (
  id BIGSERIAL PRIMARY KEY,
  order_of_id BIGINT NOT NULL REFERENCES orders_of(id) ON DELETE CASCADE,
  etape fab_etape_type NOT NULL,
  statut fab_statut_type DEFAULT 'en_attente',
  declared_by UUID REFERENCES profiles(id),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── AQL INSPECTIONS ──
CREATE TABLE aql_inspections (
  id BIGSERIAL PRIMARY KEY,
  lot_id BIGINT NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
  type aql_type NOT NULL,
  resultat aql_resultat_type DEFAULT 'en_attente',
  avis_aq TEXT,
  inspected_by UUID REFERENCES profiles(id),
  requested_at TIMESTAMPTZ,
  inspected_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── LIBERATION DOCUMENTS ──
CREATE TABLE liberation_documents (
  id BIGSERIAL PRIMARY KEY,
  lot_id BIGINT NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
  type_document doc_type NOT NULL,
  statut doc_statut_type DEFAULT 'non_emis',
  is_applicable BOOLEAN DEFAULT true,
  is_required BOOLEAN DEFAULT true,
  service_emetteur TEXT,
  emitted_by UUID REFERENCES profiles(id),
  emitted_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ── DOCUMENT MOVEMENTS ──
CREATE TABLE document_movements (
  id BIGSERIAL PRIMARY KEY,
  document_id BIGINT NOT NULL REFERENCES liberation_documents(id) ON DELETE CASCADE,
  action mvt_action_type NOT NULL,
  from_service TEXT,
  to_service TEXT,
  motif_retour TEXT,
  performed_by UUID NOT NULL REFERENCES profiles(id),
  performed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── DEVIATIONS ──
CREATE TABLE deviations (
  id BIGSERIAL PRIMARY KEY,
  lot_id BIGINT NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
  numero_deviation TEXT UNIQUE NOT NULL,
  type dev_type NOT NULL,
  statut dev_statut_type DEFAULT 'ouverte',
  gravite dev_gravite_type NOT NULL,
  description TEXT,
  declared_by UUID NOT NULL REFERENCES profiles(id),
  declared_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── LIBERATION DOSSIER ──
CREATE TABLE liberation_dossiers (
  id BIGSERIAL PRIMARY KEY,
  lot_id BIGINT UNIQUE NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
  if_approved BOOLEAN DEFAULT false,
  ic_approved BOOLEAN DEFAULT false,
  da_pc_approved BOOLEAN DEFAULT false,
  da_micro_approved BOOLEAN DEFAULT false,
  da_micro_applicable BOOLEAN DEFAULT true,
  deviations_closed BOOLEAN DEFAULT true,
  pieces_complementaires_ok BOOLEAN DEFAULT true,
  statut dossier_statut_type DEFAULT 'incomplet',
  transferred_by UUID REFERENCES profiles(id),
  liberated_by UUID REFERENCES profiles(id),
  transferred_at TIMESTAMPTZ,
  liberated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ── LOT EVENTS (audit trail) ──
CREATE TABLE lot_events (
  id BIGSERIAL PRIMARY KEY,
  lot_id BIGINT NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  description TEXT,
  old_value TEXT,
  new_value TEXT,
  triggered_by UUID REFERENCES profiles(id),
  source TEXT DEFAULT 'app',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_events_lot ON lot_events(lot_id, created_at DESC);

-- ── PERMISSIONS ──
CREATE TABLE permissions (
  id BIGSERIAL PRIMARY KEY,
  service service_type NOT NULL,
  action TEXT NOT NULL,
  allowed BOOLEAN DEFAULT false,
  UNIQUE(service, action)
);

-- ═══════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- ═══════════════════════════════════════════════════════════

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE lots ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders_of ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders_oc ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_validations ENABLE ROW LEVEL SECURITY;
ALTER TABLE fabrication_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE aql_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE liberation_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE deviations ENABLE ROW LEVEL SECURITY;
ALTER TABLE liberation_dossiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE lot_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;

-- Lecture : tous les utilisateurs authentifiés
CREATE POLICY "read_all" ON profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON products FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON lots FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON orders_of FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON orders_oc FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON order_validations FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON fabrication_steps FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON aql_inspections FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON liberation_documents FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON document_movements FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON deviations FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON liberation_dossiers FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON lot_events FOR SELECT TO authenticated USING (true);
CREATE POLICY "read_all" ON permissions FOR SELECT TO authenticated USING (true);

-- Écriture : utilisateurs authentifiés (contrôle fin côté app via permissions table)
CREATE POLICY "write_auth" ON lots FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "write_auth" ON orders_of FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "write_auth" ON orders_oc FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "write_auth" ON order_validations FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "write_auth" ON fabrication_steps FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "write_auth" ON aql_inspections FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "write_auth" ON liberation_documents FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "write_auth" ON document_movements FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "write_auth" ON deviations FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "write_auth" ON liberation_dossiers FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "write_auth" ON lot_events FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "write_auth" ON products FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "write_auth" ON profiles FOR UPDATE TO authenticated USING (id = auth.uid());

-- ═══════════════════════════════════════════════════════════
-- AUTO-CREATE PROFILE ON SIGNUP
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, nom, prenom, email, service, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nom', ''),
    COALESCE(NEW.raw_user_meta_data->>'prenom', ''),
    NEW.email,
    COALESCE((NEW.raw_user_meta_data->>'service')::service_type, 'admin'),
    COALESCE((NEW.raw_user_meta_data->>'role')::role_type, 'operateur')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ═══════════════════════════════════════════════════════════
-- SEED PERMISSIONS
-- ═══════════════════════════════════════════════════════════
INSERT INTO permissions (service, action, allowed) VALUES
-- Planification
('planification','creer_lot',true),('planification','mettre_en_circuit_of',true),('planification','mettre_en_circuit_oc',true),
-- Stock
('stock','valider_quantites_of',true),('stock','valider_quantites_oc',true),
-- AQ
('aq','valider_of',true),('aq','valider_oc',true),('aq','realiser_aql',true),('aq','declarer_nc',true),
('aq','cloturer_deviation',true),('aq','verifier_if',true),('aq','verifier_ic',true),
('aq','verifier_da_pc',true),('aq','verifier_da_micro',true),('aq','retourner_document',true),('aq','transferer_dossier_dt',true),
-- AQ DAP
('aq_dap','remettre_ordre_production',true),
-- DT
('dt','autoriser_lancement',true),('dt','approuver_if',true),('dt','approuver_ic',true),
('dt','approuver_da_pc',true),('dt','approuver_da_micro',true),('dt','retourner_document',true),
('dt','cloturer_deviation',true),('dt','liberer_lot',true),
-- Fabrication
('fabrication','accuser_reception_of',true),('fabrication','declarer_etape_fab',true),
('fabrication','declarer_fin_sf',true),('fabrication','demander_aql_fab',true),
('fabrication','emettre_if',true),('fabrication','rectifier_document',true),
-- Conditionnement
('conditionnement','accuser_reception_oc',true),('conditionnement','declarer_fin_pf',true),
('conditionnement','demander_aql_cond',true),('conditionnement','emettre_ic',true),('conditionnement','rectifier_document',true),
-- LCQ
('lcq','realiser_analyse_pc',true),('lcq','realiser_analyse_micro',true),
('lcq','emettre_da_pc',true),('lcq','emettre_da_micro',true),('lcq','rectifier_document',true);

-- Lecture KPI pour tous
INSERT INTO permissions (service, action, allowed)
SELECT s.s, a.a, true
FROM (VALUES ('planification'::service_type),('stock'),('aq'),('aq_dap'),('dt'),('fabrication'),('conditionnement'),('lcq')) AS s(s),
     (VALUES ('voir_dashboard'),('voir_lots'),('voir_timeline'),('voir_kpi')) AS a(a);
