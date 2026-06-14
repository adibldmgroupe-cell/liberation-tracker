<template>
  <div v-if="lot">
    <div class="bc"><span @click="goBack">← Retour aux lots</span></div>
    <div class="lh">
      <div><span class="ln">{{lot.numero_lot}}</span><span class="lp">{{prod.description}}</span></div>
      <div class="lh-right">
        <span v-if="phaseLabel" class="sp-phase" :class="getPhaseClass(phaseLabel)">{{phaseLabel}}</span>
        <span class="sp" :class="'s-'+lot.statut_sap">{{statusLabels[lot.statut_sap]}}</span>
        <button v-if="canPerform('modifier_lot')" class="btn-sm" @click="showModify=true">✏️ Modifier</button>
        <button v-if="canPerform('supprimer_lot')" class="btn-sm btn-del" @click="confirmDelete">🗑️ Supprimer</button>
      </div>
    </div>

    <!-- Modify modal -->
    <div class="modal-overlay" v-if="showModify" @click="showModify=false">
      <div class="modal" @click.stop>
        <div class="modal-title">Modifier le lot</div>
        <div class="field"><label>N° Lot</label><input v-model="editNumLot" class="input" /></div>
        <div class="field"><label>Code produit</label>
          <input v-model="editCodeProd" @input="searchProd" class="input" />
          <div class="auto-list" v-if="prodSuggestions.length">
            <div v-for="s in prodSuggestions" :key="s.id" class="auto-item" @click="selectProd(s)">
              <span class="auto-code">{{s.code_article}}</span>{{s.description}}
            </div>
          </div>
        </div>
        <div class="modal-actions">
          <button class="btn bg" @click="doModify">Enregistrer</button>
          <button class="btn bc2" @click="showModify=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- Indicateur rechargement après action -->
    <div v-if="detailLoading" class="detail-reloading">⟳ Actualisation…</div>

    <!-- KPI -->
    <div class="ks">
      <div class="k"><div class="kv">{{ofV}}/6</div><div class="kl">OF</div></div>
      <div class="k"><div class="kv">{{ocV}}/6</div><div class="kl">OC</div></div>
      <div class="k"><div class="kv" :class="{'cw':docsOk<docsReq}">{{docsOk}}/{{docsReq}}</div><div class="kl">Docs</div></div>
      <div class="k"><div class="kv" :class="{'cd':devsOpen>0}">{{devsOpen}}</div><div class="kl">Dév.</div></div>
      <div class="k"><div class="kv">{{leadTime||'—'}}<span class="ku" v-if="leadTime">j</span></div><div class="kl">Lead time</div></div>
    </div>

    <!-- Circuits de lancement (cartes harmonisées — clic → détail) -->
    <div class="section" v-if="of||oc">
      <div class="sh"><span>Circuits de lancement</span></div>
      <div class="dg">
        <div class="di" v-if="of" @click="$router.push('/lots/'+lot.id+'/circuit/of')">
          <div class="dind" :class="circuitOverallInd('of')"></div>
          <div><div class="dn">Circuit OF</div><div class="ds" :class="of.statut==='termine'?'ds-ok':''">{{circuitSummary('of')}}</div></div>
        </div>
        <div class="di" v-if="oc" @click="$router.push('/lots/'+lot.id+'/circuit/oc')">
          <div class="dind" :class="circuitOverallInd('oc')"></div>
          <div><div class="dn">Circuit OC</div><div class="ds" :class="oc.statut==='termine'?'ds-ok':''">{{circuitSummary('oc')}}</div></div>
        </div>
      </div>
    </div>

    <!-- AQL — cartes cliquables (parcours façon circuit) -->
    <div class="section"><div class="sh"><span>AQL</span></div>
      <div class="dg">
        <div class="di di-act" @click="$router.push('/lots/'+lot.id+'/aql/fabrication')">
          <div class="dind" :class="aqlInd('fabrication')"></div>
          <div><div class="dn">AQL Fabrication</div><div class="ds" :class="aqlDsClass('fabrication')">{{aqlSummary('fabrication')}}</div></div>
        </div>
        <div class="di di-act" @click="$router.push('/lots/'+lot.id+'/aql/conditionnement')">
          <div class="dind" :class="aqlInd('conditionnement')"></div>
          <div><div class="dn">AQL Conditionnement</div><div class="ds" :class="aqlDsClass('conditionnement')">{{aqlSummary('conditionnement')}}</div></div>
        </div>
      </div>
    </div>

    <!-- Documents -->
    <div class="section"><div class="sh"><span>Dossier de libération</span><span class="dc">{{docsOk}}/{{docsReq}}</span></div>
      <div class="dg">
        <div class="di" v-for="d in mainDocs" :key="d.id" :class="{'dna':!d.is_applicable&&d.type_document!=='da_micro'}" @click="$router.push('/lots/'+lot.id+'/documents/'+d.id)">
          <div class="dind" :class="indClass(d)"></div>
          <div>
            <div class="dn">{{docTypeLabel(d)}}</div>
            <div class="ds" :class="dsClass(d)">{{docStatLabel(d)}}</div>
            <div class="ds-block" v-if="isDocBlocked(d)">⚠ AQL requis</div>
            <!-- DA Micro : bouton déclarer applicable -->
            <button v-if="d.type_document==='da_micro' && !d.is_applicable && canPerform('emettre_da_micro')"
                    class="btn-app" @click.stop="doSetDaMicroApplicable(d.id)">
              ＋ Déclarer applicable
            </button>
            <span v-if="d.type_document==='da_micro' && !d.is_applicable && !canPerform('emettre_da_micro')" class="ds-na-hint">Non applicable (LCQ)</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Déviations -->
    <div class="section"><div class="sh"><span>Déviations</span></div>
      <div class="dg" v-if="canPerform('declarer_nc')">
        <div class="di di-act" @click="showDevForm=!showDevForm"><div class="dind ind-orange"></div><div><div class="dn">Déclarer une déviation</div><div class="ds">{{showDevForm?'✕ Fermer':'＋ Déclarer'}}</div></div></div>
      </div>
      <div class="dev-form" v-if="showDevForm">
        <div class="dev-form-row">
          <label class="dev-lbl">N° DN</label>
          <input type="text" v-model="devNumeroDn" placeholder="Ex: DN-2026-001" class="dev-input-sm" />
        </div>
        <div class="dev-form-row">
          <label class="dev-lbl">Observation</label>
          <textarea v-model="devObs" rows="2" placeholder="Observation (facultatif)..." class="dev-input"></textarea>
        </div>
        <div class="dev-form-row dev-bloquante-row">
          <label class="dev-lbl">Bloquante</label>
          <button class="dev-tog" :class="devBloquante?'dev-tog-on':'dev-tog-off'" @click="devBloquante=!devBloquante">
            {{devBloquante ? 'Oui — Bloquante' : 'Non — Non bloquante'}}
          </button>
        </div>
        <button class="btn" @click="doDeclareDeviation">Confirmer</button>
      </div>
      <!-- Résumé déviations -->
      <div class="dev-resume" v-if="devs.length">
        <span class="dev-res-bl">{{devBloquanteOpen}} bloquante{{devBloquanteOpen!==1?'s':''}}</span>
        <span class="dev-res-nb">{{devNonBloquanteOpen}} non bloquante{{devNonBloquanteOpen!==1?'s':''}}</span>
        <span class="dev-res-cl">{{devClosed}} clôturée{{devClosed!==1?'s':''}}</span>
      </div>
      <div v-if="!devs.length" class="em">Aucune déviation</div>
      <div class="dev-list" v-else>
        <div class="dev-card" v-for="d in devs" :key="d.id">
          <!-- Ligne 1 : badges + statut + clôturer -->
          <div class="dev-card-top">
            <span class="dev-badge-bl" :class="d.bloquante?'dev-bl-on':'dev-bl-off'">{{d.bloquante?'BLOQUANTE':'Non bloquante'}}</span>
            <span class="sp2" :class="d.statut==='ouverte'?'sp2-ko':'sp2-ok'">{{d.statut==='ouverte'?'Ouverte':'Clôturée'}}</span>
            <button v-if="!d.bloquante&&(d.statut==='ouverte'||d.statut==='en_cours')&&canPerform('declarer_nc')" class="btn-sm dev-bl-mark-btn" @click="doMarkBloquante(d.id)">⚠ Marquer bloquante</button>
            <button v-if="(d.statut==='ouverte'||d.statut==='en_cours') && canPerform('cloturer_deviation')" class="btn-sm dev-cl-btn" @click="doCloseDeviation(d.id)">Clôturer</button>
          </div>
          <!-- Ligne 2 : service déclarant / nom / date -->
          <div class="dev-card-meta">
            <span class="dev-meta-svc">{{SVC_LABELS[d.declared_service]||d.declared_service||'—'}}</span>
            <span class="dev-meta-who" v-if="d.profiles">{{(d.profiles.prenom||'')+' '+(d.profiles.nom||'')}}</span>
            <span class="dev-meta-when">{{fmtDevDate(d.declared_at)}}</span>
          </div>
          <!-- Champs éditables N° DN et Observation -->
          <div class="dev-card-edit" v-if="devEdits[d.id]">
            <div class="dev-card-row">
              <label class="dev-lbl">N° DN</label>
              <input type="text" v-model="devEdits[d.id].editNumeroDn" placeholder="Ex: DN-2026-001" class="dev-input-sm" />
            </div>
            <div class="dev-card-row">
              <label class="dev-lbl">Observation</label>
              <textarea v-model="devEdits[d.id].editObs" rows="2" placeholder="Observation..." class="dev-input"></textarea>
            </div>
            <button class="dev-save-btn" @click="saveDevField(d.id)">💾 Sauvegarder</button>
          </div>
        </div>
      </div>
    </div>

    <!-- RVP -->
    <div class="section"><div class="sh"><span>RVP</span></div>
      <div class="dg" v-if="canPerform('emettre_rvp')">
        <div class="di di-act" @click="doDeclareRvp('rvp_fab')"><div class="dind ind-violet"></div><div><div class="dn">RVP Fabrication</div><div class="ds">＋ Émettre</div></div></div>
        <div class="di di-act" @click="doDeclareRvp('rvp_cond')"><div class="dind ind-violet"></div><div><div class="dn">RVP Conditionnement</div><div class="ds">＋ Émettre</div></div></div>
        <div class="di di-act" @click="doDeclareRvp('rvp_lcq')"><div class="dind ind-violet"></div><div><div class="dn">RVP LCQ</div><div class="ds">＋ Émettre</div></div></div>
      </div>
      <div v-if="!rvpDocs.length" class="em">Aucun RVP</div>
      <div class="dg" v-else>
        <div class="di" v-for="d in rvpDocs" :key="d.id" @click="$router.push('/lots/'+lot.id+'/documents/'+d.id)">
          <div class="dind" :class="indClass(d)"></div>
          <div><div class="dn">RVP — {{rvpServiceLabel(d)}}</div><div class="ds" :class="dsClass(d)">{{docStatLabel(d)}}</div></div>
        </div>
      </div>
    </div>

    <!-- MàJ Documents -->
    <div v-if="docErrMsg" class="doc-err">{{docErrMsg}}</div>
    <div class="section"><div class="sh"><span>Mises à jour documentaires</span></div>
      <div class="dg" v-if="canPerform('emettre_maj_if')||canPerform('emettre_maj_ic')||canPerform('emettre_maj_nmcl_of')||canPerform('emettre_maj_nmcl_oc')">
        <div class="di di-act" v-if="canPerform('emettre_maj_if')" @click="doDeclareMajDoc('maj_if')"><div class="dind ind-teal"></div><div><div class="dn">MàJ IF</div><div class="ds">＋ Déclarer</div></div></div>
        <div class="di di-act" v-if="canPerform('emettre_maj_ic')" @click="doDeclareMajDoc('maj_ic')"><div class="dind ind-teal"></div><div><div class="dn">MàJ IC</div><div class="ds">＋ Déclarer</div></div></div>
        <div class="di di-act" v-if="canPerform('emettre_maj_nmcl_of')" @click="doDeclareMajDoc('maj_nmcl_of')"><div class="dind ind-teal"></div><div><div class="dn">MàJ Nmcl OF</div><div class="ds">＋ Déclarer</div></div></div>
        <div class="di di-act" v-if="canPerform('emettre_maj_nmcl_oc')" @click="doDeclareMajDoc('maj_nmcl_oc')"><div class="dind ind-teal"></div><div><div class="dn">MàJ Nmcl OC</div><div class="ds">＋ Déclarer</div></div></div>
      </div>
      <div v-if="!majDocs.length" class="em">Aucune mise à jour documentaire</div>
      <div class="dg" v-else>
        <div class="di" v-for="d in majDocs" :key="d.id" @click="$router.push('/lots/'+lot.id+'/documents/'+d.id)">
          <div class="dind" :class="indClass(d)"></div>
          <div><div class="dn">{{majDocLabel(d)}}</div><div class="ds" :class="dsClass(d)">{{docStatLabel(d)}}</div></div>
        </div>
      </div>
    </div>

    <!-- Clôture SAP -->
    <div class="section"><div class="sh"><span>Clôture SAP</span></div>
      <div class="dg" v-if="canPerform('emettre_cloture_sap_of')||canPerform('emettre_cloture_sap_oc')">
        <div class="di di-act" v-if="canPerform('emettre_cloture_sap_of')" @click="doDeclareClotureSap('cloture_sap_of')"><div class="dind ind-slate"></div><div><div class="dn">Clôt. SAP OF</div><div class="ds">＋ Émettre</div></div></div>
        <div class="di di-act" v-if="canPerform('emettre_cloture_sap_oc')" @click="doDeclareClotureSap('cloture_sap_oc')"><div class="dind ind-slate"></div><div><div class="dn">Clôt. SAP OC</div><div class="ds">＋ Émettre</div></div></div>
      </div>
      <div v-if="!clotDocs.length" class="em">Aucune clôture SAP</div>
      <div class="dg" v-else>
        <div class="di" v-for="d in clotDocs" :key="d.id" @click="$router.push('/lots/'+lot.id+'/documents/'+d.id)">
          <div class="dind" :class="clotIndClass(d)"></div>
          <div><div class="dn">{{clotDocLabel(d)}}</div><div class="ds" :class="clotDsClass(d)">{{clotStatLabel(d)}}</div></div>
        </div>
      </div>
    </div>

    <!-- Planification libération -->
    <div class="section"><div class="sh"><span>Planification libération</span><span class="dc" v-if="planSaving">Enregistrement…</span></div>
      <div class="plan-grid">
        <div class="plan-bloc">
          <div class="plan-titre">🔬 Libération LCQ</div>
          <div class="plan-row">
            <label>Date cible</label>
            <input type="date" v-model="planEdit.date_lcq_cible" class="plan-input" @change="savePlanning('date_lcq_cible')" />
          </div>
        </div>
        <div class="plan-bloc">
          <div class="plan-titre">✅ Libération AQ</div>
          <div class="plan-row">
            <label>Date cible</label>
            <input type="date" v-model="planEdit.date_aq_cible" class="plan-input" @change="savePlanning('date_aq_cible')" />
          </div>
        </div>
        <div class="plan-bloc">
          <div class="plan-titre">📋 Libération DT</div>
          <div class="plan-row">
            <label>Date cible</label>
            <input type="date" v-model="planEdit.date_dt_cible" class="plan-input" @change="savePlanning('date_dt_cible')" />
          </div>
        </div>
      </div>
    </div>

    <!-- Synthèse -->
    <div class="section" v-if="dossier"><div class="sh"><span>Synthèse libération</span></div>
      <div class="syg">
        <div class="syc"><span>IF</span><span :class="dossier.if_approved?'ok':'ko'">{{dossier.if_approved?'✓':'✕'}}</span></div>
        <div class="syc"><span>IC</span><span :class="dossier.ic_approved?'ok':'ko'">{{dossier.ic_approved?'✓':'✕'}}</span></div>
        <div class="syc"><span>DA PC</span><span :class="dossier.da_pc_approved?'ok':'ko'">{{dossier.da_pc_approved?'✓':'✕'}}</span></div>
        <div class="syc"><span>DA Micro</span><span :class="!dossier.da_micro_applicable?'na':dossier.da_micro_approved?'ok':'ko'">{{!dossier.da_micro_applicable?'N/A':dossier.da_micro_approved?'✓':'✕'}}</span></div>
        <div class="syc"><span>Dév. clôturées</span><span :class="dossier.deviations_closed?'ok':'ko'">{{dossier.deviations_closed?'✓':'✕'}}</span></div>
        <div class="syc"><span>Pièces compl.</span><span :class="dossier.pieces_complementaires_ok?'ok':'ko'">{{dossier.pieces_complementaires_ok?'✓':'✕'}}</span></div>
      </div>
      <div class="lz" v-if="canPerform('liberer_lot')"><button class="lb" :disabled="!dossierComplete" @click="doLiberer">{{dossierComplete?'Libérer le lot':'Conditions non remplies'}}</button></div>
    </div>
  </div>
  <div v-else class="loading">Chargement...</div>
</template>
<script>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { loadPermissions, canPerform, getPermissionForEtape } from '../services/permissions'
import { validateOrder, libererLot, declareDeviation, closeDeviation, declareRVP, declareMajDoc, declareClotureSap, requestAql, respondAql, isAqlConforme, modifyLot, deleteLot } from '../services/actions'
export default {
  setup() {
    var route = useRoute(), router = useRouter()
    var lot = ref(null), prod = ref({}), of = ref(null), oc = ref(null), ofVals = ref([]), ocVals = ref([])
    var docs = ref([]), devs = ref([]), aqls = ref([]), dossier = ref(null), userId = ref(null), userService = ref('')
    var showDevForm = ref(false), devObs = ref(''), devBloquante = ref(false), devNumeroDn = ref(''), showModify = ref(false)
    var devEdits = ref({})
    var editNumLot = ref(''), editCodeProd = ref(''), editProductId = ref(null), prodSuggestions = ref([])
    var aqlFabConforme = ref(false), aqlCondConforme = ref(false)
    var detailLoading = ref(false)
    var planning = ref(null), planSaving = ref(false)
    var planEdit = ref({date_lcq_cible:'',date_lcq_revisee:'',date_aq_cible:'',date_aq_revisee:'',date_dt_cible:'',date_dt_revisee:''})

    var isAdmin = computed(function(){return userService.value === 'admin'})
    var statusLabels = {vide:'PLANIFIÉ',quarantaine:'QUARANTAINE',sous_investigation:'SOUS INVESTIGATION',accepte:'ACCEPTÉ',refuse:'REFUSÉ'}
    var circuitSteps = [
      {key:'planification',label:'Mise en circuit',service:'Planification'},
      {key:'stock',label:'Validation quantités',service:'Stock'},
      {key:'aq',label:'Validation AQ',service:'AQ'},
      {key:'dt',label:'Autorisation lancement',service:'DT'},
      {key:'aq_dap',label:'Remise à Production',service:'AQ DAP'},
      {key:'production',label:'Accusé réception',service:'Production'},
    ]

    var canValidateStep = function(orderType, etape) {
      if (userService.value === 'admin') return true
      var permKey = getPermissionForEtape(etape, orderType)
      return permKey ? canPerform(permKey) : false
    }

    var getVal = function(type,etape){return (type==='of'?ofVals:ocVals).value.find(function(v){return v.etape===etape})}
    var pipClass = function(type,etape){if(getVal(type,etape))return'pip-done';var o=type==='of'?of.value:oc.value;return o&&o.etape_circuit===etape?'pip-active':'pip-wait'}
    var stepIndClass = function(type,etape){
      if(getVal(type,etape)) return 'ind-done'
      var o=type==='of'?of.value:oc.value
      return o&&o.etape_circuit===etape?'ind-prog':'ind-wait'
    }
    // Étapes du circuit en cartes (style dossier) : statut + clic
    var stepStatus = function(type,etape){
      var v=getVal(type,etape)
      if(v) return '✓ Validé — '+(v.user||'')+' · '+fmtDt(v.validated_at)
      var o=type==='of'?of.value:oc.value
      if(o&&o.etape_circuit===etape){
        if(o.pending_ar_service) return '⏳ En attente AR — '+(SVC_LABELS[o.pending_ar_service]||o.pending_ar_service)
        if(canValidateStep(type,etape)) return '＋ À valider'
        return 'En cours'
      }
      return 'À venir'
    }
    var stepClickable = function(type,etape){
      var o=type==='of'?of.value:oc.value
      if(!o||o.statut==='termine'||o.etape_circuit!==etape) return false
      if(o.pending_ar_service) return (o.pending_ar_service===userService.value||isAdmin.value)&&canPerform('accuser_reception_circuit')
      return canValidateStep(type,etape)
    }
    var stepClick = function(type,etape){
      if(!stepClickable(type,etape)) return
      var o=type==='of'?of.value:oc.value
      if(o.pending_ar_service) doAcknowledgeOrderAR(type,o.id)
      else doValidate(type,o.id,etape)
    }
    var circuitFlowClass = function(type,etape){
      var order = type==='of'?of.value:oc.value
      if(!order) return 'fs-wait'
      if(order.statut==='termine') return 'fs-done'
      if(getVal(type,etape)) return 'fs-done'
      if(order.etape_circuit===etape) return 'fs-active'
      return 'fs-wait'
    }
    var fmtDt = function(d){return d?new Date(d).toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}):''}

    // Terminé = toutes les étapes faites par définition (statut terminal) → compteur plein (cohérent avec circuitSummary)
    var ofV = computed(function(){return (of.value && of.value.statut==='termine') ? circuitSteps.length : ofVals.value.length})
    var ocV = computed(function(){return (oc.value && oc.value.statut==='termine') ? circuitSteps.length : ocVals.value.length})
    var mainDocs = computed(function(){return docs.value.filter(function(d){return d.type_document!=='rvp'&&!d.type_document.startsWith('maj_')&&!d.type_document.startsWith('cloture_sap_')})})
    var rvpDocs = computed(function(){return docs.value.filter(function(d){return d.type_document==='rvp'})})
    var majDocs = computed(function(){return docs.value.filter(function(d){return d.type_document.startsWith('maj_')})})
    var clotDocs = computed(function(){return docs.value.filter(function(d){return d.type_document.startsWith('cloture_sap_')})})
    var docsOk = computed(function(){return docs.value.filter(function(d){return d.statut==='approuve_dt'&&d.is_applicable}).length})
    var docsReq = computed(function(){return docs.value.filter(function(d){return d.is_applicable&&d.is_required}).length})
    var devsOpen = computed(function(){return devs.value.filter(function(d){return d.statut==='ouverte'||d.statut==='en_cours'}).length})
    var leadTime = computed(function(){if(!lot.value||!lot.value.date_enregistrement)return null;var end=lot.value.date_liberation||new Date().toISOString().split('T')[0];return Math.floor((new Date(end)-new Date(lot.value.date_enregistrement))/86400000)})
    var dossierComplete = computed(function(){return dossier.value&&dossier.value.if_approved&&dossier.value.ic_approved&&dossier.value.da_pc_approved&&(!dossier.value.da_micro_applicable||dossier.value.da_micro_approved)&&dossier.value.deviations_closed&&dossier.value.pieces_complementaires_ok})

    // Carte compacte circuit (LotDetailPage) — résumé + clic vers le détail
    var circuitOverallInd = function(type){
      var o=type==='of'?of.value:oc.value
      if(!o) return 'ind-wait'
      if(o.statut==='termine') return 'ind-done'
      return 'ind-prog'
    }
    var circuitSummary = function(type){
      var o=type==='of'?of.value:oc.value
      if(!o) return '—'
      var total=circuitSteps.length
      // terminé = toutes les étapes faites par définition (statut terminal) → compteur plein
      var n=o.statut==='termine'?total:(type==='of'?ofVals:ocVals).value.length
      if(o.statut==='termine') return '✓ Terminé — '+total+'/'+total+' étapes'
      if(o.pending_ar_service) return '⏳ En attente AR — '+(SVC_LABELS[o.pending_ar_service]||o.pending_ar_service)+' · '+n+'/'+total
      var cur=circuitSteps.find(function(e){return e.key===o.etape_circuit})
      return (cur?cur.label:'En cours')+' · '+n+'/'+total
    }

    var docTypeLabel = function(d){var map={if:'IF',ic:'IC',da_pc:'DA Physico-chimie',da_micro:'DA Microbiologie'};return map[d.type_document]||d.type_document}
    var docStatLabel = function(d){if(!d.is_applicable)return'Non applicable';var map={non_emis:'Non émis',emis:'Émis',verification_aq:'Vérif AQ',retour_emetteur:'Retourné',approuve_aq:'Appr. AQ',approuve_dt:'Approuvé'};return map[d.statut]||d.statut}
    var indClass = function(d){if(!d.is_applicable)return'ind-na';if(d.statut==='approuve_dt')return'ind-done';if(d.statut==='retour_emetteur')return'ind-ret';if(d.statut==='non_emis')return'ind-wait';return'ind-prog'}
    var dsClass = function(d){if(!d.is_applicable)return'ds-na';if(d.statut==='approuve_dt')return'ds-ok';if(d.statut==='retour_emetteur')return'ds-ret';return''}
    var rvpServiceLabel = function(d){var map={fabrication:'Fabrication',conditionnement:'Conditionnement',lcq:'LCQ'};return map[d.service_emetteur]||d.service_emetteur}
    var isDocBlocked = function(d){if(d.statut!=='non_emis')return false;if(d.type_document==='if'&&!aqlFabConforme.value)return true;if(d.type_document==='ic'&&!aqlCondConforme.value)return true;return false}

    var goBack = function(){
      var query = {}
      if(route.query.q)query.q=route.query.q
      if(route.query.filters)query.filters=route.query.filters
      router.push({path:'/lots',query:query})
    }

    var doValidate = async function(type,orderId,etape){await validateOrder(type,orderId,etape,userId.value,lot.value.id);await loadLot()}
    var doLiberer = async function(){await libererLot(lot.value.id,userId.value);await loadLot()}
    var doDeclareDeviation = async function(){await declareDeviation(lot.value.id,devObs.value,devBloquante.value,devNumeroDn.value,userId.value,userService.value);devObs.value='';devNumeroDn.value='';devBloquante.value=false;showDevForm.value=false;await loadLot()}
    var doCloseDeviation = async function(id){await closeDeviation(id,lot.value.id,userId.value);await loadLot()}
    var doMarkBloquante = async function(id){
      await supabase.from('deviations').update({bloquante:true}).eq('id',id)
      await supabase.from('lot_events').insert({lot_id:lot.value.id,event_type:'deviation_bloquante',description:'Déviation marquée bloquante',triggered_by:userId.value,created_at:new Date().toISOString()})
      await loadLot()
    }
    var doDeclareRvp = async function(type){await declareRVP(lot.value.id,type,userId.value);await loadLot()}
    var docErrMsg = ref('')
    var doDeclareMajDoc = async function(type){
      docErrMsg.value=''
      try{await declareMajDoc(lot.value.id,type,userId.value);await loadLot()}
      catch(e){docErrMsg.value='Erreur : '+e.message;console.error('declareMajDoc',e)}
    }
    var doDeclareClotureSap = async function(type){
      docErrMsg.value=''
      try{await declareClotureSap(lot.value.id,type,userId.value);await loadLot()}
      catch(e){docErrMsg.value='Erreur : '+e.message;console.error('declareClotureSap',e)}
    }
    var majDocLabel = function(d){var map={maj_if:'MàJ IF',maj_ic:'MàJ IC',maj_nmcl_of:'MàJ Nmcl OF',maj_nmcl_oc:'MàJ Nmcl OC'};return map[d.type_document]||d.type_document}
    var clotDocLabel = function(d){var map={cloture_sap_of:'Clôture SAP OF',cloture_sap_oc:'Clôture SAP OC'};return map[d.type_document]||d.type_document}
    var clotStatLabels = {emis:'Dem. valid.',valide_planif:'Validé',cloture_demandee:'Dem. clôt.',cloture:'Clôturé'}
    var clotStatLabel = function(d){return clotStatLabels[d.statut]||d.statut}
    var clotIndClass = function(d){if(d.statut==='cloture')return'ind-done';if(d.statut==='non_emis')return'ind-wait';return'ind-prog'}
    var clotDsClass = function(d){if(d.statut==='cloture')return'ds-ok';return''}
    // AQL — résumé pour les cartes cliquables (parcours façon circuit)
    var aqlLatest = function(type){ var s=aqls.value.filter(function(x){return x.type===type}); return s.length?s[0]:null }
    var aqlAllDone = function(a){ return a && !a.request_ar_pending && a.resultat!=='en_attente' && !a.result_ar_pending }
    var aqlSummary = function(type){
      var a=aqlLatest(type)
      if(!a) return 'Aucune demande — à demander'
      if(a.request_ar_pending) return '⏳ AR demande (AQ)'
      if(a.resultat==='en_attente') return '⏳ Réalisation LCQ'
      if(a.result_ar_pending) return '⏳ AR résultat'
      return a.resultat==='conforme'?'✓ Conforme':'✗ Non conforme'
    }
    var aqlInd = function(type){ var a=aqlLatest(type); if(!a) return 'ind-wait'; if(aqlAllDone(a)) return a.resultat==='conforme'?'ind-done':'ind-ret'; return 'ind-prog' }
    var aqlDsClass = function(type){ var a=aqlLatest(type); if(aqlAllDone(a)) return a.resultat==='conforme'?'ds-ok':'ds-ret'; return '' }
    var doRequestAql = async function(type){await requestAql(lot.value.id,type,userId.value);await loadLot()}
    var doAqlConforme = async function(id){await respondAql(id,'conforme','',userId.value,lot.value.id);await loadLot()}
    var doAqlNonConforme = async function(id){var reco=prompt('Recommandations :');await respondAql(id,'non_conforme',reco||'',userId.value,lot.value.id);await loadLot()}
    var isLatestAql = function(a){var sameType=aqls.value.filter(function(x){return x.type===a.type});return sameType.length>0&&sameType[0].id===a.id}
    var canRelanceAql = function(a){return canPerform('demander_aql_'+(a.type==='fabrication'?'fab':'cond'))}
    var doRelanceAql = async function(a){await requestAql(lot.value.id,a.type,userId.value);await loadLot()}

    var doAcknowledgeOrderAR = async function(orderType, orderId) {
      var now = new Date().toISOString()
      var tbl = orderType==='of'?'orders_of':'orders_oc'
      var res = await supabase.from(tbl).update({pending_ar_service:null,updated_at:now}).eq('id',orderId)
      if(res.error){alert('Erreur AR : '+res.error.message);return}
      await supabase.from('lot_events').insert({lot_id:lot.value.id,event_type:'ar_circuit',description:'AR circuit '+orderType.toUpperCase(),triggered_by:userId.value,created_at:now})
      await loadLot()
    }
    var doAcknowledgeAqlRequest = async function(aqlId) {
      var now = new Date().toISOString()
      var res = await supabase.from('aql_inspections').update({request_ar_pending:false,updated_at:now}).eq('id',aqlId)
      if(res.error){alert('Erreur AR demande AQL : '+res.error.message);return}
      await supabase.from('lot_events').insert({lot_id:lot.value.id,event_type:'ar_aql_demande',description:'AR demande AQL',triggered_by:userId.value,created_at:now})
      await loadLot()
    }
    var doAcknowledgeAqlResult = async function(aqlId) {
      var now = new Date().toISOString()
      var res = await supabase.from('aql_inspections').update({result_ar_pending:false,updated_at:now}).eq('id',aqlId)
      if(res.error){alert('Erreur AR résultat AQL : '+res.error.message);return}
      await supabase.from('lot_events').insert({lot_id:lot.value.id,event_type:'ar_aql_resultat',description:'AR résultat AQL',triggered_by:userId.value,created_at:now})
      await loadLot()
    }
    // Masquer "Demander AQL" si le dernier AQL de ce type est en attente ou non_conforme (relancer via bouton per-ligne)
    var canDemanderAql = function(type) {
      var sameType = aqls.value.filter(function(x){return x.type===type})
      if (!sameType.length) return true // aucun AQL → afficher Demander
      var latest = sameType[0] // déjà trié par created_at desc
      if (latest.resultat==='en_attente'||latest.resultat===null) return false // en attente → masquer
      if (latest.resultat==='non_conforme') return false // non conforme → relancer via bouton per-ligne
      return true // conforme → on peut redemander un nouveau cycle
    }

    var doSetDaMicroApplicable = async function(docId) {
      var now = new Date().toISOString()
      await supabase.from('liberation_documents').update({is_applicable:true,is_required:true,updated_at:now}).eq('id',docId)
      await supabase.from('liberation_dossiers').update({da_micro_applicable:true,updated_at:now}).eq('lot_id',lot.value.id)
      await supabase.from('lot_events').insert({lot_id:lot.value.id,event_type:'da_micro_applicable',description:'DA Microbiologie déclarée applicable',triggered_by:userId.value,created_at:now})
      await loadLot()
    }

    var SVC_LABELS = {planification:'Planification',stock:'Stock',aq:'AQ',aq_dap:'AQ DAP',dt:'DT',fabrication:'Fabrication',conditionnement:'Conditionnement',lcq:'LCQ',admin:'Admin'}
    var fmtDevDate = function(iso) {
      if (!iso) return '—'
      var d = new Date(iso)
      return d.toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',year:'numeric'})+' '+d.toLocaleTimeString('fr-FR',{hour:'2-digit',minute:'2-digit'})
    }
    var devBloquanteOpen = computed(function(){return devs.value.filter(function(d){return (d.statut==='ouverte'||d.statut==='en_cours')&&d.bloquante}).length})
    var devNonBloquanteOpen = computed(function(){return devs.value.filter(function(d){return (d.statut==='ouverte'||d.statut==='en_cours')&&!d.bloquante}).length})
    var devClosed = computed(function(){return devs.value.filter(function(d){return d.statut==='cloturee'}).length})

    var saveDevField = async function(devId) {
      var e = devEdits.value[devId]
      if (!e) return
      await supabase.from('deviations').update({numero_dn: e.editNumeroDn||null, description: e.editObs||''}).eq('id', devId)
      var dev = devs.value.find(function(d){return d.id===devId})
      if (dev) { dev.numero_dn = e.editNumeroDn; dev.description = e.editObs }
    }

    var savePlanning = async function(field) {
      if (!canPerform('modifier_planning')) { alert('Permission « modifier les dates prévisionnelles » requise'); return }
      planSaving.value = true
      var val = planEdit.value[field] || null
      await supabase.from('lot_planning').upsert(
        { lot_id: lot.value.id, [field]: val, updated_at: new Date().toISOString(), updated_by: userId.value },
        { onConflict: 'lot_id' }
      )
      var fieldToCol = {date_lcq_cible:'plan_lcq', date_aq_cible:'plan_aq', date_dt_cible:'plan_dt1', date_dt_revisee:'plan_dt2'}
      var colKey = fieldToCol[field] || field
      var u = await supabase.auth.getUser()
      var userEmail = u.data.user?.email || userId.value
      await supabase.from('lot_events').insert({
        lot_id: lot.value.id,
        event_type: 'planning_updated',
        description: colKey + '|' + (val || 'supprimé') + '|' + userEmail,
        triggered_by: userId.value,
        created_at: new Date().toISOString()
      })
      var planRes=(await supabase.from('lot_planning').select('*').eq('lot_id',lot.value.id).maybeSingle()).data
      planning.value=planRes; planSaving.value = false
    }

    var searchProd = async function(){
      if(editCodeProd.value.length<2){prodSuggestions.value=[];return}
      var res = await supabase.from('products').select('id,code_article,description').or('code_article.ilike.%'+editCodeProd.value+'%,description.ilike.%'+editCodeProd.value+'%').limit(5)
      prodSuggestions.value = res.data || []
    }
    var selectProd = function(p){editCodeProd.value=p.code_article;editProductId.value=p.id;prodSuggestions.value=[]}
    var doModify = async function(){
      if(!canPerform('modifier_lot'))return
      if(!editNumLot.value)return
      await modifyLot(lot.value.id, editNumLot.value, editProductId.value || lot.value.product_id)
      showModify.value=false;await loadLot()
    }
    var confirmDelete = async function(){
      if(!canPerform('supprimer_lot'))return
      if(!confirm('Supprimer le lot '+lot.value.numero_lot+' ? Cette action est irréversible.'))return
      await deleteLot(lot.value.id);router.push('/lots')
    }

    var loadLot = async function(){
      detailLoading.value = true
      try {
        var lotId = route.params.id
        // Round 1 — toutes les requêtes indépendantes en parallèle
        var r1 = await Promise.all([
          supabase.from('lots').select('*').eq('id',lotId).single(),
          supabase.from('orders_of').select('*').eq('lot_id',lotId).maybeSingle(),
          supabase.from('orders_oc').select('*').eq('lot_id',lotId).maybeSingle(),
          supabase.from('liberation_documents').select('*').eq('lot_id',lotId),
          supabase.from('deviations').select('*,profiles!declared_by(prenom,nom)').eq('lot_id',lotId).order('declared_at'),
          supabase.from('aql_inspections').select('*').eq('lot_id',lotId).order('created_at',{ascending:false}),
          supabase.from('liberation_dossiers').select('*').eq('lot_id',lotId).maybeSingle(),
          supabase.from('lot_planning').select('*').eq('lot_id',lotId).maybeSingle(),
          isAqlConforme(lotId,'fabrication'),
          isAqlConforme(lotId,'conditionnement'),
        ])
        var l = r1[0].data
        if(!l){console.error('loadLot: lot introuvable',lotId);return}
        lot.value=l
        of.value=r1[1].data
        oc.value=r1[2].data
        docs.value=r1[3].data||[]
        devs.value=r1[4].data||[]
        devEdits.value={};devs.value.forEach(function(d){devEdits.value[d.id]={editNumeroDn:d.numero_dn||'',editObs:d.description||''}})
        aqls.value=r1[5].data||[]
        dossier.value=r1[6].data
        var planRes=r1[7].data
        aqlFabConforme.value=r1[8]
        aqlCondConforme.value=r1[9]
        planning.value=planRes
        editNumLot.value=l.numero_lot
        // Round 2 — requêtes qui dépendent des résultats du round 1
        var r2 = await Promise.all([
          supabase.from('products').select('*').eq('id',l.product_id).single(),
          of.value?supabase.from('order_validations').select('*,profiles(prenom,nom)').eq('order_type','of').eq('order_id',of.value.id).order('validated_at'):Promise.resolve({data:[]}),
          oc.value?supabase.from('order_validations').select('*,profiles(prenom,nom)').eq('order_type','oc').eq('order_id',oc.value.id).order('validated_at'):Promise.resolve({data:[]}),
        ])
        prod.value=r2[0].data||{}
        editCodeProd.value=prod.value.code_article||''
        ofVals.value=(r2[1].data||[]).map(function(v){return{etape:v.etape,validated_at:v.validated_at,user:v.profiles?v.profiles.prenom+' '+v.profiles.nom:''}})
        ocVals.value=(r2[2].data||[]).map(function(v){return{etape:v.etape,validated_at:v.validated_at,user:v.profiles?v.profiles.prenom+' '+v.profiles.nom:''}})
        var toDate=function(d){return d?d.split('T')[0]:''}
        planEdit.value={
          date_lcq_cible:toDate(planRes?.date_lcq_cible),date_lcq_revisee:toDate(planRes?.date_lcq_revisee),
          date_aq_cible:toDate(planRes?.date_aq_cible),date_aq_revisee:toDate(planRes?.date_aq_revisee),
          date_dt_cible:toDate(planRes?.date_dt_cible),date_dt_revisee:toDate(planRes?.date_dt_revisee),
        }
      } catch(e) {
        console.error('loadLot erreur:',e)
      } finally {
        detailLoading.value = false
      }
    }

    // Phase par défaut (lots importés sans suivi de production) : réceptionné en stock ≠ "Planifié"
    var defaultPhase = function(s) {
      if (s === 'accepte') return 'Libéré'
      if (s === 'quarantaine' || s === 'sous_investigation' || s === 'refuse') return 'Reçu en stock'
      return 'Planifié'
    }
    var phaseLabel = computed(function(){ return lot.value ? (lot.value.phase_production_en_cours || defaultPhase(lot.value.statut_sap)) : '' })
    var getPhaseClass = function(phase) {
      if (!phase || phase === 'Planifié') return 'phase-planifie'
      if (phase === 'Reçu en stock') return 'phase-stock'
      if (phase === 'Libéré') return 'phase-libere'
      if (phase === 'Clôturé') return 'phase-cloture'
      if (phase === 'Fabriqué — En attente conditionnement') return 'phase-attente-cond'
      if (phase === 'Conditionné — En attente livraison PF') return 'phase-attente-pf'
      if (phase.startsWith('Conditionnement —')) return 'phase-cond'
      return 'phase-fab'
    }

    onMounted(async function(){
      var u=await supabase.auth.getUser();userId.value=u.data.user.id
      var p=await supabase.from('profiles').select('service').eq('id',u.data.user.id).single()
      if(p.data){userService.value=p.data.service;await loadPermissions(p.data.service)}
      await await loadLot()
    })

    // Naviguer directement d'un lot à un autre (changement de :id) sans démonter le composant :
    // Vue Router réutilise l'instance → recharger explicitement, sinon données du lot précédent.
    watch(function(){ return route.params.id }, function(nv, ov){ if(nv && nv !== ov) loadLot() })

    return{lot,prod,of,oc,ofVals,ocVals,docs,devs,aqls,dossier,detailLoading,statusLabels,circuitSteps,isAdmin,
      showDevForm,devObs,devBloquante,devNumeroDn,showModify,editNumLot,editCodeProd,prodSuggestions,rvpDocs,mainDocs,
      getVal,pipClass,stepIndClass,circuitFlowClass,stepStatus,stepClickable,stepClick,circuitOverallInd,circuitSummary,fmtDt,ofV,ocV,docsOk,docsReq,devsOpen,leadTime,dossierComplete,canValidateStep,
      docTypeLabel,docStatLabel,indClass,dsClass,rvpServiceLabel,isDocBlocked,goBack,
      userService,
      doValidate,doLiberer,doDeclareDeviation,doCloseDeviation,doMarkBloquante,doDeclareRvp,doDeclareMajDoc,doDeclareClotureSap,doRequestAql,doAqlConforme,doAqlNonConforme,doRelanceAql,isLatestAql,canRelanceAql,canDemanderAql,aqlSummary,aqlInd,aqlDsClass,
      doAcknowledgeOrderAR,doAcknowledgeAqlRequest,doAcknowledgeAqlResult,
      majDocs,clotDocs,majDocLabel,clotDocLabel,clotStatLabel,clotIndClass,clotDsClass,docErrMsg,
      searchProd,selectProd,doModify,confirmDelete,canPerform,
      planning,planEdit,planSaving,savePlanning,
      doSetDaMicroApplicable,
      devEdits,saveDevField,SVC_LABELS,fmtDevDate,
      devBloquanteOpen,devNonBloquanteOpen,devClosed,getPhaseClass,phaseLabel}
  }
}
</script>
<style scoped>
.bc{font-size:12px;color:#2563eb;cursor:pointer;margin-bottom:8px}
.lh{display:flex;align-items:center;justify-content:space-between;padding-bottom:8px;border-bottom:1px solid #e5e7eb;flex-wrap:wrap;gap:8px}
.lh-right{display:flex;align-items:center;gap:6px}
.ln{font-size:22px;font-weight:500;font-family:'SF Mono',monospace}.lp{font-size:13px;color:#666;margin-left:10px}
.sp{font-size:11px;font-weight:500;padding:3px 10px;border-radius:2px}
.s-quarantaine{background:#FFA94D;color:#412402}.s-accepte{background:#1D9E75;color:#fff}.s-sous_investigation{background:#E24B4A;color:#fff}.s-vide{background:#e8e8e8;color:#666}.s-refuse{background:#666;color:#fff}
.sp-phase{font-size:10px;font-weight:500;padding:3px 10px;border-radius:2px;white-space:nowrap}
.phase-planifie{background:#f0f0f0;color:#999}.phase-fab{background:#EEE8FF;color:#5B3CC4}.phase-attente-cond{background:#FFF3CD;color:#856404}.phase-cond{background:#E0F7F4;color:#00695C}.phase-attente-pf{background:#FFF3CD;color:#856404}.phase-stock{background:#E6F1FB;color:#1E5A9E}.phase-libere{background:#EAF3DE;color:#3B6D11}.phase-cloture{background:#e8e8e8;color:#333}
.loading{text-align:center;padding:60px;color:#999}
.detail-reloading{font-size:11px;color:#999;padding:4px 0 6px;letter-spacing:.3px;animation:spin-txt 1s linear infinite}
@keyframes spin-txt{0%{opacity:1}50%{opacity:.4}100%{opacity:1}}
.btn-sm{font-size:11px;padding:3px 10px;border:1px solid #ddd;border-radius:3px;background:#fff;cursor:pointer;color:#666}.btn-sm:hover{background:#f5f5f5}
.btn-del{border-color:#E24B4A;color:#E24B4A}.btn-del:hover{background:#FCEBEB}
.ks{display:grid;grid-template-columns:repeat(5,1fr);border:1px solid #e8e8e8;margin:10px 0}
.k{padding:10px 8px;text-align:center;border-right:1px solid #e8e8e8}.k:last-child{border-right:none}
.kv{font-size:16px;font-weight:500;font-family:'SF Mono',monospace}.ku{font-size:11px;color:#999}.kl{font-size:10px;color:#999;text-transform:uppercase;margin-top:2px}
.cw{color:#BA7517}.cd{color:#E24B4A}
.section{margin-top:16px}.sh{display:flex;justify-content:space-between;align-items:center;font-size:10px;font-weight:500;text-transform:uppercase;letter-spacing:1px;color:#999;padding-bottom:6px;border-bottom:1px solid #e8e8e8}
.dc{font-family:'SF Mono',monospace;color:#BA7517}
.action-btns{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:8px;margin:10px 0}
.btn-action{font-size:12px;padding:7px 12px;border-radius:4px;border:none;cursor:pointer;font-weight:500;background:#2563eb;color:#fff;min-height:36px;display:flex;align-items:center;justify-content:center;text-align:center;line-height:1.2}.btn-action:hover{background:#1d4ed8}
.btn-orange{background:#BA7517}.btn-orange:hover{background:#8B5A12}
.btn-violet{background:#5B3CC4}.btn-violet:hover{background:#4A2FA3}
.btn-teal{background:#0D7C66}.btn-teal:hover{background:#0A6050}
.btn-slate{background:#475569}.btn-slate:hover{background:#334155}
.doc-err{background:#FCEBEB;color:#A32D2D;font-size:12px;padding:10px 14px;border-radius:4px;margin:8px 0;border:1px solid #f5c6c6}
.ct{width:100%;border-collapse:collapse;font-size:13px}.ct td{padding:8px;border-bottom:1px solid #f5f5f5}
.cs{width:30%}.ca{font-weight:500}.cv{width:14%;color:#999;font-size:12px}.cp{width:8%;text-align:center}.cdt{width:22%;text-align:right;font-family:'SF Mono',monospace;font-size:12px;color:#666}.cac{width:26%;text-align:right}
.cu{font-size:12px;color:#999}
.pip{display:inline-block;width:8px;height:8px;border-radius:50%}.pip-done{background:#1D9E75}.pip-active{background:#2563eb;box-shadow:0 0 0 3px rgba(124,58,237,.15)}.pip-wait{background:#e8e8e8}
.btn{font-size:12px;padding:5px 14px;border-radius:2px;border:none;cursor:pointer;font-weight:500;background:#2563eb;color:#fff;margin-left:4px}.btn:hover{background:#1d4ed8}.bd{background:#f5f5f5;color:#ccc;cursor:not-allowed}
.br{background:#E24B4A}.bg{background:#1D9E75}.bc2{background:#f5f5f5;color:#666}
.dg{display:grid;grid-template-columns:1fr 1fr;border:1px solid #e8e8e8}
.di{padding:10px 12px;border-right:1px solid #e8e8e8;border-bottom:1px solid #e8e8e8;display:flex;gap:10px;cursor:pointer}.di:hover{background:#fafafa}.di:nth-child(2n){border-right:none}.dna{opacity:.35}
.dind{width:3px;height:28px;border-radius:1px;flex-shrink:0}.ind-wait{background:#e8e8e8}.ind-prog{background:#2563eb}.ind-done{background:#1D9E75}.ind-ret{background:#E24B4A}.ind-na{background:#e8e8e8;opacity:.3}
.ind-orange{background:#BA7517}.ind-violet{background:#5B3CC4}.ind-teal{background:#0D7C66}.ind-slate{background:#475569}
.di-act .ds{color:#2563eb;font-weight:500}.di-act:hover{background:#eff6ff}
.dg-1{grid-template-columns:1fr !important}.di-ro{cursor:default}.di-ro:hover{background:transparent}
.dn{font-size:13px;font-weight:500}.ds{font-size:11px;color:#999;margin-top:1px}.ds-ok{color:#1D9E75}.ds-ret{color:#E24B4A}.ds-na{color:#ccc}
.ds-block{font-size:10px;color:#BA7517;margin-top:2px}
.btn-app{font-size:10px;padding:3px 8px;border:1px solid #1D9E75;border-radius:3px;background:#EAF3DE;color:#3B6D11;cursor:pointer;margin-top:4px;display:block;font-family:inherit}.btn-app:hover{background:#d4edda}
.ds-na-hint{font-size:10px;color:#ccc;display:block;margin-top:2px}
.sp2{font-size:11px;padding:2px 8px;border-radius:2px;font-weight:500}.sp2-ok{background:#EAF3DE;color:#3B6D11}.sp2-ko{background:#FCEBEB;color:#A32D2D}.sp2-wait{background:#f5f5f5;color:#999}
.dev-form{display:flex;flex-direction:column;gap:8px;margin:10px 0}
.dev-form-row{display:flex;align-items:flex-start;gap:10px}
.dev-lbl{font-size:11px;font-weight:600;color:#999;min-width:80px;padding-top:6px;text-transform:uppercase;letter-spacing:.5px}
.dev-input{flex:1;border:1px solid #ddd;padding:6px 8px;font-size:13px;resize:vertical;font-family:inherit;border-radius:2px}
.dev-input-sm{flex:1;border:1px solid #ddd;padding:6px 8px;font-size:13px;font-family:inherit;border-radius:2px}
.dev-bloquante-row{align-items:center}
.dev-tog{padding:5px 14px;border:none;border-radius:10px;cursor:pointer;font-size:11px;font-weight:600}
.dev-tog-on{background:#FCEBEB;color:#A32D2D}.dev-tog-off{background:#f5f5f5;color:#999}
.dev-badge-bl{font-size:10px;padding:2px 7px;border-radius:3px;font-weight:600;white-space:nowrap}
.dev-bl-on{background:#FCEBEB;color:#A32D2D}.dev-bl-off{background:#f5f5f5;color:#bbb}
/* Résumé déviations */
.dev-resume{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:8px}
.dev-res-bl{font-size:11px;padding:2px 10px;border-radius:10px;background:#FCEBEB;color:#A32D2D;font-weight:600}
.dev-res-nb{font-size:11px;padding:2px 10px;border-radius:10px;background:#f5f5f5;color:#666;font-weight:500}
.dev-res-cl{font-size:11px;padding:2px 10px;border-radius:10px;background:#EAF3DE;color:#3B6D11;font-weight:500}
/* Cartes déviations */
.dev-list{display:flex;flex-direction:column;gap:8px;margin-top:8px}
.dev-card{border:1px solid #f0f0f0;border-radius:4px;padding:10px 12px;background:#fafafa}
.dev-card-top{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.dev-bl-mark-btn{background:#FEF5E7;color:#A0620D;border-color:#E89C3A !important}.dev-bl-mark-btn:hover{background:#FDEBD0 !important;color:#7D4E0A !important}
.dev-cl-btn{margin-left:auto}
.dev-card-meta{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-top:6px;padding-top:6px;border-top:1px solid #f0f0f0}
.dev-meta-svc{font-size:10px;background:#dbeafe;color:#1d4ed8;padding:1px 7px;border-radius:10px;font-weight:600;white-space:nowrap}
.dev-meta-who{font-size:11px;font-weight:500;color:#555}
.dev-meta-when{font-size:10px;font-family:'SF Mono',monospace;color:#999;margin-left:auto}
.dev-card-edit{margin-top:8px;display:flex;flex-direction:column;gap:6px}
.dev-card-row{display:flex;align-items:flex-start;gap:8px}
.dev-save-btn{align-self:flex-start;font-size:11px;padding:4px 12px;border:1px solid #2563eb;border-radius:3px;background:#dbeafe;color:#1d4ed8;cursor:pointer;font-family:inherit}.dev-save-btn:hover{background:#ddd6fe}
.dim{color:#999;font-size:12px}.mono{font-family:'SF Mono',monospace;font-size:12px}
.em{font-size:12px;color:#999;padding:12px 0;text-align:center}
/* Stepper circuit OF/OC */
.flow-wrap{overflow-x:auto;-webkit-overflow-scrolling:touch;margin:12px 0}
.flow{display:flex;align-items:center;gap:0;border:1px solid #e8e8e8;border-radius:2px;overflow:hidden;flex-wrap:nowrap;min-width:480px}
.flow-6 .flow-step{padding:8px 4px}
.flow-step{flex:1;padding:10px 12px;text-align:center;display:flex;align-items:center;justify-content:center;gap:5px;min-height:44px}
.flow-arrow{padding:0 2px;color:#ccc;font-size:12px;flex-shrink:0}
.fs-num{width:20px;height:20px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-size:11px;font-weight:500;flex-shrink:0}
.fs-label{font-size:11px;line-height:1.3}
.fs-done{background:#EAF3DE}.fs-done .fs-num{background:#1D9E75;color:#fff}.fs-done .fs-label{color:#3B6D11}
.fs-active{background:#dbeafe}.fs-active .fs-num{background:#2563eb;color:#fff}.fs-active .fs-label{color:#1d4ed8;font-weight:500}
.fs-wait{background:#fafafa}.fs-wait .fs-num{background:#e8e8e8;color:#999}.fs-wait .fs-label{color:#999}
.circ-act{margin:10px 0;display:flex;align-items:center;gap:10px}
.circ-done{font-size:12px;color:#1D9E75;font-weight:500}
.circ-ar-pending{font-size:12px;color:#BA7517;font-weight:500;margin-right:8px}
.circ-hist{margin-top:10px;border-top:1px solid #f0f0f0;padding-top:8px;display:flex;flex-direction:column;gap:2px}
.circ-hist-row{display:flex;align-items:center;gap:8px;font-size:11px;padding:3px 0;border-bottom:1px solid #f8f8f8}
.circ-hist-dot{width:6px;height:6px;border-radius:50%;background:#1D9E75;flex-shrink:0}
.circ-hist-step{font-weight:500;color:#333;flex:1}
.circ-hist-who{color:#999}
.circ-hist-at{font-family:'SF Mono',monospace;font-size:10px;color:#bbb}
/* Cartes circuit OF/OC harmonisées avec documents */
.di-step{cursor:default}
.di-body{flex:1;min-width:0}
.dn-active{color:#2563eb;font-weight:600}
.di-val{display:flex;justify-content:space-between;align-items:center;margin-top:3px;flex-wrap:wrap;gap:4px}
.di-date{font-family:'SF Mono',monospace;font-size:10px;color:#bbb}
.di-pending{color:#ccc !important;font-style:italic}
.btn-step{font-size:11px;padding:3px 12px;border:1px solid #2563eb;border-radius:3px;background:#dbeafe;color:#1d4ed8;cursor:pointer;margin-top:4px;font-family:inherit}.btn-step:hover{background:#ddd6fe}
.syg{display:grid;grid-template-columns:1fr 1fr;border:1px solid #e8e8e8}.syc{padding:8px 12px;border-right:1px solid #e8e8e8;border-bottom:1px solid #e8e8e8;display:flex;justify-content:space-between;font-size:13px}.syc:nth-child(2n){border-right:none}.syc span:first-child{color:#666}
.ok{color:#1D9E75;font-weight:500}.ko{color:#E24B4A;font-weight:500}.na{color:#ccc}
/* Planning libération */
.plan-grid{display:grid;grid-template-columns:1fr 1fr;gap:1px;background:#e8e8e8;border:1px solid #e8e8e8;margin-top:10px}
.plan-bloc{background:#fff;padding:12px 14px;border-left:3px solid #2563eb}
.plan-titre{font-size:11px;font-weight:600;color:#333;margin-bottom:10px}
.plan-row{display:flex;align-items:center;justify-content:space-between;margin-bottom:6px;gap:8px}
.plan-row label{font-size:11px;color:#999;white-space:nowrap;flex-shrink:0}
.plan-input{padding:4px 8px;border:1px solid #ddd;border-radius:3px;font-size:12px;font-family:inherit;outline:none;width:130px;text-align:right}.plan-input:focus{border-color:#2563eb}
.plan-revised{border-color:#BA7517 !important;background:#fffbf0}
.plan-note{font-size:10px;color:#bbb;margin-top:4px}
.lz{text-align:center;padding:14px 0}.lb{padding:10px 32px;font-size:13px;font-weight:500;background:#2563eb;color:#fff;border:none;border-radius:2px;cursor:pointer}.lb:disabled{opacity:.4;cursor:not-allowed}.lb:hover:not(:disabled){background:#1d4ed8}
.modal-overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:100}
.modal{background:#fff;padding:24px;width:400px;border-radius:4px}.modal-title{font-size:16px;font-weight:500;margin-bottom:16px}
.field{margin-bottom:14px}.field label{display:block;font-size:11px;color:#666;text-transform:uppercase;margin-bottom:4px}
.input{width:100%;padding:8px 10px;border:1px solid #ddd;font-size:13px;outline:none;box-sizing:border-box}.input:focus{border-color:#2563eb}
.auto-list{border:1px solid #ddd;border-radius:4px;margin-top:2px;max-height:160px;overflow-y:auto}.auto-item{padding:6px 10px;cursor:pointer;font-size:12px}.auto-item:hover{background:#f5f5f5}.auto-code{font-family:'SF Mono',monospace;font-weight:500;color:#2563eb;margin-right:8px}
.modal-actions{display:flex;gap:8px}
/* AQL harmonisé */
.aql-list{display:flex;flex-direction:column;gap:0;border:1px solid #e8e8e8;border-radius:2px;overflow:hidden;margin-top:8px}
.aql-row{display:flex;align-items:center;gap:12px;padding:10px 14px;border-bottom:1px solid #f0f0f0;flex-wrap:wrap}
.aql-row:last-child{border-bottom:none}
.aql-left{min-width:110px}
.aql-type-lbl{font-size:12px;font-weight:500;color:#333}
.aql-type-val{font-family:'SF Mono',monospace;font-size:11px;font-weight:600;color:#2563eb;margin-left:3px;text-transform:uppercase}
.aql-date{font-family:'SF Mono',monospace;font-size:10px;color:#bbb;margin-top:2px}
.aql-mid{display:flex;align-items:center;gap:6px;flex:1;flex-wrap:wrap}
.aql-ar-badge{font-size:10px;color:#BA7517;background:#FFF8E1;border:1px solid #FFE082;padding:2px 6px;border-radius:8px}
.aql-acts{display:flex;gap:4px;flex-wrap:wrap}
@media(max-width:768px){
  .plan-grid{grid-template-columns:1fr}
  .plan-input{width:120px}
  .ks{grid-template-columns:repeat(3,1fr)}
  .k:nth-child(3){border-right:none}
  .k:nth-child(4),.k:nth-child(5){border-top:1px solid #e8e8e8}
  .k:nth-child(5){border-right:none}
  .lh{flex-direction:column;align-items:flex-start;gap:8px}
  .lh-right{flex-wrap:wrap}
  .ln{font-size:18px}
  .lp{display:block;margin-left:0;margin-top:2px}
  .dg{grid-template-columns:1fr}
  .di:nth-child(2n){border-right:1px solid #e8e8e8}
  .ct{font-size:12px}
  .ct td{padding:7px 4px}
  .cdt{display:none}
  .cs{width:40%}.cv{width:20%}.cac{width:40%}
  .action-btns{gap:6px}
  .btn-action{padding:8px 12px;min-height:38px}
  .modal{width:min(90vw,400px)}
  .lb{width:100%;padding:12px;font-size:14px;min-height:44px}
  .dev-form{flex-direction:column}
  .dev-form .btn{width:100%;min-height:44px;margin-left:0}
  .btn-sm{min-height:36px;padding:5px 12px}
}
@media(max-width:480px){
  .ks{grid-template-columns:repeat(2,1fr)}
  .k:nth-child(3){border-top:1px solid #e8e8e8;border-right:1px solid #e8e8e8}
  .k:nth-child(4){border-top:1px solid #e8e8e8;border-right:none}
  .k:nth-child(5){border-top:1px solid #e8e8e8;border-right:none;grid-column:span 2}
  .kv{font-size:14px}
  .section{margin-top:12px}
  .cv{display:none}
  .cs{width:50%}.cac{width:50%}
  .syg{grid-template-columns:1fr}
  .syc{border-right:1px solid #e8e8e8}
  .syc:nth-child(2n){border-right:1px solid #e8e8e8}
}
</style>
