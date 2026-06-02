-- ═══════════════════════════════════════════════════════════════════════════
-- schema_reference.sql — RÉFÉRENCE VERSIONNÉE DU SCHÉMA SUPABASE (public)
-- Généré depuis Supabase (Dashboard → Database → Schema), 02/06/2026.
-- ───────────────────────────────────────────────────────────────────────────
-- ⚠️ NE PAS EXÉCUTER TEL QUEL. Ce fichier documente l'état réel de la base pour
--    que le schéma soit enfin VERSIONNÉ dans le repo (cf. CLAUDE.md N°18 : la partie
--    Production venait d'une app tierce importée → tables créées hors migrations).
--
-- Notes de lecture :
--  • Les colonnes « USER-DEFINED » sont des ENUM PostgreSQL (service, role_type,
--    statut_sap_type, order_statut_type, doc_statut_type, dev_statut_type, etc.).
--    Leurs définitions `CREATE TYPE` sont dans les migrations 001+ (tables core).
--  • Une recréation « from scratch » nécessite donc : (1) les CREATE TYPE des enums,
--    (2) ce DDL, (3) les migrations RLS 020→023, (4) les FK 024.
--  • Les tables du module Production/Référentiel n'utilisent PAS d'enum → recréables
--    directement à partir de ce fichier.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE public.profiles (
  id uuid NOT NULL,
  nom text NOT NULL,
  prenom text NOT NULL,
  email text NOT NULL,
  service USER-DEFINED NOT NULL,
  role USER-DEFINED NOT NULL DEFAULT 'operateur'::role_type,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.products (
  id bigint NOT NULL DEFAULT nextval('products_id_seq'::regclass),
  code_article text NOT NULL UNIQUE,
  description text NOT NULL,
  forme_galenique text,
  is_semi_solide boolean DEFAULT false,
  prix_vente numeric DEFAULT 0,
  ppa numeric DEFAULT 0,
  quantite_par_colis integer DEFAULT 0,
  shp numeric DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  groupe_article text,
  dci text,
  code_dci text,
  duree_vie text,
  fabricant text,
  actif boolean DEFAULT true,
  CONSTRAINT products_pkey PRIMARY KEY (id)
);
CREATE TABLE public.lots (
  id bigint NOT NULL DEFAULT nextval('lots_id_seq'::regclass),
  numero_lot text NOT NULL UNIQUE,
  product_id bigint NOT NULL,
  num_document_sap text,
  quantite integer DEFAULT 0,
  statut_sap USER-DEFINED DEFAULT 'vide'::statut_sap_type,
  statut_operationnel text,
  date_enregistrement date,
  date_declaration date,
  date_liberation date,
  ddf date,
  ddp date,
  is_lot_validation boolean DEFAULT false,
  synced_from_excel_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  prix_vente numeric,
  ppa numeric,
  quantite_par_colis integer,
  shp numeric,
  phase_production_en_cours text,
  CONSTRAINT lots_pkey PRIMARY KEY (id),
  CONSTRAINT lots_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);
CREATE TABLE public.orders_of (
  id bigint NOT NULL DEFAULT nextval('orders_of_id_seq'::regclass),
  lot_id bigint NOT NULL UNIQUE,
  numero_of text,
  statut USER-DEFINED DEFAULT 'planifie'::order_statut_type,
  etape_circuit USER-DEFINED,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  pending_ar_service character varying,
  CONSTRAINT orders_of_pkey PRIMARY KEY (id),
  CONSTRAINT orders_of_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id)
);
CREATE TABLE public.orders_oc (
  id bigint NOT NULL DEFAULT nextval('orders_oc_id_seq'::regclass),
  lot_id bigint NOT NULL UNIQUE,
  numero_oc text,
  statut USER-DEFINED DEFAULT 'planifie'::order_statut_type,
  etape_circuit USER-DEFINED,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  pending_ar_service character varying,
  CONSTRAINT orders_oc_pkey PRIMARY KEY (id),
  CONSTRAINT orders_oc_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id)
);
CREATE TABLE public.order_validations (
  id bigint NOT NULL DEFAULT nextval('order_validations_id_seq'::regclass),
  order_type text NOT NULL CHECK (order_type = ANY (ARRAY['of'::text, 'oc'::text])),
  order_id bigint NOT NULL,
  etape USER-DEFINED NOT NULL,
  action USER-DEFINED DEFAULT 'valide'::validation_action_type,
  validated_by uuid NOT NULL,
  commentaire text,
  validated_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT order_validations_pkey PRIMARY KEY (id),
  CONSTRAINT order_validations_validated_by_fkey FOREIGN KEY (validated_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.fabrication_steps (
  id bigint NOT NULL DEFAULT nextval('fabrication_steps_id_seq'::regclass),
  order_of_id bigint NOT NULL,
  etape USER-DEFINED NOT NULL,
  statut USER-DEFINED DEFAULT 'en_attente'::fab_statut_type,
  declared_by uuid,
  started_at timestamp with time zone,
  completed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT fabrication_steps_pkey PRIMARY KEY (id),
  CONSTRAINT fabrication_steps_order_of_id_fkey FOREIGN KEY (order_of_id) REFERENCES public.orders_of(id),
  CONSTRAINT fabrication_steps_declared_by_fkey FOREIGN KEY (declared_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.aql_inspections (
  id bigint NOT NULL DEFAULT nextval('aql_inspections_id_seq'::regclass),
  lot_id bigint NOT NULL,
  type USER-DEFINED NOT NULL,
  resultat USER-DEFINED DEFAULT 'en_attente'::aql_resultat_type,
  avis_aq text,
  inspected_by uuid,
  requested_at timestamp with time zone,
  inspected_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  request_ar_pending boolean DEFAULT false,
  request_ar_at timestamp with time zone,
  request_ar_by uuid,
  result_ar_pending boolean DEFAULT false,
  result_ar_at timestamp with time zone,
  result_ar_by uuid,
  CONSTRAINT aql_inspections_pkey PRIMARY KEY (id),
  CONSTRAINT aql_inspections_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id),
  CONSTRAINT aql_inspections_inspected_by_fkey FOREIGN KEY (inspected_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.liberation_documents (
  id bigint NOT NULL DEFAULT nextval('liberation_documents_id_seq'::regclass),
  lot_id bigint NOT NULL,
  type_document USER-DEFINED NOT NULL,
  statut USER-DEFINED DEFAULT 'non_emis'::doc_statut_type,
  is_applicable boolean DEFAULT true,
  is_required boolean DEFAULT true,
  service_emetteur text,
  emitted_by uuid,
  emitted_at timestamp with time zone,
  approved_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  pending_ar_service character varying,
  CONSTRAINT liberation_documents_pkey PRIMARY KEY (id),
  CONSTRAINT liberation_documents_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id),
  CONSTRAINT liberation_documents_emitted_by_fkey FOREIGN KEY (emitted_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.document_movements (
  id bigint NOT NULL DEFAULT nextval('document_movements_id_seq'::regclass),
  document_id bigint NOT NULL,
  action USER-DEFINED NOT NULL,
  from_service text,
  to_service text,
  motif_retour text,
  performed_by uuid NOT NULL,
  performed_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT document_movements_pkey PRIMARY KEY (id),
  CONSTRAINT document_movements_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.liberation_documents(id),
  CONSTRAINT document_movements_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.deviations (
  id bigint NOT NULL DEFAULT nextval('deviations_id_seq'::regclass),
  lot_id bigint NOT NULL,
  numero_deviation text UNIQUE,
  type USER-DEFINED NOT NULL,
  statut USER-DEFINED DEFAULT 'ouverte'::dev_statut_type,
  description text,
  declared_by uuid NOT NULL,
  declared_at timestamp with time zone NOT NULL DEFAULT now(),
  closed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  bloquante boolean DEFAULT false,
  numero_dn text,
  notified_48h boolean DEFAULT false,
  declared_service text,
  closed_by uuid,
  CONSTRAINT deviations_pkey PRIMARY KEY (id),
  CONSTRAINT deviations_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id),
  CONSTRAINT deviations_declared_by_fkey FOREIGN KEY (declared_by) REFERENCES public.profiles(id),
  CONSTRAINT deviations_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.liberation_dossiers (
  id bigint NOT NULL DEFAULT nextval('liberation_dossiers_id_seq'::regclass),
  lot_id bigint NOT NULL UNIQUE,
  if_approved boolean DEFAULT false,
  ic_approved boolean DEFAULT false,
  da_pc_approved boolean DEFAULT false,
  da_micro_approved boolean DEFAULT false,
  da_micro_applicable boolean DEFAULT true,
  deviations_closed boolean DEFAULT true,
  pieces_complementaires_ok boolean DEFAULT true,
  statut USER-DEFINED DEFAULT 'incomplet'::dossier_statut_type,
  transferred_by uuid,
  liberated_by uuid,
  transferred_at timestamp with time zone,
  liberated_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT liberation_dossiers_pkey PRIMARY KEY (id),
  CONSTRAINT liberation_dossiers_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id),
  CONSTRAINT liberation_dossiers_transferred_by_fkey FOREIGN KEY (transferred_by) REFERENCES public.profiles(id),
  CONSTRAINT liberation_dossiers_liberated_by_fkey FOREIGN KEY (liberated_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.lot_events (
  id bigint NOT NULL DEFAULT nextval('lot_events_id_seq'::regclass),
  lot_id bigint NOT NULL,
  event_type text NOT NULL,
  description text,
  old_value text,
  new_value text,
  triggered_by uuid,
  source text DEFAULT 'app'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT lot_events_pkey PRIMARY KEY (id),
  CONSTRAINT lot_events_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id),
  CONSTRAINT lot_events_triggered_by_fkey FOREIGN KEY (triggered_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.permissions (
  id bigint NOT NULL DEFAULT nextval('permissions_id_seq'::regclass),
  service USER-DEFINED NOT NULL,
  action text NOT NULL,
  allowed boolean DEFAULT false,
  CONSTRAINT permissions_pkey PRIMARY KEY (id)
);
CREATE TABLE public.notifications (
  id bigint NOT NULL DEFAULT nextval('notifications_id_seq'::regclass),
  service USER-DEFINED NOT NULL,
  lot_id bigint,
  document_id bigint,
  message text NOT NULL,
  event_type text NOT NULL,
  is_read boolean DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id),
  CONSTRAINT notifications_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.liberation_documents(id)
);
CREATE TABLE public.lot_planning (
  id bigint NOT NULL DEFAULT nextval('lot_planning_id_seq'::regclass),
  lot_id bigint UNIQUE,
  date_lcq_cible date,
  date_lcq_revisee date,
  date_aq_cible date,
  date_aq_revisee date,
  date_dt_cible date,
  date_dt_revisee date,
  updated_at timestamp with time zone DEFAULT now(),
  updated_by uuid,
  CONSTRAINT lot_planning_pkey PRIMARY KEY (id),
  CONSTRAINT lot_planning_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id),
  CONSTRAINT lot_planning_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id)
);
CREATE TABLE public.planning_alert_log (
  id bigint NOT NULL DEFAULT nextval('planning_alert_log_id_seq'::regclass),
  lot_id bigint,
  date_type text NOT NULL,
  target_date date NOT NULL,
  level text NOT NULL,
  alert_day date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT planning_alert_log_pkey PRIMARY KEY (id),
  CONSTRAINT planning_alert_log_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id)
);

-- ─── MODULE PRODUCTION / RÉFÉRENCIEL TRS (créé hors migrations — cf. CLAUDE.md N°18) ───
-- Pas d'enum : recréable directement. RLS = migrations 020→023. FK manquantes = 024.

CREATE TABLE public.services (
  id text NOT NULL,
  label text NOT NULL,
  sort_order integer DEFAULT 0,
  CONSTRAINT services_pkey PRIMARY KEY (id)
);
CREATE TABLE public.app_settings (
  key text NOT NULL,
  value text DEFAULT ''::text,
  CONSTRAINT app_settings_pkey PRIMARY KEY (key)
);
CREATE TABLE public.processus (
  id bigint NOT NULL DEFAULT nextval('processus_id_seq'::regclass),
  nom_process text NOT NULL,
  ordre integer NOT NULL DEFAULT 0,
  couleur text NOT NULL DEFAULT '#6B7280'::text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT processus_pkey PRIMARY KEY (id)
);
CREATE TABLE public.ateliers (
  id bigint NOT NULL DEFAULT nextval('ateliers_id_seq'::regclass),
  nom_atelier text NOT NULL,
  processus_id bigint,
  description_plan_zone text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT ateliers_pkey PRIMARY KEY (id),
  CONSTRAINT ateliers_processus_id_fkey FOREIGN KEY (processus_id) REFERENCES public.processus(id)
);
CREATE TABLE public.arret_familles (
  id bigint NOT NULL DEFAULT nextval('arret_familles_id_seq'::regclass),
  nom text NOT NULL,
  couleur text NOT NULL DEFAULT '#EF4444'::text,
  ordre integer NOT NULL DEFAULT 0,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT arret_familles_pkey PRIMARY KEY (id)
);
CREATE TABLE public.arret_sous_familles (
  id bigint NOT NULL DEFAULT nextval('arret_sous_familles_id_seq'::regclass),
  famille_id bigint NOT NULL,
  nom text NOT NULL,
  ordre integer NOT NULL DEFAULT 0,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT arret_sous_familles_pkey PRIMARY KEY (id),
  CONSTRAINT arret_sous_familles_famille_id_fkey FOREIGN KEY (famille_id) REFERENCES public.arret_familles(id)
);
CREATE TABLE public.arret_types (
  id bigint NOT NULL DEFAULT nextval('arret_types_id_seq'::regclass),
  sous_famille_id bigint NOT NULL,
  code text NOT NULL UNIQUE,
  nom text NOT NULL,
  couleur text,
  duree_std_min integer,
  est_planifie boolean NOT NULL DEFAULT false,
  est_pause boolean NOT NULL DEFAULT false,
  impacte_trs boolean NOT NULL DEFAULT true,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT arret_types_pkey PRIMARY KEY (id),
  CONSTRAINT arret_types_sous_famille_id_fkey FOREIGN KEY (sous_famille_id) REFERENCES public.arret_sous_familles(id)
);
CREATE TABLE public.shifts (
  id bigint NOT NULL DEFAULT nextval('shifts_id_seq'::regclass),
  nom text NOT NULL,
  heure_debut time without time zone NOT NULL,
  heure_fin time without time zone NOT NULL,
  duree_min integer NOT NULL DEFAULT 480,
  couleur text NOT NULL DEFAULT '#3B82F6'::text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT shifts_pkey PRIMARY KEY (id)
);
CREATE TABLE public.equipes (
  id bigint NOT NULL DEFAULT nextval('equipes_id_seq'::regclass),
  nom text NOT NULL,
  couleur text NOT NULL DEFAULT '#8B5CF6'::text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT equipes_pkey PRIMARY KEY (id)
);
CREATE TABLE public.equipements_conditionnement (
  id bigint NOT NULL DEFAULT nextval('equipements_conditionnement_id_seq'::regclass),
  nom_equipement text NOT NULL,
  site text NOT NULL DEFAULT 'PHARMA'::text,
  description_zone text,
  ordre_affichage integer NOT NULL DEFAULT 9999,
  travaille_weekend boolean NOT NULL DEFAULT false,
  cadence_nominale_boite_min numeric,
  cadence_objectif_boite_min numeric,
  taux_rendement_cible numeric DEFAULT 85.00,
  temps_ouverture_shift_min integer NOT NULL DEFAULT 480,
  temps_pause_planifie_min integer NOT NULL DEFAULT 30,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT equipements_conditionnement_pkey PRIMARY KEY (id)
);
CREATE TABLE public.objectifs_production (
  id bigint NOT NULL DEFAULT nextval('objectifs_production_id_seq'::regclass),
  equipement_id bigint NOT NULL,
  product_id bigint,
  shift_id bigint,
  cadence_objectif_boite_min numeric NOT NULL,
  colisage_ref integer,
  commentaire text,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT objectifs_production_pkey PRIMARY KEY (id),
  CONSTRAINT objectifs_production_equipement_id_fkey FOREIGN KEY (equipement_id) REFERENCES public.equipements_conditionnement(id),
  CONSTRAINT objectifs_production_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT objectifs_production_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.shifts(id)
);
CREATE TABLE public.shift_planning (
  id bigint NOT NULL DEFAULT nextval('shift_planning_id_seq'::regclass),
  date date NOT NULL,
  shift_id bigint NOT NULL,
  equipe_id bigint,
  equipement_id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT shift_planning_pkey PRIMARY KEY (id),
  CONSTRAINT shift_planning_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.shifts(id),
  CONSTRAINT shift_planning_equipe_id_fkey FOREIGN KEY (equipe_id) REFERENCES public.equipes(id),
  CONSTRAINT shift_planning_equipement_id_fkey FOREIGN KEY (equipement_id) REFERENCES public.equipements_conditionnement(id)
);
CREATE TABLE public.planification_conditionnement (
  id bigint NOT NULL DEFAULT nextval('planification_conditionnement_id_seq'::regclass),
  lot_id bigint NOT NULL UNIQUE,
  equipement_id bigint,
  ordre_plan integer,
  date_debut_estimee date,
  date_fin_estimee date,
  duree_estimee_jours numeric,
  statut_planification text NOT NULL DEFAULT 'Planifié'::text,
  commentaire text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT planification_conditionnement_pkey PRIMARY KEY (id),
  CONSTRAINT planification_conditionnement_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id),
  CONSTRAINT planification_conditionnement_equipement_id_fkey FOREIGN KEY (equipement_id) REFERENCES public.equipements_conditionnement(id)
);
CREATE TABLE public.suivi_fabrication (
  id bigint NOT NULL DEFAULT nextval('suivi_fabrication_id_seq'::regclass),
  lot_id bigint NOT NULL,
  atelier_id bigint,
  processus_id bigint,
  date_debut date,
  heure_debut time without time zone,
  date_fin date,
  heure_fin time without time zone,
  statut text CHECK (statut = ANY (ARRAY['En cours'::text, 'Clôturé'::text, 'Arrêt'::text])),
  observation text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  deleted_at timestamp with time zone,
  CONSTRAINT suivi_fabrication_pkey PRIMARY KEY (id),
  CONSTRAINT suivi_fabrication_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id),
  CONSTRAINT suivi_fabrication_atelier_id_fkey FOREIGN KEY (atelier_id) REFERENCES public.ateliers(id),
  CONSTRAINT suivi_fabrication_processus_id_fkey FOREIGN KEY (processus_id) REFERENCES public.processus(id)
);
CREATE TABLE public.atelier_arrets (
  id bigint NOT NULL DEFAULT nextval('atelier_arrets_id_seq'::regclass),
  atelier_id bigint NOT NULL,
  lot_id bigint,
  motif text NOT NULL,
  date_debut date NOT NULL,
  heure_debut time without time zone,
  date_fin date,
  heure_fin time without time zone,
  commentaire text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  deleted_at timestamp with time zone,
  CONSTRAINT atelier_arrets_pkey PRIMARY KEY (id),
  CONSTRAINT atelier_arrets_atelier_id_fkey FOREIGN KEY (atelier_id) REFERENCES public.ateliers(id),
  CONSTRAINT atelier_arrets_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id)
);
CREATE TABLE public.production_sessions (
  id bigint NOT NULL DEFAULT nextval('production_sessions_id_seq'::regclass),
  lot_id bigint NOT NULL,
  equipement_id bigint NOT NULL,
  shift_id bigint,
  equipe_id bigint,
  date date NOT NULL,
  heure_debut time without time zone NOT NULL,
  heure_fin time without time zone,
  statut text NOT NULL DEFAULT 'En cours'::text,
  colis_produits integer NOT NULL DEFAULT 0,
  colis_rebuts integer NOT NULL DEFAULT 0,
  cadence_nominale_snapshot numeric,
  cadence_objectif_snapshot numeric,
  cadence_reelle_boite_min numeric,
  objectif_boites integer,
  rendement_pct numeric,
  temps_ouverture_min integer,
  temps_fonctionnement_min integer,
  temps_net_min integer,
  temps_utile_min integer,
  temps_arret_planifie_min integer,
  temps_arret_impro_min integer,
  temps_pause_min integer,
  disponibilite numeric,
  performance numeric,
  qualite numeric,
  trs numeric,
  observation text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  deleted_at timestamp with time zone,
  colisage_confirme integer,
  CONSTRAINT production_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT production_sessions_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES public.lots(id),
  CONSTRAINT production_sessions_equipement_id_fkey FOREIGN KEY (equipement_id) REFERENCES public.equipements_conditionnement(id),
  CONSTRAINT production_sessions_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.shifts(id),
  CONSTRAINT production_sessions_equipe_id_fkey FOREIGN KEY (equipe_id) REFERENCES public.equipes(id)
);
CREATE TABLE public.production_arrets (
  id bigint NOT NULL DEFAULT nextval('production_arrets_id_seq'::regclass),
  session_id bigint NOT NULL,
  arret_type_id bigint,
  famille_nom text,
  sous_famille_nom text,
  arret_code text,
  arret_nom text,
  couleur text,
  est_planifie boolean NOT NULL DEFAULT false,
  est_pause boolean NOT NULL DEFAULT false,
  heure_debut time without time zone NOT NULL,
  heure_fin time without time zone,
  duree_minutes integer,
  is_running boolean NOT NULL DEFAULT true,
  commentaire text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT production_arrets_pkey PRIMARY KEY (id),
  CONSTRAINT production_arrets_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.production_sessions(id),
  CONSTRAINT production_arrets_arret_type_id_fkey FOREIGN KEY (arret_type_id) REFERENCES public.arret_types(id)
);
CREATE TABLE public.production_comptages (
  id bigint NOT NULL DEFAULT nextval('production_comptages_id_seq'::regclass),
  session_id bigint NOT NULL,
  heure time without time zone NOT NULL,
  colis_cumules integer NOT NULL DEFAULT 0,
  rebuts_cumules integer NOT NULL DEFAULT 0,
  cadence_instantanee numeric,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT production_comptages_pkey PRIMARY KEY (id),
  CONSTRAINT production_comptages_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.production_sessions(id)
);
CREATE TABLE public.plan_rooms (
  id bigint NOT NULL DEFAULT nextval('plan_rooms_id_seq'::regclass),
  code text NOT NULL UNIQUE,
  nom text NOT NULL,
  zone text NOT NULL DEFAULT 'formes_seches'::text,
  type text NOT NULL DEFAULT 'fab'::text,
  atelier_id bigint,
  equipement_id bigint,
  x double precision NOT NULL DEFAULT 0,
  y double precision NOT NULL DEFAULT 0,
  w double precision NOT NULL DEFAULT 80,
  h double precision NOT NULL DEFAULT 50,
  pdf_page integer NOT NULL DEFAULT 1,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  op_number integer,
  trs_cible_pct numeric,
  to_shift_min integer,
  pause_min integer,
  vdlp_min integer,
  vdlc_min integer,
  chgt_format_min integer,
  reglage_min integer,
  micro_arrets_min integer,
  maint_min integer,
  op_code character varying,
  equipment_name character varying,
  CONSTRAINT plan_rooms_pkey PRIMARY KEY (id),
  CONSTRAINT plan_rooms_atelier_id_fkey FOREIGN KEY (atelier_id) REFERENCES public.ateliers(id),
  CONSTRAINT plan_rooms_equipement_id_fkey FOREIGN KEY (equipement_id) REFERENCES public.equipements_conditionnement(id)
);
CREATE TABLE public.operations_master (
  id integer NOT NULL DEFAULT nextval('operations_master_id_seq'::regclass),
  processus text NOT NULL,
  room_code text NOT NULL UNIQUE,
  room_name text NOT NULL,
  op_number integer NOT NULL,
  op_code text NOT NULL,
  equipment_name text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  trs_cible_pct numeric,
  to_shift_min integer,
  pause_min integer,
  vdlp_min integer,
  vdlc_min integer,
  chgt_format_min integer,
  reglage_min integer,
  micro_arrets_min integer,
  maint_min integer,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT operations_master_pkey PRIMARY KEY (id)
);
CREATE TABLE public.product_flux (
  id integer NOT NULL DEFAULT nextval('product_flux_id_seq'::regclass),
  product_code text NOT NULL,
  product_name text NOT NULL,
  op_number integer NOT NULL,
  route integer NOT NULL DEFAULT 1,
  room_code text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT product_flux_pkey PRIMARY KEY (id)
);
CREATE TABLE public.equipment_cadences (
  id integer NOT NULL DEFAULT nextval('equipment_cadences_id_seq'::regclass),
  room_code text NOT NULL,
  product_code text NOT NULL,
  cadence_theorique numeric,
  unite text DEFAULT 'cp/h'::text,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT equipment_cadences_pkey PRIMARY KEY (id)
);
CREATE TABLE public.session_cadences (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id bigint NOT NULL,
  cadence_bpm numeric NOT NULL,
  colisage integer,
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT session_cadences_pkey PRIMARY KEY (id),
  CONSTRAINT session_cadences_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.production_sessions(id)
);
CREATE TABLE public.suivi_conditionnement (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  lot_id bigint,
  equipement_id bigint,
  date_debut timestamp with time zone,
  date_fin timestamp with time zone,
  date_fin_estimee date,
  taille_lot integer,
  statut character varying NOT NULL DEFAULT 'En cours'::character varying,
  observation text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  deleted_at timestamp with time zone,
  created_by uuid,
  CONSTRAINT suivi_conditionnement_pkey PRIMARY KEY (id),
  CONSTRAINT fk_suivi_cond_lot FOREIGN KEY (lot_id) REFERENCES public.lots(id),
  CONSTRAINT fk_suivi_cond_equip FOREIGN KEY (equipement_id) REFERENCES public.equipements_conditionnement(id)
);
CREATE TABLE public.arret_conditionnement (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  suivi_id uuid,
  equipement_id uuid,                          -- ⚠️ BUG TYPE : devrait être bigint (cf. 024)
  lot_id bigint,
  motif text NOT NULL,
  heure_debut timestamp with time zone DEFAULT now(),
  heure_fin timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  deleted_at timestamp with time zone,
  CONSTRAINT arret_conditionnement_pkey PRIMARY KEY (id)
  -- ⚠️ AUCUNE FK d'origine (suivi_id, lot_id ajoutées en 024 ; equipement_id bloquée par le type)
);
CREATE TABLE public.cadences (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  numero_salle integer NOT NULL,
  code_article character varying NOT NULL,
  description text,
  equipment_name character varying,
  taille_lot integer NOT NULL,
  cadence_objectif_b_min numeric NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT cadences_pkey PRIMARY KEY (id)
);
