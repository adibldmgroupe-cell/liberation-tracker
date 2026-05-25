<template>
  <div class="pdp-fab">
    <!-- ── HEADER ── -->
    <div class="ph">
      <div class="ph-left">
        <span class="pt">PDP FABRICATION</span>
        <div class="view-tabs">
          <button v-for="v in views" :key="v.key" class="vtab" :class="{active:activeView===v.key}" @click="activeView=v.key">
            <span class="vtab-icon">{{v.icon}}</span>{{v.label}}
          </button>
        </div>
      </div>
      <div class="ph-right">
        <div class="proc-tabs">
          <button v-for="p in ['Tous',...processus.map(x=>x.nom_process)]" :key="p" class="proc-tab"
            :class="{active:filterProc===p}" @click="filterProc=p">{{p}}</button>
        </div>
        <button class="btn-refresh" @click="loadAll" :class="{spinning:loading}">↻</button>
      </div>
    </div>

    <div v-if="loading && !ateliers.length" class="loading">Chargement…</div>

    <!-- ════════════════════════════════════════
         VUE 1 — ATELIERS (cards)
    ════════════════════════════════════════ -->
    <div v-show="activeView==='ateliers'" class="ateliers-grid">
      <div v-for="at in filteredAteliers" :key="at.id" class="at-card" :class="atClass(at)">
        <div class="at-hd" :style="{borderTopColor: procColor(at.processus_id)}">
          <div>
            <div class="at-nom">{{at.nom_atelier}}</div>
            <div class="at-proc">{{getProcNom(at.processus_id)}}</div>
          </div>
          <div class="at-badge" :style="{background:procColor(at.processus_id)+'22',color:procColor(at.processus_id)}">
            {{getActiveCount(at.id)}} lot{{getActiveCount(at.id)>1?'s':''}} actif{{getActiveCount(at.id)>1?'s':''}}
          </div>
        </div>

        <!-- Lots actifs dans cet atelier -->
        <div class="at-lots">
          <div v-for="sf in getActiveFab(at.id)" :key="sf.id" class="at-lot-row">
            <div class="alr-left">
              <div class="alr-num">Lot {{sf.lots?.numero_lot||sf.lot_id}}</div>
              <div class="alr-prod">{{sf.lots?.products?.nom_produit||'—'}}</div>
            </div>
            <div class="alr-mid">
              <span class="alr-statut" :class="'st-'+sf.statut.toLowerCase().replace(/\s/g,'-')">{{sf.statut}}</span>
              <span class="alr-dur">{{elapsedFab(sf)}}</span>
            </div>
            <div class="alr-right">
              <button class="btn-sm" @click="openArretAtelier(sf)" title="Déclarer arrêt">⏸</button>
              <button class="btn-sm btn-ok" @click="clotureAtelier(sf)" title="Clôturer">✓</button>
            </div>
          </div>
          <div v-if="!getActiveFab(at.id).length" class="at-empty">Aucun lot en cours</div>
        </div>

        <!-- Arrêts actifs -->
        <div class="at-arrets" v-if="getActiveArrets(at.id).length">
          <div class="at-arrets-title">⚠ Arrêts en cours</div>
          <div v-for="arr in getActiveArrets(at.id)" :key="arr.id" class="arr-row">
            <span class="arr-motif">{{arr.motif}}</span>
            <span class="arr-dur">{{elapsedArret(arr)}}</span>
            <button class="btn-sm btn-ok" @click="closeArretAtelier(arr)">✓ Lever</button>
          </div>
        </div>

        <!-- Actions -->
        <div class="at-actions">
          <button class="btn-act" @click="openFabModal(null, at.id)">+ Suivi lot</button>
          <button class="btn-act btn-sec" @click="activeView='lotfab'; filterAtelier=at.id">Historique</button>
        </div>
      </div>
    </div>

    <!-- ════════════════════════════════════════
         VUE 2 — GANTT PDP FABRICATION
    ════════════════════════════════════════ -->
    <div v-show="activeView==='gantt'" class="gantt-wrap">
      <div class="gantt-toolbar">
        <div class="gantt-period-btns">
          <button v-for="p in ganttPeriods" :key="p.key" class="gp-btn" :class="{active:ganttPeriod===p.key}" @click="ganttPeriod=p.key;buildGantt()">{{p.label}}</button>
        </div>
        <div class="gantt-nav">
          <button class="gnav" @click="ganttOffset--;buildGantt()">◀</button>
          <button class="gnav gnav-today" @click="ganttOffset=0;buildGantt()">Aujourd'hui</button>
          <button class="gnav" @click="ganttOffset++;buildGantt()">▶</button>
        </div>
        <div class="gantt-legend">
          <span class="gl-item"><span class="gl-dot" style="background:#3b82f6"></span>Planifié</span>
          <span class="gl-item"><span class="gl-dot" style="background:#10b981"></span>En cours</span>
          <span class="gl-item"><span class="gl-dot" style="background:#6366f1"></span>Clôturé</span>
          <span class="gl-item"><span class="gl-dot" style="background:#ef4444"></span>Arrêt</span>
        </div>
      </div>

      <div class="gantt-body" ref="ganttEl">
        <!-- Header dates -->
        <div class="gantt-hd-row">
          <div class="gantt-label-cell">Lot / Atelier</div>
          <div class="gantt-dates-cell">
            <div class="gantt-dates" :style="{width: ganttTotalW+'px'}">
              <div v-for="grp in ganttGroups" :key="grp.label" class="gantt-grp-hd"
                :style="{left:grp.left+'px',width:grp.width+'px'}">{{grp.label}}</div>
              <div v-for="(d,i) in ganttDays" :key="i" class="gantt-day-hd"
                :style="{left:i*ganttDayW+'px',width:ganttDayW+'px'}"
                :class="{today:d.isToday,weekend:d.isWeekend}">{{d.label}}</div>
            </div>
          </div>
        </div>

        <!-- Rows par lot en fab -->
        <div v-for="sf in ganttSuivis" :key="sf.id" class="gantt-row">
          <div class="gantt-label-cell">
            <div class="gantt-lot-nom">Lot {{sf.lots?.numero_lot||sf.lot_id}}</div>
            <div class="gantt-lot-sub">{{sf.lots?.products?.nom_produit||'—'}} · {{getAtelierNom(sf.atelier_id)}}</div>
          </div>
          <div class="gantt-dates-cell">
            <div class="gantt-track" :style="{width: ganttTotalW+'px'}">
              <!-- Today line -->
              <div class="gantt-today-line" v-if="todayOffset>=0" :style="{left:todayOffset*ganttDayW+'px'}"></div>
              <!-- Bars -->
              <div v-for="bar in getFabBars(sf)" :key="bar.key"
                class="gantt-bar"
                :style="{left:bar.left+'px',width:bar.width+'px',background:bar.color}"
                :title="bar.title">
                <span class="gantt-bar-lbl">{{bar.label}}</span>
              </div>
            </div>
          </div>
        </div>
        <div v-if="!ganttSuivis.length" class="gantt-empty">Aucun suivi fabrication sur la période</div>
      </div>
    </div>

    <!-- ════════════════════════════════════════
         VUE 3 — SUIVI LOTS FAB (table)
    ════════════════════════════════════════ -->
    <div v-show="activeView==='lotfab'" class="lotfab-wrap">
      <div class="sf-toolbar">
        <input class="sf-search" v-model="sfSearch" placeholder="Rechercher lot, produit…">
        <select class="sf-sel" v-model="filterAtelier">
          <option value="">Tous les ateliers</option>
          <option v-for="at in ateliers" :key="at.id" :value="at.id">{{at.nom_atelier}}</option>
        </select>
        <select class="sf-sel" v-model="sfStatut">
          <option value="">Tous statuts</option>
          <option>En cours</option>
          <option>Clôturé</option>
          <option>Arrêt</option>
        </select>
        <select class="sf-sel" v-model="sfProc">
          <option value="">Tous processus</option>
          <option v-for="p in processus" :key="p.id" :value="p.id">{{p.nom_process}}</option>
        </select>
        <button class="btn-act" @click="openFabModal(null, null)">+ Nouveau suivi</button>
      </div>

      <table class="sf-table">
        <thead>
          <tr>
            <th @click="sfSort('lots.numero_lot')" class="sortable">Lot <span class="sort-ic">{{sfSortIc('lots.numero_lot')}}</span></th>
            <th @click="sfSort('lots.products.nom_produit')" class="sortable">Produit <span class="sort-ic">{{sfSortIc('lots.products.nom_produit')}}</span></th>
            <th @click="sfSort('nom_atelier')" class="sortable">Atelier <span class="sort-ic">{{sfSortIc('nom_atelier')}}</span></th>
            <th>Processus</th>
            <th @click="sfSort('date_debut')" class="sortable">Début <span class="sort-ic">{{sfSortIc('date_debut')}}</span></th>
            <th @click="sfSort('date_fin')" class="sortable">Fin <span class="sort-ic">{{sfSortIc('date_fin')}}</span></th>
            <th>Durée</th>
            <th @click="sfSort('statut')" class="sortable">Statut <span class="sort-ic">{{sfSortIc('statut')}}</span></th>
            <th>Arrêts</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="sf in filteredSuivis" :key="sf.id" :class="'row-'+sf.statut.toLowerCase().replace(/\s/g,'-')">
            <td class="td-mono">{{sf.lots?.numero_lot||sf.lot_id}}</td>
            <td>{{sf.lots?.products?.nom_produit||'—'}}</td>
            <td>{{getAtelierNom(sf.atelier_id)}}</td>
            <td><span class="proc-chip" :style="{background:procColor(sf.processus_id)+'22',color:procColor(sf.processus_id)}">{{getProcNom(sf.processus_id)}}</span></td>
            <td class="td-mono">{{fmtDate(sf.date_debut)}}</td>
            <td class="td-mono">{{fmtDate(sf.date_fin)||'—'}}</td>
            <td class="td-mono">{{calcDuree(sf)}}</td>
            <td><span class="statut-chip" :class="'sc-'+sf.statut.toLowerCase().replace(/\s/g,'-')">{{sf.statut}}</span></td>
            <td>
              <span v-if="getArretCount(sf.id)" class="arr-badge">{{getArretCount(sf.id)}} arrêt{{getArretCount(sf.id)>1?'s':''}}</span>
              <span v-else class="arr-none">—</span>
            </td>
            <td class="td-acts">
              <button class="btn-sm" @click="openFabModal(sf, sf.atelier_id)" title="Modifier">✏</button>
              <button class="btn-sm" @click="openArretAtelier(sf)" title="Arrêt" v-if="sf.statut==='En cours'">⏸</button>
              <button class="btn-sm btn-ok" @click="clotureAtelier(sf)" title="Clôturer" v-if="sf.statut==='En cours'||sf.statut==='Arrêt'">✓</button>
              <button class="btn-sm btn-del" @click="deleteFab(sf)" title="Supprimer">✕</button>
            </td>
          </tr>
          <tr v-if="!filteredSuivis.length"><td colspan="10" class="no-data">Aucun suivi trouvé</td></tr>
        </tbody>
      </table>
    </div>

    <!-- ════════════════════════════════════════
         VUE 4 — ARRÊTS ATELIERS
    ════════════════════════════════════════ -->
    <div v-show="activeView==='arrets'" class="arrets-wrap">
      <div class="arr-toolbar">
        <input class="sf-search" v-model="arrSearch" placeholder="Rechercher motif, lot…">
        <select class="sf-sel" v-model="arrFilterAt">
          <option value="">Tous les ateliers</option>
          <option v-for="at in ateliers" :key="at.id" :value="at.id">{{at.nom_atelier}}</option>
        </select>
        <select class="sf-sel" v-model="arrFilterStatut">
          <option value="">Tous</option>
          <option value="actif">En cours</option>
          <option value="cloture">Clôturés</option>
        </select>
        <div class="arr-stats">
          <span class="arr-stat">Total : <b>{{arretAtelier.length}}</b></span>
          <span class="arr-stat arr-en-cours">En cours : <b>{{arretAtelier.filter(a=>!a.heure_fin).length}}</b></span>
          <span class="arr-stat">Durée moy. : <b>{{avgArretDuree}}</b></span>
        </div>
      </div>

      <table class="sf-table">
        <thead>
          <tr>
            <th>Lot</th>
            <th>Atelier</th>
            <th @click="arrSort('motif')" class="sortable">Motif <span class="sort-ic">{{arrSortIc('motif')}}</span></th>
            <th @click="arrSort('heure_debut')" class="sortable">Début <span class="sort-ic">{{arrSortIc('heure_debut')}}</span></th>
            <th>Fin</th>
            <th @click="arrSort('duree')" class="sortable">Durée <span class="sort-ic">{{arrSortIc('duree')}}</span></th>
            <th>Statut</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="arr in filteredArrets" :key="arr.id" :class="arr.heure_fin?'':'row-actif'">
            <td class="td-mono">{{getLotNum(arr.lot_id)}}</td>
            <td>{{getAtelierNom(arr.atelier_id)}}</td>
            <td>{{arr.motif}}</td>
            <td class="td-mono">{{fmtDateTime(arr.heure_debut)}}</td>
            <td class="td-mono">{{arr.heure_fin?fmtDateTime(arr.heure_fin):'En cours'}}</td>
            <td class="td-mono">{{arretDuree(arr)}}</td>
            <td>
              <span :class="arr.heure_fin?'statut-chip sc-cloture':'statut-chip sc-en-cours'">{{arr.heure_fin?'Clôturé':'En cours'}}</span>
            </td>
            <td class="td-acts">
              <button v-if="!arr.heure_fin" class="btn-sm btn-ok" @click="closeArretAtelier(arr)">✓ Lever</button>
              <button class="btn-sm btn-del" @click="deleteArret(arr)">✕</button>
            </td>
          </tr>
          <tr v-if="!filteredArrets.length"><td colspan="8" class="no-data">Aucun arrêt trouvé</td></tr>
        </tbody>
      </table>
    </div>

    <!-- ══════════════════════════════════════════════
         MODAL — NOUVEAU / EDIT SUIVI FAB
    ══════════════════════════════════════════════ -->
    <div v-if="fabModal.open" class="modal-overlay" @click.self="fabModal.open=false">
      <div class="modal modal-fab">
        <div class="modal-hd">
          <span>{{fabModal.id?'Modifier suivi':'Nouveau suivi fabrication'}}</span>
          <button class="modal-close" @click="fabModal.open=false">✕</button>
        </div>
        <div class="modal-body">
          <div class="form-row">
            <label>Lot *</label>
            <div class="lot-ac">
              <input class="form-inp" v-model="fabModal.lotSearch" @input="searchLots" placeholder="N° lot ou produit…">
              <div class="lot-suggestions" v-if="lotSuggestions.length">
                <div v-for="l in lotSuggestions" :key="l.id" class="lot-sug" @click="selectLot(l)">
                  <span class="ls-num">{{l.numero_lot}}</span>
                  <span class="ls-prod">{{l.products?.nom_produit}}</span>
                  <span class="ls-qty">{{l.quantite_prevue}} u.</span>
                </div>
              </div>
            </div>
            <div v-if="fabModal.lotId" class="lot-selected">
              ✓ Lot {{fabModal.lotNum}} — {{fabModal.lotProd}}
            </div>
          </div>

          <div class="form-row">
            <label>Atelier *</label>
            <select class="form-inp" v-model="fabModal.atelierId" @change="onAtelierChange">
              <option value="">— Choisir —</option>
              <option v-for="at in ateliers" :key="at.id" :value="at.id">{{at.nom_atelier}} ({{getProcNom(at.processus_id)}})</option>
            </select>
          </div>

          <div class="form-row">
            <label>Processus *</label>
            <select class="form-inp" v-model="fabModal.processusId">
              <option value="">— Choisir —</option>
              <option v-for="p in processus" :key="p.id" :value="p.id">{{p.nom_process}}</option>
            </select>
          </div>

          <div class="form-row-2">
            <div class="form-row">
              <label>Date/heure début *</label>
              <input type="datetime-local" class="form-inp" v-model="fabModal.dateDebut">
            </div>
            <div class="form-row">
              <label>Date/heure fin</label>
              <input type="datetime-local" class="form-inp" v-model="fabModal.dateFin">
            </div>
          </div>

          <div class="form-row">
            <label>Statut</label>
            <select class="form-inp" v-model="fabModal.statut">
              <option>En cours</option>
              <option>Clôturé</option>
              <option>Arrêt</option>
            </select>
          </div>

          <div v-if="fabModal.err" class="form-err">{{fabModal.err}}</div>
        </div>
        <div class="modal-ft">
          <button class="btn-cancel" @click="fabModal.open=false">Annuler</button>
          <button class="btn-save" @click="saveFab" :disabled="fabModal.saving">{{fabModal.saving?'…':'Enregistrer'}}</button>
        </div>
      </div>
    </div>

    <!-- ══════════════════════════════════════════════
         MODAL — ARRÊT ATELIER
    ══════════════════════════════════════════════ -->
    <div v-if="arretModal.open" class="modal-overlay" @click.self="arretModal.open=false">
      <div class="modal modal-arret">
        <div class="modal-hd">
          <span>Déclarer arrêt — {{getAtelierNom(arretModal.atelierId)}}</span>
          <button class="modal-close" @click="arretModal.open=false">✕</button>
        </div>
        <div class="modal-body">
          <div class="arr-lot-info">
            <span class="alr-num">Lot {{arretModal.lotNum}}</span>
            <span class="alr-prod">{{arretModal.lotProd}}</span>
          </div>
          <div class="form-row">
            <label>Motif de l'arrêt *</label>
            <textarea class="form-inp form-ta" v-model="arretModal.motif" rows="3" placeholder="Décrire la cause de l'arrêt…"></textarea>
          </div>
          <div class="form-row">
            <label>Heure de début</label>
            <input type="datetime-local" class="form-inp" v-model="arretModal.heureDebut">
          </div>
          <div v-if="arretModal.err" class="form-err">{{arretModal.err}}</div>
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

export default {
  setup() {
    // ─── STATE ────────────────────────────────────────────────
    var loading = ref(false)
    var activeView = ref('ateliers')
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

    // Gantt
    var ganttPeriod = ref('1mois')
    var ganttOffset = ref(0)
    var ganttDays = ref([])
    var ganttGroups = ref([])
    var ganttDayW = 28
    var ganttTotalW = ref(0)
    var todayOffset = ref(-1)
    var ganttEl = ref(null)
    var ganttPeriods = [
      { key:'2sem', label:'2 semaines' },
      { key:'1mois', label:'1 mois' },
      { key:'3mois', label:'3 mois' },
    ]

    // Timers
    var fabTimers = ref({})
    var arretTimers = ref({})
    var now = ref(Date.now())
    var tickInt = null

    // Modals
    var fabModal = ref({
      open:false, id:null, lotId:null, lotNum:'', lotProd:'', lotSearch:'',
      atelierId:'', processusId:'', dateDebut:'', dateFin:'', statut:'En cours',
      err:'', saving:false
    })
    var arretModal = ref({
      open:false, fabId:null, lot_id:null, lotNum:'', lotProd:'',
      atelierId:null, motif:'', heureDebut:'', err:'', saving:false
    })
    var lotSuggestions = ref([])

    // ─── LOAD ─────────────────────────────────────────────────
    var loadAll = async function() {
      loading.value = true
      var [r1,r2,r3,r4] = await Promise.all([
        supabase.from('processus').select('*').eq('actif',true).order('ordre'),
        supabase.from('ateliers').select('*').eq('actif',true).order('nom_atelier'),
        supabase.from('suivi_fabrication')
          .select('*, lots(id,numero_lot,quantite_prevue,products(nom_produit))')
          .is('deleted_at',null)
          .order('date_debut',{ascending:false}),
        supabase.from('atelier_arrets')
          .select('*')
          .is('deleted_at',null)
          .order('heure_debut',{ascending:false})
      ])
      if (!r1.error) processus.value = r1.data
      if (!r2.error) ateliers.value = r2.data
      if (!r3.error) suiviFab.value = r3.data
      if (!r4.error) arretAtelier.value = r4.data
      loading.value = false
      buildGantt()
    }

    // ─── GANTT ────────────────────────────────────────────────
    var buildGantt = function() {
      var periods = {'2sem':14,'1mois':30,'3mois':90}
      var numDays = periods[ganttPeriod.value] || 30
      var offset = ganttOffset.value

      var baseDate = new Date()
      baseDate.setDate(baseDate.getDate() + offset * numDays)
      // Align to monday for 2sem, first of month for others
      if (ganttPeriod.value === '2sem') {
        var dow = baseDate.getDay(); var diff = (dow===0?-6:1-dow)
        baseDate.setDate(baseDate.getDate() + diff)
      } else if (ganttPeriod.value !== '2sem') {
        baseDate.setDate(1)
      }

      var days = []
      var today = new Date(); today.setHours(0,0,0,0)
      todayOffset.value = -1
      for (var i=0; i<numDays; i++) {
        var d = new Date(baseDate); d.setDate(baseDate.getDate()+i)
        var dow2 = d.getDay()
        var isToday = d.toDateString()===today.toDateString()
        if (isToday) todayOffset.value = i
        days.push({
          iso: d.toISOString().slice(0,10),
          label: ganttPeriod.value==='3mois' ? (i%7===0?d.getDate()+'':'') : d.getDate()+'',
          isToday, isWeekend: dow2===0||dow2===6
        })
      }
      ganttDays.value = days
      ganttTotalW.value = numDays * ganttDayW

      // Groups
      var groups = []
      if (ganttPeriod.value === '2sem') {
        // Group by day name
        days.forEach(function(d,i) {
          var dt = new Date(d.iso)
          var label = dt.toLocaleDateString('fr-FR',{weekday:'short',day:'numeric',month:'short'})
          groups.push({label, left:i*ganttDayW, width:ganttDayW})
        })
      } else if (ganttPeriod.value === '1mois') {
        // Group by week
        var weekStart = -1, weekLabel = ''
        days.forEach(function(d,i) {
          var dt = new Date(d.iso); var dow3 = dt.getDay()
          if (dow3===1||i===0) {
            if (weekStart>=0) groups.push({label:weekLabel,left:weekStart*ganttDayW,width:(i-weekStart)*ganttDayW})
            weekStart=i
            var wn = Math.ceil((dt.getDate()+(new Date(dt.getFullYear(),dt.getMonth(),1).getDay()||7)-1)/7)
            weekLabel='S'+wn
          }
          if (i===days.length-1) groups.push({label:weekLabel,left:weekStart*ganttDayW,width:(i-weekStart+1)*ganttDayW})
        })
      } else {
        // Group by month
        var curMonth = -1, monthStart = 0
        days.forEach(function(d,i) {
          var dt = new Date(d.iso); var m = dt.getMonth()
          if (m!==curMonth) {
            if (curMonth>=0) groups.push({label:new Date(dt.getFullYear(),curMonth,1).toLocaleDateString('fr-FR',{month:'short'}),left:monthStart*ganttDayW,width:(i-monthStart)*ganttDayW})
            curMonth=m; monthStart=i
          }
          if (i===days.length-1) groups.push({label:dt.toLocaleDateString('fr-FR',{month:'short'}),left:monthStart*ganttDayW,width:(i-monthStart+1)*ganttDayW})
        })
      }
      ganttGroups.value = groups
    }

    var dayOffset = function(isoDate) {
      if (!isoDate) return -1
      return ganttDays.value.findIndex(function(d){ return d.iso===isoDate.slice(0,10) })
    }

    var getFabBars = function(sf) {
      var bars = []
      var colorMap = {'En cours':'#10b981','Clôturé':'#6366f1','Arrêt':'#ef4444'}
      var color = colorMap[sf.statut] || '#3b82f6'
      if (!sf.date_debut) return bars
      var startOff = dayOffset(sf.date_debut)
      var endOff = sf.date_fin ? dayOffset(sf.date_fin) : dayOffset(new Date().toISOString())
      if (startOff < 0 && endOff < 0) return bars
      var left = Math.max(0, startOff) * ganttDayW
      var right = Math.min(ganttDays.value.length-1, endOff) * ganttDayW + ganttDayW - 2
      if (right < 0) return bars
      bars.push({
        key:'fab-'+sf.id, left, width:Math.max(4,right-left),
        color, label: 'Lot '+(sf.lots?.numero_lot||sf.lot_id),
        title: (sf.lots?.numero_lot||sf.lot_id)+' · '+sf.statut
      })
      return bars
    }

    var ganttSuivis = computed(function() {
      return suiviFab.value.filter(function(sf) {
        if (!sf.date_debut) return false
        var start = sf.date_debut.slice(0,10)
        var end = sf.date_fin ? sf.date_fin.slice(0,10) : new Date().toISOString().slice(0,10)
        var gStart = ganttDays.value[0]?.iso
        var gEnd = ganttDays.value[ganttDays.value.length-1]?.iso
        return gStart && gEnd && start <= gEnd && end >= gStart
      })
    })

    // ─── COMPUTED ─────────────────────────────────────────────
    var filteredAteliers = computed(function() {
      return ateliers.value.filter(function(at) {
        if (filterProc.value==='Tous') return true
        var p = processus.value.find(function(x){ return x.id===at.processus_id })
        return p && p.nom_process===filterProc.value
      })
    })

    var filteredSuivis = computed(function() {
      var list = suiviFab.value.filter(function(sf) {
        if (sfSearch.value) {
          var q = sfSearch.value.toLowerCase()
          var num = (sf.lots?.numero_lot||'').toLowerCase()
          var prod = (sf.lots?.products?.nom_produit||'').toLowerCase()
          if (!num.includes(q)&&!prod.includes(q)) return false
        }
        if (filterAtelier.value && sf.atelier_id!=filterAtelier.value) return false
        if (sfStatut.value && sf.statut!==sfStatut.value) return false
        if (sfProc.value && sf.processus_id!=sfProc.value) return false
        return true
      })
      list = list.slice().sort(function(a,b) {
        var va='', vb=''
        if (sfSortCol.value==='lots.numero_lot') { va=a.lots?.numero_lot||''; vb=b.lots?.numero_lot||'' }
        else if (sfSortCol.value==='lots.products.nom_produit') { va=a.lots?.products?.nom_produit||''; vb=b.lots?.products?.nom_produit||'' }
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
          if (!(arr.motif||'').toLowerCase().includes(q) && !getLotNum(arr.lot_id).toLowerCase().includes(q)) return false
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
      var total = closed.reduce(function(acc,a){ return acc + (new Date(a.heure_fin)-new Date(a.heure_debut)) },0)
      var avg = total/closed.length/60000
      return Math.round(avg)+'min'
    })

    // ─── HELPERS ──────────────────────────────────────────────
    var getActiveFab = function(atelierId) {
      return suiviFab.value.filter(function(sf){ return sf.atelier_id===atelierId && (sf.statut==='En cours'||sf.statut==='Arrêt') })
    }
    var getActiveCount = function(atelierId) { return getActiveFab(atelierId).length }
    var getActiveArrets = function(atelierId) {
      return arretAtelier.value.filter(function(a){ return a.atelier_id===atelierId && !a.heure_fin })
    }
    var getArretCount = function(fabId) {
      return arretAtelier.value.filter(function(a){ return a.suivi_fab_id===fabId }).length
    }
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

    var atClass = function(at) {
      var hasArret = getActiveArrets(at.id).length>0
      var hasActive = getActiveCount(at.id)>0
      if (hasArret) return 'at-arret'
      if (hasActive) return 'at-active'
      return 'at-idle'
    }

    var elapsedFab = function(sf) {
      if (!sf.date_debut) return ''
      var start = new Date(sf.date_debut)
      var end = sf.date_fin?new Date(sf.date_fin):new Date(now.value)
      var diff = Math.max(0, end-start)
      var h = Math.floor(diff/3600000)
      var m = Math.floor((diff%3600000)/60000)
      return h>0?(h+'h'+String(m).padStart(2,'0')):(m+'min')
    }

    var elapsedArret = function(arr) {
      if (!arr.heure_debut) return ''
      var start = new Date(arr.heure_debut)
      var diff = Math.max(0, new Date(now.value)-start)
      var h = Math.floor(diff/3600000)
      var m = Math.floor((diff%3600000)/60000)
      var s = Math.floor((diff%60000)/1000)
      return h>0?(h+'h'+String(m).padStart(2,'0')):(m+'min'+String(s).padStart(2,'0')+'s')
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

    var calcDuree = function(sf) {
      if (!sf.date_debut) return '—'
      var start = new Date(sf.date_debut)
      var end = sf.date_fin?new Date(sf.date_fin):new Date()
      var diff = end-start
      var h = Math.floor(diff/3600000)
      var m = Math.floor((diff%3600000)/60000)
      return h+'h'+String(m).padStart(2,'0')
    }

    var fmtDate = function(dt) {
      if (!dt) return ''
      return new Date(dt).toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',year:'2-digit',hour:'2-digit',minute:'2-digit'})
    }
    var fmtDateTime = function(dt) {
      if (!dt) return ''
      return new Date(dt).toLocaleString('fr-FR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'})
    }

    // Sort helpers
    var sfSort = function(col) {
      if (sfSortCol.value===col) sfSortDir.value = sfSortDir.value==='asc'?'desc':'asc'
      else { sfSortCol.value=col; sfSortDir.value='asc' }
    }
    var sfSortIc = function(col) {
      if (sfSortCol.value!==col) return '⇅'
      return sfSortDir.value==='asc'?'↑':'↓'
    }
    var arrSort = function(col) {
      if (arrSortCol.value===col) arrSortDir.value = arrSortDir.value==='asc'?'desc':'asc'
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
          .select('id,numero_lot,quantite_prevue,products(nom_produit)')
          .or('numero_lot.ilike.%'+q+'%')
          .limit(8)
        if (!res.error) lotSuggestions.value = res.data
      }, 250)
    }
    var selectLot = function(l) {
      fabModal.value.lotId = l.id
      fabModal.value.lotNum = l.numero_lot
      fabModal.value.lotProd = l.products?.nom_produit||''
      fabModal.value.lotSearch = l.numero_lot
      lotSuggestions.value = []
    }

    // ─── MODALS ───────────────────────────────────────────────
    var openFabModal = function(sf, atelierId) {
      var now2 = new Date()
      var local = now2.toISOString().slice(0,16)
      if (sf) {
        fabModal.value = {
          open:true, id:sf.id,
          lotId:sf.lot_id, lotNum:sf.lots?.numero_lot||'', lotProd:sf.lots?.products?.nom_produit||'',
          lotSearch:sf.lots?.numero_lot||'',
          atelierId:sf.atelier_id, processusId:sf.processus_id,
          dateDebut:sf.date_debut?sf.date_debut.slice(0,16):'',
          dateFin:sf.date_fin?sf.date_fin.slice(0,16):'',
          statut:sf.statut, err:'', saving:false
        }
      } else {
        fabModal.value = {
          open:true, id:null,
          lotId:null, lotNum:'', lotProd:'', lotSearch:'',
          atelierId:atelierId||'',
          processusId:'', dateDebut:local, dateFin:'', statut:'En cours',
          err:'', saving:false
        }
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
      var payload = {
        lot_id: fabModal.value.lotId,
        atelier_id: fabModal.value.atelierId,
        processus_id: fabModal.value.processusId,
        date_debut: fabModal.value.dateDebut||null,
        date_fin: fabModal.value.dateFin||null,
        statut: fabModal.value.statut
      }
      var res
      if (fabModal.value.id) {
        res = await supabase.from('suivi_fabrication').update(payload).eq('id',fabModal.value.id)
      } else {
        res = await supabase.from('suivi_fabrication').insert(payload)
      }
      fabModal.value.saving = false
      if (res.error) { fabModal.value.err = res.error.message; return }
      fabModal.value.open = false
      await loadAll()
    }

    var clotureAtelier = async function(sf) {
      var now2 = new Date().toISOString()
      var res = await supabase.from('suivi_fabrication')
        .update({ statut:'Clôturé', date_fin:now2 })
        .eq('id', sf.id)
      if (!res.error) await loadAll()
    }

    var deleteFab = async function(sf) {
      if (!confirm('Supprimer ce suivi ?')) return
      var res = await supabase.from('suivi_fabrication')
        .update({ deleted_at: new Date().toISOString() })
        .eq('id', sf.id)
      if (!res.error) await loadAll()
    }

    // ─── ARRÊTS ATELIER ───────────────────────────────────────
    var openArretAtelier = function(sf) {
      var now2 = new Date().toISOString().slice(0,16)
      arretModal.value = {
        open:true, fabId:sf.id, lot_id:sf.lot_id,
        lotNum:sf.lots?.numero_lot||sf.lot_id,
        lotProd:sf.lots?.products?.nom_produit||'',
        atelierId:sf.atelier_id,
        motif:'', heureDebut:now2,
        err:'', saving:false
      }
      // Also set suivi to Arrêt
    }

    var saveArret = async function() {
      if (!arretModal.value.motif.trim()) { arretModal.value.err='Motif requis'; return }
      arretModal.value.saving = true; arretModal.value.err = ''
      var payload = {
        atelier_id: arretModal.value.atelierId,
        lot_id: arretModal.value.lot_id,
        motif: arretModal.value.motif,
        heure_debut: arretModal.value.heureDebut||new Date().toISOString()
      }
      var res = await supabase.from('atelier_arrets').insert(payload)
      if (res.error) { arretModal.value.err=res.error.message; arretModal.value.saving=false; return }
      // Update suivi statut to Arrêt
      await supabase.from('suivi_fabrication').update({statut:'Arrêt'}).eq('id',arretModal.value.fabId)
      arretModal.value.saving = false
      arretModal.value.open = false
      await loadAll()
    }

    var closeArretAtelier = async function(arr) {
      var res = await supabase.from('atelier_arrets')
        .update({ heure_fin: new Date().toISOString() })
        .eq('id', arr.id)
      if (!res.error) {
        // If no more active arrets on this lot, restore suivi to En cours
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

    // ─── TICK ─────────────────────────────────────────────────
    var tick = function() { now.value = Date.now() }

    // ─── LIFECYCLE ────────────────────────────────────────────
    onMounted(function() {
      loadAll()
      tickInt = setInterval(tick, 1000)
    })
    onBeforeUnmount(function() {
      clearInterval(tickInt)
    })

    return {
      loading, activeView, filterProc, filterAtelier, sfSearch, sfStatut, sfProc,
      sfSortCol, sfSortDir, arrSearch, arrFilterAt, arrFilterStatut, arrSortCol, arrSortDir,
      processus, ateliers, suiviFab, arretAtelier,
      ganttPeriod, ganttOffset, ganttDays, ganttGroups, ganttDayW, ganttTotalW, todayOffset,
      ganttEl, ganttPeriods, fabTimers, arretTimers, now,
      fabModal, arretModal, lotSuggestions,
      filteredAteliers, filteredSuivis, filteredArrets, ganttSuivis, avgArretDuree,
      views: [
        {key:'ateliers', icon:'🏭', label:'Ateliers'},
        {key:'gantt',    icon:'▦',  label:'Gantt Fab'},
        {key:'lotfab',   icon:'▥',  label:'Suivi lots'},
        {key:'arrets',   icon:'⚠',  label:'Arrêts'},
      ],
      loadAll, buildGantt, getFabBars,
      getActiveFab, getActiveCount, getActiveArrets, getArretCount,
      getAtelierNom, getProcNom, procColor, getLotNum,
      atClass, elapsedFab, elapsedArret, arretDuree, calcDuree, fmtDate, fmtDateTime,
      sfSort, sfSortIc, arrSort, arrSortIc,
      searchLots, selectLot,
      openFabModal, onAtelierChange, saveFab, clotureAtelier, deleteFab,
      openArretAtelier, saveArret, closeArretAtelier, deleteArret,
    }
  }
}
</script>

<style scoped>
/* ── Base ── */
.pdp-fab { font-family:'Inter',sans-serif; font-size:13px; padding:0 0 40px; }

/* ── Header ── */
.ph { display:flex; align-items:center; justify-content:space-between; padding-bottom:10px; border-bottom:2px solid #0a0a0a; margin-bottom:16px; flex-wrap:wrap; gap:8px; }
.ph-left { display:flex; align-items:center; gap:16px; flex-wrap:wrap; }
.ph-right { display:flex; align-items:center; gap:8px; }
.pt { font-size:11px; font-weight:600; letter-spacing:1.5px; text-transform:uppercase; }

/* ── View tabs ── */
.view-tabs { display:flex; gap:4px; }
.vtab { display:flex; align-items:center; gap:5px; padding:5px 12px; border:1px solid #d1d5db; border-radius:4px; background:#fff; font-size:12px; cursor:pointer; color:#555; transition:all .15s; }
.vtab:hover { background:#f3f4f6; }
.vtab.active { background:#0a0a0a; color:#fff; border-color:#0a0a0a; }
.vtab-icon { font-size:13px; }

/* ── Proc tabs ── */
.proc-tabs { display:flex; gap:3px; flex-wrap:wrap; }
.proc-tab { padding:4px 10px; border-radius:3px; border:1px solid #e5e7eb; background:#fff; font-size:11px; cursor:pointer; color:#555; }
.proc-tab.active { background:#0a0a0a; color:#fff; border-color:#0a0a0a; }

.btn-refresh { padding:5px 10px; border:1px solid #d1d5db; border-radius:4px; background:#fff; cursor:pointer; font-size:15px; line-height:1; transition:transform .3s; }
.btn-refresh.spinning { animation:spin 1s linear infinite; }
@keyframes spin { to{transform:rotate(360deg)} }

.loading { text-align:center; padding:60px; color:#999; font-size:14px; }

/* ════ VUE 1 — ATELIERS ════ */
.ateliers-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(320px,1fr)); gap:16px; }

.at-card { border:1px solid #e5e7eb; border-radius:6px; background:#fff; overflow:hidden; display:flex; flex-direction:column; }
.at-card.at-active { border-color:#10b981; box-shadow:0 0 0 1px #10b98133; }
.at-card.at-arret { border-color:#ef4444; box-shadow:0 0 0 1px #ef444433; }
.at-card.at-idle { opacity:.85; }

.at-hd { display:flex; align-items:center; justify-content:space-between; padding:12px 14px 10px; border-top:3px solid #888; }
.at-nom { font-size:13px; font-weight:600; }
.at-proc { font-size:11px; color:#888; margin-top:1px; }
.at-badge { font-size:11px; font-weight:500; padding:3px 9px; border-radius:20px; }

.at-lots { padding:0 14px 10px; display:flex; flex-direction:column; gap:6px; }
.at-empty { color:#bbb; font-size:12px; padding:6px 0; text-align:center; font-style:italic; }

.at-lot-row { display:flex; align-items:center; gap:8px; padding:7px 10px; background:#f9fafb; border-radius:4px; border:1px solid #f0f0f0; }
.alr-left { flex:1; min-width:0; }
.alr-num { font-size:12px; font-weight:600; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.alr-prod { font-size:11px; color:#666; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.alr-mid { display:flex; flex-direction:column; align-items:flex-end; gap:2px; }
.alr-statut { font-size:10px; padding:2px 7px; border-radius:3px; font-weight:500; }
.alr-statut.st-en-cours { background:#d1fae5; color:#065f46; }
.alr-statut.st-arrêt, .alr-statut.st-arret { background:#fee2e2; color:#991b1b; }
.alr-statut.st-clôturé, .alr-statut.st-cloture { background:#e0e7ff; color:#3730a3; }
.alr-dur { font-size:10px; color:#888; font-variant-numeric:tabular-nums; }
.alr-right { display:flex; gap:4px; }

.at-arrets { padding:0 14px 10px; border-top:1px solid #fee2e2; background:#fff5f5; }
.at-arrets-title { font-size:10px; font-weight:600; color:#ef4444; padding:6px 0 4px; text-transform:uppercase; letter-spacing:.5px; }
.arr-row { display:flex; align-items:center; gap:6px; padding:4px 0; border-bottom:1px solid #fee2e2; }
.arr-row:last-child { border-bottom:none; }
.arr-motif { flex:1; font-size:11px; color:#374151; }
.arr-dur { font-size:11px; font-weight:600; color:#ef4444; font-variant-numeric:tabular-nums; }

.at-actions { padding:10px 14px; border-top:1px solid #f0f0f0; display:flex; gap:6px; margin-top:auto; }
.btn-act { padding:6px 12px; border-radius:4px; border:none; background:#0a0a0a; color:#fff; font-size:12px; cursor:pointer; }
.btn-act:hover { background:#333; }
.btn-act.btn-sec { background:#f3f4f6; color:#374151; border:1px solid #d1d5db; }
.btn-act.btn-sec:hover { background:#e5e7eb; }

/* ════ GANTT ════ */
.gantt-wrap { background:#fff; border:1px solid #e5e7eb; border-radius:6px; overflow:hidden; }
.gantt-toolbar { display:flex; align-items:center; gap:12px; padding:10px 16px; border-bottom:1px solid #e5e7eb; flex-wrap:wrap; }
.gantt-period-btns { display:flex; gap:3px; }
.gp-btn { padding:4px 10px; border:1px solid #d1d5db; border-radius:3px; background:#fff; font-size:11px; cursor:pointer; color:#555; }
.gp-btn.active { background:#0a0a0a; color:#fff; border-color:#0a0a0a; }
.gantt-nav { display:flex; gap:3px; }
.gnav { padding:4px 10px; border:1px solid #d1d5db; border-radius:3px; background:#fff; font-size:11px; cursor:pointer; }
.gnav:hover { background:#f3f4f6; }
.gnav-today { font-weight:600; }
.gantt-legend { display:flex; gap:10px; margin-left:auto; flex-wrap:wrap; }
.gl-item { display:flex; align-items:center; gap:4px; font-size:11px; color:#555; }
.gl-dot { width:10px; height:10px; border-radius:2px; }

.gantt-body { overflow-x:auto; }
.gantt-hd-row, .gantt-row { display:flex; border-bottom:1px solid #f0f0f0; }
.gantt-hd-row { background:#f9fafb; position:sticky; top:0; z-index:2; }
.gantt-label-cell { width:200px; min-width:200px; padding:8px 12px; border-right:1px solid #e5e7eb; }
.gantt-dates-cell { flex:1; position:relative; overflow:hidden; }
.gantt-dates, .gantt-track { position:relative; height:100%; }
.gantt-grp-hd { position:absolute; top:0; height:20px; line-height:20px; font-size:10px; font-weight:600; text-align:center; border-right:1px solid #d1d5db; color:#555; overflow:hidden; background:#f9fafb; }
.gantt-day-hd { position:absolute; top:20px; height:20px; line-height:20px; font-size:9px; text-align:center; border-right:1px solid #f0f0f0; color:#888; overflow:hidden; }
.gantt-day-hd.today { background:#eff6ff; color:#2563eb; font-weight:700; }
.gantt-day-hd.weekend { background:#fafafa; color:#bbb; }
.gantt-hd-row .gantt-dates-cell { min-height:40px; }
.gantt-lot-nom { font-size:12px; font-weight:600; }
.gantt-lot-sub { font-size:10px; color:#888; margin-top:1px; }
.gantt-row { min-height:40px; }
.gantt-track { min-height:40px; }
.gantt-today-line { position:absolute; top:0; bottom:0; width:2px; background:#2563eb44; z-index:1; }
.gantt-bar { position:absolute; top:8px; height:24px; border-radius:3px; overflow:hidden; display:flex; align-items:center; z-index:2; }
.gantt-bar-lbl { font-size:10px; color:#fff; padding:0 6px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; font-weight:500; text-shadow:0 1px 2px rgba(0,0,0,.3); }
.gantt-empty { padding:40px; text-align:center; color:#bbb; }

/* ════ VUE 3 — LOT FAB ════ */
.lotfab-wrap { }
.sf-toolbar { display:flex; gap:8px; margin-bottom:12px; flex-wrap:wrap; align-items:center; }
.sf-search { padding:6px 10px; border:1px solid #d1d5db; border-radius:4px; font-size:12px; flex:1; min-width:160px; }
.sf-sel { padding:6px 10px; border:1px solid #d1d5db; border-radius:4px; font-size:12px; background:#fff; }

.sf-table { width:100%; border-collapse:collapse; font-size:12px; }
.sf-table th { padding:8px 10px; text-align:left; background:#f9fafb; border-bottom:2px solid #e5e7eb; font-weight:600; font-size:11px; color:#374151; white-space:nowrap; }
.sf-table td { padding:7px 10px; border-bottom:1px solid #f0f0f0; vertical-align:middle; }
.sf-table tr:hover td { background:#f9fafb; }
.sf-table tr.row-en-cours td { background:#f0fdf4; }
.sf-table tr.row-arrêt td, .sf-table tr.row-arret td { background:#fff5f5; }
.sf-table tr.row-clôturé td, .sf-table tr.row-cloture td { opacity:.75; }
.no-data { text-align:center; padding:40px; color:#bbb; }
.sortable { cursor:pointer; user-select:none; }
.sortable:hover { background:#f0f0f0; }
.sort-ic { color:#aaa; font-size:10px; }
.td-mono { font-family:monospace; font-size:11px; }
.td-acts { display:flex; gap:4px; white-space:nowrap; }

.proc-chip { font-size:10px; padding:2px 7px; border-radius:3px; font-weight:500; }
.statut-chip { font-size:10px; padding:2px 7px; border-radius:3px; font-weight:500; }
.sc-en-cours { background:#d1fae5; color:#065f46; }
.sc-arrêt, .sc-arret { background:#fee2e2; color:#991b1b; }
.sc-clôturé, .sc-cloture { background:#e0e7ff; color:#3730a3; }
.arr-badge { font-size:10px; background:#fef9c3; color:#92400e; padding:2px 7px; border-radius:3px; }
.arr-none { color:#ccc; }

/* ════ VUE 4 — ARRÊTS ════ */
.arrets-wrap { }
.arr-toolbar { display:flex; gap:8px; margin-bottom:12px; flex-wrap:wrap; align-items:center; }
.arr-stats { display:flex; gap:12px; margin-left:auto; flex-wrap:wrap; }
.arr-stat { font-size:11px; color:#555; }
.arr-en-cours { color:#ef4444; }
.row-actif td { background:#fff5f5; }

/* ── Buttons ── */
.btn-sm { padding:3px 7px; border:1px solid #d1d5db; border-radius:3px; background:#fff; font-size:11px; cursor:pointer; }
.btn-sm:hover { background:#f3f4f6; }
.btn-sm.btn-ok { border-color:#10b981; color:#10b981; }
.btn-sm.btn-ok:hover { background:#d1fae5; }
.btn-sm.btn-del { border-color:#ef4444; color:#ef4444; }
.btn-sm.btn-del:hover { background:#fee2e2; }

/* ════ MODALS ════ */
.modal-overlay { position:fixed; inset:0; background:rgba(0,0,0,.5); z-index:1000; display:flex; align-items:center; justify-content:center; }
.modal { background:#fff; border-radius:8px; box-shadow:0 20px 60px rgba(0,0,0,.3); display:flex; flex-direction:column; max-height:90vh; overflow:hidden; }
.modal-fab { width:540px; max-width:95vw; }
.modal-arret { width:460px; max-width:95vw; }
.modal-hd { display:flex; align-items:center; justify-content:space-between; padding:16px 20px; border-bottom:1px solid #e5e7eb; font-weight:600; font-size:13px; }
.modal-close { background:none; border:none; font-size:18px; cursor:pointer; color:#888; line-height:1; }
.modal-body { padding:20px; overflow-y:auto; display:flex; flex-direction:column; gap:14px; }
.modal-ft { padding:14px 20px; border-top:1px solid #e5e7eb; display:flex; justify-content:flex-end; gap:8px; }

.form-row { display:flex; flex-direction:column; gap:4px; }
.form-row-2 { display:grid; grid-template-columns:1fr 1fr; gap:12px; }
.form-row label { font-size:11px; font-weight:600; color:#374151; text-transform:uppercase; letter-spacing:.5px; }
.form-inp { padding:7px 10px; border:1px solid #d1d5db; border-radius:4px; font-size:13px; }
.form-inp:focus { outline:none; border-color:#0a0a0a; }
.form-ta { resize:vertical; font-family:inherit; }
.form-err { color:#ef4444; font-size:12px; padding:6px 10px; background:#fff5f5; border-radius:4px; border:1px solid #fecaca; }

.lot-ac { position:relative; }
.lot-suggestions { position:absolute; top:100%; left:0; right:0; z-index:20; background:#fff; border:1px solid #d1d5db; border-radius:4px; box-shadow:0 4px 12px rgba(0,0,0,.1); max-height:180px; overflow-y:auto; }
.lot-sug { display:flex; gap:8px; align-items:center; padding:8px 12px; cursor:pointer; border-bottom:1px solid #f0f0f0; }
.lot-sug:hover { background:#f9fafb; }
.ls-num { font-weight:600; font-size:12px; }
.ls-prod { flex:1; color:#555; font-size:12px; }
.ls-qty { font-size:11px; color:#888; }
.lot-selected { font-size:12px; color:#10b981; font-weight:500; padding:4px 8px; background:#d1fae5; border-radius:3px; }

.arr-lot-info { display:flex; gap:8px; align-items:center; padding:8px 12px; background:#f9fafb; border-radius:4px; border:1px solid #e5e7eb; }

.btn-cancel { padding:7px 16px; border:1px solid #d1d5db; border-radius:4px; background:#fff; font-size:13px; cursor:pointer; }
.btn-cancel:hover { background:#f3f4f6; }
.btn-save { padding:7px 20px; border:none; border-radius:4px; background:#0a0a0a; color:#fff; font-size:13px; cursor:pointer; font-weight:500; }
.btn-save:hover { background:#333; }
.btn-save:disabled { opacity:.5; cursor:not-allowed; }
</style>
