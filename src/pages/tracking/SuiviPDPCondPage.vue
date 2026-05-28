<template>
  <div class="pdpc">

    <!-- ── HEADER ── -->
    <div class="ph">
      <div class="ph-l">
        <span class="pt">PDP CONDITIONNEMENT</span>
        <div class="vtabs">
          <button v-for="v in views" :key="v.key" class="vtab" :class="{active:activeView===v.key}" @click="activeView=v.key">
            <span class="vtab-ic">{{v.icon}}</span>{{v.label}}
          </button>
        </div>
      </div>
      <div class="ph-r">
        <div class="stabs">
          <button v-for="s in ['Tous','PHARMA','OTC']" :key="s" class="stab" :class="{active:filterSite===s}" @click="filterSite=s">{{s}}</button>
        </div>
        <button class="btn-ref" @click="loadAll" :class="{spin:loading}">↻</button>
      </div>
    </div>

    <!-- ════════════════════════════════════════════
         VUE 1 — TABLEAU CROISÉ Date × Équipement
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
          <option value="planifie">Planifié</option>
          <option value="encours">En cours</option>
          <option value="cloture">Clôturé</option>
          <option value="retard">En retard</option>
        </select>
        <button class="btn-add" @click="openAddPlan(null)">+ Planifier</button>
      </div>

      <!-- Légende -->
      <div class="tc-leg">
        <span class="tl tl-planifie">■ Planifié</span>
        <span class="tl tl-encours">■ En cours</span>
        <span class="tl tl-cloture">■ Clôturé</span>
        <span class="tl tl-retard">■ En retard</span>
        <span class="tl tl-vide">■ Vide</span>
      </div>

      <!-- Tableau -->
      <div class="tc-scroll" v-if="!loading||tableRows.length">
        <table class="tc-tbl">
          <thead>
            <tr>
              <th class="th-date">Date</th>
              <th v-for="eq in filteredEquipements" :key="eq.id" class="th-eq">
                <div class="the-nom">{{eq.nom_equipement}}</div>
                <div class="the-sub">{{eq.site}}<span v-if="eq.description_zone"> · {{eq.description_zone}}</span></div>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in tableRows" :key="row.iso" :class="{tr-today:row.isToday,'tr-we':row.isWeekend}">
              <td class="td-date" :class="{tdd-today:row.isToday}">
                <div class="dj">{{row.dayLabel}}</div>
                <div class="dd">{{row.dateLabel}}</div>
              </td>
              <td v-for="cell in row.cells" :key="cell.eq.id"
                class="tc-cell"
                :class="['c-'+cell.status, cell.dimmed?'c-dim':'', (cell.status!=='vide'&&!cell.dimmed)?'c-click':'']"
                @click="cell.status!=='vide'&&!cell.dimmed&&openDetail(cell,row)">
                <template v-if="cell.status!=='vide'&&!cell.dimmed">
                  <div v-for="p in cell.plans.slice(0,2)" :key="'p'+p.id" class="ci-plan">
                    <span class="ci-lot">{{p.numero_lot}}</span>
                  </div>
                  <div v-for="s in cell.sessions.slice(0,2)" :key="'s'+s.id" class="ci-sess">
                    <span class="ci-dot" :class="'cid-'+s.statut.toLowerCase().replace(/\s/g,'-')"></span>
                    <span class="ci-lot">{{s.numero_lot}}</span>
                  </div>
                  <div v-if="cell.plans.length+cell.sessions.length>4" class="ci-more">+{{cell.plans.length+cell.sessions.length-4}}</div>
                </template>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-if="loading&&!tableRows.length" class="ldg">Chargement…</div>
      <div v-if="!loading&&!filteredEquipements.length" class="ldg">Aucun équipement pour ce site</div>
    </div>

    <!-- ════════════════════════════════════════════
         VUE 2 — SESSIONS (tableau lecture seule)
    ════════════════════════════════════════════ -->
    <div v-show="activeView==='sessions'">
      <div class="t-bar">
        <input v-model="sessSearch" class="t-srch" placeholder="Lot, produit…" />
        <select v-model="sessEquipId" class="t-sel">
          <option :value="null">Tous équipements</option>
          <option v-for="e in equipements" :key="e.id" :value="e.id">{{e.nom_equipement}}</option>
        </select>
        <select v-model="sessStatut" class="t-sel">
          <option value="">Tous statuts</option>
          <option>En cours</option><option>Clôturé</option><option>Arrêt</option>
        </select>
        <select v-model="sessShiftId" class="t-sel">
          <option :value="null">Tous shifts</option>
          <option v-for="s in shifts" :key="s.id" :value="s.id">{{s.nom}}</option>
        </select>
      </div>
      <div class="dt-wrap">
        <table class="dt" v-if="filteredSessions.length">
          <thead>
            <tr>
              <th class="srt" @click="sortSess('numero_lot')">Lot <span class="si">{{sortArrow('numero_lot')}}</span></th>
              <th>Produit</th>
              <th class="srt" @click="sortSess('nom_equipement')">Équipement <span class="si">{{sortArrow('nom_equipement')}}</span></th>
              <th>Shift</th>
              <th class="srt" @click="sortSess('date')">Date <span class="si">{{sortArrow('date')}}</span></th>
              <th>Début→Fin</th>
              <th class="tc">Colis</th>
              <th class="tc">Rend.</th>
              <th class="tc">TRS</th>
              <th>Statut</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in filteredSessions" :key="s.id">
              <td class="mono">{{s.numero_lot}}</td>
              <td class="sm">{{s.code_article}}</td>
              <td class="sm">{{s.nom_equipement}}</td>
              <td><span v-if="s.shift_nom" class="shchip" :style="{background:s.shift_couleur+'33',color:s.shift_couleur}">{{s.shift_nom}}</span></td>
              <td class="mono">{{fmtDate(s.date)}}</td>
              <td class="mono">{{s.heure_debut&&s.heure_debut.slice(0,5)}}→{{s.heure_fin&&s.heure_fin.slice(0,5)||'…'}}</td>
              <td class="num">{{s.colis_produits||0}}</td>
              <td class="num"><span :class="vClass(s.rendement_pct)">{{s.rendement_pct!=null?s.rendement_pct+'%':'—'}}</span></td>
              <td class="num"><span :class="vClass(s.trs)">{{s.trs!=null?s.trs+'%':'—'}}</span></td>
              <td><span class="schip" :class="'sc-'+(s.statut||'').toLowerCase().replace(/\s/g,'-')">{{s.statut}}</span></td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty">Aucune session trouvée</div>
      </div>
    </div>

    <!-- ════════════════════════════════════════════
         VUE 3 — PLANNING PDP (gestion)
    ════════════════════════════════════════════ -->
    <div v-show="activeView==='planning'">
      <div class="t-bar">
        <select v-model="filterEquipId" class="t-sel">
          <option :value="null">Tous équipements</option>
          <option v-for="e in equipements" :key="e.id" :value="e.id">{{e.nom_equipement}}</option>
        </select>
        <select v-model="filterPlanStatut" class="t-sel">
          <option value="">Tous statuts</option>
          <option>Planifié</option><option>En cours</option><option>Clôturé</option><option>Annulé</option>
        </select>
        <button class="btn-add" @click="openAddPlan(null)">+ Ajouter au PDP</button>
      </div>
      <div class="dt-wrap">
        <table class="dt" v-if="filteredPlanning.length">
          <thead>
            <tr>
              <th class="tc">Ordre</th>
              <th>Lot</th>
              <th>Produit</th>
              <th>Équipement</th>
              <th>Début</th>
              <th>Fin</th>
              <th class="tc">Durée (j)</th>
              <th>Statut</th>
              <th>Commentaire</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in filteredPlanning" :key="p.id" :class="{'row-annule':p.statut_planification==='Annulé'}">
              <td class="num">
                <div class="ord-btns">
                  <button class="ob" @click="movePlan(p,'up')" :disabled="p.ordre_plan<=1">↑</button>
                  <span class="ord-n">{{p.ordre_plan||'—'}}</span>
                  <button class="ob" @click="movePlan(p,'down')">↓</button>
                </div>
              </td>
              <td class="mono">{{p.numero_lot}}</td>
              <td class="sm">{{p.code_article}}</td>
              <td class="sm">{{p.nom_equipement||'—'}}</td>
              <td class="mono">{{fmtDate(p.date_debut_estimee)||'—'}}</td>
              <td class="mono">{{fmtDate(p.date_fin_estimee)||'—'}}</td>
              <td class="num">{{p.duree_estimee_jours||'—'}}</td>
              <td><span class="pchip" :class="'pc-'+(p.statut_planification||'').toLowerCase().replace(/\s/g,'-')">{{p.statut_planification}}</span></td>
              <td class="sm">{{p.commentaire||'—'}}</td>
              <td class="acts">
                <button class="ia" @click="openEditPlan(p)" title="Modifier">✏️</button>
                <button class="ia del" @click="cancelPlan(p)" title="Annuler" v-if="p.statut_planification!=='Annulé'">✕</button>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty">Aucun lot dans le PDP</div>
      </div>
    </div>

    <!-- ═══ MODAL DÉTAIL CELLULE ═══ -->
    <div class="ov" v-if="detailPanel.show" @click.self="detailPanel.show=false">
      <div class="dp">
        <div class="dp-hd">
          <div>
            <div class="dp-eq">{{detailPanel.eqNom}}</div>
            <div class="dp-date">{{detailPanel.dayLabel}} {{detailPanel.dateLabel}}</div>
          </div>
          <button class="dp-x" @click="detailPanel.show=false">✕</button>
        </div>
        <div class="dp-body">
          <!-- Plans planifiés -->
          <div v-if="detailPanel.plans&&detailPanel.plans.length" class="dp-sec">
            <div class="dp-stitle">📋 Planifié</div>
            <div v-for="p in detailPanel.plans" :key="p.id" class="dp-item">
              <div class="dpi-row">
                <span class="dpi-lot">{{p.numero_lot}}</span>
                <span class="dpi-chip dchip-planifie">{{p.statut_planification}}</span>
              </div>
              <div class="dpi-prod">{{p.code_article}}</div>
              <div class="dpi-meta">{{fmtDate(p.date_debut_estimee)}} → {{fmtDate(p.date_fin_estimee)||'—'}}<span v-if="p.duree_estimee_jours"> · {{p.duree_estimee_jours}} j</span></div>
              <div class="dpi-acts">
                <button class="dpi-btn" @click="openEditPlan(p);detailPanel.show=false">Modifier</button>
              </div>
            </div>
          </div>
          <!-- Sessions réalisées -->
          <div v-if="detailPanel.sessions&&detailPanel.sessions.length" class="dp-sec">
            <div class="dp-stitle">✅ Réalisé (sessions)</div>
            <div v-for="s in detailPanel.sessions" :key="s.id" class="dp-item">
              <div class="dpi-row">
                <span class="dpi-lot">{{s.numero_lot}}</span>
                <span class="dpi-chip" :class="'dchip-'+(s.statut||'').toLowerCase().replace(/\s/g,'-')">{{s.statut}}</span>
              </div>
              <div class="dpi-prod">{{s.code_article}}</div>
              <div class="dpi-meta">{{s.heure_debut&&s.heure_debut.slice(0,5)}} → {{s.heure_fin&&s.heure_fin.slice(0,5)||'…'}}
                <span v-if="s.shift_nom"> · {{s.shift_nom}}</span>
              </div>
              <div class="dpi-kpis" v-if="s.colis_produits||s.trs!=null">
                <span class="kpiv">{{s.colis_produits||0}} colis</span>
                <span v-if="s.rendement_pct!=null" class="kpiv" :class="vClass(s.rendement_pct)">Rend. {{s.rendement_pct}}%</span>
                <span v-if="s.trs!=null" class="kpiv" :class="vClass(s.trs)">TRS {{s.trs}}%</span>
              </div>
            </div>
          </div>
          <div v-if="(!detailPanel.plans||!detailPanel.plans.length)&&(!detailPanel.sessions||!detailPanel.sessions.length)" class="dp-empty">
            Aucune donnée pour cette cellule
          </div>
        </div>
      </div>
    </div>

    <!-- ═══ MODAL PLAN PDP ═══ -->
    <div class="ov" v-if="planModal.show" @click.self="planModal.show=false">
      <div class="modal">
        <div class="modal-hd">{{planModal.editing ? 'Modifier entrée PDP' : 'Ajouter au PDP'}}</div>
        <label class="lbl">N° Lot *</label>
        <div class="auto-wrap">
          <input v-model="planModal.lotSearch" class="inp" placeholder="Rechercher numéro de lot…" @input="searchLots('plan')" :disabled="!!planModal.editing" />
          <div class="auto-list" v-if="planModal.lotSuggestions.length">
            <div v-for="l in planModal.lotSuggestions" :key="l.id" class="auto-item" @mousedown.prevent="selectLot('plan',l)">
              <span class="auto-code">{{l.numero_lot}}</span>
              <span class="auto-desc">{{l.code_article}} — {{l.description}}</span>
            </div>
          </div>
        </div>
        <div class="sel-lot-info" v-if="planModal.lot">✓ {{planModal.lot.numero_lot}} — {{planModal.lot.description}}</div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Équipement *</label>
            <select v-model="planModal.equipement_id" class="inp">
              <option :value="null">— Choisir —</option>
              <option v-for="e in equipements" :key="e.id" :value="e.id">{{e.nom_equipement}}</option>
            </select>
          </div>
          <div class="form-field">
            <label class="lbl">Durée estimée (jours)</label>
            <input type="number" v-model.number="planModal.duree_jours" class="inp" step="0.5" min="0.5" placeholder="ex: 3" />
          </div>
        </div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Date début estimée</label>
            <input type="date" v-model="planModal.date_debut" class="inp" @change="calcDateFin" />
          </div>
          <div class="form-field">
            <label class="lbl">Date fin estimée</label>
            <input type="date" v-model="planModal.date_fin" class="inp" />
          </div>
        </div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Statut</label>
            <select v-model="planModal.statut" class="inp">
              <option>Planifié</option><option>En cours</option><option>Clôturé</option>
            </select>
          </div>
        </div>
        <label class="lbl">Commentaire</label>
        <input v-model="planModal.commentaire" class="inp" placeholder="Optionnel…" />
        <div class="err" v-if="planModal.error">{{planModal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save" @click="savePlan" :disabled="planModal.saving">{{planModal.saving?'…':'Enregistrer'}}</button>
          <button class="btn-cancel" @click="planModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

  </div>
</template>

<script>
import { ref, reactive, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'

export default {
  setup() {
    // ─── STATE ─────────────────────────────────────────────────
    var activeView    = ref('tableau')
    var loading       = ref(false)
    var equipements   = ref([])
    var shifts        = ref([])
    var allSessions   = ref([])
    var allPlanning   = ref([])

    // Filtres globaux
    var filterSite    = ref('Tous')
    var filterEquipId = ref(null)
    var filterPlanStatut = ref('')

    // Filtres sessions
    var sessSearch    = ref('')
    var sessEquipId   = ref(null)
    var sessStatut    = ref('')
    var sessShiftId   = ref(null)
    var sessSortCol   = ref('date')
    var sessSortDir   = ref('desc')

    // Tableau croisé
    var periode       = ref('2sem')
    var baseDate      = ref(new Date().toISOString().slice(0,10))
    var filterLot     = ref('')
    var filterStatutTC = ref('')

    var PERIODS = [
      { k:'1sem', l:'1 sem' },
      { k:'2sem', l:'2 sem' },
      { k:'1mois', l:'1 mois' }
    ]

    // Détail panel
    var detailPanel = reactive({ show:false, eqNom:'', dateLabel:'', dayLabel:'', plans:[], sessions:[] })

    // Modal plan
    var planModal = reactive({ show:false, editing:null, equip:null, lotSearch:'', lotSuggestions:[], lot:null, equipement_id:null, date_debut:'', date_fin:'', duree_jours:null, statut:'Planifié', commentaire:'', error:'', saving:false })

    var lotSearchTimeout = null

    var views = [
      { key:'tableau',  icon:'⊞', label:'Planning' },
      { key:'sessions', icon:'▥', label:'Sessions' },
      { key:'planning', icon:'☰', label:'Gérer PDP' }
    ]

    // ─── HELPERS ───────────────────────────────────────────────
    var fmtDate = function(d) {
      if (!d) return ''
      var p = d.slice(0,10).split('-')
      return p[2]+'/'+p[1]+'/'+p[0]
    }

    var vClass = function(v) {
      if (v == null) return ''
      if (v >= 85) return 'vg'
      if (v >= 60) return 'vo'
      return 'vr'
    }

    var nowDate = function() { return new Date().toISOString().slice(0,10) }

    // ─── TABLEAU CROISÉ ────────────────────────────────────────
    var periodeNbDays = function() {
      if (periode.value === '1sem') return 7
      if (periode.value === '2sem') return 14
      return 31
    }

    var setPeriode = function(k) {
      periode.value = k
    }

    var navPeriod = function(dir) {
      var n = periodeNbDays()
      var d = new Date(baseDate.value)
      d.setDate(d.getDate() + dir * n)
      baseDate.value = d.toISOString().slice(0,10)
    }

    var goToday = function() {
      baseDate.value = nowDate()
    }

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

    var getCellStatus = function(iso, plans, sessions) {
      var today = nowDate()
      if (sessions.some(function(s){ return s.statut === 'En cours' || s.statut === 'Arrêt' })) return 'encours'
      if (sessions.some(function(s){ return s.statut === 'Clôturé' })) return 'cloture'
      if (plans.length > 0) {
        if (iso < today) return 'retard'
        return 'planifie'
      }
      return 'vide'
    }

    var filteredEquipements = computed(function() {
      if (filterSite.value === 'Tous') return equipements.value
      return equipements.value.filter(function(e){ return e.site === filterSite.value })
    })

    var tableRows = computed(function() {
      return dates.value.map(function(d) {
        var cells = filteredEquipements.value.map(function(eq) {
          // Plans couvrant cette date pour cet équipement
          var allP = allPlanning.value.filter(function(p) {
            if (p.equipement_id !== eq.id) return false
            var debut = p.date_debut_estimee || ''
            var fin   = p.date_fin_estimee   || debut
            return debut && debut <= d.iso && d.iso <= fin
          })
          // Sessions de cette date pour cet équipement
          var allS = allSessions.value.filter(function(s) {
            return s.equipement_id === eq.id && s.date === d.iso
          })
          // Filtre lot
          var plans, sessions
          if (filterLot.value) {
            var q = filterLot.value.toLowerCase()
            plans    = allP.filter(function(p){ return (p.numero_lot||'').toLowerCase().includes(q)||(p.code_article||'').toLowerCase().includes(q) })
            sessions = allS.filter(function(s){ return (s.numero_lot||'').toLowerCase().includes(q)||(s.code_article||'').toLowerCase().includes(q) })
          } else {
            plans = allP
            sessions = allS
          }
          var status = getCellStatus(d.iso, plans, sessions)
          var dimmed = !!(filterStatutTC.value && filterStatutTC.value !== status && status !== 'vide')
          return { eq, plans, sessions, status, dimmed }
        })
        return { iso:d.iso, dayLabel:d.dayLabel, dateLabel:d.dateLabel, isToday:d.isToday, isWeekend:d.isWeekend, cells }
      })
    })

    var openDetail = function(cell, row) {
      detailPanel.eqNom    = cell.eq.nom_equipement
      detailPanel.dateLabel = row.dateLabel
      detailPanel.dayLabel  = row.dayLabel
      detailPanel.plans     = cell.plans
      detailPanel.sessions  = cell.sessions
      detailPanel.show      = true
    }

    // ─── SESSIONS COMPUTED ─────────────────────────────────────
    var filteredSessions = computed(function() {
      var res = allSessions.value.slice()
      if (filterSite.value !== 'Tous') res = res.filter(function(s){ return s.site === filterSite.value })
      if (sessEquipId.value) res = res.filter(function(s){ return s.equipement_id === sessEquipId.value })
      if (sessStatut.value)  res = res.filter(function(s){ return s.statut === sessStatut.value })
      if (sessShiftId.value) res = res.filter(function(s){ return s.shift_id === sessShiftId.value })
      if (sessSearch.value) {
        var q = sessSearch.value.toLowerCase()
        res = res.filter(function(s){ return (s.numero_lot||'').toLowerCase().includes(q)||(s.code_article||'').toLowerCase().includes(q) })
      }
      res = res.sort(function(a,b) {
        var va = a[sessSortCol.value]||'', vb = b[sessSortCol.value]||''
        if (va < vb) return sessSortDir.value==='asc'?-1:1
        if (va > vb) return sessSortDir.value==='asc'?1:-1
        return 0
      })
      return res
    })

    var sortSess = function(col) {
      if (sessSortCol.value===col) sessSortDir.value = sessSortDir.value==='asc'?'desc':'asc'
      else { sessSortCol.value=col; sessSortDir.value='asc' }
    }
    var sortArrow = function(col) {
      if (sessSortCol.value!==col) return '⇅'
      return sessSortDir.value==='asc'?'↑':'↓'
    }

    // ─── PLANNING COMPUTED ─────────────────────────────────────
    var filteredPlanning = computed(function() {
      var res = allPlanning.value.slice()
      if (filterSite.value !== 'Tous') res = res.filter(function(p){ return p.site === filterSite.value })
      if (filterEquipId.value) res = res.filter(function(p){ return p.equipement_id === filterEquipId.value })
      if (filterPlanStatut.value) res = res.filter(function(p){ return p.statut_planification === filterPlanStatut.value })
      return res
    })

    // ─── LOAD ──────────────────────────────────────────────────
    var loadAll = async function() {
      loading.value = true
      var [rEq, rSh, rPlan, rSess] = await Promise.all([
        supabase.from('equipements_conditionnement').select('*').eq('actif',true).order('ordre_affichage'),
        supabase.from('shifts').select('id,nom,couleur').eq('actif',true).order('heure_debut'),
        supabase.from('planification_conditionnement')
          .select('*, lots(numero_lot, products(code_article, description)), equipements_conditionnement(nom_equipement, site)')
          .neq('statut_planification','Annulé')
          .order('equipement_id').order('ordre_plan'),
        supabase.from('production_sessions')
          .select('*, lots(numero_lot, products(code_article,description)), equipements_conditionnement(nom_equipement,site), shifts(nom,couleur)')
          .is('deleted_at',null)
          .order('date',{ascending:false}).order('heure_debut',{ascending:false})
          .limit(800)
      ])

      if (rEq.data)  equipements.value = rEq.data
      if (rSh.data)  shifts.value      = rSh.data

      if (rPlan.data) {
        allPlanning.value = rPlan.data.map(function(p) {
          return Object.assign({}, p, {
            numero_lot:     p.lots ? p.lots.numero_lot : '—',
            code_article:   p.lots && p.lots.products ? p.lots.products.code_article : '—',
            description:    p.lots && p.lots.products ? p.lots.products.description  : '',
            nom_equipement: p.equipements_conditionnement ? p.equipements_conditionnement.nom_equipement : '—',
            site:           p.equipements_conditionnement ? p.equipements_conditionnement.site : ''
          })
        })
      }

      if (rSess.data) {
        allSessions.value = rSess.data.map(function(s) {
          return Object.assign({}, s, {
            numero_lot:    s.lots ? s.lots.numero_lot : '—',
            code_article:  s.lots && s.lots.products ? s.lots.products.code_article : '—',
            nom_equipement:s.equipements_conditionnement ? s.equipements_conditionnement.nom_equipement : '—',
            site:          s.equipements_conditionnement ? s.equipements_conditionnement.site : '',
            shift_nom:     s.shifts ? s.shifts.nom    : '',
            shift_couleur: s.shifts ? s.shifts.couleur : '#3B82F6'
          })
        })
      }
      loading.value = false
    }

    // ─── RECHERCHE LOTS ────────────────────────────────────────
    var searchLots = function(target) {
      clearTimeout(lotSearchTimeout)
      var q = planModal.lotSearch
      if (!q || q.length < 2) { planModal.lotSuggestions = []; return }
      lotSearchTimeout = setTimeout(async function() {
        var r = await supabase.from('lots')
          .select('id, numero_lot, product_id, products(code_article, description)')
          .ilike('numero_lot','%'+q+'%').limit(8)
        planModal.lotSuggestions = (r.data||[]).map(function(l) {
          return { id:l.id, numero_lot:l.numero_lot, code_article:l.products?l.products.code_article:'', description:l.products?l.products.description:'', product_id:l.product_id }
        })
      }, 200)
    }

    var selectLot = function(target, l) {
      planModal.lot = l; planModal.lotSearch = l.numero_lot; planModal.lotSuggestions = []
    }

    // ─── PLAN PDP CRUD ─────────────────────────────────────────
    var openAddPlan = function(eq) {
      planModal.editing = null; planModal.equip = eq
      planModal.lotSearch=''; planModal.lot=null; planModal.lotSuggestions=[]
      planModal.equipement_id = eq ? eq.id : null
      planModal.date_debut=''; planModal.date_fin=''; planModal.duree_jours=null
      planModal.statut='Planifié'; planModal.commentaire=''
      planModal.error=''; planModal.saving=false
      planModal.show = true
    }

    var openEditPlan = function(p) {
      planModal.editing = p
      planModal.lotSearch = p.numero_lot; planModal.lot = { id:p.lot_id, numero_lot:p.numero_lot, description:p.description }
      planModal.lotSuggestions = []
      planModal.equipement_id = p.equipement_id
      planModal.date_debut = p.date_debut_estimee||''; planModal.date_fin = p.date_fin_estimee||''
      planModal.duree_jours = p.duree_estimee_jours
      planModal.statut = p.statut_planification; planModal.commentaire = p.commentaire||''
      planModal.error=''; planModal.saving=false
      planModal.show = true
    }

    var calcDateFin = function() {
      if (planModal.date_debut && planModal.duree_jours) {
        var d = new Date(planModal.date_debut)
        d.setDate(d.getDate() + Math.ceil(planModal.duree_jours))
        planModal.date_fin = d.toISOString().slice(0,10)
      }
    }

    var savePlan = async function() {
      if (!planModal.lot && !planModal.editing) { planModal.error='Sélectionner un lot.'; return }
      if (!planModal.equipement_id) { planModal.error='Choisir un équipement.'; return }
      planModal.saving = true
      var payload = {
        equipement_id:        planModal.equipement_id,
        date_debut_estimee:   planModal.date_debut||null,
        date_fin_estimee:     planModal.date_fin||null,
        duree_estimee_jours:  planModal.duree_jours||null,
        statut_planification: planModal.statut,
        commentaire:          planModal.commentaire||null,
        updated_at:           new Date().toISOString()
      }
      var r
      if (planModal.editing) {
        r = await supabase.from('planification_conditionnement').update(payload).eq('id',planModal.editing.id)
      } else {
        var maxOrdre = allPlanning.value.filter(function(p){ return p.equipement_id===planModal.equipement_id }).reduce(function(m,p){ return Math.max(m,p.ordre_plan||0) },0)
        payload.lot_id = planModal.lot.id
        payload.ordre_plan = maxOrdre + 1
        r = await supabase.from('planification_conditionnement').insert(payload)
      }
      if (r.error) { planModal.error=r.error.message; planModal.saving=false; return }
      planModal.show=false; planModal.saving=false
      await loadAll()
    }

    var cancelPlan = async function(p) {
      if (!confirm('Annuler ce lot du PDP ?')) return
      await supabase.from('planification_conditionnement').update({ statut_planification:'Annulé', updated_at:new Date().toISOString() }).eq('id',p.id)
      await loadAll()
    }

    var movePlan = async function(p, dir) {
      var sameEquip = allPlanning.value.filter(function(x){ return x.equipement_id===p.equipement_id && x.statut_planification!=='Annulé' }).sort(function(a,b){ return (a.ordre_plan||0)-(b.ordre_plan||0) })
      var idx = sameEquip.findIndex(function(x){ return x.id===p.id })
      var swapIdx = dir==='up'?idx-1:idx+1
      if (swapIdx<0||swapIdx>=sameEquip.length) return
      var other = sameEquip[swapIdx]
      var tmpOrdre = p.ordre_plan
      await supabase.from('planification_conditionnement').update({ ordre_plan:other.ordre_plan, updated_at:new Date().toISOString() }).eq('id',p.id)
      await supabase.from('planification_conditionnement').update({ ordre_plan:tmpOrdre, updated_at:new Date().toISOString() }).eq('id',other.id)
      await loadAll()
    }

    onMounted(loadAll)

    return {
      activeView, loading, views, PERIODS,
      equipements, shifts, allSessions, allPlanning,
      filterSite, filterEquipId, filterPlanStatut,
      sessSearch, sessEquipId, sessStatut, sessShiftId,
      periode, baseDate, filterLot, filterStatutTC,
      filteredEquipements, filteredSessions, filteredPlanning,
      tableRows, rangeLabel, dates,
      detailPanel, planModal,
      fmtDate, vClass, sortArrow,
      setPeriode, navPeriod, goToday,
      openDetail,
      sortSess, loadAll, searchLots, selectLot,
      openAddPlan, openEditPlan, calcDateFin, savePlan, cancelPlan, movePlan
    }
  }
}
</script>

<style scoped>
/* ── BASE ── */
.pdpc { min-height:100%; background:#0b0b1c; color:#e0e0f0; font-family:'Inter',sans-serif; font-size:13px; }

/* ── HEADER ── */
.ph { display:flex; align-items:center; justify-content:space-between; padding-bottom:10px; border-bottom:2px solid #1a1a38; margin-bottom:14px; flex-wrap:wrap; gap:8px; }
.ph-l { display:flex; align-items:center; gap:12px; flex-wrap:wrap; }
.ph-r { display:flex; align-items:center; gap:6px; }
.pt { font-size:11px; font-weight:600; letter-spacing:1.5px; text-transform:uppercase; color:#a0a0c8; }

.vtabs { display:flex; gap:3px; }
.vtab { display:flex; align-items:center; gap:5px; padding:5px 12px; font-size:11px; border:1px solid #252545; background:#12122a; color:#8888b0; border-radius:3px; cursor:pointer; transition:.15s; }
.vtab:hover { background:#1a1a35; color:#c0c0e8; }
.vtab.active { background:#1e3a6e; color:#93c5fd; border-color:#3b82f6; }
.vtab-ic { font-size:12px; }

.stabs { display:flex; gap:3px; }
.stab { padding:4px 10px; font-size:11px; border:1px solid #252545; background:#12122a; color:#8888b0; border-radius:3px; cursor:pointer; }
.stab.active { background:#1e3a6e; color:#93c5fd; border-color:#3b82f6; }
.btn-ref { padding:4px 10px; font-size:16px; border:1px solid #252545; background:#12122a; color:#8888b0; border-radius:3px; cursor:pointer; }
.btn-ref.spin { animation:spin .7s linear infinite; }
@keyframes spin{from{transform:rotate(0)}to{transform:rotate(360deg)}}

/* ── TOOLBAR TABLEAU CROISÉ ── */
.tc-bar { display:flex; align-items:center; gap:8px; margin-bottom:10px; flex-wrap:wrap; }
.tc-nav { display:flex; align-items:center; gap:4px; }
.tn { padding:5px 10px; border:1px solid #252545; background:#12122a; color:#a0a0c8; border-radius:3px; cursor:pointer; font-size:11px; }
.tn:hover { background:#1a1a35; color:#e0e0f0; }
.tn-now { font-weight:600; color:#93c5fd; border-color:#3b82f633; }
.tc-range { font-size:12px; font-family:monospace; color:#a0a0c8; margin-left:6px; white-space:nowrap; }
.tc-pds { display:flex; gap:3px; }
.tpd { padding:5px 10px; font-size:11px; border:1px solid #252545; background:#12122a; color:#8888b0; border-radius:3px; cursor:pointer; }
.tpd.active { background:#1e3a6e; color:#93c5fd; border-color:#3b82f6; }
.tc-srch { flex:1; min-width:150px; padding:6px 10px; border:1px solid #252545; background:#12122a; color:#e0e0f0; border-radius:3px; font-size:12px; outline:none; }
.tc-srch:focus { border-color:#3b82f6; }
.tc-sel { padding:6px 10px; border:1px solid #252545; background:#12122a; color:#a0a0c8; border-radius:3px; font-size:12px; cursor:pointer; }
.btn-add { padding:6px 14px; background:#1e3a6e; color:#93c5fd; border:1px solid #3b82f655; font-size:12px; border-radius:3px; cursor:pointer; white-space:nowrap; }
.btn-add:hover { background:#2a4f8a; }

/* ── LÉGENDE ── */
.tc-leg { display:flex; gap:14px; margin-bottom:10px; flex-wrap:wrap; }
.tl { font-size:11px; display:flex; align-items:center; gap:4px; }
.tl-planifie { color:#60a5fa; }
.tl-encours  { color:#fbbf24; }
.tl-cloture  { color:#34d399; }
.tl-retard   { color:#f87171; }
.tl-vide     { color:#3a3a5c; }

/* ── TABLEAU CROISÉ ── */
.tc-scroll { overflow:auto; max-height:calc(100vh - 240px); border:1px solid #1a1a38; border-radius:6px; }
.tc-tbl { border-collapse:collapse; min-width:max-content; width:100%; }

/* Header */
.tc-tbl thead tr { position:sticky; top:0; z-index:5; }
.th-date { position:sticky; left:0; top:0; z-index:6; background:#07071a; padding:8px 12px; text-align:left; font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:.5px; color:#606090; border-right:2px solid #1a1a38; border-bottom:2px solid #1a1a38; min-width:72px; }
.th-eq { background:#07071a; padding:8px 10px; text-align:left; border-bottom:2px solid #1a1a38; border-right:1px solid #151530; min-width:140px; max-width:180px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.the-nom { font-size:11px; font-weight:600; color:#c8c8e8; }
.the-sub { font-size:9px; color:#5a5a80; margin-top:1px; }

/* Rows */
.tc-tbl tbody tr { transition:background .1s; }
.tc-tbl tbody tr:hover td { background:#101028 !important; }
.tr-today td { background:#111130 !important; }
.tr-today .td-date { border-left:3px solid #3b82f6; }
.tr-we td { background:#0c0c20 !important; }

/* Date column */
.td-date { position:sticky; left:0; z-index:2; background:#0d0d22; padding:6px 10px; border-right:2px solid #1a1a38; border-bottom:1px solid #141430; white-space:nowrap; }
.tdd-today { background:#121230 !important; }
.dj { font-size:9px; color:#5a5a80; text-transform:uppercase; letter-spacing:.5px; }
.dd { font-size:12px; font-weight:600; color:#c0c0e0; font-family:monospace; }

/* Cells */
.tc-cell { padding:4px 6px; border-bottom:1px solid #141430; border-right:1px solid #151530; vertical-align:top; min-height:36px; height:36px; transition:background .12s; }
.c-vide   { background:#0b0b1c; }
.c-planifie { background:#1e3a5f22; border-left:2px solid #3b82f6; }
.c-encours  { background:#78350f22; border-left:2px solid #f59e0b; }
.c-cloture  { background:#064e3b22; border-left:2px solid #10b981; }
.c-retard   { background:#7f1d1d22; border-left:2px solid #ef4444; }
.c-click { cursor:pointer; }
.c-click:hover { filter:brightness(1.3); }
.c-dim { opacity:.22; }

/* Cell content */
.cell-content { display:flex; flex-direction:column; gap:1px; }
.ci-plan, .ci-sess { display:flex; align-items:center; gap:3px; }
.ci-lot { font-size:10px; font-family:monospace; font-weight:600; color:#e0e0f0; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:120px; }
.ci-dot { width:5px; height:5px; border-radius:50%; flex-shrink:0; }
.cid-en-cours { background:#fbbf24; }
.cid-clôturé, .cid-cloture { background:#34d399; }
.cid-arrêt, .cid-arret { background:#f87171; }
.ci-more { font-size:9px; color:#6060a0; }

/* ── LOADING / EMPTY ── */
.ldg { padding:40px; text-align:center; color:#4a4a70; font-size:13px; }

/* ── TOOLBAR TABLES ── */
.t-bar { display:flex; gap:8px; margin-bottom:10px; flex-wrap:wrap; }
.t-srch { flex:1; min-width:150px; padding:6px 10px; border:1px solid #252545; background:#12122a; color:#e0e0f0; border-radius:3px; font-size:12px; outline:none; }
.t-srch:focus { border-color:#3b82f6; }
.t-sel { padding:6px 10px; border:1px solid #252545; background:#12122a; color:#a0a0c8; border-radius:3px; font-size:12px; cursor:pointer; }

/* ── DARK TABLES ── */
.dt-wrap { overflow-x:auto; border:1px solid #1a1a38; border-radius:6px; }
.dt { width:100%; border-collapse:collapse; font-size:12px; min-width:640px; }
.dt thead tr { position:sticky; top:0; z-index:2; }
.dt th { background:#07071a; padding:8px 10px; text-align:left; font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:.4px; color:#6060a0; border-bottom:2px solid #1a1a38; white-space:nowrap; }
.dt th.srt { cursor:pointer; user-select:none; }
.dt th.srt:hover { background:#0f0f28; color:#a0a0c8; }
.dt th.tc { text-align:center; }
.dt td { padding:8px 10px; border-bottom:1px solid #131330; color:#c0c0e0; vertical-align:middle; }
.dt tr:hover td { background:#0f0f28; }
.dt tr.row-annule td { opacity:.35; }
.si { font-size:9px; color:#4a4a70; }
.mono { font-family:monospace; font-size:11px; }
.sm { font-size:11px; color:#9090b8; max-width:150px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.num { text-align:center; font-family:monospace; }
.tc { text-align:center; }
.empty { padding:30px; text-align:center; color:#3a3a60; font-size:13px; }
.vg { color:#34d399; font-weight:600; }
.vo { color:#fbbf24; font-weight:600; }
.vr { color:#f87171; font-weight:600; }
.shchip { font-size:10px; font-weight:600; padding:1px 7px; border-radius:8px; }
.schip { font-size:10px; padding:2px 7px; border-radius:8px; font-weight:500; }
.sc-en-cours { background:#065f4622; color:#34d399; }
.sc-clôturé, .sc-cloture { background:#30303055; color:#9090b8; }
.sc-arrêt, .sc-arret { background:#7f1d1d33; color:#f87171; }
.pchip { font-size:10px; padding:2px 7px; border-radius:8px; font-weight:500; }
.pc-planifié, .pc-planifie { background:#1e3a6e33; color:#60a5fa; }
.pc-en-cours { background:#065f4633; color:#34d399; }
.pc-clôturé, .pc-cloture { background:#30303055; color:#9090b8; }

/* ordre btns */
.ord-btns { display:flex; align-items:center; gap:2px; justify-content:center; }
.ob { background:none; border:1px solid #252545; color:#6060a0; font-size:10px; padding:1px 5px; cursor:pointer; border-radius:2px; }
.ob:hover:not(:disabled) { background:#1a1a35; color:#a0a0c8; }
.ob:disabled { opacity:.3; cursor:not-allowed; }
.ord-n { font-family:monospace; font-size:11px; font-weight:600; min-width:20px; text-align:center; color:#c0c0e0; }
.acts { text-align:right; white-space:nowrap; }
.ia { background:none; border:none; cursor:pointer; font-size:12px; padding:3px 5px; border-radius:2px; opacity:.7; }
.ia:hover { background:#1e1e3c; opacity:1; }
.ia.del:hover { background:#3a1010; }

/* ── MODAL DÉTAIL ── */
.ov { position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,.6); display:flex; align-items:center; justify-content:center; z-index:200; }
.dp { background:#14142e; border:1px solid #2a2a52; border-radius:10px; width:480px; max-width:96vw; max-height:88vh; display:flex; flex-direction:column; box-shadow:0 24px 60px rgba(0,0,0,.6); }
.dp-hd { display:flex; align-items:flex-start; justify-content:space-between; padding:18px 20px 14px; border-bottom:1px solid #1e1e40; }
.dp-eq { font-size:15px; font-weight:700; color:#e0e0f8; }
.dp-date { font-size:12px; color:#7070a0; margin-top:2px; font-family:monospace; }
.dp-x { background:none; border:none; color:#6060a0; font-size:18px; cursor:pointer; line-height:1; padding:2px 6px; }
.dp-x:hover { color:#e0e0f0; }
.dp-body { overflow-y:auto; padding:16px 20px 20px; display:flex; flex-direction:column; gap:16px; }
.dp-sec { }
.dp-stitle { font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:.8px; color:#6060a0; margin-bottom:8px; }
.dp-item { background:#0e0e28; border:1px solid #1c1c3c; border-radius:6px; padding:12px; display:flex; flex-direction:column; gap:5px; margin-bottom:6px; }
.dpi-row { display:flex; align-items:center; justify-content:space-between; }
.dpi-lot { font-family:monospace; font-size:13px; font-weight:700; color:#e0e0f8; }
.dpi-chip { font-size:10px; padding:2px 8px; border-radius:8px; font-weight:500; }
.dchip-planifié, .dchip-planifie { background:#1e3a6e44; color:#60a5fa; }
.dchip-en-cours { background:#06402a44; color:#34d399; }
.dchip-clôturé, .dchip-cloture { background:#30303055; color:#9090b8; }
.dchip-arrêt, .dchip-arret { background:#5a050544; color:#f87171; }
.dpi-prod { font-size:11px; color:#8080b0; }
.dpi-meta { font-size:10px; font-family:monospace; color:#5a5a80; }
.dpi-kpis { display:flex; gap:8px; flex-wrap:wrap; margin-top:2px; }
.kpiv { font-size:11px; font-family:monospace; color:#9090b8; }
.kpiv.vg { color:#34d399; }
.kpiv.vo { color:#fbbf24; }
.kpiv.vr { color:#f87171; }
.dpi-acts { display:flex; gap:6px; margin-top:4px; }
.dpi-btn { padding:4px 12px; border:1px solid #252545; background:#1a1a35; color:#a0a0c8; font-size:11px; border-radius:3px; cursor:pointer; }
.dpi-btn:hover { background:#242445; color:#e0e0f0; }
.dp-empty { text-align:center; padding:20px; color:#4a4a70; font-size:13px; }

/* ── MODAL PLAN ── */
.modal { background:#14142e; border:1px solid #2a2a52; padding:24px; width:520px; max-width:96vw; border-radius:10px; max-height:92vh; overflow-y:auto; }
.modal-hd { font-size:14px; font-weight:600; margin-bottom:16px; color:#e0e0f8; }
.lbl { display:block; font-size:10px; color:#6060a0; text-transform:uppercase; letter-spacing:.5px; margin-bottom:4px; margin-top:12px; }
.inp { width:100%; padding:8px 10px; border:1px solid #252545; background:#0e0e28; color:#e0e0f0; font-size:13px; outline:none; box-sizing:border-box; border-radius:3px; font-family:inherit; }
.inp:focus { border-color:#3b82f6; }
.inp:disabled { opacity:.4; }
.form-row { display:flex; gap:10px; }
.form-field { flex:1; }
.auto-wrap { position:relative; }
.auto-list { position:absolute; top:100%; left:0; right:0; background:#14142e; border:1px solid #2a2a52; border-radius:4px; box-shadow:0 8px 24px rgba(0,0,0,.5); z-index:10; max-height:180px; overflow-y:auto; }
.auto-item { display:flex; gap:8px; padding:7px 10px; cursor:pointer; font-size:12px; border-bottom:1px solid #1a1a38; }
.auto-item:hover { background:#1a1a38; }
.auto-code { font-family:monospace; font-weight:600; color:#60a5fa; min-width:70px; }
.auto-desc { color:#8080b0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.sel-lot-info { font-size:11px; color:#34d399; padding:4px 8px; background:#064e3b22; border-radius:3px; margin-top:4px; border:1px solid #34d39933; }
.err { color:#f87171; font-size:12px; margin-top:8px; padding:6px 10px; background:#7f1d1d22; border-radius:3px; border:1px solid #f8717133; }
.modal-acts { display:flex; gap:8px; margin-top:16px; }
.btn-save { flex:1; padding:10px; background:#1e3a6e; color:#93c5fd; border:1px solid #3b82f655; font-size:13px; font-weight:500; cursor:pointer; border-radius:3px; }
.btn-save:hover:not(:disabled) { background:#2a4f8a; }
.btn-save:disabled { opacity:.4; }
.btn-cancel { flex:1; padding:10px; background:#1a1a35; color:#8080b0; border:1px solid #252545; font-size:13px; cursor:pointer; border-radius:3px; }
.btn-cancel:hover { background:#222240; }

@media(max-width:768px){
  .tc-bar { flex-direction:column; align-items:flex-start; }
  .tc-srch { width:100%; }
  .form-row { flex-direction:column; }
}
</style>
