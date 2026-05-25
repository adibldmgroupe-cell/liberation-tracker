-- ═══════════════════════════════════════════════════════
-- TABLE plan_rooms — Hotspots interactifs sur le plan PDF
-- Exécuter dans Supabase SQL Editor
-- ═══════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS plan_rooms (
  id              bigserial PRIMARY KEY,
  code            text NOT NULL,              -- ex: "428"
  nom             text NOT NULL,              -- ex: "Granulation et séchage 02"
  zone            text NOT NULL DEFAULT 'formes_seches',
                  -- formes_seches | formes_semi | cond_secondaire | pesee | technique | magasin
  type            text NOT NULL DEFAULT 'fab',
                  -- fab | cond | pesee | support
  -- Liens vers les tables métier (optionnels)
  atelier_id      bigint REFERENCES ateliers(id) ON DELETE SET NULL,
  equipement_id   bigint REFERENCES equipements_conditionnement(id) ON DELETE SET NULL,
  -- Position sur le canvas PDF (en pixels, à l'échelle de rendu 2.5x)
  x               float NOT NULL DEFAULT 0,
  y               float NOT NULL DEFAULT 0,
  w               float NOT NULL DEFAULT 80,
  h               float NOT NULL DEFAULT 50,
  -- Page du PDF (si multi-pages)
  pdf_page        int NOT NULL DEFAULT 1,
  actif           bool NOT NULL DEFAULT true,
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now()
);

-- Index
CREATE INDEX IF NOT EXISTS plan_rooms_zone_idx ON plan_rooms(zone);
CREATE INDEX IF NOT EXISTS plan_rooms_type_idx ON plan_rooms(type);
CREATE INDEX IF NOT EXISTS plan_rooms_atelier_idx ON plan_rooms(atelier_id);
CREATE INDEX IF NOT EXISTS plan_rooms_equip_idx ON plan_rooms(equipement_id);

-- RLS : tout le monde peut lire, seul l'admin peut modifier
ALTER TABLE plan_rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "plan_rooms_read_all" ON plan_rooms
  FOR SELECT USING (true);

CREATE POLICY "plan_rooms_admin_write" ON plan_rooms
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.service = 'admin'
    )
  );

-- ═══════════════════════════════════════
-- SEED : salles pré-positionnées
-- Basé sur le plan P004 (page 1, rendu 2.5x = ~3000px wide)
-- Coordonnées à ajuster via le mode admin drag & drop
-- ═══════════════════════════════════════

-- Note: ces positions sont approximatives, à recalibrer
-- via le mode admin (bouton ✎ dans l'interface)

INSERT INTO plan_rooms (code, nom, zone, type, x, y, w, h, pdf_page) VALUES
-- Zone Formes Sèches (violet)
('428', 'Granulation et Séchage 01',    'formes_seches', 'fab', 1200, 440, 160, 90, 1),
('425', 'Granulation et Séchage 02',    'formes_seches', 'fab', 1380, 440, 160, 90, 1),
('429', 'Salle de Mélange',             'formes_seches', 'fab', 1560, 440, 120, 90, 1),
('421', 'Compression 01',               'formes_seches', 'fab', 1100, 560, 140, 90, 1),
('441', 'Compression 02',               'formes_seches', 'fab', 1260, 560, 140, 90, 1),
('444', 'Compression 03',               'formes_seches', 'fab', 1420, 560, 140, 90, 1),
('431', 'Pelliculage',                  'formes_seches', 'fab', 1580, 560, 140, 90, 1),
('448', 'Zone Pesée',                   'pesee',         'pesee',1100, 440, 80,  90, 1),

-- Zone Formes Semi-Solides (bleu)
('130', 'Fabrication Semi-Solide 01',   'formes_semi',   'fab',  460, 700, 160, 90, 1),
('131', 'Fabrication Semi-Solide 02',   'formes_semi',   'fab',  640, 700, 160, 90, 1),
('135', 'Remplissage Tubes',            'formes_semi',   'fab',  820, 700, 140, 90, 1),
('140', 'Remplissage Flacons',          'formes_semi',   'fab', 1000, 700, 140, 90, 1),

-- Zone Conditionnement Secondaire (vert — droite)
('154', 'Conditionnement Secondaire 01','cond_secondaire','cond',1820, 360, 160, 90, 1),
('155', 'Conditionnement Secondaire 02','cond_secondaire','cond',1820, 470, 160, 90, 1),
('152', 'Conditionnement Secondaire 03','cond_secondaire','cond',1820, 580, 160, 90, 1),
('153', 'Conditionnement Secondaire 04','cond_secondaire','cond',1820, 690, 160, 90, 1),

-- Zone Conditionnement (gauche)
('220', 'Conditionnement Primaire 01',  'cond_secondaire','cond', 160, 440, 160, 90, 1),
('222', 'Conditionnement Primaire 02',  'cond_secondaire','cond', 160, 560, 160, 90, 1),
('224', 'Conditionnement Primaire 03',  'cond_secondaire','cond', 160, 680, 160, 90, 1),

-- Zones support
('410', 'Couloir Formes Sèches',        'technique',     'support', 950, 440, 60, 200, 1),
('200', 'SAS Production',               'technique',     'support', 680, 840, 100, 80, 1);

-- Vérification
SELECT code, nom, zone, type, x, y FROM plan_rooms ORDER BY zone, code;
