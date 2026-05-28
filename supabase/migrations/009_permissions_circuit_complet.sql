-- ═══════════════════════════════════════════════════════════
-- MIGRATION 009 — Circuit IF/IC/DA PC/DA Micro — Permissions complètes
-- Toutes les permissions manquantes pour les services opérationnels.
-- ON CONFLICT DO NOTHING : sûr à réexécuter (idempotent).
-- ═══════════════════════════════════════════════════════════

INSERT INTO permissions (service, action, allowed) VALUES

  -- ═══════════════════════════════
  -- FABRICATION
  -- Circuit OF, IF, AQL, RVP, MàJ, Clôture SAP, Déviations
  -- ═══════════════════════════════
  ('fabrication', 'accuser_reception_of',           true),
  ('fabrication', 'accuser_reception_circuit',      true),
  ('fabrication', 'emettre_if',                     true),
  ('fabrication', 'rectifier_document',             true),
  ('fabrication', 'accuser_reception_document',     true),
  ('fabrication', 'accuser_reception_aql_resultat', true),
  ('fabrication', 'demander_aql_fab',               true),
  ('fabrication', 'declarer_nc',                    true),
  ('fabrication', 'voir_lots',                      true),
  ('fabrication', 'declarer_etape_fab',             true),
  ('fabrication', 'declarer_fin_sf',                true),
  ('fabrication', 'declarer_fin_pf',                true),
  ('fabrication', 'emettre_cloture_sap_of',         true),
  ('fabrication', 'demander_cloture_sap_of',        true),
  ('fabrication', 'emettre_maj_if',                 true),
  ('fabrication', 'emettre_rvp',                    true),

  -- ═══════════════════════════════
  -- CONDITIONNEMENT
  -- Circuit OC, IC, AQL, RVP, MàJ, Clôture SAP, Déviations
  -- ═══════════════════════════════
  ('conditionnement', 'accuser_reception_oc',           true),
  ('conditionnement', 'accuser_reception_circuit',      true),
  ('conditionnement', 'emettre_ic',                     true),
  ('conditionnement', 'rectifier_document',             true),
  ('conditionnement', 'accuser_reception_document',     true),
  ('conditionnement', 'accuser_reception_aql_resultat', true),
  ('conditionnement', 'demander_aql_cond',              true),
  ('conditionnement', 'declarer_nc',                    true),
  ('conditionnement', 'voir_lots',                      true),
  ('conditionnement', 'emettre_cloture_sap_oc',         true),
  ('conditionnement', 'demander_cloture_sap_oc',        true),
  ('conditionnement', 'emettre_maj_ic',                 true),
  ('conditionnement', 'emettre_rvp',                    true),

  -- ═══════════════════════════════
  -- LCQ
  -- DA PC, DA Micro, RVP, AR AQL demande
  -- ═══════════════════════════════
  ('lcq', 'emettre_da_pc',                 true),
  ('lcq', 'emettre_da_micro',              true),
  ('lcq', 'rectifier_document',            true),
  ('lcq', 'accuser_reception_document',    true),
  ('lcq', 'accuser_reception_aql_demande', true),
  ('lcq', 'voir_lots',                     true),
  ('lcq', 'emettre_rvp',                   true),

  -- ═══════════════════════════════
  -- AQ
  -- Vérification documents, AQL, retour, AR, déviations
  -- ═══════════════════════════════
  ('aq', 'valider_of',                    true),
  ('aq', 'valider_oc',                    true),
  ('aq', 'accuser_reception_circuit',     true),
  ('aq', 'verifier_if',                   true),
  ('aq', 'verifier_ic',                   true),
  ('aq', 'verifier_da_pc',               true),
  ('aq', 'verifier_da_micro',            true),
  ('aq', 'verifier_rvp',                 true),
  ('aq', 'verifier_maj_doc',             true),
  ('aq', 'retourner_document',           true),
  ('aq', 'accuser_reception_document',   true),
  ('aq', 'accuser_reception_aql_demande', true),
  ('aq', 'realiser_aql',                 true),
  ('aq', 'demander_aql_fab',             true),
  ('aq', 'demander_aql_cond',            true),
  ('aq', 'declarer_nc',                  true),
  ('aq', 'cloturer_deviation',           true),
  ('aq', 'voir_lots',                    true),
  ('aq', 'voir_dashboard',               true),
  ('aq', 'voir_timeline',                true),
  ('aq', 'voir_kpi',                     true),

  -- ═══════════════════════════════
  -- DT (Direction Technique)
  -- Approbation documents, autorisation circuit, AR
  -- ═══════════════════════════════
  ('dt', 'autoriser_lancement',         true),
  ('dt', 'accuser_reception_circuit',   true),
  ('dt', 'approuver_if',                true),
  ('dt', 'approuver_ic',                true),
  ('dt', 'approuver_da_pc',             true),
  ('dt', 'approuver_da_micro',          true),
  ('dt', 'approuver_rvp',               true),
  ('dt', 'approuver_maj_doc',           true),
  ('dt', 'retourner_document',          true),
  ('dt', 'accuser_reception_document',  true),
  ('dt', 'voir_lots',                   true),

  -- ═══════════════════════════════
  -- PLANIFICATION
  -- Mise en circuit, planning, clôture SAP, MàJ nomenclature
  -- ═══════════════════════════════
  ('planification', 'mettre_en_circuit_of',       true),
  ('planification', 'mettre_en_circuit_oc',       true),
  ('planification', 'accuser_reception_circuit',  true),
  ('planification', 'modifier_planning',          true),
  ('planification', 'valider_cloture_sap_of',     true),
  ('planification', 'valider_cloture_sap_oc',     true),
  ('planification', 'confirmer_cloture_sap_of',   true),
  ('planification', 'confirmer_cloture_sap_oc',   true),
  ('planification', 'emettre_maj_nmcl_of',        true),
  ('planification', 'emettre_maj_nmcl_oc',        true),
  ('planification', 'voir_lots',                  true),
  ('planification', 'voir_dashboard',             true),
  ('planification', 'voir_timeline',              true),
  ('planification', 'voir_kpi',                   true),

  -- ═══════════════════════════════
  -- STOCK
  -- Validation quantités
  -- ═══════════════════════════════
  ('stock', 'valider_quantites_of',       true),
  ('stock', 'valider_quantites_oc',       true),
  ('stock', 'accuser_reception_circuit',  true),
  ('stock', 'voir_lots',                  true),

  -- ═══════════════════════════════
  -- AQ DAP
  -- Remise ordre production
  -- ═══════════════════════════════
  ('aq_dap', 'remettre_ordre_production', true),
  ('aq_dap', 'accuser_reception_circuit', true),
  ('aq_dap', 'voir_lots',                 true)

ON CONFLICT (service, action) DO NOTHING;
