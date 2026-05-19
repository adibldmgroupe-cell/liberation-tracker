<template>
  <div>
    <div class="ph">
      <span class="pt">LOTS</span>
      <div class="ph-right">
        <span class="pc" v-if="total">{{total}} lots</span>
        <button class="btn-toggle" @click="showDates=!showDates">{{showDates?'Voir statuts':'Voir dates'}}</button>
        <button class="btn-exp" @click="doExportExcel">📥 Excel</button>
        <button class="btn-exp" @click="doExportPDF">📄 PDF</button>
      </div>
    </div>
    <div class="filters">
      <button v-for="f in filterOptions" :key="f.value" class="fbtn" :class="{active:activeFilters.includes(f.value)}" @click="toggleFilter(f.value)">
        <span class="fdot" :style="{background:f.color}"></span>{{f.label}}
      </button>
    </div>
    <!-- Barre d'actions en masse -->
    <div class="bulk-bar">
      <select v-model="actionType" class="bulk-sel">
        <option value="">— Choisir une action —</option>
        <template v-for="grp in actionGroups" :key="grp.label">
          <optgroup :label="grp.label">
            <option v-for="opt in grp.actions" :key="opt.value" :value="opt.value">{{opt.label}}</option>
          </optgroup>
        </template>
      </select>
      <button class="bulk-btn" :disabled="!canExecute" @click="showConfirm=true">
        Exécuter<span v-if="selected.length"> ({{selected.length}})</span>
      </button>
      <span v-if="selected.length" class="bulk-info">{{selected.length}} lot(s) sélectionné(s)</span>
      <button v-if="selected.length" class="bulk-clear" @click="selected=[]">✕ Tout désélectionner</button>
    </div>

    <!-- Chips filtres colonnes actifs -->
    <div v-if="hasColumnFilters" class="cf-bar">
      <span class="cf-label">Filtres actifs :</span>
      <span v-for="(val,col) in columnFilters" :key="col" class="cf-chip">
        {{col}} : <strong>{{val}}</strong>
        <button class="cf-rm" @click="removeColumnFilter(col)">✕</button>
      </span>
      <button class="cf-clear" @click="clearColumnFilters">Tout effacer</button>
    </div>

    <div v-if="!filteredLots.length" class="empty">Aucun lot trouvé</div>
    <div v-else class="table-wrap">
      <table class="tb">
        <thead><tr>
          <th class="th-chk"><input type="checkbox" :checked="allVisibleChecked" @change="toggleAll" /></th>
          <th class="th-s"><span class="th-txt" @click="sortBy('numero_lot')">N° Lot <span class="sort-arrow">{{sortIcon('numero_lot')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['numero_lot']}" @click="openDropdown('numero_lot',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt" @click="sortBy('prod_desc')">Produit <span class="sort-arrow">{{sortIcon('prod_desc')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['prod_desc']}" @click="openDropdown('prod_desc',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt" @click="sortBy('statut_label')">Statut <span class="sort-arrow">{{sortIcon('statut_label')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['statut_label']}" @click="openDropdown('statut_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt" @click="sortBy('of_label')">OF <span class="sort-arrow">{{sortIcon('of_label')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['of_label']}" @click="openDropdown('of_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt" @click="sortBy('oc_label')">OC <span class="sort-arrow">{{sortIcon('oc_label')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['oc_label']}" @click="openDropdown('oc_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt">AQL Fab</span><button class="th-f" :class="{'th-f-on':columnFilters['aql_fab_label']}" @click="openDropdown('aql_fab_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt">AQL Cond</span><button class="th-f" :class="{'th-f-on':columnFilters['aql_cond_label']}" @click="openDropdown('aql_cond_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt" @click="sortBy('if_label')">IF <span class="sort-arrow">{{sortIcon('if_label')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['if_label']}" @click="openDropdown('if_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt" @click="sortBy('ic_label')">IC <span class="sort-arrow">{{sortIcon('ic_label')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['ic_label']}" @click="openDropdown('ic_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt">DA PC</span><button class="th-f" :class="{'th-f-on':columnFilters['dapc_label']}" @click="openDropdown('dapc_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt">DA Micro</span><button class="th-f" :class="{'th-f-on':columnFilters['damicro_label']}" @click="openDropdown('damicro_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt">Dév.</span><button class="th-f" :class="{'th-f-on':columnFilters['dev_label']}" @click="openDropdown('dev_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt">RVP Fab</span><button class="th-f" :class="{'th-f-on':columnFilters['rvp_fab_label']}" @click="openDropdown('rvp_fab_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt">RVP Cond</span><button class="th-f" :class="{'th-f-on':columnFilters['rvp_cond_label']}" @click="openDropdown('rvp_cond_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt">RVP LCQ</span><button class="th-f" :class="{'th-f-on':columnFilters['rvp_lcq_label']}" @click="openDropdown('rvp_lcq_label',$event)">⌄</button></th>
          <th class="th-s"><span class="th-txt" @click="sortBy('date_fmt')">{{showDates?'Libération':'Entrée'}} <span class="sort-arrow">{{sortIcon('date_fmt')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['date_fmt']}" @click="openDropdown('date_fmt',$event)">⌄</button></th>
        </tr></thead>
        <tbody><tr v-for="l in filteredLots" :key="l.id" :class="{'row-sel':isSelected(l.id)}" @click="goToLot(l.id)">
          <td class="td-chk" @click.stop><input type="checkbox" :value="l.id" v-model="selected" /></td>
          <td class="mono bold">{{l.numero_lot}}</td>
          <td class="td-prod">{{l.prod_desc}}<span class="code">{{l.prod_code}}</span></td>
          <td><span class="sp" :class="l.statut_class">{{l.statut_label}}</span></td>
          <td><span class="doc-pip" :class="showDates&&l.of_date?'dc-date':l.of_done?'pip-done-t':'pip-prog-t'">{{showDates&&l.of_date?l.of_date:l.of_label}}</span></td>
          <td><span class="doc-pip" :class="showDates&&l.oc_date?'dc-date':l.oc_done?'pip-done-t':'pip-prog-t'">{{showDates&&l.oc_date?l.oc_date:l.oc_label}}</span></td>
          <td><span class="doc-pip" :class="l.aql_fab_class">{{showDates&&l.aql_fab_date?l.aql_fab_date:l.aql_fab_label}}</span></td>
          <td><span class="doc-pip" :class="l.aql_cond_class">{{showDates&&l.aql_cond_date?l.aql_cond_date:l.aql_cond_label}}</span></td>
          <td><span class="doc-pip" :class="showDates&&l.if_date?'dc-date':l.if_class">{{showDates&&l.if_date?l.if_date:l.if_label}}</span></td>
          <td><span class="doc-pip" :class="showDates&&l.ic_date?'dc-date':l.ic_class">{{showDates&&l.ic_date?l.ic_date:l.ic_label}}</span></td>
          <td><span class="doc-pip" :class="showDates&&l.dapc_date?'dc-date':l.dapc_class">{{showDates&&l.dapc_date?l.dapc_date:l.dapc_label}}</span></td>
          <td><span class="doc-pip" :class="showDates&&l.damicro_date?'dc-date':l.damicro_class">{{showDates&&l.damicro_date?l.damicro_date:l.damicro_label}}</span></td>
          <td><span v-if="l.dev_count>0" class="dev-badge" :class="l.dev_open>0?'dev-open':'dev-closed'">{{l.dev_open>0?'Ouverte':'Clôturée'}}</span><span v-else class="dim">—</span></td>
          <td><span class="doc-pip" :class="l.rvp_fab_class">{{l.rvp_fab_label}}</span></td>
          <td><span class="doc-pip" :class="l.rvp_cond_class">{{l.rvp_cond_label}}</span></td>
          <td><span class="doc-pip" :class="l.rvp_lcq_class">{{l.rvp_lcq_label}}</span></td>
          <td class="mono dim">{{showDates?(l.date_lib||l.date_fmt):l.date_fmt}}</td>
        </tr></tbody>
      </table>
    </div>
    <!-- Dropdown filtre colonne (position:fixed) -->
    <div v-if="activeDropdown" class="col-dd" :style="{top:ddPos.top+'px',left:ddPos.left+'px'}" @click.stop>
      <div class="col-dd-item col-dd-all" @click="setColumnFilter(null)">— Tout —</div>
      <div v-for="v in getColumnValues(activeDropdown)" :key="v" class="col-dd-item" :class="{'col-dd-on':columnFilters[activeDropdown]===v}" @click="setColumnFilter(v)">{{v}}</div>
    </div>

    <!-- Modal confirmation action en masse -->
    <div class="m-overlay" v-if="showConfirm" @click.self="showConfirm=false">
      <div class="m-box">
        <div class="m-title">Confirmer l'action en masse</div>
        <div class="m-body">
          <div class="m-line"><span class="m-lbl">Action</span><span>{{actionLabel}}</span></div>
          <div class="m-line"><span class="m-lbl">Lots concernés</span><span class="mono">{{selected.length}}</span></div>
          <div class="m-chips">
            <span v-for="id in selected.slice(0,20)" :key="id" class="m-chip">{{getLotNum(id)}}</span>
            <span v-if="selected.length>20" class="m-chip m-more">+{{selected.length-20}} autres</span>
          </div>
        </div>
        <div class="m-result" v-if="execResult">
          <div class="m-rh">Exécution terminée</div>
          <div class="m-rg">
            <div class="m-rc"><div class="m-rv" style="color:#1D9E75">{{execResult.ok}}</div><div class="m-rl">Réussis</div></div>
            <div class="m-rc"><div class="m-rv" style="color:#E24B4A">{{execResult.fail}}</div><div class="m-rl">Échoués</div></div>
          </div>
          <div v-if="execResult.errors.length" class="m-errs">
            <div v-for="(e,i) in execResult.errors" :key="i" class="m-err">{{e}}</div>
          </div>
        </div>
        <div class="m-actions">
          <button class="m-btn-ok" @click="executeAction" :disabled="executing">{{executing?'En cours... '+progress+'/'+selected.length:'Confirmer'}}</button>
          <button class="m-btn-cancel" @click="showConfirm=false;execResult=null">Annuler</button>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { exportToExcel, exportToPDF } from '../services/export'
import { createNotification } from '../services/notifications'
import { canPerform, loadPermissions, getPermissionForBulkAction } from '../services/permissions'
export default {
  setup() {
    var route = useRoute(), router = useRouter()
    var lots = ref([]), total = ref(0), activeFilters = ref([])
    var sortCol = ref(''), sortDir = ref('asc'), showDates = ref(false)
    var selected = ref([]), actionType = ref(''), showConfirm = ref(false)
    var executing = ref(false), progress = ref(0), execResult = ref(null)
    var userService = ref('')

    // ── Autorisation via table permissions DB (canPerform) ─────────────
    var canAction = function(action) {
      if (userService.value === 'admin') return true
      var permKey = getPermissionForBulkAction(action)
      return permKey ? canPerform(permKey) : false
    }

    // ── Définition complète des groupes d'actions ───────────────────────
    var actionGroupDefs = [
      {label:'Circuit OF',actions:[{value:'of_planification',label:'OF — Mise en circuit'},{value:'of_stock',label:'OF — Validation Stock'},{value:'of_aq',label:'OF — Validation AQ'},{value:'of_dt',label:'OF — Autorisation DT'},{value:'of_aq_dap',label:'OF — Remise AQ DAP'},{value:'of_production',label:'OF — Accusé réception'}]},
      {label:'Circuit OC',actions:[{value:'oc_planification',label:'OC — Mise en circuit'},{value:'oc_stock',label:'OC — Validation Stock'},{value:'oc_aq',label:'OC — Validation AQ'},{value:'oc_dt',label:'OC — Autorisation DT'},{value:'oc_aq_dap',label:'OC — Remise AQ DAP'},{value:'oc_production',label:'OC — Accusé réception'}]},
      {label:'Documents — Émission',actions:[{value:'doc_if',label:'IF — Émettre'},{value:'doc_ic',label:'IC — Émettre'},{value:'doc_da_pc',label:'DA Physico — Émettre'},{value:'doc_da_micro',label:'DA Micro — Émettre'}]},
      {label:'Documents — Vérification AQ → DT',actions:[{value:'doc_if_verifier',label:'IF — Vérifier AQ → DT'},{value:'doc_ic_verifier',label:'IC — Vérifier AQ → DT'},{value:'doc_da_pc_verifier',label:'DA Physico — Vérifier AQ → DT'},{value:'doc_da_micro_verifier',label:'DA Micro — Vérifier AQ → DT'}]},
      {label:'Documents — Approbation DT',actions:[{value:'doc_if_approuver',label:'IF — Approuver DT'},{value:'doc_ic_approuver',label:'IC — Approuver DT'},{value:'doc_da_pc_approuver',label:'DA Physico — Approuver DT'},{value:'doc_da_micro_approuver',label:'DA Micro — Approuver DT'}]},
      {label:'Documents — Retour',actions:[{value:'doc_if_retour_emetteur',label:"IF — Retourner à l'émetteur"},{value:'doc_ic_retour_emetteur',label:"IC — Retourner à l'émetteur"},{value:'doc_da_pc_retour_emetteur',label:"DA Physico — Retourner à l'émetteur"},{value:'doc_da_micro_retour_emetteur',label:"DA Micro — Retourner à l'émetteur"},{value:'doc_if_retour_aq',label:"IF — DT retourne à l'AQ"},{value:'doc_ic_retour_aq',label:"IC — DT retourne à l'AQ"},{value:'doc_da_pc_retour_aq',label:"DA Physico — DT retourne à l'AQ"},{value:'doc_da_micro_retour_aq',label:"DA Micro — DT retourne à l'AQ"}]},
      {label:'AQL',actions:[{value:'aql_fab_demander',label:'AQL Fabrication — Demander'},{value:'aql_fab_relancer',label:'AQL Fabrication — Relancer'},{value:'aql_fab_conforme',label:'AQL Fabrication — Conforme'},{value:'aql_fab_non_conforme',label:'AQL Fabrication — Non conforme'},{value:'aql_cond_demander',label:'AQL Conditionnement — Demander'},{value:'aql_cond_relancer',label:'AQL Conditionnement — Relancer'},{value:'aql_cond_conforme',label:'AQL Conditionnement — Conforme'},{value:'aql_cond_non_conforme',label:'AQL Conditionnement — Non conforme'}]},
      {label:'RVP — Émission',actions:[{value:'rvp_fab_emettre',label:'RVP Fabrication — Émettre'},{value:'rvp_cond_emettre',label:'RVP Conditionnement — Émettre'},{value:'rvp_lcq_emettre',label:'RVP LCQ — Émettre'}]},
      {label:'RVP — Vérification AQ → DT',actions:[{value:'rvp_fab_verifier',label:'RVP Fabrication — Vérifier AQ → DT'},{value:'rvp_cond_verifier',label:'RVP Conditionnement — Vérifier AQ → DT'},{value:'rvp_lcq_verifier',label:'RVP LCQ — Vérifier AQ → DT'}]},
      {label:'RVP — Approbation DT',actions:[{value:'rvp_fab_approuver',label:'RVP Fabrication — Approuver DT'},{value:'rvp_cond_approuver',label:'RVP Conditionnement — Approuver DT'},{value:'rvp_lcq_approuver',label:'RVP LCQ — Approuver DT'}]},
      {label:'RVP — Retour',actions:[{value:'rvp_fab_retour_emetteur',label:"RVP Fabrication — Retourner à l'émetteur"},{value:'rvp_cond_retour_emetteur',label:"RVP Conditionnement — Retourner à l'émetteur"},{value:'rvp_lcq_retour_emetteur',label:"RVP LCQ — Retourner à l'émetteur"},{value:'rvp_fab_retour_aq',label:"RVP Fabrication — DT retourne à l'AQ"},{value:'rvp_cond_retour_aq',label:"RVP Conditionnement — DT retourne à l'AQ"},{value:'rvp_lcq_retour_aq',label:"RVP LCQ — DT retourne à l'AQ"}]},
      {label:'Déviation',actions:[{value:'dev_declarer',label:'Déviation — Déclarer'},{value:'dev_cloture',label:'Déviation — Clôturer'}]},
    ]
    var actionGroups = computed(function(){
      return actionGroupDefs.map(function(g){
        return {label:g.label,actions:g.actions.filter(function(a){return canAction(a.value)})}
      }).filter(function(g){return g.actions.length>0})
    })
    // ───────────────────────────────────────────────────────────────────

    var statusLabels = {vide:'Planifié',quarantaine:'Quarantaine',sous_investigation:'Investigation',accepte:'Accepté',refuse:'Refusé'}
    var filterOptions = [
      {label:'Planifié',value:'planifie',color:'#999'},
      {label:'En préparation',value:'en_preparation',color:'#5B3CC4'},
      {label:'En production',value:'en_production',color:'#185FA5'},
      {label:'Quarantaine',value:'quarantaine',color:'#FFA94D'},
      {label:'Investigation',value:'sous_investigation',color:'#E24B4A'},
      {label:'Acceptés',value:'accepte',color:'#1D9E75'},
      {label:'Refusé',value:'refuse',color:'#666'},
    ]
    var etapeLabels = {planification:'Planif.',stock:'Stock',aq:'AQ',dt:'DT',aq_dap:'AQ DAP',production:'Prod.'}
    var docStatutLabels = {non_emis:'Non émis',emis:'Émis',verification_aq:'Vérif AQ',retour_emetteur:'Retourné',rectification:'Rectif.',approuve_aq:'Appr. AQ',approbation_dt:'Appr. DT',approuve_dt:'Approuvé'}
    var fmt = function(d){return d?new Date(d).toLocaleDateString('fr-FR'):'—'}

    var getGranularStatus = function(of,oc,docs,statutSap) {
      if (statutSap === 'accepte') return {label:'Accepté',cls:'s-accepte',filter:'accepte'}
      if (statutSap === 'quarantaine') return {label:'Quarantaine',cls:'s-quarantaine',filter:'quarantaine'}
      if (statutSap === 'sous_investigation') return {label:'Investigation',cls:'s-sous_investigation',filter:'sous_investigation'}
      if (statutSap === 'refuse') return {label:'Refusé',cls:'s-refuse',filter:'refuse'}
      var anyDocEmis = false
      if(docs){for(var i=0;i<docs.length;i++){var t=docs[i].type_document;if((t==='if'||t==='ic'||t==='da_pc'||t==='da_micro')&&docs[i].statut!=='non_emis'){anyDocEmis=true;break}}}
      if(anyDocEmis)return{label:'En production',cls:'s-enprod',filter:'en_production'}
      var ofRecu=of&&(of.etape_circuit==='production'||of.statut==='termine')
      var ocRecu=oc&&(oc.etape_circuit==='production'||oc.statut==='termine')
      if(ofRecu||ocRecu)return{label:'En production',cls:'s-enprod',filter:'en_production'}
      var ofStarted=of&&of.etape_circuit!=='planification'
      var ocStarted=oc&&oc.etape_circuit!=='planification'
      if(ofStarted||ocStarted)return{label:'En préparation',cls:'s-enprep',filter:'en_preparation'}
      return{label:'Planifié',cls:'s-vide',filter:'planifie'}
    }

    var getDocInfo = function(docs,type){
      var d=null;if(docs){for(var i=0;i<docs.length;i++){if(docs[i].type_document===type){d=docs[i];break}}}
      if(!d)return{label:'—',cls:'dc-na',date:null}
      if(!d.is_applicable)return{label:'N/A',cls:'dc-na',date:null}
      var label=docStatutLabels[d.statut]||d.statut
      var cls='dc-wait';if(d.statut==='approuve_dt')cls='dc-ok';else if(d.statut==='retour_emetteur')cls='dc-ret';else if(d.statut!=='non_emis')cls='dc-prog'
      var date=d.approved_at||d.emitted_at;return{label:label,cls:cls,date:date?fmt(date):null}
    }

    var getRvpInfo = function(docs,emetteur){
      var d=null;if(docs){for(var i=0;i<docs.length;i++){if(docs[i].type_document==='rvp'&&docs[i].service_emetteur===emetteur){d=docs[i];break}}}
      if(!d)return{label:'—',cls:'dc-na'}
      var label=docStatutLabels[d.statut]||d.statut
      var cls='dc-wait';if(d.statut==='approuve_dt')cls='dc-ok';else if(d.statut==='retour_emetteur')cls='dc-ret';else if(d.statut!=='non_emis')cls='dc-prog'
      return{label:label,cls:cls}
    }

    var getAqlInfo = function(aqls,type){
      if(!aqls||!aqls.length)return{label:'—',cls:'dc-na',date:null}
      var latest=null;for(var i=0;i<aqls.length;i++){if(aqls[i].type===type){if(!latest||new Date(aqls[i].requested_at||0)>new Date(latest.requested_at||0))latest=aqls[i]}}
      if(!latest)return{label:'—',cls:'dc-na',date:null}
      if(latest.resultat==='conforme')return{label:'Conforme',cls:'dc-ok',date:latest.inspected_at?fmt(latest.inspected_at):null}
      if(latest.resultat==='non_conforme')return{label:'Non conf.',cls:'dc-ret',date:latest.inspected_at?fmt(latest.inspected_at):null}
      return{label:'En attente',cls:'dc-prog',date:latest.requested_at?fmt(latest.requested_at):null}
    }

    var getOfOcInfo = function(order,statutSap){
      var inStock=statutSap==='quarantaine'||statutSap==='sous_investigation'||statutSap==='accepte'||statutSap==='refuse'
      if(inStock)return{label:'Terminé',done:true,date:null}
      if(!order)return{label:'—',done:false,date:null}
      if(order.statut==='termine')return{label:'Terminé',done:true,date:order.updated_at?fmt(order.updated_at):null}
      return{label:etapeLabels[order.etape_circuit]||order.etape_circuit||'—',done:false,date:order.updated_at?fmt(order.updated_at):null}
    }

    var load = async function() {
      var query = supabase.from('lots').select('*, products(code_article,description), orders_of(id,statut,etape_circuit,updated_at), orders_oc(id,statut,etape_circuit,updated_at), liberation_documents(id,type_document,statut,is_applicable,service_emetteur,emitted_at,approved_at), deviations(statut), aql_inspections(type,resultat,requested_at,inspected_at)', {count:'exact'})

      var q = route.query.q
      if(q){
        var matchRes=await supabase.from('products').select('id').or('code_article.ilike.%'+q+'%,description.ilike.%'+q+'%')
        var prodIds=(matchRes.data||[]).map(function(p){return p.id})
        if(prodIds.length){query=query.or('numero_lot.ilike.%'+q+'%,product_id.in.('+prodIds.join(',')+')')}
        else{query=query.ilike('numero_lot','%'+q+'%')}
      }

      query=query.order('date_enregistrement',{ascending:false,nullsFirst:false})
      var result=await query
      total.value=result.count||(result.data?result.data.length:0)

      lots.value=(result.data||[]).map(function(l){
        var docs=l.liberation_documents||[]
        var devs=l.deviations||[]
        var aqls=l.aql_inspections||[]
        var of=Array.isArray(l.orders_of)?l.orders_of[0]:l.orders_of
        var oc=Array.isArray(l.orders_oc)?l.orders_oc[0]:l.orders_oc

        var statutInfo=getGranularStatus(of,oc,docs,l.statut_sap)
        var ofInfo=getOfOcInfo(of,l.statut_sap)
        var ocInfo=getOfOcInfo(oc,l.statut_sap)
        var ifInfo=getDocInfo(docs,'if')
        var icInfo=getDocInfo(docs,'ic')
        var dapcInfo=getDocInfo(docs,'da_pc')
        var damicroInfo=getDocInfo(docs,'da_micro')
        var aqlFab=getAqlInfo(aqls,'fabrication')
        var aqlCond=getAqlInfo(aqls,'conditionnement')
        var rvpFab=getRvpInfo(docs,'fabrication')
        var rvpCond=getRvpInfo(docs,'conditionnement')
        var rvpLcq=getRvpInfo(docs,'lcq')

        var devOpen=0;for(var j=0;j<devs.length;j++){if(devs[j].statut==='ouverte'||devs[j].statut==='en_cours')devOpen++}

        return{
          id:l.id,numero_lot:l.numero_lot,statut_sap:l.statut_sap,
          statut_label:statutInfo.label,statut_class:statutInfo.cls,statut_filter:statutInfo.filter,
          date_fmt:fmt(l.date_enregistrement),date_lib:l.date_liberation?fmt(l.date_liberation):null,
          prod_desc:l.products?l.products.description:'',prod_code:l.products?l.products.code_article:'',
          of_label:ofInfo.label,of_done:ofInfo.done,of_date:ofInfo.date,
          oc_label:ocInfo.label,oc_done:ocInfo.done,oc_date:ocInfo.date,
          if_label:ifInfo.label,if_class:ifInfo.cls,if_date:ifInfo.date,
          ic_label:icInfo.label,ic_class:icInfo.cls,ic_date:icInfo.date,
          dapc_label:dapcInfo.label,dapc_class:dapcInfo.cls,dapc_date:dapcInfo.date,
          damicro_label:damicroInfo.label,damicro_class:damicroInfo.cls,damicro_date:damicroInfo.date,
          aql_fab_label:aqlFab.label,aql_fab_class:aqlFab.cls,aql_fab_date:aqlFab.date,
          aql_cond_label:aqlCond.label,aql_cond_class:aqlCond.cls,aql_cond_date:aqlCond.date,
          rvp_fab_label:rvpFab.label,rvp_fab_class:rvpFab.cls,
          rvp_cond_label:rvpCond.label,rvp_cond_class:rvpCond.cls,
          rvp_lcq_label:rvpLcq.label,rvp_lcq_class:rvpLcq.cls,
          dev_count:devs.length,dev_open:devOpen,dev_label:devs.length>0?(devOpen>0?'Ouverte':'Clôturée'):'—',
          of_id:of?of.id:null,oc_id:oc?oc.id:null,docs:docs,
        }
      })
    }

    // ── Filtres par colonne ─────────────────────────────────────────────
    var columnFilters = ref({})
    var activeDropdown = ref(null)
    var ddPos = ref({top:0,left:0})

    var openDropdown = function(col, event) {
      event.stopPropagation()
      if (activeDropdown.value === col) { activeDropdown.value = null; return }
      var rect = event.currentTarget.getBoundingClientRect()
      ddPos.value = { top: rect.bottom + 2, left: rect.left }
      activeDropdown.value = col
    }
    var getColumnValues = function(col) {
      var seen = {}, vals = []
      lots.value.forEach(function(l) {
        var v = l[col]
        if (v !== undefined && v !== null && v !== '' && v !== '—' && !seen[v]) { seen[v]=true; vals.push(v) }
      })
      return vals.sort()
    }
    var setColumnFilter = function(val) {
      var col = activeDropdown.value
      if (val === null) {
        var nf = {}; Object.keys(columnFilters.value).forEach(function(k){ if(k!==col)nf[k]=columnFilters.value[k] }); columnFilters.value = nf
      } else {
        columnFilters.value = Object.assign({}, columnFilters.value, {[col]: val})
      }
      activeDropdown.value = null
    }
    var clearColumnFilters = function(){ columnFilters.value = {}; activeDropdown.value = null }
    var removeColumnFilter = function(col){ var nf={}; Object.keys(columnFilters.value).forEach(function(k){if(k!==col)nf[k]=columnFilters.value[k]}); columnFilters.value=nf }
    var hasColumnFilters = computed(function(){ return Object.keys(columnFilters.value).length > 0 })
    var closeDropdownGlobal = function(){ activeDropdown.value = null }
    // ───────────────────────────────────────────────────────────────────

    var filteredLots = computed(function(){
      var result = lots.value
      if(activeFilters.value.length>0){
        result=result.filter(function(l){return activeFilters.value.indexOf(l.statut_filter)>=0})
      }
      var cf=columnFilters.value, cfk=Object.keys(cf)
      if(cfk.length>0){result=result.filter(function(l){return cfk.every(function(k){return l[k]===cf[k]})})}
      if(sortCol.value){
        var col=sortCol.value,dir=sortDir.value
        result=result.slice().sort(function(a,b){
          var va=a[col]||'',vb=b[col]||''
          if(typeof va==='string')va=va.toLowerCase()
          if(typeof vb==='string')vb=vb.toLowerCase()
          if(va<vb)return dir==='asc'?-1:1
          if(va>vb)return dir==='asc'?1:-1
          return 0
        })
      }
      return result
    })

    var toggleFilter = function(value){
      var idx=activeFilters.value.indexOf(value)
      if(idx>=0)activeFilters.value.splice(idx,1);else activeFilters.value.push(value)
    }

    var sortBy = function(col){
      if(sortCol.value===col){sortDir.value=sortDir.value==='asc'?'desc':'asc'}
      else{sortCol.value=col;sortDir.value='asc'}
    }
    var sortIcon = function(col){
      if(sortCol.value!==col)return'↕';return sortDir.value==='asc'?'↑':'↓'
    }

    var goToLot = function(id){
      var query={};if(route.query.q)query.q=route.query.q
      if(activeFilters.value.length)query.filters=activeFilters.value.join(',')
      router.push({path:'/lots/'+id,query:query})
    }

    var exportCols=[
      {key:'numero_lot',label:'N° Lot',width:12},{key:'prod_desc',label:'Produit',width:28},{key:'prod_code',label:'Code',width:12},
      {key:'statut_label',label:'Statut',width:14},{key:'of_label',label:'OF',width:10},{key:'oc_label',label:'OC',width:10},
      {key:'aql_fab_label',label:'AQL Fab',width:10},{key:'aql_cond_label',label:'AQL Cond',width:10},
      {key:'if_label',label:'IF',width:10},{key:'ic_label',label:'IC',width:10},
      {key:'dapc_label',label:'DA PC',width:10},{key:'damicro_label',label:'DA Micro',width:10},
      {key:'rvp_fab_label',label:'RVP Fab',width:10},{key:'rvp_cond_label',label:'RVP Cond',width:10},{key:'rvp_lcq_label',label:'RVP LCQ',width:10},
      {key:'date_fmt',label:'Entrée',width:12}
    ]
    var doExportExcel = function(){exportToExcel(filteredLots.value,exportCols,'lots_liberation')}
    var doExportPDF = function(){exportToPDF(filteredLots.value,exportCols,'lots_liberation')}

    // ── Actions en masse ────────────────────────────────────────────────
    var actionLabels = {
      of_planification:'OF — Mise en circuit',of_stock:'OF — Validation Stock',of_aq:'OF — Validation AQ',
      of_dt:'OF — Autorisation DT',of_aq_dap:'OF — Remise AQ DAP',of_production:'OF — Accusé réception',
      oc_planification:'OC — Mise en circuit',oc_stock:'OC — Validation Stock',oc_aq:'OC — Validation AQ',
      oc_dt:'OC — Autorisation DT',oc_aq_dap:'OC — Remise AQ DAP',oc_production:'OC — Accusé réception',
      doc_if:'IF — Émettre',doc_ic:'IC — Émettre',doc_da_pc:'DA Physico — Émettre',doc_da_micro:'DA Micro — Émettre',
      doc_if_verifier:'IF — Vérifier AQ → DT',doc_ic_verifier:'IC — Vérifier AQ → DT',
      doc_da_pc_verifier:'DA Physico — Vérifier AQ → DT',doc_da_micro_verifier:'DA Micro — Vérifier AQ → DT',
      doc_if_approuver:'IF — Approuver DT',doc_ic_approuver:'IC — Approuver DT',
      doc_da_pc_approuver:'DA Physico — Approuver DT',doc_da_micro_approuver:'DA Micro — Approuver DT',
      doc_if_retour_emetteur:'IF — Retourner à l\'émetteur',doc_ic_retour_emetteur:'IC — Retourner à l\'émetteur',
      doc_da_pc_retour_emetteur:'DA Physico — Retourner à l\'émetteur',doc_da_micro_retour_emetteur:'DA Micro — Retourner à l\'émetteur',
      doc_if_retour_aq:'IF — DT retourne à l\'AQ',doc_ic_retour_aq:'IC — DT retourne à l\'AQ',
      doc_da_pc_retour_aq:'DA Physico — DT retourne à l\'AQ',doc_da_micro_retour_aq:'DA Micro — DT retourne à l\'AQ',
      aql_fab_demander:'AQL Fabrication — Demander',aql_fab_relancer:'AQL Fabrication — Relancer',
      aql_fab_conforme:'AQL Fabrication — Conforme',aql_fab_non_conforme:'AQL Fabrication — Non conforme',
      aql_cond_demander:'AQL Conditionnement — Demander',aql_cond_relancer:'AQL Conditionnement — Relancer',
      aql_cond_conforme:'AQL Conditionnement — Conforme',aql_cond_non_conforme:'AQL Conditionnement — Non conforme',
      rvp_fab_emettre:'RVP Fabrication — Émettre',rvp_cond_emettre:'RVP Conditionnement — Émettre',rvp_lcq_emettre:'RVP LCQ — Émettre',
      rvp_fab_verifier:'RVP Fabrication — Vérifier AQ → DT',rvp_cond_verifier:'RVP Conditionnement — Vérifier AQ → DT',rvp_lcq_verifier:'RVP LCQ — Vérifier AQ → DT',
      rvp_fab_approuver:'RVP Fabrication — Approuver DT',rvp_cond_approuver:'RVP Conditionnement — Approuver DT',rvp_lcq_approuver:'RVP LCQ — Approuver DT',
      rvp_fab_retour_emetteur:'RVP Fabrication — Retourner à l\'émetteur',rvp_cond_retour_emetteur:'RVP Conditionnement — Retourner à l\'émetteur',rvp_lcq_retour_emetteur:'RVP LCQ — Retourner à l\'émetteur',
      rvp_fab_retour_aq:'RVP Fabrication — DT retourne à l\'AQ',rvp_cond_retour_aq:'RVP Conditionnement — DT retourne à l\'AQ',rvp_lcq_retour_aq:'RVP LCQ — DT retourne à l\'AQ',
      dev_declarer:'Déviation — Déclarer',dev_cloture:'Déviation — Clôturer',
    }
    var actionLabel = computed(function(){ return actionLabels[actionType.value] || '' })
    var canExecute = computed(function(){ return selected.value.length > 0 && actionType.value !== '' })

    var isSelected = function(id){ return selected.value.indexOf(id) >= 0 }
    var toggleLot = function(id){ var idx=selected.value.indexOf(id); if(idx>=0)selected.value.splice(idx,1); else selected.value.push(id) }
    var allVisibleChecked = computed(function(){ return filteredLots.value.length>0 && filteredLots.value.every(function(l){return isSelected(l.id)}) })
    var someVisibleChecked = computed(function(){ return filteredLots.value.some(function(l){return isSelected(l.id)}) })
    var toggleAll = function(){
      if(allVisibleChecked.value){ filteredLots.value.forEach(function(l){ var i=selected.value.indexOf(l.id); if(i>=0)selected.value.splice(i,1) }) }
      else { filteredLots.value.forEach(function(l){ if(!isSelected(l.id))selected.value.push(l.id) }) }
    }
    var getLotNum = function(id){ var l=lots.value.find(function(x){return x.id===id}); return l?l.numero_lot:id }

    var executeAction = async function() {
      // Garde — vérification permission avant tout traitement
      if (!canAction(actionType.value)) {
        execResult.value = {ok:0,fail:selected.value.length,errors:['Action non autorisée pour votre service ('+userService.value+')']}
        showConfirm.value = false
        return
      }
      executing.value = true; progress.value = 0
      var result = { ok:0, fail:0, errors:[] }
      var now = new Date().toISOString()
      var userRes = await supabase.auth.getUser()
      var userId = userRes.data.user.id
      var flow = ['planification','stock','aq','dt','aq_dap','production']

      for (var i=0; i<selected.value.length; i++) {
        var lotId = selected.value[i]
        var lot = lots.value.find(function(x){return x.id===lotId})
        if (!lot) { result.fail++; continue }
        try {
          var action = actionType.value
          if (action.startsWith('of_') || action.startsWith('oc_')) {
            var parts=action.split('_'), orderType=parts[0], etape=parts.slice(1).join('_')
            var orderId = orderType==='of' ? lot.of_id : lot.oc_id
            if (!orderId) { result.errors.push(lot.numero_lot+': pas d\'ordre '+orderType.toUpperCase()); result.fail++; continue }
            var idx2=flow.indexOf(etape), nextEtape=idx2<flow.length-1?flow[idx2+1]:null
            var tbl = orderType==='of'?'orders_of':'orders_oc'
            await supabase.from('order_validations').insert({order_type:orderType,order_id:orderId,etape:etape,action:'valide',validated_by:userId,validated_at:now})
            await supabase.from(tbl).update({statut:nextEtape?'en_circuit':'termine',etape_circuit:nextEtape||etape,updated_at:now}).eq('id',orderId)
            var nextLabel=nextEtape?(etapeLabels[nextEtape]||nextEtape):'Terminé'
            await supabase.from('lots').update({statut_operationnel:orderType.toUpperCase()+' — '+nextLabel,updated_at:now}).eq('id',lotId)
            await supabase.from('lot_events').insert({lot_id:lotId,event_type:'validation_'+orderType,description:'Circuit '+orderType.toUpperCase()+' — '+etape+' validé (masse)',triggered_by:userId,created_at:now})
            // Notification — service responsable de l'étape suivante
            var notifSvc = nextEtape === 'stock' ? 'stock' : nextEtape === 'aq' ? 'aq' : nextEtape === 'dt' ? 'dt' : nextEtape === 'aq_dap' ? 'aq_dap' : nextEtape === 'production' ? (orderType==='of'?'fabrication':'conditionnement') : 'planification'
            var stepLbl = etapeLabels[etape]||etape
            await createNotification(notifSvc, lotId, null, 'Lot '+lot.numero_lot+' — Circuit '+orderType.toUpperCase()+' : '+stepLbl+' validé', 'circuit_avance')
            result.ok++
          } else if (action.startsWith('doc_')) {
            var docAction=action.replace('doc_','')
            var isApprouver=docAction.endsWith('_approuver'),isVerifier=docAction.endsWith('_verifier')
            var isRetourEmetteur=docAction.endsWith('_retour_emetteur'),isRetourAQ=docAction.endsWith('_retour_aq')
            var docType=docAction
            if(isApprouver)docType=docAction.replace('_approuver','')
            if(isVerifier)docType=docAction.replace('_verifier','')
            if(isRetourEmetteur)docType=docAction.replace('_retour_emetteur','')
            if(isRetourAQ)docType=docAction.replace('_retour_aq','')
            var doc=null; if(lot.docs){for(var j=0;j<lot.docs.length;j++){if(lot.docs[j].type_document===docType){doc=lot.docs[j];break}}}
            if(!doc){result.errors.push(lot.numero_lot+': document '+docType+' non trouvé');result.fail++;continue}
            if(isApprouver){
              await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:now,updated_at:now}).eq('id',doc.id)
              var fldMap={'if':'if_approved',ic:'ic_approved',da_pc:'da_pc_approved',da_micro:'da_micro_approved'}
              var fld=fldMap[docType]; if(fld)await supabase.from('liberation_dossiers').update({[fld]:true,updated_at:now}).eq('lot_id',lotId)
              await supabase.from('document_movements').insert({document_id:doc.id,action:'approbation',from_service:'dt',performed_by:userId,performed_at:now})
            } else if(isVerifier){
              await supabase.from('liberation_documents').update({statut:'approuve_aq',updated_at:now}).eq('id',doc.id)
              await supabase.from('document_movements').insert({document_id:doc.id,action:'approbation',from_service:'aq',to_service:'dt',performed_by:userId,performed_at:now})
            } else if(isRetourEmetteur){
              var svcMap2={'if':'fabrication',ic:'conditionnement',da_pc:'lcq',da_micro:'lcq'}
              await supabase.from('liberation_documents').update({statut:'retour_emetteur',updated_at:now}).eq('id',doc.id)
              await supabase.from('document_movements').insert({document_id:doc.id,action:'retour',from_service:'aq',to_service:svcMap2[docType]||'',motif_retour:'Retour en masse',performed_by:userId,performed_at:now})
            } else if(isRetourAQ){
              await supabase.from('liberation_documents').update({statut:'verification_aq',updated_at:now}).eq('id',doc.id)
              await supabase.from('document_movements').insert({document_id:doc.id,action:'retour',from_service:'dt',to_service:'aq',motif_retour:'Retour DT en masse',performed_by:userId,performed_at:now})
            } else {
              if(docType==='da_micro'){
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,is_applicable:true,is_required:true,updated_at:now}).eq('id',doc.id)
                await supabase.from('liberation_dossiers').update({da_micro_applicable:true,updated_at:now}).eq('lot_id',lotId)
              } else {
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,updated_at:now}).eq('id',doc.id)
              }
              var svcMap={'if':'fabrication',ic:'conditionnement',da_pc:'lcq',da_micro:'lcq'}
              await supabase.from('document_movements').insert({document_id:doc.id,action:'emission',from_service:svcMap[docType]||'',to_service:'aq',performed_by:userId,performed_at:now})
            }
            var actionDesc=isApprouver?'approuvé DT':isVerifier?'vérifié AQ → DT':isRetourEmetteur?'retourné à l\'émetteur':isRetourAQ?'retourné DT → AQ':'émis'
            await supabase.from('lot_events').insert({lot_id:lotId,event_type:'document_masse',description:docType.toUpperCase()+' — '+actionDesc+' (masse)',triggered_by:userId,created_at:now})
            // Notifications
            var typeLabel=docType.toUpperCase().replace('_',' ')
            if(!isApprouver&&!isVerifier&&!isRetourEmetteur&&!isRetourAQ){
              await createNotification('aq',lotId,doc.id,'Lot '+lot.numero_lot+' — '+typeLabel+' émis, en attente de vérification','document_transmis')
            } else if(isVerifier){
              await createNotification('dt',lotId,doc.id,'Lot '+lot.numero_lot+' — '+typeLabel+' vérifié AQ, en attente d\'approbation DT','document_transmis')
            } else if(isRetourEmetteur){
              var svcNotif={'if':'fabrication',ic:'conditionnement',da_pc:'lcq',da_micro:'lcq'}
              if(svcNotif[docType])await createNotification(svcNotif[docType],lotId,doc.id,'Lot '+lot.numero_lot+' — '+typeLabel+' retourné pour rectification','document_retourne')
            } else if(isRetourAQ){
              await createNotification('aq',lotId,doc.id,'Lot '+lot.numero_lot+' — '+typeLabel+' retourné par le DT','document_retourne')
            } else if(isApprouver){
              await createNotification('aq',lotId,doc.id,'Lot '+lot.numero_lot+' — '+typeLabel+' approuvé par le DT','document_approuve')
              var svcEm={'if':'fabrication',ic:'conditionnement',da_pc:'lcq',da_micro:'lcq'}
              if(svcEm[docType])await createNotification(svcEm[docType],lotId,doc.id,'Lot '+lot.numero_lot+' — '+typeLabel+' approuvé par le DT','document_approuve')
            }
            result.ok++
          } else if (action.startsWith('aql_')) {
            var aqlParts=action.split('_'), aqlSvc=aqlParts[1], aqlOp=aqlParts.slice(2).join('_')
            var aqlTypeVal=aqlSvc==='fab'?'fabrication':'conditionnement'
            var aqlSvcLabel=aqlSvc==='fab'?'Fabrication':'Conditionnement'
            if(aqlOp==='demander'||aqlOp==='relancer'){
              await supabase.from('aql_inspections').insert({lot_id:lotId,type:aqlTypeVal,requested_at:now,requested_by:userId})
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'aql_demande',description:'AQL '+aqlSvcLabel+' — '+(aqlOp==='relancer'?'relancé':'demandé')+' (masse)',triggered_by:userId,created_at:now})
              await createNotification('aq',lotId,null,'Lot '+lot.numero_lot+' — AQL '+aqlSvcLabel+(aqlOp==='relancer'?' relancé':' demandé'),'aql_demande')
              result.ok++
            } else if(aqlOp==='conforme'||aqlOp==='non_conforme'){
              var aqlRes=await supabase.from('aql_inspections').select('id').eq('lot_id',lotId).eq('type',aqlTypeVal).is('resultat',null).order('requested_at',{ascending:false}).limit(1)
              var latestAql=aqlRes.data&&aqlRes.data[0]
              if(!latestAql){result.errors.push(lot.numero_lot+': pas d\'AQL '+aqlSvcLabel+' en attente');result.fail++;continue}
              await supabase.from('aql_inspections').update({resultat:aqlOp,inspected_at:now,inspected_by:userId}).eq('id',latestAql.id)
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'aql_resultat',description:'AQL '+aqlSvcLabel+' — '+aqlOp.replace('_',' ')+' (masse)',triggered_by:userId,created_at:now})
              await createNotification('planification',lotId,null,'Lot '+lot.numero_lot+' — AQL '+aqlSvcLabel+' : '+aqlOp.replace('_',' '),'aql_resultat')
              result.ok++
            } else {result.errors.push(lot.numero_lot+': action AQL inconnue');result.fail++}
          } else if (action.startsWith('rvp_')) {
            var rvpParts=action.split('_'), rvpSvc=rvpParts[1], rvpOp=rvpParts.slice(2).join('_')
            var rvpSvcMap={fab:'fabrication',cond:'conditionnement',lcq:'lcq'}
            var rvpEmetteur=rvpSvcMap[rvpSvc]||rvpSvc
            var rvpDoc=null
            if(lot.docs){for(var jj=0;jj<lot.docs.length;jj++){if(lot.docs[jj].type_document==='rvp'&&lot.docs[jj].service_emetteur===rvpEmetteur){rvpDoc=lot.docs[jj];break}}}
            if(!rvpDoc){result.errors.push(lot.numero_lot+': RVP '+rvpEmetteur+' non trouvé');result.fail++;continue}
            if(rvpOp==='emettre'){
              await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,updated_at:now}).eq('id',rvpDoc.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc.id,action:'emission',from_service:rvpEmetteur,to_service:'aq',performed_by:userId,performed_at:now})
              await createNotification('aq',lotId,rvpDoc.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur+' émis, en attente de vérification','document_transmis')
            } else if(rvpOp==='verifier'){
              await supabase.from('liberation_documents').update({statut:'approuve_aq',updated_at:now}).eq('id',rvpDoc.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc.id,action:'approbation',from_service:'aq',to_service:'dt',performed_by:userId,performed_at:now})
              await createNotification('dt',lotId,rvpDoc.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur+' vérifié AQ → DT','document_transmis')
            } else if(rvpOp==='approuver'){
              await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:now,updated_at:now}).eq('id',rvpDoc.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc.id,action:'approbation',from_service:'dt',performed_by:userId,performed_at:now})
              await createNotification('aq',lotId,rvpDoc.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur+' approuvé DT','document_approuve')
              await createNotification(rvpEmetteur,lotId,rvpDoc.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur+' approuvé DT','document_approuve')
            } else if(rvpOp==='retour_emetteur'){
              await supabase.from('liberation_documents').update({statut:'retour_emetteur',updated_at:now}).eq('id',rvpDoc.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc.id,action:'retour',from_service:'aq',to_service:rvpEmetteur,motif_retour:'Retour en masse',performed_by:userId,performed_at:now})
              await createNotification(rvpEmetteur,lotId,rvpDoc.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur+' retourné pour rectification','document_retourne')
            } else if(rvpOp==='retour_aq'){
              await supabase.from('liberation_documents').update({statut:'verification_aq',updated_at:now}).eq('id',rvpDoc.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc.id,action:'retour',from_service:'dt',to_service:'aq',motif_retour:'Retour DT en masse',performed_by:userId,performed_at:now})
              await createNotification('aq',lotId,rvpDoc.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur+' retourné par le DT','document_retourne')
            } else {result.errors.push(lot.numero_lot+': action RVP inconnue');result.fail++;continue}
            await supabase.from('lot_events').insert({lot_id:lotId,event_type:'rvp_masse',description:'RVP '+rvpEmetteur+' — '+rvpOp.replace(/_/g,' ')+' (masse)',triggered_by:userId,created_at:now})
            result.ok++
          } else if (action.startsWith('dev_')) {
            var devOp=action.replace('dev_','')
            if(devOp==='declarer'){
              await supabase.from('deviations').insert({lot_id:lotId,statut:'ouverte',description:'Déclaration en masse',declared_by:userId,declared_at:now,created_at:now})
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'deviation_declaree',description:'Déviation déclarée (masse)',triggered_by:userId,created_at:now})
              result.ok++
            } else if(devOp==='cloture'){
              var openDevs=await supabase.from('deviations').select('id').eq('lot_id',lotId).in('statut',['ouverte','en_cours'])
              if(!openDevs.data||!openDevs.data.length){result.errors.push(lot.numero_lot+': aucune déviation ouverte');result.fail++;continue}
              for(var kk=0;kk<openDevs.data.length;kk++){
                await supabase.from('deviations').update({statut:'cloturee',closed_at:now,closed_by:userId,updated_at:now}).eq('id',openDevs.data[kk].id)
              }
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'deviation_cloturee',description:openDevs.data.length+' déviation(s) clôturée(s) (masse)',triggered_by:userId,created_at:now})
              result.ok++
            } else {result.errors.push(lot.numero_lot+': action déviation inconnue');result.fail++}
          }
        } catch(e) { result.errors.push(lot.numero_lot+': '+e.message); result.fail++ }
        progress.value = i+1
      }
      execResult.value = result; executing.value = false; showConfirm.value = false
      selected.value = []; actionType.value = ''
      load()
    }
    // ────────────────────────────────────────────────────────────────────

    onMounted(async function(){
      var u = await supabase.auth.getUser()
      if (u.data.user) {
        var p = await supabase.from('profiles').select('service').eq('id', u.data.user.id).single()
        if (p.data) {
          await loadPermissions(p.data.service)
          userService.value = p.data.service
        }
      }
      if(route.query.filters)activeFilters.value=route.query.filters.split(',')
      load()
      document.addEventListener('click', closeDropdownGlobal)
    })
    onUnmounted(function(){ document.removeEventListener('click', closeDropdownGlobal) })
    watch(function(){return route.query},load,{deep:true})

    return{lots,total,activeFilters,showDates,filteredLots,filterOptions,
      toggleFilter,sortBy,sortIcon,goToLot,doExportExcel,doExportPDF,
      selected,actionType,showConfirm,executing,progress,execResult,
      actionLabel,canExecute,allVisibleChecked,someVisibleChecked,
      isSelected,toggleLot,toggleAll,getLotNum,executeAction,
      actionGroups,userService,
      columnFilters,activeDropdown,ddPos,openDropdown,getColumnValues,setColumnFilter,clearColumnFilters,removeColumnFilter,hasColumnFilters}
  }
}
</script>
<style scoped>
.ph{display:flex;align-items:baseline;justify-content:space-between;padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:2px;flex-wrap:wrap;gap:8px}
.pt{font-size:11px;font-weight:500;letter-spacing:1.5px}.pc{font-size:11px;color:#999;font-family:'SF Mono',monospace}
.ph-right{display:flex;align-items:center;gap:6px;flex-wrap:wrap}
.btn-exp{font-size:11px;padding:4px 10px;border:1px solid #ddd;border-radius:3px;background:#fff;cursor:pointer;color:#666;font-family:inherit}.btn-exp:hover{background:#f5f5f5}
.btn-toggle{font-size:11px;padding:4px 10px;border:1px solid #185FA5;border-radius:3px;background:#E6F1FB;cursor:pointer;color:#0C447C;font-family:inherit}.btn-toggle:hover{background:#d0e3f5}
.filters{display:flex;gap:4px;padding:8px 0;flex-wrap:wrap}
.fbtn{display:flex;align-items:center;gap:4px;padding:5px 10px;min-height:32px;font-size:11px;border:1px solid #e8e8e8;border-radius:3px;background:#fff;cursor:pointer;color:#666;font-family:inherit;transition:.15s}
.fbtn:hover{border-color:#ccc}.fbtn.active{border-color:#185FA5;background:#E6F1FB;color:#0C447C}
.fdot{width:6px;height:6px;border-radius:50%;flex-shrink:0}
.table-wrap{overflow-x:auto;overflow-y:auto;-webkit-overflow-scrolling:touch;max-height:calc(100vh - 150px)}
.tb{width:100%;border-collapse:collapse;font-size:11px;white-space:nowrap}.tb th{font-size:9px;text-transform:uppercase;color:#999;font-weight:500;padding:5px 4px;text-align:left;border-bottom:1px solid #e8e8e8;position:sticky;top:0;background:#fff;z-index:1}
.sortable{cursor:pointer;user-select:none}.sortable:hover{color:#185FA5}.sort-arrow{font-size:10px;color:#ccc}
.tb td{padding:6px 4px;border-bottom:1px solid #f5f5f5}.tb tr{cursor:pointer}.tb tr:hover td{background:#fafafa}
.bold{font-weight:500}.mono{font-family:'SF Mono',monospace;font-size:10px}.dim{color:#999;font-size:10px}
.td-prod{max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:11px}
.code{font-size:9px;color:#999;font-family:'SF Mono',monospace;margin-left:3px}
.sp{font-size:9px;padding:2px 5px;border-radius:2px;font-weight:500;white-space:nowrap}
.s-quarantaine{background:#FAEEDA;color:#854F0B}.s-accepte{background:#EAF3DE;color:#3B6D11}.s-sous_investigation{background:#FCEBEB;color:#A32D2D}.s-vide{background:#f5f5f5;color:#999}.s-enprod{background:#E6F1FB;color:#0C447C}.s-enprep{background:#F0EBFE;color:#5B3CC4}.s-refuse{background:#e8e8e8;color:#333}
.doc-pip{font-size:9px;padding:2px 4px;border-radius:2px;font-weight:500}
.dc-ok{background:#EAF3DE;color:#3B6D11}.dc-ret{background:#FCEBEB;color:#A32D2D}.dc-wait{background:#f5f5f5;color:#999}.dc-prog{background:#E6F1FB;color:#0C447C}.dc-na{background:transparent;color:#ccc}.dc-date{background:#fafafa;color:#666;font-family:'SF Mono',monospace}
.pip-done-t{background:#EAF3DE;color:#3B6D11}.pip-prog-t{background:#FAEEDA;color:#854F0B}
.dev-badge{font-size:9px;padding:2px 5px;border-radius:2px;font-weight:500}.dev-open{background:#FCEBEB;color:#A32D2D}.dev-closed{background:#EAF3DE;color:#3B6D11}
.empty{text-align:center;padding:40px;color:#999}
/* column filter chips */
.cf-bar{display:flex;align-items:center;gap:6px;padding:5px 0;flex-wrap:wrap;font-size:11px;border-bottom:1px solid #e8e8e8;margin-bottom:0}
.cf-label{color:#999;font-weight:500;white-space:nowrap}
.cf-chip{display:flex;align-items:center;gap:4px;background:#E6F1FB;color:#0C447C;padding:2px 8px;border-radius:10px;font-size:11px}
.cf-chip strong{font-weight:600}
.cf-rm{background:none;border:none;cursor:pointer;color:#185FA5;font-size:11px;padding:0 0 0 2px;line-height:1}
.cf-clear{font-size:11px;padding:2px 10px;border:1px solid #E24B4A;border-radius:10px;background:#fff;color:#E24B4A;cursor:pointer;white-space:nowrap}.cf-clear:hover{background:#FCEBEB}
/* column header with filter button */
.th-s{display:flex;align-items:center;gap:2px;padding:5px 4px !important;white-space:nowrap}
.th-txt{cursor:pointer;flex:1;display:flex;align-items:center;gap:2px}
.th-txt:hover{color:#185FA5}
.th-f{background:none;border:none;cursor:pointer;color:#ccc;font-size:11px;padding:0 2px;line-height:1;border-radius:2px;flex-shrink:0;transition:.1s}
.th-f:hover{color:#185FA5;background:#f0f0f0}
.th-f-on{color:#185FA5 !important;background:#E6F1FB}
/* column dropdown */
.col-dd{position:fixed;background:#fff;border:1px solid #ddd;border-radius:4px;box-shadow:0 6px 20px rgba(0,0,0,.12);z-index:300;min-width:160px;max-width:260px;max-height:280px;overflow-y:auto;font-size:12px}
.col-dd-item{padding:7px 12px;cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;transition:.1s}
.col-dd-item:hover{background:#f5f5f5}
.col-dd-all{color:#999;font-style:italic;border-bottom:1px solid #f0f0f0}
.col-dd-on{background:#E6F1FB;color:#0C447C;font-weight:500}
/* bulk bar */
.bulk-bar{display:flex;align-items:center;gap:8px;padding:6px 0;flex-wrap:wrap;border-bottom:1px solid #e8e8e8;margin-bottom:0}
.bulk-sel{padding:5px 8px;font-size:12px;border:1px solid #ddd;border-radius:3px;outline:none;font-family:inherit;min-width:220px}.bulk-sel:focus{border-color:#185FA5}
.bulk-btn{padding:5px 14px;font-size:12px;font-weight:500;background:#185FA5;color:#fff;border:none;border-radius:3px;cursor:pointer;white-space:nowrap}.bulk-btn:hover{background:#0C447C}.bulk-btn:disabled{opacity:.35;cursor:not-allowed}
.bulk-info{font-size:11px;color:#185FA5;font-family:'SF Mono',monospace}
.bulk-clear{font-size:11px;padding:3px 10px;border:1px solid #E24B4A;border-radius:3px;background:#fff;color:#E24B4A;cursor:pointer}.bulk-clear:hover{background:#FCEBEB}
/* checkboxes */
.th-chk,.td-chk{width:32px;text-align:center;padding:0 4px !important}
.td-chk{cursor:pointer}
.row-sel td{background:#E6F1FB !important}
/* modal masse */
.m-overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:200;padding:16px}
.m-box{background:#fff;padding:24px;width:min(100%,460px);border-radius:4px;max-height:85vh;overflow-y:auto}
.m-title{font-size:16px;font-weight:500;margin-bottom:16px}
.m-body{margin-bottom:16px}
.m-line{display:flex;justify-content:space-between;padding:6px 0;font-size:13px;border-bottom:1px solid #f5f5f5}.m-lbl{color:#999}
.m-chips{display:flex;flex-wrap:wrap;gap:4px;margin-top:10px}
.m-chip{font-size:11px;font-family:'SF Mono',monospace;padding:2px 8px;background:#f5f5f5;border-radius:2px;color:#666}
.m-more{background:#E6F1FB;color:#185FA5}
.m-actions{display:flex;gap:8px;margin-top:16px}
.m-btn-ok{flex:1;padding:11px;background:#185FA5;color:#fff;border:none;font-size:13px;font-weight:500;cursor:pointer;border-radius:2px;min-height:44px}.m-btn-ok:hover{background:#0C447C}.m-btn-ok:disabled{opacity:.5}
.m-btn-cancel{flex:1;padding:11px;background:#f5f5f5;color:#666;border:none;font-size:13px;cursor:pointer;border-radius:2px;min-height:44px}
.m-result{border:1px solid #e8e8e8;padding:16px;margin-top:12px}
.m-rh{font-size:13px;font-weight:500;margin-bottom:10px}
.m-rg{display:grid;grid-template-columns:1fr 1fr;border:1px solid #e8e8e8}
.m-rc{padding:10px;text-align:center;border-right:1px solid #e8e8e8}.m-rc:last-child{border-right:none}
.m-rv{font-size:18px;font-weight:500;font-family:'SF Mono',monospace}.m-rl{font-size:10px;color:#999;text-transform:uppercase;margin-top:2px}
.m-errs{margin-top:10px}.m-err{font-size:11px;color:#E24B4A;padding:3px 0;border-bottom:1px solid #f5f5f5}
@media(max-width:768px){
  .ph{flex-direction:column;gap:6px}
  .ph-right{width:100%;justify-content:flex-start;gap:4px}
  .btn-exp,.btn-toggle{padding:6px 10px;min-height:36px}
  .filters{overflow-x:auto;-webkit-overflow-scrolling:touch;flex-wrap:nowrap;padding-bottom:6px;padding-top:6px;gap:6px;scrollbar-width:none}
  .filters::-webkit-scrollbar{display:none}
  .fbtn{min-height:36px;padding:6px 12px;white-space:nowrap}
  .td-prod{max-width:110px}
  .tb td{padding:8px 4px}
  .table-wrap{max-height:calc(100vh - 220px)}
  .bulk-sel{min-width:0;width:100%}
  .bulk-bar{flex-direction:column;align-items:stretch}
  .bulk-btn{width:100%;padding:10px;min-height:44px}
}
</style>
