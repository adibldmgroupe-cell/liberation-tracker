import { supabase } from '../supabase'

function norm(s) { return s.replace(/[\n\r]+/g, ' ').replace(/\s+/g, ' ').trim() }

// ══════════════ IMPORT RÉCEPTION PF (SAP) depuis GOOGLE SHEETS ══════════════

function parseCSV(text) {
  var lines = []; var row = []; var field = ''; var inQuote = false
  for (var i = 0; i < text.length; i++) {
    var c = text[i]
    if (inQuote) {
      if (c === '"') {
        if (i+1 < text.length && text[i+1] === '"') { field += '"'; i++ }
        else inQuote = false
      } else field += c
    } else {
      if (c === '"') inQuote = true
      else if (c === ',') { row.push(field.trim()); field = '' }
      else if (c === '\n') {
        row.push(field.trim()); field = ''
        if (row.some(function(f){ return f !== '' })) lines.push(row)
        row = []
      } else if (c !== '\r') field += c
    }
  }
  row.push(field.trim())
  if (row.some(function(f){ return f !== '' })) lines.push(row)
  return lines
}

function parseQuantite(val) {
  if (!val) return 0
  var s = String(val).replace(/\s/g, '').replace(',', '.')
  var n = parseFloat(s)
  return isNaN(n) ? 0 : Math.round(n)
}

function makeCsvGetVal(row, headers) {
  return function(col) {
    var normCol = norm(col)
    var idx = headers[normCol]
    if (idx === undefined) {
      var found = Object.keys(headers).find(function(k) { return k.includes(normCol) || normCol.includes(k) })
      if (found !== undefined) idx = headers[found]
    }
    return idx !== undefined ? (row[idx] || '') : ''
  }
}

export async function importFromGoogleSheets(url, onProgress) {
  var stats = { created: 0, updated: 0, skipped: 0, errors: [], type: 'Google Sheets' }
  if (onProgress) onProgress(5)

  // ── 1. Fetch CSV ──────────────────────────────────────────────────────
  var text
  try {
    var fetchRes = await fetch(url)
    if (!fetchRes.ok) throw new Error('HTTP ' + fetchRes.status)
    text = await fetchRes.text()
  } catch(e) {
    return Object.assign(stats, { errors: ['Impossible de lire l\'URL Google Sheets : ' + e.message] })
  }
  if (onProgress) onProgress(15)

  // ── 2. Parse CSV ──────────────────────────────────────────────────────
  var rows = parseCSV(text)
  if (!rows.length) return Object.assign(stats, { errors: ['Fichier vide'] })
  var headers = {}
  rows[0].forEach(function(h, i) { headers[norm(h)] = i })
  var dataRows = rows.slice(1)

  // ── 3. Extraire + fusionner les mouvements SAP par numero_lot ────────────
  // Règles de fusion :
  //   quantite          → somme de toutes les lignes
  //   date_enregistrement, date_declaration → la plus ancienne
  //   date_liberation   → la plus récente
  //   num_document_sap  → le premier (document le plus ancien)
  //   statut, DDF, DDP, prix, PPA, qte_colis, SHP → dernière ligne
  var parsedMap = {}
  dataRows.forEach(function(row) {
    var getVal = makeCsvGetVal(row, headers)
    var codeArticle = clean(getVal('code_article'))
    var numLot = clean(getVal('N_lot'))
    if (!codeArticle || !numLot) { stats.skipped++; return }

    var dateEnr  = parseDate(getVal('date_enregistrement'))
    var dateDecl = parseDate(getVal('Date_Declaration'))
    var dateLib  = parseDate(getVal('Date_liberation'))
    var qte      = parseQuantite(getVal('quantite'))

    if (parsedMap[numLot]) {
      var ex = parsedMap[numLot]
      // Somme des quantités (mouvements SAP)
      ex.quantite += qte
      // Date enregistrement : la plus ancienne
      if (dateEnr  && (!ex.dateEnr  || dateEnr  < ex.dateEnr))  ex.dateEnr  = dateEnr
      // Date déclaration : la plus ancienne
      if (dateDecl && (!ex.dateDecl || dateDecl < ex.dateDecl)) ex.dateDecl = dateDecl
      // Date libération : la plus récente
      if (dateLib  && (!ex.dateLib  || dateLib  > ex.dateLib))  ex.dateLib  = dateLib
      // num_document_sap : on garde le premier (ne pas écraser)
      // Autres champs : valeurs de la ligne courante (plus récente)
      ex.statutSap = mapStatut(clean(getVal('Statut_Lot')))
      ex.ddf       = parseDate(getVal('DDF'))
      ex.ddp       = parseDate(getVal('DDP'))
      ex.prixVente = parseNum(getVal('prix_vente'))
      ex.ppa       = parseNum(getVal('PPA'))
      ex.qteColis  = parseInt(clean(getVal('quantite_par_colis'))) || null
      ex.shp       = parseNum(getVal('SHP'))
    } else {
      parsedMap[numLot] = {
        codeArticle: codeArticle, numLot: numLot,
        description: clean(getVal('description')) || codeArticle,
        numDocSap:   clean(getVal('Num_document')) || null,
        quantite:    qte,
        statutSap:   mapStatut(clean(getVal('Statut_Lot'))),
        dateEnr: dateEnr, dateDecl: dateDecl, dateLib: dateLib,
        ddf: parseDate(getVal('DDF')), ddp: parseDate(getVal('DDP')),
        prixVente: parseNum(getVal('prix_vente')),
        ppa:       parseNum(getVal('PPA')),
        qteColis:  parseInt(clean(getVal('quantite_par_colis'))) || null,
        shp:       parseNum(getVal('SHP')),
      }
    }
  })
  var parsed = Object.values(parsedMap)
  if (onProgress) onProgress(25)

  // ── 4. Produits : 1 requête pour tous ────────────────────────────────
  var allCodes = parsed.map(function(p){ return p.codeArticle }).filter(function(c,i,a){ return a.indexOf(c)===i })
  var existingProdsRes = await supabase.from('products').select('id,code_article').in('code_article', allCodes)
  var prodMap = {}
  ;(existingProdsRes.data||[]).forEach(function(p){ prodMap[p.code_article] = p.id })

  // Insérer les produits manquants en 1 batch
  var newProdsData = allCodes.filter(function(c){ return !prodMap[c] }).map(function(c) {
    var item = parsed.find(function(p){ return p.codeArticle === c })
    return { code_article: c, description: item.description, is_semi_solide: isSemiSolide(item.description) }
  })
  if (newProdsData.length) {
    var insProdsRes = await supabase.from('products').insert(newProdsData).select('id,code_article')
    ;(insProdsRes.data||[]).forEach(function(p){ prodMap[p.code_article] = p.id })
    if (insProdsRes.error) stats.errors.push('Produits : ' + insProdsRes.error.message)
  }
  if (onProgress) onProgress(40)

  // ── 5. Lots : 1 requête pour tous ────────────────────────────────────
  var allNumLots = parsed.map(function(p){ return p.numLot })
  var existingLotsRes = await supabase.from('lots').select('id,numero_lot,statut_sap').in('numero_lot', allNumLots)
  var lotMap = {}
  ;(existingLotsRes.data||[]).forEach(function(l){ lotMap[l.numero_lot] = l })
  if (onProgress) onProgress(50)

  var now = new Date().toISOString()

  // ── 6. Upsert unique pour tous les lots (nouveaux + existants) ────────
  var allLotData = []
  parsed.forEach(function(p) {
    var productId = prodMap[p.codeArticle]
    if (!productId) { stats.errors.push('Produit introuvable : ' + p.codeArticle); return }
    allLotData.push({
      numero_lot: p.numLot, product_id: productId,
      num_document_sap: p.numDocSap,
      quantite: p.quantite, statut_sap: p.statutSap,
      date_enregistrement: p.dateEnr, date_declaration: p.dateDecl,
      date_liberation: p.dateLib, ddf: p.ddf, ddp: p.ddp,
      prix_vente: p.prixVente, ppa: p.ppa,
      quantite_par_colis: p.qteColis, shp: p.shp,
      synced_from_excel_at: now, updated_at: now,
    })
  })
  if (onProgress) onProgress(65)

  var upsertRes = await supabase.from('lots').upsert(allLotData, { onConflict: 'numero_lot' }).select('id,numero_lot,statut_sap')
  if (upsertRes.error) {
    stats.errors.push('Sync lots : ' + upsertRes.error.message)
    return stats
  }
  if (onProgress) onProgress(75)

  // Distinguer créés vs mis à jour via lotMap
  var newLotRows = []
  ;(upsertRes.data||[]).forEach(function(l) {
    if (lotMap[l.numero_lot]) { stats.updated++ }
    else { newLotRows.push(l); stats.created++ }
  })
  if (onProgress) onProgress(85)
  // Note : la sync Réception PF ne crée pas les documents/dossiers des nouveaux lots.
  // L'import Historique (ci-dessous) initialise complètement chaque lot.

  // ── 7. OF/OC : mise à jour batch pour lots avec statut SAP ───────────
  var idsAvecStatut = (upsertRes.data||[]).filter(function(l){ return l.statut_sap !== 'vide' }).map(function(l){ return l.id })
  if (idsAvecStatut.length) {
    await supabase.from('orders_of').update({ statut: 'termine', etape_circuit: 'production' }).in('lot_id', idsAvecStatut)
    await supabase.from('orders_oc').update({ statut: 'termine', etape_circuit: 'production' }).in('lot_id', idsAvecStatut)
  }
  if (onProgress) onProgress(100)

  return stats
}

// ══════════════ IMPORT HISTORIQUE depuis GOOGLE SHEETS (batch) ══════════════
// Source : feuille "Historique" publiée en CSV (mêmes colonnes que l'ancien import Excel
// Historique). Particularité : 1re ligne = groupes de services → on détecte la vraie
// ligne d'en-têtes (celle contenant "N°LOT"). Optimisé en batch (upserts groupés).
// Prérequis migration : UNIQUE(lot_id,type_document,service_emetteur) sur liberation_documents (migration 039).
function chunk(arr, size) { var out = []; for (var i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size)); return out }

export async function importHistoriqueDepuisGoogleSheets(url, onProgress) {
  var stats = { created: 0, updated: 0, skipped: 0, errors: [], type: 'Historique GS' }
  var P = function(n) { if (onProgress) onProgress(n) }
  P(3)

  // ── 1. Fetch CSV ──
  var text
  try {
    var res = await fetch(url)
    if (!res.ok) throw new Error('HTTP ' + res.status)
    text = await res.text()
  } catch (e) { return Object.assign(stats, { errors: ['Lecture URL impossible : ' + e.message] }) }
  P(10)

  // ── 2. Parse + détection ligne d'en-têtes (saute la ligne de groupes) ──
  var rows = parseCSV(text)
  if (!rows.length) return Object.assign(stats, { errors: ['Fichier vide'] })
  var headerIdx = rows.findIndex(function(r) { return r.some(function(c) { return norm(c).toUpperCase().indexOf('LOT') !== -1 }) })
  if (headerIdx === -1) return Object.assign(stats, { errors: ['En-têtes introuvables (colonne N°LOT absente)'] })
  var headers = {}
  rows[headerIdx].forEach(function(h, i) { headers[norm(h)] = i })
  var dataRows = rows.slice(headerIdx + 1)
  P(15)

  // ── 3. Parser les lignes → objets (dédup par numero_lot) ──
  var map = {}
  dataRows.forEach(function(row) {
    var g = makeCsvGetVal(row, headers)
    var numLot = clean(g('N°LOT')) || clean(g('LOT'))
    var codeArticle = clean(g('Code SAP'))
    if (!numLot || !codeArticle) { stats.skipped++; return }
    map[numLot] = {
      numLot: numLot, codeArticle: codeArticle,
      description: clean(g('Description article')) || codeArticle,
      statut: mapStatut(clean(g('Statut')) || ''),
      qte: parseQuantite(g('Quantité entrée en stock')),
      dateEntree: parseDate(g('Date entrée Stock PF')),
      dateIF: parseDate(g('DDL Fab')), dateIC: parseDate(g('DDL condt')),
      dateDAPC: parseDate(g('D.A Physico')), dateDAMicro: parseDate(g('D.A Microbio')),
      demandeAQL: parseDate(g('demande AQL')), finAQL: parseDate(g('Date fin AQL')),
      deviation: clean(g('DEVIATION')), dateLib: parseDate(g('libération réelle')),
      dateFinFab: parseDate(g('Date fin fab')), dateFinCdt: parseDate(g('Date fin cdt')),
      // Dates prévisionnelles de libération (estimations GS) → lot_planning (cibles).
      // "à définir"/vide → parseDate renvoie null (non importé).
      estCQ: parseDate(g('Estimation CQ (Dossier Analytique)')),    // → date_lcq_cible (LIB. LCQ)
      estAQ: parseDate(g('Estimation AQ (CCL)')),                   // → date_aq_cible  (LIB. AQ)
      estDT: parseDate(g('Estimation DT (Libération à la vente)')), // → date_dt_cible  (LIB. DT)
    }
  })
  var parsed = Object.values(map)
  if (!parsed.length) return Object.assign(stats, { errors: ['Aucune ligne valide (N°LOT + Code SAP requis)'] })
  P(25)

  // ── 4. Produits (batch) ──
  var codes = parsed.map(function(p) { return p.codeArticle }).filter(function(c, i, a) { return a.indexOf(c) === i })
  var prodMap = {}
  for (var ccodes of chunk(codes, 800)) {
    var exProds = await supabase.from('products').select('id,code_article').in('code_article', ccodes)
    ;(exProds.data || []).forEach(function(p) { prodMap[p.code_article] = p.id })
  }
  var newProds = codes.filter(function(c) { return !prodMap[c] }).map(function(c) {
    var it = parsed.find(function(p) { return p.codeArticle === c })
    return { code_article: c, description: it.description, is_semi_solide: isSemiSolide(it.description) }
  })
  for (var pc of chunk(newProds, 500)) {
    var insP = await supabase.from('products').insert(pc).select('id,code_article')
    if (insP.error) stats.errors.push('Produits : ' + insP.error.message)
    ;(insP.data || []).forEach(function(p) { prodMap[p.code_article] = p.id })
  }
  P(40)

  // ── 5. Lots existants (distinguer créés/màj) ──
  var numLots = parsed.map(function(p) { return p.numLot })
  var existing = {}
  for (var nc of chunk(numLots, 800)) {
    var ex = await supabase.from('lots').select('numero_lot').in('numero_lot', nc)
    ;(ex.data || []).forEach(function(l) { existing[l.numero_lot] = true })
  }
  var now = new Date().toISOString()

  // ── 6. Upsert lots (batch, onConflict numero_lot comme la sync SAP) ──
  var lotRows = []
  parsed.forEach(function(p) {
    var pid = prodMap[p.codeArticle]
    if (!pid) { stats.errors.push('Produit introuvable : ' + p.codeArticle); return }
    // statut_sap, date_liberation, date_enregistrement (= date d'entrée stock) sont
    // propriété de la Réception SAP → ne pas les écrire ici (sinon l'Historique
    // écraserait la donnée SAP). On n'apporte que les dates d'émission documentaires.
    lotRows.push({
      numero_lot: p.numLot, product_id: pid,
      quantite: p.qte, synced_from_excel_at: now, updated_at: now,
    })
  })
  var lotIdMap = {}
  for (var lc of chunk(lotRows, 500)) {
    var up = await supabase.from('lots').upsert(lc, { onConflict: 'numero_lot' }).select('id,numero_lot')
    if (up.error) return Object.assign(stats, { errors: ['Lots : ' + up.error.message] })
    ;(up.data || []).forEach(function(l) { lotIdMap[l.numero_lot] = l.id })
  }
  parsed.forEach(function(p) { if (existing[p.numLot]) stats.updated++; else stats.created++ })
  P(60)

  // ── 7. Construire docs / dossiers / OF / OC / AQL / déviations / planning ──
  var docRows = [], dossierRows = [], ofRows = [], ocRows = [], aqlCand = [], devCand = [], planCand = []
  var SVC = { if: 'fabrication', ic: 'conditionnement', da_pc: 'lcq', da_micro: 'lcq', ccl: 'aq' }
  parsed.forEach(function(p) {
    var lotId = lotIdMap[p.numLot]; if (!lotId) return
    var libere = !!p.dateLib || p.statut === 'accepte'
    var microApp = !!(p.dateDAMicro && p.dateDAMicro !== '1970-01-01')
    // Les dates IF/IC/DA PC/DA Micro de l'Historique sont des dates d'ÉMISSION par le
    // service émetteur (→ emitted_at), PAS des dates d'approbation DT.
    //  • Lot libéré        → document à l'état terminal "approuvé DT" (flux complété, aucune tâche).
    //  • Lot non libéré    → document "émis" à sa date d'émission : il suit le flux normal
    //                        (vérification AQ si le lot est en quarantaine côté SAP).
    //  • Pas de date / N/A → "non émis".
    // Le statut SAP, la date de libération et la date d'entrée stock viennent de la
    // Réception SAP (importFromGoogleSheets), jamais d'ici.
    function doc(type, emittedDate, applicable) {
      var d = { lot_id: lotId, type_document: type, is_applicable: applicable, is_required: applicable, service_emetteur: SVC[type], statut: 'non_emis', emitted_at: null, approved_at: null, updated_at: now }
      if (emittedDate) d.emitted_at = emittedDate + 'T00:00:00Z'
      if (applicable) {
        if (libere) { d.statut = 'approuve_dt'; if (p.dateLib) d.approved_at = p.dateLib + 'T00:00:00Z' }
        else if (emittedDate) { d.statut = 'emis' }
      }
      return d
    }
    docRows.push(doc('if', p.dateIF, true), doc('ic', p.dateIC, true), doc('da_pc', p.dateDAPC, true), doc('da_micro', microApp ? p.dateDAMicro : null, microApp), doc('ccl', null, true))

    var dossier = { lot_id: lotId, da_micro_applicable: microApp, updated_at: now }
    if (libere) {
      dossier.statut = 'libere'; if (p.dateLib) dossier.liberated_at = p.dateLib + 'T00:00:00Z'
      dossier.if_approved = true; dossier.ic_approved = true; dossier.da_pc_approved = true
      dossier.da_micro_approved = microApp; dossier.deviations_closed = true; dossier.pieces_complementaires_ok = true
    } else if (p.deviation && p.deviation !== '0') { dossier.deviations_closed = false }
    dossierRows.push(dossier)

    var ofT = !!(p.dateIF || p.dateDAPC || p.dateFinFab)
    var ocT = !!(p.dateIC || p.dateFinCdt)
    // Cohérence : on ne peut pas conditionner sans avoir fabriqué → OC terminé ⟹ OF terminé.
    if (ocT) ofT = true
    ofRows.push({ lot_id: lotId, statut: ofT ? 'termine' : 'planifie', etape_circuit: ofT ? 'production' : 'planification', updated_at: now })
    ocRows.push({ lot_id: lotId, statut: ocT ? 'termine' : 'planifie', etape_circuit: ocT ? 'production' : 'planification', updated_at: now })

    if (p.demandeAQL || p.finAQL) aqlCand.push({ lotId: lotId, demandeAQL: p.demandeAQL, finAQL: p.finAQL })
    if (p.deviation && p.deviation !== '0') devCand.push({ lotId: lotId, description: p.deviation })
    if (p.estCQ || p.estAQ || p.estDT) planCand.push({ lotId: lotId, estCQ: p.estCQ, estAQ: p.estAQ, estDT: p.estDT })
  })

  // ── 8. Upsert docs / dossiers / OF / OC (batch) ──
  for (var dc of chunk(docRows, 500)) {
    var rD = await supabase.from('liberation_documents').upsert(dc, { onConflict: 'lot_id,type_document,service_emetteur' })
    if (rD.error) stats.errors.push('Documents : ' + rD.error.message + ' — exécuter la migration 039 (UNIQUE lot_id,type_document,service_emetteur)')
  }
  for (var dsc of chunk(dossierRows, 500)) {
    var rDs = await supabase.from('liberation_dossiers').upsert(dsc, { onConflict: 'lot_id' })
    if (rDs.error) stats.errors.push('Dossiers : ' + rDs.error.message)
  }
  for (var ofc of chunk(ofRows, 500)) {
    var rOf = await supabase.from('orders_of').upsert(ofc, { onConflict: 'lot_id' })
    if (rOf.error) stats.errors.push('OF : ' + rOf.error.message)
  }
  for (var occ of chunk(ocRows, 500)) {
    var rOc = await supabase.from('orders_oc').upsert(occ, { onConflict: 'lot_id' })
    if (rOc.error) stats.errors.push('OC : ' + rOc.error.message)
  }

  // ── 8b. Planning prévisionnel (estimations CQ/AQ/DT → cibles lot_planning) ──
  // Fusion : le GS gagne quand la date est valide ; sinon on PRÉSERVE l'existant
  // (une estimation "à définir" n'écrase pas une date déjà saisie). onConflict lot_id.
  if (planCand.length) {
    var existPlan = {}
    var planLotIds = planCand.map(function(c){ return c.lotId }).filter(Boolean)
    for (var plf of chunk(planLotIds, 800)) {
      var ePl = await supabase.from('lot_planning').select('lot_id,date_lcq_cible,date_aq_cible,date_dt_cible').in('lot_id', plf)
      ;(ePl.data || []).forEach(function(x){ existPlan[x.lot_id] = x })
    }
    var planRows = planCand.map(function(c){
      var ex = existPlan[c.lotId] || {}
      return {
        lot_id: c.lotId,
        date_lcq_cible: c.estCQ || ex.date_lcq_cible || null,
        date_aq_cible:  c.estAQ || ex.date_aq_cible  || null,
        date_dt_cible:  c.estDT || ex.date_dt_cible  || null,
        updated_at: now,
      }
    })
    for (var plc of chunk(planRows, 500)) {
      var rPl = await supabase.from('lot_planning').upsert(plc, { onConflict: 'lot_id' })
      if (rPl.error) stats.errors.push('Planning : ' + rPl.error.message)
    }
  }
  P(80)

  // ── 9. AQL : insérer les manquants (pas de contrainte unique → select existants) ──
  if (aqlCand.length) {
    var exAql = {}
    for (var alc of chunk(aqlCand.map(function(a) { return a.lotId }), 800)) {
      var ea = await supabase.from('aql_inspections').select('lot_id').in('lot_id', alc).eq('type', 'fabrication')
      ;(ea.data || []).forEach(function(x) { exAql[x.lot_id] = true })
    }
    var aqlRows = aqlCand.filter(function(a) { return !exAql[a.lotId] }).map(function(a) {
      return { lot_id: a.lotId, type: 'fabrication', resultat: a.finAQL ? 'conforme' : 'en_attente', requested_at: a.demandeAQL ? a.demandeAQL + 'T00:00:00Z' : null, inspected_at: a.finAQL ? a.finAQL + 'T00:00:00Z' : null }
    })
    for (var aqc of chunk(aqlRows, 500)) {
      var rA = await supabase.from('aql_inspections').insert(aqc)
      if (rA.error) stats.errors.push('AQL : ' + rA.error.message)
    }
  }
  P(90)

  // ── 10. Déviations : insérer les manquantes ──
  if (devCand.length) {
    var u = await supabase.auth.getUser()
    var uid = u.data.user ? u.data.user.id : null
    var exDev = {}
    for (var dlc of chunk(devCand.map(function(d) { return d.lotId }), 800)) {
      var ed = await supabase.from('deviations').select('lot_id').in('lot_id', dlc)
      ;(ed.data || []).forEach(function(x) { exDev[x.lot_id] = true })
    }
    var devRows = devCand.filter(function(d) { return !exDev[d.lotId] }).map(function(d) {
      return { lot_id: d.lotId, type: 'deviation', statut: 'ouverte', description: d.description, declared_by: uid, declared_at: now }
    })
    for (var dvc of chunk(devRows, 500)) {
      var rDv = await supabase.from('deviations').insert(dvc)
      if (rDv.error) stats.errors.push('Déviations : ' + rDv.error.message)
    }
  }
  P(100)
  return stats
}

// ══════════════ VIDAGE COMPLET (reset opérationnel) ══════════════
// Efface tous les lots et leur cycle de vie (SAP + Historique + saisie manuelle).
// Conserve le référentiel : produits, profils, permissions, config, ateliers.
// notifications + order_validations n'ont pas de FK cascade → suppression explicite
// (nécessite policies DELETE — voir migration).
// ── Volet « Gestion lots » : vide les lots + tout leur dossier (cascade) ──
export async function viderDonneesOperationnelles(onProgress) {
  var stats = { errors: [] }
  var P = function(n) { if (onProgress) onProgress(n) }
  P(10)
  var n1 = await supabase.from('notifications').delete().gt('id', 0)
  if (n1.error) stats.errors.push('notifications : ' + n1.error.message + ' — policy DELETE requise')
  P(25)
  var n2 = await supabase.from('order_validations').delete().gt('id', 0)
  if (n2.error) stats.errors.push('order_validations : ' + n2.error.message + ' — policy DELETE requise')
  P(40)
  // arrêts rattachés au lot : arret_conditionnement (FK NO ACTION → bloquerait le DELETE lots) + atelier_arrets (FK SET NULL → orphelins) → supprimer avant lots
  var a1 = await supabase.from('arret_conditionnement').delete().not('id', 'is', null)
  if (a1.error) stats.errors.push('arret_conditionnement : ' + a1.error.message)
  var a2 = await supabase.from('atelier_arrets').delete().not('id', 'is', null)
  if (a2.error) stats.errors.push('atelier_arrets : ' + a2.error.message)
  P(60)
  // lots en dernier → cascade OF/OC, documents, mouvements, AQL, déviations, dossiers, events, planning, planif_cond, production_sessions, suivi_fab, suivi_cond
  var n3 = await supabase.from('lots').delete().gt('id', 0)
  if (n3.error) stats.errors.push('lots : ' + n3.error.message)
  P(100)
  return stats
}

// ── Volet « Module production » : vide l'OPÉRATIONNEL (référentiel + lots conservés) ──
export async function viderDonneesProduction(onProgress) {
  var stats = { errors: [] }
  var P = function(n) { if (onProgress) onProgress(n) }
  var DEL = function(t) { return supabase.from(t).delete().not('id', 'is', null) }
  // enfants → parents pour éviter tout blocage FK ; référentiel (cadences, ateliers, équipements, plan_rooms, operations_master, product_flux) NON touché
  var steps = [
    ['production_arrets', 12], ['production_comptages', 24], ['session_cadences', 36],
    ['production_sessions', 50], ['arret_conditionnement', 63], ['atelier_arrets', 76],
    ['suivi_conditionnement', 88], ['suivi_fabrication', 100]
  ]
  for (var i = 0; i < steps.length; i++) {
    var r = await DEL(steps[i][0])
    if (r.error) stats.errors.push(steps[i][0] + ' : ' + r.error.message + ' — policy DELETE requise ?')
    P(steps[i][1])
  }
  return stats
}

// ── Volet « Risque péremption » : vide les évaluations (config pondérations/seuils conservée) ──
export async function viderDonneesPeremption(onProgress) {
  var stats = { errors: [] }
  if (onProgress) onProgress(25)
  var r = await supabase.from('peremption_evaluations').delete().not('id', 'is', null)
  if (r.error) stats.errors.push('peremption_evaluations : ' + r.error.message + ' — policy DELETE requise ?')
  if (onProgress) onProgress(100)
  return stats
}

// ══════════════ HELPERS ══════════════
function clean(val) { return val == null ? '' : String(val).trim() }
function parseNum(val) { if (val == null) return 0; var n = parseFloat(String(val).replace(',','.')); return isNaN(n) ? 0 : n }
function parseDate(val) {
  if (!val) return null
  if (val instanceof Date) { if (isNaN(val.getTime())) return null; return val.getFullYear()+'-'+String(val.getMonth()+1).padStart(2,'0')+'-'+String(val.getDate()).padStart(2,'0') }
  var s = String(val).trim(); if (!s || s === '0') return null
  var dmy = s.match(/^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4})$/); if (dmy) return dmy[3]+'-'+dmy[2].padStart(2,'0')+'-'+dmy[1].padStart(2,'0')
  var ymd = s.match(/^(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})$/); if (ymd) return ymd[1]+'-'+ymd[2].padStart(2,'0')+'-'+ymd[3].padStart(2,'0')
  var num = parseFloat(s); if (!isNaN(num) && num > 40000 && num < 60000) return new Date((num-25569)*86400000).toISOString().split('T')[0]
  return null
}
function mapStatut(raw) {
  var l = (raw || '').toLowerCase()
  if (l.indexOf('accept') !== -1) return 'accepte'
  if (l.indexOf('quarantaine') !== -1) return 'quarantaine'
  if (l.indexOf('investigation') !== -1) return 'sous_investigation'
  if (l.indexOf('refus') !== -1) return 'refuse'
  return 'vide'
}
function isSemiSolide(desc) { var l = desc.toLowerCase(); return ['crème','creme','pommade','gel ','onguent','pâte','pate'].some(function(k){return l.includes(k)}) }
