<template>
  <div>
    <!-- Header -->
    <div class="ph">
      <div>
        <div class="pt">PERMISSIONS PAR SERVICE</div>
        <div class="ps" v-if="!loading">{{services.length}} services · {{allPerms.length}} permissions</div>
      </div>
      <button class="btn-mgr" :class="{'btn-mgr-on': showMgr}" @click="showMgr=!showMgr">
        {{showMgr ? '✕ Fermer' : '⚙ Gérer les services'}}
      </button>
    </div>

    <!-- Services CRUD panel -->
    <div class="mgr-panel" v-if="showMgr">
      <div class="mgr-title">Services enregistrés</div>
      <div class="mgr-list">
        <div v-for="svc in services" :key="svc.id" class="mgr-row">
          <template v-if="editSvc && editSvc.id===svc.id">
            <span class="ms-id">{{svc.id}}</span>
            <input v-model="editSvc.label" class="mgr-inp" @keyup.enter="saveEditSvc" @keyup.escape="editSvc=null" />
            <button class="mb ok" @click="saveEditSvc">✓</button>
            <button class="mb cancel" @click="editSvc=null">✕</button>
          </template>
          <template v-else>
            <span class="ms-id">{{svc.id}}</span>
            <span class="ms-label">{{svc.label}}</span>
            <div class="ms-actions">
              <button class="mb edit" @click="startEditSvc(svc)">Renommer</button>
              <button class="mb del" @click="deleteSvc(svc)">Supprimer</button>
            </div>
          </template>
        </div>
      </div>
      <div class="mgr-add">
        <input v-model="newSvcId" class="mgr-inp" placeholder="identifiant (ex: qualite_ops)" @keyup.enter="addSvc" />
        <input v-model="newSvcLabel" class="mgr-inp" placeholder="Libellé (ex: Qualité Ops)" @keyup.enter="addSvc" />
        <button class="btn-add" @click="addSvc" :disabled="!newSvcId.trim()||!newSvcLabel.trim()">+ Ajouter</button>
      </div>
      <div class="mgr-err" v-if="mgrErr">{{mgrErr}}</div>
    </div>

    <div v-if="loading" class="em">Chargement…</div>
    <div v-else>
      <!-- Legend -->
      <div class="legend">
        <span class="leg-item"><span class="cb-on">✓</span> Autorisé</span>
        <span class="leg-item leg-col">Clic colonne = toggle toute la colonne</span>
        <span class="leg-item leg-row">Clic service = toggle toute la ligne</span>
        <span class="leg-item leg-grp">Clic groupe = toggle tout le groupe</span>
      </div>

      <!-- Matrix -->
      <div class="matrix-outer">
        <table class="matrix">
          <thead>
            <!-- Row 1: group headers -->
            <tr class="grp-row">
              <th class="corner" rowspan="2">Service</th>
              <th v-for="g in actionGroups" :key="g.label" :colspan="g.actions.length" class="grp-hd">
                <div class="grp-hd-inner">
                  <span class="grp-hd-label">{{g.label}}</span>
                  <button class="grp-tog" @click.stop="toggleGroup(g)" title="Tout basculer pour ce groupe (tous services)">⊡</button>
                </div>
              </th>
            </tr>
            <!-- Row 2: individual permission headers (rotated) -->
            <tr class="perm-row">
              <th
                v-for="p in allPerms"
                :key="p.key"
                class="perm-hd"
                @click="togglePermColumn(p.key)"
                :title="'Toggle «' + p.label + '» pour tous les services'"
              >
                <div class="perm-hd-inner">{{p.label}}</div>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="svc in services" :key="svc.id">
              <td class="svc-cell" @click="toggleServiceRow(svc)" :title="'Toggle toutes les permissions pour ' + svc.label">
                <div class="svc-inner">
                  <span class="svc-name">{{svc.label}}</span>
                  <span class="svc-count">{{countAllowed(svc.id)}}/{{allPerms.length}}</span>
                </div>
              </td>
              <td
                v-for="p in allPerms"
                :key="p.key"
                class="cb-cell"
                :class="'grp-'+getGroupIndex(p.key)"
                @click="togglePerm(svc.id, p.key)"
              >
                <span :class="isAllowed(svc.id, p.key) ? 'cb-on' : 'cb-off'">{{isAllowed(svc.id, p.key) ? '✓' : ''}}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'

export default {
  setup() {
    var loading = ref(true)
    var permMap = ref({})
    var services = ref([])
    var showMgr = ref(false)
    var editSvc = ref(null)
    var newSvcId = ref('')
    var newSvcLabel = ref('')
    var mgrErr = ref('')

    var actionGroups = [
      {
        label: 'Circuit OF / OC',
        actions: [
          { key: 'creer_lot', label: 'Créer un lot' },
          { key: 'mettre_en_circuit_of', label: 'Mettre en circuit OF' },
          { key: 'mettre_en_circuit_oc', label: 'Mettre en circuit OC' },
          { key: 'valider_quantites_of', label: 'Valider quantités OF' },
          { key: 'valider_quantites_oc', label: 'Valider quantités OC' },
          { key: 'valider_of', label: 'Valider OF (AQ)' },
          { key: 'valider_oc', label: 'Valider OC (AQ)' },
          { key: 'autoriser_lancement', label: 'Autoriser lancement (DT)' },
          { key: 'remettre_ordre_production', label: 'Remettre à production' },
          { key: 'accuser_reception_of', label: 'AR OF' },
          { key: 'accuser_reception_oc', label: 'AR OC' },
        ]
      },
      {
        label: 'Documents',
        actions: [
          { key: 'emettre_if', label: 'Émettre IF' },
          { key: 'emettre_ic', label: 'Émettre IC' },
          { key: 'emettre_da_pc', label: 'Émettre DA PC' },
          { key: 'emettre_da_micro', label: 'Émettre DA Micro' },
          { key: 'emettre_rvp', label: 'Émettre RVP' },
          { key: 'verifier_if', label: 'Vérifier IF' },
          { key: 'verifier_ic', label: 'Vérifier IC' },
          { key: 'verifier_da_pc', label: 'Vérifier DA PC' },
          { key: 'verifier_da_micro', label: 'Vérifier DA Micro' },
          { key: 'verifier_rvp', label: 'Vérifier RVP' },
          { key: 'retourner_document', label: 'Retourner doc.' },
          { key: 'rectifier_document', label: 'Rectifier doc.' },
          { key: 'approuver_if', label: 'Approuver IF' },
          { key: 'approuver_ic', label: 'Approuver IC' },
          { key: 'approuver_da_pc', label: 'Approuver DA PC' },
          { key: 'approuver_da_micro', label: 'Approuver DA Micro' },
          { key: 'approuver_rvp', label: 'Approuver RVP' },
          { key: 'transferer_dossier_dt', label: 'Transférer au DT' },
          { key: 'liberer_lot', label: 'Libérer le lot' },
          { key: 'doc_delete', label: 'Supprimer doc.' },
        ]
      },
      {
        label: 'AQL',
        actions: [
          { key: 'demander_aql_fab', label: 'Demander AQL Fab.' },
          { key: 'demander_aql_cond', label: 'Demander AQL Cond.' },
          { key: 'realiser_aql', label: 'Réaliser AQL' },
          { key: 'aql_delete', label: 'Supprimer AQL' },
        ]
      },
      {
        label: 'MàJ Docs',
        actions: [
          { key: 'emettre_maj_if', label: 'Émettre MàJ IF' },
          { key: 'emettre_maj_ic', label: 'Émettre MàJ IC' },
          { key: 'emettre_maj_nmcl_of', label: 'MàJ Nmcl OF' },
          { key: 'emettre_maj_nmcl_oc', label: 'MàJ Nmcl OC' },
          { key: 'verifier_maj_doc', label: 'Vérifier MàJ (AQ)' },
          { key: 'approuver_maj_doc', label: 'Approuver MàJ (DT)' },
        ]
      },
      {
        label: 'Clôture SAP',
        actions: [
          { key: 'emettre_cloture_sap_of', label: 'Émettre clôture OF' },
          { key: 'valider_cloture_sap_of', label: 'Valider clôture OF' },
          { key: 'demander_cloture_sap_of', label: 'Demander clôture OF' },
          { key: 'confirmer_cloture_sap_of', label: 'Confirmer clôture OF' },
          { key: 'emettre_cloture_sap_oc', label: 'Émettre clôture OC' },
          { key: 'valider_cloture_sap_oc', label: 'Valider clôture OC' },
          { key: 'demander_cloture_sap_oc', label: 'Demander clôture OC' },
          { key: 'confirmer_cloture_sap_oc', label: 'Confirmer clôture OC' },
        ]
      },
      {
        label: 'Planning',
        actions: [
          { key: 'modifier_planning', label: 'Modifier dates prév.' },
        ]
      },
      {
        label: 'Déviations',
        actions: [
          { key: 'declarer_nc', label: 'Déclarer NC' },
          { key: 'cloturer_deviation', label: 'Clôturer déviation' },
          { key: 'dev_bloquer', label: 'Bloquer lot (dév.)' },
          { key: 'dev_delete', label: 'Supprimer déviation' },
        ]
      },
      {
        label: 'Fab. / LCQ',
        actions: [
          { key: 'declarer_etape_fab', label: 'Déclarer étape Fab.' },
          { key: 'declarer_fin_sf', label: 'Fin semi-fini' },
          { key: 'declarer_fin_pf', label: 'Fin produit fini' },
          { key: 'realiser_analyse_pc', label: 'Analyse PC' },
          { key: 'realiser_analyse_micro', label: 'Analyse Micro' },
        ]
      },
      {
        label: 'Accusés réception',
        actions: [
          { key: 'accuser_reception_circuit', label: 'AR circuit OF/OC' },
          { key: 'accuser_reception_document', label: 'AR document' },
          { key: 'accuser_reception_aql_demande', label: 'AR demande AQL' },
          { key: 'accuser_reception_aql_resultat', label: 'AR résultat AQL' },
        ]
      },
      {
        label: 'Administration',
        actions: [
          { key: 'modifier_lot', label: 'Modifier un lot' },
          { key: 'supprimer_lot', label: 'Supprimer un lot' },
          { key: 'lot_edit_statut_sap', label: 'Modifier statut SAP' },
          { key: 'lot_edit_quarantaine', label: 'Mettre en quarantaine' },
        ]
      },
      {
        label: 'Dashboard',
        actions: [
          { key: 'voir_dashboard', label: 'Voir dashboard' },
          { key: 'voir_lots', label: 'Voir les lots' },
          { key: 'voir_timeline', label: 'Voir timeline' },
          { key: 'voir_kpi', label: 'Voir KPI' },
        ]
      },
    ]

    var allPerms = computed(function() {
      var result = []
      actionGroups.forEach(function(g) { g.actions.forEach(function(a) { result.push(a) }) })
      return result
    })

    // Build a map: permKey → groupIndex (for column shading)
    var groupIndexMap = {}
    actionGroups.forEach(function(g, gi) { g.actions.forEach(function(a) { groupIndexMap[a.key] = gi }) })
    var getGroupIndex = function(key) { return groupIndexMap[key] !== undefined ? groupIndexMap[key] % 2 : 0 }

    var isAllowed = function(svc, action) {
      return !!(permMap.value[svc] && permMap.value[svc][action])
    }

    var countAllowed = function(svcId) {
      if (!permMap.value[svcId]) return 0
      return Object.values(permMap.value[svcId]).filter(Boolean).length
    }

    // Single toggle
    var togglePerm = async function(svc, action) {
      var current = isAllowed(svc, action)
      var newVal = !current
      if (!permMap.value[svc]) permMap.value[svc] = {}
      permMap.value[svc][action] = newVal
      var { error } = await supabase.from('permissions')
        .upsert({ service: svc, action: action, allowed: newVal }, { onConflict: 'service,action' })
      if (error) { permMap.value[svc][action] = current; alert('Erreur : ' + error.message) }
    }

    // Toggle all permissions for a service row
    var toggleServiceRow = async function(svc) {
      var allowed = countAllowed(svc.id)
      var newVal = allowed === 0
      var rows = allPerms.value.map(function(p) { return { service: svc.id, action: p.key, allowed: newVal } })
      if (!permMap.value[svc.id]) permMap.value[svc.id] = {}
      allPerms.value.forEach(function(p) { permMap.value[svc.id][p.key] = newVal })
      var { error } = await supabase.from('permissions').upsert(rows, { onConflict: 'service,action' })
      if (error) { alert('Erreur : ' + error.message); await loadPermissions() }
    }

    // Toggle a permission column for all services
    var togglePermColumn = async function(key) {
      var totalAllowed = services.value.filter(function(s) { return isAllowed(s.id, key) }).length
      var newVal = totalAllowed === 0
      var rows = services.value.map(function(s) { return { service: s.id, action: key, allowed: newVal } })
      services.value.forEach(function(s) {
        if (!permMap.value[s.id]) permMap.value[s.id] = {}
        permMap.value[s.id][key] = newVal
      })
      var { error } = await supabase.from('permissions').upsert(rows, { onConflict: 'service,action' })
      if (error) { alert('Erreur : ' + error.message); await loadPermissions() }
    }

    // Toggle all permissions in a group for all services
    var toggleGroup = async function(g) {
      var total = 0
      services.value.forEach(function(s) {
        g.actions.forEach(function(a) { if (isAllowed(s.id, a.key)) total++ })
      })
      var newVal = total === 0
      var rows = []
      services.value.forEach(function(s) {
        if (!permMap.value[s.id]) permMap.value[s.id] = {}
        g.actions.forEach(function(a) {
          permMap.value[s.id][a.key] = newVal
          rows.push({ service: s.id, action: a.key, allowed: newVal })
        })
      })
      var { error } = await supabase.from('permissions').upsert(rows, { onConflict: 'service,action' })
      if (error) { alert('Erreur : ' + error.message); await loadPermissions() }
    }

    var loadPermissions = async function() {
      var res = await supabase.from('permissions').select('service, action, allowed')
      var map = {}
      if (res.data) {
        res.data.forEach(function(p) {
          if (!map[p.service]) map[p.service] = {}
          map[p.service][p.action] = p.allowed
        })
      }
      permMap.value = map
    }

    var loadServices = async function() {
      var res = await supabase.from('services').select('id, label, sort_order').order('sort_order')
      services.value = res.data || []
    }

    // --- Service CRUD ---
    var startEditSvc = function(svc) {
      editSvc.value = { id: svc.id, label: svc.label }
    }

    var saveEditSvc = async function() {
      if (!editSvc.value || !editSvc.value.label.trim()) return
      mgrErr.value = ''
      var { error } = await supabase.from('services').update({ label: editSvc.value.label.trim() }).eq('id', editSvc.value.id)
      if (error) { mgrErr.value = error.message; return }
      var svc = services.value.find(function(s) { return s.id === editSvc.value.id })
      if (svc) svc.label = editSvc.value.label.trim()
      editSvc.value = null
    }

    var deleteSvc = async function(svc) {
      if (!confirm('Supprimer le service "' + svc.label + '" ?\nToutes ses permissions seront supprimées.')) return
      mgrErr.value = ''
      await supabase.from('permissions').delete().eq('service', svc.id)
      var { error } = await supabase.from('services').delete().eq('id', svc.id)
      if (error) { mgrErr.value = error.message; return }
      services.value = services.value.filter(function(s) { return s.id !== svc.id })
      var newMap = Object.assign({}, permMap.value)
      delete newMap[svc.id]
      permMap.value = newMap
    }

    var addSvc = async function() {
      var id = newSvcId.value.trim().replace(/\s+/g, '_').toLowerCase()
      var label = newSvcLabel.value.trim()
      if (!id || !label) return
      mgrErr.value = ''
      var maxOrder = services.value.reduce(function(m, s) { return Math.max(m, s.sort_order || 0) }, 0)
      var { error } = await supabase.from('services').insert({ id: id, label: label, sort_order: maxOrder + 1 })
      if (error) { mgrErr.value = error.message; return }
      services.value.push({ id: id, label: label, sort_order: maxOrder + 1 })
      newSvcId.value = ''
      newSvcLabel.value = ''
    }

    onMounted(async function() {
      loading.value = true
      await Promise.all([loadServices(), loadPermissions()])
      loading.value = false
    })

    return {
      loading, services, actionGroups, allPerms,
      showMgr, editSvc, newSvcId, newSvcLabel, mgrErr,
      isAllowed, countAllowed, getGroupIndex,
      togglePerm, toggleServiceRow, togglePermColumn, toggleGroup,
      startEditSvc, saveEditSvc, deleteSvc, addSvc
    }
  }
}
</script>

<style scoped>
/* Header */
.ph { display:flex; align-items:center; justify-content:space-between; padding-bottom:10px; border-bottom:2px solid #0a0a0a; margin-bottom:16px }
.pt { font-size:11px; font-weight:500; letter-spacing:1.5px }
.ps { font-size:12px; color:#999; margin-top:3px }
.btn-mgr { font-size:12px; padding:6px 14px; border:1px solid #d0e4f8; background:#fff; color:#185FA5; border-radius:3px; cursor:pointer; font-family:inherit; white-space:nowrap }
.btn-mgr:hover { background:#f0f7ff }
.btn-mgr-on { background:#E6F1FB }

/* Services management panel */
.mgr-panel { border:1px solid #d0e4f8; border-radius:6px; padding:16px; background:#f7fbff; margin-bottom:16px }
.mgr-title { font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:1px; color:#888; margin-bottom:10px }
.mgr-list { display:flex; flex-direction:column; gap:4px; margin-bottom:12px }
.mgr-row { display:flex; align-items:center; gap:8px; padding:7px 10px; background:#fff; border:1px solid #e8e8e8; border-radius:3px }
.ms-id { font-size:11px; color:#bbb; font-family:'SF Mono',monospace; min-width:130px; flex-shrink:0 }
.ms-label { font-size:13px; font-weight:500; flex:1 }
.ms-actions { display:flex; gap:6px; margin-left:auto }
.mb { font-size:11px; padding:4px 10px; border-radius:2px; cursor:pointer; font-family:inherit; transition:.1s }
.mb.edit { border:1px solid #d0e4f8; background:#fff; color:#185FA5 }
.mb.edit:hover { background:#E6F1FB }
.mb.del { border:1px solid #f5d0d0; background:#fff; color:#E24B4A }
.mb.del:hover { background:#fff0f0 }
.mb.ok { border:1px solid #b8e8d0; background:#EAF3DE; color:#1D9E75 }
.mb.cancel { border:1px solid #e8e8e8; background:#fff; color:#999 }
.mgr-inp { font-size:12px; border:1px solid #d0d8e8; border-radius:2px; padding:5px 8px; flex:1; min-width:0; font-family:inherit; outline:none }
.mgr-inp:focus { border-color:#185FA5 }
.mgr-add { display:flex; gap:8px; align-items:center }
.btn-add { font-size:12px; padding:6px 14px; background:#185FA5; color:#fff; border:none; border-radius:2px; cursor:pointer; white-space:nowrap; font-family:inherit }
.btn-add:disabled { opacity:0.5; cursor:default }
.mgr-err { font-size:12px; color:#E24B4A; margin-top:8px }

/* Legend */
.legend { display:flex; align-items:center; gap:16px; flex-wrap:wrap; font-size:11px; color:#888; margin-bottom:10px; padding:6px 10px; background:#fafafa; border:1px solid #f0f0f0; border-radius:3px }
.leg-item { display:flex; align-items:center; gap:4px }
.cb-on { color:#1D9E75; font-weight:700; font-size:13px }
.leg-col { cursor:pointer }
.leg-row { cursor:pointer }
.leg-grp { cursor:pointer }

/* Matrix container */
.matrix-outer { overflow-x:auto; -webkit-overflow-scrolling:touch; border:1px solid #e8e8e8; border-radius:4px }
.matrix { border-collapse:collapse; table-layout:fixed }

/* Corner cell */
.corner { position:sticky; left:0; z-index:3; background:#f4f7fc; width:170px; min-width:170px; font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:0.8px; color:#888; text-align:left; padding:8px 10px; border:1px solid #d8e4f0 }

/* Group header row */
.grp-hd { background:#f0f5fb; padding:4px 8px; text-align:center; border:1px solid #d0dff0; white-space:nowrap }
.grp-hd-inner { display:flex; align-items:center; justify-content:center; gap:6px }
.grp-hd-label { font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:0.5px; color:#185FA5; white-space:nowrap }
.grp-tog { font-size:14px; padding:0 3px; border:none; background:none; cursor:pointer; color:#185FA5; opacity:0.6; line-height:1 }
.grp-tog:hover { opacity:1 }

/* Permission header cells (rotated) */
.perm-hd { width:26px; min-width:26px; max-width:26px; height:140px; vertical-align:bottom; padding:0; cursor:pointer; border:1px solid #e8e8e8 }
.perm-hd:hover { background:#f0f5fb }
.perm-hd-inner { writing-mode:vertical-rl; transform:rotate(180deg); font-size:10px; color:#555; white-space:nowrap; padding:6px 7px 10px; font-weight:400; line-height:1 }

/* Service name (sticky left column) */
.svc-cell { position:sticky; left:0; z-index:1; background:#fff; width:170px; min-width:170px; padding:0 10px; cursor:pointer; border:1px solid #e8e8e8; border-right:2px solid #d0dff0 }
.svc-cell:hover { background:#f0f7ff }
.svc-inner { display:flex; align-items:center; justify-content:space-between; gap:8px }
.svc-name { font-size:12px; font-weight:600; color:#111; white-space:nowrap; overflow:hidden; text-overflow:ellipsis }
.svc-count { font-size:10px; color:#bbb; font-family:'SF Mono',monospace; flex-shrink:0 }

/* Checkbox cells */
.cb-cell { width:26px; min-width:26px; max-width:26px; text-align:center; padding:0; cursor:pointer; border:1px solid #ebebeb; transition:background .1s }
.cb-cell:hover { background:#e6f1fb !important }
.cb-on { color:#1D9E75; font-size:13px; font-weight:700 }
.cb-off { color:transparent; font-size:13px }

/* Alternating group shading */
.grp-0 { background:#fff }
.grp-1 { background:#fafbfd }
tbody tr:hover .cb-cell { background:#f7faff }
tbody tr:hover .svc-cell { background:#f0f7ff }
tbody tr { height:36px }

/* Loading */
.em { text-align:center; padding:40px; color:#999; font-size:13px }

/* Responsive */
@media (max-width:768px) {
  .corner { width:120px; min-width:120px }
  .svc-cell { width:120px; min-width:120px }
  .svc-name { font-size:11px }
  .legend { gap:10px; font-size:10px }
  .mgr-add { flex-direction:column }
  .mgr-add .btn-add { width:100% }
}
</style>
