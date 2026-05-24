<template>
  <div v-if="loaded">
    <div class="dh"><span class="dt">DASHBOARD</span><span class="dp">{{ currentYear }}</span></div>

    <div class="ks">
      <div class="k" v-for="k in kpis" :key="k.label"><div class="kv" :style="{color:k.color}">{{k.value}}<span class="ku" v-if="k.unit">{{k.unit}}</span></div><div class="kl">{{k.label}}</div></div>
    </div>

    <div class="section">
      <div class="sh"><span>KPI mensuels {{ currentYear }}</span></div>
      <div class="table-wrap">
        <table class="mtb">
          <thead><tr><th>Indicateur</th><th v-for="m in months" :key="m">{{ m }}</th><th class="ytd">YTD</th></tr></thead>
          <tbody>
            <tr v-for="row in monthlyData" :key="row.label">
              <td class="row-label">{{ row.label }}</td>
              <td v-for="(v,i) in row.values" :key="i" class="mono">{{ v }}</td>
              <td class="mono ytd-val">{{ row.ytd }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="section">
      <div class="sh"><span>Documents en attente par service</span></div>
      <div class="table-wrap">
        <table class="mtb">
          <thead><tr><th>Service</th><th>En attente</th><th>En retour</th></tr></thead>
          <tbody>
            <tr v-for="s in serviceQueue" :key="s.service">
              <td class="row-label">{{ s.label }}</td>
              <td class="mono" :class="{'cw':s.pending>0}">{{ s.pending }}</td>
              <td class="mono" :class="{'cd':s.returned>0}">{{ s.returned }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="section" v-if="alertes.length">
      <div class="sh"><span>Alertes actives</span></div>
      <div class="al" v-for="(a,i) in alertes" :key="i" @click="$router.push('/lots?q='+a.lot)">
        <span class="ap" :class="'ap-'+a.level"></span><span class="aln">{{a.lot}}</span><span class="am">{{a.msg}}</span>
      </div>
    </div>
  </div>
  <div v-else class="loading">Chargement...</div>
</template>
<script>
import { ref, onMounted } from 'vue'
import { supabase } from '../supabase'
export default {
  setup() {
    var loaded = ref(false), kpis = ref([]), monthlyData = ref([]), serviceQueue = ref([]), alertes = ref([])
    var now = new Date()
    var currentYear = now.getFullYear()
    var currentMonth = now.getMonth() // 0-indexed
    var monthNames = ['Jan','Fév','Mar','Avr','Mai','Juin','Juil','Aoû','Sep','Oct','Nov','Déc']
    var months = monthNames.slice(0, currentMonth + 1)

    onMounted(async function() {
      // KPI globaux
      var counts = {}
      for (var s of ['vide','quarantaine','sous_investigation','accepte']) {
        var r = await supabase.from('lots').select('*',{count:'exact',head:true}).eq('statut_sap',s)
        counts[s] = r.count || 0
      }
      var devRes = await supabase.from('deviations').select('*',{count:'exact',head:true}).in('statut',['ouverte','en_cours'])
      kpis.value = [
        {label:'Quarantaine',value:counts.quarantaine,color:'#BA7517'},
        {label:'Investigation',value:counts.sous_investigation,color:'#E24B4A'},
        {label:'Acceptés',value:counts.accepte,color:'#1D9E75'},
        {label:'Planifiés',value:counts.vide,color:'#999'},
        {label:'Dév. ouvertes',value:devRes.count||0,color:devRes.count>0?'#E24B4A':'#1D9E75'},
      ]

      // KPI mensuels
      var liberations = await supabase.from('lots').select('date_liberation').eq('statut_sap','accepte').not('date_liberation','is',null)
      var docs = await supabase.from('liberation_documents').select('type_document, emitted_at, service_emetteur').not('emitted_at','is',null)
      var aqlData = await supabase.from('aql_inspections').select('type, inspected_at').not('inspected_at','is',null)

      var indicators = [
        {label:'Lots libérés', key:'lib'},
        {label:'IF émis', key:'if'},
        {label:'IC émis', key:'ic'},
        {label:'DA Physico émis', key:'da_pc'},
        {label:'DA Micro émis', key:'da_micro'},
      ]

      var monthCounts = {}
      indicators.forEach(function(ind) { monthCounts[ind.key] = new Array(currentMonth+1).fill(0) })

      // Lots libérés par mois
      if (liberations.data) liberations.data.forEach(function(l) {
        var d = new Date(l.date_liberation)
        if (d.getFullYear() === currentYear && d.getMonth() <= currentMonth) monthCounts.lib[d.getMonth()]++
      })

      // Documents par mois
      if (docs.data) docs.data.forEach(function(d) {
        var dt = new Date(d.emitted_at)
        if (dt.getFullYear() === currentYear && dt.getMonth() <= currentMonth && monthCounts[d.type_document]) {
          monthCounts[d.type_document][dt.getMonth()]++
        }
      })

      monthlyData.value = indicators.map(function(ind) {
        var vals = monthCounts[ind.key]
        var ytd = vals.reduce(function(a,b){return a+b},0)
        return { label: ind.label, values: vals, ytd: ytd }
      })

      // Moyenne mensuelle
      monthlyData.value.push({
        label: 'Moyenne libération/mois',
        values: new Array(currentMonth+1).fill(''),
        ytd: monthCounts.lib.reduce(function(a,b){return a+b},0) > 0
          ? Math.round(monthCounts.lib.reduce(function(a,b){return a+b},0) / (currentMonth+1))
          : 0
      })

      // Documents en attente par service
      var pendingDocs = await supabase.from('liberation_documents').select('statut, service_emetteur').in('statut', ['emis','verification_aq','retour_emetteur','approuve_aq'])
      var svcMap = {}
      var svcLabels = {fabrication:'Fabrication',conditionnement:'Conditionnement',lcq:'LCQ',aq:'AQ',dt:'DT'}

      if (pendingDocs.data) pendingDocs.data.forEach(function(d) {
        var targetSvc = ''
        if (d.statut === 'emis' || d.statut === 'verification_aq') targetSvc = 'aq'
        else if (d.statut === 'approuve_aq') targetSvc = 'dt'
        else if (d.statut === 'retour_emetteur') targetSvc = d.service_emetteur

        if (!svcMap[targetSvc]) svcMap[targetSvc] = {pending:0,returned:0}
        if (d.statut === 'retour_emetteur') svcMap[targetSvc].returned++
        else svcMap[targetSvc].pending++
      })

      serviceQueue.value = Object.keys(svcLabels).map(function(k) {
        return {service:k, label:svcLabels[k], pending:(svcMap[k]||{}).pending||0, returned:(svcMap[k]||{}).returned||0}
      }).filter(function(s){return s.pending>0||s.returned>0})

      // Alertes
      var devs = await supabase.from('deviations').select('lot_id, declared_at, lots(numero_lot)').in('statut',['ouverte','en_cours']).order('declared_at').limit(5)
      if (devs.data) devs.data.forEach(function(d) {
        var jours = Math.floor((Date.now()-new Date(d.declared_at))/86400000)
        alertes.value.push({level:'critique',lot:d.lots?d.lots.numero_lot:'',msg:'Déviation ouverte depuis '+jours+'j'})
      })

      loaded.value = true
    })

    return { loaded, kpis, monthlyData, serviceQueue, alertes, currentYear, months }
  }
}
</script>
<style scoped>
.dh{display:flex;align-items:baseline;justify-content:space-between;padding-bottom:10px;border-bottom:2px solid #0a0a0a}.dt{font-size:11px;font-weight:500;letter-spacing:1.5px}.dp{font-size:12px;font-family:'SF Mono',monospace;color:#999}
.loading{text-align:center;padding:60px;color:#999}
.ks{display:grid;grid-template-columns:repeat(5,1fr);border:1px solid #e8e8e8;margin:12px 0}
.k{padding:14px 12px;text-align:center;border-right:1px solid #e8e8e8}.k:last-child{border-right:none}
.kv{font-size:22px;font-weight:500;font-family:'SF Mono',monospace}.ku{font-size:13px;font-weight:400;color:#999}.kl{font-size:10px;color:#999;text-transform:uppercase;margin-top:4px}
.section{margin-top:16px}.sh{display:flex;justify-content:space-between;font-size:10px;font-weight:500;text-transform:uppercase;letter-spacing:1px;color:#999;padding-bottom:6px;border-bottom:1px solid #e8e8e8}
.table-wrap{overflow-x:auto;-webkit-overflow-scrolling:touch}
.mtb{width:100%;border-collapse:collapse;font-size:12px;margin-top:4px}.mtb th{font-size:10px;text-transform:uppercase;color:#999;font-weight:500;padding:6px 8px;text-align:center;border-bottom:1px solid #e8e8e8}.mtb th:first-child{text-align:left}
.mtb td{padding:6px 8px;border-bottom:1px solid #f5f5f5;text-align:center}.mtb td:first-child{text-align:left}
.row-label{font-weight:500;font-size:12px;white-space:nowrap}.mono{font-family:'SF Mono',monospace;font-size:11px}
.ytd{background:#fafafa;font-weight:500}.ytd-val{background:#fafafa;font-weight:500;color:#185FA5}
.cw{color:#BA7517}.cd{color:#E24B4A}
.al{display:flex;align-items:center;gap:8px;padding:8px 0;border-bottom:1px solid #f5f5f5;font-size:12px;cursor:pointer;min-height:44px}.al:hover{background:#fafafa}
.ap{width:6px;height:6px;border-radius:50%;flex-shrink:0}.ap-critique{background:#E24B4A}
.aln{font-family:'SF Mono',monospace;font-size:11px;color:#666;min-width:90px}.am{flex:1}
@media(max-width:768px){
  .ks{grid-template-columns:repeat(3,1fr)}
  .k:nth-child(3){border-right:none}
  .k:nth-child(4),.k:nth-child(5){border-top:1px solid #e8e8e8}
  .k:nth-child(5){border-right:none}
  .kv{font-size:18px}
}
@media(max-width:480px){
  .ks{grid-template-columns:repeat(2,1fr)}
  .k:nth-child(2){border-right:none}
  .k:nth-child(3){border-top:1px solid #e8e8e8;border-right:1px solid #e8e8e8}
  .k:nth-child(3n){border-right:none}
  .k:nth-child(4){border-top:1px solid #e8e8e8;border-right:none}
  .k:nth-child(5){border-top:1px solid #e8e8e8;border-right:none}
  .k:nth-child(odd):last-child{grid-column:span 2}
  .kv{font-size:20px}
  .kl{font-size:9px}
  .dh{padding-bottom:8px}
}
</style>
