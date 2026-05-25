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
        <span class="leg-item"><span class="cb-on-eg">✓</span> Autorisé</span>
        <span class="leg-sep">·</span>
        <span class="leg-item">Clic <strong>en-tête service</strong> = toggle toute la colonne</span>
        <span class="leg-sep">·</span>
        <span class="leg-item">Clic <strong>nom permission</strong> = toggle pour tous les services</span>
        <span class="leg-sep">·</span>
        <span class="leg-item">Clic <strong>⊡ groupe</strong> = toggle tout le groupe</span>
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
              <!-- Group header row -->
              <tr class="grp-row">
                <td :colspan="services.length + 1" class="grp-hd">
                  <div class="grp-hd-inner">
                    <span class="grp-hd-label">{{g.label}}</span>
                    <button class="grp-tog" @click.stop="toggleGroup(g)" title="Tout basculer pour ce groupe (tous services)">⊡ Tout basculer</button>
                  </div>
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
          { key: 'transferer_dossier_dt', label: 'Transférer le dossier au DT' },
          { key: 'liberer_lot', label: 'Libérer le lot' },
          { key: 'doc_delete', label: 'Supprimer un document' },
        ]
      },
      {
        label: 'AQL',
        actions: [
          { key: 'demander_aql_fab', label: 'Demander AQL Fabrication' },
          { key: 'demander_aql_cond', label: 'Demander AQL Conditionnement' },
          { key: 'realiser_aql', label: 'Réaliser AQL' },
          { key: 'aql_delete', label: 'Supprimer un AQL' },
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
          { key: 'dev_delete', label: 'Supprimer une déviation' },
        ]
      },
      {
        label: 'Fabrication / LCQ',
        actions: [
          { key: 'declarer_etape_fab', label: 'Déclarer une étape de fabrication' },
          { key: 'declarer_fin_sf', label: 'Déclarer fin semi-fini' },
          { key: 'declarer_fin_pf', label: 'Déclarer fin produit fini' },
          { key: 'realiser_analyse_pc', label: 'Réaliser analyse physico-chimie' },
          { key: 'realiser_analyse_micro', label: 'Réaliser analyse microbiologie' },
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
          { key: 'lot_edit_statut_sap', label: 'Modifier le statut SAP' },
          { key: 'lot_edit_quarantaine', label: 'Mettre en quarantaine' },
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

    // Permissions par défaut par service
    var defaultPermissions = {
      planification: [
        'valider_quantites_of','valider_quantites_oc',
        'accuser_reception_of','accuser_reception_oc',
        'valider_cloture_sap_of','confirmer_cloture_sap_of',
        'valider_cloture_sap_oc','confirmer_cloture_sap_oc',
        'emettre_maj_nmcl_of','emettre_maj_nmcl_oc',
        'modifier_planning',
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
        'modifier_lot','lot_edit_statut_sap','lot_edit_quarantaine',
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
        'transferer_dossier_dt',
        'approuver_maj_doc',
        'voir_lots','voir_dashboard','voir_timeline','voir_kpi'
      ],
      fabrication: [
        'mettre_en_circuit_of',
        'emettre_if','emettre_maj_if',
        'emettre_cloture_sap_of','demander_cloture_sap_of',
        'declarer_etape_fab','declarer_fin_sf','declarer_fin_pf',
        'accuser_reception_circuit','accuser_reception_aql_resultat',
        'dev_bloquer',
        'voir_lots','voir_dashboard'
      ],
      conditionnement: [
        'mettre_en_circuit_oc',
        'emettre_ic','emettre_maj_ic',
        'emettre_cloture_sap_oc','demander_cloture_sap_oc',
        'accuser_reception_circuit','accuser_reception_aql_resultat',
        'voir_lots','voir_dashboard'
      ],
      lcq: [
        'realiser_aql',
        'realiser_analyse_pc','realiser_analyse_micro',
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
      togglePerm, toggleServiceCol, togglePermRow, toggleGroup, resetService,
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
.legend { display:flex; align-items:center; gap:10px; flex-wrap:wrap; font-size:11px; color:#888; margin-bottom:10px; padding:6px 10px; background:#fafafa; border:1px solid #f0f0f0; border-radius:3px }
.cb-on-eg { color:#1D9E75; font-weight:700; font-size:13px }
.leg-sep { color:#ddd }

/* Matrix container */
.matrix-outer { overflow-x:auto; -webkit-overflow-scrolling:touch; border:1px solid #e0e0e0; border-radius:4px }
.matrix { border-collapse:collapse; table-layout:fixed; min-width:100% }

/* Sticky top-left corner */
.corner {
  position:sticky; top:0; left:0; z-index:4;
  background:#f4f7fc;
  width:220px; min-width:220px;
  font-size:10px; font-weight:600; text-transform:uppercase; letter-spacing:0.8px; color:#888;
  text-align:left; padding:10px 12px;
  border-bottom:2px solid #d0dff0; border-right:2px solid #d0dff0
}

/* Service column headers (sticky top) */
.svc-hd {
  position:sticky; top:0; z-index:2;
  background:#f0f5fb;
  min-width:90px; width:90px;
  text-align:center; padding:8px 6px;
  cursor:pointer;
  border-bottom:2px solid #d0dff0; border-right:1px solid #dde8f4;
  transition:background .1s
}
.svc-hd:hover { background:#e0eefb }
.svc-hd-name { font-size:11px; font-weight:600; color:#185FA5; line-height:1.3 }
.svc-hd-count { font-size:10px; color:#aaa; font-family:'SF Mono',monospace; margin-top:2px }
.svc-reset-btn { display:block; margin:5px auto 0; font-size:10px; padding:2px 7px; border:1px solid #c0d8f0; background:#fff; color:#185FA5; border-radius:2px; cursor:pointer; font-family:inherit; white-space:nowrap; opacity:0.7; transition:.1s }
.svc-reset-btn:hover { opacity:1; background:#E6F1FB }

/* Group header rows */
.grp-row .grp-hd {
  background:#f4f7fc;
  padding:7px 12px;
  border-top:2px solid #d0dff0; border-bottom:1px solid #d8e4f0
}
.grp-hd-inner { display:flex; align-items:center; justify-content:space-between }
.grp-hd-label { font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:1px; color:#185FA5 }
.grp-tog { font-size:11px; padding:2px 10px; border:1px solid #c0d8f0; background:#fff; color:#185FA5; border-radius:2px; cursor:pointer; font-family:inherit }
.grp-tog:hover { background:#E6F1FB }

/* Permission name (sticky left) */
.perm-cell {
  position:sticky; left:0; z-index:1;
  background:#fff;
  width:220px; min-width:220px;
  padding:7px 12px;
  cursor:pointer;
  border-bottom:1px solid #f0f0f0; border-right:2px solid #e8eef6
}
.perm-cell:hover { background:#f7fbff }
.perm-name { font-size:12px; color:#222; line-height:1.3 }
.perm-key { font-size:10px; color:#ccc; font-family:'SF Mono',monospace; margin-top:1px }

/* Checkbox cells */
.cb-cell {
  text-align:center; padding:0;
  cursor:pointer;
  border-bottom:1px solid #f0f0f0; border-right:1px solid #f0f0f0;
  transition:background .1s
}
.cb-cell:hover { background:#e6f1fb }
.cb-on { color:#1D9E75; font-size:15px; font-weight:700 }
.cb-off { color:transparent; font-size:15px }

/* Alternating permission rows */
.perm-row:nth-child(even) .cb-cell { background:#fafbfd }
.perm-row:nth-child(even) .cb-cell:hover { background:#e6f1fb }
.perm-row:nth-child(even) .perm-cell { background:#fafbfd }
.perm-row:nth-child(even) .perm-cell:hover { background:#f0f7ff }
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
