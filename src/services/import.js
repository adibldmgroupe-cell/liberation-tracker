import ExcelJS from 'exceljs'
import { supabase } from '../supabase'

export async function importExcel(file, onProgress) {
  var workbook = new ExcelJS.Workbook()
  var buffer = await file.arrayBuffer()
  await workbook.xlsx.load(buffer)
  var sheet = workbook.worksheets[0]
  if (!sheet) return { created: 0, updated: 0, skipped: 0, errors: ['Aucun onglet trouvé'], type: 'unknown' }

  var headers = {}
  sheet.getRow(1).eachCell(function(cell, colNumber) {
    headers[norm(String(cell.value || ''))] = colNumber
  })

  if (headers['N_lot'] && headers['code_article']) return await importSAP(sheet, headers, onProgress)
  else if (findKey(headers, 'LOT')) return await importHistorique(sheet, headers, onProgress)
  else return { created: 0, updated: 0, skipped: 0, errors: ['Format non reconnu'], type: 'unknown' }
}

function norm(s) { return s.replace(/[\n\r]+/g, ' ').replace(/\s+/g, ' ').trim() }
function findKey(headers, keyword) { return Object.keys(headers).find(function(k) { return k.toUpperCase().includes(keyword) }) }

function makeGetVal(row, headers) {
  return function(col) {
    var normCol = norm(col)
    var c = headers[normCol]
    if (!c) {
      var found = Object.keys(headers).find(function(k) { return k.includes(normCol) || normCol.includes(k) })
      if (found) c = headers[found]
    }
    if (!c) {
      var words = normCol.split(' ').filter(function(w) { return w.length > 2 })
      var found2 = Object.keys(headers).find(function(k) { return words.every(function(w) { return k.toLowerCase().includes(w.toLowerCase()) }) })
      if (found2) c = headers[found2]
    }
    return c ? row.getCell(c).value : null
  }
}

// ══════════════ IMPORT SAP ══════════════
async function importSAP(sheet, headers, onProgress) {
  var stats = { created: 0, updated: 0, skipped: 0, errors: [], type: 'SAP' }
  var totalRows = sheet.rowCount - 1
  for (var i = 2; i <= sheet.rowCount; i++) {
    try { await processSAPRow(sheet.getRow(i), headers, stats) }
    catch (e) { stats.errors.push('Ligne ' + i + ': ' + e.message) }
    if (onProgress) onProgress(Math.round(((i - 1) / totalRows) * 100))
  }
  return stats
}

async function processSAPRow(row, headers, stats) {
  var getVal = makeGetVal(row, headers)
  var codeArticle = clean(getVal('code_article'))
  var numLot = clean(getVal('N_lot'))
  if (!codeArticle || !numLot) { stats.skipped++; return }

  var product = await upsertProduct(codeArticle, clean(getVal('description')) || codeArticle, getVal)
  var statutSap = mapStatut(clean(getVal('Statut_Lot')))
  var lotData = {
    numero_lot: numLot, product_id: product.id, num_document_sap: clean(getVal('Num_document')) || null,
    quantite: parseInt(getVal('quantite')) || 0, statut_sap: statutSap,
    date_enregistrement: parseDate(getVal('date_enregistrement')),
    date_declaration: parseDate(getVal('Date_Declaration')),
    date_liberation: parseDate(getVal('Date_liberation')),
    ddf: parseDate(getVal('DDF')), ddp: parseDate(getVal('DDP')),
    synced_from_excel_at: new Date().toISOString(),
  }

  var existing = await supabase.from('lots').select('id, statut_sap').eq('numero_lot', numLot).maybeSingle()
  if (existing.data) {
    await supabase.from('lots').update({
      quantite: lotData.quantite, statut_sap: lotData.statut_sap,
      date_enregistrement: lotData.date_enregistrement, date_declaration: lotData.date_declaration,
      date_liberation: lotData.date_liberation, ddf: lotData.ddf, ddp: lotData.ddp,
      synced_from_excel_at: lotData.synced_from_excel_at, updated_at: new Date().toISOString(),
    }).eq('id', existing.data.id)

    // Auto-correction OF/OC pour lots avec statut SAP
    if (statutSap !== 'vide') {
      await supabase.from('orders_of').update({ statut: 'termine', etape_circuit: 'production' }).eq('lot_id', existing.data.id)
      await supabase.from('orders_oc').update({ statut: 'termine', etape_circuit: 'production' }).eq('lot_id', existing.data.id)
    }
    stats.updated++
  } else {
    var newLot = await supabase.from('lots').insert(lotData).select('id').single()
    if (newLot.error) throw newLot.error
    await initLotDocuments(newLot.data.id)

    // OF/OC: terminé si lot a un statut SAP, sinon planifié
    if (statutSap !== 'vide') {
      await supabase.from('orders_of').update({ statut: 'termine', etape_circuit: 'production' }).eq('lot_id', newLot.data.id)
      await supabase.from('orders_oc').update({ statut: 'termine', etape_circuit: 'production' }).eq('lot_id', newLot.data.id)
    }
    stats.created++
  }
}

// ══════════════ IMPORT HISTORIQUE ══════════════
async function importHistorique(sheet, headers, onProgress) {
  var stats = { created: 0, updated: 0, skipped: 0, errors: [], type: 'Historique' }
  var totalRows = sheet.rowCount - 1
  var lotKey = findKey(headers, 'LOT')
  for (var i = 2; i <= sheet.rowCount; i++) {
    try { await processHistoriqueRow(sheet.getRow(i), headers, lotKey, stats) }
    catch (e) { stats.errors.push('Ligne ' + i + ': ' + e.message) }
    if (onProgress) onProgress(Math.round(((i - 1) / totalRows) * 100))
  }
  return stats
}

async function processHistoriqueRow(row, headers, lotKey, stats) {
  var getVal = makeGetVal(row, headers)
  var numLot = clean(row.getCell(headers[lotKey]).value)
  if (!numLot) { stats.skipped++; return }

  var now = new Date().toISOString()
  var isNew = false
  var lot = await supabase.from('lots').select('id').eq('numero_lot', numLot).maybeSingle()

  if (!lot.data) {
    var codeArticle = clean(getVal('Code SAP'))
    if (!codeArticle) { stats.skipped++; return }
    var description = clean(getVal('Description article'))
    var statut = mapStatut(clean(getVal('Statut') || ''))
    var product = await upsertProduct(codeArticle, description || codeArticle)
    var newLot = await supabase.from('lots').insert({
      numero_lot: numLot, product_id: product.id, statut_sap: statut,
      quantite: parseInt(getVal('Quantité entrée en stock')) || 0,
      date_enregistrement: parseDate(getVal('Date entrée Stock PF')),
      synced_from_excel_at: now,
    }).select('id').single()
    if (newLot.error) throw newLot.error
    lot = newLot
    await initLotDocuments(lot.data.id)
    isNew = true
  }

  var lotId = lot.data.id

  // Dates documents
  var dateIF = parseDate(getVal('DDL Fab'))
  var dateIC = parseDate(getVal('DDL condt'))
  var dateDAPC = parseDate(getVal('D.A Physico'))
  var dateDAMicro = parseDate(getVal('D.A Microbio'))
  var dateFinFab = parseDate(getVal('Date fin fab'))
  var dateFinCdt = parseDate(getVal('Date fin cdt'))
  var dateLib = parseDate(getVal('libération réelle'))

  // OF: terminé SEULEMENT si IF ou DA PC émis ou date fin fab
  if (dateIF || dateDAPC || dateFinFab) {
    await supabase.from('orders_of').update({ statut: 'termine', etape_circuit: 'production', updated_at: now }).eq('lot_id', lotId)
  }
  // OC: terminé SEULEMENT si IC émis ou date fin cdt
  if (dateIC || dateFinCdt) {
    await supabase.from('orders_oc').update({ statut: 'termine', etape_circuit: 'production', updated_at: now }).eq('lot_id', lotId)
  }

  // Documents
  if (dateIF) await updateDoc(lotId, 'if', dateIF)
  if (dateIC) await updateDoc(lotId, 'ic', dateIC)
  if (dateDAPC) await updateDoc(lotId, 'da_pc', dateDAPC)
  if (dateDAMicro && dateDAMicro !== '1970-01-01') {
    await supabase.from('liberation_documents').update({
      is_applicable: true, is_required: true, statut: 'emis', emitted_at: dateDAMicro + 'T00:00:00Z', updated_at: now
    }).eq('lot_id', lotId).eq('type_document', 'da_micro')
    await supabase.from('liberation_dossiers').update({ da_micro_applicable: true, updated_at: now }).eq('lot_id', lotId)
  }

  // AQL
  var dateDemandeAQL = parseDate(getVal('demande AQL'))
  var dateFinAQL = parseDate(getVal('Date fin AQL'))
  if (dateDemandeAQL || dateFinAQL) {
    var existingAql = await supabase.from('aql_inspections').select('id').eq('lot_id', lotId).eq('type', 'fabrication').maybeSingle()
    if (!existingAql.data) {
      await supabase.from('aql_inspections').insert({
        lot_id: lotId, type: 'fabrication',
        resultat: dateFinAQL ? 'conforme' : 'en_attente',
        requested_at: dateDemandeAQL ? dateDemandeAQL + 'T00:00:00Z' : null,
        inspected_at: dateFinAQL ? dateFinAQL + 'T00:00:00Z' : null,
      })
    }
  }

  // Déviation
  var deviation = getVal('DEVIATION')
  if (deviation && String(deviation).trim() !== '' && String(deviation).trim() !== '0') {
    var existingDev = await supabase.from('deviations').select('id').eq('lot_id', lotId).maybeSingle()
    if (!existingDev.data) {
      var user = await supabase.auth.getUser()
      await supabase.from('deviations').insert({
        lot_id: lotId, type: 'deviation', statut: 'ouverte', description: String(deviation).trim(),
        declared_by: user.data.user.id, declared_at: now,
      })
      await supabase.from('liberation_dossiers').update({ deviations_closed: false, updated_at: now }).eq('lot_id', lotId)
    }
  }

  // Libération
  if (dateLib) {
    await supabase.from('liberation_documents').update({
      statut: 'approuve_dt', approved_at: dateLib + 'T00:00:00Z', updated_at: now
    }).eq('lot_id', lotId).eq('is_applicable', true)
    var daMicro = await supabase.from('liberation_documents').select('is_applicable').eq('lot_id', lotId).eq('type_document', 'da_micro').maybeSingle()
    await supabase.from('liberation_dossiers').update({
      statut: 'libere', liberated_at: dateLib + 'T00:00:00Z',
      if_approved: true, ic_approved: true, da_pc_approved: true,
      da_micro_approved: daMicro.data && daMicro.data.is_applicable ? true : false,
      deviations_closed: true, pieces_complementaires_ok: true, updated_at: now,
    }).eq('lot_id', lotId)
  }

  if (isNew) stats.created++; else stats.updated++
}

// ══════════════ IMPORT GOOGLE SHEETS ══════════════

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
  // Note : la sync Google Sheets ne crée pas les documents/dossiers des nouveaux lots.
  // Utiliser l'import Excel pour initialiser complètement un nouveau lot.

  // ── 9. OF/OC : mise à jour batch pour lots avec statut SAP ───────────
  var idsAvecStatut = (upsertRes.data||[]).filter(function(l){ return l.statut_sap !== 'vide' }).map(function(l){ return l.id })
  if (idsAvecStatut.length) {
    await supabase.from('orders_of').update({ statut: 'termine', etape_circuit: 'production' }).in('lot_id', idsAvecStatut)
    await supabase.from('orders_oc').update({ statut: 'termine', etape_circuit: 'production' }).in('lot_id', idsAvecStatut)
  }
  if (onProgress) onProgress(100)

  return stats
}

// ══════════════ IMPORT HISTORIQUE depuis GOOGLE SHEETS (batch) ══════════════
// Source : feuille "Historique" publiée en CSV (mêmes colonnes que l'import Excel
// Historique). Particularité : 1re ligne = groupes de services → on détecte la vraie
// ligne d'en-têtes (celle contenant "N°LOT"). Optimisé en batch (upserts groupés).
// Prérequis migration : UNIQUE(lot_id,type_document) sur liberation_documents.
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
    lotRows.push({
      numero_lot: p.numLot, product_id: pid, statut_sap: p.statut,
      quantite: p.qte, date_enregistrement: p.dateEntree,
      date_liberation: p.dateLib || null, synced_from_excel_at: now, updated_at: now,
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

  // ── 7. Construire docs / dossiers / OF / OC / AQL / déviations ──
  var docRows = [], dossierRows = [], ofRows = [], ocRows = [], aqlCand = [], devCand = []
  var SVC = { if: 'fabrication', ic: 'conditionnement', da_pc: 'lcq', da_micro: 'lcq', ccl: 'aq' }
  parsed.forEach(function(p) {
    var lotId = lotIdMap[p.numLot]; if (!lotId) return
    var libere = !!p.dateLib
    var microApp = !!(p.dateDAMicro && p.dateDAMicro !== '1970-01-01')
    function doc(type, emittedDate, applicable) {
      var d = { lot_id: lotId, type_document: type, is_applicable: applicable, is_required: applicable, service_emetteur: SVC[type], statut: 'non_emis', emitted_at: null, approved_at: null, updated_at: now }
      if (emittedDate) { d.statut = 'emis'; d.emitted_at = emittedDate + 'T00:00:00Z' }
      if (libere && applicable) { d.statut = 'approuve_dt'; d.approved_at = p.dateLib + 'T00:00:00Z' }
      return d
    }
    docRows.push(doc('if', p.dateIF, true), doc('ic', p.dateIC, true), doc('da_pc', p.dateDAPC, true), doc('da_micro', microApp ? p.dateDAMicro : null, microApp), doc('ccl', null, true))

    var dossier = { lot_id: lotId, da_micro_applicable: microApp, updated_at: now }
    if (libere) {
      dossier.statut = 'libere'; dossier.liberated_at = p.dateLib + 'T00:00:00Z'
      dossier.if_approved = true; dossier.ic_approved = true; dossier.da_pc_approved = true
      dossier.da_micro_approved = microApp; dossier.deviations_closed = true; dossier.pieces_complementaires_ok = true
    } else if (p.deviation && p.deviation !== '0') { dossier.deviations_closed = false }
    dossierRows.push(dossier)

    var ofT = !!(p.dateIF || p.dateDAPC || p.dateFinFab)
    ofRows.push({ lot_id: lotId, statut: ofT ? 'termine' : 'planifie', etape_circuit: ofT ? 'production' : 'planification', updated_at: now })
    var ocT = !!(p.dateIC || p.dateFinCdt)
    ocRows.push({ lot_id: lotId, statut: ocT ? 'termine' : 'planifie', etape_circuit: ocT ? 'production' : 'planification', updated_at: now })

    if (p.demandeAQL || p.finAQL) aqlCand.push({ lotId: lotId, demandeAQL: p.demandeAQL, finAQL: p.finAQL })
    if (p.deviation && p.deviation !== '0') devCand.push({ lotId: lotId, description: p.deviation })
  })

  // ── 8. Upsert docs / dossiers / OF / OC (batch) ──
  for (var dc of chunk(docRows, 500)) {
    var rD = await supabase.from('liberation_documents').upsert(dc, { onConflict: 'lot_id,type_document' })
    if (rD.error) stats.errors.push('Documents : ' + rD.error.message + ' — exécuter la migration UNIQUE(lot_id,type_document)')
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
export async function viderDonneesOperationnelles(onProgress) {
  var stats = { errors: [] }
  var P = function(n) { if (onProgress) onProgress(n) }
  P(10)
  var n1 = await supabase.from('notifications').delete().gt('id', 0)
  if (n1.error) stats.errors.push('notifications : ' + n1.error.message + ' — policy DELETE requise')
  P(35)
  var n2 = await supabase.from('order_validations').delete().gt('id', 0)
  if (n2.error) stats.errors.push('order_validations : ' + n2.error.message + ' — policy DELETE requise')
  P(60)
  // lots en dernier → cascade OF/OC, documents, mouvements, AQL, déviations, dossiers, events, étapes fab
  var n3 = await supabase.from('lots').delete().gt('id', 0)
  if (n3.error) stats.errors.push('lots : ' + n3.error.message)
  P(100)
  return stats
}

// ══════════════ HELPERS ══════════════
async function upsertProduct(code, description, getVal) {
  var existing = await supabase.from('products').select('id').eq('code_article', code).maybeSingle()
  if (existing.data) return existing.data
  var ins = { code_article: code, description: description, is_semi_solide: isSemiSolide(description) }
  if (getVal) {
    ins.prix_vente = parseNum(getVal('prix_vente'))
    ins.ppa = parseNum(getVal('PPA'))
    ins.quantite_par_colis = parseInt(getVal('quantite_par_colis')) || 0
    ins.shp = parseNum(getVal('SHP'))
  }
  var res = await supabase.from('products').insert(ins).select('id').single()
  if (res.error) throw res.error
  return res.data
}

async function initLotDocuments(lotId) {
  await supabase.from('liberation_documents').insert([
    { lot_id: lotId, type_document: 'if', is_applicable: true, is_required: true, service_emetteur: 'fabrication' },
    { lot_id: lotId, type_document: 'ic', is_applicable: true, is_required: true, service_emetteur: 'conditionnement' },
    { lot_id: lotId, type_document: 'da_pc', is_applicable: true, is_required: true, service_emetteur: 'lcq' },
    { lot_id: lotId, type_document: 'da_micro', is_applicable: false, is_required: false, service_emetteur: 'lcq' },
    { lot_id: lotId, type_document: 'ccl', is_applicable: true, is_required: true, service_emetteur: 'aq' },
  ])
  await supabase.from('liberation_dossiers').insert({ lot_id: lotId, da_micro_applicable: false })
  await supabase.from('orders_of').insert({ lot_id: lotId, statut: 'planifie', etape_circuit: 'planification' })
  await supabase.from('orders_oc').insert({ lot_id: lotId, statut: 'planifie', etape_circuit: 'planification' })
}

// Version sécurisée pour Google Sheets : ignore les doublons silencieusement
async function initLotDocumentsSafe(lotId) {
  await supabase.from('liberation_documents').upsert([
    { lot_id: lotId, type_document: 'if', is_applicable: true, is_required: true, service_emetteur: 'fabrication' },
    { lot_id: lotId, type_document: 'ic', is_applicable: true, is_required: true, service_emetteur: 'conditionnement' },
    { lot_id: lotId, type_document: 'da_pc', is_applicable: true, is_required: true, service_emetteur: 'lcq' },
    { lot_id: lotId, type_document: 'da_micro', is_applicable: false, is_required: false, service_emetteur: 'lcq' },
    { lot_id: lotId, type_document: 'ccl', is_applicable: true, is_required: true, service_emetteur: 'aq' },
  ], { onConflict: 'lot_id,type_document', ignoreDuplicates: true })
  await supabase.from('liberation_dossiers').upsert({ lot_id: lotId, da_micro_applicable: false }, { onConflict: 'lot_id', ignoreDuplicates: true })
  await supabase.from('orders_of').upsert({ lot_id: lotId, statut: 'planifie', etape_circuit: 'planification' }, { onConflict: 'lot_id', ignoreDuplicates: true })
  await supabase.from('orders_oc').upsert({ lot_id: lotId, statut: 'planifie', etape_circuit: 'planification' }, { onConflict: 'lot_id', ignoreDuplicates: true })
}

async function updateDoc(lotId, type, date) {
  await supabase.from('liberation_documents').update({
    statut: 'emis', emitted_at: date + 'T00:00:00Z', updated_at: new Date().toISOString()
  }).eq('lot_id', lotId).eq('type_document', type)
}

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
  var l = raw.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'')
  if (l.includes('accepte')) return 'accepte'; if (l.includes('quarantaine')) return 'quarantaine'
  if (l.includes('investigation')) return 'sous_investigation'; if (l.includes('refuse')) return 'refuse'
  return 'vide'
}
function isSemiSolide(desc) { var l = desc.toLowerCase(); return ['crème','creme','pommade','gel ','onguent','pâte','pate'].some(function(k){return l.includes(k)}) }
