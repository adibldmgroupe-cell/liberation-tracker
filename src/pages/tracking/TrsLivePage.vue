<template>
  <div class="trs-live">
    <div class="ph">
      <div class="ph-left">
        <span class="pt">TRS LIVE</span>
        <span class="pt-clock">{{clock}}</span>
      </div>
      <div class="ph-right">
        <div class="site-tabs">
          <button v-for="s in ['Tous','PHARMA','OTC']" :key="s" class="site-tab" :class="{active:filterSite===s}" @click="filterSite=s">{{s}}</button>
        </div>
        <button class="btn-refresh" @click="loadAll" :class="{spinning:loading}" title="Rafraîchir">↻</button>
      </div>
    </div>

    <!-- ══ GRILLE ÉQUIPEMENTS ══ -->
    <div v-if="loading && !panels.length" class="loading">Chargement…</div>
    <div class="panels-grid" v-else>
      <div
        v-for="p in filteredPanels" :key="p.equip.id"
        class="panel" :class="panelClass(p)"
      >
        <!-- ── Header équipement ── -->
        <div class="panel-hd" :style="{borderTopColor: panelColor(p)}">
          <div class="panel-hd-left">
            <div class="panel-equip">{{p.equip.nom_equipement}}</div>
            <div class="panel-site">{{p.equip.site}}</div>
          </div>
          <div class="panel-status-badge" :style="{background:panelColor(p)+'22', color:panelColor(p)}">
            {{p.session ? p.session.statut : 'Disponible'}}
          </div>
        </div>

        <!-- ── Shift & équipe ── -->
        <div class="panel-shift" v-if="p.session && (p.shiftNom || p.equipeNom)">
          <span v-if="p.shiftNom" class="shift-chip" :style="{background:p.shiftCouleur+'22',color:p.shiftCouleur,borderColor:p.shiftCouleur+'44'}">{{p.shiftNom}}</span>
          <span v-if="p.equipeNom" class="equipe-chip" :style="{background:p.equipeCouleur+'22',color:p.equipeCouleur}">{{p.equipeNom}}</span>
        </div>

        <!-- ── Lot en cours ── -->
        <div class="panel-lot" v-if="p.session">
          <div class="lot-num">Lot {{p.lotNum}}</div>
          <div class="lot-prod">{{p.lotProd}}</div>
        </div>
        <div class="panel-empty" v-else>Aucune session active</div>

        <!-- ── Minuteur principal ── -->
        <div class="panel-timer" v-if="p.session">
          <div class="timer-label">{{p.session.statut === 'En cours' ? 'TEMPS PRODUCTION' : p.session.statut === 'Arrêt' ? 'ARRÊT EN COURS' : 'PAUSE'}}</div>
          <div class="timer-val" :style="{color: p.session.statut === 'En cours' ? '#1D9E75' : p.session.statut === 'Arrêt' ? '#EF4444' : '#F97316'}">
            {{p.session.statut === 'En cours' ? timers[p.equip.id] || '00:00:00' : (p.activeArret ? arretTimers[p.activeArret.id] || '00:00:00' : '—')}}
          </div>
          <!-- Info arrêt actif -->
          <div class="arret-info" v-if="p.activeArret">
            <span class="arret-code-chip" :style="{background:(p.activeArret.couleur||'#EF4444')+'22', color:p.activeArret.couleur||'#EF4444', borderColor:(p.activeArret.couleur||'#EF4444')+'55'}">
              {{p.activeArret.arret_code || '—'}}
            </span>
            <span class="arret-nom">{{p.activeArret.arret_nom || p.activeArret.famille_nom}}</span>
          </div>
        </div>

        <!-- ── Cadence & comptage ── -->
        <div class="panel-metrics" v-if="p.session">
          <div class="metric">
            <div class="metric-val">{{p.session.colis_produits || 0}}</div>
            <div class="metric-lbl">Colis prod.</div>
          </div>
          <div class="metric">
            <div class="metric-val" :class="{ok: p.rendPct >= 100, warn: p.rendPct >= 80 && p.rendPct < 100, bad: p.rendPct < 80}">
              {{p.session.objectif_boites || '—'}}
            </div>
            <div class="metric-lbl">Objectif</div>
          </div>
          <div class="metric">
            <div class="metric-val cadence-val">
              {{p.session.cadence_reelle_boite_min != null ? p.session.cadence_reelle_boite_min : '—'}}
            </div>
            <div class="metric-lbl">b/min réel</div>
          </div>
          <div class="metric">
            <div class="metric-val">{{p.session.cadence_objectif_snapshot || p.equip.cadence_objectif_boite_min || '—'}}</div>
            <div class="metric-lbl">b/min obj.</div>
          </div>
        </div>

        <!-- ── Barre de rendement ── -->
        <div class="panel-rend" v-if="p.session && p.session.objectif_boites">
          <div class="rend-bar">
            <div class="rend-fill" :style="{width: Math.min(p.rendPct,100)+'%', background: p.rendPct>=100?'#1D9E75':p.rendPct>=80?'#F97316':'#EF4444'}"></div>
          </div>
          <div class="rend-pct" :class="{ok:p.rendPct>=100,warn:p.rendPct>=80&&p.rendPct<100,bad:p.rendPct<80}">{{p.rendPct}}%</div>
        </div>

        <!-- ── OEE indicateurs ── -->
        <div class="panel-oee" v-if="p.session">
          <div class="oee-item">
            <div class="oee-val" :class="oeeClass(p.session.disponibilite)">{{p.session.disponibilite != null ? p.session.disponibilite+'%' : '—'}}</div>
            <div class="oee-lbl">Dispo</div>
          </div>
          <div class="oee-sep"></div>
          <div class="oee-item">
            <div class="oee-val" :class="oeeClass(p.session.performance)">{{p.session.performance != null ? p.session.performance+'%' : '—'}}</div>
            <div class="oee-lbl">Perf.</div>
          </div>
          <div class="oee-sep"></div>
          <div class="oee-item">
            <div class="oee-val" :class="oeeClass(p.session.qualite)">{{p.session.qualite != null ? p.session.qualite+'%' : '—'}}</div>
            <div class="oee-lbl">Qual.</div>
          </div>
          <div class="oee-sep"></div>
          <div class="oee-item trs-item">
            <div class="oee-val trs-big" :class="oeeClass(p.session.trs)">{{p.session.trs != null ? p.session.trs+'%' : '—'}}</div>
            <div class="oee-lbl">TRS</div>
          </div>
        </div>

        <!-- ── Actions ── -->
        <div class="panel-actions">
          <template v-if="!p.session">
            <button class="act-btn act-start" @click="openStartModal(p.equip)">▶ Démarrer session</button>
          </template>
          <template v-else-if="p.session.statut === 'En cours'">
            <button class="act-btn act-stop" @click="openArretModal(p)">⏸ Déclarer arrêt</button>
            <button class="act-btn act-count" @click="openComptageModal(p)">+ Comptage</button>
            <button class="act-btn act-close" @click="openCloseModal(p)">✓ Clôturer</button>
          </template>
          <template v-else-if="p.session.statut === 'Arrêt' || p.session.statut === 'Pause'">
            <button class="act-btn act-resume" @click="clotureArret(p)">▶ Reprendre</button>
            <button class="act-btn act-requalif" @click="openRequalifModal(p)" v-if="p.activeArret">✎ Requalifier</button>
          </template>
        </div>

        <!-- ── Historique arrêts du shift ── -->
        <div class="panel-arrets" v-if="p.session && p.arrets && p.arrets.length">
          <div class="arrets-title">Arrêts du shift</div>
          <div v-for="a in p.arrets" :key="a.id" class="arret-row" :class="{running: a.is_running}">
            <span class="arret-dot" :style="{background:a.couleur||a.est_pause?'#10B981':'#EF4444'}"></span>
            <span class="arret-code-sm">{{a.arret_code||'—'}}</span>
            <span class="arret-nom-sm">{{a.arret_nom||a.famille_nom||'—'}}</span>
            <span class="arret-dur">{{a.is_running ? '⏱ en cours' : (a.duree_minutes ? a.duree_minutes+'min' : '—')}}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- ══ MODAL DÉMARRER SESSION ══ -->
    <div class="overlay" v-if="startModal.show" @click.self="startModal.show=false">
      <div class="modal">
        <div class="modal-hd">▶ Démarrer une session — {{startModal.equip?.nom_equipement}}</div>

        <label class="lbl">N° Lot *</label>
        <div class="auto-wrap">
          <input v-model="startModal.lotSearch" class="inp" placeholder="Rechercher numéro de lot…" @input="searchLots" />
          <div class="auto-list" v-if="startModal.lotSuggestions.length">
            <div v-for="l in startModal.lotSuggestions" :key="l.id" class="auto-item" @mousedown.prevent="selectLot(l)">
              <span class="auto-code">{{l.numero_lot}}</span>
              <span class="auto-desc">{{l.code_article}} — {{l.description}}</span>
            </div>
          </div>
        </div>
        <div class="selected-lot" v-if="startModal.lot">
          ✓ Lot <strong>{{startModal.lot.numero_lot}}</strong> — {{startModal.lot.description}}
        </div>

        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Shift</label>
            <select v-model="startModal.shift_id" class="inp">
              <option :value="null">— Aucun —</option>
              <option v-for="s in shifts" :key="s.id" :value="s.id">{{s.nom}} ({{s.heure_debut.slice(0,5)}}→{{s.heure_fin.slice(0,5)}})</option>
            </select>
          </div>
          <div class="form-field">
            <label class="lbl">Équipe</label>
            <select v-model="startModal.equipe_id" class="inp">
              <option :value="null">— Aucune —</option>
              <option v-for="e in equipes" :key="e.id" :value="e.id">{{e.nom}}</option>
            </select>
          </div>
        </div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Date</label>
            <input type="date" v-model="startModal.date" class="inp" />
          </div>
          <div class="form-field">
            <label class="lbl">Heure début</label>
            <input type="time" v-model="startModal.heure_debut" class="inp" step="60" />
          </div>
        </div>

        <!-- Snapshot cadence objectif -->
        <div class="cadence-preview" v-if="startModal.equip">
          <div class="cp-row">
            <span class="cp-lbl">Cadence nominale</span>
            <span class="cp-val">{{startModal.equip.cadence_nominale_boite_min || '—'}} boîtes/min</span>
          </div>
          <div class="cp-row">
            <span class="cp-lbl">Cadence objectif</span>
            <span class="cp-val obj">{{startModal.cadenceObj || startModal.equip.cadence_objectif_boite_min || '—'}} boîtes/min</span>
          </div>
          <div class="cp-row" v-if="startModal.cadenceObj || startModal.equip.cadence_objectif_boite_min">
            <span class="cp-lbl">Objectif / shift</span>
            <span class="cp-val obj">{{computeObjShift(startModal)}} boîtes</span>
          </div>
        </div>

        <div class="err" v-if="startModal.error">{{startModal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save btn-go" @click="doStart" :disabled="startModal.saving || !startModal.lot">
            {{startModal.saving ? 'Démarrage…' : '▶ Démarrer'}}
          </button>
          <button class="btn-cancel" @click="startModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL DÉCLARER ARRÊT ══ -->
    <div class="overlay" v-if="arretModal.show" @click.self="arretModal.show=false">
      <div class="modal">
        <div class="modal-hd">⏸ Déclarer un arrêt — {{arretModal.panel?.equip.nom_equipement}}</div>

        <div class="cascade-selects">
          <div class="cs-step">
            <label class="lbl">Famille *</label>
            <select v-model="arretModal.famille_id" class="inp" @change="onFamilleChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="f in arretFamilles" :key="f.id" :value="f.id">{{f.nom}}</option>
            </select>
          </div>
          <div class="cs-arrow">→</div>
          <div class="cs-step">
            <label class="lbl">Sous-famille *</label>
            <select v-model="arretModal.sf_id" class="inp" :disabled="!arretModal.famille_id" @change="onSFChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="sf in arretModal.sousFamilles" :key="sf.id" :value="sf.id">{{sf.nom}}</option>
            </select>
          </div>
          <div class="cs-arrow">→</div>
          <div class="cs-step">
            <label class="lbl">Code arrêt *</label>
            <select v-model="arretModal.type_id" class="inp" :disabled="!arretModal.sf_id" @change="onTypeChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="t in arretModal.types" :key="t.id" :value="t.id">{{t.code}} — {{t.nom}}</option>
            </select>
          </div>
        </div>

        <!-- Preview type sélectionné -->
        <div class="type-preview" v-if="arretModal.selectedType">
          <span class="arret-code-chip" :style="{background:(arretModal.selectedType.couleur||arretModal.familleCouleur)+'22', color:arretModal.selectedType.couleur||arretModal.familleCouleur, borderColor:(arretModal.selectedType.couleur||arretModal.familleCouleur)+'55'}">
            {{arretModal.selectedType.code}}
          </span>
          <span class="type-prev-nom">{{arretModal.selectedType.nom}}</span>
          <span class="tag tag-plan" v-if="arretModal.selectedType.est_planifie">Planifié</span>
          <span class="tag tag-pause" v-if="arretModal.selectedType.est_pause">Pause</span>
          <span class="tag tag-dur" v-if="arretModal.selectedType.duree_std_min">~{{arretModal.selectedType.duree_std_min}} min</span>
        </div>

        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Heure début arrêt</label>
            <input type="time" v-model="arretModal.heure_debut" class="inp" step="60" />
          </div>
        </div>

        <label class="lbl">Commentaire</label>
        <input v-model="arretModal.commentaire" class="inp" placeholder="Optionnel…" />

        <div class="err" v-if="arretModal.error">{{arretModal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save btn-stop" @click="doArret" :disabled="arretModal.saving || !arretModal.type_id">
            {{arretModal.saving ? 'Enregistrement…' : '⏸ Démarrer chrono arrêt'}}
          </button>
          <button class="btn-cancel" @click="arretModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL REQUALIFIER ARRÊT ══ -->
    <div class="overlay" v-if="requalModal.show" @click.self="requalModal.show=false">
      <div class="modal modal-sm">
        <div class="modal-hd">✎ Requalifier l'arrêt en cours</div>
        <div class="modal-ctx">{{requalModal.panel?.equip.nom_equipement}} — arrêt actif</div>

        <div class="cascade-selects" style="flex-direction:column;gap:8px">
          <div>
            <label class="lbl">Famille</label>
            <select v-model="requalModal.famille_id" class="inp" @change="onRequalFamilleChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="f in arretFamilles" :key="f.id" :value="f.id">{{f.nom}}</option>
            </select>
          </div>
          <div>
            <label class="lbl">Sous-famille</label>
            <select v-model="requalModal.sf_id" class="inp" :disabled="!requalModal.famille_id" @change="onRequalSFChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="sf in requalModal.sousFamilles" :key="sf.id" :value="sf.id">{{sf.nom}}</option>
            </select>
          </div>
          <div>
            <label class="lbl">Code arrêt</label>
            <select v-model="requalModal.type_id" class="inp" :disabled="!requalModal.sf_id">
              <option :value="null">— Sélectionner —</option>
              <option v-for="t in requalModal.types" :key="t.id" :value="t.id">{{t.code}} — {{t.nom}}</option>
            </select>
          </div>
        </div>
        <div class="modal-acts">
          <button class="btn-save" @click="doRequalif" :disabled="requalModal.saving || !requalModal.type_id">{{requalModal.saving?'…':'Requalifier'}}</button>
          <button class="btn-cancel" @click="requalModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL COMPTAGE ══ -->
    <div class="overlay" v-if="comptageModal.show" @click.self="comptageModal.show=false">
      <div class="modal modal-sm">
        <div class="modal-hd">+ Saisie comptage — {{comptageModal.panel?.equip.nom_equipement}}</div>
        <div class="modal-ctx" v-if="comptageModal.panel?.session">
          Session en cours · Colis actuels : <strong>{{comptageModal.panel.session.colis_produits}}</strong>
        </div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Heure relevé</label>
            <input type="time" v-model="comptageModal.heure" class="inp" step="60" />
          </div>
          <div class="form-field">
            <label class="lbl">Colis cumulés *</label>
            <input type="number" v-model.number="comptageModal.colis" class="inp" placeholder="ex: 1250" min="0" />
          </div>
        </div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Rebuts cumulés</label>
            <input type="number" v-model.number="comptageModal.rebuts" class="inp" placeholder="0" min="0" />
          </div>
        </div>

        <!-- Calcul cadence instantanée -->
        <div class="cadence-calc" v-if="comptageModal.panel?.session && comptageModal.colis">
          <div class="cc-row">
            <span class="cc-lbl">Cadence calculée</span>
            <span class="cc-val">{{computeCadence(comptageModal)}} boîtes/min</span>
          </div>
          <div class="cc-row">
            <span class="cc-lbl">vs objectif</span>
            <span class="cc-val" :class="computeCadenceVsObj(comptageModal) >= 100 ? 'ok' : 'bad'">
              {{computeCadenceVsObj(comptageModal)}}%
            </span>
          </div>
        </div>

        <div class="modal-acts">
          <button class="btn-save" @click="doComptage" :disabled="comptageModal.saving || !comptageModal.colis">
            {{comptageModal.saving ? '…' : 'Enregistrer'}}
          </button>
          <button class="btn-cancel" @click="comptageModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL CLÔTURER SESSION ══ -->
    <div class="overlay" v-if="closeModal.show" @click.self="closeModal.show=false">
      <div class="modal">
        <div class="modal-hd">✓ Clôturer la session — {{closeModal.panel?.equip.nom_equipement}}</div>
        <div class="modal-ctx" v-if="closeModal.panel?.session">
          Lot {{closeModal.panel.lotNum}} · Démarré à {{closeModal.panel.session.heure_debut}}
        </div>

        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Heure fin *</label>
            <input type="time" v-model="closeModal.heure_fin" class="inp" step="60" />
          </div>
          <div class="form-field">
            <label class="lbl">Colis produits final *</label>
            <input type="number" v-model.number="closeModal.colis_produits" class="inp" min="0" />
          </div>
        </div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Colis rebuts</label>
            <input type="number" v-model.number="closeModal.colis_rebuts" class="inp" min="0" />
          </div>
        </div>
        <label class="lbl">Observation</label>
        <input v-model="closeModal.observation" class="inp" placeholder="Optionnel…" />

        <!-- Preview OEE calculé -->
        <div class="oee-preview" v-if="closeModal.panel && closeModal.heure_fin && closeModal.colis_produits">
          <div class="op-title">OEE estimé à la clôture</div>
          <div class="op-grid">
            <div class="op-item" v-for="item in computeOEEPreview(closeModal)" :key="item.label">
              <div class="op-val" :class="oeeClass(item.val)">{{item.val != null ? item.val+'%' : '—'}}</div>
              <div class="op-lbl">{{item.label}}</div>
            </div>
          </div>
        </div>

        <div class="err" v-if="closeModal.error">{{closeModal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save btn-close-sess" @click="doClose" :disabled="closeModal.saving || !closeModal.heure_fin">
            {{closeModal.saving ? 'Clôture…' : '✓ Clôturer et calculer OEE'}}
          </button>
          <button class="btn-cancel" @click="closeModal.show=false">Annuler</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../../supabase'

export default {
  setup() {
    var panels        = ref([])
    var shifts        = ref([])
    var equipes       = ref([])
    var arretFamilles = ref([])
    var loading       = ref(false)
    var clock         = ref('')
    var filterSite    = ref('Tous')
    var timers        = ref({})       // equipId → 'HH:MM:SS' durée prod
    var arretTimers   = ref({})       // arretId → 'HH:MM:SS' durée arrêt
    var clockInt = null
    var refreshInt = null
    var lotSearchTimeout = null

    // ── Modals ──
    var startModal   = reactive({ show:false, equip:null, lotSearch:'', lotSuggestions:[], lot:null, shift_id:null, equipe_id:null, date:'', heure_debut:'', cadenceObj:null, error:'', saving:false })
    var arretModal   = reactive({ show:false, panel:null, famille_id:null, sf_id:null, type_id:null, sousFamilles:[], types:[], selectedType:null, familleCouleur:'#EF4444', heure_debut:'', commentaire:'', error:'', saving:false })
    var requalModal  = reactive({ show:false, panel:null, famille_id:null, sf_id:null, type_id:null, sousFamilles:[], types:[] , saving:false })
    var comptageModal = reactive({ show:false, panel:null, heure:'', colis:null, rebuts:0, saving:false })
    var closeModal   = reactive({ show:false, panel:null, heure_fin:'', colis_produits:null, colis_rebuts:0, observation:'', error:'', saving:false })

    var filteredPanels = computed(function() {
      if (filterSite.value === 'Tous') return panels.value
      return panels.value.filter(function(p){ return p.equip.site === filterSite.value })
    })

    // ── Helpers ──
    var nowTime = function() {
      var n = new Date()
      return String(n.getHours()).padStart(2,'0') + ':' + String(n.getMinutes()).padStart(2,'0')
    }

    var toDateTime = function(dateStr, timeStr) {
      if (!dateStr || !timeStr) return null
      return new Date(dateStr + 'T' + timeStr)
    }

    var formatElapsed = function(ms) {
      if (ms < 0) ms = 0
      var s = Math.floor(ms / 1000)
      var h = Math.floor(s / 3600)
      var m = Math.floor((s % 3600) / 60)
      var sec = s % 60
      return String(h).padStart(2,'0') + ':' + String(m).padStart(2,'0') + ':' + String(sec).padStart(2,'0')
    }

    var panelClass = function(p) {
      if (!p.session) return 'panel-dispo'
      if (p.session.statut === 'En cours') return 'panel-encours'
      if (p.session.statut === 'Arrêt') return 'panel-arret'
      if (p.session.statut === 'Pause') return 'panel-pause'
      return ''
    }

    var panelColor = function(p) {
      if (!p.session) return '#9CA3AF'
      if (p.session.statut === 'En cours') return '#1D9E75'
      if (p.session.statut === 'Arrêt') return '#EF4444'
      if (p.session.statut === 'Pause') return '#F97316'
      return '#9CA3AF'
    }

    var oeeClass = function(v) {
      if (v == null) return ''
      if (v >= 85) return 'oee-green'
      if (v >= 60) return 'oee-orange'
      return 'oee-red'
    }

    var computeObjShift = function(m) {
      var cadObj = m.cadenceObj || (m.equip && m.equip.cadence_objectif_boite_min)
      if (!cadObj || !m.equip) return '—'
      var to = m.equip.temps_ouverture_shift_min || 480
      var pauses = m.equip.temps_pause_planifie_min || 0
      return Math.round(cadObj * (to - pauses))
    }

    var computeCadence = function(m) {
      var s = m.panel && m.panel.session
      if (!s || !m.colis || !s.heure_debut || !s.date) return '—'
      var start = toDateTime(s.date, s.heure_debut)
      if (!start) return '—'
      var now = new Date()
      var minElapsed = (now - start) / 60000
      if (minElapsed <= 0) return '—'
      return (m.colis / minElapsed).toFixed(1)
    }

    var computeCadenceVsObj = function(m) {
      var cadR = parseFloat(computeCadence(m))
      var cadO = m.panel && m.panel.session && m.panel.session.cadence_objectif_snapshot
      if (!cadR || !cadO) return '—'
      return Math.round((cadR / cadO) * 100)
    }

    var computeOEEPreview = function(m) {
      var s = m.panel && m.panel.session
      if (!s) return []
      var eq = m.panel.equip
      var start = toDateTime(s.date, s.heure_debut)
      var end   = toDateTime(s.date, m.heure_fin)
      if (!start || !end || end <= start) return []

      // Temps total session en minutes
      var totalMin = (end - start) / 60000
      // Arrêts non planifiés
      var arretImpro = (m.panel.arrets||[]).reduce(function(acc, a) {
        if (!a.est_planifie && !a.est_pause) return acc + (a.duree_minutes || 0)
        return acc
      }, 0)
      // Arrêts planifiés (maintenance, etc.)
      var arretPlan = (m.panel.arrets||[]).reduce(function(acc, a) {
        if (a.est_planifie && !a.est_pause) return acc + (a.duree_minutes || 0)
        return acc
      }, 0)
      // Pauses
      var pauses = (m.panel.arrets||[]).reduce(function(acc, a) {
        if (a.est_pause) return acc + (a.duree_minutes || 0)
        return acc
      }, 0)

      var to = totalMin - pauses           // Temps ouverture
      var tf = to - arretImpro             // Temps fonctionnement
      var colisGood = (m.colis_produits || 0) - (m.colis_rebuts || 0)
      var total     = m.colis_produits || 0
      var cadNom    = s.cadence_nominale_snapshot || eq.cadence_nominale_boite_min || 0
      var tn = cadNom > 0 && tf > 0 ? Math.min((total / cadNom), tf) : tf

      var D = to > 0 ? Math.round((tf / to) * 100) : null
      var P = tf > 0 && cadNom > 0 ? Math.round((tn / tf) * 100) : null
      var Q = total > 0 ? Math.round((colisGood / total) * 100) : null
      var TRS = (D != null && P != null && Q != null) ? Math.round((D * P * Q) / 10000) : null

      return [
        { label:'Disponibilité', val: D },
        { label:'Performance',   val: P },
        { label:'Qualité',       val: Q },
        { label:'TRS',           val: TRS }
      ]
    }

    // ── Chargement ──
    var loadAll = async function() {
      loading.value = true
      var [rEq, rSh, rEq2, rFam] = await Promise.all([
        supabase.from('equipements_conditionnement').select('*').eq('actif', true).order('ordre_affichage'),
        supabase.from('shifts').select('*').eq('actif', true).order('heure_debut'),
        supabase.from('equipes').select('*').eq('actif', true).order('nom'),
        supabase.from('arret_familles').select('*').eq('actif', true).order('ordre')
      ])
      if (rSh.data)   shifts.value   = rSh.data
      if (rEq2.data)  equipes.value  = rEq2.data
      if (rFam.data)  arretFamilles.value = rFam.data

      var equipList = rEq.data || []

      // Pour chaque équipement : session active + lot + arrêts
      var newPanels = []
      for (var i = 0; i < equipList.length; i++) {
        var eq = equipList[i]
        var rSess = await supabase.from('production_sessions')
          .select('*')
          .eq('equipement_id', eq.id)
          .neq('statut', 'Clôturé')
          .is('deleted_at', null)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle()

        var session = rSess.data || null
        var lotNum = '—', lotProd = '—', lotId = null

        if (session) {
          var rLot = await supabase.from('lots').select('numero_lot, product_id').eq('id', session.lot_id).maybeSingle()
          if (rLot.data) {
            lotId  = session.lot_id
            lotNum = rLot.data.numero_lot
            var rProd = await supabase.from('products').select('code_article, description').eq('id', rLot.data.product_id).maybeSingle()
            if (rProd.data) lotProd = rProd.data.code_article + ' — ' + rProd.data.description
          }
        }

        // Arrêts de la session
        var arrets = []
        var activeArret = null
        if (session) {
          var rArr = await supabase.from('production_arrets')
            .select('*')
            .eq('session_id', session.id)
            .order('created_at', { ascending: false })
          if (rArr.data) {
            arrets = rArr.data
            activeArret = arrets.find(function(a){ return a.is_running }) || null
          }
        }

        // Shift & équipe info
        var shiftNom = '', shiftCouleur = '#3B82F6', equipeNom = '', equipeCouleur = '#8B5CF6'
        if (session && session.shift_id) {
          var sh = shifts.value.find(function(s){ return s.id === session.shift_id })
          if (sh) { shiftNom = sh.nom; shiftCouleur = sh.couleur }
        }
        if (session && session.equipe_id) {
          var eq2 = equipes.value.find(function(e){ return e.id === session.equipe_id })
          if (eq2) { equipeNom = eq2.nom; equipeCouleur = eq2.couleur }
        }

        var rendPct = 0
        if (session && session.objectif_boites && session.colis_produits) {
          rendPct = Math.round((session.colis_produits / session.objectif_boites) * 100)
        }

        newPanels.push({
          equip: eq, session: session, activeArret: activeArret,
          arrets: arrets, lotNum: lotNum, lotProd: lotProd,
          shiftNom: shiftNom, shiftCouleur: shiftCouleur,
          equipeNom: equipeNom, equipeCouleur: equipeCouleur,
          rendPct: rendPct
        })
      }
      panels.value = newPanels
      loading.value = false
    }

    // ── Ticker ──
    var tick = function() {
      var n = new Date()
      var p2 = function(v){ return String(v).padStart(2,'0') }
      clock.value = p2(n.getHours())+':'+p2(n.getMinutes())+':'+p2(n.getSeconds())

      // Mettre à jour timers
      var newT = {}, newAT = {}
      for (var i = 0; i < panels.value.length; i++) {
        var p = panels.value[i]
        if (p.session && p.session.statut === 'En cours') {
          var start = toDateTime(p.session.date, p.session.heure_debut)
          if (start) newT[p.equip.id] = formatElapsed(n - start)
        }
        if (p.activeArret && p.activeArret.is_running) {
          var aStart = toDateTime(p.session ? p.session.date : new Date().toISOString().slice(0,10), p.activeArret.heure_debut)
          if (aStart) newAT[p.activeArret.id] = formatElapsed(n - aStart)
        }
      }
      timers.value     = newT
      arretTimers.value = newAT
    }

    // ── Démarrer session ──
    var openStartModal = function(equip) {
      startModal.equip          = equip
      startModal.lotSearch      = ''
      startModal.lotSuggestions = []
      startModal.lot            = null
      startModal.shift_id       = null
      startModal.equipe_id      = null
      startModal.date           = new Date().toISOString().slice(0,10)
      startModal.heure_debut    = nowTime()
      startModal.cadenceObj     = null
      startModal.error          = ''
      startModal.saving         = false
      startModal.show           = true
    }

    var searchLots = function() {
      clearTimeout(lotSearchTimeout)
      var q = startModal.lotSearch
      if (!q || q.length < 2) { startModal.lotSuggestions = []; return }
      lotSearchTimeout = setTimeout(async function() {
        var r = await supabase.from('lots')
          .select('id, numero_lot, product_id, products(code_article, description)')
          .ilike('numero_lot', '%' + q + '%')
          .limit(8)
        startModal.lotSuggestions = (r.data || []).map(function(l) {
          return {
            id: l.id, numero_lot: l.numero_lot,
            code_article: l.products ? l.products.code_article : '',
            description:  l.products ? l.products.description  : '',
            product_id:   l.product_id
          }
        })
      }, 200)
    }

    var selectLot = async function(l) {
      startModal.lot            = l
      startModal.lotSearch      = l.numero_lot
      startModal.lotSuggestions = []
      // Chercher objectif spécifique pour ce produit × shift
      if (startModal.equip) {
        var r = await supabase.from('objectifs_production')
          .select('cadence_objectif_boite_min')
          .eq('equipement_id', startModal.equip.id)
          .eq('product_id', l.product_id)
          .eq('actif', true)
          .limit(1)
          .maybeSingle()
        startModal.cadenceObj = r.data ? r.data.cadence_objectif_boite_min : null
      }
    }

    var doStart = async function() {
      if (!startModal.lot) { startModal.error = 'Sélectionner un lot.'; return }
      startModal.saving = true
      var eq = startModal.equip
      var cadObj = startModal.cadenceObj || eq.cadence_objectif_boite_min
      var to     = eq.temps_ouverture_shift_min || 480
      var pauses = eq.temps_pause_planifie_min  || 0
      var objBoites = cadObj ? Math.round(cadObj * (to - pauses)) : null

      var r = await supabase.from('production_sessions').insert({
        lot_id: startModal.lot.id,
        equipement_id: eq.id,
        shift_id:  startModal.shift_id  || null,
        equipe_id: startModal.equipe_id || null,
        date: startModal.date,
        heure_debut: startModal.heure_debut + ':00',
        statut: 'En cours',
        cadence_nominale_snapshot:  eq.cadence_nominale_boite_min  || null,
        cadence_objectif_snapshot:  cadObj                         || null,
        objectif_boites:            objBoites,
        colis_produits: 0, colis_rebuts: 0
      })
      if (r.error) { startModal.error = r.error.message; startModal.saving = false; return }
      startModal.show = false; startModal.saving = false
      await loadAll()
    }

    // ── Déclarer arrêt ──
    var openArretModal = function(p) {
      arretModal.panel       = p
      arretModal.famille_id  = null
      arretModal.sf_id       = null
      arretModal.type_id     = null
      arretModal.sousFamilles = []
      arretModal.types       = []
      arretModal.selectedType = null
      arretModal.heure_debut = nowTime()
      arretModal.commentaire = ''
      arretModal.error       = ''
      arretModal.saving      = false
      arretModal.show        = true
    }

    var onFamilleChange = async function() {
      arretModal.sf_id       = null
      arretModal.type_id     = null
      arretModal.sousFamilles = []
      arretModal.types       = []
      arretModal.selectedType = null
      if (!arretModal.famille_id) return
      var f = arretFamilles.value.find(function(x){ return x.id === arretModal.famille_id })
      arretModal.familleCouleur = f ? f.couleur : '#EF4444'
      var r = await supabase.from('arret_sous_familles').select('*').eq('famille_id', arretModal.famille_id).eq('actif', true).order('ordre')
      arretModal.sousFamilles = r.data || []
    }

    var onSFChange = async function() {
      arretModal.type_id  = null
      arretModal.types    = []
      arretModal.selectedType = null
      if (!arretModal.sf_id) return
      var r = await supabase.from('arret_types').select('*').eq('sous_famille_id', arretModal.sf_id).eq('actif', true).order('code')
      arretModal.types = r.data || []
    }

    var onTypeChange = function() {
      arretModal.selectedType = arretModal.types.find(function(t){ return t.id === arretModal.type_id }) || null
    }

    var doArret = async function() {
      if (!arretModal.type_id) { arretModal.error = 'Sélectionner un code arrêt.'; return }
      arretModal.saving = true
      var t = arretModal.selectedType
      var f = arretFamilles.value.find(function(x){ return x.id === arretModal.famille_id })
      var sf = arretModal.sousFamilles.find(function(x){ return x.id === arretModal.sf_id })

      // 1. Créer l'arrêt
      var r = await supabase.from('production_arrets').insert({
        session_id:       arretModal.panel.session.id,
        arret_type_id:    t.id,
        famille_nom:      f ? f.nom : '',
        sous_famille_nom: sf ? sf.nom : '',
        arret_code:       t.code,
        arret_nom:        t.nom,
        couleur:          t.couleur || (f ? f.couleur : '#EF4444'),
        est_planifie:     t.est_planifie,
        est_pause:        t.est_pause,
        heure_debut:      arretModal.heure_debut + ':00',
        is_running:       true,
        commentaire:      arretModal.commentaire || null
      })
      if (r.error) { arretModal.error = r.error.message; arretModal.saving = false; return }

      // 2. Mettre à jour statut session
      var newStatut = t.est_pause ? 'Pause' : 'Arrêt'
      await supabase.from('production_sessions').update({ statut: newStatut, updated_at: new Date().toISOString() }).eq('id', arretModal.panel.session.id)

      arretModal.show = false; arretModal.saving = false
      await loadAll()
    }

    // ── Clôturer arrêt (reprendre) ──
    var clotureArret = async function(p) {
      if (!p.activeArret) return
      var now = nowTime()
      var start = toDateTime(p.session.date, p.activeArret.heure_debut)
      var dur = start ? Math.round((new Date() - start) / 60000) : null
      await supabase.from('production_arrets').update({
        heure_fin: now + ':00', duree_minutes: dur, is_running: false, updated_at: new Date().toISOString()
      }).eq('id', p.activeArret.id)
      await supabase.from('production_sessions').update({ statut: 'En cours', updated_at: new Date().toISOString() }).eq('id', p.session.id)
      await loadAll()
    }

    // ── Requalifier arrêt ──
    var openRequalifModal = function(p) {
      requalModal.panel        = p
      requalModal.famille_id   = null
      requalModal.sf_id        = null
      requalModal.type_id      = null
      requalModal.sousFamilles = []
      requalModal.types        = []
      requalModal.saving       = false
      requalModal.show         = true
    }

    var onRequalFamilleChange = async function() {
      requalModal.sf_id = null; requalModal.type_id = null; requalModal.types = []
      if (!requalModal.famille_id) return
      var r = await supabase.from('arret_sous_familles').select('*').eq('famille_id', requalModal.famille_id).eq('actif', true).order('ordre')
      requalModal.sousFamilles = r.data || []
    }

    var onRequalSFChange = async function() {
      requalModal.type_id = null
      if (!requalModal.sf_id) return
      var r = await supabase.from('arret_types').select('*').eq('sous_famille_id', requalModal.sf_id).eq('actif', true).order('code')
      requalModal.types = r.data || []
    }

    var doRequalif = async function() {
      if (!requalModal.type_id || !requalModal.panel.activeArret) return
      requalModal.saving = true
      var t = requalModal.types.find(function(x){ return x.id === requalModal.type_id })
      var f = arretFamilles.value.find(function(x){ return x.id === requalModal.famille_id })
      var sf = requalModal.sousFamilles.find(function(x){ return x.id === requalModal.sf_id })
      await supabase.from('production_arrets').update({
        arret_type_id: t.id, famille_nom: f ? f.nom : '', sous_famille_nom: sf ? sf.nom : '',
        arret_code: t.code, arret_nom: t.nom, couleur: t.couleur || (f ? f.couleur : '#EF4444'),
        est_planifie: t.est_planifie, est_pause: t.est_pause, updated_at: new Date().toISOString()
      }).eq('id', requalModal.panel.activeArret.id)
      requalModal.show = false; requalModal.saving = false
      await loadAll()
    }

    // ── Comptage ──
    var openComptageModal = function(p) {
      comptageModal.panel  = p
      comptageModal.heure  = nowTime()
      comptageModal.colis  = p.session ? p.session.colis_produits : null
      comptageModal.rebuts = p.session ? p.session.colis_rebuts : 0
      comptageModal.saving = false
      comptageModal.show   = true
    }

    var doComptage = async function() {
      if (!comptageModal.colis) return
      comptageModal.saving = true
      var s = comptageModal.panel.session
      var prev = s.colis_produits || 0
      var delta = comptageModal.colis - prev
      var start = toDateTime(s.date, s.heure_debut)
      var minEl = start ? (new Date() - start) / 60000 : null
      var cadInst = (minEl && minEl > 0) ? parseFloat((comptageModal.colis / minEl).toFixed(2)) : null

      await supabase.from('production_comptages').insert({
        session_id: s.id, heure: comptageModal.heure + ':00',
        colis_cumules: comptageModal.colis, rebuts_cumules: comptageModal.rebuts || 0,
        cadence_instantanee: cadInst
      })
      await supabase.from('production_sessions').update({
        colis_produits: comptageModal.colis, colis_rebuts: comptageModal.rebuts || 0,
        cadence_reelle_boite_min: cadInst, updated_at: new Date().toISOString()
      }).eq('id', s.id)
      comptageModal.show = false; comptageModal.saving = false
      await loadAll()
    }

    // ── Clôturer session ──
    var openCloseModal = function(p) {
      closeModal.panel          = p
      closeModal.heure_fin      = nowTime()
      closeModal.colis_produits = p.session ? p.session.colis_produits : null
      closeModal.colis_rebuts   = p.session ? p.session.colis_rebuts : 0
      closeModal.observation    = ''
      closeModal.error          = ''
      closeModal.saving         = false
      closeModal.show           = true
    }

    var doClose = async function() {
      if (!closeModal.heure_fin) { closeModal.error = 'Heure de fin requise.'; return }
      closeModal.saving = true
      var s    = closeModal.panel.session
      var eq   = closeModal.panel.equip
      var arrs = closeModal.panel.arrets || []

      var start = toDateTime(s.date, s.heure_debut)
      var end   = toDateTime(s.date, closeModal.heure_fin)
      var totalMin = (start && end) ? Math.round((end - start) / 60000) : 0

      // Calcul temps
      var arretImpro = arrs.reduce(function(a,x){ return !x.est_planifie && !x.est_pause ? a + (x.duree_minutes||0) : a }, 0)
      var arretPlan  = arrs.reduce(function(a,x){ return x.est_planifie && !x.est_pause ? a + (x.duree_minutes||0) : a }, 0)
      var pauses     = arrs.reduce(function(a,x){ return x.est_pause ? a + (x.duree_minutes||0) : a }, 0)
      var to = totalMin - pauses
      var tf = to - arretImpro
      var tp = Math.max(0, tf - arretPlan)

      // OEE
      var total    = closeModal.colis_produits || 0
      var good     = total - (closeModal.colis_rebuts || 0)
      var cadNom   = s.cadence_nominale_snapshot || eq.cadence_nominale_boite_min || 0
      var cadObj   = s.cadence_objectif_snapshot  || eq.cadence_objectif_boite_min || 0
      var cadReelle = (totalMin > 0 && total > 0) ? parseFloat((total / totalMin).toFixed(2)) : null
      var D = to > 0 ? Math.round((tf / to) * 100) : null
      var P = (tf > 0 && cadNom > 0) ? Math.min(100, Math.round((cadReelle || 0) / cadNom * 100)) : null
      var Q = total > 0 ? Math.round((good / total) * 100) : null
      var TRS = (D != null && P != null && Q != null) ? Math.round((D/100) * (P/100) * (Q/100) * 100) : null
      var rendPct = (s.objectif_boites && total) ? Math.round((total / s.objectif_boites) * 100) : null

      // Clôturer arrêt actif si présent
      if (closeModal.panel.activeArret) {
        var now = nowTime()
        var aStart = toDateTime(s.date, closeModal.panel.activeArret.heure_debut)
        var aDur = aStart ? Math.round((end - aStart) / 60000) : null
        await supabase.from('production_arrets').update({
          heure_fin: now+':00', duree_minutes: aDur, is_running: false, updated_at: new Date().toISOString()
        }).eq('id', closeModal.panel.activeArret.id)
      }

      var r = await supabase.from('production_sessions').update({
        heure_fin:               closeModal.heure_fin + ':00',
        statut:                  'Clôturé',
        colis_produits:          total,
        colis_rebuts:            closeModal.colis_rebuts || 0,
        cadence_reelle_boite_min: cadReelle,
        rendement_pct:           rendPct,
        temps_ouverture_min:     to,
        temps_fonctionnement_min: tf,
        temps_arret_planifie_min: arretPlan,
        temps_arret_impro_min:   arretImpro,
        temps_pause_min:         pauses,
        disponibilite:           D,
        performance:             P,
        qualite:                 Q,
        trs:                     TRS,
        observation:             closeModal.observation || null,
        updated_at:              new Date().toISOString()
      }).eq('id', s.id)

      if (r.error) { closeModal.error = r.error.message; closeModal.saving = false; return }
      closeModal.show = false; closeModal.saving = false
      await loadAll()
    }

    onMounted(async function() {
      await loadAll()
      clockInt   = setInterval(tick, 1000)
      refreshInt = setInterval(loadAll, 60000)
      tick()
    })

    onUnmounted(function() {
      clearInterval(clockInt)
      clearInterval(refreshInt)
    })

    return {
      panels, shifts, equipes, arretFamilles, loading, clock, filterSite,
      timers, arretTimers, filteredPanels,
      startModal, arretModal, requalModal, comptageModal, closeModal,
      panelClass, panelColor, oeeClass,
      computeObjShift, computeCadence, computeCadenceVsObj, computeOEEPreview,
      loadAll,
      openStartModal, searchLots, selectLot, doStart,
      openArretModal, onFamilleChange, onSFChange, onTypeChange, doArret,
      clotureArret, openRequalifModal, onRequalFamilleChange, onRequalSFChange, doRequalif,
      openComptageModal, doComptage,
      openCloseModal, doClose
    }
  }
}
</script>

<style scoped>
.trs-live{min-height:100%}
.ph{display:flex;align-items:center;justify-content:space-between;padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:16px;flex-wrap:wrap;gap:8px}
.ph-left{display:flex;align-items:baseline;gap:12px}
.pt{font-size:11px;font-weight:500;letter-spacing:1.5px}
.pt-clock{font-family:'SF Mono',monospace;font-size:14px;color:#185FA5;font-weight:600}
.ph-right{display:flex;align-items:center;gap:8px}
.site-tabs{display:flex;gap:3px}
.site-tab{padding:4px 10px;font-size:11px;border:1px solid #ddd;background:#fff;border-radius:2px;cursor:pointer}
.site-tab.active{background:#0a0a0a;color:#fff;border-color:#0a0a0a}
.btn-refresh{padding:4px 10px;font-size:16px;border:1px solid #ddd;background:#fff;border-radius:2px;cursor:pointer;transition:.3s}
.btn-refresh.spinning{animation:spin .7s linear infinite}
@keyframes spin{from{transform:rotate(0)}to{transform:rotate(360deg)}}
.loading{padding:24px;text-align:center;color:#999}

/* Grille panels */
.panels-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:14px}
.panel{border:1px solid #e0e0e0;border-radius:6px;border-top:3px solid #e0e0e0;overflow:hidden;background:#fff;transition:.2s}
.panel-encours{border-top-color:#1D9E75;box-shadow:0 2px 12px rgba(29,158,117,.1)}
.panel-arret{border-top-color:#EF4444;box-shadow:0 2px 12px rgba(239,68,68,.12)}
.panel-pause{border-top-color:#F97316;box-shadow:0 2px 12px rgba(249,115,22,.1)}
.panel-dispo{border-top-color:#9CA3AF}

.panel-hd{display:flex;align-items:flex-start;justify-content:space-between;padding:10px 12px 6px}
.panel-equip{font-size:13px;font-weight:600;line-height:1.2}
.panel-site{font-size:9px;color:#aaa;text-transform:uppercase;letter-spacing:.5px;margin-top:2px}
.panel-status-badge{font-size:10px;font-weight:600;padding:2px 8px;border-radius:8px;letter-spacing:.3px;white-space:nowrap}
.panel-shift{display:flex;gap:4px;padding:0 12px 6px;flex-wrap:wrap}
.shift-chip{font-size:10px;font-weight:600;padding:2px 8px;border-radius:8px;border:1px solid}
.equipe-chip{font-size:10px;font-weight:600;padding:2px 8px;border-radius:8px}

.panel-lot{padding:6px 12px 4px}
.lot-num{font-family:'SF Mono',monospace;font-size:13px;font-weight:600;color:#0a0a0a}
.lot-prod{font-size:11px;color:#666;margin-top:1px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.panel-empty{padding:10px 12px;font-size:12px;color:#bbb;font-style:italic}

.panel-timer{padding:10px 12px 6px;border-top:1px solid #f5f5f5;border-bottom:1px solid #f5f5f5;margin:4px 0}
.timer-label{font-size:9px;font-weight:600;letter-spacing:1px;text-transform:uppercase;color:#aaa;margin-bottom:2px}
.timer-val{font-family:'SF Mono','Fira Code',monospace;font-size:28px;font-weight:700;letter-spacing:2px;line-height:1}
.arret-info{display:flex;align-items:center;gap:6px;margin-top:4px}
.arret-code-chip{font-family:'SF Mono',monospace;font-size:10px;font-weight:600;padding:2px 7px;border-radius:3px;border:1px solid}
.arret-nom{font-size:11px;color:#555;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}

.panel-metrics{display:grid;grid-template-columns:repeat(4,1fr);padding:8px 12px;gap:4px}
.metric{text-align:center}
.metric-val{font-family:'SF Mono',monospace;font-size:16px;font-weight:600;color:#0a0a0a}
.metric-val.ok{color:#1D9E75}
.metric-val.warn{color:#F97316}
.metric-val.bad{color:#EF4444}
.cadence-val{color:#185FA5}
.metric-lbl{font-size:9px;color:#aaa;text-transform:uppercase;letter-spacing:.3px;margin-top:1px}

.panel-rend{display:flex;align-items:center;gap:8px;padding:0 12px 8px}
.rend-bar{flex:1;height:6px;background:#f0f0f0;border-radius:3px;overflow:hidden}
.rend-fill{height:100%;border-radius:3px;transition:.5s}
.rend-pct{font-size:11px;font-weight:600;min-width:36px;text-align:right}
.rend-pct.ok{color:#1D9E75}
.rend-pct.warn{color:#F97316}
.rend-pct.bad{color:#EF4444}

.panel-oee{display:flex;align-items:center;padding:6px 12px;border-top:1px solid #f5f5f5;gap:0}
.oee-item{flex:1;text-align:center}
.oee-item.trs-item{flex:1.2}
.oee-sep{width:1px;height:28px;background:#f0f0f0}
.oee-val{font-size:14px;font-weight:700;font-family:'SF Mono',monospace}
.oee-val.oee-green{color:#1D9E75}
.oee-val.oee-orange{color:#F97316}
.oee-val.oee-red{color:#EF4444}
.trs-big{font-size:18px}
.oee-lbl{font-size:8px;text-transform:uppercase;letter-spacing:.5px;color:#aaa;margin-top:1px}

.panel-actions{display:flex;gap:4px;padding:8px 12px;flex-wrap:wrap}
.act-btn{flex:1;padding:7px 8px;border:none;border-radius:3px;font-size:11px;font-weight:600;cursor:pointer;white-space:nowrap;letter-spacing:.2px}
.act-start{background:#0a0a0a;color:#fff}
.act-start:hover{background:#333}
.act-stop{background:#FEF2F2;color:#DC2626;border:1px solid #fca5a5}
.act-stop:hover{background:#fee2e2}
.act-resume{background:#F0FDF4;color:#15803D;border:1px solid #86efac}
.act-resume:hover{background:#dcfce7}
.act-count{background:#EBF5FF;color:#185FA5;border:1px solid #bfdbfe}
.act-count:hover{background:#dbeafe}
.act-close{background:#F5F5F5;color:#555;border:1px solid #e0e0e0}
.act-close:hover{background:#eee}
.act-requalif{background:#FFF7ED;color:#C2410C;border:1px solid #fed7aa}
.act-requalif:hover{background:#ffedd5}

.panel-arrets{padding:6px 12px 10px;border-top:1px solid #f5f5f5}
.arrets-title{font-size:9px;text-transform:uppercase;letter-spacing:.5px;color:#aaa;margin-bottom:4px}
.arret-row{display:flex;align-items:center;gap:5px;font-size:11px;padding:2px 0}
.arret-row.running{background:#fff8f8}
.arret-dot{width:7px;height:7px;border-radius:50%;flex-shrink:0}
.arret-code-sm{font-family:'SF Mono',monospace;font-size:10px;color:#666;min-width:70px}
.arret-nom-sm{flex:1;color:#555;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.arret-dur{font-size:10px;color:#aaa;white-space:nowrap;font-family:'SF Mono',monospace}

/* Modals */
.overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.45);display:flex;align-items:center;justify-content:center;z-index:200}
.modal{background:#fff;padding:24px;width:520px;max-width:96vw;border-radius:8px;max-height:92vh;overflow-y:auto}
.modal-sm{width:380px}
.modal-hd{font-size:14px;font-weight:600;margin-bottom:16px}
.modal-ctx{font-size:11px;color:#666;background:#f5f5f5;padding:6px 10px;border-radius:3px;margin-bottom:12px}
.lbl{display:block;font-size:11px;color:#666;text-transform:uppercase;letter-spacing:.3px;margin-bottom:4px;margin-top:10px}
.inp{width:100%;padding:8px 10px;border:1px solid #ddd;font-size:13px;outline:none;box-sizing:border-box;font-family:inherit;border-radius:2px}
.inp:focus{border-color:#185FA5}
.inp:disabled{opacity:.4;cursor:not-allowed}
.form-row{display:flex;gap:12px}
.form-field{flex:1}
.auto-wrap{position:relative}
.auto-list{position:absolute;top:100%;left:0;right:0;background:#fff;border:1px solid #ddd;border-radius:3px;box-shadow:0 4px 12px rgba(0,0,0,.08);z-index:10;max-height:200px;overflow-y:auto}
.auto-item{display:flex;align-items:center;gap:8px;padding:7px 10px;cursor:pointer;font-size:12px}
.auto-item:hover{background:#f5f5f5}
.auto-code{font-family:'SF Mono',monospace;font-size:12px;font-weight:600;color:#185FA5;min-width:60px}
.auto-desc{color:#666;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.selected-lot{font-size:12px;color:#1D9E75;padding:5px 8px;background:#f0fdf4;border-radius:3px;margin-top:4px}
.cadence-preview{margin-top:12px;padding:10px 14px;background:#f8f8f8;border-radius:4px;border:1px solid #e8e8e8}
.cp-row{display:flex;justify-content:space-between;padding:2px 0;font-size:12px}
.cp-lbl{color:#666}
.cp-val{font-family:'SF Mono',monospace;font-weight:500}
.cp-val.obj{color:#185FA5;font-weight:600}
.cascade-selects{display:flex;align-items:flex-end;gap:6px}
.cs-step{flex:1}
.cs-arrow{color:#ccc;font-size:16px;padding-bottom:10px;flex-shrink:0}
.type-preview{display:flex;align-items:center;gap:8px;margin-top:8px;padding:8px 12px;background:#fafafa;border-radius:4px;flex-wrap:wrap}
.type-prev-nom{font-size:12px;font-weight:500;flex:1}
.tag{font-size:10px;padding:1px 7px;border-radius:8px;font-weight:500;white-space:nowrap}
.tag-plan{background:#EFF6FF;color:#1D4ED8}
.tag-pause{background:#F0FDF4;color:#15803D}
.tag-dur{background:#FFF7ED;color:#C2410C;font-family:'SF Mono',monospace}
.cadence-calc{margin-top:10px;padding:10px;background:#f0f7ff;border-radius:3px}
.cc-row{display:flex;justify-content:space-between;font-size:12px;padding:2px 0}
.cc-lbl{color:#666}
.cc-val{font-family:'SF Mono',monospace;font-weight:600}
.cc-val.ok{color:#1D9E75}
.cc-val.bad{color:#EF4444}
.oee-preview{margin-top:12px;padding:12px 14px;background:#f0fdf4;border:1px solid #bbf7d0;border-radius:4px}
.op-title{font-size:10px;text-transform:uppercase;letter-spacing:.5px;color:#166534;margin-bottom:8px;font-weight:600}
.op-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;text-align:center}
.op-val{font-size:18px;font-weight:700;font-family:'SF Mono',monospace}
.op-lbl{font-size:9px;color:#555;text-transform:uppercase;margin-top:2px}
.err{color:#E24B4A;font-size:12px;margin-top:8px;padding:6px 10px;background:#FEF2F2;border-radius:3px}
.modal-acts{display:flex;gap:8px;margin-top:14px}
.btn-save{flex:1;padding:10px;background:#185FA5;color:#fff;border:none;font-size:13px;font-weight:500;cursor:pointer;border-radius:2px}
.btn-save:hover:not(:disabled){background:#0C447C}
.btn-save:disabled{opacity:.5;cursor:not-allowed}
.btn-go{background:#1D9E75}
.btn-go:hover:not(:disabled){background:#158a65}
.btn-stop{background:#EF4444}
.btn-stop:hover:not(:disabled){background:#c53030}
.btn-close-sess{background:#0a0a0a}
.btn-close-sess:hover:not(:disabled){background:#333}
.btn-cancel{flex:1;padding:10px;background:#f5f5f5;color:#666;border:none;font-size:13px;cursor:pointer;border-radius:2px}
.btn-cancel:hover{background:#eee}

@media(max-width:768px){
  .panels-grid{grid-template-columns:1fr}
  .cascade-selects{flex-direction:column;gap:8px}
  .cs-arrow{display:none}
  /* Modal */
  .trs-modal{width:min(96vw,480px);padding:16px}
  .form-row{flex-direction:column}
  .btn-save,.btn-cancel,.btn-go,.btn-stop,.btn-close-sess{min-height:44px;font-size:14px}
  .modal-acts{flex-wrap:wrap}
  .btn-save,.btn-cancel{flex:1}
  /* Panneau panel */
  .panel{font-size:12px}
  .panel-hd{flex-wrap:wrap}
  .oee-grid{grid-template-columns:1fr 1fr}
  .action-btns{flex-wrap:wrap}
  .action-btns .btn-sm{flex:1;min-height:40px}
  /* Header barre */
  .page-header{flex-wrap:wrap;gap:8px}
}
@media(max-width:480px){
  .panels-grid{grid-template-columns:1fr}
  .kpi-grid{grid-template-columns:1fr 1fr}
}
</style>
