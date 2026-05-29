<template>
  <div class="pdpf" :data-theme="theme">

    <!-- ── HEADER ── -->
    <div class="ph">
      <div class="ph-l">
        <span class="pt">PDP FABRICATION</span>
        <div class="vtabs">
          <button v-for="v in views" :key="v.key" class="vtab" :class="{active:activeView===v.key}" @click="activeView=v.key">
            <span class="vtab-ic">{{v.icon}}</span>{{v.label}}
          </button>
        </div>
      </div>
      <div class="ph-r">
        <div class="proc-tabs">
          <button v-for="p in ['Tous',...processus.map(function(x){return x.nom_process})]" :key="p" class="proc-tab"
            :class="{active:filterProc===p}" @click="filterProc=p">{{p}}</button>
        </div>
        <button class="btn-ref" @click="loadAll" :class="{spin:loading}">↻</button>
        <div class="theme-sw">
          <button class="tsw-btn" :class="{active:theme==='night'}" @click="theme='night'" title="Nuit">🌙</button>
          <button class="tsw-btn" :class="{active:theme==='day'}" @click="theme='day'" title="Jour">☀️</button>
          <button class="tsw-btn" :class="{active:theme==='workshop'}" @click="theme='workshop'" title="Atelier">🏭</button>
        </div>
      </div>
    </div>

    <!-- ════════════════════════════════════════════
         VUE 1 — TABLEAU CROISÉ Date × Atelier
    ════════════════════════════════════════════ -->
    <div v-show="activeView==='tableau'">

      <!-- Toolbar -->
      <div class="tc-bar">
        <div class="tc-nav">
          <button class="tn" @click="navPeriod(-1)">◀</button>
          <button class="tn tn-now" @click="goToday">Auj.</button>
          <button class="tn" @click="navPeriod(1)">▶</button>
          <span class="tc-range">{{rangeLabel}}</span>
        </div>
        <div class="tc-pds">
          <button v-for="p in PERIODS" :key="p.k" class="tpd" :class="{active:periode===p.k}" @click="setPeriode(p.k)">{{p.l}}</button>
        </div>
        <input v-model="filterLot" class="tc-srch" placeholder="Lot ou produit…" />
        <select v-model="filterStatutTC" class="tc-sel">
          <option value="">Tous statuts</option>
          <option value="encours">En cours</option>
          <option value="cloture">Clôturé</option>
          <option value="arret">Arrêt</option>
        </select>
        <button class="btn-add" @click="openFabModal(null,null)">+ Nouveau suivi</button>
      </div>

      <!-- Légende -->
      <div class="tc-leg">
        <span class="tl tl-encours">■ En cours</span>
        <span class="tl tl-cloture">■ Clôturé</span>
        <span class="tl tl-arret">■ Arrêt</span>
        <span class="tl tl-vide">■ Vide</span>
      </div>

      <!-- Tableau -->
      <div class="tc-scroll" v-if="!loading||tableRows.length">
        <table class="tc-tbl">
          <thead>
            <tr>
              <th class="th-date">Date</th>
              <th v-for="at in filteredAteliers" :key="at.id" class="th-at">
                <div class="tha-nom">{{at.nom_atelier}}</div>
                <div class="tha-sub">{{getProcNom(at.processus_id)}}</div>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in tableRows" :key="row.iso" :class="{'tr-today':row.isToday,'tr-we':row.isWeekend}">
              <td class="td-date" :class="{'tdd-today':row.isToday}">
                <div class="dj">{{row.dayLabel}}</div>
                <div class="dd">{{row.dateLabel}}</div>
              </td>
              <td v-for="cell in row.cells" :key="cell.at.id"
                class="tc-cell"
                :class="['c-'+cell.status, cell.dimmed?'c-dim':'', (cell.status!=='vide'&&!cell.dimmed)?'c-click':'']"
                @click="cell.status!=='vide'&&!cell.dimmed&&openDetail(cell,row)">
                <template v-if="cell.status!=='vide'&&!cell.dimmed">
                  <div v-for="sf in cell.suivis.slice(0,3)" :key="sf.id" class="ci-sf">
                    <span class="ci-dot" :class="'cid-'+sf.statut.toLowerCase().replace(/\s/g,'-')"></span>
                    <span class="ci-lot">{{sf.lots&&sf.lots.numero_lot||sf.lot_id}}</span>
                  </div>
                  <div v-if="cell.suivis.length>3" class="ci-more">+{{cell.suivis.length-3}}</div>
                </template>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-if="loading&&!tableRows.length" class="ldg">Chargement…</div>
      <div v-if="!loading&&!filteredAteliers.length" class="ldg">Aucun atelier pour ce filtre</div>
    </div>

    <!-- ════════════════════════════════════════════
         VUE 2 — SUIVI LOTS FAB (tableau)
    ════════════════════════════════════════════ -->
    <div v-show="activeView==='lotfab'">
      <div class="t-bar">
        <input class="t-srch" v-model="sfSearch" placeholder="Lot, produit…">
        <select class="t-sel" v-model="filterAtelier">
          <option value="">Tous les ateliers</option>
          <option v-for="at in ateliers" :key="at.id" :value="at.id">{{at.nom_atelier}}</option>
        </select>
        <select class="t-sel" v-model="sfStatut">
          <option value="">Tous statuts</option>
          <option>En cours</option><option>Clôturé</option><option>Arrêt</option>
        </select>
        <select class="t-sel" v-model="sfProc">
          <option value="">Tous processus</option>
          <option v-for="p in processus" :key="p.id" :value="p.id">{{p.nom_process}}</option>
        </select>
        <button class="btn-add" @click="openFabModal(null,null)">+ Nouveau suivi</button>
      </div>
      <div class="dt-wrap">
        <table class="dt">
          <thead>
            <tr>
              <th class="srt" @click="sfSort('lots.numero_lot')">Lot <span class="si">{{sfSortIc('lots.numero_lot')}}</span></th>
              <th class="srt" @click="sfSort('lots.products.description')">Produit <span class="si">{{sfSortIc('lots.products.description')}}</span></th>
              <th class="srt" @click="sfSort('nom_atelier')">Atelier <span class="si">{{sfSortIc('nom_atelier')}}</span></th>
              <th>Processus</th>
              <th class="srt" @click="sfSort('date_debut')">Début <span class="si">{{sfSortIc('date_debut')}}</span></th>
              <th class="srt" @click="sfSort('date_fin')">Fin <span class="si">{{sfSortIc('date_fin')}}</span></th>
              <th>Durée</th>
              <th class="srt" @click="sfSort('statut')">Statut <span class="si">{{sfSortIc('statut')}}</span></th>
              <th>Arrêts</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="sf in filteredSuivis" :key="sf.id" :class="'row-'+sf.statut.toLowerCase().replace(/\s/g,'-')">
              <td class="mono">{{sf.lots&&sf.lots.numero_lot||sf.lot_id}}</td>
              <td class="sm">{{sf.lots&&sf.lots.products&&sf.lots.products.description||'—'}}</td>
              <td class="sm">{{getAtelierNom(sf.atelier_id)}}</td>
              <td><span class="prc-chip" :style="{background:procColor(sf.processus_id)+'33',color:procColor(sf.processus_id)}">{{getProcNom(sf.processus_id)}}</span></td>
              <td class="mono">{{fmtDate(sf.date_debut)}}</td>
              <td class="mono">{{fmtDate(sf.date_fin)||'—'}}</td>
              <td class="mono">{{calcDuree(sf)}}</td>
              <td><span class="schip" :class="'sc-'+sf.statut.toLowerCase().replace(/\s/g,'-')">{{sf.statut}}</span></td>
              <td>
                <span v-if="getArretCount(sf.id)" class="arr-badge">{{getArretCount(sf.id)}} arrêt{{getArretCount(sf.id)>1?'s':''}}</span>
                <span v-else class="arr-none">—</span>
              </td>
              <td class="acts">
                <button class="ia" @click="openFabModal(sf,sf.atelier_id)" title="Modifier">✏</button>
                <button class="ia" @click="openArretAtelier(sf)" title="Arrêt" v-if="sf.statut==='En cours'">⏸</button>
                <button class="ia ok" @click="clotureAtelier(sf)" title="Clôturer" v-if="sf.statut==='En cours'||sf.statut==='Arrêt'">✓</button>
                <button class="ia del" @click="deleteFab(sf)" title="Supprimer">✕</button>
              </td>
            </tr>
            <tr v-if="!filteredSuivis.length"><td colspan="10" class="empty">Aucun suivi trouvé</td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ════════════════════════════════════════════
         VUE 3 — ARRÊTS ATELIERS
    ════════════════════════════════════════════ -->
    <div v-show="activeView==='arrets'">
      <div class="t-bar">
        <input class="t-srch" v-model="arrSearch" placeholder="Motif, lot…">
        <select class="t-sel" v-model="arrFilterAt">
          <option value="">Tous les ateliers</option>
          <option v-for="at in ateliers" :key="at.id" :value="at.id">{{at.nom_atelier}}</option>
        </select>
        <select class="t-sel" v-model="arrFilterStatut">
          <option value="">Tous</option>
          <option value="actif">En cours</option>
          <option value="cloture">Clôturés</option>
        </select>
        <div class="arr-stats">
          <span class="arr-stat">Total : <b>{{arretAtelier.length}}</b></span>
          <span class="arr-stat arr-ec">En cours : <b>{{arretAtelier.filter(function(a){return !a.heure_fin}).length}}</b></span>
          <span class="arr-stat">Durée moy. : <b>{{avgArretDuree}}</b></span>
        </div>
      </div>
      <div class="dt-wrap">
        <table class="dt">
          <thead>
            <tr>
              <th>Lot</th>
              <th>Atelier</th>
              <th class="srt" @click="arrSort('motif')">Motif <span class="si">{{arrSortIc('motif')}}</span></th>
              <th class="srt" @click="arrSort('heure_debut')">Début <span class="si">{{arrSortIc('heure_debut')}}</span></th>
              <th>Fin</th>
              <th>Durée</th>
              <th>Statut</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="arr in filteredArrets" :key="arr.id" :class="arr.heure_fin?'':'row-actif'">
              <td class="mono">{{getLotNum(arr.lot_id)}}</td>
              <td class="sm">{{getAtelierNom(arr.atelier_id)}}</td>
              <td class="sm">{{arr.motif}}</td>
              <td class="mono">{{fmtDateTime(arr.heure_debut)}}</td>
              <td class="mono">{{arr.heure_fin?fmtDateTime(arr.heure_fin):'En cours'}}</td>
              <td class="mono">{{arretDuree(arr)}}</td>
              <td><span :class="arr.heure_fin?'schip sc-clôturé':'schip sc-en-cours'">{{arr.heure_fin?'Clôturé':'En cours'}}</span></td>
              <td class="acts">
                <button v-if="!arr.heure_fin" class="ia ok" @click="closeArretAtelier(arr)">✓ Lever</button>
                <button class="ia del" @click="deleteArret(arr)">✕</button>
              </td>
            </tr>
            <tr v-if="!filteredArrets.length"><td colspan="8" class="empty">Aucun arrêt</td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ═══ MODAL DÉTAIL CELLULE ═══ -->
    <div class="ov" v-if="detailPanel.show" @click.self="detailPanel.show=false">
      <div class="dp">
        <div class="dp-hd">
          <div>
            <div class="dp-eq">{{detailPanel.atNom}}</div>
            <div class="dp-date">{{detailPanel.dayLabel}} {{detailPanel.dateLabel}} · {{detailPanel.procNom}}</div>
          </div>
          <button class="dp-x" @click="detailPanel.show=false">✕</button>
        </div>
        <div class="dp-body">
          <div v-if="detailPanel.suivis&&detailPanel.suivis.length" class="dp-sec">
            <div class="dp-stitle">🏭 Réalisé (suivi fabrication)</div>
            <div v-for="sf in detailPanel.suivis" :key="sf.id" class="dp-item">
              <div class="dpi-row">
                <span class="dpi-lot">{{sf.lots&&sf.lots.numero_lot||sf.lot_id}}</span>
                <span class="dpi-chip" :class="'dchip-'+sf.statut.toLowerCase().replace(/\s/g,'-')">{{sf.statut}}</span>
              </div>
              <div class="dpi-prod">{{sf.lots&&sf.lots.products&&sf.lots.products.description||'—'}}</div>
              <div class="dpi-meta">Début : {{fmtDate(sf.date_debut)}}<span v-if="sf.date_fin"> · Fin : {{fmtDate(sf.date_fin)}}</span><span v-else> · En cours</span></div>
              <div class="dpi-meta">Durée : {{calcDuree(sf)}}</div>
              <div class="dpi-meta" v-if="getArretCount(sf.id)">⚠ {{getArretCount(sf.id)}} arrêt(s)</div>
              <div class="dpi-acts">
                <button class="dpi-btn" @click="openFabModal(sf,sf.atelier_id);detailPanel.show=false">Modifier</button>
                <button class="dpi-btn" @click="openArretAtelier(sf);detailPanel.show=false" v-if="sf.statut==='En cours'">Arrêt</button>
                <button class="dpi-btn dpi-btn-ok" @click="clotureAtelier(sf);detailPanel.show=false" v-if="sf.statut==='En cours'||sf.statut==='Arrêt'">Clôturer</button>
              </div>
            </div>
          </div>
          <div v-else class="dp-empty">Aucun suivi pour cette cellule</div>
        </div>
      </div>
    </div>

    <!-- ═══ MODAL NOUVEAU/EDIT SUIVI FAB ═══ -->
    <div v-if="fabModal.open" class="ov" @click.self="fabModal.open=false">
      <div class="modal modal-fab">
        <div class="modal-hd">
          {{fabModal.id?'Modifier suivi':'Nouveau suivi fabrication'}}
          <button class="dp-x" @click="fabModal.open=false">✕</button>
        </div>
        <div class="modal-body">
          <div class="form-row">
            <label class="lbl">Lot *</label>
            <div class="lot-ac">
              <input class="inp" v-model="fabModal.lotSearch" @input="searchLots" placeholder="N° lot ou produit…">
              <div class="auto-list" v-if="lotSuggestions.length">
                <div v-for="l in lotSuggestions" :key="l.id" class="auto-item" @mousedown.prevent="selectLot(l)">
                  <span class="auto-code">{{l.numero_lot}}</span>
                  <span class="auto-desc">{{l.products&&l.products.description||''}}</span>
                </div>
              </div>
            </div>
            <div v-if="fabModal.lotId" class="sel-lot-info">✓ {{fabModal.lotNum}} — {{fabModal.lotProd}}</div>
          </div>
          <div class="form-row">
            <label class="lbl">Atelier *</label>
            <select class="inp" v-model="fabModal.atelierId" @change="onAtelierChange">
              <option value="">— Choisir —</option>
              <option v-for="at in ateliers" :key="at.id" :value="at.id">{{at.nom_atelier}} ({{getProcNom(at.processus_id)}})</option>
            </select>
          </div>
          <div class="form-row">
            <label class="lbl">Processus *</label>
            <select class="inp" v-model="fabModal.processusId">
              <option value="">— Choisir —</option>
              <option v-for="p in processus" :key="p.id" :value="p.id">{{p.nom_process}}</option>
            </select>
          </div>
          <div class="form-row-2">
            <div class="form-fld">
              <label class="lbl">Date/heure début *</label>
              <input type="datetime-local" class="inp" v-model="fabModal.dateDebut">
            </div>
            <div class="form-fld">
              <label class="lbl">Date/heure fin</label>
              <input type="datetime-local" class="inp" v-model="fabModal.dateFin">
            </div>
          </div>
          <div class="form-row">
            <label class="lbl">Statut</label>
            <select class="inp" v-model="fabModal.statut">
              <option>En cours</option><option>Clôturé</option><option>Arrêt</option>
            </select>
          </div>
          <div v-if="fabModal.err" class="err">{{fabModal.err}}</div>
        </div>
        <div class="modal-ft">
          <button class="btn-cancel" @click="fabModal.open=false">Annuler</button>
          <button class="btn-save" @click="saveFab" :disabled="fabModal.saving">{{fabModal.saving?'…':'Enregistrer'}}</button>
        </div>
      </div>
    </div>

    <!-- ═══ MODAL ARRÊT ATELIER ═══ -->
    <div v-if="arretModal.open" class="ov" @click.self="arretModal.open=false">
      <div class="modal modal-arret">
        <div class="modal-hd">
          Déclarer arrêt — {{getAtelierNom(arretModal.atelierId)}}
          <button class="dp-x" @click="arretModal.open=false">✕</button>
        </div>
        <div class="modal-body">
          <div class="arr-lot-info">
            <span class="mono">{{arretModal.lotNum}}</span>
            <span class="sm">{{arretModal.lotProd}}</span>
          </div>
          <div class="form-row">
            <label class="lbl">Motif de l'arrêt *</label>
            <textarea class="inp form-ta" v-model="arretModal.motif" rows="3" placeholder="Décrire la cause de l'arrêt…"></textarea>
          </div>
          <div class="form-row">
            <label class="lbl">Heure de début</label>
            <input type="datetime-local" class="inp" v-model="arretModal.heureDebut">
          </div>
          <div v-if="arretModal.err" class="err">{{arretModal.err}}</div>
        </div>
        <div class="modal-ft">
          <button class="btn-cancel" @click="arretModal.open=false">Annuler</button>
          <button class="btn-save" @click="saveArret" :disabled="arretModal.saving">{{arretModal.saving?'…':'Déclarer arrêt'}}</button>
        </div>
      </div>
    </div>

  </div>
</template>

<script>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { supabase } from '../../supabase'
import { useTheme } from '../../composables/useTheme'
import { getAll as gsGetAll } from '../../services/googleSheets'

export default {
  setup() {
    var { theme } = useTheme()

    // ─── STATE ─────────────────────────────────────────────────
    var loading = ref(false)
    var activeView = ref('tableau')
    var filterProc = ref('Tous')
    var filterAtelier = ref('')
    var sfSearch = ref('')
    var sfStatut = ref('')
    var sfProc = ref('')
    var sfSortCol = ref('date_debut')
    var sfSortDir = ref('desc')
    var arrSearch = ref('')
    var arrFilterAt = ref('')
    var arrFilterStatut = ref('')
    var arrSortCol = ref('heure_debut')
    var arrSortDir = ref('desc')

    // Data
    var processus = ref([])
    var ateliers = ref([])
    var suiviFab = ref([])
    var arretAtelier = ref([])

    // Tableau croisé
    var periode = ref('2sem')
    var baseDate = ref(new Date().toISOString().slice(0,10))
    var filterLot = ref('')
    var filterStatutTC = ref('')

    var PERIODS = [
      { k:'1sem', l:'1 sem' },
      { k:'2sem', l:'2 sem' },
      { k:'1mois', l:'1 mois' }
    ]

    // Tick pour temps écoulés
    var now = ref(Date.now())
    var tickInt = null

    // Detail panel
    var detailPanel = ref({ show:false, atNom:'', procNom:'', dateLabel:'', dayLabel:'', suivis:[] })

    // Modals
    var fabModal = ref({ open:false, id:null, lotId:null, lotNum:'', lotProd:'', lotSearch:'', atelierId:'', processusId:'', dateDebut:'', dateFin:'', statut:'En cours', err:'', saving:false })
    var arretModal = ref({ open:false, fabId:null, lot_id:null, lotNum:'', lotProd:'', atelierId:null, motif:'', heureDebut:'', err:'', saving:false })
    var lotSuggestions = ref([])

    var views = [
      { key:'tableau', icon:'⊞', label:'Planning' },
      { key:'lotfab',  icon:'▥', label:'Suivi lots' },
      { key:'arrets',  icon:'⚠', label:'Arrêts' }
    ]

    // ─── LOAD ──────────────────────────────────────────────────
    var loadAll = async function() {
      loading.value = true
      var [gsData, r3, r4] = await Promise.all([
        gsGetAll(),
        supabase.from('suivi_fabrication')
          .select('*, lots(id,numero_lot,quantite,products(description))')
          .is('deleted_at',null)
          .order('date_debut',{ascending:false}),
        supabase.from('atelier_arrets')
          .select('*')
          .is('deleted_at',null)
          .order('heure_debut',{ascending:false})
      ])
      // Processus et ateliers chargés depuis Google Sheets
      processus.value = gsData.processus.filter(function(p){ return p.nom_process !== 'Conditionnement' })
      var fabProcIds = {}
      processus.value.forEach(function(p){ fabProcIds[p.id] = true })
      ateliers.value = gsData.ateliers.filter(function(at){ return fabProcIds[at.processus_id] })
      if (!r3.error) suiviFab.value = r3.data
      if (!r4.error) arretAtelier.value = r4.data
      loading.value = false
    }

    // ─── HELPERS ───────────────────────────────────────────────
    var fmtDate = function(dt) {
      if (!dt) return ''
      return new Date(dt).toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',year:'2-digit',hour:'2-digit',minute:'2-digit'})
    }
    var fmtDateTime = function(dt) {
      if (!dt) return ''
      return new Date(dt).toLocaleString('fr-FR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'})
    }
    var nowDate = function() { return new Date().toISOString().slice(0,10) }

    var getAtelierNom = function(id) {
      var at = ateliers.value.find(function(a){ return a.id===id })
      return at?at.nom_atelier:'—'
    }
    var getProcNom = function(id) {
      var p = processus.value.find(function(x){ return x.id===id })
      return p?p.nom_process:'—'
    }
    var procColor = function(id) {
      var p = processus.value.find(function(x){ return x.id===id })
      return p&&p.couleur?p.couleur:'#888'
    }
    var getLotNum = function(id) {
      var sf = suiviFab.value.find(function(s){ return s.lot_id===id })
      return sf&&sf.lots?sf.lots.numero_lot:String(id)
    }
    var getArretCount = function(fabId) {
      var fab = suiviFab.value.find(function(s){ return s.id===fabId })
      if (!fab) return 0
      return arretAtelier.value.filter(function(a){ return a.lot_id===fab.lot_id && a.atelier_id===fab.atelier_id }).length
    }
    var calcDuree = function(sf) {
      if (!sf.date_debut) return '—'
      var start = new Date(sf.date_debut)
      var end = sf.date_fin?new Date(sf.date_fin):new Date()
      var diff = end-start
      var h = Math.floor(diff/3600000)
      var m = Math.floor((diff%3600000)/60000)
      return h+'h'+String(m).padStart(2,'0')
    }
    var arretDuree = function(arr) {
      if (!arr.heure_debut) return '—'
      var start = new Date(arr.heure_debut)
      var end = arr.heure_fin?new Date(arr.heure_fin):new Date()
      var diff = end-start
      var h = Math.floor(diff/3600000)
      var m = Math.floor((diff%3600000)/60000)
      return h>0?(h+'h'+String(m).padStart(2,'0')+'min'):(m+'min')
    }

    // ─── TABLEAU CROISÉ ────────────────────────────────────────
    var periodeNbDays = function() {
      if (periode.value === '1sem') return 7
      if (periode.value === '2sem') return 14
      return 31
    }
    var setPeriode = function(k) { periode.value = k }
    var navPeriod = function(dir) {
      var n = periodeNbDays()
      var d = new Date(baseDate.value)
      d.setDate(d.getDate() + dir * n)
      baseDate.value = d.toISOString().slice(0,10)
    }
    var goToday = function() { baseDate.value = nowDate() }

    var dates = computed(function() {
      var start = new Date(baseDate.value)
      var n = periodeNbDays()
      var today = nowDate()
      var JOURS = ['Dim','Lun','Mar','Mer','Jeu','Ven','Sam']
      var arr = []
      for (var i = 0; i < n; i++) {
        var d = new Date(start)
        d.setDate(start.getDate() + i)
        var iso = d.toISOString().slice(0,10)
        var dow = d.getDay()
        arr.push({
          iso,
          dayLabel: JOURS[dow],
          dateLabel: String(d.getDate()).padStart(2,'0')+'/'+String(d.getMonth()+1).padStart(2,'0'),
          isToday: iso === today,
          isWeekend: dow === 0 || dow === 6
        })
      }
      return arr
    })

    var rangeLabel = computed(function() {
      if (!dates.value.length) return ''
      return dates.value[0].dateLabel + ' — ' + dates.value[dates.value.length-1].dateLabel
    })

    var filteredAteliers = computed(function() {
      return ateliers.value.filter(function(at) {
        if (filterProc.value === 'Tous') return true
        var p = processus.value.find(function(x){ return x.id===at.processus_id })
        return p && p.nom_process === filterProc.value
      })
    })

    var getCellStatus = function(suivis) {
      if (!suivis.length) return 'vide'
      if (suivis.some(function(s){ return s.statut==='Arrêt' })) return 'arret'
      if (suivis.some(function(s){ return s.statut==='En cours' })) return 'encours'
      if (suivis.some(function(s){ return s.statut==='Clôturé' })) return 'cloture'
      return 'vide'
    }

    var tableRows = computed(function() {
      return dates.value.map(function(d) {
        var cells = filteredAteliers.value.map(function(at) {
          // Suivis qui couvrent cette date pour cet atelier
          var allSf = suiviFab.value.filter(function(sf) {
            if (sf.atelier_id !== at.id) return false
            if (!sf.date_debut) return false
            var debut = sf.date_debut.slice(0,10)
            var fin = sf.date_fin ? sf.date_fin.slice(0,10) : nowDate()
            return debut <= d.iso && d.iso <= fin
          })
          var suivis
          if (filterLot.value) {
            var q = filterLot.value.toLowerCase()
            suivis = allSf.filter(function(sf) {
              var num = (sf.lots&&sf.lots.numero_lot||'').toLowerCase()
              var desc = (sf.lots&&sf.lots.products&&sf.lots.products.description||'').toLowerCase()
              return num.includes(q) || desc.includes(q)
            })
          } else {
            suivis = allSf
          }
          var status = getCellStatus(suivis)
          var dimmed = !!(filterStatutTC.value && filterStatutTC.value !== status && status !== 'vide')
          return { at, suivis, status, dimmed }
        })
        return { iso:d.iso, dayLabel:d.dayLabel, dateLabel:d.dateLabel, isToday:d.isToday, isWeekend:d.isWeekend, cells }
      })
    })

    var openDetail = function(cell, row) {
      detailPanel.value = {
        show:    true,
        atNom:   cell.at.nom_atelier,
        procNom: getProcNom(cell.at.processus_id),
        dateLabel: row.dateLabel,
        dayLabel:  row.dayLabel,
        suivis:  cell.suivis
      }
    }

    // ─── COMPUTED LISTES ───────────────────────────────────────
    var filteredSuivis = computed(function() {
      var list = suiviFab.value.filter(function(sf) {
        if (sfSearch.value) {
          var q = sfSearch.value.toLowerCase()
          var num = (sf.lots&&sf.lots.numero_lot||'').toLowerCase()
          var prod = (sf.lots&&sf.lots.products&&sf.lots.products.description||'').toLowerCase()
          if (!num.includes(q)&&!prod.includes(q)) return false
        }
        if (filterAtelier.value && sf.atelier_id!=filterAtelier.value) return false
        if (sfStatut.value && sf.statut!==sfStatut.value) return false
        if (sfProc.value && sf.processus_id!=sfProc.value) return false
        return true
      })
      list = list.slice().sort(function(a,b) {
        var va='', vb=''
        if (sfSortCol.value==='lots.numero_lot') { va=a.lots&&a.lots.numero_lot||''; vb=b.lots&&b.lots.numero_lot||'' }
        else if (sfSortCol.value==='lots.products.description') { va=a.lots&&a.lots.products&&a.lots.products.description||''; vb=b.lots&&b.lots.products&&b.lots.products.description||'' }
        else if (sfSortCol.value==='nom_atelier') { va=getAtelierNom(a.atelier_id); vb=getAtelierNom(b.atelier_id) }
        else { va=a[sfSortCol.value]||''; vb=b[sfSortCol.value]||'' }
        var cmp = va<vb?-1:va>vb?1:0
        return sfSortDir.value==='asc'?cmp:-cmp
      })
      return list
    })

    var filteredArrets = computed(function() {
      var list = arretAtelier.value.filter(function(arr) {
        if (arrSearch.value) {
          var q = arrSearch.value.toLowerCase()
          if (!(arr.motif||'').toLowerCase().includes(q)&&!getLotNum(arr.lot_id).toLowerCase().includes(q)) return false
        }
        if (arrFilterAt.value && arr.atelier_id!=arrFilterAt.value) return false
        if (arrFilterStatut.value==='actif' && arr.heure_fin) return false
        if (arrFilterStatut.value==='cloture' && !arr.heure_fin) return false
        return true
      })
      list = list.slice().sort(function(a,b) {
        var va=a[arrSortCol.value]||'', vb=b[arrSortCol.value]||''
        if (arrSortCol.value==='duree') {
          va=a.heure_fin?new Date(a.heure_fin)-new Date(a.heure_debut):Date.now()-new Date(a.heure_debut)
          vb=b.heure_fin?new Date(b.heure_fin)-new Date(b.heure_debut):Date.now()-new Date(b.heure_debut)
        }
        var cmp=va<vb?-1:va>vb?1:0
        return arrSortDir.value==='asc'?cmp:-cmp
      })
      return list
    })

    var avgArretDuree = computed(function() {
      var closed = arretAtelier.value.filter(function(a){ return a.heure_fin })
      if (!closed.length) return '—'
      var total = closed.reduce(function(acc,a){ return acc+(new Date(a.heure_fin)-new Date(a.heure_debut)) },0)
      return Math.round(total/closed.length/60000)+'min'
    })

    // ─── SORTS ─────────────────────────────────────────────────
    var sfSort = function(col) {
      if (sfSortCol.value===col) sfSortDir.value=sfSortDir.value==='asc'?'desc':'asc'
      else { sfSortCol.value=col; sfSortDir.value='asc' }
    }
    var sfSortIc = function(col) {
      if (sfSortCol.value!==col) return '⇅'
      return sfSortDir.value==='asc'?'↑':'↓'
    }
    var arrSort = function(col) {
      if (arrSortCol.value===col) arrSortDir.value=arrSortDir.value==='asc'?'desc':'asc'
      else { arrSortCol.value=col; arrSortDir.value='asc' }
    }
    var arrSortIc = function(col) {
      if (arrSortCol.value!==col) return '⇅'
      return arrSortDir.value==='asc'?'↑':'↓'
    }

    // ─── LOT AUTOCOMPLETE ──────────────────────────────────────
    var lotAcTimer = null
    var searchLots = function() {
      clearTimeout(lotAcTimer)
      var q = fabModal.value.lotSearch.trim()
      if (!q) { lotSuggestions.value=[]; return }
      lotAcTimer = setTimeout(async function() {
        var res = await supabase.from('lots')
          .select('id,numero_lot,quantite,products(description)')
          .or('numero_lot.ilike.%'+q+'%').limit(8)
        if (!res.error) lotSuggestions.value = res.data
      }, 250)
    }
    var selectLot = function(l) {
      fabModal.value.lotId = l.id
      fabModal.value.lotNum = l.numero_lot
      fabModal.value.lotProd = l.products&&l.products.description||''
      fabModal.value.lotSearch = l.numero_lot
      lotSuggestions.value = []
    }

    // ─── FAB CRUD ──────────────────────────────────────────────
    var openFabModal = function(sf, atelierId) {
      var now2 = new Date().toISOString().slice(0,16)
      if (sf) {
        fabModal.value = { open:true, id:sf.id, lotId:sf.lot_id, lotNum:sf.lots&&sf.lots.numero_lot||'', lotProd:sf.lots&&sf.lots.products&&sf.lots.products.description||'', lotSearch:sf.lots&&sf.lots.numero_lot||'', atelierId:sf.atelier_id, processusId:sf.processus_id, dateDebut:sf.date_debut?sf.date_debut.slice(0,16):'', dateFin:sf.date_fin?sf.date_fin.slice(0,16):'', statut:sf.statut, err:'', saving:false }
      } else {
        fabModal.value = { open:true, id:null, lotId:null, lotNum:'', lotProd:'', lotSearch:'', atelierId:atelierId||'', processusId:'', dateDebut:now2, dateFin:'', statut:'En cours', err:'', saving:false }
        if (atelierId) onAtelierChange()
      }
      lotSuggestions.value = []
    }
    var onAtelierChange = function() {
      var at = ateliers.value.find(function(a){ return a.id==fabModal.value.atelierId })
      if (at) fabModal.value.processusId = at.processus_id
    }
    var saveFab = async function() {
      if (!fabModal.value.lotId) { fabModal.value.err='Lot requis'; return }
      if (!fabModal.value.atelierId) { fabModal.value.err='Atelier requis'; return }
      if (!fabModal.value.processusId) { fabModal.value.err='Processus requis'; return }
      fabModal.value.saving = true; fabModal.value.err = ''
      var payload = { lot_id:fabModal.value.lotId, atelier_id:fabModal.value.atelierId, processus_id:fabModal.value.processusId, date_debut:fabModal.value.dateDebut||null, date_fin:fabModal.value.dateFin||null, statut:fabModal.value.statut }
      var res
      if (fabModal.value.id) {
        res = await supabase.from('suivi_fabrication').update(payload).eq('id',fabModal.value.id)
      } else {
        res = await supabase.from('suivi_fabrication').insert(payload)
      }
      fabModal.value.saving = false
      if (res.error) { fabModal.value.err=res.error.message; return }
      fabModal.value.open = false
      await loadAll()
    }
    var clotureAtelier = async function(sf) {
      var res = await supabase.from('suivi_fabrication').update({ statut:'Clôturé', date_fin:new Date().toISOString() }).eq('id',sf.id)
      if (!res.error) await loadAll()
    }
    var deleteFab = async function(sf) {
      if (!confirm('Supprimer ce suivi ?')) return
      var res = await supabase.from('suivi_fabrication').update({ deleted_at:new Date().toISOString() }).eq('id',sf.id)
      if (!res.error) await loadAll()
    }

    // ─── ARRÊTS ────────────────────────────────────────────────
    var openArretAtelier = function(sf) {
      var now2 = new Date().toISOString().slice(0,16)
      arretModal.value = { open:true, fabId:sf.id, lot_id:sf.lot_id, lotNum:sf.lots&&sf.lots.numero_lot||sf.lot_id, lotProd:sf.lots&&sf.lots.products&&sf.lots.products.description||'', atelierId:sf.atelier_id, motif:'', heureDebut:now2, err:'', saving:false }
    }
    var saveArret = async function() {
      if (!arretModal.value.motif.trim()) { arretModal.value.err='Motif requis'; return }
      arretModal.value.saving = true; arretModal.value.err = ''
      var payload = { atelier_id:arretModal.value.atelierId, lot_id:arretModal.value.lot_id, motif:arretModal.value.motif, heure_debut:arretModal.value.heureDebut||new Date().toISOString() }
      var res = await supabase.from('atelier_arrets').insert(payload)
      if (res.error) { arretModal.value.err=res.error.message; arretModal.value.saving=false; return }
      await supabase.from('suivi_fabrication').update({statut:'Arrêt'}).eq('id',arretModal.value.fabId)
      arretModal.value.saving = false; arretModal.value.open = false
      await loadAll()
    }
    var closeArretAtelier = async function(arr) {
      var res = await supabase.from('atelier_arrets').update({ heure_fin:new Date().toISOString() }).eq('id',arr.id)
      if (!res.error) {
        var remaining = arretAtelier.value.filter(function(a){ return a.lot_id===arr.lot_id && !a.heure_fin && a.id!==arr.id })
        if (!remaining.length) {
          var sf = suiviFab.value.find(function(s){ return s.lot_id===arr.lot_id && s.atelier_id===arr.atelier_id })
          if (sf) await supabase.from('suivi_fabrication').update({statut:'En cours'}).eq('id',sf.id)
        }
        await loadAll()
      }
    }
    var deleteArret = async function(arr) {
      if (!confirm('Supprimer cet arrêt ?')) return
      var res = await supabase.from('atelier_arrets').update({deleted_at:new Date().toISOString()}).eq('id',arr.id)
      if (!res.error) await loadAll()
    }

    // ─── LIFECYCLE ─────────────────────────────────────────────
    onMounted(function() {
      loadAll()
      tickInt = setInterval(function(){ now.value = Date.now() }, 1000)
    })
    onBeforeUnmount(function() { clearInterval(tickInt) })

    return {
      theme,
      loading, activeView, views, PERIODS,
      processus, ateliers, suiviFab, arretAtelier,
      filterProc, filterAtelier, sfSearch, sfStatut, sfProc,
      sfSortCol, sfSortDir, arrSearch, arrFilterAt, arrFilterStatut, arrSortCol, arrSortDir,
      periode, baseDate, filterLot, filterStatutTC,
      filteredAteliers, filteredSuivis, filteredArrets, avgArretDuree,
      tableRows, rangeLabel, dates, detailPanel,
      fabModal, arretModal, lotSuggestions, now,
      fmtDate, fmtDateTime,
      getAtelierNom, getProcNom, procColor, getLotNum, getArretCount, calcDuree, arretDuree,
      setPeriode, navPeriod, goToday, openDetail,
      sfSort, sfSortIc, arrSort, arrSortIc,
      searchLots, selectLot,
      openFabModal, onAtelierChange, saveFab, clotureAtelier, deleteFab,
      openArretAtelier, saveArret, closeArretAtelier, deleteArret
    }
  }
}
</script>

<style scoped>
/* ── BASE ── */
.pdpf { min-height:100%; background:#0b0b1c; color:#e0e0f0; font-family:'Inter',sans-serif; font-size:13px; }

/* ── HEADER ── */
.ph { display:flex; align-items:center; justify-content:space-between; padding-bottom:10px; border-bottom:2px solid #1a1a38; margin-bottom:14px; flex-wrap:wrap; gap:8px; }
.ph-l { display:flex; align-items:center; gap:12px; flex-wrap:wrap; }
.ph-r { display:flex; align-items:center; gap:6px; flex-wrap:wrap; }
.pt { font-size:11px; font-weight:600; letter-spacing:1.5px; text-transform:uppercase; color:#a0a0c8; }

.vtabs { display:flex; gap:3px; }
.vtab { display:flex; align-items:center; gap:5px; padding:5px 12px; font-size:11px; border:1px solid #252545; background:#12122a; color:#8888b0; border-radius:3px; cursor:pointer; transition:.15s; }
.vtab:hover { background:#1a1a35; color:#c0c0e8; }
.vtab.active { background:#1e3a6e; color:#93c5fd; border-color:#3b82f6; }
.vtab-ic { font-size:12px; }

.proc-tabs { display:flex; gap:3px; flex-wrap:wrap; }
.proc-tab { padding:4px 10px; font-size:11px; border:1px solid #252545; background:#12122a; color:#8888b0; border-radius:3px; cursor:pointer; }
.proc-tab.active { background:#2d1f6e; color:#a78bfa; border-color:#7c3aed44; }
.btn-ref { padding:4px 10px; font-size:16px; border:1px solid #252545; background:#12122a; color:#8888b0; border-radius:3px; cursor:pointer; }
.btn-ref.spin { animation:spin .7s linear infinite; }
@keyframes spin{from{transform:rotate(0)}to{transform:rotate(360deg)}}

/* ── TOOLBAR TC ── */
.tc-bar { display:flex; align-items:center; gap:8px; margin-bottom:10px; flex-wrap:wrap; }
.tc-nav { display:flex; align-items:center; gap:4px; }
.tn { padding:5px 10px; border:1px solid #252545; background:#12122a; color:#a0a0c8; border-radius:3px; cursor:pointer; font-size:11px; }
.tn:hover { background:#1a1a35; color:#e0e0f0; }
.tn-now { font-weight:600; color:#a78bfa; border-color:#7c3aed33; }
.tc-range { font-size:12px; font-family:monospace; color:#a0a0c8; margin-left:6px; white-space:nowrap; }
.tc-pds { display:flex; gap:3px; }
.tpd { padding:5px 10px; font-size:11px; border:1px solid #252545; background:#12122a; color:#8888b0; border-radius:3px; cursor:pointer; }
.tpd.active { background:#2d1f6e; color:#a78bfa; border-color:#7c3aed44; }
.tc-srch { flex:1; min-width:150px; padding:6px 10px; border:1px solid #252545; background:#12122a; color:#e0e0f0; border-radius:3px; font-size:12px; outline:none; }
.tc-srch:focus { border-color:#7c3aed; }
.tc-sel { padding:6px 10px; border:1px solid #252545; background:#12122a; color:#a0a0c8; border-radius:3px; font-size:12px; cursor:pointer; }
.btn-add { padding:6px 14px; background:#2d1f6e; color:#a78bfa; border:1px solid #7c3aed44; font-size:12px; border-radius:3px; cursor:pointer; white-space:nowrap; }
.btn-add:hover { background:#3d2a8a; }

/* ── LÉGENDE ── */
.tc-leg { display:flex; gap:14px; margin-bottom:10px; flex-wrap:wrap; }
.tl { font-size:11px; display:flex; align-items:center; gap:4px; }
.tl-encours { color:#fbbf24; }
.tl-cloture { color:#34d399; }
.tl-arret   { color:#f87171; }
.tl-vide    { color:#3a3a5c; }

/* ── TABLEAU CROISÉ ── */
.tc-scroll { overflow:auto; max-height:calc(100vh - 240px); border:1px solid #1a1a38; border-radius:6px; }
.tc-tbl { border-collapse:collapse; min-width:max-content; width:100%; }

.tc-tbl thead tr { position:sticky; top:0; z-index:5; }
.th-date { position:sticky; left:0; top:0; z-index:6; background:#07071a; padding:8px 12px; text-align:left; font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:.5px; color:#606090; border-right:2px solid #1a1a38; border-bottom:2px solid #1a1a38; min-width:72px; }
.th-at { background:#07071a; padding:8px 10px; text-align:left; border-bottom:2px solid #1a1a38; border-right:1px solid #151530; min-width:140px; max-width:180px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.tha-nom { font-size:11px; font-weight:600; color:#c8c8e8; }
.tha-sub { font-size:9px; color:#5a5a80; margin-top:1px; }

.tc-tbl tbody tr:hover td { background:#101028 !important; }
.tr-today td { background:#111130 !important; }
.tr-today .td-date { border-left:3px solid #7c3aed; }
.tr-we td { background:#0c0c20 !important; }

.td-date { position:sticky; left:0; z-index:2; background:#0d0d22; padding:6px 10px; border-right:2px solid #1a1a38; border-bottom:1px solid #141430; white-space:nowrap; }
.tdd-today { background:#121230 !important; }
.dj { font-size:9px; color:#5a5a80; text-transform:uppercase; letter-spacing:.5px; }
.dd { font-size:12px; font-weight:600; color:#c0c0e0; font-family:monospace; }

.tc-cell { padding:4px 6px; border-bottom:1px solid #141430; border-right:1px solid #151530; vertical-align:top; min-height:36px; height:36px; transition:background .12s; }
.c-vide    { background:#0b0b1c; }
.c-encours { background:#78350f22; border-left:2px solid #f59e0b; }
.c-cloture { background:#064e3b22; border-left:2px solid #10b981; }
.c-arret   { background:#7f1d1d22; border-left:2px solid #ef4444; }
.c-click { cursor:pointer; }
.c-click:hover { filter:brightness(1.3); }
.c-dim { opacity:.2; }

.ci-sf { display:flex; align-items:center; gap:3px; }
.ci-lot { font-size:10px; font-family:monospace; font-weight:600; color:#e0e0f0; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:120px; }
.ci-dot { width:5px; height:5px; border-radius:50%; flex-shrink:0; }
.cid-en-cours { background:#fbbf24; }
.cid-clôturé, .cid-cloture { background:#34d399; }
.cid-arrêt, .cid-arret { background:#f87171; }
.ci-more { font-size:9px; color:#6060a0; }

.ldg { padding:40px; text-align:center; color:#4a4a70; font-size:13px; }

/* ── TOOLBAR TABLES ── */
.t-bar { display:flex; gap:8px; margin-bottom:10px; flex-wrap:wrap; }
.t-srch { flex:1; min-width:150px; padding:6px 10px; border:1px solid #252545; background:#12122a; color:#e0e0f0; border-radius:3px; font-size:12px; outline:none; }
.t-srch:focus { border-color:#7c3aed; }
.t-sel { padding:6px 10px; border:1px solid #252545; background:#12122a; color:#a0a0c8; border-radius:3px; font-size:12px; cursor:pointer; }
.arr-stats { display:flex; gap:10px; margin-left:auto; flex-wrap:wrap; align-items:center; }
.arr-stat { font-size:11px; color:#6060a0; }
.arr-ec { color:#f87171; }

/* ── DARK TABLES ── */
.dt-wrap { overflow-x:auto; border:1px solid #1a1a38; border-radius:6px; }
.dt { width:100%; border-collapse:collapse; font-size:12px; min-width:700px; }
.dt thead tr { position:sticky; top:0; z-index:2; }
.dt th { background:#07071a; padding:8px 10px; text-align:left; font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:.4px; color:#6060a0; border-bottom:2px solid #1a1a38; white-space:nowrap; }
.dt th.srt { cursor:pointer; user-select:none; }
.dt th.srt:hover { background:#0f0f28; color:#a0a0c8; }
.dt td { padding:8px 10px; border-bottom:1px solid #131330; color:#c0c0e0; vertical-align:middle; }
.dt tr:hover td { background:#0f0f28; }
.dt tr.row-en-cours td { background:#1a130022; }
.dt tr.row-arrêt td, .dt tr.row-arret td { background:#1a060622; }
.dt tr.row-clôturé td, .dt tr.row-cloture td { opacity:.7; }
.dt tr.row-actif td { background:#1a060622; }
.si { font-size:9px; color:#4a4a70; }
.mono { font-family:monospace; font-size:11px; }
.sm { font-size:11px; color:#9090b8; max-width:150px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.acts { white-space:nowrap; }
.empty { text-align:center; padding:30px; color:#3a3a60; font-size:13px; }

.prc-chip { font-size:10px; padding:2px 7px; border-radius:3px; font-weight:500; }
.schip { font-size:10px; padding:2px 7px; border-radius:8px; font-weight:500; }
.sc-en-cours { background:#065f4622; color:#34d399; }
.sc-clôturé, .sc-cloture { background:#30303055; color:#9090b8; }
.sc-arrêt, .sc-arret { background:#7f1d1d33; color:#f87171; }
.arr-badge { font-size:10px; background:#78350f33; color:#fbbf24; padding:2px 7px; border-radius:3px; }
.arr-none { color:#3a3a60; }

.ia { background:none; border:none; cursor:pointer; font-size:12px; padding:3px 6px; border-radius:2px; opacity:.7; color:#a0a0c8; }
.ia:hover { background:#1e1e3c; opacity:1; }
.ia.ok { color:#34d399; }
.ia.ok:hover { background:#064e3b33; }
.ia.del { color:#f87171; }
.ia.del:hover { background:#7f1d1d33; }

/* ── MODAL DÉTAIL ── */
.ov { position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,.6); display:flex; align-items:center; justify-content:center; z-index:200; }
.dp { background:#14142e; border:1px solid #2a2a52; border-radius:10px; width:480px; max-width:96vw; max-height:88vh; display:flex; flex-direction:column; box-shadow:0 24px 60px rgba(0,0,0,.6); }
.dp-hd { display:flex; align-items:flex-start; justify-content:space-between; padding:18px 20px 14px; border-bottom:1px solid #1e1e40; }
.dp-eq { font-size:15px; font-weight:700; color:#e0e0f8; }
.dp-date { font-size:12px; color:#7070a0; margin-top:2px; font-family:monospace; }
.dp-x { background:none; border:none; color:#6060a0; font-size:18px; cursor:pointer; line-height:1; padding:2px 6px; }
.dp-x:hover { color:#e0e0f0; }
.dp-body { overflow-y:auto; padding:16px 20px 20px; display:flex; flex-direction:column; gap:12px; }
.dp-sec { }
.dp-stitle { font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:.8px; color:#6060a0; margin-bottom:8px; }
.dp-item { background:#0e0e28; border:1px solid #1c1c3c; border-radius:6px; padding:12px; display:flex; flex-direction:column; gap:5px; margin-bottom:6px; }
.dpi-row { display:flex; align-items:center; justify-content:space-between; }
.dpi-lot { font-family:monospace; font-size:13px; font-weight:700; color:#e0e0f8; }
.dpi-chip { font-size:10px; padding:2px 8px; border-radius:8px; font-weight:500; }
.dchip-en-cours { background:#06402a44; color:#34d399; }
.dchip-clôturé, .dchip-cloture { background:#30303055; color:#9090b8; }
.dchip-arrêt, .dchip-arret { background:#5a050544; color:#f87171; }
.dpi-prod { font-size:11px; color:#8080b0; }
.dpi-meta { font-size:10px; font-family:monospace; color:#5a5a80; }
.dpi-acts { display:flex; gap:6px; margin-top:4px; flex-wrap:wrap; }
.dpi-btn { padding:4px 12px; border:1px solid #252545; background:#1a1a35; color:#a0a0c8; font-size:11px; border-radius:3px; cursor:pointer; }
.dpi-btn:hover { background:#242445; color:#e0e0f0; }
.dpi-btn-ok { border-color:#064e3b44; background:#064e3b22; color:#34d399; }
.dpi-btn-ok:hover { background:#064e3b44; }
.dp-empty { text-align:center; padding:20px; color:#4a4a70; font-size:13px; }

/* ── MODALS FAB / ARRET ── */
.modal { background:#14142e; border:1px solid #2a2a52; border-radius:10px; max-width:96vw; max-height:90vh; overflow:hidden; display:flex; flex-direction:column; box-shadow:0 24px 60px rgba(0,0,0,.6); }
.modal-fab { width:540px; }
.modal-arret { width:460px; }
.modal-hd { display:flex; align-items:center; justify-content:space-between; padding:16px 20px; border-bottom:1px solid #1e1e40; font-weight:600; font-size:13px; color:#e0e0f8; }
.modal-body { padding:20px; overflow-y:auto; display:flex; flex-direction:column; gap:10px; }
.modal-ft { padding:14px 20px; border-top:1px solid #1e1e40; display:flex; justify-content:flex-end; gap:8px; }
.form-row { display:flex; flex-direction:column; gap:4px; }
.form-row-2 { display:grid; grid-template-columns:1fr 1fr; gap:12px; }
.form-fld { display:flex; flex-direction:column; gap:4px; }
.lbl { font-size:10px; font-weight:600; color:#6060a0; text-transform:uppercase; letter-spacing:.5px; }
.inp { padding:7px 10px; border:1px solid #252545; background:#0e0e28; color:#e0e0f0; border-radius:3px; font-size:13px; font-family:inherit; width:100%; box-sizing:border-box; outline:none; }
.inp:focus { border-color:#7c3aed; }
.form-ta { resize:vertical; }
.err { color:#f87171; font-size:12px; padding:6px 10px; background:#7f1d1d22; border-radius:3px; border:1px solid #f8717133; }
.sel-lot-info { font-size:11px; color:#34d399; padding:4px 8px; background:#064e3b22; border-radius:3px; border:1px solid #34d39933; }
.lot-ac { position:relative; }
.auto-list { position:absolute; top:100%; left:0; right:0; background:#14142e; border:1px solid #2a2a52; border-radius:4px; box-shadow:0 8px 24px rgba(0,0,0,.5); z-index:10; max-height:180px; overflow-y:auto; }
.auto-item { display:flex; gap:8px; padding:7px 10px; cursor:pointer; font-size:12px; border-bottom:1px solid #1a1a38; }
.auto-item:hover { background:#1a1a38; }
.auto-code { font-family:monospace; font-weight:600; color:#a78bfa; min-width:70px; }
.auto-desc { color:#8080b0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.arr-lot-info { display:flex; gap:8px; align-items:center; padding:8px 12px; background:#0e0e28; border-radius:4px; border:1px solid #1c1c3c; }
.btn-cancel { padding:7px 16px; border:1px solid #252545; border-radius:3px; background:#1a1a35; color:#8080b0; font-size:13px; cursor:pointer; }
.btn-cancel:hover { background:#222240; }
.btn-save { padding:7px 20px; border:none; border-radius:3px; background:#2d1f6e; color:#a78bfa; font-size:13px; cursor:pointer; font-weight:500; }
.btn-save:hover { background:#3d2a8a; }
.btn-save:disabled { opacity:.4; cursor:not-allowed; }

@media(max-width:768px){
  .tc-bar { flex-direction:column; align-items:flex-start; }
  .tc-srch { width:100%; }
  .form-row-2 { grid-template-columns:1fr; }
  .arr-stats { margin-left:0; }
}

/* ══════════════════════════════════════════
   THÈME JOUR ☀️
══════════════════════════════════════════ */
.pdpf[data-theme="day"] { background:#f0f2f5; color:#1a1a2e; }
.pdpf[data-theme="day"] .ph { border-bottom-color:#d8dce8; }
.pdpf[data-theme="day"] .pt { color:#5a5a8a; }
.pdpf[data-theme="day"] .vtab { background:#e4e7f0; color:#555; border-color:#c8ccd8; }
.pdpf[data-theme="day"] .vtab:hover { background:#d8dcea; color:#333; }
.pdpf[data-theme="day"] .vtab.active { background:#7c3aed; color:#fff; border-color:#7c3aed; }
.pdpf[data-theme="day"] .proc-tab { background:#e4e7f0; color:#555; border-color:#c8ccd8; }
.pdpf[data-theme="day"] .proc-tab.active { background:#7c3aed; color:#fff; border-color:#7c3aed; }
.pdpf[data-theme="day"] .btn-ref { background:#e4e7f0; color:#666; border-color:#c8ccd8; }
.pdpf[data-theme="day"] .tn { background:#e4e7f0; color:#555; border-color:#c8ccd8; }
.pdpf[data-theme="day"] .tn:hover { background:#d8dcea; color:#333; }
.pdpf[data-theme="day"] .tn-now { color:#7c3aed; border-color:#7c3aed33; }
.pdpf[data-theme="day"] .tc-range { color:#777; }
.pdpf[data-theme="day"] .tpd { background:#e4e7f0; color:#555; border-color:#c8ccd8; }
.pdpf[data-theme="day"] .tpd.active { background:#7c3aed; color:#fff; border-color:#7c3aed; }
.pdpf[data-theme="day"] .tc-srch { background:#fff; color:#1a1a2e; border-color:#c8ccd8; }
.pdpf[data-theme="day"] .tc-sel { background:#fff; color:#555; border-color:#c8ccd8; }
.pdpf[data-theme="day"] .btn-add { background:#7c3aed; color:#fff; border-color:#7c3aed; }
.pdpf[data-theme="day"] .tc-leg .tl-vide { color:#bbb; }
.pdpf[data-theme="day"] .tc-scroll { border-color:#d8dce8; }
.pdpf[data-theme="day"] .th-date { background:#e8eaf3; color:#888; border-right-color:#d8dce8; border-bottom-color:#d8dce8; }
.pdpf[data-theme="day"] .th-eq { background:#e8eaf3; border-bottom-color:#d8dce8; border-right-color:#dde1ec; }
.pdpf[data-theme="day"] .the-nom { color:#333; }
.pdpf[data-theme="day"] .the-sub { color:#aaa; }
.pdpf[data-theme="day"] .tc-tbl tbody tr:hover td { background:#e0e5f0 !important; }
.pdpf[data-theme="day"] .tr-today td { background:#f0eaff !important; }
.pdpf[data-theme="day"] .tr-today .td-date { border-left-color:#7c3aed; }
.pdpf[data-theme="day"] .tr-we td { background:#ebebf3 !important; }
.pdpf[data-theme="day"] .td-date { background:#eceef5; border-right-color:#d8dce8; border-bottom-color:#e4e7f0; }
.pdpf[data-theme="day"] .tdd-today { background:#f0eaff !important; }
.pdpf[data-theme="day"] .dj { color:#bbb; }
.pdpf[data-theme="day"] .dd { color:#333; }
.pdpf[data-theme="day"] .tc-cell { border-bottom-color:#e4e7f0; border-right-color:#e4e7f0; }
.pdpf[data-theme="day"] .c-vide { background:#f5f6f9; }
.pdpf[data-theme="day"] .c-planifie { background:#dbeafe; border-left-color:#3b82f6; }
.pdpf[data-theme="day"] .c-encours  { background:#fef3c7; border-left-color:#f59e0b; }
.pdpf[data-theme="day"] .c-cloture  { background:#d1fae5; border-left-color:#10b981; }
.pdpf[data-theme="day"] .c-retard   { background:#fee2e2; border-left-color:#ef4444; }
.pdpf[data-theme="day"] .ci-lot { color:#1a1a2e; }
.pdpf[data-theme="day"] .ci-more { color:#bbb; }
.pdpf[data-theme="day"] .dp { background:#fff; border-color:#d8dce8; box-shadow:0 12px 40px rgba(0,0,0,.15); }
.pdpf[data-theme="day"] .dp-hd { border-bottom-color:#eee; }
.pdpf[data-theme="day"] .dp-eq { color:#1a1a2e; }
.pdpf[data-theme="day"] .dp-date { color:#aaa; }
.pdpf[data-theme="day"] .dp-x { color:#ccc; }
.pdpf[data-theme="day"] .dp-x:hover { color:#333; }
.pdpf[data-theme="day"] .dp-stitle { color:#bbb; }
.pdpf[data-theme="day"] .dp-item { background:#f5f6f9; border-color:#e4e7f0; }
.pdpf[data-theme="day"] .dpi-lot { color:#1a1a2e; }
.pdpf[data-theme="day"] .dpi-prod { color:#777; }
.pdpf[data-theme="day"] .dpi-meta { color:#bbb; }
.pdpf[data-theme="day"] .dpi-btn { background:#eee; color:#555; border-color:#ddd; }
.pdpf[data-theme="day"] .dpi-btn:hover { background:#e0e0e0; color:#333; }
.pdpf[data-theme="day"] .dpi-btn-ok { background:#d1fae5; color:#059669; border-color:#6ee7b744; }
.pdpf[data-theme="day"] .dp-empty { color:#ccc; }
.pdpf[data-theme="day"] .dt-wrap { border-color:#d8dce8; }
.pdpf[data-theme="day"] .dt th { background:#e8eaf3; color:#888; border-bottom-color:#d8dce8; }
.pdpf[data-theme="day"] .dt th.srt:hover { background:#dde1ec; color:#555; }
.pdpf[data-theme="day"] .dt td { color:#444; border-bottom-color:#eee; }
.pdpf[data-theme="day"] .dt tr:hover td { background:#eceff5; }
.pdpf[data-theme="day"] .t-srch { background:#fff; color:#1a1a2e; border-color:#c8ccd8; }
.pdpf[data-theme="day"] .t-sel { background:#fff; color:#555; border-color:#c8ccd8; }
.pdpf[data-theme="day"] .empty { color:#ccc; }
.pdpf[data-theme="day"] .si { color:#aaa; }
.pdpf[data-theme="day"] .sm { color:#888; }
.pdpf[data-theme="day"] .modal { background:#fff; border-color:#d8dce8; box-shadow:0 16px 48px rgba(0,0,0,.18); }
.pdpf[data-theme="day"] .modal-hd { color:#1a1a2e; border-bottom-color:#eee; }
.pdpf[data-theme="day"] .modal-body { background:#fff; }
.pdpf[data-theme="day"] .modal-ft { border-top-color:#eee; }
.pdpf[data-theme="day"] .inp { background:#fff; border-color:#c8ccd8; color:#1a1a2e; }
.pdpf[data-theme="day"] .inp:focus { border-color:#7c3aed; }
.pdpf[data-theme="day"] .lbl { color:#999; }
.pdpf[data-theme="day"] .btn-save { background:#7c3aed; color:#fff; }
.pdpf[data-theme="day"] .btn-save:hover { background:#6d28d9; }
.pdpf[data-theme="day"] .btn-cancel { background:#f0f0f0; color:#666; border-color:#ccc; }
.pdpf[data-theme="day"] .btn-cancel:hover { background:#e0e0e0; }
.pdpf[data-theme="day"] .auto-list { background:#fff; border-color:#c8ccd8; box-shadow:0 4px 16px rgba(0,0,0,.1); }
.pdpf[data-theme="day"] .auto-item { border-bottom-color:#f0f0f0; }
.pdpf[data-theme="day"] .auto-item:hover { background:#f5f5f8; }
.pdpf[data-theme="day"] .err { background:#FEF2F2; color:#c53030; border-color:#fca5a5; }
.pdpf[data-theme="day"] .ldg { color:#ccc; }
.pdpf[data-theme="day"] .arr-badge { background:#fef3c744; color:#b45309; }
.pdpf[data-theme="day"] .arr-none { color:#ccc; }
.pdpf[data-theme="day"] .arr-stat { color:#aaa; }

/* ══════════════════════════════════════════
   THÈME ATELIER 🏭
══════════════════════════════════════════ */
.pdpf[data-theme="workshop"] { background:#161616; color:#f0f0f0; }
.pdpf[data-theme="workshop"] .ph { border-bottom-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .pt { color:#aaaaaa; letter-spacing:2px; }
.pdpf[data-theme="workshop"] .vtab { background:#1e1e1e; color:#aaa; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .vtab:hover { background:#252525; color:#fff; }
.pdpf[data-theme="workshop"] .vtab.active { background:#ff9800; color:#000; border-color:#ff9800; font-weight:700; }
.pdpf[data-theme="workshop"] .proc-tab { background:#1e1e1e; color:#aaa; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .proc-tab.active { background:#00c853; color:#000; font-weight:700; border-color:#00c853; }
.pdpf[data-theme="workshop"] .btn-ref { background:#1e1e1e; color:#aaa; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .tn { background:#1e1e1e; color:#ccc; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .tn:hover { background:#252525; color:#fff; }
.pdpf[data-theme="workshop"] .tn-now { color:#00c853; border-color:#00c85344; }
.pdpf[data-theme="workshop"] .tc-range { color:#888; }
.pdpf[data-theme="workshop"] .tpd { background:#1e1e1e; color:#aaa; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .tpd.active { background:#ff9800; color:#000; border-color:#ff9800; font-weight:700; }
.pdpf[data-theme="workshop"] .tc-srch { background:#1e1e1e; color:#f0f0f0; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .tc-sel { background:#1e1e1e; color:#ccc; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .btn-add { background:#152200; color:#00c853; border-color:#00c85333; }
.pdpf[data-theme="workshop"] .tc-leg .tl-planifie { color:#29b6f6; }
.pdpf[data-theme="workshop"] .tc-leg .tl-encours  { color:#ff9800; }
.pdpf[data-theme="workshop"] .tc-leg .tl-cloture  { color:#00c853; }
.pdpf[data-theme="workshop"] .tc-leg .tl-retard   { color:#ff3d3d; }
.pdpf[data-theme="workshop"] .tc-leg .tl-vide { color:#444; }
.pdpf[data-theme="workshop"] .tc-scroll { border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .th-date { background:#0e0e0e; color:#555; border-right-color:#2a2a2a; border-bottom-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .th-eq { background:#0e0e0e; border-bottom-color:#2a2a2a; border-right-color:#1e1e1e; }
.pdpf[data-theme="workshop"] .the-nom { color:#f0f0f0; font-weight:700; }
.pdpf[data-theme="workshop"] .the-sub { color:#555; }
.pdpf[data-theme="workshop"] .tc-tbl tbody tr:hover td { background:#1e1e1e !important; }
.pdpf[data-theme="workshop"] .tr-today td { background:#1a1200 !important; }
.pdpf[data-theme="workshop"] .tr-today .td-date { border-left-color:#ff9800; }
.pdpf[data-theme="workshop"] .tr-we td { background:#111 !important; }
.pdpf[data-theme="workshop"] .td-date { background:#131313; border-right-color:#2a2a2a; border-bottom-color:#1e1e1e; }
.pdpf[data-theme="workshop"] .tdd-today { background:#1a1200 !important; }
.pdpf[data-theme="workshop"] .dj { color:#555; }
.pdpf[data-theme="workshop"] .dd { color:#f0f0f0; font-weight:700; }
.pdpf[data-theme="workshop"] .tc-cell { border-bottom-color:#1e1e1e; border-right-color:#1e1e1e; }
.pdpf[data-theme="workshop"] .c-vide { background:#161616; }
.pdpf[data-theme="workshop"] .c-planifie { background:#002030; border-left-color:#29b6f6; }
.pdpf[data-theme="workshop"] .c-encours  { background:#1f1000; border-left-color:#ff9800; }
.pdpf[data-theme="workshop"] .c-cloture  { background:#001a08; border-left-color:#00c853; }
.pdpf[data-theme="workshop"] .c-retard   { background:#1a0000; border-left-color:#ff3d3d; }
.pdpf[data-theme="workshop"] .ci-lot { color:#ffffff; font-weight:700; }
.pdpf[data-theme="workshop"] .ci-more { color:#555; }
.pdpf[data-theme="workshop"] .dp { background:#1c1c1c; border-color:#2a2a2a; box-shadow:0 24px 60px rgba(0,0,0,.8); }
.pdpf[data-theme="workshop"] .dp-hd { border-bottom-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .dp-eq { color:#fff; }
.pdpf[data-theme="workshop"] .dp-date { color:#666; }
.pdpf[data-theme="workshop"] .dp-x { color:#666; }
.pdpf[data-theme="workshop"] .dp-x:hover { color:#fff; }
.pdpf[data-theme="workshop"] .dp-stitle { color:#666; }
.pdpf[data-theme="workshop"] .dp-item { background:#111; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .dpi-lot { color:#fff; font-weight:700; }
.pdpf[data-theme="workshop"] .dpi-prod { color:#888; }
.pdpf[data-theme="workshop"] .dpi-meta { color:#555; }
.pdpf[data-theme="workshop"] .dpi-btn { background:#222; color:#ccc; border-color:#333; }
.pdpf[data-theme="workshop"] .dpi-btn:hover { background:#2a2a2a; color:#fff; }
.pdpf[data-theme="workshop"] .dpi-btn-ok { background:#001a08; color:#00c853; border-color:#00c85333; }
.pdpf[data-theme="workshop"] .dp-empty { color:#444; }
.pdpf[data-theme="workshop"] .dt-wrap { border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .dt th { background:#0e0e0e; color:#00c853; border-bottom-color:#2a2a2a; font-weight:700; }
.pdpf[data-theme="workshop"] .dt th.srt:hover { background:#171717; }
.pdpf[data-theme="workshop"] .dt td { color:#e0e0e0; border-bottom-color:#1e1e1e; }
.pdpf[data-theme="workshop"] .dt tr:hover td { background:#1c1c1c; }
.pdpf[data-theme="workshop"] .t-srch { background:#1e1e1e; color:#f0f0f0; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .t-sel { background:#1e1e1e; color:#ccc; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .empty { color:#444; }
.pdpf[data-theme="workshop"] .si { color:#555; }
.pdpf[data-theme="workshop"] .sm { color:#777; }
.pdpf[data-theme="workshop"] .modal { background:#1c1c1c; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .modal-hd { color:#fff; border-bottom-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .modal-ft { border-top-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .inp { background:#111; border-color:#2a2a2a; color:#f0f0f0; }
.pdpf[data-theme="workshop"] .inp:focus { border-color:#ff9800; }
.pdpf[data-theme="workshop"] .lbl { color:#666; }
.pdpf[data-theme="workshop"] .btn-save { background:#152200; color:#00c853; }
.pdpf[data-theme="workshop"] .btn-save:hover { background:#1c2e00; }
.pdpf[data-theme="workshop"] .btn-cancel { background:#1e1e1e; color:#888; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .auto-list { background:#1c1c1c; border-color:#2a2a2a; }
.pdpf[data-theme="workshop"] .auto-item { border-bottom-color:#1e1e1e; }
.pdpf[data-theme="workshop"] .auto-item:hover { background:#222; }
.pdpf[data-theme="workshop"] .err { background:#2a0000; color:#ff6b6b; border-color:#ff3d3d44; }
.pdpf[data-theme="workshop"] .ldg { color:#444; }
.pdpf[data-theme="workshop"] .arr-badge { background:#1f100033; color:#ff9800; }
.pdpf[data-theme="workshop"] .arr-ec { color:#ff3d3d; }
.pdpf[data-theme="workshop"] .arr-stat { color:#666; }
</style>
