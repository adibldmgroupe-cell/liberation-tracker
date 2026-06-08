// ════════════════════════════════════════════════════════════════════════
// SOURCE UNIQUE — Matrice de gestion des risques de péremption
// DEUX modèles de scoring sélectionnés par produit :
//   • PRODUCTION (LDM) : fabricant === « PRODUCTION LDM GROUPE » (générique + OTC)
//   • IMPORT          : tout le reste (sous-licence ABBOTT/SERVIER/… + REV revente)
// Chaque modèle : 3 axes, sous-critères 1/3/5, score d'axe = moyenne,
// score global = pondération configurable. Niveau 3 paliers (≤seuil_moyen Faible
// · ≤seuil_eleve Moyen · sinon Élevé). Ne PAS redéfinir ces barèmes ailleurs.
// ════════════════════════════════════════════════════════════════════════

// ── Sous-critères du modèle IMPORT (revente / sous-licence) ──
var C_IMPORT = [
  { key: 'sc_shelf_life', axe: 'produit', label: 'Shelf Life', s1: '≥ 4 ans', s3: '2–3 ans', s5: '< 2 ans', logique: 'Plus la shelf life est courte, plus le risque de péremption est élevé', binaire: false },
  { key: 'sc_prix', axe: 'produit', label: 'Montant forecast', s1: '< 50 M DA', s3: '50–500 M DA', s5: '≥ 500 M DA', logique: "Plus la valeur est élevée, plus l'impact financier de la perte est important", binaire: false },
  { key: 'sc_historique', axe: 'produit', label: 'Historique péremption', s1: 'Aucun précédent', s3: 'Déjà arrivé (ponctuel)', s5: 'Récurrent (répétitif)', logique: 'La répétitivité indique un problème structurel, pas conjoncturel', binaire: false },
  { key: 'sc_forecast', axe: 'partenaire', label: 'Forecast accuracy', s1: 'Fiable (écart < 10%)', s3: null, s5: 'Non fiable (écart > 30%)', logique: "Binaire (1 ou 5) : le forecast est fiable ou ne l'est pas", binaire: true },
  { key: 'sc_solvabilite', axe: 'partenaire', label: 'Solvabilité', s1: 'Solvable (paiement régulier)', s3: 'Retards ponctuels', s5: "Risque d'impayé", logique: 'Capacité du client/partenaire à honorer ses engagements', binaire: false },
  { key: 'sc_engagements', axe: 'partenaire', label: 'Respect engagements', s1: 'Engagements tenus', s3: 'Écarts modérés', s5: 'Non-respect récurrent', logique: 'Contrats cadres, BC, volumes engagés vs consommés', binaire: false },
  { key: 'sc_croissance', axe: 'marche', label: 'Croissance marché', s1: '> +5% (croissance)', s3: '0% à +5% (stable)', s5: '< 0% (décroissance)', logique: 'Un marché en décroissance amplifie le risque de surstock', binaire: false },
  { key: 'sc_concurrence', axe: 'marche', label: 'Concurrence', s1: "Faible (peu d'acteurs)", s3: 'Moyenne (3–5 acteurs)', s5: 'Forte (saturé)', logique: 'Plus le marché est concurrentiel, plus la part est fragile', binaire: false },
  { key: 'sc_maturite', axe: 'marche', label: 'Maturité produit', s1: 'Routine (établi)', s3: null, s5: 'Lancement (nouveau)', logique: 'Un produit en lancement a un forecast moins fiable', binaire: true },
]

// ── Sous-critères du modèle PRODUCTION (générique + OTC LDM) ──
var C_PROD = [
  { key: 'sc_shelf_life', axe: 'produit', label: 'Shelf Life', s1: '≥ 3 ans', s3: null, s5: '< 3 ans', logique: 'Plus la shelf life est courte, plus le risque de péremption est élevé', binaire: true },
  { key: 'sc_prix', axe: 'produit', label: 'Montant forecast', s1: '< 10 M DA', s3: '10–50 M DA', s5: '≥ 50 M DA', logique: "Plus la valeur est élevée, plus l'impact financier de la perte est important", binaire: false },
  { key: 'sc_historique', axe: 'produit', label: 'Historique péremption', s1: 'Aucun précédent', s3: 'Déjà arrivé (ponctuel)', s5: 'Récurrent (répétitif)', logique: 'La répétitivité indique un problème structurel, pas conjoncturel', binaire: false },
  { key: 'sc_profitabilite', axe: 'produit', label: 'Profitabilité', s1: 'Niveau 1', s3: 'Niveau 2', s5: 'Niveau 3', logique: 'Plus la profitabilité est faible, plus la perte pèse', binaire: false },
  { key: 'sc_forecast', axe: 'commercial', label: 'Forecast accuracy', s1: 'Fiable (écart < 10%)', s3: 'Moyennement fiable (écart < 30%)', s5: 'Non fiable (écart > 30%)', logique: 'Précision des prévisions commerciales', binaire: false },
  { key: 'sc_promotion', axe: 'commercial', label: 'Promotion médicale & Marketing, Offre commerciale', s1: 'Niveau 1', s3: 'Niveau 2', s5: 'Niveau 3', logique: "Effort promotionnel / commercial soutenant l'écoulement", binaire: false },
  { key: 'sc_croissance', axe: 'marche', label: 'Croissance marché', s1: '> +5% (croissance)', s3: '0% à +5% (stable)', s5: '< 0% (décroissance)', logique: 'Un marché en décroissance amplifie le risque de surstock', binaire: false },
  { key: 'sc_concurrence', axe: 'marche', label: 'Concurrence', s1: "Faible (peu d'acteurs)", s3: 'Moyenne (3–5 acteurs)', s5: 'Forte (saturé)', logique: 'Plus le marché est concurrentiel, plus la part est fragile', binaire: false },
  { key: 'sc_maturite', axe: 'marche', label: 'Maturité produit', s1: 'Routine (établi)', s3: null, s5: 'Lancement (nouveau)', logique: 'Un produit en lancement a un forecast moins fiable', binaire: true },
]

export var MODELS = {
  import: {
    key: 'import', label: 'Import / Revente',
    axes: [
      { key: 'produit', label: 'Produit', short: 'Produit', poidsKey: 'poids_produit' },
      { key: 'partenaire', label: 'Partenaire', short: 'Partenaire', poidsKey: 'poids_partenaire' },
      { key: 'marche', label: 'Marché', short: 'Marché', poidsKey: 'poids_marche' },
    ],
    criteria: C_IMPORT,
  },
  production: {
    key: 'production', label: 'Production LDM',
    axes: [
      { key: 'produit', label: 'Produit', short: 'Produit', poidsKey: 'poids_prod_produit' },
      { key: 'commercial', label: 'Commercial, Marketing & promotion médicale', short: 'Commercial', poidsKey: 'poids_prod_commercial' },
      { key: 'marche', label: 'Marché', short: 'Marché', poidsKey: 'poids_prod_marche' },
    ],
    criteria: C_PROD,
  },
}

export var LDM_FABRICANT = 'PRODUCTION LDM GROUPE'

export function getModel(modelKey) { return MODELS[modelKey] || MODELS.import }

// Modèle d'un produit : LDM → production ; tout le reste → import
export function modelForProduct(p) {
  var fab = (p && p.fabricant ? p.fabricant : '').trim().toUpperCase()
  return fab === LDM_FABRICANT ? 'production' : 'import'
}

// Type d'un produit (pour affichage / filtre)
export function productType(p) {
  if (!p) return 'import'
  var fab = (p.fabricant || '').trim().toUpperCase()
  var grp = p.groupe_article || ''
  if (fab === LDM_FABRICANT) return grp === 'OT.PF-OTC' ? 'otc' : 'generique'
  if (/REV/i.test(grp)) return 'import'
  return 'sous_licence'
}
export var TYPE_LABELS = { generique: 'Générique', otc: 'OTC', sous_licence: 'Sous-licence', import: 'Import/Revente' }
export var TYPE_CLASS = { generique: 'ty-gen', otc: 'ty-otc', sous_licence: 'ty-sl', import: 'ty-imp' }

// produit en revente en l'état (REV) — visible uniquement dans la matrice péremption
export function isRevente(p) { return !!(p && p.groupe_article && /REV/i.test(p.groupe_article)) }

// Libellé COMPLET de chaque sous-critère (union des 2 modèles) — source unique pour les colonnes
export var CRIT_LABELS = {}
;[].concat(C_IMPORT, C_PROD).forEach(function (c) { if (!CRIT_LABELS[c.key]) CRIT_LABELS[c.key] = c.label })
// Axe d'appartenance (pour l'en-tête de groupe dans la matrice ; l'axe milieu = Partenaire en import / Commercial en production)
export var CRIT_AXIS_LABEL = {
  sc_shelf_life: 'Produit', sc_prix: 'Produit', sc_historique: 'Produit', sc_profitabilite: 'Produit',
  sc_forecast: 'Partenaire / Commercial', sc_solvabilite: 'Partenaire / Commercial', sc_engagements: 'Partenaire / Commercial', sc_promotion: 'Partenaire / Commercial',
  sc_croissance: 'Marché', sc_concurrence: 'Marché', sc_maturite: 'Marché',
}

export var MODE_APPRO = [
  { key: 'sous_licence', label: 'Production sous licence' },
  { key: 'import',       label: "Importation (revente en l'état)" },
  { key: 'les_deux',     label: 'Les deux (production + import)' },
  { key: 'generique',    label: 'Générique LDM' },
]
export var MODE_APPRO_LABELS = MODE_APPRO.reduce(function (m, x) { m[x.key] = x.label; return m }, {})

export var DEFAULT_CONFIG = {
  poids_produit: 25, poids_partenaire: 25, poids_marche: 50,
  poids_prod_produit: 40, poids_prod_commercial: 25, poids_prod_marche: 35,
  seuil_moyen: 2, seuil_eleve: 4,
}

export var NIVEAU_LABELS = { faible: 'Faible', moyen: 'Moyen', eleve: 'Élevé' }
export var NIVEAU_CLASS  = { faible: 'niv-faible', moyen: 'niv-moyen', eleve: 'niv-eleve' }
export var NIVEAU_ORDER  = { faible: 1, moyen: 2, eleve: 3 }

export function criteriaForModel(modelKey) { return getModel(modelKey).criteria }
export function criteriaForModelAxe(modelKey, axeKey) { return getModel(modelKey).criteria.filter(function (c) { return c.axe === axeKey }) }

// valeur autorisée pour un sous-critère (binaire = 1 ou 5 ; sinon 1/3/5)
export function allowedValues(crit) { return crit.binaire ? [1, 5] : [1, 3, 5] }

function r2(v) { return v == null ? null : Math.round(v * 100) / 100 }

// moyenne d'axe (sur les sous-critères renseignés) pour un modèle donné
export function axisScore(scores, modelKey, axeKey) {
  var vals = criteriaForModelAxe(modelKey, axeKey)
    .map(function (c) { return scores[c.key] })
    .filter(function (v) { return v === 1 || v === 3 || v === 5 })
  if (!vals.length) return null
  return vals.reduce(function (a, b) { return a + b }, 0) / vals.length
}

// score global pondéré + niveau, pour le modèle du produit
export function computeScores(scores, config, modelKey) {
  var cfg = config || DEFAULT_CONFIG
  var model = getModel(modelKey)
  var parts = [], axisScores = {}
  model.axes.forEach(function (ax) {
    var s = axisScore(scores, model.key, ax.key)
    axisScores[ax.key] = r2(s)
    if (s != null) parts.push([s, Number(cfg[ax.poidsKey]) || 0])
  })
  var totalW = parts.reduce(function (a, p) { return a + p[1] }, 0)
  var global = totalW > 0 ? parts.reduce(function (a, p) { return a + p[0] * p[1] }, 0) / totalW : null
  var niveau = global == null ? null
    : (global <= Number(cfg.seuil_moyen) ? 'faible' : (global <= Number(cfg.seuil_eleve) ? 'moyen' : 'eleve'))
  // axe milieu (partenaire pour import, commercial pour production) stocké dans score_partenaire
  var milieu = axisScores.partenaire != null ? axisScores.partenaire : (axisScores.commercial != null ? axisScores.commercial : null)
  return {
    axisScores: axisScores,
    score_produit: axisScores.produit != null ? axisScores.produit : null,
    score_partenaire: milieu,
    score_marche: axisScores.marche != null ? axisScores.marche : null,
    score_global: r2(global), niveau: niveau,
  }
}

// tous les sous-critères du modèle sont-ils renseignés ?
export function isComplete(scores, modelKey) {
  return getModel(modelKey).criteria.every(function (c) { var v = scores[c.key]; return v === 1 || v === 3 || v === 5 })
}

// ════════════════════════════════════════════════════════════════════════
// COUCHE DÉCISIONNELLE — le niveau de risque déclenche des décisions
// (auto-recommandées, confirmées dans le circuit Phase 2). Commun aux 2 modèles.
// Faible → aucun circuit · Moyen → validation Niveau 2 · Élevé → Niveau 3.
// ════════════════════════════════════════════════════════════════════════
export var DECISION_MATRIX = {
  faible: { forecast: 'best',   split: 'multiple_moq', validation: null, monitoring: 'trimestriel' },
  moyen:  { forecast: 'middle', split: 'multiple_moq', validation: 2,    monitoring: 'mensuel' },
  eleve:  { forecast: 'worst',  split: 'moq',          validation: 3,    monitoring: '15j' },
}
export var FORECAST_LABELS = { best: 'Best case', middle: 'Middle', worst: 'Worst case' }
export var SPLIT_LABELS = { moq: 'MOQ (lot minimum)', multiple_moq: 'Multiple MOQ' }
export var MONITORING_LABELS = { '15j': 'Tous les 15 jours', mensuel: 'Mensuel', trimestriel: 'Trimestriel' }
export function decisionsFor(niveau) { return DECISION_MATRIX[niveau] || null }
export function needsValidation(niveau) { return niveau === 'moyen' || niveau === 'eleve' }
