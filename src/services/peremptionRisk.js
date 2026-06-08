// ════════════════════════════════════════════════════════════════════════
// SOURCE UNIQUE — Matrice de gestion des risques de péremption (Phase 1)
// 3 axes · 9 sous-critères scorés 1/3/5 · score d'axe = moyenne · score global
// = pondération configurable (Produit 25 / Partenaire 25 / Marché 50).
// Ne JAMAIS redéfinir ces barèmes ailleurs (cf. règle « source unique »).
// ════════════════════════════════════════════════════════════════════════

export var AXES = [
  { key: 'produit',    label: 'Produit',    poidsKey: 'poids_produit' },
  { key: 'partenaire', label: 'Partenaire', poidsKey: 'poids_partenaire' },
  { key: 'marche',     label: 'Marché',     poidsKey: 'poids_marche' },
]

// barème exact de la PJ « 2. BARÈMES DE SCORING PAR SOUS-CRITÈRE »
export var CRITERIA = [
  // ── PRODUIT ──
  { key: 'sc_shelf_life', axe: 'produit', label: 'Shelf Life',
    s1: '≥ 4 ans', s3: '2–3 ans', s5: '< 2 ans',
    logique: 'Plus la shelf life est courte, plus le risque de péremption est élevé', binaire: false },
  { key: 'sc_prix', axe: 'produit', label: 'Prix unitaire',
    s1: '< 50 M DA', s3: '50–500 M DA', s5: '≥ 500 M DA',
    logique: "Plus la valeur est élevée, plus l'impact financier de la perte est important", binaire: false },
  { key: 'sc_historique', axe: 'produit', label: 'Historique péremption',
    s1: 'Aucun précédent', s3: 'Déjà arrivé (ponctuel)', s5: 'Récurrent (répétitif)',
    logique: 'La répétitivité indique un problème structurel, pas conjoncturel', binaire: false },
  // ── PARTENAIRE ── (partenaire = fabricant du catalogue)
  { key: 'sc_forecast', axe: 'partenaire', label: 'Forecast accuracy',
    s1: 'Fiable (écart < 10%)', s3: null, s5: 'Non fiable (écart > 30%)',
    logique: "Binaire (1 ou 5) : le forecast est fiable ou ne l'est pas", binaire: true },
  { key: 'sc_solvabilite', axe: 'partenaire', label: 'Solvabilité',
    s1: 'Solvable (paiement régulier)', s3: 'Retards ponctuels', s5: "Risque d'impayé",
    logique: 'Capacité du client/partenaire à honorer ses engagements', binaire: false },
  { key: 'sc_engagements', axe: 'partenaire', label: 'Respect engagements',
    s1: 'Engagements tenus', s3: 'Écarts modérés', s5: 'Non-respect récurrent',
    logique: 'Contrats cadres, BC, volumes engagés vs consommés', binaire: false },
  // ── MARCHÉ ──
  { key: 'sc_croissance', axe: 'marche', label: 'Croissance marché',
    s1: '> +5% (croissance)', s3: '0% à +5% (stable)', s5: '< 0% (décroissance)',
    logique: 'Un marché en décroissance amplifie le risque de surstock', binaire: false },
  { key: 'sc_concurrence', axe: 'marche', label: 'Concurrence',
    s1: "Faible (peu d'acteurs)", s3: 'Moyenne (3–5 acteurs)', s5: 'Forte (saturé)',
    logique: 'Plus le marché est concurrentiel, plus la part est fragile', binaire: false },
  { key: 'sc_maturite', axe: 'marche', label: 'Maturité produit',
    s1: 'Routine (établi)', s3: null, s5: 'Lancement (nouveau)',
    logique: 'Un produit en lancement a un forecast moins fiable', binaire: true },
]

// Mode d'approvisionnement (relation au partenaire/labo) — sert aussi à la Phase 2
export var MODE_APPRO = [
  { key: 'sous_licence', label: 'Production sous licence' },
  { key: 'import',       label: "Importation (revente en l'état)" },
  { key: 'les_deux',     label: 'Les deux (production + import)' },
  { key: 'generique',    label: 'Générique LDM' },
]
export var MODE_APPRO_LABELS = MODE_APPRO.reduce(function (m, x) { m[x.key] = x.label; return m }, {})

export var DEFAULT_CONFIG = { poids_produit: 25, poids_partenaire: 25, poids_marche: 50, seuil_moyen: 2, seuil_eleve: 4 }

export var NIVEAU_LABELS = { faible: 'Faible', moyen: 'Moyen', eleve: 'Élevé' }
export var NIVEAU_CLASS  = { faible: 'niv-faible', moyen: 'niv-moyen', eleve: 'niv-eleve' }
export var NIVEAU_ORDER  = { faible: 1, moyen: 2, eleve: 3 }

export function criteriaForAxe(axeKey) {
  return CRITERIA.filter(function (c) { return c.axe === axeKey })
}

// valeur autorisée pour un sous-critère (binaire = 1 ou 5 ; sinon 1/3/5)
export function allowedValues(crit) {
  return crit.binaire ? [1, 5] : [1, 3, 5]
}

// moyenne d'axe sur les sous-critères renseignés (1/3/5) ; null si aucun
export function axisScore(scores, axeKey) {
  var vals = criteriaForAxe(axeKey)
    .map(function (c) { return scores[c.key] })
    .filter(function (v) { return v === 1 || v === 3 || v === 5 })
  if (!vals.length) return null
  return vals.reduce(function (a, b) { return a + b }, 0) / vals.length
}

// arrondi 2 décimales (évite les flottants type 2.6666666)
function r2(v) { return v == null ? null : Math.round(v * 100) / 100 }

// score global pondéré + niveau (paliers configurables)
export function computeScores(scores, config) {
  var cfg = config || DEFAULT_CONFIG
  var sp = axisScore(scores, 'produit')
  var spa = axisScore(scores, 'partenaire')
  var sm = axisScore(scores, 'marche')
  var parts = []
  if (sp != null) parts.push([sp, Number(cfg.poids_produit) || 0])
  if (spa != null) parts.push([spa, Number(cfg.poids_partenaire) || 0])
  if (sm != null) parts.push([sm, Number(cfg.poids_marche) || 0])
  var totalW = parts.reduce(function (a, p) { return a + p[1] }, 0)
  var global = totalW > 0 ? parts.reduce(function (a, p) { return a + p[0] * p[1] }, 0) / totalW : null
  var niveau = global == null ? null
    : (global <= Number(cfg.seuil_moyen) ? 'faible'
      : (global <= Number(cfg.seuil_eleve) ? 'moyen' : 'eleve'))
  return { score_produit: r2(sp), score_partenaire: r2(spa), score_marche: r2(sm), score_global: r2(global), niveau: niveau }
}

// les 9 sous-critères sont-ils tous renseignés ?
export function isComplete(scores) {
  return CRITERIA.every(function (c) { var v = scores[c.key]; return v === 1 || v === 3 || v === 5 })
}
