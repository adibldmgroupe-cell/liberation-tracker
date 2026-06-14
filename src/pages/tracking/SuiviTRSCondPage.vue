<template>
  <div class="pdpc" :data-theme="theme">

    <!-- ── HEADER ── -->
    <div class="ph">
      <div class="ph-l">
        <span class="pt">SESSIONS TRS</span>
      </div>
      <div class="ph-r">
        <div class="stabs">
          <button v-for="s in ['Tous','PHARMA','OTC']" :key="s" class="stab" :class="{active:filterSite===s}" @click="filterSite=s">{{s}}</button>
        </div>
        <button class="btn-ref" @click="loadAll" :class="{spin:loading}">↻</button>
        <button class="btn-ref" @click="cycleTheme" :title="themeTitle">{{themeIcon}}</button>
      </div>
    </div>

    <!-- ── FILTRES ── -->
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

    <!-- ── TABLEAU SESSIONS ── -->
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
            <th class="tc">D%</th>
            <th class="tc">P%</th>
            <th class="tc">Q%</th>
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
            <td class="num"><span :class="vClass(s.disponibilite)">{{s.disponibilite!=null?s.disponibilite+'%':'—'}}</span></td>
            <td class="num"><span :class="vClass(s.performance)">{{s.performance!=null?s.performance+'%':'—'}}</span></td>
            <td class="num"><span :class="vClass(s.qualite)">{{s.qualite!=null?s.qualite+'%':'—'}}</span></td>
            <td class="num"><span :class="vClass(s.trs)">{{s.trs!=null?s.trs+'%':'—'}}</span></td>
            <td><span class="schip" :class="'sc-'+(s.statut||'').toLowerCase().replace(/\s/g,'-')">{{s.statut}}</span></td>
          </tr>
        </tbody>
      </table>
      <div v-else-if="loading" class="empty">Chargement…</div>
      <div v-else class="empty">Aucune session trouvée</div>
    </div>

  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { useTheme } from '../../composables/useTheme'

export default {
  setup() {
    var { theme } = useTheme()

    var loading      = ref(false)
    var equipements  = ref([])
    var shifts       = ref([])
    var allSessions  = ref([])

    var filterSite   = ref('Tous')
    var sessSearch   = ref('')
    var sessEquipId  = ref(null)
    var sessStatut   = ref('')
    var sessShiftId  = ref(null)
    var sessSortCol  = ref('date')
    var sessSortDir  = ref('desc')

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
      return res.sort(function(a,b) {
        var va = a[sessSortCol.value]||'', vb = b[sessSortCol.value]||''
        if (va < vb) return sessSortDir.value==='asc'?-1:1
        if (va > vb) return sessSortDir.value==='asc'?1:-1
        return 0
      })
    })

    var sortSess = function(col) {
      if (sessSortCol.value===col) sessSortDir.value = sessSortDir.value==='asc'?'desc':'asc'
      else { sessSortCol.value=col; sessSortDir.value='asc' }
    }
    var sortArrow = function(col) {
      if (sessSortCol.value!==col) return '⇅'
      return sessSortDir.value==='asc'?'↑':'↓'
    }

    var loadAll = async function() {
      loading.value = true
      var [rEq, rSh, rSess] = await Promise.all([
        supabase.from('equipements_conditionnement').select('id,nom_equipement,site').eq('actif',true).order('ordre_affichage'),
        supabase.from('shifts').select('id,nom,couleur').eq('actif',true).order('heure_debut'),
        supabase.from('production_sessions')
          .select('*, lots(numero_lot, products(code_article,description)), equipements_conditionnement(nom_equipement,site), shifts(nom,couleur)')
          .is('deleted_at',null)
          .order('date',{ascending:false}).order('heure_debut',{ascending:false})
          .limit(800)
      ])
      if (rEq.data) equipements.value = rEq.data
      if (rSh.data) shifts.value      = rSh.data
      if (rSess.data) {
        allSessions.value = rSess.data.map(function(s) {
          return Object.assign({}, s, {
            numero_lot:    s.lots ? s.lots.numero_lot : '—',
            code_article:  s.lots && s.lots.products ? s.lots.products.code_article : '—',
            nom_equipement:s.equipements_conditionnement ? s.equipements_conditionnement.nom_equipement : '—',
            site:          s.equipements_conditionnement ? s.equipements_conditionnement.site : '',
            shift_nom:     s.shifts ? s.shifts.nom     : '',
            shift_couleur: s.shifts ? s.shifts.couleur : '#3B82F6'
          })
        })
      }
      loading.value = false
    }

    onMounted(loadAll)

    var THEME_ORDER = ['night', 'day', 'workshop']
    var cycleTheme = function() {
      var idx = THEME_ORDER.indexOf(theme.value)
      theme.value = THEME_ORDER[(idx + 1) % THEME_ORDER.length]
    }
    var themeIcon = computed(function() {
      return theme.value === 'day' ? '☀️' : theme.value === 'workshop' ? '🏭' : '🌙'
    })
    var themeTitle = computed(function() {
      return theme.value === 'night' ? 'Nuit → Jour' : theme.value === 'day' ? 'Jour → Atelier' : 'Atelier → Nuit'
    })

    return {
      theme, cycleTheme, themeIcon, themeTitle,
      loading, equipements, shifts,
      filterSite, sessSearch, sessEquipId, sessStatut, sessShiftId,
      filteredSessions, fmtDate, vClass, sortSess, sortArrow, loadAll
    }
  }
}
</script>

<style scoped>
.pdpc { min-height:100%; background:#0b0b1c; color:#e0e0f0; font-family:'Inter',sans-serif; font-size:13px; }
.ph { display:flex; align-items:center; justify-content:space-between; padding-bottom:10px; border-bottom:2px solid #1a1a38; margin-bottom:14px; flex-wrap:wrap; gap:8px; }
.ph-l { display:flex; align-items:center; gap:12px; }
.ph-r { display:flex; align-items:center; gap:6px; }
.pt { font-size:11px; font-weight:600; letter-spacing:1.5px; text-transform:uppercase; color:#a0a0c8; }
.stabs { display:flex; gap:3px; }
.stab { padding:4px 10px; font-size:11px; border:1px solid #252545; background:#12122a; color:#8888b0; border-radius:3px; cursor:pointer; }
.stab.active { background:#1e3a6e; color:#93c5fd; border-color:#3b82f6; }
.btn-ref { padding:4px 10px; font-size:16px; border:1px solid #252545; background:#12122a; color:#8888b0; border-radius:3px; cursor:pointer; }
.btn-ref.spin { animation:spin .7s linear infinite; }
@keyframes spin{from{transform:rotate(0)}to{transform:rotate(360deg)}}
.t-bar { display:flex; gap:8px; margin-bottom:10px; flex-wrap:wrap; }
.t-srch { flex:1; min-width:150px; padding:6px 10px; border:1px solid #252545; background:#12122a; color:#e0e0f0; border-radius:3px; font-size:12px; outline:none; }
.t-srch:focus { border-color:#3b82f6; }
.t-sel { padding:6px 10px; border:1px solid #252545; background:#12122a; color:#a0a0c8; border-radius:3px; font-size:12px; cursor:pointer; }
.dt-wrap { overflow-x:auto; border:1px solid #1a1a38; border-radius:6px; }
.dt { width:100%; border-collapse:collapse; font-size:12px; min-width:640px; }
.dt thead tr { position:sticky; top:0; z-index:2; }
.dt th { background:#07071a; padding:8px 10px; text-align:left; font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:.4px; color:#6060a0; border-bottom:2px solid #1a1a38; white-space:nowrap; }
.dt th.srt { cursor:pointer; user-select:none; }
.dt th.srt:hover { background:#0f0f28; color:#a0a0c8; }
.dt th.tc { text-align:center; }
.dt td { padding:8px 10px; border-bottom:1px solid #131330; color:#c0c0e0; vertical-align:middle; }
.dt tr:hover td { background:#0f0f28; }
.si { font-size:9px; color:#4a4a70; }
.mono { font-family:monospace; font-size:11px; }
.sm { font-size:11px; color:#9090b8; max-width:160px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.num { text-align:center; font-family:monospace; }
.tc { text-align:center; }
.empty { padding:40px; text-align:center; color:#3a3a60; font-size:13px; }
.vg { color:#34d399; font-weight:600; }
.vo { color:#fbbf24; font-weight:600; }
.vr { color:#f87171; font-weight:600; }
.shchip { font-size:10px; font-weight:600; padding:1px 7px; border-radius:8px; }
.schip { font-size:10px; padding:2px 7px; border-radius:8px; font-weight:500; }
.sc-en-cours { background:#065f4622; color:#34d399; }
.sc-clôturé, .sc-cloture { background:#30303055; color:#9090b8; }
.sc-arrêt, .sc-arret { background:#7f1d1d33; color:#f87171; }
/* JOUR */
.pdpc[data-theme="day"] { background:#ffffff; color:#1a1a2e; }
.pdpc[data-theme="day"] .ph { border-bottom-color:#dbeafe; }
.pdpc[data-theme="day"] .pt { color:#2563eb; }
.pdpc[data-theme="day"] .stab { background:#f9fafb; color:#6b7280; border-color:#e5e7eb; }
.pdpc[data-theme="day"] .stab.active { background:#2563eb; color:#fff; border-color:#2563eb; }
.pdpc[data-theme="day"] .btn-ref { background:#f9fafb; color:#6b7280; border-color:#e5e7eb; }
.pdpc[data-theme="day"] .t-srch { background:#fff; color:#1a1a2e; border-color:#e5e7eb; }
.pdpc[data-theme="day"] .t-sel { background:#fff; color:#1a1a2e; border-color:#e5e7eb; }
.pdpc[data-theme="day"] .dt-wrap { border-color:#e5e7eb; }
.pdpc[data-theme="day"] .dt th { background:#eff6ff; color:#2563eb; border-bottom-color:#dbeafe; }
.pdpc[data-theme="day"] .dt td { border-bottom-color:#f3f4f6; color:#374151; }
.pdpc[data-theme="day"] .dt tr:hover td { background:#faf5ff; }
.pdpc[data-theme="day"] .sc-en-cours { background:#d1fae5; color:#065f46; }
.pdpc[data-theme="day"] .sc-clôturé,
.pdpc[data-theme="day"] .sc-cloture  { background:#f3f4f6; color:#6b7280; }
.pdpc[data-theme="day"] .sc-arrêt,
.pdpc[data-theme="day"] .sc-arret   { background:#fee2e2; color:#dc2626; }
/* ATELIER */
.pdpc[data-theme="workshop"] { background:#0d1117; color:#cdd9e5; }
.pdpc[data-theme="workshop"] .ph { border-bottom-color:#30363d; }
.pdpc[data-theme="workshop"] .dt th { background:#161b22; border-bottom-color:#30363d; color:#8b949e; }
.pdpc[data-theme="workshop"] .dt td { border-bottom-color:#21262d; color:#cdd9e5; }
.pdpc[data-theme="workshop"] .dt tr:hover td { background:#161b22; }
@media(max-width:768px){ .t-bar { flex-direction:column; } .t-srch { width:100%; } }
</style>
