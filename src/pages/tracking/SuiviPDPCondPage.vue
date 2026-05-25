<template>
  <div class="pdp-cond">
    <!-- ── HEADER ── -->
    <div class="ph">
      <div class="ph-left">
        <span class="pt">PDP CONDITIONNEMENT</span>
        <div class="view-tabs">
          <button v-for="v in views" :key="v.key" class="vtab" :class="{active:activeView===v.key}" @click="activeView=v.key">
            <span class="vtab-icon">{{v.icon}}</span>{{v.label}}
          </button>
        </div>
      </div>
      <div class="ph-right">
        <div class="site-tabs">
          <button v-for="s in ['Tous','PHARMA','OTC']" :key="s" class="site-tab" :class="{active:filterSite===s}" @click="filterSite=s">{{s}}</button>
        </div>
        <button class="btn-refresh" @click="loadAll" :class="{spinning:loading}">↻</button>
      </div>
    </div>

    <div v-if="loading && !equipements.length" class="loading">Chargement…</div>

    <!-- ════════════════════════════════════
         VUE 1 — CARDS ÉQUIPEMENTS
    ════════════════════════════════════ -->
    <div v-show="activeView==='cards'" class="cards-grid">
      <div v-for="eq in filteredEquipements" :key="eq.id" class="eq-card" :class="cardClass(eq)">
        <!-- Header -->
        <div class="card-hd" :style="{borderTopColor: cardColor(eq)}">
          <div>
            <div class="card-nom">{{eq.nom_equipement}}</div>
            <div class="card-site">{{eq.site}}</div>
          </div>
          <div class="card-status" :style="{background:cardColor(eq)+'22',color:cardColor(eq)}">
            {{cardStatut(eq)}}
          </div>
        </div>

        <!-- Session active -->
        <template v-if="getActiveSession(eq.id)">
          <div class="card-lot">
            <div class="lot-n">Lot {{getActiveSession(eq.id).numero_lot}}</div>
            <div class="lot-p">{{getActiveSession(eq.id).code_article}}</div>
          </div>
          <div class="card-prog" v-if="getActiveSession(eq.id).objectif_boites">
            <div class="prog-bar">
              <div class="prog-fill" :style="{width:Math.min(getRendPct(getActiveSession(eq.id)),100)+'%', background:cardColor(eq)}"></div>
            </div>
            <div class="prog-nums">
              <span>{{getActiveSession(eq.id).colis_produits||0}} colis</span>
              <span class="prog-pct" :style="{color:cardColor(eq)}">{{getRendPct(getActiveSession(eq.id))}}%</span>
            </div>
          </div>
          <div class="card-cadence" v-if="getActiveSession(eq.id).cadence_reelle_boite_min || getActiveSession(eq.id).cadence_objectif_snapshot">
            <span class="cad-r">{{getActiveSession(eq.id).cadence_reelle_boite_min || '—'}} b/min réel</span>
            <span class="cad-sep">·</span>
            <span class="cad-o">obj. {{getActiveSession(eq.id).cadence_objectif_snapshot || eq.cadence_objectif_boite_min || '—'}}</span>
          </div>
        </template>
        <div class="card-empty" v-else-if="!getNextPlan(eq.id)">Aucun lot en cours</div>

        <!-- Prochain lot planifié -->
        <div class="card-next" v-if="getNextPlan(eq.id) && !getActiveSession(eq.id)">
          <div class="next-label">Prochain lot planifié</div>
          <div class="next-lot">{{getNextPlan(eq.id).numero_lot}}</div>
          <div class="next-prod">{{getNextPlan(eq.id).code_article}}</div>
          <div class="next-dates" v-if="getNextPlan(eq.id).date_debut_estimee">
            <span class="nd-start">{{fmtDate(getNextPlan(eq.id).date_debut_estimee)}}</span>
            <span class="nd-arr">→</span>
            <span class="nd-end">{{fmtDate(getNextPlan(eq.id).date_fin_estimee)}}</span>
          </div>
        </div>

        <!-- File d'attente PDP -->
        <div class="card-queue" v-if="getPlanQueue(eq.id).length">
          <div class="queue-title">File d'attente ({{getPlanQueue(eq.id).length}})</div>
          <div v-for="(p,i) in getPlanQueue(eq.id).slice(0,3)" :key="p.id" class="queue-item">
            <span class="qi-rank">{{i+1}}</span>
            <span class="qi-lot">{{p.numero_lot}}</span>
            <span class="qi-prod">{{p.code_article}}</span>
            <span class="qi-dur" v-if="p.duree_estimee_jours">{{p.duree_estimee_jours}}j</span>
          </div>
          <div v-if="getPlanQueue(eq.id).length>3" class="queue-more">+{{getPlanQueue(eq.id).length-3}} autres</div>
        </div>

        <div class="card-actions">
          <button class="ca-btn" @click="openAddSession(eq)">+ Session</button>
          <button class="ca-btn" @click="openAddPlan(eq)">+ Planifier</button>
          <button class="ca-btn ca-sec" @click="activeView='planning'; filterEquipId=eq.id">PDP ↗</button>
        </div>
      </div>
    </div>

    <!-- ════════════════════════════════════
         VUE 2 — GANTT PDP
    ════════════════════════════════════ -->
    <div v-show="activeView==='gantt'" class="gantt-wrap">
      <div class="gantt-controls">
        <div class="gc-left">
          <button v-for="p in ['2sem','1mois','3mois']" :key="p" class="gp-btn" :class="{active:ganttPeriod===p}" @click="ganttPeriod=p;buildGantt()">{{p}}</button>
          <button class="gp-btn gp-nav" @click="ganttOffset--;buildGantt()">←</button>
          <button class="gp-btn gp-nav today-btn" @click="ganttOffset=0;buildGantt()">Auj.</button>
          <button class="gp-btn gp-nav" @click="ganttOffset++;buildGantt()">→</button>
        </div>
        <div class="gc-right">
          <span class="gantt-range">{{ganttRangeLabel}}</span>
        </div>
      </div>

      <div class="gantt-table" v-if="ganttDays.length">
        <!-- Header dates -->
        <div class="gt-corner"></div>
        <div class="gt-dates-row">
          <div v-for="d in ganttHeaderDays" :key="d.iso" class="gt-date-cell" :style="{width: (d.span * ganttDayW)+'px'}" :class="{today: d.isToday, weekend: d.isWeekend}">
            {{d.label}}
          </div>
        </div>

        <!-- Ligne par équipement -->
        <template v-for="eq in filteredEquipements" :key="eq.id">
          <div class="gt-eq-label">
            <div class="gel-nom">{{eq.nom_equipement}}</div>
            <div class="gel-site">{{eq.site}}</div>
          </div>
          <div class="gt-eq-row" :style="{width: (ganttDays.length * ganttDayW)+'px'}">
            <!-- Fond today -->
            <div v-for="(d,di) in ganttDays" :key="d.iso" class="gt-day-bg" :class="{today:d.isToday, weekend:d.isWeekend}" :style="{left:(di*ganttDayW)+'px',width:ganttDayW+'px'}"></div>
            <!-- Barres PDP -->
            <div v-for="bar in getGanttBars(eq.id)" :key="bar.id"
              class="gt-bar" :class="'gt-bar-'+bar.type"
              :style="{left:bar.left+'px', width:Math.max(bar.width,8)+'px', background:bar.color, borderColor:bar.color}"
              :title="bar.tooltip"
              @click="openEditPlan(bar.plan)"
            >
              <span class="gt-bar-label">{{bar.label}}</span>
            </div>
            <!-- Sessions réelles -->
            <div v-for="bar in getGanttSessionBars(eq.id)" :key="'s'+bar.id"
              class="gt-bar gt-bar-session"
              :style="{left:bar.left+'px', width:Math.max(bar.width,8)+'px'}"
              :title="bar.tooltip"
            >
              <span class="gt-bar-label">{{bar.label}}</span>
            </div>
          </div>
        </template>

        <!-- Légende -->
        <div class="gantt-legend">
          <span class="gl-item"><span class="gl-dot" style="background:#185FA5"></span>Planifié</span>
          <span class="gl-item"><span class="gl-dot" style="background:#1D9E75"></span>En cours</span>
          <span class="gl-item"><span class="gl-dot" style="background:#9CA3AF"></span>Clôturé</span>
          <span class="gl-item"><span class="gl-dot" style="background:#F97316;opacity:.5"></span>Session réelle</span>
        </div>
      </div>
    </div>

    <!-- ════════════════════════════════════
         VUE 3 — SESSIONS (tableau)
    ════════════════════════════════════ -->
    <div v-show="activeView==='sessions'">
      <div class="table-toolbar">
        <input v-model="sessSearch" class="t-search" placeholder="Lot, produit…" @input="filterSessions" />
        <select v-model="sessEquipId" class="t-sel" @change="filterSessions">
          <option :value="null">Tous équipements</option>
          <option v-for="e in equipements" :key="e.id" :value="e.id">{{e.nom_equipement}}</option>
        </select>
        <select v-model="sessStatut" class="t-sel" @change="filterSessions">
          <option value="">Tous statuts</option>
          <option>En cours</option><option>Clôturé</option><option>Arrêt</option>
        </select>
        <select v-model="sessShiftId" class="t-sel" @change="filterSessions">
          <option :value="null">Tous shifts</option>
          <option v-for="s in shifts" :key="s.id" :value="s.id">{{s.nom}}</option>
        </select>
      </div>

      <table class="data-table" v-if="filteredSessions.length">
        <thead>
          <tr>
            <th @click="sortSess('numero_lot')" class="sortable">Lot <span class="sort-arrow">{{sortArrow('numero_lot')}}</span></th>
            <th>Produit</th>
            <th @click="sortSess('nom_equipement')" class="sortable">Équipement</th>
            <th>Shift</th>
            <th>Équipe</th>
            <th @click="sortSess('date')" class="sortable">Date <span class="sort-arrow">{{sortArrow('date')}}</span></th>
            <th>Début → Fin</th>
            <th class="num-col">Colis</th>
            <th class="num-col">Obj.</th>
            <th class="num-col">Rend.</th>
            <th class="num-col">TRS</th>
            <th>Statut</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in filteredSessions" :key="s.id">
            <td class="mono-sm">{{s.numero_lot}}</td>
            <td class="small-txt">{{s.code_article}}</td>
            <td class="small-txt">{{s.nom_equipement}}</td>
            <td><span v-if="s.shift_nom" class="sh-chip-sm" :style="{background:s.shift_couleur+'22',color:s.shift_couleur}">{{s.shift_nom}}</span></td>
            <td><span v-if="s.equipe_nom" class="eq-chip-sm" :style="{background:s.equipe_couleur+'22',color:s.equipe_couleur}">{{s.equipe_nom}}</span></td>
            <td class="mono-sm">{{fmtDate(s.date)}}</td>
            <td class="mono-sm">{{s.heure_debut?.slice(0,5)}} → {{s.heure_fin?.slice(0,5)||'…'}}</td>
            <td class="num">{{s.colis_produits||0}}</td>
            <td class="num">{{s.objectif_boites||'—'}}</td>
            <td class="num"><span :class="oeeClass(s.rendement_pct)">{{s.rendement_pct!=null?s.rendement_pct+'%':'—'}}</span></td>
            <td class="num"><span :class="oeeClass(s.trs)">{{s.trs!=null?s.trs+'%':'—'}}</span></td>
            <td><span class="stat-chip" :class="'stat-'+s.statut?.toLowerCase().replace(' ','-')">{{s.statut}}</span></td>
          </tr>
        </tbody>
      </table>
      <div v-else class="empty">Aucune session trouvée</div>
    </div>

    <!-- ════════════════════════════════════
         VUE 4 — PLANNING PDP (gestion)
    ════════════════════════════════════ -->
    <div v-show="activeView==='planning'">
      <div class="table-toolbar">
        <select v-model="filterEquipId" class="t-sel">
          <option :value="null">Tous équipements</option>
          <option v-for="e in equipements" :key="e.id" :value="e.id">{{e.nom_equipement}}</option>
        </select>
        <select v-model="filterPlanStatut" class="t-sel">
          <option value="">Tous statuts</option>
          <option>Planifié</option><option>En cours</option><option>Clôturé</option><option>Annulé</option>
        </select>
        <button class="btn-add-plan" @click="openAddPlan(null)">+ Ajouter au PDP</button>
      </div>

      <table class="data-table" v-if="filteredPlanning.length">
        <thead>
          <tr>
            <th class="num-col">Ordre</th>
            <th>Lot</th>
            <th>Produit</th>
            <th>Équipement</th>
            <th>Début estimé</th>
            <th>Fin estimée</th>
            <th class="num-col">Durée (j)</th>
            <th>Statut</th>
            <th>Commentaire</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="p in filteredPlanning" :key="p.id" :class="{plan-annule: p.statut_planification==='Annulé'}">
            <td class="num">
              <div class="order-btns">
                <button class="ob" @click="movePlan(p,'up')" :disabled="p.ordre_plan<=1" title="Monter">↑</button>
                <span class="order-num">{{p.ordre_plan||'—'}}</span>
                <button class="ob" @click="movePlan(p,'down')" title="Descendre">↓</button>
              </div>
            </td>
            <td class="mono-sm">{{p.numero_lot}}</td>
            <td class="small-txt">{{p.code_article}}</td>
            <td class="small-txt">{{p.nom_equipement||'—'}}</td>
            <td class="mono-sm">{{fmtDate(p.date_debut_estimee)||'—'}}</td>
            <td class="mono-sm">{{fmtDate(p.date_fin_estimee)||'—'}}</td>
            <td class="num">{{p.duree_estimee_jours||'—'}}</td>
            <td><span class="plan-chip" :class="'plan-'+p.statut_planification?.toLowerCase().replace(' ','-')">{{p.statut_planification}}</span></td>
            <td class="small-txt">{{p.commentaire||'—'}}</td>
            <td class="acts">
              <button class="ia" @click="openEditPlan(p)" title="Modifier">✏️</button>
              <button class="ia del" @click="cancelPlan(p)" title="Annuler" v-if="p.statut_planification!=='Annulé'">✕</button>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-else class="empty">Aucun lot dans le PDP</div>
    </div>

    <!-- ══ MODAL AJOUTER SESSION ══ -->
    <div class="overlay" v-if="sessModal.show" @click.self="sessModal.show=false">
      <div class="modal">
        <div class="modal-hd">{{sessModal.editing ? 'Modifier session' : 'Nouvelle session'}} — {{sessModal.equip?.nom_equipement}}</div>
        <label class="lbl">N° Lot *</label>
        <div class="auto-wrap">
          <input v-model="sessModal.lotSearch" class="inp" placeholder="Rechercher numéro de lot…" @input="searchLots('sess')" />
          <div class="auto-list" v-if="sessModal.lotSuggestions.length">
            <div v-for="l in sessModal.lotSuggestions" :key="l.id" class="auto-item" @mousedown.prevent="selectLot('sess',l)">
              <span class="auto-code">{{l.numero_lot}}</span>
              <span class="auto-desc">{{l.code_article}} — {{l.description}}</span>
            </div>
          </div>
        </div>
        <div class="sel-lot-info" v-if="sessModal.lot">✓ {{sessModal.lot.numero_lot}} — {{sessModal.lot.description}}</div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Date *</label>
            <input type="date" v-model="sessModal.date" class="inp" />
          </div>
          <div class="form-field">
            <label class="lbl">Heure début *</label>
            <input type="time" v-model="sessModal.heure_debut" class="inp" step="60" />
          </div>
          <div class="form-field">
            <label class="lbl">Heure fin</label>
            <input type="time" v-model="sessModal.heure_fin" class="inp" step="60" />
          </div>
        </div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Shift</label>
            <select v-model="sessModal.shift_id" class="inp">
              <option :value="null">— Aucun —</option>
              <option v-for="s in shifts" :key="s.id" :value="s.id">{{s.nom}}</option>
            </select>
          </div>
          <div class="form-field">
            <label class="lbl">Équipe</label>
            <select v-model="sessModal.equipe_id" class="inp">
              <option :value="null">— Aucune —</option>
              <option v-for="e in equipes" :key="e.id" :value="e.id">{{e.nom}}</option>
            </select>
          </div>
        </div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Colis produits</label>
            <input type="number" v-model.number="sessModal.colis_produits" class="inp" min="0" />
          </div>
          <div class="form-field">
            <label class="lbl">Statut</label>
            <select v-model="sessModal.statut" class="inp">
              <option>En cours</option><option>Clôturé</option><option>Arrêt</option>
            </select>
          </div>
        </div>
        <div class="err" v-if="sessModal.error">{{sessModal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save" @click="saveSession" :disabled="sessModal.saving">{{sessModal.saving?'…':'Enregistrer'}}</button>
          <button class="btn-cancel" @click="sessModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL PLAN PDP ══ -->
    <div class="overlay" v-if="planModal.show" @click.self="planModal.show=false">
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
    var activeView    = ref('cards')
    var loading       = ref(false)
    var equipements   = ref([])
    var shifts        = ref([])
    var equipes       = ref([])
    var allSessions   = ref([])
    var allPlanning   = ref([])
    var filterSite    = ref('Tous')
    var filterEquipId = ref(null)
    var filterPlanStatut = ref('')
    var sessSearch    = ref('')
    var sessEquipId   = ref(null)
    var sessStatut    = ref('')
    var sessShiftId   = ref(null)
    var sessSortCol   = ref('date')
    var sessSortDir   = ref('desc')
    var ganttPeriod   = ref('1mois')
    var ganttOffset   = ref(0)
    var ganttDays     = ref([])
    var ganttHeaderDays = ref([])
    var ganttRangeLabel = ref('')
    var ganttDayW     = 28   // px par jour
    var lotSearchTimeout = null

    var views = [
      { key:'cards',    icon:'⊞', label:'Équipements' },
      { key:'gantt',    icon:'▦', label:'Gantt PDP' },
      { key:'sessions', icon:'▥', label:'Sessions' },
      { key:'planning', icon:'☰', label:'Planning PDP' }
    ]

    var sessModal = reactive({ show:false, editing:null, equip:null, lotSearch:'', lotSuggestions:[], lot:null, date:'', heure_debut:'', heure_fin:'', shift_id:null, equipe_id:null, colis_produits:null, statut:'En cours', error:'', saving:false })
    var planModal = reactive({ show:false, editing:null, equip:null, lotSearch:'', lotSuggestions:[], lot:null, equipement_id:null, date_debut:'', date_fin:'', duree_jours:null, statut:'Planifié', commentaire:'', error:'', saving:false })

    // ── Helpers ──
    var fmtDate = function(d) {
      if (!d) return ''
      var p = d.slice(0,10).split('-')
      return p[2]+'/'+p[1]+'/'+p[0]
    }

    var oeeClass = function(v) {
      if (v == null) return ''
      if (v >= 85) return 'val-green'
      if (v >= 60) return 'val-orange'
      return 'val-red'
    }

    var nowDate = function() { return new Date().toISOString().slice(0,10) }
    var nowTime = function() {
      var n = new Date()
      return String(n.getHours()).padStart(2,'0')+':'+String(n.getMinutes()).padStart(2,'0')
    }

    // ── Données dérivées ──
    var filteredEquipements = computed(function() {
      if (filterSite.value === 'Tous') return equipements.value
      return equipements.value.filter(function(e){ return e.site === filterSite.value })
    })

    var getActiveSession = function(equipId) {
      return allSessions.value.find(function(s){ return s.equipement_id===equipId && s.statut!=='Clôturé' }) || null
    }

    var getNextPlan = function(equipId) {
      return allPlanning.value.find(function(p){ return p.equipement_id===equipId && p.statut_planification==='Planifié' }) || null
    }

    var getPlanQueue = function(equipId) {
      return allPlanning.value.filter(function(p){ return p.equipement_id===equipId && p.statut_planification==='Planifié' })
    }

    var getRendPct = function(s) {
      if (!s || !s.objectif_boites || !s.colis_produits) return 0
      return Math.round((s.colis_produits / s.objectif_boites) * 100)
    }

    var cardStatut = function(eq) {
      var s = getActiveSession(eq.id)
      return s ? s.statut : 'Disponible'
    }

    var cardColor = function(eq) {
      var s = getActiveSession(eq.id)
      if (!s) return '#9CA3AF'
      if (s.statut === 'En cours') return '#1D9E75'
      if (s.statut === 'Arrêt')    return '#EF4444'
      return '#F97316'
    }

    var cardClass = function(eq) {
      var s = getActiveSession(eq.id)
      if (!s) return 'card-dispo'
      if (s.statut === 'En cours') return 'card-encours'
      if (s.statut === 'Arrêt')    return 'card-arret'
      return 'card-pause'
    }

    var filteredSessions = computed(function() {
      var res = allSessions.value.slice()
      if (filterSite.value !== 'Tous') res = res.filter(function(s){ return s.site === filterSite.value })
      if (sessEquipId.value) res = res.filter(function(s){ return s.equipement_id === sessEquipId.value })
      if (sessStatut.value)  res = res.filter(function(s){ return s.statut === sessStatut.value })
      if (sessShiftId.value) res = res.filter(function(s){ return s.shift_id === sessShiftId.value })
      if (sessSearch.value) {
        var q = sessSearch.value.toLowerCase()
        res = res.filter(function(s){ return (s.numero_lot||'').toLowerCase().includes(q) || (s.code_article||'').toLowerCase().includes(q) })
      }
      res = res.sort(function(a,b) {
        var va = a[sessSortCol.value] || '', vb = b[sessSortCol.value] || ''
        if (va < vb) return sessSortDir.value === 'asc' ? -1 : 1
        if (va > vb) return sessSortDir.value === 'asc' ? 1 : -1
        return 0
      })
      return res
    })

    var filteredPlanning = computed(function() {
      var res = allPlanning.value.slice()
      if (filterSite.value !== 'Tous') res = res.filter(function(p){ return p.site === filterSite.value })
      if (filterEquipId.value) res = res.filter(function(p){ return p.equipement_id === filterEquipId.value })
      if (filterPlanStatut.value) res = res.filter(function(p){ return p.statut_planification === filterPlanStatut.value })
      return res
    })

    var sortSess = function(col) {
      if (sessSortCol.value === col) sessSortDir.value = sessSortDir.value === 'asc' ? 'desc' : 'asc'
      else { sessSortCol.value = col; sessSortDir.value = 'asc' }
    }

    var sortArrow = function(col) {
      if (sessSortCol.value !== col) return '⇅'
      return sessSortDir.value === 'asc' ? '↑' : '↓'
    }

    var filterSessions = function() {} // computed handles reactivity

    // ── Gantt ──
    var buildGantt = function() {
      var today = new Date()
      var days = ganttPeriod.value === '2sem' ? 14 : ganttPeriod.value === '1mois' ? 31 : 92
      var start = new Date(today)
      start.setDate(today.getDate() + ganttOffset.value * days)
      // Snap to Monday
      var diff = (start.getDay() + 6) % 7
      start.setDate(start.getDate() - diff)

      var allDays = []
      for (var i = 0; i < days; i++) {
        var d = new Date(start)
        d.setDate(start.getDate() + i)
        var iso = d.toISOString().slice(0,10)
        allDays.push({ iso: iso, isToday: iso === today.toISOString().slice(0,10), isWeekend: d.getDay()===0||d.getDay()===6 })
      }
      ganttDays.value = allDays

      // Header groupé par semaine/mois
      var headers = []
      if (days <= 14) {
        // Grouper par jour
        allDays.forEach(function(d) {
          var dt = new Date(d.iso)
          var lbls = ['Dim','Lun','Mar','Mer','Jeu','Ven','Sam']
          headers.push({ iso: d.iso, label: lbls[dt.getDay()]+' '+dt.getDate(), span: 1, isToday: d.isToday, isWeekend: d.isWeekend })
        })
      } else if (days <= 31) {
        // Grouper par semaine
        var weekMap = {}
        allDays.forEach(function(d) {
          var dt = new Date(d.iso)
          var mon = new Date(dt)
          var wdiff = (dt.getDay() + 6) % 7
          mon.setDate(dt.getDate() - wdiff)
          var key = mon.toISOString().slice(0,10)
          if (!weekMap[key]) { weekMap[key] = { iso: key, label: 'Sem '+mon.getDate()+'/'+( mon.getMonth()+1), span: 0 } }
          weekMap[key].span++
        })
        Object.values(weekMap).forEach(function(w) { headers.push(w) })
      } else {
        // Grouper par mois
        var monthMap = {}
        allDays.forEach(function(d) {
          var key = d.iso.slice(0,7)
          if (!monthMap[key]) { var mns = ['Jan','Fév','Mar','Avr','Mai','Juin','Juil','Aoû','Sep','Oct','Nov','Déc']; var mo = parseInt(d.iso.slice(5,7))-1; monthMap[key] = { iso: key, label: mns[mo]+' '+d.iso.slice(0,4), span: 0 } }
          monthMap[key].span++
        })
        Object.values(monthMap).forEach(function(m) { headers.push(m) })
      }
      ganttHeaderDays.value = headers

      // Range label
      var last = new Date(allDays[allDays.length-1].iso)
      ganttRangeLabel.value = fmtDate(start.toISOString().slice(0,10)) + ' — ' + fmtDate(last.toISOString().slice(0,10))
    }

    var dayOffset = function(isoDate) {
      if (!isoDate || !ganttDays.value.length) return -1
      return ganttDays.value.findIndex(function(d){ return d.iso === isoDate.slice(0,10) })
    }

    var getGanttBars = function(equipId) {
      var bars = []
      allPlanning.value.filter(function(p){ return p.equipement_id === equipId && p.statut_planification !== 'Annulé' }).forEach(function(p) {
        var left  = dayOffset(p.date_debut_estimee)
        var right = dayOffset(p.date_fin_estimee)
        if (left < 0 && right < 0) return
        if (left < 0) left = 0
        if (right < 0) right = ganttDays.value.length - 1
        var colorMap = { 'Planifié':'#185FA5', 'En cours':'#1D9E75', 'Clôturé':'#9CA3AF' }
        bars.push({
          id: p.id, plan: p,
          left: left * ganttDayW,
          width: (right - left + 1) * ganttDayW - 2,
          color: colorMap[p.statut_planification] || '#185FA5',
          type: p.statut_planification?.toLowerCase().replace(' ','-') || 'planifie',
          label: p.numero_lot,
          tooltip: 'Lot ' + p.numero_lot + ' · ' + p.code_article + ' · ' + fmtDate(p.date_debut_estimee) + ' → ' + fmtDate(p.date_fin_estimee)
        })
      })
      return bars
    }

    var getGanttSessionBars = function(equipId) {
      var bars = []
      allSessions.value.filter(function(s){ return s.equipement_id === equipId }).forEach(function(s) {
        var left = dayOffset(s.date)
        if (left < 0) return
        bars.push({
          id: s.id,
          left: left * ganttDayW,
          width: ganttDayW - 2,
          label: s.numero_lot,
          tooltip: 'Session · Lot ' + s.numero_lot + ' · ' + s.statut
        })
      })
      return bars
    }

    // ── Chargement ──
    var loadAll = async function() {
      loading.value = true
      var [rEq, rSh, rEqp, rPlan, rSess] = await Promise.all([
        supabase.from('equipements_conditionnement').select('*').eq('actif',true).order('ordre_affichage'),
        supabase.from('shifts').select('id,nom,couleur').eq('actif',true).order('heure_debut'),
        supabase.from('equipes').select('id,nom,couleur').eq('actif',true).order('nom'),
        supabase.from('planification_conditionnement')
          .select('*, lots(numero_lot, products(code_article, description)), equipements_conditionnement(nom_equipement, site)')
          .neq('statut_planification','Annulé')
          .order('equipement_id').order('ordre_plan'),
        supabase.from('production_sessions')
          .select('*, lots(numero_lot, products(code_article,description)), equipements_conditionnement(nom_equipement,site), shifts(nom,couleur), equipes(nom,couleur)')
          .is('deleted_at',null)
          .order('date', { ascending:false }).order('heure_debut', { ascending:false })
          .limit(500)
      ])

      if (rEq.data)  equipements.value = rEq.data
      if (rSh.data)  shifts.value      = rSh.data
      if (rEqp.data) equipes.value     = rEqp.data

      if (rPlan.data) {
        allPlanning.value = rPlan.data.map(function(p) {
          return Object.assign({}, p, {
            numero_lot:    p.lots ? p.lots.numero_lot : '—',
            code_article:  p.lots && p.lots.products ? p.lots.products.code_article : '—',
            description:   p.lots && p.lots.products ? p.lots.products.description  : '',
            nom_equipement: p.equipements_conditionnement ? p.equipements_conditionnement.nom_equipement : '—',
            site:          p.equipements_conditionnement ? p.equipements_conditionnement.site : ''
          })
        })
      }

      if (rSess.data) {
        allSessions.value = rSess.data.map(function(s) {
          return Object.assign({}, s, {
            numero_lot:   s.lots ? s.lots.numero_lot : '—',
            code_article: s.lots && s.lots.products ? s.lots.products.code_article : '—',
            description:  s.lots && s.lots.products ? s.lots.products.description  : '',
            nom_equipement: s.equipements_conditionnement ? s.equipements_conditionnement.nom_equipement : '—',
            site:         s.equipements_conditionnement ? s.equipements_conditionnement.site : '',
            shift_nom:    s.shifts  ? s.shifts.nom    : '',
            shift_couleur:s.shifts  ? s.shifts.couleur : '#3B82F6',
            equipe_nom:   s.equipes ? s.equipes.nom   : '',
            equipe_couleur:s.equipes ? s.equipes.couleur : '#8B5CF6'
          })
        })
      }

      loading.value = false
      buildGantt()
    }

    // ── Recherche lots ──
    var searchLots = function(target) {
      clearTimeout(lotSearchTimeout)
      var q = target === 'sess' ? sessModal.lotSearch : planModal.lotSearch
      if (!q || q.length < 2) {
        if (target === 'sess') sessModal.lotSuggestions = []
        else planModal.lotSuggestions = []
        return
      }
      lotSearchTimeout = setTimeout(async function() {
        var r = await supabase.from('lots')
          .select('id, numero_lot, product_id, products(code_article, description)')
          .ilike('numero_lot', '%'+q+'%').limit(8)
        var mapped = (r.data||[]).map(function(l) {
          return { id:l.id, numero_lot:l.numero_lot, code_article:l.products?l.products.code_article:'', description:l.products?l.products.description:'', product_id:l.product_id }
        })
        if (target === 'sess') sessModal.lotSuggestions = mapped
        else planModal.lotSuggestions = mapped
      }, 200)
    }

    var selectLot = function(target, l) {
      if (target === 'sess') { sessModal.lot = l; sessModal.lotSearch = l.numero_lot; sessModal.lotSuggestions = [] }
      else { planModal.lot = l; planModal.lotSearch = l.numero_lot; planModal.lotSuggestions = [] }
    }

    // ── Session CRUD ──
    var openAddSession = function(eq) {
      sessModal.editing = null; sessModal.equip = eq
      sessModal.lotSearch=''; sessModal.lot=null; sessModal.lotSuggestions=[]
      sessModal.date=nowDate(); sessModal.heure_debut=nowTime(); sessModal.heure_fin=''
      sessModal.shift_id=null; sessModal.equipe_id=null; sessModal.colis_produits=null
      sessModal.statut='En cours'; sessModal.error=''; sessModal.saving=false
      sessModal.show = true
    }

    var saveSession = async function() {
      if (!sessModal.lot) { sessModal.error='Sélectionner un lot.'; return }
      if (!sessModal.date || !sessModal.heure_debut) { sessModal.error='Date et heure de début requises.'; return }
      sessModal.saving = true
      var eq = sessModal.equip
      var cadObj = eq.cadence_objectif_boite_min
      var to = eq.temps_ouverture_shift_min || 480
      var pauses = eq.temps_pause_planifie_min || 0
      var objBoites = cadObj ? Math.round(cadObj * (to - pauses)) : null

      var payload = {
        lot_id: sessModal.lot.id, equipement_id: eq.id,
        shift_id: sessModal.shift_id||null, equipe_id: sessModal.equipe_id||null,
        date: sessModal.date, heure_debut: sessModal.heure_debut+':00',
        heure_fin: sessModal.heure_fin ? sessModal.heure_fin+':00' : null,
        statut: sessModal.statut, colis_produits: sessModal.colis_produits||0,
        cadence_nominale_snapshot: eq.cadence_nominale_boite_min||null,
        cadence_objectif_snapshot: cadObj||null,
        objectif_boites: objBoites, colis_rebuts: 0
      }
      var r = await supabase.from('production_sessions').insert(payload)
      if (r.error) { sessModal.error=r.error.message; sessModal.saving=false; return }
      sessModal.show=false; sessModal.saving=false
      await loadAll()
    }

    // ── Plan PDP CRUD ──
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
      planModal.equip = null
      planModal.lotSearch = p.numero_lot; planModal.lot = { id: p.lot_id, numero_lot: p.numero_lot, description: p.description }
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
        equipement_id: planModal.equipement_id,
        date_debut_estimee: planModal.date_debut||null,
        date_fin_estimee:   planModal.date_fin||null,
        duree_estimee_jours: planModal.duree_jours||null,
        statut_planification: planModal.statut,
        commentaire: planModal.commentaire||null,
        updated_at: new Date().toISOString()
      }
      var r
      if (planModal.editing) {
        r = await supabase.from('planification_conditionnement').update(payload).eq('id', planModal.editing.id)
      } else {
        // Trouver le prochain ordre_plan pour cet équipement
        var maxOrdre = allPlanning.value.filter(function(p){ return p.equipement_id===planModal.equipement_id }).reduce(function(m,p){ return Math.max(m,p.ordre_plan||0) }, 0)
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
      var swapIdx = dir==='up' ? idx-1 : idx+1
      if (swapIdx<0 || swapIdx>=sameEquip.length) return
      var other = sameEquip[swapIdx]
      var tmpOrdre = p.ordre_plan
      await supabase.from('planification_conditionnement').update({ ordre_plan: other.ordre_plan, updated_at:new Date().toISOString() }).eq('id', p.id)
      await supabase.from('planification_conditionnement').update({ ordre_plan: tmpOrdre, updated_at:new Date().toISOString() }).eq('id', other.id)
      await loadAll()
    }

    onMounted(loadAll)

    return {
      activeView, loading, views, equipements, shifts, equipes,
      allSessions, allPlanning, filterSite, filterEquipId, filterPlanStatut,
      sessSearch, sessEquipId, sessStatut, sessShiftId,
      sessSortCol, sessSortDir,
      ganttPeriod, ganttOffset, ganttDays, ganttHeaderDays, ganttRangeLabel, ganttDayW,
      filteredEquipements, filteredSessions, filteredPlanning,
      sessModal, planModal,
      fmtDate, oeeClass, sortArrow,
      getActiveSession, getNextPlan, getPlanQueue, getRendPct,
      cardStatut, cardColor, cardClass,
      getGanttBars, getGanttSessionBars,
      buildGantt,
      loadAll, filterSessions, sortSess,
      openAddSession, saveSession,
      openAddPlan, openEditPlan, calcDateFin, savePlan, cancelPlan, movePlan,
      searchLots, selectLot
    }
  }
}
</script>

<style scoped>
.pdp-cond{min-height:100%}
.ph{display:flex;align-items:center;justify-content:space-between;padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:14px;flex-wrap:wrap;gap:8px}
.ph-left{display:flex;align-items:center;gap:12px;flex-wrap:wrap}
.pt{font-size:11px;font-weight:500;letter-spacing:1.5px;white-space:nowrap}
.ph-right{display:flex;align-items:center;gap:6px}
.view-tabs{display:flex;gap:2px}
.vtab{display:flex;align-items:center;gap:4px;padding:5px 10px;font-size:11px;border:1px solid #ddd;background:#fff;border-radius:2px;cursor:pointer;white-space:nowrap}
.vtab.active{background:#0a0a0a;color:#fff;border-color:#0a0a0a}
.vtab-icon{font-size:12px}
.site-tabs{display:flex;gap:3px}
.site-tab{padding:4px 10px;font-size:11px;border:1px solid #ddd;background:#fff;border-radius:2px;cursor:pointer}
.site-tab.active{background:#0a0a0a;color:#fff;border-color:#0a0a0a}
.btn-refresh{padding:4px 10px;font-size:16px;border:1px solid #ddd;background:#fff;border-radius:2px;cursor:pointer}
.btn-refresh.spinning{animation:spin .7s linear infinite}
@keyframes spin{from{transform:rotate(0)}to{transform:rotate(360deg)}}
.loading{padding:24px;text-align:center;color:#999}
.empty{padding:30px;text-align:center;color:#bbb;font-size:13px}

/* ── CARDS ── */
.cards-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px}
.eq-card{border:1px solid #e0e0e0;border-radius:6px;border-top:3px solid #e0e0e0;background:#fff;overflow:hidden}
.card-encours{border-top-color:#1D9E75}
.card-arret{border-top-color:#EF4444}
.card-pause{border-top-color:#F97316}
.card-dispo{border-top-color:#9CA3AF}
.card-hd{display:flex;align-items:flex-start;justify-content:space-between;padding:10px 12px 6px}
.card-nom{font-size:13px;font-weight:600}
.card-site{font-size:9px;color:#aaa;text-transform:uppercase;letter-spacing:.5px;margin-top:1px}
.card-status{font-size:10px;font-weight:600;padding:2px 8px;border-radius:8px;white-space:nowrap}
.card-lot{padding:6px 12px 2px}
.lot-n{font-family:'SF Mono',monospace;font-size:13px;font-weight:600}
.lot-p{font-size:11px;color:#666;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.card-prog{padding:6px 12px}
.prog-bar{height:6px;background:#f0f0f0;border-radius:3px;overflow:hidden;margin-bottom:3px}
.prog-fill{height:100%;border-radius:3px;transition:.5s}
.prog-nums{display:flex;justify-content:space-between;font-size:10px;color:#999}
.prog-pct{font-weight:700}
.card-cadence{padding:2px 12px 6px;font-size:10px;color:#888}
.cad-r{font-family:'SF Mono',monospace}
.cad-sep{margin:0 4px}
.cad-o{color:#185FA5;font-family:'SF Mono',monospace}
.card-empty{padding:8px 12px;font-size:11px;color:#bbb;font-style:italic}
.card-next{padding:6px 12px 4px;background:#fafafa;border-top:1px solid #f0f0f0}
.next-label{font-size:9px;text-transform:uppercase;letter-spacing:.5px;color:#aaa;margin-bottom:3px}
.next-lot{font-family:'SF Mono',monospace;font-size:12px;font-weight:600;color:#185FA5}
.next-prod{font-size:11px;color:#666}
.next-dates{display:flex;align-items:center;gap:4px;margin-top:3px;font-size:10px;font-family:'SF Mono',monospace;color:#888}
.nd-arr{color:#ccc}
.card-queue{padding:6px 12px 4px;border-top:1px solid #f0f0f0}
.queue-title{font-size:9px;text-transform:uppercase;letter-spacing:.5px;color:#aaa;margin-bottom:4px}
.queue-item{display:flex;align-items:center;gap:6px;padding:2px 0;font-size:11px}
.qi-rank{width:14px;height:14px;border-radius:50%;background:#e8e8e8;color:#666;display:flex;align-items:center;justify-content:center;font-size:9px;font-weight:600;flex-shrink:0}
.qi-lot{font-family:'SF Mono',monospace;font-size:11px;font-weight:500;color:#0a0a0a;min-width:50px}
.qi-prod{flex:1;color:#666;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.qi-dur{font-size:10px;color:#aaa;font-family:'SF Mono',monospace}
.queue-more{font-size:10px;color:#aaa;padding:2px 0}
.card-actions{display:flex;gap:4px;padding:8px 12px;border-top:1px solid #f5f5f5}
.ca-btn{flex:1;padding:6px 4px;border:1px solid #e0e0e0;background:#fff;font-size:11px;border-radius:2px;cursor:pointer}
.ca-btn:hover{background:#f5f5f5}
.ca-btn.ca-sec{color:#185FA5;border-color:#bfdbfe;background:#EBF5FF}
.ca-btn.ca-sec:hover{background:#dbeafe}

/* ── GANTT ── */
.gantt-wrap{overflow-x:auto}
.gantt-controls{display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;flex-wrap:wrap;gap:8px}
.gc-left{display:flex;gap:4px}
.gp-btn{padding:4px 10px;font-size:11px;border:1px solid #ddd;background:#fff;border-radius:2px;cursor:pointer}
.gp-btn.active,.gp-btn.today-btn{background:#0a0a0a;color:#fff;border-color:#0a0a0a}
.gp-btn:hover:not(.active):not(.today-btn){background:#f5f5f5}
.gantt-range{font-size:11px;color:#666;font-family:'SF Mono',monospace}
.gantt-table{display:grid;grid-template-columns:140px 1fr;border:1px solid #e0e0e0;border-radius:4px;overflow:hidden;min-width:600px}
.gt-corner{background:#f8f8f8;border-bottom:2px solid #e0e0e0;border-right:1px solid #e0e0e0}
.gt-dates-row{display:flex;background:#f8f8f8;border-bottom:2px solid #e0e0e0;overflow:hidden}
.gt-date-cell{font-size:10px;font-weight:600;text-align:center;padding:4px 2px;border-right:1px solid #e8e8e8;white-space:nowrap;overflow:hidden;flex-shrink:0}
.gt-date-cell.today{background:#EBF5FF;color:#185FA5}
.gt-date-cell.weekend{color:#ddd}
.gt-eq-label{padding:8px 10px;border-right:1px solid #e0e0e0;border-bottom:1px solid #f0f0f0;display:flex;flex-direction:column;justify-content:center;background:#fafafa}
.gel-nom{font-size:12px;font-weight:600}
.gel-site{font-size:9px;color:#aaa;text-transform:uppercase;letter-spacing:.5px}
.gt-eq-row{position:relative;height:40px;border-bottom:1px solid #f0f0f0;overflow:hidden}
.gt-day-bg{position:absolute;top:0;bottom:0}
.gt-day-bg.today{background:rgba(24,95,165,.06)}
.gt-day-bg.weekend{background:#fafafa}
.gt-bar{position:absolute;top:6px;height:28px;border-radius:3px;border:1px solid;cursor:pointer;display:flex;align-items:center;padding:0 6px;transition:.15s;z-index:1}
.gt-bar:hover{filter:brightness(.9);z-index:2}
.gt-bar-session{background:#F97316!important;opacity:.5;cursor:default;top:18px;height:10px;border:none;border-radius:2px}
.gt-bar-label{font-size:10px;font-weight:600;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.gantt-legend{grid-column:span 2;display:flex;gap:14px;padding:8px 12px;background:#f8f8f8;border-top:1px solid #e0e0e0}
.gl-item{display:flex;align-items:center;gap:5px;font-size:11px;color:#666}
.gl-dot{width:10px;height:10px;border-radius:2px}

/* ── TABLE COMMUNE ── */
.table-toolbar{display:flex;gap:8px;margin-bottom:10px;flex-wrap:wrap}
.t-search{flex:1;min-width:160px;padding:7px 10px;border:1px solid #ddd;font-size:12px;outline:none;border-radius:2px;font-family:inherit}
.t-search:focus{border-color:#185FA5}
.t-sel{padding:7px 10px;border:1px solid #ddd;font-size:12px;border-radius:2px;background:#fff;font-family:inherit;cursor:pointer}
.btn-add-plan{padding:7px 14px;background:#0a0a0a;color:#fff;border:none;font-size:12px;border-radius:2px;cursor:pointer;white-space:nowrap}
.btn-add-plan:hover{background:#333}
.data-table{width:100%;border-collapse:collapse;font-size:12px}
.data-table th{background:#f5f5f5;padding:7px 10px;text-align:left;font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.4px;border-bottom:2px solid #e0e0e0;white-space:nowrap}
.data-table th.sortable{cursor:pointer;user-select:none}
.data-table th.sortable:hover{background:#eee}
.data-table th.num-col{text-align:center}
.data-table td{padding:8px 10px;border-bottom:1px solid #f0f0f0;vertical-align:middle}
.data-table tr:hover td{background:#fafafa}
.data-table tr.plan-annule td{opacity:.4}
.sort-arrow{font-size:10px;color:#aaa;margin-left:3px}
.mono-sm{font-family:'SF Mono',monospace;font-size:11px}
.small-txt{font-size:11px;color:#555;max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.num{text-align:center;font-family:'SF Mono',monospace;font-size:12px}
.val-green{color:#1D9E75;font-weight:600}
.val-orange{color:#F97316;font-weight:600}
.val-red{color:#EF4444;font-weight:600}
.sh-chip-sm,.eq-chip-sm{font-size:10px;font-weight:600;padding:1px 7px;border-radius:8px}
.stat-chip{font-size:10px;padding:2px 7px;border-radius:8px;font-weight:500}
.stat-en-cours{background:#F0FDF4;color:#15803D}
.stat-clôturé{background:#F5F5F5;color:#666}
.stat-arrêt{background:#FEF2F2;color:#DC2626}
.plan-chip{font-size:10px;padding:2px 7px;border-radius:8px;font-weight:500}
.plan-planifié{background:#EFF6FF;color:#1D4ED8}
.plan-en-cours{background:#F0FDF4;color:#15803D}
.plan-clôturé{background:#F5F5F5;color:#666}
.order-btns{display:flex;align-items:center;gap:2px;justify-content:center}
.ob{background:none;border:1px solid #ddd;font-size:10px;padding:1px 5px;cursor:pointer;border-radius:2px}
.ob:hover:not(:disabled){background:#f0f0f0}
.ob:disabled{opacity:.3;cursor:not-allowed}
.order-num{font-family:'SF Mono',monospace;font-size:11px;font-weight:600;min-width:20px;text-align:center}
.acts{text-align:right;white-space:nowrap}
.ia{background:none;border:none;cursor:pointer;font-size:12px;padding:3px 5px;border-radius:2px;opacity:.7}
.ia:hover{background:#e8e8e8;opacity:1}
.ia.del:hover{background:#fde8e8}

/* ── MODALS ── */
.overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.45);display:flex;align-items:center;justify-content:center;z-index:200}
.modal{background:#fff;padding:24px;width:500px;max-width:96vw;border-radius:8px;max-height:92vh;overflow-y:auto}
.modal-hd{font-size:14px;font-weight:600;margin-bottom:14px}
.lbl{display:block;font-size:11px;color:#666;text-transform:uppercase;letter-spacing:.3px;margin-bottom:4px;margin-top:10px}
.inp{width:100%;padding:8px 10px;border:1px solid #ddd;font-size:13px;outline:none;box-sizing:border-box;font-family:inherit;border-radius:2px}
.inp:focus{border-color:#185FA5}
.inp:disabled{opacity:.4}
.form-row{display:flex;gap:10px}
.form-field{flex:1}
.auto-wrap{position:relative}
.auto-list{position:absolute;top:100%;left:0;right:0;background:#fff;border:1px solid #ddd;border-radius:3px;box-shadow:0 4px 12px rgba(0,0,0,.08);z-index:10;max-height:180px;overflow-y:auto}
.auto-item{display:flex;gap:8px;padding:7px 10px;cursor:pointer;font-size:12px}
.auto-item:hover{background:#f5f5f5}
.auto-code{font-family:'SF Mono',monospace;font-weight:600;color:#185FA5;min-width:60px}
.auto-desc{color:#666;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.sel-lot-info{font-size:11px;color:#1D9E75;padding:4px 8px;background:#f0fdf4;border-radius:3px;margin-top:4px}
.err{color:#E24B4A;font-size:12px;margin-top:8px;padding:6px 10px;background:#FEF2F2;border-radius:3px}
.modal-acts{display:flex;gap:8px;margin-top:14px}
.btn-save{flex:1;padding:10px;background:#185FA5;color:#fff;border:none;font-size:13px;font-weight:500;cursor:pointer;border-radius:2px}
.btn-save:hover:not(:disabled){background:#0C447C}
.btn-save:disabled{opacity:.5}
.btn-cancel{flex:1;padding:10px;background:#f5f5f5;color:#666;border:none;font-size:13px;cursor:pointer;border-radius:2px}
.btn-cancel:hover{background:#eee}

@media(max-width:768px){
  .cards-grid{grid-template-columns:1fr}
  .view-tabs .vtab-icon+*{display:none}
  .form-row{flex-direction:column}
}
</style>
