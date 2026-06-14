<template>
  <div class="shifts-page">

    <!-- ── En-tête ── -->
    <div class="fa-header">
      <div>
        <div class="fa-title"><NavIcon name="clock" :size="18" /> Shifts & Équipes</div>
        <div class="fa-sub">Gestion des shifts horaires et équipes de production</div>
      </div>
    </div>

    <div class="two-cols">

      <!-- ══ SHIFTS ══ -->
      <div class="card">
        <div class="card-hd">
          <span class="card-title">Postes horaires</span>
          <button class="btn-add" @click="openShiftModal(null)">+ Ajouter</button>
        </div>

        <div v-if="loadingS" class="loading">Chargement…</div>
        <div v-for="s in shifts" :key="s.id" class="shift-row">
          <div class="shift-color" :style="{background:s.couleur}"></div>
          <div class="shift-body">
            <div class="shift-nom">{{s.nom}}</div>
            <div class="shift-hours">
              <span class="mono">{{s.heure_debut}}</span>
              <span class="arrow">→</span>
              <span class="mono">{{s.heure_fin}}</span>
              <span class="dur-badge">{{s.duree_min}} min</span>
            </div>
          </div>
          <span class="stat-badge" :class="s.actif?'actif':'inactif'">{{s.actif?'Actif':'Inactif'}}</span>
          <div class="row-acts">
            <button class="ia" @click="openShiftModal(s)"><NavIcon name="pencil" :size="13" /></button>
            <button class="ia del" @click="deleteShift(s)"><NavIcon name="trash" :size="13" /></button>
          </div>
        </div>
        <div v-if="!loadingS && shifts.length===0" class="empty">Aucun shift</div>
      </div>

      <!-- ══ ÉQUIPES ══ -->
      <div class="card">
        <div class="card-hd">
          <span class="card-title">Équipes</span>
          <button class="btn-add" @click="openEquipeModal(null)">+ Ajouter</button>
        </div>

        <div v-if="loadingE" class="loading">Chargement…</div>
        <div v-for="e in equipes" :key="e.id" class="equipe-row">
          <div class="eq-color" :style="{background:e.couleur}"></div>
          <div class="equipe-nom">{{e.nom}}</div>
          <span class="stat-badge" :class="e.actif?'actif':'inactif'">{{e.actif?'Active':'Inactive'}}</span>
          <div class="row-acts">
            <button class="ia" @click="openEquipeModal(e)"><NavIcon name="pencil" :size="13" /></button>
            <button class="ia del" @click="deleteEquipe(e)"><NavIcon name="trash" :size="13" /></button>
          </div>
        </div>
        <div v-if="!loadingE && equipes.length===0" class="empty">Aucune équipe</div>
      </div>
    </div>

    <!-- ══ PLANNING SHIFTS ══ -->
    <div class="card" style="margin-top:16px">
      <div class="card-hd">
        <span class="card-title">Planning équipes</span>
        <div class="cal-view-tabs">
          <button class="cv-tab" :class="{active:calView==='jour'}" @click="calView='jour'">Jour</button>
          <button class="cv-tab" :class="{active:calView==='semaine'}" @click="calView='semaine'">Semaine</button>
          <button class="cv-tab" :class="{active:calView==='mois'}" @click="calView='mois'">Mois</button>
        </div>
      </div>

      <!-- ── Navigation contextuelle ── -->
      <div class="cal-nav">
        <button class="wn-btn" @click="calPrev"><NavIcon name="arrow-left" :size="14" /></button>
        <button class="wn-btn today" @click="calToday">Aujourd'hui</button>
        <button class="wn-btn" @click="calNext"><NavIcon name="arrow-right" :size="14" /></button>
        <span class="cal-period">{{calPeriodLabel}}</span>
      </div>

      <div v-if="loadingP" class="loading">Chargement…</div>

      <!-- ── VUE JOUR ── -->
      <div v-else-if="calView==='jour'" class="planning-grid" :style="{'--cols': equipements.length + 1}">
        <div class="pg-head pg-corner"></div>
        <div v-for="eq in equipements" :key="eq.id" class="pg-head pg-equip">
          <div class="pg-eq-nom">{{eq.nom_equipement}}</div>
          <div class="pg-eq-site">{{eq.site}}</div>
        </div>
        <template v-for="sh in shifts" :key="sh.id">
          <div class="pg-label" :class="{today:true}">
            <div class="sh-chip" :style="{background:sh.couleur+'22',color:sh.couleur,borderColor:sh.couleur+'44'}">
              {{sh.nom}} <span class="sh-time">{{sh.heure_debut.slice(0,5)}}</span>
            </div>
          </div>
          <div v-for="eq in equipements" :key="eq.id" class="pg-cell" :class="{today:true}">
            <div v-if="getPlanCell(currentDayIso, sh.id, eq.id)" class="plan-chip"
              :style="{background:getEquipeColor(getPlanCell(currentDayIso,sh.id,eq.id).equipe_id)+'22',borderColor:getEquipeColor(getPlanCell(currentDayIso,sh.id,eq.id).equipe_id)+'55'}">
              <span class="pc-eq" :style="{color:getEquipeColor(getPlanCell(currentDayIso,sh.id,eq.id).equipe_id)}">
                {{getEquipeNom(getPlanCell(currentDayIso,sh.id,eq.id).equipe_id)}}
              </span>
              <button class="pc-del" @click="deletePlan(getPlanCell(currentDayIso,sh.id,eq.id).id)"><NavIcon name="x" :size="12" /></button>
            </div>
            <button v-else class="pg-assign" @click="openAssignModal(currentDayIso, sh, eq)" title="Affecter une équipe">+</button>
          </div>
        </template>
      </div>

      <!-- ── VUE SEMAINE ── -->
      <div v-else-if="calView==='semaine'" class="planning-grid" :style="{'--cols': equipements.length + 1}">
        <div class="pg-head pg-corner"></div>
        <div v-for="eq in equipements" :key="eq.id" class="pg-head pg-equip">
          <div class="pg-eq-nom">{{eq.nom_equipement}}</div>
          <div class="pg-eq-site">{{eq.site}}</div>
        </div>
        <template v-for="day in weekDays" :key="day.iso">
          <template v-for="sh in shifts" :key="sh.id">
            <div class="pg-label" :class="{today:day.isToday}">
              <span class="day-label" v-if="sh === shifts[0]">{{day.label}}</span>
              <div class="sh-chip" :style="{background:sh.couleur+'22',color:sh.couleur,borderColor:sh.couleur+'44'}">
                {{sh.nom}} <span class="sh-time">{{sh.heure_debut.slice(0,5)}}</span>
              </div>
            </div>
            <div v-for="eq in equipements" :key="eq.id" class="pg-cell" :class="{today:day.isToday}">
              <div v-if="getPlanCell(day.iso, sh.id, eq.id)" class="plan-chip"
                :style="{background:getEquipeColor(getPlanCell(day.iso, sh.id, eq.id).equipe_id)+'22', borderColor:getEquipeColor(getPlanCell(day.iso, sh.id, eq.id).equipe_id)+'55'}">
                <span class="pc-eq" :style="{color:getEquipeColor(getPlanCell(day.iso, sh.id, eq.id).equipe_id)}">
                  {{getEquipeNom(getPlanCell(day.iso, sh.id, eq.id).equipe_id)}}
                </span>
                <button class="pc-del" @click="deletePlan(getPlanCell(day.iso, sh.id, eq.id).id)"><NavIcon name="x" :size="12" /></button>
              </div>
              <button v-else class="pg-assign" @click="openAssignModal(day.iso, sh, eq)" title="Affecter une équipe">+</button>
            </div>
          </template>
        </template>
      </div>

      <!-- ── VUE MOIS ── -->
      <div v-else-if="calView==='mois'" class="month-grid">
        <div class="mth-head" v-for="d in ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim']" :key="d">{{d}}</div>
        <div v-for="cell in monthCells" :key="cell.iso||('empty-'+cell.idx)"
             class="mth-cell" :class="{today:cell.isToday,'other-month':!cell.inMonth,'mth-empty':!cell.inMonth}">
          <template v-if="cell.inMonth">
            <div class="mth-day-num" :class="{today:cell.isToday}">{{cell.day}}</div>
            <div class="mth-chips">
              <div v-for="chip in getMontDayChips(cell.iso)" :key="chip.key"
                   class="mth-chip" :style="{background:chip.color+'22',color:chip.color,borderColor:chip.color+'44'}">
                {{chip.label}}
              </div>
              <div v-if="getMonthDayMore(cell.iso)>0" class="mth-more">+{{getMonthDayMore(cell.iso)}}</div>
            </div>
          </template>
        </div>
      </div>
    </div>

    <!-- ══ MODAL SHIFT ══ -->
    <div class="overlay" v-if="shiftModal.show" @click.self="shiftModal.show=false">
      <div class="modal">
        <div class="modal-hd">{{shiftModal.editing ? 'Modifier shift' : 'Nouveau shift'}}</div>
        <label class="lbl">Nom *</label>
        <input v-model="shiftModal.d.nom" class="inp" placeholder="ex: Matin" />
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Heure début *</label>
            <input type="time" v-model="shiftModal.d.heure_debut" class="inp" />
          </div>
          <div class="form-field">
            <label class="lbl">Heure fin *</label>
            <input type="time" v-model="shiftModal.d.heure_fin" class="inp" />
          </div>
          <div class="form-field">
            <label class="lbl">Durée (min)</label>
            <input type="number" v-model.number="shiftModal.d.duree_min" class="inp" placeholder="480" />
          </div>
        </div>
        <label class="lbl">Couleur</label>
        <div class="color-row">
          <input type="color" v-model="shiftModal.d.couleur" class="color-pick" />
          <div class="color-presets">
            <span v-for="c in colorPresets" :key="c" class="cp" :style="{background:c}" @click="shiftModal.d.couleur=c" :class="{selected:shiftModal.d.couleur===c}"></span>
          </div>
        </div>
        <label class="lbl chk"><input type="checkbox" v-model="shiftModal.d.actif" /> Actif</label>
        <div class="err" v-if="shiftModal.error">{{shiftModal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save" @click="saveShift" :disabled="shiftModal.saving">{{shiftModal.saving?'…':'Enregistrer'}}</button>
          <button class="btn-cancel" @click="shiftModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL ÉQUIPE ══ -->
    <div class="overlay" v-if="equipeModal.show" @click.self="equipeModal.show=false">
      <div class="modal modal-sm">
        <div class="modal-hd">{{equipeModal.editing ? 'Modifier équipe' : 'Nouvelle équipe'}}</div>
        <label class="lbl">Nom *</label>
        <input v-model="equipeModal.d.nom" class="inp" placeholder="ex: Équipe A" />
        <label class="lbl">Couleur</label>
        <div class="color-row">
          <input type="color" v-model="equipeModal.d.couleur" class="color-pick" />
          <div class="color-presets">
            <span v-for="c in colorPresets" :key="c" class="cp" :style="{background:c}" @click="equipeModal.d.couleur=c" :class="{selected:equipeModal.d.couleur===c}"></span>
          </div>
        </div>
        <label class="lbl chk"><input type="checkbox" v-model="equipeModal.d.actif" /> Active</label>
        <div class="err" v-if="equipeModal.error">{{equipeModal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save" @click="saveEquipe" :disabled="equipeModal.saving">{{equipeModal.saving?'…':'Enregistrer'}}</button>
          <button class="btn-cancel" @click="equipeModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL AFFECTATION ══ -->
    <div class="overlay" v-if="assignModal.show" @click.self="assignModal.show=false">
      <div class="modal modal-sm">
        <div class="modal-hd">Affecter une équipe</div>
        <div class="assign-ctx">
          <div><strong>{{assignModal.equip?.nom_equipement}}</strong></div>
          <div>{{assignModal.day}} — <span :style="{color:assignModal.shift?.couleur}">{{assignModal.shift?.nom}}</span></div>
        </div>
        <label class="lbl">Équipe *</label>
        <select v-model="assignModal.equipe_id" class="inp">
          <option :value="null">— Choisir —</option>
          <option v-for="e in equipes" :key="e.id" :value="e.id">{{e.nom}}</option>
        </select>
        <div class="modal-acts">
          <button class="btn-save" @click="saveAssign" :disabled="assignModal.saving || !assignModal.equipe_id">{{assignModal.saving?'…':'Affecter'}}</button>
          <button class="btn-cancel" @click="assignModal.show=false">Annuler</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, reactive, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { canPerform } from '../../services/permissions'
import NavIcon from '../../components/NavIcon.vue'
export default {
  components: { NavIcon },
  setup() {
    var shifts      = ref([])
    var equipes     = ref([])
    var equipements = ref([])
    var planningRows = ref([])
    var loadingS = ref(false)
    var loadingE = ref(false)
    var loadingP = ref(false)

    var calView    = ref('semaine')
    var weekOffset = ref(0)
    var dayOffset  = ref(0)
    var monthOffset = ref(0)
    var colorPresets = ['#3B82F6','#F97316','#7C3AED','#10B981','#EF4444','#EAB308','#06B6D4','#EC4899','#6B7280','#0EA5E9']

    var shiftModal  = reactive({ show:false, editing:null, d:{}, error:'', saving:false })
    var equipeModal = reactive({ show:false, editing:null, d:{}, error:'', saving:false })
    var assignModal = reactive({ show:false, day:'', shift:null, equip:null, equipe_id:null, saving:false })

    // Calcul de la semaine courante
    var weekDays = computed(function() {
      var today = new Date()
      var mon = new Date(today)
      var diff = (mon.getDay() + 6) % 7
      mon.setDate(mon.getDate() - diff + weekOffset.value * 7)
      var days = []
      var todayIso = today.toISOString().slice(0,10)
      for (var i = 0; i < 7; i++) {
        var d = new Date(mon)
        d.setDate(mon.getDate() + i)
        var iso = d.toISOString().slice(0,10)
        var labels = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim']
        days.push({ iso: iso, label: labels[i]+' '+d.getDate(), isToday: iso === todayIso })
      }
      return days
    })

    var weekLabel = computed(function() {
      if (!weekDays.value.length) return ''
      var d = weekDays.value[0].iso
      var parts = d.split('-')
      return parts[2]+'/'+parts[1]+'/'+parts[0]
    })

    var prevWeek = function() { weekOffset.value-- }
    var nextWeek = function() { weekOffset.value++ }
    var goToday  = function() { weekOffset.value = 0 }

    // ── Navigation calendrier ────────────────────────────────────
    var calPrev = function() {
      if (calView.value === 'jour') { dayOffset.value--; loadPlanning() }
      else if (calView.value === 'semaine') { weekOffset.value--; loadPlanning() }
      else if (calView.value === 'mois') { monthOffset.value--; loadPlanning() }
    }
    var calNext = function() {
      if (calView.value === 'jour') { dayOffset.value++; loadPlanning() }
      else if (calView.value === 'semaine') { weekOffset.value++; loadPlanning() }
      else if (calView.value === 'mois') { monthOffset.value++; loadPlanning() }
    }
    var calToday = function() {
      dayOffset.value = 0; weekOffset.value = 0; monthOffset.value = 0
      loadPlanning()
    }

    // ── Vue Jour ────────────────────────────────────────────────
    var currentDayIso = computed(function() {
      var d = new Date()
      d.setDate(d.getDate() + dayOffset.value)
      return d.toISOString().slice(0,10)
    })

    // ── Vue Mois ────────────────────────────────────────────────
    var monthCells = computed(function() {
      var today = new Date()
      var base = new Date(today.getFullYear(), today.getMonth() + monthOffset.value, 1)
      var year = base.getFullYear(), month = base.getMonth()
      var firstDow = (new Date(year, month, 1).getDay() + 6) % 7 // Mon=0
      var daysInMonth = new Date(year, month + 1, 0).getDate()
      var todayIso = today.toISOString().slice(0,10)
      var cells = []
      for (var i = 0; i < firstDow; i++) cells.push({ inMonth: false, idx: i })
      for (var d = 1; d <= daysInMonth; d++) {
        var dd = String(d).padStart(2,'0')
        var mm = String(month + 1).padStart(2,'0')
        var iso = year + '-' + mm + '-' + dd
        cells.push({ inMonth: true, day: d, iso: iso, isToday: iso === todayIso })
      }
      while (cells.length % 7 !== 0) cells.push({ inMonth: false, idx: cells.length })
      return cells
    })

    var calPeriodLabel = computed(function() {
      if (calView.value === 'jour') {
        var d = currentDayIso.value.split('-')
        return d[2]+'/'+d[1]+'/'+d[0]
      }
      if (calView.value === 'semaine') {
        return 'Semaine du ' + (weekDays.value[0]?.iso.split('-').reverse().join('/') || '')
      }
      if (calView.value === 'mois') {
        var mois = ['Janvier','Février','Mars','Avril','Mai','Juin','Juillet','Août','Septembre','Octobre','Novembre','Décembre']
        var today = new Date()
        var base = new Date(today.getFullYear(), today.getMonth() + monthOffset.value, 1)
        return mois[base.getMonth()] + ' ' + base.getFullYear()
      }
      return ''
    })

    var MONTH_MAX_CHIPS = 3
    var getMontDayChips = function(iso) {
      var rows = planningRows.value.filter(function(p) { return p.date === iso })
      return rows.slice(0, MONTH_MAX_CHIPS).map(function(p) {
        var sh = shifts.value.find(function(s) { return s.id === p.shift_id })
        return {
          key: p.id,
          label: (sh ? sh.nom.slice(0,4) : '?') + ' — ' + getEquipeNom(p.equipe_id).slice(0,3),
          color: sh ? sh.couleur : '#999'
        }
      })
    }
    var getMonthDayMore = function(iso) {
      var count = planningRows.value.filter(function(p) { return p.date === iso }).length
      return Math.max(0, count - MONTH_MAX_CHIPS)
    }

    var getPlanCell = function(date, shiftId, equipId) {
      return planningRows.value.find(function(p){ return p.date===date && p.shift_id===shiftId && p.equipement_id===equipId }) || null
    }

    var getEquipeColor = function(equipeId) {
      if (!equipeId) return '#999'
      var e = equipes.value.find(function(x){ return x.id===equipeId })
      return e ? e.couleur : '#999'
    }

    var getEquipeNom = function(equipeId) {
      if (!equipeId) return '?'
      var e = equipes.value.find(function(x){ return x.id===equipeId })
      return e ? e.nom : '?'
    }

    var loadAll = async function() {
      loadingS.value = true; loadingE.value = true
      var [rs, re, req] = await Promise.all([
        supabase.from('shifts').select('*').order('heure_debut'),
        supabase.from('equipes').select('*').order('nom'),
        supabase.from('equipements_conditionnement').select('id,nom_equipement,site').eq('actif',true).order('ordre_affichage')
      ])
      if (rs.data) shifts.value = rs.data
      if (re.data) equipes.value = re.data
      if (req.data) equipements.value = req.data
      loadingS.value = false; loadingE.value = false
      await loadPlanning()
    }

    var loadPlanning = async function() {
      loadingP.value = true
      var dates = []
      if (calView.value === 'jour') {
        dates = [currentDayIso.value]
      } else if (calView.value === 'semaine') {
        dates = weekDays.value.map(function(d){ return d.iso })
      } else if (calView.value === 'mois') {
        dates = monthCells.value.filter(function(c){ return c.inMonth }).map(function(c){ return c.iso })
      }
      var r = await supabase.from('shift_planning')
        .select('*')
        .in('date', dates)
        .order('date')
      if (r.data) planningRows.value = r.data
      loadingP.value = false
    }

    // ── Shifts CRUD ──
    var openShiftModal = function(s) {
      shiftModal.editing = s; shiftModal.error = ''; shiftModal.saving = false
      shiftModal.d = s
        ? { nom:s.nom, heure_debut:s.heure_debut, heure_fin:s.heure_fin, duree_min:s.duree_min, couleur:s.couleur, actif:s.actif }
        : { nom:'', heure_debut:'06:00', heure_fin:'14:00', duree_min:480, couleur:'#3B82F6', actif:true }
      shiftModal.show = true
    }

    var saveShift = async function() {
      if (!canPerform('gerer_shifts')) { alert('Permission « gérer shifts & équipes » requise'); return }
      if (!shiftModal.d.nom.trim()) { shiftModal.error='Le nom est requis.'; return }
      shiftModal.saving = true
      var payload = Object.assign({}, shiftModal.d, { nom:shiftModal.d.nom.trim(), updated_at:new Date().toISOString() })
      var r = shiftModal.editing
        ? await supabase.from('shifts').update(payload).eq('id',shiftModal.editing.id)
        : await supabase.from('shifts').insert(payload)
      if (r.error) { shiftModal.error=r.error.message; shiftModal.saving=false; return }
      shiftModal.show=false; shiftModal.saving=false
      var rs = await supabase.from('shifts').select('*').order('heure_debut')
      if (rs.data) shifts.value = rs.data
    }

    var deleteShift = async function(s) {
      if (!canPerform('gerer_shifts')) { alert('Permission « gérer shifts & équipes » requise'); return }
      if (!confirm('Supprimer le shift "'+s.nom+'" ?')) return
      await supabase.from('shifts').delete().eq('id',s.id)
      shifts.value = shifts.value.filter(function(x){return x.id!==s.id})
    }

    // ── Équipes CRUD ──
    var openEquipeModal = function(e) {
      equipeModal.editing = e; equipeModal.error = ''; equipeModal.saving = false
      equipeModal.d = e
        ? { nom:e.nom, couleur:e.couleur, actif:e.actif }
        : { nom:'', couleur:'#3B82F6', actif:true }
      equipeModal.show = true
    }

    var saveEquipe = async function() {
      if (!canPerform('gerer_shifts')) { alert('Permission « gérer shifts & équipes » requise'); return }
      if (!equipeModal.d.nom.trim()) { equipeModal.error='Le nom est requis.'; return }
      equipeModal.saving = true
      var payload = { nom:equipeModal.d.nom.trim(), couleur:equipeModal.d.couleur, actif:equipeModal.d.actif, updated_at:new Date().toISOString() }
      var r = equipeModal.editing
        ? await supabase.from('equipes').update(payload).eq('id',equipeModal.editing.id)
        : await supabase.from('equipes').insert(payload)
      if (r.error) { equipeModal.error=r.error.message; equipeModal.saving=false; return }
      equipeModal.show=false; equipeModal.saving=false
      var re = await supabase.from('equipes').select('*').order('nom')
      if (re.data) equipes.value = re.data
    }

    var deleteEquipe = async function(e) {
      if (!canPerform('gerer_shifts')) { alert('Permission « gérer shifts & équipes » requise'); return }
      if (!confirm('Supprimer l\'équipe "'+e.nom+'" ?')) return
      await supabase.from('equipes').delete().eq('id',e.id)
      equipes.value = equipes.value.filter(function(x){return x.id!==e.id})
    }

    // ── Planning CRUD ──
    var openAssignModal = function(day, shift, equip) {
      assignModal.day = day; assignModal.shift = shift; assignModal.equip = equip
      assignModal.equipe_id = null; assignModal.saving = false
      assignModal.show = true
    }

    var saveAssign = async function() {
      if (!canPerform('gerer_shifts')) { alert('Permission « gérer shifts & équipes » requise'); return }
      if (!assignModal.equipe_id) return
      assignModal.saving = true
      var r = await supabase.from('shift_planning').upsert({
        date: assignModal.day, shift_id: assignModal.shift.id,
        equipement_id: assignModal.equip.id, equipe_id: assignModal.equipe_id,
        updated_at: new Date().toISOString()
      }, { onConflict: 'date,shift_id,equipement_id' })
      if (!r.error) { assignModal.show=false; await loadPlanning() }
      assignModal.saving = false
    }

    var deletePlan = async function(id) {
      if (!canPerform('gerer_shifts')) { alert('Permission « gérer shifts & équipes » requise'); return }
      await supabase.from('shift_planning').delete().eq('id',id)
      await loadPlanning()
    }

    onMounted(loadAll)

    return {
      shifts, equipes, equipements, planningRows, loadingS, loadingE, loadingP,
      weekDays, weekLabel, weekOffset, colorPresets,
      calView, dayOffset, monthOffset, currentDayIso, monthCells, calPeriodLabel,
      shiftModal, equipeModal, assignModal,
      prevWeek, nextWeek, goToday,
      calPrev, calNext, calToday,
      getPlanCell, getEquipeColor, getEquipeNom,
      getMontDayChips, getMonthDayMore,
      openShiftModal, saveShift, deleteShift,
      openEquipeModal, saveEquipe, deleteEquipe,
      openAssignModal, saveAssign, deletePlan
    }
  }
}
</script>

<style scoped>
.shifts-page{font-family:'Inter',sans-serif;font-size:13px;}
.two-cols{display:grid;grid-template-columns:1fr 1fr;gap:16px}
.card{border:1px solid #e5e7eb;border-radius:8px;overflow:hidden}
.card-hd{display:flex;align-items:center;justify-content:space-between;padding:10px 14px;background:#eff6ff;border-bottom:1px solid #dbeafe}
.card-title{font-size:12px;font-weight:700;color:#2563eb;letter-spacing:.3px}
.btn-add:hover{background:#333}
.loading{padding:16px;text-align:center;color:#999;font-size:12px}
.empty{padding:16px;text-align:center;color:#bbb;font-size:12px}

.shift-row{display:flex;align-items:center;gap:10px;padding:10px 14px;border-bottom:1px solid #f0f0f0}
.shift-color{width:4px;height:36px;border-radius:2px;flex-shrink:0}
.shift-body{flex:1}
.shift-nom{font-size:13px;font-weight:500}
.shift-hours{display:flex;align-items:center;gap:6px;margin-top:2px}
.mono{font-family:'SF Mono',monospace;font-size:11px;color:#555}
.arrow{color:#999;font-size:11px}
.dur-badge{font-size:10px;background:#f0f0f0;color:#666;padding:1px 6px;border-radius:8px;font-family:'SF Mono',monospace}
.stat-badge{font-size:10px;padding:2px 7px;border-radius:8px;flex-shrink:0}
.actif{background:#F0FDF4;color:#15803D}
.inactif{background:#F5F5F5;color:#999}
.row-acts{display:flex;gap:4px}
.ia{background:none;border:none;cursor:pointer;font-size:12px;padding:3px 6px;border-radius:2px;opacity:.7}
.ia:hover{background:#e8e8e8;opacity:1}
.ia.del:hover{background:#fde8e8}

.equipe-row{display:flex;align-items:center;gap:10px;padding:10px 14px;border-bottom:1px solid #f0f0f0}
.eq-color{width:12px;height:12px;border-radius:50%;flex-shrink:0}
.equipe-nom{flex:1;font-size:13px;font-weight:500}

/* Planning grid */
.planning-grid{display:grid;grid-template-columns:140px repeat(var(--cols, 4), 1fr);border:1px solid #e5e7eb;border-radius:8px;overflow:auto;max-height:calc(100vh - 280px);font-size:11px}
.pg-head{padding:8px 6px;background:#eff6ff;border-bottom:1px solid #dbeafe;border-right:1px solid #dbeafe;font-size:10px;font-weight:700;color:#2563eb;text-align:center;position:sticky;top:0;z-index:2}
.pg-corner{}
.pg-equip{text-align:center}
.pg-eq-nom{font-size:11px;font-weight:600}
.pg-eq-site{font-size:9px;color:#aaa;margin-top:1px}
.pg-label{padding:5px 8px;background:#fafafa;border-bottom:1px solid #f0f0f0;border-right:1px solid #e8e8e8;display:flex;flex-direction:column;gap:3px;min-height:52px}
.pg-label.today{background:#EBF5FF}
.day-label{font-size:10px;font-weight:600;color:#333;margin-bottom:1px}
.sh-chip{font-size:9px;font-weight:600;padding:2px 6px;border-radius:8px;border:1px solid;display:inline-flex;align-items:center;gap:3px;white-space:nowrap}
.sh-time{opacity:.7}
.pg-cell{padding:4px 6px;border-bottom:1px solid #f0f0f0;border-right:1px solid #e8e8e8;min-height:52px;display:flex;align-items:center;justify-content:center}
.pg-cell.today{background:#fafeff}
.plan-chip{display:flex;align-items:center;gap:4px;padding:4px 8px;border-radius:12px;border:1px solid;font-size:10px;width:100%;justify-content:space-between}
.pc-eq{font-weight:600;font-size:10px}
.pc-del{background:none;border:none;cursor:pointer;font-size:9px;color:#aaa;padding:0 2px;line-height:1}
.pc-del:hover{color:#E24B4A}
.pg-assign{background:none;border:1px dashed #ddd;color:#ccc;font-size:14px;width:24px;height:24px;border-radius:50%;cursor:pointer;display:flex;align-items:center;justify-content:center;padding:0}
.pg-assign:hover{border-color:#185FA5;color:#185FA5;background:#EBF5FF}
.week-nav{display:flex;gap:4px;align-items:center}
.wn-btn{padding:4px 10px;font-size:12px;border:1px solid #ddd;background:#fff;border-radius:2px;cursor:pointer}
.wn-btn:hover{background:#f5f5f5}
.wn-btn.today{background:#0a0a0a;color:#fff;border-color:#0a0a0a}

/* Modal */
.overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:100}
.modal{background:#fff;padding:24px;width:480px;max-width:96vw;border-radius:10px;box-shadow:0 20px 50px rgba(0,0,0,.2);max-height:90vh;overflow-y:auto}
.modal-sm{width:360px}
.modal-hd{font-size:14px;font-weight:800;margin-bottom:16px;padding-bottom:12px;border-bottom:1px solid #f3f4f6}
.lbl{display:block;font-size:10px;font-weight:700;color:#6b7280;text-transform:uppercase;letter-spacing:1px;margin-bottom:4px;margin-top:10px}
.lbl.chk{display:flex;align-items:center;gap:6px;cursor:pointer;margin-top:10px;text-transform:none;font-size:13px}
.inp{width:100%;padding:8px 10px;border:1px solid #e5e7eb;font-size:12px;outline:none;box-sizing:border-box;font-family:'Inter',sans-serif;border-radius:5px}
.inp:focus{border-color:#2563eb}
.form-row{display:flex;gap:12px}
.form-field{flex:1}
.color-row{display:flex;align-items:center;gap:8px;margin-top:4px}
.color-pick{width:44px;height:32px;padding:1px;border:1px solid #ddd;border-radius:2px;cursor:pointer}
.color-presets{display:flex;gap:4px;flex-wrap:wrap}
.cp{width:20px;height:20px;border-radius:50%;cursor:pointer;border:2px solid transparent}
.cp:hover{transform:scale(1.15)}
.cp.selected{border-color:#0a0a0a}
.assign-ctx{padding:8px 10px;background:#f9fafb;border:1px solid #e5e7eb;border-radius:5px;font-size:12px;margin-bottom:12px;display:flex;flex-direction:column;gap:2px}
.err{color:#ef4444;font-size:11px;margin-top:8px;padding:6px 10px;background:#fef2f2;border-radius:4px}
.modal-acts{display:flex;gap:8px;margin-top:16px;padding-top:12px;border-top:1px solid #f3f4f6}
.btn-save{flex:1;padding:10px;background:#2563eb;color:#fff;border:none;font-size:12px;font-weight:600;cursor:pointer;border-radius:5px}
.btn-save:hover:not(:disabled){background:#1d4ed8}
.btn-save:disabled{opacity:.5}
.btn-cancel{flex:1;padding:10px;background:#f5f5f5;color:#6b7280;border:1px solid #e5e7eb;font-size:12px;cursor:pointer;border-radius:5px}
.btn-cancel:hover{background:#eee}

/* Calendar view tabs */
.cal-view-tabs{display:flex;gap:0;border:1px solid #e5e7eb;border-radius:5px;overflow:hidden}
.cv-tab{border:none;background:#f9fafb;color:#6b7280;font-size:11px;font-weight:600;padding:5px 12px;cursor:pointer;border-right:1px solid #e5e7eb}
.cv-tab:last-child{border-right:none}
.cv-tab.active{background:#0a0a0a;color:#fff}
.cal-nav{display:flex;align-items:center;gap:6px;padding:8px 14px;background:#fafafa;border-bottom:1px solid #f0f0f0}
.cal-period{font-size:12px;font-weight:600;margin-left:6px;color:#333}

/* Month grid */
.month-grid{display:grid;grid-template-columns:repeat(7,1fr);border-left:1px solid #e8e8e8;border-top:1px solid #e8e8e8}
.mth-head{text-align:center;font-size:10px;font-weight:700;color:#2563eb;text-transform:uppercase;padding:6px 0;background:#eff6ff;border-right:1px solid #dbeafe;border-bottom:1px solid #dbeafe;position:sticky;top:0;z-index:2}
.mth-cell{min-height:76px;border-right:1px solid #e8e8e8;border-bottom:1px solid #e8e8e8;padding:4px 5px;vertical-align:top;position:relative}
.mth-cell.other-month{background:#f9f9f9}
.mth-day-num{font-size:11px;font-weight:600;color:#555;margin-bottom:3px;width:20px;height:20px;display:flex;align-items:center;justify-content:center;border-radius:50%}
.mth-day-num.today{background:#0a0a0a;color:#fff}
.mth-chips{display:flex;flex-direction:column;gap:2px}
.mth-chip{font-size:9px;font-weight:600;padding:1px 5px;border-radius:8px;border:1px solid;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.mth-more{font-size:9px;color:#aaa;margin-top:1px}

@media(max-width:768px){
  .two-cols{grid-template-columns:1fr}
  .planning-grid{font-size:10px}
  .mth-cell{min-height:52px}
}
</style>
