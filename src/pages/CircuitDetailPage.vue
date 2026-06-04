<template>
  <div v-if="lot">
    <div class="bc"><span @click="goBack">← Retour au lot</span></div>
    <div class="lh">
      <div><span class="ln">{{lot.numero_lot}}</span><span class="lp">{{prod.description}}</span></div>
      <div class="lh-right"><span class="ttl">Circuit {{type.toUpperCase()}}</span></div>
    </div>

    <div v-if="loading" class="detail-reloading">⟳ Actualisation…</div>

    <!-- Étapes du circuit -->
    <div class="section">
      <div class="sh"><span>Étapes du circuit {{type.toUpperCase()}}</span><span class="dc">{{vals.length}}/{{steps.length}}</span></div>
      <div class="dg dg-1">
        <div class="di" v-for="(e,idx) in steps" :key="e.key" :class="{'di-act':stepClickable(e.key)}" @click="stepClick(e.key)">
          <div class="dind" :class="stepIndClass(e.key)"></div>
          <div class="di-body">
            <div class="dn">{{idx+1}}. {{e.label}}</div>
            <div class="ds" :class="getVal(e.key)?'ds-ok':''">{{stepStatus(e.key)}}</div>
            <div class="di-svc">Service : {{e.service}}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Historique -->
    <div class="section" v-if="vals.length">
      <div class="sh"><span>Historique des validations</span></div>
      <div class="circ-hist">
        <div class="circ-hist-row" v-for="v in vals" :key="v.etape">
          <span class="circ-hist-dot"></span>
          <span class="circ-hist-step">{{stepLabel(v.etape)}}</span>
          <span class="circ-hist-who">{{v.user}}</span>
          <span class="circ-hist-at">{{fmtDt(v.validated_at)}}</span>
        </div>
      </div>
    </div>
  </div>
  <div v-else class="loading">Chargement...</div>
</template>
<script>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { loadPermissions, canPerform, getPermissionForEtape } from '../services/permissions'
import { validateOrder } from '../services/actions'
export default {
  setup() {
    var route = useRoute(), router = useRouter()
    var type = route.params.type === 'oc' ? 'oc' : 'of'
    var lotId = route.params.lotId
    var lot = ref(null), prod = ref({}), order = ref(null), vals = ref([])
    var loading = ref(false), userId = ref(null), userService = ref('')
    var isAdmin = computed(function(){ return userService.value === 'admin' })
    var steps = [
      {key:'planification',label:'Mise en circuit',service:'Planification'},
      {key:'stock',label:'Validation quantités',service:'Stock'},
      {key:'aq',label:'Validation AQ',service:'AQ'},
      {key:'dt',label:'Autorisation lancement',service:'DT'},
      {key:'aq_dap',label:'Remise à Production',service:'AQ DAP'},
      {key:'production',label:'Accusé réception',service:'Production'},
    ]
    var SVC_LABELS = {planification:'Planification',stock:'Stock',aq:'AQ',aq_dap:'AQ DAP',dt:'DT',fabrication:'Fabrication',conditionnement:'Conditionnement',lcq:'LCQ',admin:'Admin'}
    var fmtDt = function(d){ return d ? new Date(d).toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}) : '' }
    var stepLabel = function(etape){ var e = steps.find(function(s){return s.key===etape}); return e ? e.label : etape }

    var getVal = function(etape){ return vals.value.find(function(v){return v.etape===etape}) }
    var canValidateStep = function(etape){
      if (isAdmin.value) return true
      var k = getPermissionForEtape(etape, type)
      return k ? canPerform(k) : false
    }
    var stepIndClass = function(etape){
      if (order.value && order.value.statut === 'termine') return 'ind-done'
      if (getVal(etape)) return 'ind-done'
      return order.value && order.value.etape_circuit === etape ? 'ind-prog' : 'ind-wait'
    }
    var stepStatus = function(etape){
      var v = getVal(etape)
      if (v) return '✓ Validé — ' + (v.user||'') + ' · ' + fmtDt(v.validated_at)
      if (order.value && order.value.statut === 'termine') return '✓ Terminé'
      if (order.value && order.value.etape_circuit === etape) {
        if (order.value.pending_ar_service) return '⏳ En attente AR — ' + (SVC_LABELS[order.value.pending_ar_service]||order.value.pending_ar_service)
        if (canValidateStep(etape)) return '＋ À valider'
        return 'En cours'
      }
      return 'À venir'
    }
    var stepClickable = function(etape){
      var o = order.value
      if (!o || o.statut === 'termine' || o.etape_circuit !== etape) return false
      if (o.pending_ar_service) return (o.pending_ar_service === userService.value || isAdmin.value) && canPerform('accuser_reception_circuit')
      return canValidateStep(etape)
    }
    var stepClick = function(etape){
      if (!stepClickable(etape)) return
      if (order.value.pending_ar_service) doAcknowledgeOrderAR()
      else doValidate(etape)
    }

    var doValidate = async function(etape){
      await validateOrder(type, order.value.id, etape, userId.value, lot.value.id)
      await load()
    }
    var doAcknowledgeOrderAR = async function(){
      var now = new Date().toISOString()
      var tbl = type === 'of' ? 'orders_of' : 'orders_oc'
      var res = await supabase.from(tbl).update({pending_ar_service:null,updated_at:now}).eq('id',order.value.id)
      if (res.error){ alert('Erreur AR : '+res.error.message); return }
      await supabase.from('lot_events').insert({lot_id:lot.value.id,event_type:'ar_circuit',description:'AR circuit '+type.toUpperCase(),triggered_by:userId.value,created_at:now})
      await load()
    }

    var goBack = function(){ router.push('/lots/'+lotId) }

    var load = async function(){
      loading.value = true
      try {
        var tbl = type === 'of' ? 'orders_of' : 'orders_oc'
        var r1 = await Promise.all([
          supabase.from('lots').select('*').eq('id',lotId).single(),
          supabase.from(tbl).select('*').eq('lot_id',lotId).maybeSingle(),
        ])
        var l = r1[0].data
        if (!l){ console.error('CircuitDetail: lot introuvable',lotId); return }
        lot.value = l
        order.value = r1[1].data
        var r2 = await Promise.all([
          supabase.from('products').select('*').eq('id',l.product_id).single(),
          order.value ? supabase.from('order_validations').select('*,profiles(prenom,nom)').eq('order_type',type).eq('order_id',order.value.id).order('validated_at') : Promise.resolve({data:[]}),
        ])
        prod.value = r2[0].data || {}
        vals.value = (r2[1].data||[]).map(function(v){ return {etape:v.etape,validated_at:v.validated_at,user:v.profiles?v.profiles.prenom+' '+v.profiles.nom:''} })
      } catch(e) {
        console.error('CircuitDetail load erreur:',e)
      } finally {
        loading.value = false
      }
    }

    onMounted(async function(){
      var u = await supabase.auth.getUser(); userId.value = u.data.user.id
      var p = await supabase.from('profiles').select('service').eq('id',u.data.user.id).single()
      if (p.data){ userService.value = p.data.service; await loadPermissions(p.data.service) }
      await load()
    })

    return { lot, prod, order, vals, loading, type, steps, userService, isAdmin,
      fmtDt, stepLabel, getVal, stepIndClass, stepStatus, stepClickable, stepClick, canValidateStep, canPerform, goBack }
  }
}
</script>
<style scoped>
.bc{font-size:12px;color:#7c3aed;cursor:pointer;margin-bottom:8px}
.lh{display:flex;align-items:center;justify-content:space-between;padding-bottom:8px;border-bottom:1px solid #e5e7eb;flex-wrap:wrap;gap:8px}
.lh-right{display:flex;align-items:center;gap:6px}
.ln{font-size:22px;font-weight:500;font-family:'SF Mono',monospace}.lp{font-size:13px;color:#666;margin-left:10px}
.ttl{font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:1px;color:#7c3aed;background:#f5f3ff;border:1px solid #ede9fe;padding:4px 12px;border-radius:3px}
.loading{text-align:center;padding:60px;color:#999}
.detail-reloading{font-size:11px;color:#999;padding:4px 0 6px;letter-spacing:.3px;animation:spin-txt 1s linear infinite}
@keyframes spin-txt{0%{opacity:1}50%{opacity:.4}100%{opacity:1}}
.section{margin-top:16px}.sh{display:flex;justify-content:space-between;align-items:center;font-size:10px;font-weight:500;text-transform:uppercase;letter-spacing:1px;color:#999;padding-bottom:6px;border-bottom:1px solid #e8e8e8}
.dc{font-family:'SF Mono',monospace;color:#BA7517}
.dg{display:grid;grid-template-columns:1fr 1fr;border:1px solid #e8e8e8}
.dg-1{grid-template-columns:1fr}
.di{padding:10px 12px;border-right:1px solid #e8e8e8;border-bottom:1px solid #e8e8e8;display:flex;gap:10px;cursor:default}.dg-1 .di{border-right:none}.di:last-child{border-bottom:none}
.di-act{cursor:pointer}.di-act:hover{background:#f5f3ff}.di-act .ds{color:#7c3aed;font-weight:500}
.dind{width:3px;height:36px;border-radius:1px;flex-shrink:0}.ind-wait{background:#e8e8e8}.ind-prog{background:#7c3aed}.ind-done{background:#1D9E75}
.di-body{flex:1;min-width:0}
.dn{font-size:13px;font-weight:500}.ds{font-size:11px;color:#999;margin-top:1px}.ds-ok{color:#1D9E75}
.di-svc{font-size:10px;color:#bbb;margin-top:2px}
.circ-hist{margin-top:10px;border:1px solid #e8e8e8;padding:8px 12px;display:flex;flex-direction:column;gap:2px}
.circ-hist-row{display:flex;align-items:center;gap:8px;font-size:11px;padding:4px 0;border-bottom:1px solid #f8f8f8}.circ-hist-row:last-child{border-bottom:none}
.circ-hist-dot{width:6px;height:6px;border-radius:50%;background:#1D9E75;flex-shrink:0}
.circ-hist-step{font-weight:500;color:#333;flex:1}
.circ-hist-who{color:#999}
.circ-hist-at{font-family:'SF Mono',monospace;font-size:10px;color:#bbb}
@media(max-width:768px){.dg{grid-template-columns:1fr}}
</style>
