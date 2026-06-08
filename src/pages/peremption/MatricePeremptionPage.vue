<template>
  <div class="mp" @click="closeMenus">
    <!-- En-tête -->
    <div class="fa-header">
      <div>
        <div class="fa-title">⚠️ Matrice des risques de péremption</div>
        <div class="fa-sub">{{ products.length }} produit(s) · {{ evaluatedCount }} évalué(s) · {{ products.length - evaluatedCount }} à évaluer</div>
      </div>
      <div class="fa-actions">
        <button class="mp-btn" :class="{'mp-btn-on': showColPanel}" @click.stop="showColPanel = !showColPanel">⚙ Colonnes</button>
        <button class="mp-btn" @click.stop="doExport('excel')">📥 Excel</button>
        <button class="mp-btn" @click.stop="doExport('pdf')">📄 PDF</button>
        <button v-if="canConfig" class="mp-btn-cfg" @click.stop="openConfig">⚙ Pondérations &amp; seuils</button>
      </div>
    </div>

    <!-- Panneau colonnes -->
    <div class="col-panel" v-if="showColPanel" @click.stop>
      <div class="cp-hd"><span>Colonnes affichées</span><button class="cp-reset" @click="resetCols">Réinitialiser</button></div>
      <div class="cp-list">
        <div class="cp-item" v-for="(col, i) in colOrder" :key="col">
          <label><input type="checkbox" :checked="isColVisible(col)" @change="toggleCol(col)" /> {{ COL_LABELS[col] }}</label>
          <span class="cp-move">
            <button :disabled="i === 0" @click="moveCol(col, -1)">↑</button>
            <button :disabled="i === colOrder.length - 1" @click="moveCol(col, 1)">↓</button>
          </span>
        </div>
      </div>
    </div>

    <div v-if="needsMigration" class="mp-warn">⚠️ Tables absentes — exécute les migrations <code>034</code> + <code>035</code> dans Supabase, puis recharge.</div>

    <!-- KPI par niveau -->
    <div class="mp-kpis">
      <button class="mp-kpi" :class="{on: niveauFilter === ''}" @click="niveauFilter = ''"><span class="k-n">{{ products.length }}</span><span class="k-l">Tous</span></button>
      <button class="mp-kpi kpi-faible" :class="{on: niveauFilter === 'faible'}" @click="toggleNiveau('faible')"><span class="k-n">{{ counts.faible }}</span><span class="k-l">🟢 Faible</span></button>
      <button class="mp-kpi kpi-moyen" :class="{on: niveauFilter === 'moyen'}" @click="toggleNiveau('moyen')"><span class="k-n">{{ counts.moyen }}</span><span class="k-l">🟡 Moyen</span></button>
      <button class="mp-kpi kpi-eleve" :class="{on: niveauFilter === 'eleve'}" @click="toggleNiveau('eleve')"><span class="k-n">{{ counts.eleve }}</span><span class="k-l">🔴 Élevé</span></button>
      <button class="mp-kpi kpi-na" :class="{on: niveauFilter === 'na'}" @click="toggleNiveau('na')"><span class="k-n">{{ counts.na }}</span><span class="k-l">Non évalué</span></button>
    </div>

    <!-- Toolbar : recherche + filtres rapides -->
    <div class="mp-toolbar">
      <div class="mp-search-wrap"><span class="ts-icon">🔍</span><input v-model="searchQ" class="mp-search" placeholder="Rechercher code, désignation, fabricant…" /></div>
      <select v-model="typeSel" class="mp-sel">
        <option value="">Tous les types</option>
        <option v-for="t in typeOptions" :key="t.key" :value="t.key">{{ t.label }}</option>
      </select>
      <select v-model="fabSel" class="mp-sel">
        <option value="">Tous les fabricants</option>
        <option v-for="f in fabricantOptions" :key="f" :value="f">{{ f }}</option>
      </select>
      <select v-model="groupeSel" class="mp-sel">
        <option value="">Tous les groupes</option>
        <option v-for="g in groupeOptions" :key="g" :value="g">{{ g }}</option>
      </select>
      <span v-if="selected.length" class="sel-count">{{ selected.length }} sélectionné(s) <button class="sel-clear" @click="selected = []">✕</button></span>
    </div>

    <div v-if="loading" class="em">Chargement…</div>
    <div v-else-if="!filtered.length" class="em">Aucun produit pour ce filtre.</div>
    <div v-else class="table-wrap">
      <table class="pt-table">
        <thead>
          <tr>
            <th class="th-chk"><input type="checkbox" :checked="allPageChecked" @change="toggleSelectAllPage" /></th>
            <th class="th-fix"><span class="th-txt sortable" @click="sortBy('code_article')">Code {{ sortIcon('code_article') }}</span></th>
            <th class="th-fix"><span class="th-txt sortable" @click="sortBy('description')">Désignation {{ sortIcon('description') }}</span></th>
            <th v-for="col in visibleCols" :key="col" :class="colClass(col)">
              <div class="th-i">
                <span class="th-txt sortable" @click="sortBy(col)">{{ COL_LABELS[col] }} {{ sortIcon(col) }}</span>
                <button class="th-f" :class="{'th-f-on': columnFilters[col] && columnFilters[col].length}" @click.stop="openFilter(col, $event)">⌄</button>
              </div>
            </th>
            <th class="th-act"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in paged" :key="r.id" :class="{'row-sel': isSelected(r.id)}">
            <td class="th-chk" @click.stop><input type="checkbox" :checked="isSelected(r.id)" @change="toggleSelect(r.id)" /></td>
            <td class="mono clk" @click="goEval(r.id)">{{ r.code_article }}</td>
            <td class="td-desc clk" @click="goEval(r.id)">{{ r.description }}</td>
            <td v-for="col in visibleCols" :key="col" :class="[cellClass(col), {'td-edit': critEditable(r, col)}]" @click="cellClick(r, col, $event)">
              <span v-if="colKind(col) === 'type'" class="ty" :class="TYPE_CLASS[r.type]">{{ r.typeLabel }}</span>
              <span v-else-if="colKind(col) === 'niveau'">
                <span v-if="r.niveau" class="niv" :class="NIVEAU_CLASS[r.niveau]">{{ NIVEAU_LABELS[r.niveau] }}</span>
                <span v-else class="niv niv-na">Non évalué</span>
              </span>
              <span v-else-if="colKind(col) === 'valid'">
                <span v-if="r.validation" class="valid-tag">Niveau {{ r.validation }}</span><span v-else class="val-none">—</span>
              </span>
              <span v-else-if="colKind(col) === 'crit'" class="sc-cell" :class="[critCls(r[col]), {'sc-add': critEditable(r, col) && r[col] == null}]">{{ r[col] != null ? r[col] : (critEditable(r, col) ? '＋' : '—') }}</span>
              <span v-else-if="colKind(col) === 'score'" class="mono" :class="{strong: col === 'score_global'}">{{ r[col] != null ? r[col] : '—' }}</span>
              <span v-else-if="colKind(col) === 'date'" class="dt">{{ r.evaluated_at ? fmtDate(r.evaluated_at) : '—' }}</span>
              <span v-else>{{ r[col] || '—' }}</span>
            </td>
            <td class="th-act" @click.stop><button class="btn-eval" @click="goEval(r.id)">{{ r.ev ? 'Réévaluer' : 'Évaluer' }}</button></td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Dropdown filtre colonne -->
    <div v-if="activeFilterCol" class="cf-menu" :style="{top: filterPos.top + 'px', left: filterPos.left + 'px'}" @click.stop>
      <div class="cf-hd">{{ COL_LABELS[activeFilterCol] || activeFilterCol }}</div>
      <input v-if="distinctVals.length > 12" v-model="cfSearch" class="cf-search" placeholder="Filtrer…" />
      <div class="cf-acts"><button @click="cfAll">Tout</button><button @click="cfNone">Aucun</button></div>
      <div class="cf-list">
        <label v-for="v in distinctValsShown" :key="v.key" class="cf-item">
          <input type="checkbox" :checked="cfChecked(v.key)" @change="cfToggle(v.key)" /> {{ v.label }}
        </label>
      </div>
    </div>

    <!-- Éditeur inline de score critère -->
    <div v-if="editCell && editCrit" class="ce-menu" :style="{top: editPos.top + 'px', left: editPos.left + 'px'}" @click.stop>
      <div class="ce-hd">{{ editCrit.label }}</div>
      <button v-for="v in editVals" :key="v" class="ce-opt" :class="'ceo-' + v" @click="setCellScore(v)">
        <span class="ce-n">{{ v }}</span><span class="ce-t">{{ v === 1 ? editCrit.s1 : (v === 3 ? editCrit.s3 : editCrit.s5) }}</span>
      </button>
      <button class="ce-clear" @click="setCellScore(null)">✕ Effacer</button>
    </div>

    <!-- Pagination -->
    <div class="mp-pag" v-if="!loading && filtered.length">
      <button class="pag-btn" :disabled="page === 0" @click="page--">‹ Préc.</button>
      <span class="pag-info">Page {{ page + 1 }} / {{ totalPages }} &nbsp;·&nbsp; {{ filtered.length }} produit{{ filtered.length !== 1 ? 's' : '' }}</span>
      <button class="pag-btn" :disabled="page >= totalPages - 1" @click="page++">Suiv. ›</button>
    </div>

    <!-- Modal config -->
    <div class="overlay" v-if="showConfig" @click.self="showConfig = false">
      <div class="modal">
        <div class="mt">Pondérations &amp; seuils</div>
        <div class="modal-body-inner">
          <div class="cfg-sec">Modèle IMPORT (sous-licence + revente) — total 100</div>
          <div class="fg3">
            <div class="fi"><label>Produit (%)</label><input v-model.number="cfgForm.poids_produit" type="number" class="inp" /></div>
            <div class="fi"><label>Partenaire (%)</label><input v-model.number="cfgForm.poids_partenaire" type="number" class="inp" /></div>
            <div class="fi"><label>Marché (%)</label><input v-model.number="cfgForm.poids_marche" type="number" class="inp" /></div>
          </div>
          <div class="cfg-tot" :class="{bad: totalImport !== 100}">Total import : {{ totalImport }} %</div>
          <div class="cfg-sec">Modèle PRODUCTION (générique + OTC LDM) — total 100</div>
          <div class="fg3">
            <div class="fi"><label>Produit (%)</label><input v-model.number="cfgForm.poids_prod_produit" type="number" class="inp" /></div>
            <div class="fi"><label>Commercial (%)</label><input v-model.number="cfgForm.poids_prod_commercial" type="number" class="inp" /></div>
            <div class="fi"><label>Marché (%)</label><input v-model.number="cfgForm.poids_prod_marche" type="number" class="inp" /></div>
          </div>
          <div class="cfg-tot" :class="{bad: totalProd !== 100}">Total production : {{ totalProd }} %</div>
          <div class="cfg-sec">Seuils de niveau (score global 1 → 5)</div>
          <div class="fg2">
            <div class="fi"><label>≤ ce seuil = 🟢 Faible</label><input v-model.number="cfgForm.seuil_moyen" type="number" step="0.1" class="inp" /></div>
            <div class="fi"><label>≤ ce seuil = 🟡 Moyen (sinon 🔴 Élevé)</label><input v-model.number="cfgForm.seuil_eleve" type="number" step="0.1" class="inp" /></div>
          </div>
          <div class="merr" v-if="cfgErr">{{ cfgErr }}</div>
        </div>
        <div class="ma"><button class="mp-btn-cfg" :disabled="cfgSaving" @click="saveConfig">{{ cfgSaving ? '…' : 'Enregistrer' }}</button><button class="bc2" @click="showConfig = false">Annuler</button></div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import { loadPermissions, canPerform } from '../../services/permissions'
import { NIVEAU_LABELS, NIVEAU_CLASS, NIVEAU_ORDER, DEFAULT_CONFIG, decisionsFor, productType, TYPE_LABELS, TYPE_CLASS,
  modelForProduct, getModel, allowedValues, computeScores } from '../../services/peremptionRisk'
import { exportToExcel, exportToPDF } from '../../services/export'

// Colonnes sélectionnables (Code + Désignation sont fixes, hors panneau)
var COLS = [
  { key: 'niveau', label: 'Niveau', kind: 'niveau' },
  { key: 'validation', label: 'Validation', kind: 'valid' },
  { key: 'groupe_article', label: "Groupe d'article", kind: 'text' },
  { key: 'fabricant', label: 'Fabricant', kind: 'text' },
  { key: 'type', label: 'Type', kind: 'type' },
  { key: 'sc_shelf_life', label: 'Shelf Life', kind: 'crit' },
  { key: 'sc_prix', label: 'Montant forecast', kind: 'crit' },
  { key: 'sc_historique', label: 'Historique', kind: 'crit' },
  { key: 'sc_profitabilite', label: 'Profitabilité', kind: 'crit' },
  { key: 'sc_forecast', label: 'Forecast', kind: 'crit' },
  { key: 'sc_solvabilite', label: 'Solvabilité', kind: 'crit' },
  { key: 'sc_engagements', label: 'Resp. engag.', kind: 'crit' },
  { key: 'sc_promotion', label: 'Promotion', kind: 'crit' },
  { key: 'sc_croissance', label: 'Croissance', kind: 'crit' },
  { key: 'sc_concurrence', label: 'Concurrence', kind: 'crit' },
  { key: 'sc_maturite', label: 'Maturité', kind: 'crit' },
  { key: 'score_produit', label: 'Score Produit', kind: 'score' },
  { key: 'score_partenaire', label: 'Score Part./Comm.', kind: 'score' },
  { key: 'score_marche', label: 'Score Marché', kind: 'score' },
  { key: 'score_global', label: 'Global', kind: 'score' },
  { key: 'evaluated_at', label: 'Dernière éval.', kind: 'date' },
]
var COL_LABELS = COLS.reduce(function (m, c) { m[c.key] = c.label; return m }, {})
var COL_KIND = COLS.reduce(function (m, c) { m[c.key] = c.kind; return m }, {})
var ALL_KEYS = COLS.map(function (c) { return c.key })
var ALL_SC_KEYS = ['sc_shelf_life', 'sc_prix', 'sc_historique', 'sc_profitabilite', 'sc_forecast', 'sc_solvabilite', 'sc_engagements', 'sc_promotion', 'sc_croissance', 'sc_concurrence', 'sc_maturite']
var TYPE_OPTS = [{ key: 'generique', label: 'Générique' }, { key: 'otc', label: 'OTC' }, { key: 'sous_licence', label: 'Sous-licence' }, { key: 'import', label: 'Import / Revente' }]
var LS_ORDER = 'peremption_col_order_v2', LS_HIDDEN = 'peremption_hidden_cols'

export default {
  setup() {
    var router = useRouter()
    var products = ref([]), evMap = ref({}), config = ref(Object.assign({}, DEFAULT_CONFIG))
    var loading = ref(true), needsMigration = ref(false)
    var searchQ = ref(''), niveauFilter = ref(''), typeSel = ref(''), fabSel = ref(''), groupeSel = ref('')
    var page = ref(0), PAGE_SIZE = 50
    var sortCol = ref(''), sortDir = ref('asc')
    var selected = ref([])
    var userService = ref(''), canConfig = ref(false), canEval = ref(false), userId = ref(null)
    // édition inline des cellules critères
    var editCell = ref(null), editPos = ref({ top: 0, left: 0 }), cellSaving = ref(false)
    // colonnes
    var showColPanel = ref(false)
    var savedOrder = null, savedHidden = []
    try { savedOrder = JSON.parse(localStorage.getItem(LS_ORDER) || 'null'); savedHidden = JSON.parse(localStorage.getItem(LS_HIDDEN) || '[]') } catch (e) {}
    if (savedOrder) { savedOrder = savedOrder.filter(function (k) { return ALL_KEYS.indexOf(k) >= 0 }); ALL_KEYS.forEach(function (k) { if (savedOrder.indexOf(k) < 0) savedOrder.push(k) }) }
    var colOrder = ref(savedOrder || ALL_KEYS.slice())
    var hiddenCols = ref(savedHidden || [])
    // filtre colonne
    var columnFilters = ref({})
    var activeFilterCol = ref(null), filterPos = ref({ top: 0, left: 0 }), cfSearch = ref('')
    // config modal
    var showConfig = ref(false), cfgForm = ref(Object.assign({}, DEFAULT_CONFIG)), cfgSaving = ref(false), cfgErr = ref('')

    var visibleCols = computed(function () { return colOrder.value.filter(function (k) { return hiddenCols.value.indexOf(k) < 0 }) })
    var colKind = function (col) { return COL_KIND[col] }
    var colClass = function (col) { var k = COL_KIND[col]; return (k === 'crit' || k === 'score' || k === 'niveau' || k === 'valid' || k === 'type') ? 'tc' : '' }
    var cellClass = function (col) { var k = COL_KIND[col]; return (k === 'crit' || k === 'score' || k === 'niveau' || k === 'valid' || k === 'type') ? 'tc clk' : 'clk' }
    var isColVisible = function (col) { return hiddenCols.value.indexOf(col) < 0 }
    var persistCols = function () { try { localStorage.setItem(LS_ORDER, JSON.stringify(colOrder.value)); localStorage.setItem(LS_HIDDEN, JSON.stringify(hiddenCols.value)) } catch (e) {} }
    var toggleCol = function (col) { var i = hiddenCols.value.indexOf(col); if (i >= 0) hiddenCols.value.splice(i, 1); else hiddenCols.value.push(col); persistCols() }
    var moveCol = function (col, dir) { var a = colOrder.value.slice(); var i = a.indexOf(col); var j = i + dir; if (j < 0 || j >= a.length) return; var t = a[i]; a[i] = a[j]; a[j] = t; colOrder.value = a; persistCols() }
    var resetCols = function () { colOrder.value = ALL_KEYS.slice(); hiddenCols.value = []; try { localStorage.removeItem(LS_ORDER); localStorage.removeItem(LS_HIDDEN) } catch (e) {} }

    var critCls = function (v) { return v === 1 ? 'sc1' : v === 3 ? 'sc3' : v === 5 ? 'sc5' : '' }
    var fmtDate = function (d) { return d ? new Date(d).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: '2-digit' }) : '—' }
    var toggleNiveau = function (n) { niveauFilter.value = niveauFilter.value === n ? '' : n }
    var goEval = function (id) { router.push('/peremption/' + id) }

    // ── Lignes (produit + dernière éval, à plat) ──
    var rows = computed(function () {
      return products.value.map(function (p) {
        var ev = evMap.value[p.id] || null
        var ty = productType(p)
        var row = {
          id: p.id, code_article: p.code_article || '', description: p.description || '',
          groupe_article: p.groupe_article || '', fabricant: p.fabricant || '', type: ty, typeLabel: TYPE_LABELS[ty],
          niveau: ev ? ev.niveau : null,
          validation: ev && ev.niveau ? ((decisionsFor(ev.niveau) || {}).validation || null) : null,
          evaluated_at: ev ? ev.evaluated_at : null, ev: ev,
        }
        ;['sc_shelf_life', 'sc_prix', 'sc_historique', 'sc_profitabilite', 'sc_forecast', 'sc_solvabilite', 'sc_engagements', 'sc_promotion', 'sc_croissance', 'sc_concurrence', 'sc_maturite',
          'score_produit', 'score_partenaire', 'score_marche', 'score_global'].forEach(function (k) { row[k] = ev ? ev[k] : null })
        return row
      })
    })
    var evaluatedCount = computed(function () { return rows.value.filter(function (r) { return r.ev }).length })
    var counts = computed(function () { var c = { faible: 0, moyen: 0, eleve: 0, na: 0 }; rows.value.forEach(function (r) { if (r.niveau) c[r.niveau]++; else c.na++ }); return c })
    // Filtres en cascade : les options d'un filtre = valeurs présentes parmi les produits
    // qui passent les DEUX autres filtres (on ignore le filtre courant).
    var matchSel = function (p, useType, useFab, useGroupe) {
      if (useType && typeSel.value && productType(p) !== typeSel.value) return false
      if (useFab && fabSel.value && p.fabricant !== fabSel.value) return false
      if (useGroupe && groupeSel.value && p.groupe_article !== groupeSel.value) return false
      return true
    }
    var typeOptions = computed(function () { var s = {}; products.value.forEach(function (p) { if (matchSel(p, false, true, true)) s[productType(p)] = 1 }); return TYPE_OPTS.filter(function (t) { return s[t.key] }) })
    var fabricantOptions = computed(function () { var s = {}; products.value.forEach(function (p) { if (p.fabricant && matchSel(p, true, false, true)) s[p.fabricant] = 1 }); return Object.keys(s).sort() })
    var groupeOptions = computed(function () { var s = {}; products.value.forEach(function (p) { if (p.groupe_article && matchSel(p, true, true, false)) s[p.groupe_article] = 1 }); return Object.keys(s).sort() })
    // reset d'une sélection devenue incompatible avec les autres filtres
    watch([typeSel, fabSel, groupeSel], function () {
      if (typeSel.value && !typeOptions.value.some(function (t) { return t.key === typeSel.value })) typeSel.value = ''
      if (fabSel.value && fabricantOptions.value.indexOf(fabSel.value) < 0) fabSel.value = ''
      if (groupeSel.value && groupeOptions.value.indexOf(groupeSel.value) < 0) groupeSel.value = ''
    })

    // valeur d'affichage d'une cellule (sert filtre + tri)
    var cellVal = function (r, col) {
      var k = COL_KIND[col]
      if (k === 'type') return r.typeLabel
      if (k === 'niveau') return r.niveau ? NIVEAU_LABELS[r.niveau] : 'Non évalué'
      if (k === 'valid') return r.validation ? 'Niveau ' + r.validation : '—'
      if (k === 'date') return r.evaluated_at ? fmtDate(r.evaluated_at) : '—'
      if (k === 'crit' || k === 'score') return r[col] != null ? String(r[col]) : '—'
      return r[col] || ''
    }
    var sortVal = function (r, col) {
      var k = COL_KIND[col] || (col === 'code_article' || col === 'description' ? 'text' : '')
      if (k === 'crit' || k === 'score') return r[col] == null ? -1 : r[col]
      if (k === 'niveau') return r.niveau ? NIVEAU_ORDER[r.niveau] : 0
      if (k === 'valid') return r.validation || 0
      if (k === 'date') return r.evaluated_at ? new Date(r.evaluated_at).getTime() : 0
      if (k === 'type') return (r.typeLabel || '').toLowerCase()
      return String(r[col] || '').toLowerCase()
    }

    var filtered = computed(function () {
      var q = searchQ.value.trim().toLowerCase()
      var nf = niveauFilter.value
      var cf = columnFilters.value
      var arr = rows.value.filter(function (r) {
        if (nf === 'na') { if (r.niveau) return false } else if (nf) { if (r.niveau !== nf) return false }
        if (typeSel.value && r.type !== typeSel.value) return false
        if (fabSel.value && r.fabricant !== fabSel.value) return false
        if (groupeSel.value && r.groupe_article !== groupeSel.value) return false
        for (var col in cf) { if (cf[col] && cf[col].length) { if (cf[col].indexOf(cellVal(r, col)) < 0) return false } }
        if (q && !(r.code_article.toLowerCase().includes(q) || r.description.toLowerCase().includes(q) || r.fabricant.toLowerCase().includes(q) || r.groupe_article.toLowerCase().includes(q))) return false
        return true
      })
      var sc = sortCol.value
      if (sc) {
        var dir = sortDir.value === 'asc' ? 1 : -1
        arr = arr.slice().sort(function (a, b) { var va = sortVal(a, sc), vb = sortVal(b, sc); if (va < vb) return -dir; if (va > vb) return dir; return 0 })
      } else {
        arr = arr.slice().sort(function (a, b) { var na = a.niveau ? NIVEAU_ORDER[a.niveau] : 0, nb = b.niveau ? NIVEAU_ORDER[b.niveau] : 0; if (na !== nb) return nb - na; return a.code_article.localeCompare(b.code_article) })
      }
      return arr
    })
    var totalPages = computed(function () { return Math.max(1, Math.ceil(filtered.value.length / PAGE_SIZE)) })
    var paged = computed(function () { var s = page.value * PAGE_SIZE; return filtered.value.slice(s, s + PAGE_SIZE) })
    watch([searchQ, niveauFilter, typeSel, fabSel, groupeSel, columnFilters, sortCol, sortDir], function () { page.value = 0 }, { deep: true })

    // ── Tri ──
    var sortBy = function (col) { if (sortCol.value === col) { sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc' } else { sortCol.value = col; sortDir.value = 'asc' } }
    var sortIcon = function (col) { return sortCol.value !== col ? '↕' : (sortDir.value === 'asc' ? '↑' : '↓') }

    // ── Filtre par colonne ──
    var distinctVals = computed(function () {
      if (!activeFilterCol.value) return []
      var col = activeFilterCol.value, seen = {}, out = []
      rows.value.forEach(function (r) { var v = cellVal(r, col); if (!(v in seen)) { seen[v] = 1; out.push({ key: v, label: v === '' ? '(vide)' : v }) } })
      out.sort(function (a, b) { return a.label.localeCompare(b.label, 'fr', { numeric: true }) })
      return out
    })
    var distinctValsShown = computed(function () { var s = cfSearch.value.trim().toLowerCase(); if (!s) return distinctVals.value; return distinctVals.value.filter(function (v) { return v.label.toLowerCase().includes(s) }) })
    var openFilter = function (col, ev) { if (activeFilterCol.value === col) { activeFilterCol.value = null; return } activeFilterCol.value = col; cfSearch.value = ''; var rect = ev.target.getBoundingClientRect(); filterPos.value = { top: rect.bottom + 4, left: Math.min(rect.left, window.innerWidth - 240) } }
    var cfChecked = function (v) { var f = columnFilters.value[activeFilterCol.value]; return f ? f.indexOf(v) >= 0 : false }
    var cfToggle = function (v) { var col = activeFilterCol.value; var f = (columnFilters.value[col] || []).slice(); var i = f.indexOf(v); if (i >= 0) f.splice(i, 1); else f.push(v); columnFilters.value = Object.assign({}, columnFilters.value, defObj(col, f.length ? f : undefined)) }
    var cfAll = function () { var col = activeFilterCol.value; columnFilters.value = Object.assign({}, columnFilters.value, defObj(col, distinctVals.value.map(function (v) { return v.key }))) }
    var cfNone = function () { var col = activeFilterCol.value; columnFilters.value = Object.assign({}, columnFilters.value, defObj(col, undefined)) }
    function defObj(k, v) { var o = {}; o[k] = v; return o }
    var closeMenus = function () { activeFilterCol.value = null; showColPanel.value = false; editCell.value = null }

    // ── Sélection ──
    var isSelected = function (id) { return selected.value.indexOf(id) >= 0 }
    var toggleSelect = function (id) { var i = selected.value.indexOf(id); if (i >= 0) selected.value.splice(i, 1); else selected.value.push(id) }
    var allPageChecked = computed(function () { return paged.value.length > 0 && paged.value.every(function (r) { return isSelected(r.id) }) })
    var toggleSelectAllPage = function () { if (allPageChecked.value) { paged.value.forEach(function (r) { var i = selected.value.indexOf(r.id); if (i >= 0) selected.value.splice(i, 1) }) } else { paged.value.forEach(function (r) { if (!isSelected(r.id)) selected.value.push(r.id) }) } }

    // ── Édition inline des scores critères (saisie depuis le tableau) ──
    var productById = computed(function () { var m = {}; products.value.forEach(function (p) { m[p.id] = p }); return m })
    var critEditable = function (r, col) { if (!canEval.value || COL_KIND[col] !== 'crit') return false; var p = productById.value[r.id]; if (!p) return false; return getModel(modelForProduct(p)).criteria.some(function (c) { return c.key === col }) }
    var editCrit = computed(function () { if (!editCell.value) return null; var p = productById.value[editCell.value.productId]; if (!p) return null; return getModel(modelForProduct(p)).criteria.find(function (c) { return c.key === editCell.value.col }) || null })
    var editVals = computed(function () { return editCrit.value ? allowedValues(editCrit.value) : [] })
    var cellClick = function (r, col, ev) {
      if (COL_KIND[col] === 'crit') { if (critEditable(r, col)) { ev.stopPropagation(); openCellEditor(r, col, ev) } return } // critère non applicable → rien
      goEval(r.id)
    }
    var openCellEditor = function (r, col, ev) {
      if (editCell.value && editCell.value.productId === r.id && editCell.value.col === col) { editCell.value = null; return }
      activeFilterCol.value = null; showColPanel.value = false
      editCell.value = { productId: r.id, col: col }
      var rect = ev.currentTarget.getBoundingClientRect()
      editPos.value = { top: rect.bottom + 4, left: Math.min(rect.left, window.innerWidth - 230) }
    }
    var setCellScore = function (value) { if (!editCell.value) return; var c = editCell.value; editCell.value = null; saveCell(c.productId, c.col, value) }
    var saveCell = async function (productId, col, value) {
      if (cellSaving.value) return
      cellSaving.value = true
      try {
        var p = productById.value[productId]; var mk = modelForProduct(p)
        var ev = evMap.value[productId]
        var sc = {}; ALL_SC_KEYS.forEach(function (k) { sc[k] = ev ? ev[k] : null }); sc[col] = value
        var comp = computeScores(sc, config.value, mk)
        var payload = { modele: mk, score_produit: comp.score_produit, score_partenaire: comp.score_partenaire, score_marche: comp.score_marche, score_global: comp.score_global, niveau: comp.niveau, evaluated_by: userId.value, evaluated_at: new Date().toISOString() }
        ALL_SC_KEYS.forEach(function (k) { payload[k] = sc[k] })
        var res
        if (ev && ev.id) res = await supabase.from('peremption_evaluations').update(payload).eq('id', ev.id).select().single()
        else { payload.product_id = productId; res = await supabase.from('peremption_evaluations').insert(payload).select().single() }
        if (res.error) { alert('Erreur enregistrement : ' + res.error.message); return }
        if (res.data) evMap.value = Object.assign({}, evMap.value, defObj(productId, res.data))
      } finally { cellSaving.value = false }
    }

    // ── Export ──
    var doExport = function (fmt) {
      var src = selected.value.length ? filtered.value.filter(function (r) { return isSelected(r.id) }) : filtered.value
      var cols = [{ key: 'code_article', label: 'Code' }, { key: 'description', label: 'Désignation' }]
        .concat(visibleCols.value.map(function (c) { return { key: c, label: COL_LABELS[c] } }))
      var data = src.map(function (r) { var o = {}; cols.forEach(function (c) { o[c.key] = cellVal(r, c.key) }); return o })
      var name = 'risques_peremption'
      if (fmt === 'pdf') exportToPDF(data, cols, name); else exportToExcel(data, cols, name)
    }

    // ── Config ──
    var totalImport = computed(function () { return (Number(cfgForm.value.poids_produit) || 0) + (Number(cfgForm.value.poids_partenaire) || 0) + (Number(cfgForm.value.poids_marche) || 0) })
    var totalProd = computed(function () { return (Number(cfgForm.value.poids_prod_produit) || 0) + (Number(cfgForm.value.poids_prod_commercial) || 0) + (Number(cfgForm.value.poids_prod_marche) || 0) })
    var openConfig = function () { cfgForm.value = Object.assign({}, config.value); cfgErr.value = ''; showConfig.value = true }
    var saveConfig = async function () {
      if (totalImport.value !== 100 || totalProd.value !== 100) { cfgErr.value = 'Chaque modèle doit totaliser 100 %.'; return }
      if (Number(cfgForm.value.seuil_moyen) >= Number(cfgForm.value.seuil_eleve)) { cfgErr.value = 'Seuil Faible < seuil Moyen requis.'; return }
      cfgSaving.value = true; cfgErr.value = ''
      var u = await supabase.auth.getUser()
      var p = ['poids_produit', 'poids_partenaire', 'poids_marche', 'poids_prod_produit', 'poids_prod_commercial', 'poids_prod_marche', 'seuil_moyen', 'seuil_eleve']
      var payload = { id: 1, updated_at: new Date().toISOString(), updated_by: u.data.user ? u.data.user.id : null }
      p.forEach(function (k) { payload[k] = Number(cfgForm.value[k]) })
      var res = await supabase.from('peremption_config').upsert(payload, { onConflict: 'id' })
      if (res.error) { cfgErr.value = res.error.message; cfgSaving.value = false; return }
      config.value = Object.assign({}, config.value, payload); showConfig.value = false; cfgSaving.value = false
    }

    var load = async function () {
      loading.value = true; needsMigration.value = false
      var pRes = await supabase.from('products').select('id, code_article, description, fabricant, groupe_article, actif').order('code_article')
      products.value = (pRes.data || []).filter(function (p) { return p.actif !== false })
      try {
        var cfgRes = await supabase.from('peremption_config').select('*').eq('id', 1).maybeSingle()
        if (cfgRes.data) config.value = Object.assign({}, DEFAULT_CONFIG, cfgRes.data); else needsMigration.value = true
      } catch (e) { needsMigration.value = true }
      try {
        var eRes = await supabase.from('peremption_evaluations').select('*').order('evaluated_at', { ascending: false })
        if (eRes.error) { needsMigration.value = true; evMap.value = {} }
        else { var m = {}; (eRes.data || []).forEach(function (e) { if (!m[e.product_id]) m[e.product_id] = e }); evMap.value = m }
      } catch (e) { needsMigration.value = true; evMap.value = {} }
      loading.value = false
    }

    onMounted(async function () {
      var u = await supabase.auth.getUser()
      if (u.data.user) { userId.value = u.data.user.id; var p = await supabase.from('profiles').select('service').eq('id', u.data.user.id).single(); if (p.data) { userService.value = p.data.service; await loadPermissions(p.data.service) } }
      canConfig.value = canPerform('configurer_risque_peremption')
      canEval.value = canPerform('evaluer_risque_peremption')
      await load()
    })

    return {
      products, loading, needsMigration, searchQ, niveauFilter, typeSel, fabSel, groupeSel, canConfig,
      evaluatedCount, counts, typeOptions, fabricantOptions, groupeOptions, filtered, paged, page, totalPages,
      fmtDate, toggleNiveau, goEval, critCls,
      NIVEAU_LABELS, NIVEAU_CLASS, TYPE_CLASS, COL_LABELS,
      visibleCols, colOrder, showColPanel, isColVisible, toggleCol, moveCol, resetCols, colKind, colClass, cellClass,
      sortBy, sortIcon,
      columnFilters, activeFilterCol, filterPos, cfSearch, distinctVals, distinctValsShown, openFilter, cfChecked, cfToggle, cfAll, cfNone, closeMenus,
      selected, isSelected, toggleSelect, allPageChecked, toggleSelectAllPage,
      canEval, critEditable, cellClick, editCell, editPos, editCrit, editVals, setCellScore,
      doExport,
      showConfig, cfgForm, cfgSaving, cfgErr, totalImport, totalProd, openConfig, saveConfig,
    }
  }
}
</script>

<style scoped>
.mp { font-family: 'Inter', sans-serif; }
.fa-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; flex-wrap: wrap; margin-bottom: 14px; }
.fa-title { font-size: 18px; font-weight: 800; color: var(--th-text, #1a1a2e); }
.fa-sub { font-size: 12px; color: var(--th-text2, #6b7280); margin-top: 2px; }
.fa-actions { display: flex; gap: 8px; flex-wrap: wrap; }
.mp-btn, .mp-btn-cfg { font-size: 12px; font-weight: 600; padding: 7px 12px; border-radius: 6px; border: 1px solid var(--th-border, #e5e7eb); background: var(--th-bg2, #fff); color: var(--th-text2, #555); cursor: pointer; }
.mp-btn:hover, .mp-btn-cfg:hover { border-color: #7c3aed; color: #7c3aed; }
.mp-btn-on { background: #f5f3ff; border-color: #7c3aed; color: #7c3aed; }
.mp-btn-cfg { background: #f5f3ff; border-color: #ede9fe; color: #7c3aed; }

.col-panel { position: absolute; z-index: 50; background: var(--th-bg2, #fff); color: var(--th-text, #222); border: 1px solid var(--th-border, #e5e7eb); border-radius: 8px; box-shadow: 0 10px 30px rgba(0,0,0,.15); padding: 10px; width: 280px; max-height: 60vh; overflow-y: auto; right: 16px; }
.cp-hd { display: flex; justify-content: space-between; align-items: center; font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--th-text2, #6b7280); margin-bottom: 6px; }
.cp-reset { font-size: 11px; border: none; background: none; color: #7c3aed; cursor: pointer; }
.cp-item { display: flex; align-items: center; justify-content: space-between; font-size: 12px; padding: 3px 0; }
.cp-item label { display: flex; align-items: center; gap: 6px; cursor: pointer; }
.cp-move button { font-size: 11px; border: 1px solid var(--th-border, #e5e7eb); background: var(--th-bg2, #fff); color: var(--th-text, #222); border-radius: 3px; cursor: pointer; margin-left: 2px; }
.cp-move button:disabled { opacity: .3; cursor: not-allowed; }

.mp-warn { background: #fef3c7; color: #92400e; border: 1px solid #fde68a; border-radius: 6px; padding: 10px 14px; font-size: 12px; margin-bottom: 12px; }
.mp-warn code { font-family: 'SF Mono', monospace; background: rgba(0,0,0,.05); padding: 1px 5px; border-radius: 3px; }

.mp-kpis { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 12px; }
.mp-kpi { display: flex; flex-direction: column; align-items: center; gap: 1px; min-width: 76px; padding: 8px 12px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 8px; background: var(--th-bg2, #fff); cursor: pointer; }
.mp-kpi:hover { border-color: #c4b5fd; } .mp-kpi.on { border-color: #7c3aed; box-shadow: 0 0 0 1px #7c3aed inset; }
.k-n { font-size: 18px; font-weight: 800; color: var(--th-text, #1a1a2e); font-family: 'SF Mono', monospace; }
.k-l { font-size: 10px; font-weight: 600; color: var(--th-text2, #6b7280); text-transform: uppercase; letter-spacing: .3px; }

.mp-toolbar { margin-bottom: 10px; display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
.mp-search-wrap { position: relative; flex: 1; min-width: 200px; max-width: 340px; }
.ts-icon { position: absolute; left: 10px; top: 50%; transform: translateY(-50%); font-size: 13px; opacity: .6; }
.mp-search { width: 100%; box-sizing: border-box; font-size: 13px; padding: 8px 10px 8px 30px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 6px; outline: none; background: var(--th-input-bg, #fff); color: inherit; }
.mp-search:focus { border-color: #7c3aed; }
.mp-sel { font-size: 12px; padding: 8px 10px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 6px; background: var(--th-input-bg, #fff); color: var(--th-text, #222); cursor: pointer; max-width: 200px; }
.mp-sel:focus { border-color: #7c3aed; outline: none; }
.mp-sel option { background: var(--th-input-bg, #fff); color: var(--th-text, #222); }
.sel-count { font-size: 12px; font-weight: 600; color: #7c3aed; }
.sel-clear { border: none; background: none; color: #7c3aed; cursor: pointer; font-size: 13px; }

.em { text-align: center; padding: 40px; color: var(--th-text2, #9ca3af); font-size: 13px; }
.table-wrap { overflow: auto; max-height: calc(100vh - 340px); border: 1px solid var(--th-border, #e5e7eb); border-radius: 8px; }
.pt-table { width: 100%; border-collapse: collapse; font-size: 12px; white-space: nowrap; }
.pt-table th { text-align: left; font-size: 11px; font-weight: 700; color: #7c3aed; padding: 8px 10px; border-bottom: 1px solid #ede9fe; background: #f5f3ff; position: sticky; top: 0; z-index: 2; }
.pt-table th.tc { text-align: center; }
.th-i { display: flex; align-items: center; gap: 4px; justify-content: space-between; }
.th-txt { text-transform: uppercase; letter-spacing: .3px; } .sortable { cursor: pointer; } .sortable:hover { text-decoration: underline; }
.th-f { font-size: 11px; border: none; background: none; color: #b9a8e8; cursor: pointer; padding: 0 2px; } .th-f-on { color: #7c3aed; font-weight: 800; }
.th-chk { width: 28px; text-align: center; }
.th-act { width: 70px; }
.pt-table td { padding: 7px 10px; border-bottom: 1px solid var(--th-border, #f5f5f5); vertical-align: middle; color: var(--th-text, #222); }
.pt-table tr:last-child td { border-bottom: none; }
.clk { cursor: pointer; }
.pt-table tbody tr:hover td { background: #f5f3ff; }
.row-sel td { background: #efe9fe !important; }
.mono { font-family: 'SF Mono', monospace; font-size: 11px; } .strong { font-weight: 800; }
.tc { text-align: center; }
.td-desc { max-width: 220px; overflow: hidden; text-overflow: ellipsis; }
.dt { font-family: 'SF Mono', monospace; font-size: 11px; color: var(--th-text2, #9ca3af); }
.btn-eval { font-size: 11px; font-weight: 600; padding: 4px 10px; border-radius: 5px; border: 1px solid #7c3aed; background: transparent; color: #7c3aed; cursor: pointer; }
.btn-eval:hover { background: #7c3aed; color: #fff; }
.sc-cell { display: inline-block; min-width: 20px; font-weight: 700; font-family: 'SF Mono', monospace; padding: 1px 6px; border-radius: 8px; }
.sc1 { background: #d1fae5; color: #065f46; } .sc3 { background: #fef3c7; color: #92400e; } .sc5 { background: #FCEBEB; color: #b91c1c; }

.cf-menu { position: fixed; z-index: 60; background: var(--th-bg2, #fff); color: var(--th-text, #222); border: 1px solid var(--th-border, #e5e7eb); border-radius: 8px; box-shadow: 0 10px 30px rgba(0,0,0,.2); width: 220px; padding: 8px; }
.cf-hd { font-size: 11px; font-weight: 700; text-transform: uppercase; color: #7c3aed; margin-bottom: 6px; }
.cf-search { width: 100%; box-sizing: border-box; font-size: 12px; padding: 5px 8px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 5px; margin-bottom: 6px; background: var(--th-input-bg, #fff); color: inherit; }
.cf-acts { display: flex; gap: 6px; margin-bottom: 6px; } .cf-acts button { flex: 1; font-size: 11px; padding: 4px; border: 1px solid var(--th-border, #e5e7eb); background: var(--th-bg2, #fff); color: var(--th-text, #222); border-radius: 4px; cursor: pointer; }
.cf-list { max-height: 200px; overflow-y: auto; } .cf-item { display: flex; align-items: center; gap: 6px; font-size: 12px; padding: 3px 0; cursor: pointer; }

/* Édition inline */
.td-edit { cursor: pointer; }
.td-edit:hover .sc-cell { outline: 2px solid #c4b5fd; outline-offset: 1px; }
.sc-add { background: transparent !important; color: #7c3aed !important; font-weight: 800; opacity: .55; }
.ce-menu { position: fixed; z-index: 60; background: var(--th-bg2, #fff); color: var(--th-text, #222); border: 1px solid var(--th-border, #e5e7eb); border-radius: 8px; box-shadow: 0 10px 30px rgba(0,0,0,.2); width: 230px; padding: 8px; }
.ce-hd { font-size: 11px; font-weight: 700; text-transform: uppercase; color: #7c3aed; margin-bottom: 6px; }
.ce-opt { display: flex; align-items: center; gap: 8px; width: 100%; text-align: left; padding: 7px 10px; margin-bottom: 4px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 6px; background: var(--th-bg2, #fff); color: inherit; cursor: pointer; }
.ce-opt:hover { border-color: #7c3aed; background: #f5f3ff; }
.ce-n { font-size: 14px; font-weight: 800; font-family: 'SF Mono', monospace; width: 16px; flex-shrink: 0; }
.ce-t { font-size: 11px; color: var(--th-text2, #555); line-height: 1.2; }
.ceo-1 .ce-n { color: #1D9E75; } .ceo-3 .ce-n { color: #d99e2b; } .ceo-5 .ce-n { color: #E24B4A; }
.ce-clear { width: 100%; font-size: 11px; padding: 5px; border: none; background: none; color: var(--th-text2, #9ca3af); cursor: pointer; }
.ce-clear:hover { color: #E24B4A; }
html[data-theme="night"] .ce-opt:hover, html[data-theme="workshop"] .ce-opt:hover { background: var(--th-bg3); }

.mp-pag { display: flex; align-items: center; justify-content: center; gap: 14px; padding: 12px 0 4px; }
.pag-btn { font-size: 12px; font-weight: 600; padding: 6px 14px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 6px; background: var(--th-bg2, #fff); color: var(--th-text, #333); cursor: pointer; }
.pag-btn:hover:not(:disabled) { border-color: #7c3aed; color: #7c3aed; } .pag-btn:disabled { opacity: .4; cursor: not-allowed; }
.pag-info { font-size: 12px; color: var(--th-text2, #6b7280); font-family: 'SF Mono', monospace; }

.niv { display: inline-block; font-size: 11px; font-weight: 700; padding: 2px 10px; border-radius: 10px; white-space: nowrap; }
.niv-faible { background: #d1fae5; color: #065f46; } .niv-moyen { background: #fef3c7; color: #92400e; } .niv-eleve { background: #FCEBEB; color: #b91c1c; } .niv-na { background: #f3f4f6; color: #9ca3af; }
.valid-tag { display: inline-block; font-size: 11px; font-weight: 700; padding: 2px 9px; border-radius: 10px; background: #f5f3ff; color: #7c3aed; border: 1px solid #ede9fe; } .val-none { color: var(--th-text3, #bbb); }
.ty { display: inline-block; font-size: 10px; font-weight: 700; padding: 2px 8px; border-radius: 9px; white-space: nowrap; }
.ty-gen { background: #ede9fe; color: #6d28d9; } .ty-otc { background: #e0f2fe; color: #0369a1; } .ty-sl { background: #fef3c7; color: #92400e; } .ty-imp { background: #f3f4f6; color: #6b7280; }

/* Overrides sombre */
html[data-theme="night"] .pt-table th, html[data-theme="workshop"] .pt-table th { background: var(--th-bg3); color: var(--th-accent); border-bottom-color: var(--th-border); }
html[data-theme="night"] .pt-table tbody tr:hover td, html[data-theme="workshop"] .pt-table tbody tr:hover td { background: var(--th-bg3); }
html[data-theme="night"] .row-sel td, html[data-theme="workshop"] .row-sel td { background: var(--th-bg3) !important; }
html[data-theme="night"] .mp-btn-on, html[data-theme="workshop"] .mp-btn-on, html[data-theme="night"] .mp-btn-cfg, html[data-theme="workshop"] .mp-btn-cfg { background: var(--th-bg3); color: var(--th-accent); border-color: var(--th-border); }
html[data-theme="night"] .sc1, html[data-theme="workshop"] .sc1, html[data-theme="night"] .niv-faible, html[data-theme="workshop"] .niv-faible { background: rgba(52,211,153,.12); color: #6ee7b7; }
html[data-theme="night"] .sc3, html[data-theme="workshop"] .sc3, html[data-theme="night"] .niv-moyen, html[data-theme="workshop"] .niv-moyen { background: rgba(251,191,36,.12); color: #fbbf24; }
html[data-theme="night"] .sc5, html[data-theme="workshop"] .sc5, html[data-theme="night"] .niv-eleve, html[data-theme="workshop"] .niv-eleve { background: rgba(239,68,68,.12); color: #fca5a5; }
html[data-theme="night"] .niv-na, html[data-theme="workshop"] .niv-na { background: var(--th-bg3); color: var(--th-text3, #9ca3af); }
html[data-theme="night"] .valid-tag, html[data-theme="workshop"] .valid-tag, html[data-theme="night"] .ty-gen, html[data-theme="workshop"] .ty-gen { background: var(--th-bg3); color: var(--th-accent); border-color: var(--th-border); }
html[data-theme="night"] .ty-otc, html[data-theme="workshop"] .ty-otc { background: rgba(56,189,248,.14); color: #7dd3fc; }
html[data-theme="night"] .ty-sl, html[data-theme="workshop"] .ty-sl { background: rgba(251,191,36,.12); color: #fbbf24; }
html[data-theme="night"] .ty-imp, html[data-theme="workshop"] .ty-imp { background: var(--th-bg3); color: var(--th-text3, #9ca3af); }
html[data-theme="night"] .mp-warn, html[data-theme="workshop"] .mp-warn { background: rgba(251,191,36,.12); color: #fbbf24; border-color: rgba(251,191,36,.3); }

/* Modal */
.overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 100; padding: 16px; }
.modal { background: var(--th-bg2, #fff); color: var(--th-text, #222); border-radius: 10px; box-shadow: 0 20px 50px rgba(0,0,0,.2); width: 100%; max-width: 480px; max-height: 90vh; overflow-y: auto; }
.mt { font-size: 14px; font-weight: 800; padding: 16px 20px 12px; border-bottom: 1px solid var(--th-border, #f3f4f6); }
.modal-body-inner { padding: 16px 20px; }
.cfg-sec { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .5px; color: #7c3aed; margin: 10px 0 8px; }
.fg3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; } .fg2 { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.fi { display: flex; flex-direction: column; gap: 4px; } .fi label { font-size: 10px; font-weight: 700; color: var(--th-text2, #6b7280); }
.inp { font-size: 13px; padding: 8px 10px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 5px; outline: none; width: 100%; box-sizing: border-box; background: var(--th-input-bg, #fff); color: inherit; } .inp:focus { border-color: #7c3aed; }
.cfg-tot { font-size: 12px; font-weight: 600; margin: 8px 0; color: #1D9E75; } .cfg-tot.bad { color: #E24B4A; }
.merr { font-size: 11px; color: #ef4444; background: rgba(239,68,68,.08); padding: 6px 10px; border-radius: 4px; margin-top: 8px; }
.ma { display: flex; gap: 8px; padding: 12px 20px; border-top: 1px solid var(--th-border, #f3f4f6); }
.bc2 { padding: 7px 16px; background: var(--th-bg3, #f5f5f5); color: var(--th-text2, #666); border: 1px solid var(--th-border, #e5e7eb); border-radius: 5px; font-size: 12px; cursor: pointer; }
</style>
