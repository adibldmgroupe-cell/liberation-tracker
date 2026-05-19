<template>
  <div v-if="lot">
    <div class="bc"><span @click="goBack">← Retour aux lots</span></div>
    <div class="lh">
      <div><span class="ln">{{lot.numero_lot}}</span><span class="lp">{{prod.description}}</span></div>
      <div class="lh-right">
        <span class="sp" :class="'s-'+lot.statut_sap">{{statusLabels[lot.statut_sap]}}</span>
        <button v-if="isAdmin" class="btn-sm" @click="showModify=true">✏️ Modifier</button>
        <button v-if="isAdmin" class="btn-sm btn-del" @click="confirmDelete">🗑️ Supprimer</button>
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

    <!-- KPI -->
    <div class="ks">
      <div class="k"><div class="kv">{{ofV}}/6</div><div class="kl">OF</div></div>
      <div class="k"><div class="kv">{{ocV}}/6</div><div class="kl">OC</div></div>
      <div class="k"><div class="kv" :class="{'cw':docsOk<docsReq}">{{docsOk}}/{{docsReq}}</div><div class="kl">Docs</div></div>
      <div class="k"><div class="kv" :class="{'cd':devsOpen>0}">{{devsOpen}}</div><div class="kl">Dév.</div></div>
      <div class="k"><div class="kv">{{leadTime||'—'}}<span class="ku" v-if="leadTime">j</span></div><div class="kl">Lead time</div></div>
    </div>

    <!-- Circuit OF -->
    <div class="section" v-if="of"><div class="sh"><span>Circuit OF</span></div>
      <table class="ct"><tr v-for="e in circuitSteps" :key="'of-'+e.key">
        <td class="cs" :class="{'ca':of.etape_circuit===e.key}">{{e.label}}</td><td class="cv">{{e.service}}</td>
        <td class="cp"><span class="pip" :class="pipClass('of',e.key)"></span></td>
        <td class="cdt">{{getVal('of',e.key)?fmtDt(getVal('of',e.key).validated_at):''}}</td>
        <td class="cac"><span v-if="getVal('of',e.key)" class="cu">{{getVal('of',e.key).user}}</span>
          <button v-else-if="of.etape_circuit===e.key && canValidateStep('of',e.key)" class="btn" @click="doValidate('of',of.id,e.key)">Valider</button>
          <button v-else class="btn bd" disabled>Valider</button></td>
      </tr></table>
    </div>

    <!-- Circuit OC -->
    <div class="section" v-if="oc"><div class="sh"><span>Circuit OC</span></div>
      <table class="ct"><tr v-for="e in circuitSteps" :key="'oc-'+e.key">
        <td class="cs" :class="{'ca':oc.etape_circuit===e.key}">{{e.label}}</td><td class="cv">{{e.service}}</td>
        <td class="cp"><span class="pip" :class="pipClass('oc',e.key)"></span></td>
        <td class="cdt">{{getVal('oc',e.key)?fmtDt(getVal('oc',e.key).validated_at):''}}</td>
        <td class="cac"><span v-if="getVal('oc',e.key)" class="cu">{{getVal('oc',e.key).user}}</span>
          <button v-else-if="oc.etape_circuit===e.key && canValidateStep('oc',e.key)" class="btn" @click="doValidate('oc',oc.id,e.key)">Valider</button>
          <button v-else class="btn bd" disabled>Valider</button></td>
      </tr></table>
    </div>

    <!-- AQL -->
    <div class="section"><div class="sh"><span>AQL</span></div>
      <div class="action-btns">
        <button class="btn-action" @click="doRequestAql('fabrication')">Demander AQL Fabrication</button>
        <button class="btn-action" @click="doRequestAql('conditionnement')">Demander AQL Conditionnement</button>
      </div>
      <div v-if="!aqls.length" class="em">Aucune demande AQL</div>
      <table class="ct" v-else><tr v-for="a in aqls" :key="a.id">
        <td class="cs">AQL {{a.type}}</td>
        <td><span class="sp2" :class="a.resultat==='conforme'?'sp2-ok':a.resultat==='non_conforme'?'sp2-ko':'sp2-wait'">{{a.resultat==='en_attente'?'En attente':a.resultat==='conforme'?'Conforme':'Non conforme'}}</span></td>
        <td class="cdt">{{fmtDt(a.inspected_at||a.requested_at)}}</td>
        <td class="cac">
          <button v-if="a.resultat==='en_attente'" class="btn bg" @click="doAqlConforme(a.id)">Conforme</button>
          <button v-if="a.resultat==='en_attente'" class="btn br" @click="doAqlNonConforme(a.id)">Non conforme</button>
          <button v-if="a.resultat==='non_conforme'" class="btn" @click="doRelanceAql(a)">Relancer AQL</button>
        </td>
      </tr></table>
    </div>

    <!-- Documents -->
    <div class="section"><div class="sh"><span>Dossier de libération</span><span class="dc">{{docsOk}}/{{docsReq}}</span></div>
      <div class="dg">
        <div class="di" v-for="d in mainDocs" :key="d.id" :class="{'dna':!d.is_applicable}" @click="$router.push('/lots/'+lot.id+'/documents/'+d.id)">
          <div class="dind" :class="indClass(d)"></div>
          <div><div class="dn">{{docTypeLabel(d)}}</div><div class="ds" :class="dsClass(d)">{{docStatLabel(d)}}</div>
            <div class="ds-block" v-if="isDocBlocked(d)">⚠ AQL requis</div></div>
        </div>
      </div>
    </div>

    <!-- Déviations -->
    <div class="section"><div class="sh"><span>Déviations</span></div>
      <div class="action-btns"><button class="btn-action btn-orange" @click="showDevForm=!showDevForm">Déclarer déviation</button></div>
      <div class="dev-form" v-if="showDevForm">
        <textarea v-model="devObs" rows="2" placeholder="Observation (facultatif)..." class="dev-input"></textarea>
        <button class="btn" @click="doDeclareDeviation">Confirmer</button>
      </div>
      <div v-if="!devs.length" class="em">Aucune déviation</div>
      <table class="ct" v-else><tr v-for="d in devs" :key="d.id">
        <td class="mono cs">{{d.numero_deviation}}</td>
        <td><span class="sp2" :class="d.statut==='ouverte'?'sp2-ko':'sp2-ok'">{{d.statut==='ouverte'?'Ouverte':'Clôturée'}}</span></td>
        <td class="dim" style="max-width:200px;overflow:hidden;text-overflow:ellipsis">{{d.description||'—'}}</td>
        <td class="cac"><button v-if="d.statut==='ouverte'" class="btn-sm" @click="doCloseDeviation(d.id)">Clôturer</button></td>
      </tr></table>
    </div>

    <!-- RVP -->
    <div class="section"><div class="sh"><span>RVP</span></div>
      <div class="action-btns">
        <button class="btn-action btn-violet" @click="doDeclareRvp('rvp_fab')">RVP Fabrication</button>
        <button class="btn-action btn-violet" @click="doDeclareRvp('rvp_cond')">RVP Conditionnement</button>
        <button class="btn-action btn-violet" @click="doDeclareRvp('rvp_lcq')">RVP LCQ</button>
      </div>
      <div v-if="!rvpDocs.length" class="em">Aucun RVP</div>
      <div class="dg" v-else>
        <div class="di" v-for="d in rvpDocs" :key="d.id" @click="$router.push('/lots/'+lot.id+'/documents/'+d.id)">
          <div class="dind" :class="indClass(d)"></div>
          <div><div class="dn">RVP — {{rvpServiceLabel(d)}}</div><div class="ds" :class="dsClass(d)">{{docStatLabel(d)}}</div></div>
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
      <div class="lz"><button class="lb" :disabled="!dossierComplete" @click="doLiberer">{{dossierComplete?'Libérer le lot':'Conditions non remplies'}}</button></div>
    </div>
  </div>
  <div v-else class="loading">Chargement...</div>
</template>
<script>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { loadPermissions } from '../services/permissions'
import { validateOrder, getRequiredService, libererLot, declareDeviation, closeDeviation, declareRVP, requestAql, respondAql, isAqlConforme, modifyLot, deleteLot } from '../services/actions'
export default {
  setup() {
    var route = useRoute(), router = useRouter()
    var lot = ref(null), prod = ref({}), of = ref(null), oc = ref(null), ofVals = ref([]), ocVals = ref([])
    var docs = ref([]), devs = ref([]), aqls = ref([]), dossier = ref(null), userId = ref(null), userService = ref('')
    var showDevForm = ref(false), devObs = ref(''), showModify = ref(false)
    var editNumLot = ref(''), editCodeProd = ref(''), editProductId = ref(null), prodSuggestions = ref([])
    var aqlFabConforme = ref(false), aqlCondConforme = ref(false)

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
      var required = getRequiredService(orderType, etape)
      return userService.value === required
    }

    var getVal = function(type,etape){return (type==='of'?ofVals:ocVals).value.find(function(v){return v.etape===etape})}
    var pipClass = function(type,etape){if(getVal(type,etape))return'pip-done';var o=type==='of'?of.value:oc.value;return o&&o.etape_circuit===etape?'pip-active':'pip-wait'}
    var fmtDt = function(d){return d?new Date(d).toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}):''}

    var ofV = computed(function(){return ofVals.value.length})
    var ocV = computed(function(){return ocVals.value.length})
    var mainDocs = computed(function(){return docs.value.filter(function(d){return d.type_document!=='rvp'})})
    var rvpDocs = computed(function(){return docs.value.filter(function(d){return d.type_document==='rvp'})})
    var docsOk = computed(function(){return docs.value.filter(function(d){return d.statut==='approuve_dt'&&d.is_applicable}).length})
    var docsReq = computed(function(){return docs.value.filter(function(d){return d.is_applicable&&d.is_required}).length})
    var devsOpen = computed(function(){return devs.value.filter(function(d){return d.statut==='ouverte'||d.statut==='en_cours'}).length})
    var leadTime = computed(function(){if(!lot.value||!lot.value.date_enregistrement)return null;var end=lot.value.date_liberation||new Date().toISOString().split('T')[0];return Math.floor((new Date(end)-new Date(lot.value.date_enregistrement))/86400000)})
    var dossierComplete = computed(function(){return dossier.value&&dossier.value.if_approved&&dossier.value.ic_approved&&dossier.value.da_pc_approved&&(!dossier.value.da_micro_applicable||dossier.value.da_micro_approved)&&dossier.value.deviations_closed&&dossier.value.pieces_complementaires_ok})

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

    var doValidate = async function(type,orderId,etape){await validateOrder(type,orderId,etape,userId.value,lot.value.id);loadLot()}
    var doLiberer = async function(){await libererLot(lot.value.id,userId.value);loadLot()}
    var doDeclareDeviation = async function(){await declareDeviation(lot.value.id,devObs.value,userId.value);devObs.value='';showDevForm.value=false;loadLot()}
    var doCloseDeviation = async function(id){await closeDeviation(id,lot.value.id,userId.value);loadLot()}
    var doDeclareRvp = async function(type){await declareRVP(lot.value.id,type,userId.value);loadLot()}
    var doRequestAql = async function(type){await requestAql(lot.value.id,type,userId.value);loadLot()}
    var doAqlConforme = async function(id){await respondAql(id,'conforme','',userId.value,lot.value.id);loadLot()}
    var doAqlNonConforme = async function(id){var reco=prompt('Recommandations :');await respondAql(id,'non_conforme',reco||'',userId.value,lot.value.id);loadLot()}
    var doRelanceAql = async function(a){await requestAql(lot.value.id,a.type,userId.value);loadLot()}

    var searchProd = async function(){
      if(editCodeProd.value.length<2){prodSuggestions.value=[];return}
      var res = await supabase.from('products').select('id,code_article,description').or('code_article.ilike.%'+editCodeProd.value+'%,description.ilike.%'+editCodeProd.value+'%').limit(5)
      prodSuggestions.value = res.data || []
    }
    var selectProd = function(p){editCodeProd.value=p.code_article;editProductId.value=p.id;prodSuggestions.value=[]}
    var doModify = async function(){
      if(!editNumLot.value)return
      await modifyLot(lot.value.id, editNumLot.value, editProductId.value || lot.value.product_id)
      showModify.value=false;loadLot()
    }
    var confirmDelete = async function(){
      if(!confirm('Supprimer le lot '+lot.value.numero_lot+' ? Cette action est irréversible.'))return
      await deleteLot(lot.value.id);router.push('/lots')
    }

    var loadLot = async function(){
      var l=(await supabase.from('lots').select('*').eq('id',route.params.id).single()).data;lot.value=l
      prod.value=(await supabase.from('products').select('*').eq('id',l.product_id).single()).data||{}
      editNumLot.value=l.numero_lot;editCodeProd.value=prod.value.code_article||''
      of.value=(await supabase.from('orders_of').select('*').eq('lot_id',l.id).maybeSingle()).data
      oc.value=(await supabase.from('orders_oc').select('*').eq('lot_id',l.id).maybeSingle()).data
      if(of.value){var ov=(await supabase.from('order_validations').select('*,profiles(prenom,nom)').eq('order_type','of').eq('order_id',of.value.id).order('validated_at')).data;ofVals.value=(ov||[]).map(function(v){return{etape:v.etape,validated_at:v.validated_at,user:v.profiles?v.profiles.prenom+' '+v.profiles.nom:''}})}
      if(oc.value){var ov2=(await supabase.from('order_validations').select('*,profiles(prenom,nom)').eq('order_type','oc').eq('order_id',oc.value.id).order('validated_at')).data;ocVals.value=(ov2||[]).map(function(v){return{etape:v.etape,validated_at:v.validated_at,user:v.profiles?v.profiles.prenom+' '+v.profiles.nom:''}})}
      docs.value=(await supabase.from('liberation_documents').select('*').eq('lot_id',l.id)).data||[]
      devs.value=(await supabase.from('deviations').select('*').eq('lot_id',l.id).order('declared_at')).data||[]
      aqls.value=(await supabase.from('aql_inspections').select('*').eq('lot_id',l.id).order('created_at',{ascending:false})).data||[]
      dossier.value=(await supabase.from('liberation_dossiers').select('*').eq('lot_id',l.id).maybeSingle()).data
      aqlFabConforme.value=await isAqlConforme(l.id,'fabrication')
      aqlCondConforme.value=await isAqlConforme(l.id,'conditionnement')
    }

    onMounted(async function(){
      var u=await supabase.auth.getUser();userId.value=u.data.user.id
      var p=await supabase.from('profiles').select('service').eq('id',u.data.user.id).single()
      if(p.data){userService.value=p.data.service;await loadPermissions(p.data.service)}
      await loadLot()
    })

    return{lot,prod,of,oc,ofVals,ocVals,docs,devs,aqls,dossier,statusLabels,circuitSteps,isAdmin,
      showDevForm,devObs,showModify,editNumLot,editCodeProd,prodSuggestions,rvpDocs,mainDocs,
      getVal,pipClass,fmtDt,ofV,ocV,docsOk,docsReq,devsOpen,leadTime,dossierComplete,canValidateStep,
      docTypeLabel,docStatLabel,indClass,dsClass,rvpServiceLabel,isDocBlocked,goBack,
      doValidate,doLiberer,doDeclareDeviation,doCloseDeviation,doDeclareRvp,doRequestAql,doAqlConforme,doAqlNonConforme,doRelanceAql,
      searchProd,selectProd,doModify,confirmDelete}
  }
}
</script>
<style scoped>
.bc{font-size:12px;color:#185FA5;cursor:pointer;margin-bottom:8px}
.lh{display:flex;align-items:center;justify-content:space-between;padding-bottom:8px;border-bottom:2px solid #0a0a0a;flex-wrap:wrap;gap:8px}
.lh-right{display:flex;align-items:center;gap:6px}
.ln{font-size:22px;font-weight:500;font-family:'SF Mono',monospace}.lp{font-size:13px;color:#666;margin-left:10px}
.sp{font-size:11px;font-weight:500;padding:3px 10px;border-radius:2px}
.s-quarantaine{background:#FFA94D;color:#412402}.s-accepte{background:#1D9E75;color:#fff}.s-sous_investigation{background:#E24B4A;color:#fff}.s-vide{background:#e8e8e8;color:#666}.s-refuse{background:#666;color:#fff}
.loading{text-align:center;padding:60px;color:#999}
.btn-sm{font-size:11px;padding:3px 10px;border:1px solid #ddd;border-radius:3px;background:#fff;cursor:pointer;color:#666}.btn-sm:hover{background:#f5f5f5}
.btn-del{border-color:#E24B4A;color:#E24B4A}.btn-del:hover{background:#FCEBEB}
.ks{display:grid;grid-template-columns:repeat(5,1fr);border:1px solid #e8e8e8;margin:10px 0}
.k{padding:10px 8px;text-align:center;border-right:1px solid #e8e8e8}.k:last-child{border-right:none}
.kv{font-size:16px;font-weight:500;font-family:'SF Mono',monospace}.ku{font-size:11px;color:#999}.kl{font-size:10px;color:#999;text-transform:uppercase;margin-top:2px}
.cw{color:#BA7517}.cd{color:#E24B4A}
.section{margin-top:16px}.sh{display:flex;justify-content:space-between;align-items:center;font-size:10px;font-weight:500;text-transform:uppercase;letter-spacing:1px;color:#999;padding-bottom:6px;border-bottom:1px solid #e8e8e8}
.dc{font-family:'SF Mono',monospace;color:#BA7517}
.action-btns{display:flex;gap:8px;margin:10px 0;flex-wrap:wrap}
.btn-action{font-size:12px;padding:8px 16px;border-radius:4px;border:none;cursor:pointer;font-weight:500;background:#185FA5;color:#fff}.btn-action:hover{background:#0C447C}
.btn-orange{background:#BA7517}.btn-orange:hover{background:#8B5A12}
.btn-violet{background:#5B3CC4}.btn-violet:hover{background:#4A2FA3}
.ct{width:100%;border-collapse:collapse;font-size:13px}.ct td{padding:8px;border-bottom:1px solid #f5f5f5}
.cs{width:30%}.ca{font-weight:500}.cv{width:14%;color:#999;font-size:12px}.cp{width:8%;text-align:center}.cdt{width:22%;text-align:right;font-family:'SF Mono',monospace;font-size:12px;color:#666}.cac{width:26%;text-align:right}
.cu{font-size:12px;color:#999}
.pip{display:inline-block;width:8px;height:8px;border-radius:50%}.pip-done{background:#1D9E75}.pip-active{background:#185FA5;box-shadow:0 0 0 3px rgba(24,95,165,.12)}.pip-wait{background:#e8e8e8}
.btn{font-size:12px;padding:5px 14px;border-radius:2px;border:none;cursor:pointer;font-weight:500;background:#185FA5;color:#fff;margin-left:4px}.btn:hover{background:#0C447C}.bd{background:#f5f5f5;color:#ccc;cursor:not-allowed}
.br{background:#E24B4A}.bg{background:#1D9E75}.bc2{background:#f5f5f5;color:#666}
.dg{display:grid;grid-template-columns:1fr 1fr;border:1px solid #e8e8e8}
.di{padding:10px 12px;border-right:1px solid #e8e8e8;border-bottom:1px solid #e8e8e8;display:flex;gap:10px;cursor:pointer}.di:hover{background:#fafafa}.di:nth-child(2n){border-right:none}.dna{opacity:.35}
.dind{width:3px;height:28px;border-radius:1px;flex-shrink:0}.ind-wait{background:#e8e8e8}.ind-prog{background:#185FA5}.ind-done{background:#1D9E75}.ind-ret{background:#E24B4A}.ind-na{background:#e8e8e8;opacity:.3}
.dn{font-size:13px;font-weight:500}.ds{font-size:11px;color:#999;margin-top:1px}.ds-ok{color:#1D9E75}.ds-ret{color:#E24B4A}.ds-na{color:#ccc}
.ds-block{font-size:10px;color:#BA7517;margin-top:2px}
.sp2{font-size:11px;padding:2px 8px;border-radius:2px;font-weight:500}.sp2-ok{background:#EAF3DE;color:#3B6D11}.sp2-ko{background:#FCEBEB;color:#A32D2D}.sp2-wait{background:#f5f5f5;color:#999}
.dev-form{display:flex;gap:8px;align-items:flex-start;margin:10px 0}.dev-input{flex:1;border:1px solid #ddd;padding:6px 8px;font-size:13px;resize:vertical;font-family:inherit;border-radius:2px}
.dim{color:#999;font-size:12px}.mono{font-family:'SF Mono',monospace;font-size:12px}
.em{font-size:12px;color:#999;padding:12px 0;text-align:center}
.syg{display:grid;grid-template-columns:1fr 1fr;border:1px solid #e8e8e8}.syc{padding:8px 12px;border-right:1px solid #e8e8e8;border-bottom:1px solid #e8e8e8;display:flex;justify-content:space-between;font-size:13px}.syc:nth-child(2n){border-right:none}.syc span:first-child{color:#666}
.ok{color:#1D9E75;font-weight:500}.ko{color:#E24B4A;font-weight:500}.na{color:#ccc}
.lz{text-align:center;padding:14px 0}.lb{padding:10px 32px;font-size:13px;font-weight:500;background:#185FA5;color:#fff;border:none;border-radius:2px;cursor:pointer}.lb:disabled{opacity:.4;cursor:not-allowed}.lb:hover:not(:disabled){background:#0C447C}
.modal-overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:100}
.modal{background:#fff;padding:24px;width:400px;border-radius:4px}.modal-title{font-size:16px;font-weight:500;margin-bottom:16px}
.field{margin-bottom:14px}.field label{display:block;font-size:11px;color:#666;text-transform:uppercase;margin-bottom:4px}
.input{width:100%;padding:8px 10px;border:1px solid #ddd;font-size:13px;outline:none;box-sizing:border-box}.input:focus{border-color:#185FA5}
.auto-list{border:1px solid #ddd;border-radius:4px;margin-top:2px;max-height:160px;overflow-y:auto}.auto-item{padding:6px 10px;cursor:pointer;font-size:12px}.auto-item:hover{background:#f5f5f5}.auto-code{font-family:'SF Mono',monospace;font-weight:500;color:#185FA5;margin-right:8px}
.modal-actions{display:flex;gap:8px}
@media(max-width:768px){
  .ks{grid-template-columns:repeat(3,1fr)}.lh{flex-direction:column;align-items:flex-start}
  .dg{grid-template-columns:1fr}.di:nth-child(2n){border-right:1px solid #e8e8e8}
  .ct td{padding:6px 4px;font-size:12px}.action-btns{flex-direction:column}
  .modal{width:90%;margin:0 5%}
}
</style>
