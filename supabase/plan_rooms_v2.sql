-- ═══════════════════════════════════════════════════════════════════
-- plan_rooms_v2.sql — Hotspots corrigés d'après le plan P004 réel
-- Exécuter dans Supabase → SQL Editor
-- Les coordonnées x/y sont approximatives — à recalibrer via ✎ admin
-- Canvas de référence : PNG 150 DPI ≈ 4967×3508 px (A1 paysage)
-- ═══════════════════════════════════════════════════════════════════

-- 1. Vider les anciennes données (les fausses)
TRUNCATE plan_rooms RESTART IDENTITY;

-- 2. Insérer les vraies salles de process

INSERT INTO plan_rooms (code, nom, zone, type, x, y, w, h, pdf_page) VALUES

-- ── ZONE FORMES SÈCHES — BÂTIMENT 400 (nouveau) ───────────────────
('442',  'Salle de Formulation',                        'formes_seches', 'fab', 1260,   30, 320, 220, 1),
('425',  'Salle de Granulation et Séchage 02',          'formes_seches', 'fab', 1260,  280, 490, 330, 1),
('448',  'Salle de Mélange 03',                         'formes_seches', 'fab', 1770,  280, 330, 330, 1),
('429',  'Salle de Pelliculage 02',                     'formes_seches', 'fab', 2120,  280, 310, 330, 1),
('426',  'Salle Préparation Solution Granulation 02',   'formes_seches', 'fab', 1260,  630, 260, 130, 1),
('430',  'Salle Préparation Solution Pelliculage 02',   'formes_seches', 'fab', 2120,  630, 310, 130, 1),
('436',  'Salle de Remplissage Gélules 02',             'formes_seches', 'fab', 1260,  880, 390, 260, 1),
('445',  'Salle de Compression 04',                     'formes_seches', 'fab', 1670,  880, 340, 260, 1),

-- ── ZONE FORMES SÈCHES — BÂTIMENT 100 (historique) ───────────────
('138',  'Salle de Mélange 01 (Tamisage & Broyage)',    'formes_seches', 'fab', 1260, 1160, 330, 220, 1),
('140',  'Salle de Granulation et Séchage 01',          'formes_seches', 'fab', 1970, 1160, 330, 260, 1),
('131',  'Salle de Compression 01',                     'formes_seches', 'fab', 1260, 1400, 330, 280, 1),
('134',  'Salle de Compression 03',                     'formes_seches', 'fab', 1610, 1250, 330, 220, 1),
('128',  'Salle de Compression 02',                     'formes_seches', 'fab', 1970, 1440, 330, 260, 1),
('137',  'Salle de Mélange 02 (Tamisage & Broyage)',    'formes_seches', 'fab', 1610, 1490, 330, 220, 1),
('529',  'Salle de Mélange 03 (Tamisage & Broyage)',    'formes_seches', 'fab', 1260, 1700, 320, 220, 1),
('136',  'Salle de Pelliculage 03',                     'formes_seches', 'fab', 1610, 1730, 310, 210, 1),
('141',  'Salle de Séchage (LAF) Développement',        'formes_seches', 'fab', 1970, 1720, 300, 200, 1),
('141a', 'Salle de Pelliculage Développement',          'formes_seches', 'fab', 2290, 1720, 300, 200, 1),
('142',  'Salle de Granulation Développement',          'formes_seches', 'fab', 1970, 1940, 280, 180, 1),
('143a', 'Salle Préparation Solutions Pelliculage 01',  'formes_seches', 'fab', 2290, 1940, 300, 180, 1),
('143',  'Salle de Pelliculage 01',                     'formes_seches', 'fab', 1970, 2140, 310, 250, 1),
('139',  'Salle Préparation Solution Granulation 01',   'formes_seches', 'fab', 2300, 2140, 280, 160, 1),

-- ── ZONE FORMES SEMI-SOLIDES / PÂTEUSES ──────────────────────────
('200',  'Salle de Mélange Homogénéisateur',            'formes_semi',   'fab', 1500, 2620, 330, 260, 1),
('206',  'Salle de Remplissage des Tubes',              'formes_semi',   'fab',  900, 2620, 300, 300, 1),

-- ── ZONE CONDITIONNEMENT PRIMAIRE ────────────────────────────────
('224',  'Salle Conditionnement Primaire 08',           'cond_secondaire','cond', 890,   30, 330, 220, 1),
('223',  'Salle Conditionnement Primaire 07',           'cond_secondaire','cond', 890,  280, 330, 220, 1),
('222',  'Salle Conditionnement Primaire 06',           'cond_secondaire','cond', 890,  530, 330, 220, 1),
('220',  'Salle Conditionnement Primaire 05',           'cond_secondaire','cond', 890,  990, 330, 220, 1),
('146',  'Salle Conditionnement Primaire 04',           'cond_secondaire','cond', 890, 1260, 330, 220, 1),
('147',  'Salle Conditionnement Primaire 03',           'cond_secondaire','cond', 890, 1510, 330, 220, 1),
('148',  'Salle Conditionnement Primaire 02',           'cond_secondaire','cond', 890, 1760, 330, 220, 1),
('149',  'Salle Conditionnement Primaire 01',           'cond_secondaire','cond', 890, 2010, 330, 220, 1),

-- ── ZONE CONDITIONNEMENT SECONDAIRE ──────────────────────────────
('154',  'Salle Cond. Secondaire Extension',            'cond_secondaire','cond',  30,   30, 840, 1200, 1),
('153',  'Salle de Conditionnement Secondaire',         'cond_secondaire','cond',  30, 1260, 840, 1200, 1),

-- ── ZONE PESÉE ────────────────────────────────────────────────────
('464',  'Salle Pesée -02',                             'pesee',          'pesee',2620, 450, 310, 440, 1),
('471',  'Salle Pesée -03',                             'pesee',          'pesee',2620,1110, 310, 440, 1),

-- ── ZONE INJECTABLE / FORMES INJECTABLES ──────────────────────────
('521',  'Réception AC/SF Injectables',                 'injectable',     'cond', 3100, 2300, 380, 280, 1),
('522',  'Cond. Secondaire des Injectables',            'injectable',     'cond', 3100, 1850, 380, 360, 1);

-- 3. Vérification
SELECT code, nom, zone, type, x, y, w, h
FROM   plan_rooms
ORDER  BY zone, code::text;
