<template>
  <div>
    <div class="ph">
      <div>
        <div class="pt">Permissions par service</div>
        <div class="ps">Cliquez sur une permission pour l'activer ou la désactiver</div>
      </div>
    </div>

    <div v-if="loading" class="em">Chargement...</div>
    <div v-else>
      <!-- Onglets services -->
      <div class="tabs">
        <button v-for="svc in services" :key="svc"
          class="tab" :class="{'tab-on': selectedSvc === svc}"
          @click="selectedSvc = svc">
          {{ serviceLabels[svc] }}
        </button>
      </div>

      <!-- Groupes d'actions pour le service sélectionné -->
      <div class="pane" v-if="selectedSvc">
        <div class="group" v-for="g in actionGroups" :key="g.label">
          <div class="gl">{{ g.label }}</div>
          <div class="glist">
            <div class="arow" v-for="a in g.actions" :key="a.key">
              <div class="aleft">
                <div class="aname">{{ a.label }}</div>
                <div class="akey">{{ a.key }}</div>
              </div>
              <button class="tog" :class="isAllowed(selectedSvc, a.key) ? 'ton' : 'toff'"
                @click="togglePerm(selectedSvc, a.key)">
                {{ isAllowed(selectedSvc, a.key) ? 'Autorisé' : 'Refusé' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import { ref, onMounted } from 'vue'
import { supabase } from '../supabase'
export default {
  setup() {
    var loading = ref(true)
    var selectedSvc = ref('planification')
    // permMap[service][action] = true | false
    var permMap = ref({})

    var services = ['planification', 'stock', 'aq', 'aq_dap', 'dt', 'fabrication', 'conditionnement', 'lcq', 'admin']
    var serviceLabels = { planification: 'Planification', stock: 'Stock', aq: 'AQ', aq_dap: 'AQ DAP', dt: 'DT', fabrication: 'Fabrication', conditionnement: 'Conditionnement', lcq: 'LCQ', admin: 'Admin' }

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
          { key: 'remettre_ordre_production', label: 'Remettre à production (AQ DAP)' },
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
          { key: 'emettre_cloture_sap_of', label: 'Émettre demande clôture SAP OF (Fabrication)' },
          { key: 'valider_cloture_sap_of', label: 'Valider clôture SAP OF (Planification)' },
          { key: 'demander_cloture_sap_of', label: 'Demander clôture SAP OF (Fabrication)' },
          { key: 'confirmer_cloture_sap_of', label: 'Confirmer clôture SAP OF (Planification)' },
        ]
      },
      {
        label: 'Clôture SAP — OC',
        actions: [
          { key: 'emettre_cloture_sap_oc', label: 'Émettre demande clôture SAP OC (Conditionnement)' },
          { key: 'valider_cloture_sap_oc', label: 'Valider clôture SAP OC (Planification)' },
          { key: 'demander_cloture_sap_oc', label: 'Demander clôture SAP OC (Conditionnement)' },
          { key: 'confirmer_cloture_sap_oc', label: 'Confirmer clôture SAP OC (Planification)' },
        ]
      },
      {
        label: 'Déviations',
        actions: [
          { key: 'declarer_nc', label: 'Déclarer une non-conformité' },
          { key: 'cloturer_deviation', label: 'Clôturer une déviation' },
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
    ]

    var isAllowed = function(svc, action) {
      return !!(permMap.value[svc] && permMap.value[svc][action])
    }

    var togglePerm = async function(svc, action) {
      var current = isAllowed(svc, action)
      var newVal = !current
      // Mise à jour optimiste
      if (!permMap.value[svc]) permMap.value[svc] = {}
      permMap.value[svc][action] = newVal
      // Upsert en base
      var { error } = await supabase.from('permissions')
        .upsert({ service: svc, action: action, allowed: newVal }, { onConflict: 'service,action' })
      if (error) {
        // Rollback en cas d'erreur
        permMap.value[svc][action] = current
        alert('Erreur lors de la mise à jour : ' + error.message)
      }
    }

    var loadPermissions = async function() {
      loading.value = true
      var res = await supabase.from('permissions').select('service, action, allowed')
      var map = {}
      if (res.data) {
        res.data.forEach(function(p) {
          if (!map[p.service]) map[p.service] = {}
          map[p.service][p.action] = p.allowed
        })
      }
      permMap.value = map
      loading.value = false
    }

    onMounted(loadPermissions)

    return { loading, selectedSvc, services, serviceLabels, actionGroups, isAllowed, togglePerm }
  }
}
</script>
<style scoped>
.ph{margin-bottom:16px}
.pt{font-size:18px;font-weight:500}.ps{font-size:12px;color:#999;margin-top:4px}
.em{text-align:center;padding:40px;color:#999;font-size:13px}
.tabs{display:flex;gap:4px;flex-wrap:wrap;border-bottom:2px solid #e8e8e8;margin-bottom:0}
.tab{font-size:12px;padding:8px 14px;border:none;background:none;cursor:pointer;color:#999;font-weight:500;border-bottom:2px solid transparent;margin-bottom:-2px;transition:.15s}
.tab:hover{color:#185FA5}.tab-on{color:#185FA5;border-bottom-color:#185FA5}
.pane{padding-top:16px}
.group{margin-bottom:20px}
.gl{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:1px;color:#999;padding:6px 0;border-bottom:1px solid #e8e8e8;margin-bottom:4px}
.glist{border:1px solid #e8e8e8;border-top:none}
.arow{display:flex;align-items:center;justify-content:space-between;padding:9px 12px;border-bottom:1px solid #f5f5f5}
.arow:last-child{border-bottom:none}
.aleft{flex:1;min-width:0}
.aname{font-size:13px;font-weight:500}
.akey{font-size:11px;color:#bbb;font-family:'SF Mono',monospace;margin-top:1px}
.tog{font-size:11px;padding:4px 14px;border:none;border-radius:10px;cursor:pointer;font-weight:500;flex-shrink:0;margin-left:12px}
.ton{background:#EAF3DE;color:#3B6D11}.toff{background:#f5f5f5;color:#999}
@media(max-width:768px){
  .tabs{flex-wrap:nowrap;overflow-x:auto;-webkit-overflow-scrolling:touch;gap:2px;scrollbar-width:none;padding-bottom:2px}
  .tabs::-webkit-scrollbar{display:none}
  .tab{font-size:11px;padding:8px 12px;white-space:nowrap;min-height:40px;flex-shrink:0}
  .arow{padding:10px 12px;gap:8px}
  .aname{font-size:12px}
  .tog{padding:6px 14px;min-height:36px;font-size:11px}
  .akey{display:none}
}
@media(max-width:480px){
  .tab{font-size:10px;padding:8px 10px}
  .tog{padding:5px 10px;font-size:10px}
  .aname{font-size:13px}
  .group{margin-bottom:14px}
}
</style>
