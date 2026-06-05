<template>
  <div v-if="lot">
    <div class="bc"><span @click="goBack">← Retour au lot</span></div>
    <div class="lh">
      <div><span class="ln">{{lot.numero_lot}}</span><span class="lp">{{prod.description}}</span></div>
      <div class="lh-right"><span class="ttl">AQL {{typeLabel}}</span><span class="ttl-full">Acceptable quality level</span></div>
    </div>

    <div v-if="loading" class="detail-reloading">⟳ Actualisation…</div>

    <!-- Étapes du parcours AQL -->
    <div class="section">
      <div class="sh"><span>Parcours AQL {{typeLabel}}</span><span class="dc" :class="cur && cur.resultat==='non_conforme' && allDone?'dc-ko':''">{{doneCount}}/{{steps.length}}</span></div>
      <div class="dg dg-1">
        <div class="di" v-for="(e,idx) in steps" :key="e.key" :class="{'di-act':stepClickable(e.key)}" @click="stepClick(e.key)">
          <div class="dind" :class="stepIndClass(e.key)"></div>
          <div class="di-body">
            <div class="dn">{{idx+1}}. {{e.label}}</div>
            <div class="ds" :class="dsClass(e.key)">{{stepStatus(e.key)}}</div>
            <div class="di-svc">Service : {{e.service}}</div>
            <div v-if="e.key==='realisation' && realisationActionable" class="aql-choice" @click.stop>
              <button class="btn-c" @click="doConforme">✓ Conforme</button>
              <button class="btn-nc" @click="doNonConforme">✗ Non conforme</button>
            </div>
            <div v-if="e.key==='ar_resultat' && relanceActionable" class="aql-choice" @click.stop>
              <button class="btn-relance" @click="doRelance">↻ Relancer un nouvel AQL</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Historique des tentatives -->
    <div class="section" v-if="aqls.length">
      <div class="sh"><span>Historique AQL {{typeLabel}}</span></div>
      <div class="circ-hist">
        <div class="circ-hist-row" v-for="a in aqls" :key="a.id">
          <span class="circ-hist-dot" :class="a.resultat==='conforme'?'dot-ok':a.resultat==='non_conforme'?'dot-ko':'dot-wait'"></span>
          <span class="circ-hist-step">{{a.resultat==='en_attente'?'En attente':a.resultat==='conforme'?'Conforme':'Non conforme'}}</span>
          <span class="circ-hist-who">Demandé {{fmtDt(a.requested_at)}}</span>
          <span class="circ-hist-at">{{a.inspected_at?'Réalisé '+fmtDt(a.inspected_at):''}}</span>
        </div>
      </div>
    </div>
  </div>
  <div v-else class="loading">Chargement...</div>
</template>
<script>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { loadPermissions, canPerform } from '../services/permissions'
import { requestAql, acknowledgeAqlRequest, respondAql, acknowledgeAqlResult } from '../services/actions'
export default {
  setup() {
    var route = useRoute(), router = useRouter()
    var type = route.params.type === 'conditionnement' ? 'conditionnement' : 'fabrication'
    var lotId = route.params.lotId
    var svcEm = type === 'fabrication' ? 'Fabrication' : 'Conditionnement'
    var typeLabel = computed(function(){ return svcEm })
    var lot = ref(null), prod = ref({}), aqls = ref([])
    var loading = ref(false), userId = ref(null), userService = ref('')
    var isAdmin = computed(function(){ return userService.value === 'admin' })
    var steps = [
      {key:'demande',     label:'Demande AQL',                 service: svcEm},
      {key:'ar_demande',  label:'Accusé réception demande',    service:'AQ'},
      {key:'realisation', label:'Réalisation (inspection)',    service:'LCQ'},
      {key:'ar_resultat', label:'Accusé réception résultat',   service: svcEm},
    ]
    // Inspection courante = la plus récente (les relances créent une nouvelle ligne)
    var cur = computed(function(){ return aqls.value.length ? aqls.value[0] : null })

    var fmtDt = function(d){ return d ? new Date(d).toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}) : '' }

    var stepDone = function(key){
      var a = cur.value; if (!a) return false
      if (key === 'demande') return true
      if (key === 'ar_demande') return a.request_ar_pending === false
      if (key === 'realisation') return a.resultat !== 'en_attente'
      if (key === 'ar_resultat') return a.resultat !== 'en_attente' && a.result_ar_pending === false
      return false
    }
    var currentStep = computed(function(){
      var a = cur.value
      if (!a) return 'demande'
      if (a.request_ar_pending) return 'ar_demande'
      if (a.resultat === 'en_attente') return 'realisation'
      if (a.result_ar_pending) return 'ar_resultat'
      return null
    })
    var allDone = computed(function(){ return cur.value && currentStep.value === null })
    var doneCount = computed(function(){ var n=0; steps.forEach(function(e){ if (stepDone(e.key)) n++ }); return n })

    var permFor = {
      demande: 'demander_aql_' + (type==='fabrication'?'fab':'cond'),
      ar_demande: 'accuser_reception_aql_demande',
      realisation: 'realiser_aql',
      ar_resultat: 'accuser_reception_aql_resultat'
    }
    var canStep = function(key){ return isAdmin.value || canPerform(permFor[key]) }

    var stepIndClass = function(key){
      if (stepDone(key)){
        if (key==='realisation' && cur.value && cur.value.resultat==='non_conforme') return 'ind-ko'
        return 'ind-done'
      }
      return currentStep.value === key ? 'ind-prog' : 'ind-wait'
    }
    var dsClass = function(key){
      if (key==='realisation' && stepDone(key) && cur.value && cur.value.resultat==='non_conforme') return 'ds-ko'
      if (stepDone(key)) return 'ds-ok'
      return ''
    }
    var stepStatus = function(key){
      var a = cur.value
      if (stepDone(key)){
        if (key==='demande')     return '✓ Demandé — ' + fmtDt(a.requested_at)
        if (key==='ar_demande')  return '✓ Accusé réception'
        if (key==='realisation') return (a.resultat==='conforme'?'✓ Conforme':'✗ Non conforme') + ' — ' + fmtDt(a.inspected_at)
        if (key==='ar_resultat') return '✓ Accusé réception'
      }
      if (currentStep.value === key){
        if (key==='demande')     return canStep(key) ? '＋ Demander l’AQL' : 'À demander'
        if (key==='ar_demande')  return canStep(key) ? '＋ Accuser réception' : '⏳ En attente AR — AQ'
        if (key==='realisation') return canStep(key) ? 'À réaliser — Conforme / Non conforme' : '⏳ En attente LCQ'
        if (key==='ar_resultat') return canStep(key) ? '＋ Accuser réception du résultat' : '⏳ En attente AR'
      }
      return 'À venir'
    }
    var stepClickable = function(key){
      if (currentStep.value !== key) return false
      if (key === 'realisation') return false // géré par les 2 boutons Conforme/Non conforme
      return canStep(key)
    }
    var realisationActionable = computed(function(){ return currentStep.value === 'realisation' && canStep('realisation') })
    var relanceActionable = computed(function(){ return allDone.value && cur.value && cur.value.resultat === 'non_conforme' && canStep('demande') })

    var stepClick = function(key){
      if (!stepClickable(key)) return
      if (key === 'demande') doDemande()
      else if (key === 'ar_demande') doArDemande()
      else if (key === 'ar_resultat') doArResultat()
    }
    var doDemande = async function(){ await requestAql(lot.value.id, type, userId.value); await load() }
    var doArDemande = async function(){ var e = await acknowledgeAqlRequest(cur.value.id, userId.value, lot.value.id); if(e){alert('Erreur : '+(e.message||e));return} await load() }
    var doConforme = async function(){ await respondAql(cur.value.id, 'conforme', '', userId.value, lot.value.id); await load() }
    var doNonConforme = async function(){ await respondAql(cur.value.id, 'non_conforme', '', userId.value, lot.value.id); await load() }
    var doArResultat = async function(){ var e = await acknowledgeAqlResult(cur.value.id, userId.value, lot.value.id); if(e){alert('Erreur : '+(e.message||e));return} await load() }
    var doRelance = async function(){ await requestAql(lot.value.id, type, userId.value); await load() }

    var goBack = function(){ router.push('/lots/'+lotId) }

    var load = async function(){
      loading.value = true
      try {
        var r1 = await Promise.all([
          supabase.from('lots').select('*').eq('id', lotId).single(),
          supabase.from('aql_inspections').select('*').eq('lot_id', lotId).eq('type', type).order('requested_at', { ascending: false }),
        ])
        var l = r1[0].data
        if (!l){ console.error('AqlDetail: lot introuvable', lotId); return }
        lot.value = l
        aqls.value = r1[1].data || []
        var pr = await supabase.from('products').select('*').eq('id', l.product_id).single()
        prod.value = pr.data || {}
      } catch(e){ console.error('AqlDetail load erreur:', e) }
      finally { loading.value = false }
    }

    onMounted(async function(){
      var u = await supabase.auth.getUser(); userId.value = u.data.user.id
      var p = await supabase.from('profiles').select('service').eq('id', u.data.user.id).single()
      if (p.data){ userService.value = p.data.service; await loadPermissions(p.data.service) }
      await load()
    })
    // Naviguer directement vers un autre AQL/lot (type ou lotId figés à la création) → recharger
    watch(function(){ return route.params.lotId + '|' + route.params.type }, function(nv, ov){ if (nv !== ov) location.reload() })

    return { lot, prod, aqls, loading, type, typeLabel, steps, userService, isAdmin, cur, doneCount, allDone,
      stepIndClass, dsClass, stepStatus, stepClickable, stepClick, realisationActionable, relanceActionable,
      doConforme, doNonConforme, doRelance, fmtDt, goBack, canPerform }
  }
}
</script>
<style scoped>
.bc{font-size:12px;color:#7c3aed;cursor:pointer;margin-bottom:8px}
.lh{display:flex;align-items:center;justify-content:space-between;padding-bottom:8px;border-bottom:1px solid #e5e7eb;flex-wrap:wrap;gap:8px}
.lh-right{display:flex;flex-direction:column;align-items:flex-end;gap:3px}
.ttl-full{font-size:10px;color:#999}
.ln{font-size:22px;font-weight:500;font-family:'SF Mono',monospace}.lp{font-size:13px;color:#666;margin-left:10px}
.ttl{font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:1px;color:#7c3aed;background:#f5f3ff;border:1px solid #ede9fe;padding:4px 12px;border-radius:3px}
.loading{text-align:center;padding:60px;color:#999}
.detail-reloading{font-size:11px;color:#999;padding:4px 0 6px;letter-spacing:.3px;animation:spin-txt 1s linear infinite}
@keyframes spin-txt{0%{opacity:1}50%{opacity:.4}100%{opacity:1}}
.section{margin-top:16px}.sh{display:flex;justify-content:space-between;align-items:center;font-size:10px;font-weight:500;text-transform:uppercase;letter-spacing:1px;color:#999;padding-bottom:6px;border-bottom:1px solid #e8e8e8}
.dc{font-family:'SF Mono',monospace;color:#BA7517}.dc-ko{color:#A32D2D}
.dg{display:grid;grid-template-columns:1fr 1fr;border:1px solid #e8e8e8}
.dg-1{grid-template-columns:1fr}
.di{padding:10px 12px;border-right:1px solid #e8e8e8;border-bottom:1px solid #e8e8e8;display:flex;gap:10px;cursor:default}.dg-1 .di{border-right:none}.di:last-child{border-bottom:none}
.di-act{cursor:pointer}.di-act:hover{background:#f5f3ff}.di-act .ds{color:#7c3aed;font-weight:500}
.dind{width:3px;height:36px;border-radius:1px;flex-shrink:0}.ind-wait{background:#e8e8e8}.ind-prog{background:#7c3aed}.ind-done{background:#1D9E75}.ind-ko{background:#E24B4A}
.di-body{flex:1;min-width:0}
.dn{font-size:13px;font-weight:500}.ds{font-size:11px;color:#999;margin-top:1px}.ds-ok{color:#1D9E75}.ds-ko{color:#E24B4A}
.di-svc{font-size:10px;color:#bbb;margin-top:2px}
.aql-choice{display:flex;gap:8px;margin-top:8px;flex-wrap:wrap}
.btn-c,.btn-nc,.btn-relance{font-size:11px;font-weight:600;padding:5px 12px;border-radius:3px;border:none;cursor:pointer}
.btn-c{background:#1D9E75;color:#fff}.btn-c:hover{background:#178a65}
.btn-nc{background:#E24B4A;color:#fff}.btn-nc:hover{background:#c93f3e}
.btn-relance{background:transparent;border:1px solid #7c3aed;color:#7c3aed}.btn-relance:hover{background:#f5f3ff}
.circ-hist{margin-top:10px;border:1px solid #e8e8e8;padding:8px 12px;display:flex;flex-direction:column;gap:2px}
.circ-hist-row{display:flex;align-items:center;gap:8px;font-size:11px;padding:4px 0;border-bottom:1px solid #f8f8f8}.circ-hist-row:last-child{border-bottom:none}
.circ-hist-dot{width:6px;height:6px;border-radius:50%;flex-shrink:0;background:#bbb}.dot-ok{background:#1D9E75}.dot-ko{background:#E24B4A}.dot-wait{background:#BA7517}
.circ-hist-step{font-weight:500;color:#333;flex:1}
.circ-hist-who{color:#999}
.circ-hist-at{font-family:'SF Mono',monospace;font-size:10px;color:#bbb}
@media(max-width:768px){.dg{grid-template-columns:1fr}}
</style>
