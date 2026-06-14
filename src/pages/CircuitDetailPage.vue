<template>
  <div v-if="lot">
    <div class="bc"><span @click="goBack"><NavIcon name="arrow-left" :size="13" /> Retour au lot</span></div>
    <div class="lh">
      <div class="lh-info">
        <div class="lh-type"><span class="lt-short">{{type.toUpperCase()}}</span> <span class="lt-full">({{typeFull}})</span></div>
        <div class="lh-lot"><span class="ll-num">{{lot.numero_lot}}</span><span class="ll-prod">{{prod.description}}</span></div>
      </div>
      <div class="lh-right"><span class="ttl">{{statusLabel}}</span></div>
    </div>

    <div v-if="loading || submitting" class="detail-reloading">⟳ Actualisation…</div>

    <!-- Étapes du circuit -->
    <div class="section">
      <div class="sh"><span>Étapes du circuit {{type.toUpperCase()}}</span><span class="dc">{{doneCount}}/{{steps.length}}</span></div>
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
import NavIcon from '../components/NavIcon.vue'
export default {
  components: { NavIcon },
  setup() {
    var route = useRoute(), router = useRouter()
    var type = route.params.type === 'oc' ? 'oc' : 'of'
    var lotId = route.params.lotId
    var lot = ref(null), prod = ref({}), order = ref(null), vals = ref([])
    var loading = ref(false), submitting = ref(false), userId = ref(null), userService = ref('')
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
    var typeFull = type === 'of' ? 'Ordre de fabrication' : 'Ordre de conditionnement'
    var statusLabel = computed(function(){
      var o = order.value; if(!o) return '—'
      if(o.statut==='termine') return 'Terminé'
      if(o.statut==='planifie') return 'Planifié'
      if(o.pending_ar_service) return 'En attente AR — '+(SVC_LABELS[o.pending_ar_service]||o.pending_ar_service)
      var cur = steps.find(function(e){return e.key===o.etape_circuit}); return cur?cur.label:'En cours'
    })

    var getVal = function(etape){ return vals.value.find(function(v){return v.etape===etape}) }
    // terminé = toutes les étapes faites par définition → compteur plein (sinon nb de validations enregistrées)
    var doneCount = computed(function(){ return order.value && order.value.statut === 'termine' ? steps.length : vals.value.length })
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
      if (submitting.value) return false
      var o = order.value
      if (!o || o.statut === 'termine' || o.etape_circuit !== etape) return false
      if (o.pending_ar_service) return (o.pending_ar_service === userService.value || isAdmin.value) && canPerform('accuser_reception_circuit')
      return canValidateStep(etape)
    }
    // Garde anti-double-clic (RÈGLE N°26) : submitting posé DÈS l'entrée, avant tout await
    // (validateOrder écrit avant que load() ne mette loading=true → fenêtre de double-soumission sinon)
    var stepClick = async function(etape){
      if (submitting.value || !stepClickable(etape)) return
      submitting.value = true
      try {
        if (order.value.pending_ar_service) await doAcknowledgeOrderAR()
        else await doValidate(etape)
      } finally {
        submitting.value = false
      }
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

    return { lot, prod, order, vals, loading, submitting, type, steps, userService, isAdmin, doneCount, typeFull, statusLabel,
      fmtDt, stepLabel, getVal, stepIndClass, stepStatus, stepClickable, stepClick, canValidateStep, canPerform, goBack }
  }
}
</script>
<style scoped>
.bc{font-size:12px;color:#2563eb;cursor:pointer;margin-bottom:8px}
.lh{display:flex;align-items:flex-start;justify-content:space-between;padding-bottom:10px;border-bottom:1px solid #e5e7eb;flex-wrap:wrap;gap:10px}
.lh-info{display:flex;flex-direction:column;gap:4px;min-width:0}
.lh-type{font-size:17px;line-height:1.25}.lt-short{font-weight:700}.lt-full{font-size:13px;color:#999;font-weight:400}
.lh-lot{font-size:13px;display:flex;align-items:baseline;gap:8px;flex-wrap:wrap}.ll-num{font-family:'SF Mono',monospace;font-weight:600;font-size:15px}.ll-prod{color:#999}
.lh-right{flex-shrink:0}
.ttl{font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:1px;color:#2563eb;background:#eff6ff;border:1px solid #dbeafe;padding:4px 12px;border-radius:3px;white-space:nowrap}
.loading{text-align:center;padding:60px;color:#999}
.detail-reloading{font-size:11px;color:#999;padding:4px 0 6px;letter-spacing:.3px;animation:spin-txt 1s linear infinite}
@keyframes spin-txt{0%{opacity:1}50%{opacity:.4}100%{opacity:1}}
.section{margin-top:16px}.sh{display:flex;justify-content:space-between;align-items:center;font-size:10px;font-weight:500;text-transform:uppercase;letter-spacing:1px;color:#999;padding-bottom:6px;border-bottom:1px solid #e8e8e8}
.dc{font-family:'SF Mono',monospace;color:#BA7517}
.dg{display:grid;grid-template-columns:1fr 1fr;border:1px solid #e8e8e8}
.dg-1{grid-template-columns:1fr}
.di{padding:10px 12px;border-right:1px solid #e8e8e8;border-bottom:1px solid #e8e8e8;display:flex;gap:10px;cursor:default}.dg-1 .di{border-right:none}.di:last-child{border-bottom:none}
.di-act{cursor:pointer}.di-act:hover{background:#eff6ff}.di-act .ds{color:#2563eb;font-weight:500}
.dind{width:3px;height:36px;border-radius:1px;flex-shrink:0}.ind-wait{background:#e8e8e8}.ind-prog{background:#2563eb}.ind-done{background:#1D9E75}
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
