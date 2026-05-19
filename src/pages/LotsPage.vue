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
    <div v-if="!filteredLots.length" class="empty">Aucun lot trouvé</div>
    <div v-else class="table-wrap">
      <table class="tb">
        <thead><tr>
          <th @click="sortBy('numero_lot')" class="sortable">N° Lot <span class="sort-arrow">{{sortIcon('numero_lot')}}</span></th>
          <th @click="sortBy('prod_desc')" class="sortable">Produit <span class="sort-arrow">{{sortIcon('prod_desc')}}</span></th>
          <th @click="sortBy('statut_label')" class="sortable">Statut <span class="sort-arrow">{{sortIcon('statut_label')}}</span></th>
          <th @click="sortBy('of_label')" class="sortable">OF</th>
          <th @click="sortBy('oc_label')" class="sortable">OC</th>
          <th>AQL Fab</th><th>AQL Cond</th>
          <th @click="sortBy('if_label')" class="sortable">IF</th>
          <th @click="sortBy('ic_label')" class="sortable">IC</th>
          <th>DA PC</th><th>DA Micro</th>
          <th>Dév.</th><th>RVP Fab</th><th>RVP Cond</th><th>RVP LCQ</th>
          <th @click="sortBy('date_fmt')" class="sortable">{{showDates?'Libération':'Entrée'}}</th>
        </tr></thead>
        <tbody><tr v-for="l in filteredLots" :key="l.id" @click="goToLot(l.id)">
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
  </div>
</template>
<script>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { exportToExcel, exportToPDF } from '../services/export'
export default {
  setup() {
    var route = useRoute(), router = useRouter()
    var lots = ref([]), total = ref(0), activeFilters = ref([])
    var sortCol = ref(''), sortDir = ref('asc'), showDates = ref(false)

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
      var query = supabase.from('lots').select('*, products(code_article,description), orders_of(id,statut,etape_circuit,updated_at), orders_oc(id,statut,etape_circuit,updated_at), liberation_documents(type_document,statut,is_applicable,service_emetteur,emitted_at,approved_at), deviations(statut), aql_inspections(type,resultat,requested_at,inspected_at)', {count:'exact'})

      var q = route.query.q
      if(q){
        var matchRes=await supabase.from('products').select('id').or('code_article.ilike.%'+q+'%,description.ilike.%'+q+'%')
        var prodIds=(matchRes.data||[]).map(function(p){return p.id})
        if(prodIds.length){query=query.or('numero_lot.ilike.%'+q+'%,product_id.in.('+prodIds.join(',')+')')}
        else{query=query.ilike('numero_lot','%'+q+'%')}
      }

      query=query.order('date_enregistrement',{ascending:false,nullsFirst:false}).limit(500)
      var result=await query
      total.value=result.count||0

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
          dev_count:devs.length,dev_open:devOpen,
        }
      })
    }

    var filteredLots = computed(function(){
      var result = lots.value
      if(activeFilters.value.length>0){
        result=result.filter(function(l){return activeFilters.value.indexOf(l.statut_filter)>=0})
      }
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

    onMounted(function(){
      if(route.query.filters)activeFilters.value=route.query.filters.split(',')
      load()
    })
    watch(function(){return route.query},load,{deep:true})

    return{lots,total,activeFilters,showDates,filteredLots,filterOptions,
      toggleFilter,sortBy,sortIcon,goToLot,doExportExcel,doExportPDF}
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
.table-wrap{overflow-x:auto;-webkit-overflow-scrolling:touch}
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
@media(max-width:768px){
  .ph{flex-direction:column;gap:6px}
  .ph-right{width:100%;justify-content:flex-start;gap:4px}
  .btn-exp,.btn-toggle{padding:6px 10px;min-height:36px}
  .filters{overflow-x:auto;-webkit-overflow-scrolling:touch;flex-wrap:nowrap;padding-bottom:6px;padding-top:6px;gap:6px;scrollbar-width:none}
  .filters::-webkit-scrollbar{display:none}
  .fbtn{min-height:36px;padding:6px 12px;white-space:nowrap}
  .td-prod{max-width:110px}
  /* masquer les colonnes secondaires sur mobile, garder N° lot, Produit, Statut, IF, IC, Date */
  .tb th:nth-child(4),.tb td:nth-child(4),
  .tb th:nth-child(5),.tb td:nth-child(5),
  .tb th:nth-child(6),.tb td:nth-child(6),
  .tb th:nth-child(7),.tb td:nth-child(7),
  .tb th:nth-child(10),.tb td:nth-child(10),
  .tb th:nth-child(11),.tb td:nth-child(11),
  .tb th:nth-child(12),.tb td:nth-child(12),
  .tb th:nth-child(13),.tb td:nth-child(13),
  .tb th:nth-child(14),.tb td:nth-child(14),
  .tb th:nth-child(15),.tb td:nth-child(15){display:none}
  .tb td{padding:8px 4px}
}
@media(max-width:480px){
  .tb th:nth-child(9),.tb td:nth-child(9){display:none}
  .td-prod{max-width:80px}
}
</style>
