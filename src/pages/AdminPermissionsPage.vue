<template>
  <div class="permissions-page">

    <!-- ── En-tête ── -->
    <div class="fa-header">
      <div>
        <div class="fa-title">🔐 Permissions par service</div>
        <div class="fa-sub" v-if="!loading">{{services.length}} services · {{allPerms.length}} permissions</div>
        <div class="fa-sub" v-else>Chargement…</div>
      </div>
      <div class="fa-actions">
        <button class="btn-mgr" :class="{'btn-mgr-on': showMgr}" @click="showMgr=!showMgr">
          {{showMgr ? '✕ Fermer' : '⚙ Gérer les services'}}
        </button>
      </div>
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
        <span class="leg-item"><span class="cb-on-eg">✓</span> Autorisé</span>
        <span class="leg-sep">·</span>
        <span class="leg-item">Clic <strong>en-tête service</strong> = toggle toute la colonne</span>
        <span class="leg-sep">·</span>
        <span class="leg-item">Clic <strong>nom permission</strong> = toggle pour tous les services</span>
        <span class="leg-sep">·</span>
        <span class="leg-item">Clic <strong>⊡ dans groupe</strong> = toggle ce groupe pour ce service</span>
      </div>

      <!-- Matrix: permissions as rows, services as columns -->
      <div class="matrix-outer">
        <table class="matrix">
          <thead>
            <tr>
              <th class="corner">Permission</th>
              <th
                v-for="svc in services"
                :key="svc.id"
                class="svc-hd"
                @click="toggleServiceCol(svc)"
                :title="'Toggle toutes les permissions pour ' + svc.label"
              >
                <div class="svc-hd-name">{{svc.label}}</div>
                <div class="svc-hd-count">{{countAllowed(svc.id)}}/{{allPerms.length}}</div>
                <button class="svc-reset-btn" @click.stop="resetService(svc)" title="Réinitialiser aux permissions par défaut">↺ Réinit.</button>
              </th>
            </tr>
          </thead>
          <tbody>
            <template v-for="g in actionGroups" :key="g.label">
              <!-- Group header row: label + one toggle button per service -->
              <tr class="grp-row">
                <td class="grp-hd-label-cell">{{g.label}}</td>
                <td
                  v-for="svc in services"
                  :key="svc.id"
                  class="grp-svc-cell"
                  :title="'Tout basculer «' + g.label + '» pour ' + svc.label"
                >
                  <button class="grp-svc-tog" @click.stop="toggleGroupForService(g, svc)">⊡</button>
                </td>
              </tr>
              <!-- Permission rows -->
              <tr v-for="p in g.actions" :key="p.key" class="perm-row">
                <td class="perm-cell" @click="togglePermRow(p.key)" :title="'Toggle «' + p.label + '» pour tous les services'">
                  <div class="perm-name">{{p.label}}</div>
                  <div class="perm-key">{{p.key}}</div>
                </td>
                <td
                  v-for="svc in services"
                  :key="svc.id"
                  class="cb-cell"
                  @click="togglePerm(svc.id, p.key)"
                >
                  <span :class="isAllowed(svc.id, p.key) ? 'cb-on' : 'cb-off'">{{isAllowed(svc.id, p.key) ? '✓' : ''}}</span>
                </td>
              </tr>
            </template>
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
          { key: 'accuser_reception_of', label: 'Accuser réception OF' },
          { key: 'accuser_reception_oc', label: 'Accuser réception OC' },
        ]
      },
      {
        label: 'Documents',
        actions: [
          { key: 'emettre_if', label: 'Émettre IF' },
          { key: 'emettre_ic', label: 'Émettre IC' },
          { key: 'emettre_da_pc', label: 'Émettre DA Physico-chimie' },
          { key: 'emettre_da_micro', label: 'Émettre DA Microbiologie' },
          { key: 'emettre_rvp', label: 'Émettre RVP' },
          { key: 'verifier_if', label: 'Vérifier IF (AQ)' },
          { key: 'verifier_ic', label: 'Vérifier IC (AQ)' },
          { key: 'verifier_da_pc', label: 'Vérifier DA Physico-chimie (AQ)' },
          { key: 'verifier_da_micro', label: 'Vérifier DA Microbiologie (AQ)' },
          { key: 'verifier_rvp', label: 'Vérifier RVP (AQ)' },
          { key: 'retourner_document', label: 'Retourner un document' },
          { key: 'rectifier_document', label: 'Rectifier un document' },
          { key: 'approuver_if', label: 'Approuver IF (DT)' },
          { key: 'approuver_ic', label: 'Approuver IC (DT)' },
          { key: 'approuver_da_pc', label: 'Approuver DA Physico-chimie (DT)' },
          { key: 'approuver_da_micro', label: 'Approuver DA Microbiologie (DT)' },
          { key: 'approuver_rvp', label: 'Approuver RVP (DT)' },
          { key: 'liberer_lot', label: 'Libérer le lot' },
        ]
      },
      {
        label: 'AQL',
        actions: [
          { key: 'demander_aql_fab', label: 'Demander AQL Fabrication' },
          { key: 'demander_aql_cond', label: 'Demander AQL Conditionnement' },
          { key: 'realiser_aql', label: 'Réaliser AQL' },
        ]
      },
      {
        label: 'MàJ Documents',
        actions: [
          { key: 'emettre_maj_if', label: 'Émettre MàJ IF (Fabrication)' },
          { key: 'emettre_maj_ic', label: 'Émettre MàJ IC (Conditionnement)' },
          { key: 'emettre_maj_nmcl_of', label: 'Émettre MàJ Nmcl OF (Planification)' },
          { key: 'emettre_maj_nmcl_oc', label: 'Émettre MàJ Nmcl OC (Planification)' },
          { key: 'verifier_maj_doc', label: 'Vérifier une MàJ documentaire (AQ)' },
          { key: 'approuver_maj_doc', label: 'Approuver une MàJ documentaire (DT)' },
        ]
      },
      {
        label: 'Clôture SAP — OF',
        actions: [
          { key: 'emettre_cloture_sap_of', label: 'Émettre demande clôture SAP OF' },
          { key: 'valider_cloture_sap_of', label: 'Valider clôture SAP OF (Planification)' },
          { key: 'demander_cloture_sap_of', label: 'Demander clôture SAP OF (Fabrication)' },
          { key: 'confirmer_cloture_sap_of', label: 'Confirmer clôture SAP OF (Planification)' },
        ]
      },
      {
        label: 'Clôture SAP — OC',
        actions: [
          { key: 'emettre_cloture_sap_oc', label: 'Émettre demande clôture SAP OC' },
          { key: 'valider_cloture_sap_oc', label: 'Valider clôture SAP OC (Planification)' },
          { key: 'demander_cloture_sap_oc', label: 'Demander clôture SAP OC (Conditionnement)' },
          { key: 'confirmer_cloture_sap_oc', label: 'Confirmer clôture SAP OC (Planification)' },
        ]
      },
      {
        label: 'Dates prévisionnelles',
        actions: [
          { key: 'modifier_planning', label: 'Modifier les dates prévisionnelles' },
        ]
      },
      {
        label: 'Déviations',
        actions: [
          { key: 'declarer_nc', label: 'Déclarer une non-conformité' },
          { key: 'cloturer_deviation', label: 'Clôturer une déviation' },
          { key: 'dev_bloquer', label: 'Bloquer un lot (déviation bloquante)' },
        ]
      },
      {
        label: 'Module Production / TRS',
        actions: [
          { key: 'trs_demarrer', label: 'Démarrer une session / un suivi de production' },
          { key: 'trs_comptage', label: 'Saisir un comptage (boîtes produites)' },
          { key: 'trs_arret', label: 'Déclarer un arrêt' },
          { key: 'trs_cloturer', label: 'Clôturer une session / un suivi' },
          { key: 'trs_supprimer_suivi', label: 'Supprimer un suivi de production' },
        ]
      },
      {
        label: 'Accusés de réception',
        actions: [
          { key: 'accuser_reception_circuit', label: 'AR circuit OF/OC (étapes intermédiaires)' },
          { key: 'accuser_reception_document', label: 'AR document (IF, IC, DA, RVP)' },
          { key: 'accuser_reception_aql_demande', label: 'AR demande AQL (AQ / LCQ)' },
          { key: 'accuser_reception_aql_resultat', label: 'AR résultat AQL (Fab. / Cond.)' },
        ]
      },
      {
        label: 'Administration',
        actions: [
          { key: 'modifier_lot', label: 'Modifier un lot' },
          { key: 'supprimer_lot', label: 'Supprimer un lot' },
        ]
      },
      {
        label: 'Tableau de bord',
        actions: [
          { key: 'voir_dashboard', label: 'Voir le dashboard' },
          { key: 'voir_lots', label: 'Voir les lots' },
          { key: 'voir_timeline', label: 'Voir la timeline' },
          { key: 'voir_kpi', label: 'Voir les KPI' },
        ]
      },
      {
        label: 'Risques péremption',
        actions: [
          { key: 'evaluer_risque_peremption', label: 'Évaluer le risque de péremption d\'un produit' },
          { key: 'configurer_risque_peremption', label: 'Configurer pondérations & seuils' },
        ]
      },
    ]

    var allPerms = computed(function() {
      var result = []
      actionGroups.forEach(function(g) { g.actions.forEach(function(a) { result.push(a) }) })
      return result
    })

    var isAllowed = function(svc, action) {
      return !!(permMap.value[svc] && permMap.value[svc][action])
    }

    var countAllowed = function(svcId) {
      if (!permMap.value[svcId]) return 0
      return Object.values(permMap.value[svcId]).filter(Boolean).length
    }

    // Single cell toggle
    var togglePerm = async function(svc, action) {
      var current = isAllowed(svc, action)
      var newVal = !current
      if (!permMap.value[svc]) permMap.value[svc] = {}
      permMap.value[svc][action] = newVal
      var { error } = await supabase.from('permissions')
        .upsert({ service: svc, action: action, allowed: newVal }, { onConflict: 'service,action' })
      if (error) { permMap.value[svc][action] = current; alert('Erreur : ' + error.message) }
    }

    // Toggle all permissions for a service column
    var toggleServiceCol = async function(svc) {
      var allowed = countAllowed(svc.id)
      var newVal = allowed === 0
      var rows = allPerms.value.map(function(p) { return { service: svc.id, action: p.key, allowed: newVal } })
      if (!permMap.value[svc.id]) permMap.value[svc.id] = {}
      allPerms.value.forEach(function(p) { permMap.value[svc.id][p.key] = newVal })
      var { error } = await supabase.from('permissions').upsert(rows, { onConflict: 'service,action' })
      if (error) { alert('Erreur : ' + error.message); await loadPermissions() }
    }

    // Toggle a permission row for all services
    var togglePermRow = async function(key) {
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

    // Toggle all permissions in a group for a specific service
    var toggleGroupForService = async function(g, svc) {
      var totalAllowed = g.actions.filter(function(a) { return isAllowed(svc.id, a.key) }).length
      var newVal = totalAllowed === 0
      if (!permMap.value[svc.id]) permMap.value[svc.id] = {}
      g.actions.forEach(function(a) { permMap.value[svc.id][a.key] = newVal })
      var rows = g.actions.map(function(a) { return { service: svc.id, action: a.key, allowed: newVal } })
      var { error } = await supabase.from('permissions').upsert(rows, { onConflict: 'service,action' })
      if (error) { alert('Erreur : ' + error.message); await loadPermissions() }
    }

    // Permissions par défaut par service
    var defaultPermissions = {
      planification: [
        'valider_quantites_of','valider_quantites_oc',
        'accuser_reception_of','accuser_reception_oc',
        'valider_cloture_sap_of','confirmer_cloture_sap_of',
        'valider_cloture_sap_oc','confirmer_cloture_sap_oc',
        'emettre_maj_nmcl_of','emettre_maj_nmcl_oc',
        'modifier_planning',
        'trs_demarrer','trs_arret','trs_cloturer','trs_supprimer_suivi',
        'voir_lots','voir_dashboard','voir_timeline','voir_kpi'
      ],
      stock: [
        'voir_lots','voir_dashboard'
      ],
      aq: [
        'creer_lot','mettre_en_circuit_of','mettre_en_circuit_oc',
        'valider_of','valider_oc',
        'verifier_if','verifier_ic','verifier_da_pc','verifier_da_micro','verifier_rvp',
        'retourner_document','rectifier_document',
        'liberer_lot',
        'demander_aql_fab','demander_aql_cond',
        'verifier_maj_doc',
        'declarer_nc','cloturer_deviation','dev_bloquer',
        'accuser_reception_circuit','accuser_reception_document','accuser_reception_aql_demande',
        'modifier_lot',
        'voir_lots','voir_dashboard','voir_timeline','voir_kpi'
      ],
      aq_dap: [
        'remettre_ordre_production',
        'accuser_reception_circuit',
        'voir_lots','voir_dashboard'
      ],
      dt: [
        'autoriser_lancement',
        'approuver_if','approuver_ic','approuver_da_pc','approuver_da_micro','approuver_rvp',
        'approuver_maj_doc',
        'voir_lots','voir_dashboard','voir_timeline','voir_kpi'
      ],
      fabrication: [
        'mettre_en_circuit_of',
        'emettre_if','emettre_maj_if',
        'emettre_cloture_sap_of','demander_cloture_sap_of',
        'trs_demarrer','trs_comptage','trs_arret','trs_cloturer',
        'accuser_reception_circuit','accuser_reception_aql_resultat',
        'dev_bloquer',
        'voir_lots','voir_dashboard'
      ],
      conditionnement: [
        'mettre_en_circuit_oc',
        'emettre_ic','emettre_maj_ic',
        'emettre_cloture_sap_oc','demander_cloture_sap_oc',
        'trs_demarrer','trs_comptage','trs_arret','trs_cloturer',
        'accuser_reception_circuit','accuser_reception_aql_resultat',
        'voir_lots','voir_dashboard'
      ],
      lcq: [
        'realiser_aql',
        'modifier_planning',
        'accuser_reception_aql_demande',
        'voir_lots','voir_dashboard','voir_timeline','voir_kpi'
      ],
      admin: null // null = toutes les permissions
    }

    var resetService = async function(svc) {
      if (!confirm('Réinitialiser les permissions de "' + svc.label + '" aux valeurs par défaut ?')) return
      var defaults = defaultPermissions[svc.id]
      var defaultSet = defaults === null
        ? new Set(allPerms.value.map(function(p) { return p.key }))
        : new Set(defaults || [])
      var rows = allPerms.value.map(function(p) {
        return { service: svc.id, action: p.key, allowed: defaultSet.has(p.key) }
      })
      if (!permMap.value[svc.id]) permMap.value[svc.id] = {}
      allPerms.value.forEach(function(p) { permMap.value[svc.id][p.key] = defaultSet.has(p.key) })
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
      isAllowed, countAllowed,
      togglePerm, toggleServiceCol, togglePermRow, toggleGroupForService, resetService,
      startEditSvc, saveEditSvc, deleteSvc, addSvc
    }
  }
}
</script>

<style scoped>
.permissions-page { font-family:'Inter',sans-serif; font-size:13px; }
.fa-actions { display:flex; align-items:center; gap:8px; flex-shrink:0; }

/* Services management button */
.btn-mgr { font-size:12px; padding:6px 14px; border:1px solid #ede9fe; background:#fff; color:#7c3aed; border-radius:5px; cursor:pointer; font-family:'Inter',sans-serif; white-space:nowrap }
.btn-mgr:hover { background:#f5f3ff }
.btn-mgr-on { background:#f5f3ff; border-color:#7c3aed }

/* Services management panel */
.mgr-panel { border:1px solid #ede9fe; border-radius:8px; padding:16px; background:#faf5ff; margin-bottom:16px }
.mgr-title { font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:1px; color:#6b7280; margin-bottom:10px }
.mgr-list { display:flex; flex-direction:column; gap:4px; margin-bottom:12px }
.mgr-row { display:flex; align-items:center; gap:8px; padding:7px 10px; background:#fff; border:1px solid #e5e7eb; border-radius:5px }
.ms-id { font-size:11px; color:#9ca3af; font-family:'SF Mono',monospace; min-width:130px; flex-shrink:0 }
.ms-label { font-size:13px; font-weight:500; flex:1; color:#374151 }
.ms-actions { display:flex; gap:6px; margin-left:auto }
.mb { font-size:11px; padding:4px 10px; border-radius:4px; cursor:pointer; font-family:'Inter',sans-serif; transition:.1s }
.mb.edit { border:1px solid #ede9fe; background:#fff; color:#7c3aed }
.mb.edit:hover { background:#f5f3ff }
.mb.del { border:1px solid #fecaca; background:#fff; color:#ef4444 }
.mb.del:hover { background:#fef2f2 }
.mb.ok { border:1px solid #bbf7d0; background:#f0fdf4; color:#059669 }
.mb.cancel { border:1px solid #e5e7eb; background:#fff; color:#9ca3af }
.mgr-inp { font-size:12px; border:1px solid #e5e7eb; border-radius:5px; padding:6px 10px; flex:1; min-width:0; font-family:'Inter',sans-serif; outline:none }
.mgr-inp:focus { border-color:#7c3aed }
.mgr-add { display:flex; gap:8px; align-items:center }
.btn-add { font-size:12px; padding:7px 14px; background:#7c3aed; color:#fff; border:none; border-radius:5px; cursor:pointer; white-space:nowrap; font-family:'Inter',sans-serif }
.btn-add:hover { background:#6d28d9 }
.btn-add:disabled { opacity:0.5; cursor:default }
.mgr-err { font-size:12px; color:#ef4444; margin-top:8px }

/* Legend */
.legend { display:flex; align-items:center; gap:10px; flex-wrap:wrap; font-size:11px; color:#6b7280; margin-bottom:10px; padding:6px 12px; background:#f9fafb; border:1px solid #e5e7eb; border-radius:6px }
.cb-on-eg { color:#059669; font-weight:700; font-size:13px }
.leg-sep { color:#d1d5db }

/* Matrix container */
.matrix-outer { overflow-x:auto; overflow-y:auto; max-height:calc(100vh - 220px); -webkit-overflow-scrolling:touch; border:1px solid #e5e7eb; border-radius:8px }
.matrix { border-collapse:collapse; table-layout:fixed; min-width:100% }

/* Sticky top-left corner */
.corner {
  position:sticky; top:0; left:0; z-index:4;
  background:#f5f3ff;
  width:220px; min-width:220px;
  font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:0.8px; color:#7c3aed;
  text-align:left; padding:10px 12px;
  border-bottom:1px solid #ede9fe; border-right:2px solid #ede9fe
}

/* Service column headers (sticky top) */
.svc-hd {
  position:sticky; top:0; z-index:2;
  background:#f5f3ff;
  min-width:90px; width:90px;
  text-align:center; padding:8px 6px;
  cursor:pointer;
  border-bottom:1px solid #ede9fe; border-right:1px solid #ede9fe;
  transition:background .1s
}
.svc-hd:hover { background:#ede9fe }
.svc-hd-name { font-size:11px; font-weight:700; color:#7c3aed; line-height:1.3 }
.svc-hd-count { font-size:10px; color:#9ca3af; font-family:'SF Mono',monospace; margin-top:2px }
.svc-reset-btn { display:block; margin:5px auto 0; font-size:10px; padding:2px 7px; border:1px solid #ede9fe; background:#fff; color:#7c3aed; border-radius:4px; cursor:pointer; font-family:'Inter',sans-serif; white-space:nowrap; opacity:0.7; transition:.1s }
.svc-reset-btn:hover { opacity:1; background:#f5f3ff }

/* Group header rows */
.grp-row .grp-hd-label-cell {
  position:sticky; left:0; z-index:1;
  background:#f5f3ff;
  padding:6px 12px;
  border-top:1px solid #ede9fe; border-bottom:1px solid #ede9fe;
  font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:1px; color:#7c3aed;
  white-space:nowrap
}
.grp-row .grp-svc-cell {
  background:#f5f3ff;
  text-align:center; padding:4px 2px;
  border-top:1px solid #ede9fe; border-bottom:1px solid #ede9fe; border-right:1px solid #ede9fe
}
.grp-svc-tog {
  font-size:13px; padding:1px 4px; border:1px solid #ede9fe; background:#fff;
  color:#7c3aed; border-radius:4px; cursor:pointer; line-height:1; opacity:0.75; transition:.1s
}
.grp-svc-tog:hover { opacity:1; background:#f5f3ff }

/* Permission name (sticky left) */
.perm-cell {
  position:sticky; left:0; z-index:1;
  background:#fff;
  width:220px; min-width:220px;
  padding:7px 12px;
  cursor:pointer;
  border-bottom:1px solid #f3f4f6; border-right:2px solid #ede9fe
}
.perm-cell:hover { background:#faf5ff }
.perm-name { font-size:12px; color:#111827; line-height:1.3 }
.perm-key { font-size:10px; color:#d1d5db; font-family:'SF Mono',monospace; margin-top:1px }

/* Checkbox cells */
.cb-cell {
  text-align:center; padding:0;
  cursor:pointer;
  border-bottom:1px solid #f3f4f6; border-right:1px solid #f3f4f6;
  transition:background .1s
}
.cb-cell:hover { background:#ede9fe }
.cb-on { color:#059669; font-size:15px; font-weight:700 }
.cb-off { color:transparent; font-size:15px }

/* Alternating permission rows */
.perm-row:nth-child(even) .cb-cell { background:#fafbfd }
.perm-row:nth-child(even) .cb-cell:hover { background:#ede9fe }
.perm-row:nth-child(even) .perm-cell { background:#fafbfd }
.perm-row:nth-child(even) .perm-cell:hover { background:#faf5ff }
.perm-row { height:36px }

/* Loading */
.em { text-align:center; padding:40px; color:#999; font-size:13px }

/* Responsive */
@media (max-width:768px) {
  .corner { width:150px; min-width:150px }
  .perm-cell { width:150px; min-width:150px }
  .svc-hd { min-width:70px; width:70px }
  .svc-hd-name { font-size:10px }
  .perm-name { font-size:11px }
  .legend { font-size:10px; gap:6px }
  .mgr-add { flex-direction:column }
  .mgr-add .btn-add { width:100% }
}
</style>
