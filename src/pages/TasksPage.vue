<template>
  <div class="tp">

    <!-- En-tête -->
    <div class="tp-hd">
      <div class="tp-hd-left">
        <span class="tp-hd-icon">📋</span>
        <div>
          <div class="tp-h1">Tâches en attente</div>
          <div class="tp-h2">{{svcLabel}}</div>
        </div>
      </div>
      <div class="tp-hd-right">
        <span class="tp-total" :class="totalCount>0?'tp-total-bad':'tp-total-ok'">
          {{totalCount}} tâche{{totalCount!==1?'s':''}} en attente
        </span>
        <button class="tp-refresh" @click="load" :disabled="loading">{{loading?'⟳':'↻'}} Rafraîchir</button>
      </div>
    </div>

    <!-- Chargement -->
    <div v-if="loading" class="tp-loading">⟳ Chargement…</div>

    <!-- Vide -->
    <div v-else-if="!loading && totalCount===0" class="tp-empty">
      <span class="tp-empty-icon">✓</span>
      <div class="tp-empty-txt">Aucune tâche en attente pour votre service</div>
    </div>

    <!-- Catégories -->
    <div v-else class="tp-cats">
      <div v-for="cat in categories" :key="cat.id" v-show="cat.items.length" class="tp-cat">
        <!-- En-tête catégorie -->
        <div class="tp-cat-hd" @click="cat.open=!cat.open">
          <span class="tp-cat-icon">{{cat.icon}}</span>
          <span class="tp-cat-title">{{cat.title}}</span>
          <span class="tp-cat-badge" :class="cat.urgent?'tp-badge-red':'tp-badge-orange'">{{cat.items.length}}</span>
          <span class="tp-cat-chev">{{cat.open?'▲':'▼'}}</span>
        </div>
        <!-- Liste items -->
        <div v-if="cat.open" class="tp-cat-list">
          <div v-for="item in cat.items" :key="item.key" class="tp-item" @click="$router.push('/lots/'+item.lotId)">
            <div class="tp-item-main">
              <span class="tp-item-lot">{{item.lotNum}}</span>
              <span v-if="item.urgent" class="tp-item-bl">⚠ BLQ</span>
              <span class="tp-item-prod">{{item.prodDesc}}</span>
            </div>
            <div class="tp-item-right">
              <span class="tp-item-action" :class="item.urgent?'tp-action-red':'tp-action-blue'">{{item.action}}</span>
              <span class="tp-item-arr">→</span>
            </div>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>
<script>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'

export default {
  setup() {
    var userService = ref('')
    var loading = ref(true)
    var categories = ref([])

    var SVC_LABELS = {planification:'Planification',stock:'Stock',aq:'Assurance Qualité',aq_dap:'AQ DAP',dt:'Direction Technique',fabrication:'Fabrication',conditionnement:'Conditionnement',lcq:'Laboratoire CQ',admin:'Administration'}
    var DOC_TYPE_LABELS = {if:'IF',ic:'IC',da_pc:'DA Physico',da_micro:'DA Micro',rvp:'RVP',maj_if:'MàJ IF',maj_ic:'MàJ IC',maj_nmcl_of:'MàJ N. OF',maj_nmcl_oc:'MàJ N. OC',cloture_sap_of:'Clôt. OF',cloture_sap_oc:'Clôt. OC'}

    var svcLabel = computed(function(){ return SVC_LABELS[userService.value] || userService.value })
    var totalCount = computed(function(){ return categories.value.reduce(function(s,c){ return s+c.items.length },0) })

    var makeCat = function(id,icon,title,urgent) {
      return {id:id,icon:icon,title:title,urgent:urgent||false,open:true,items:[]}
    }

    var load = async function() {
      loading.value = true
      var cats = []
      var svc = userService.value
      if (!svc) { loading.value = false; return }

      var isAdmin = svc === 'aq' // admin sees all? No, keep per-service

      // ── 1. CIRCUITS À VALIDER ──────────────────────────────────────
      var circEtapeMap = {planification:'planification',stock:'stock',aq:'aq',dt:'dt',aq_dap:'aq_dap'}
      var circEtape = circEtapeMap[svc]
      if (circEtape || svc==='fabrication' || svc==='conditionnement') {
        var circCat = makeCat('circuits','🔄','Circuits à valider / réceptionner')
        // OF
        var ofQ = supabase.from('orders_of').select('id,lot_id,etape_circuit,lots!inner(id,numero_lot,prod_desc,prod_code)').eq('statut','en_circuit')
        if (svc==='fabrication') ofQ = ofQ.eq('etape_circuit','production')
        else if (circEtape) ofQ = ofQ.eq('etape_circuit',circEtape)
        else ofQ = null
        if (ofQ) {
          var ofRes = await ofQ
          ;(ofRes.data||[]).forEach(function(o){
            circCat.items.push({key:'of_'+o.id,lotId:o.lots.id,lotNum:o.lots.numero_lot,prodDesc:o.lots.prod_desc||o.lots.prod_code,action:'Circuit OF — '+(o.etape_circuit||'')})
          })
        }
        // OC
        var ocQ = supabase.from('orders_oc').select('id,lot_id,etape_circuit,lots!inner(id,numero_lot,prod_desc,prod_code)').eq('statut','en_circuit')
        if (svc==='conditionnement') ocQ = ocQ.eq('etape_circuit','production')
        else if (svc==='fabrication') ocQ = null
        else if (circEtape) ocQ = ocQ.eq('etape_circuit',circEtape)
        else ocQ = null
        if (ocQ) {
          var ocRes = await ocQ
          ;(ocRes.data||[]).forEach(function(o){
            circCat.items.push({key:'oc_'+o.id,lotId:o.lots.id,lotNum:o.lots.numero_lot,prodDesc:o.lots.prod_desc||o.lots.prod_code,action:'Circuit OC — '+(o.etape_circuit||'')})
          })
        }
        if (circCat.items.length) cats.push(circCat)
      }

      // ── 2. DOCUMENTS À TRAITER ─────────────────────────────────────
      var docCat = makeCat('docs','📄','Documents à traiter')
      if (svc==='aq') {
        // AQ : vérifier les docs émis ou en vérification
        var daqRes = await supabase.from('liberation_documents')
          .select('id,type_document,statut,lot_id,lots!inner(id,numero_lot,prod_desc,prod_code)')
          .in('statut',['emis','verification_aq'])
          .in('type_document',['if','ic','da_pc','da_micro','rvp','maj_if','maj_ic','maj_nmcl_of','maj_nmcl_oc'])
          .eq('is_applicable',true)
        ;(daqRes.data||[]).forEach(function(d){
          var lbl = d.statut==='verification_aq'?'Vérifier (retour DT)':'Vérifier AQ → DT'
          docCat.items.push({key:'doc_'+d.id,lotId:d.lots.id,lotNum:d.lots.numero_lot,prodDesc:d.lots.prod_desc||d.lots.prod_code,action:(DOC_TYPE_LABELS[d.type_document]||d.type_document)+' — '+lbl})
        })
      } else if (svc==='dt') {
        // DT : approuver les docs vérifiés AQ
        var ddtRes = await supabase.from('liberation_documents')
          .select('id,type_document,statut,lot_id,lots!inner(id,numero_lot,prod_desc,prod_code)')
          .eq('statut','approuve_aq')
          .in('type_document',['if','ic','da_pc','da_micro','rvp','maj_if','maj_ic','maj_nmcl_of','maj_nmcl_oc'])
          .eq('is_applicable',true)
        ;(ddtRes.data||[]).forEach(function(d){
          docCat.items.push({key:'doc_'+d.id,lotId:d.lots.id,lotNum:d.lots.numero_lot,prodDesc:d.lots.prod_desc||d.lots.prod_code,action:(DOC_TYPE_LABELS[d.type_document]||d.type_document)+' — Approuver DT'})
        })
      } else {
        // Émetteurs : rectifier les docs retournés
        var dEmtRes = await supabase.from('liberation_documents')
          .select('id,type_document,statut,service_emetteur,lot_id,lots!inner(id,numero_lot,prod_desc,prod_code)')
          .eq('statut','retour_emetteur')
          .eq('service_emetteur',svc)
          .eq('is_applicable',true)
        ;(dEmtRes.data||[]).forEach(function(d){
          docCat.items.push({key:'doc_'+d.id,lotId:d.lots.id,lotNum:d.lots.numero_lot,prodDesc:d.lots.prod_desc||d.lots.prod_code,action:(DOC_TYPE_LABELS[d.type_document]||d.type_document)+' — Rectifier et réémettre'})
        })
      }
      if (docCat.items.length) cats.push(docCat)

      // ── 3. ACCUSÉS DE RÉCEPTION ────────────────────────────────────
      var arCat = makeCat('ar','✅','Accusés de réception à confirmer')
      // AR sur documents
      var arDocRes = await supabase.from('liberation_documents')
        .select('id,type_document,lot_id,lots!inner(id,numero_lot,prod_desc,prod_code)')
        .eq('pending_ar_service',svc)
      ;(arDocRes.data||[]).forEach(function(d){
        arCat.items.push({key:'ar_doc_'+d.id,lotId:d.lots.id,lotNum:d.lots.numero_lot,prodDesc:d.lots.prod_desc||d.lots.prod_code,action:(DOC_TYPE_LABELS[d.type_document]||d.type_document)+' — Accuser réception'})
      })
      // AR sur circuit OF
      var arOfRes = await supabase.from('orders_of')
        .select('id,lot_id,etape_circuit,lots!inner(id,numero_lot,prod_desc,prod_code)')
        .eq('pending_ar_service',svc)
      ;(arOfRes.data||[]).forEach(function(o){
        arCat.items.push({key:'ar_of_'+o.id,lotId:o.lots.id,lotNum:o.lots.numero_lot,prodDesc:o.lots.prod_desc||o.lots.prod_code,action:'Circuit OF — Accuser réception ('+o.etape_circuit+')'})
      })
      // AR sur circuit OC
      var arOcRes = await supabase.from('orders_oc')
        .select('id,lot_id,etape_circuit,lots!inner(id,numero_lot,prod_desc,prod_code)')
        .eq('pending_ar_service',svc)
      ;(arOcRes.data||[]).forEach(function(o){
        arCat.items.push({key:'ar_oc_'+o.id,lotId:o.lots.id,lotNum:o.lots.numero_lot,prodDesc:o.lots.prod_desc||o.lots.prod_code,action:'Circuit OC — Accuser réception ('+o.etape_circuit+')'})
      })
      // AR AQL demande (AQ/LCQ confirment réception de la demande)
      if (svc==='aq'||svc==='lcq') {
        var arAqlDemRes = await supabase.from('aql_inspections')
          .select('id,type,lot_id,lots!inner(id,numero_lot,prod_desc,prod_code)')
          .eq('request_ar_pending',true)
        ;(arAqlDemRes.data||[]).forEach(function(a){
          arCat.items.push({key:'ar_aql_dem_'+a.id,lotId:a.lots.id,lotNum:a.lots.numero_lot,prodDesc:a.lots.prod_desc||a.lots.prod_code,action:'AQL '+a.type+' — AR demande inspection'})
        })
      }
      // AR AQL résultat (Fabrication/Conditionnement reçoivent le résultat)
      if (svc==='fabrication'||svc==='conditionnement') {
        var aqlTypeForSvc = svc==='fabrication'?'fabrication':'conditionnement'
        var arAqlResRes = await supabase.from('aql_inspections')
          .select('id,type,resultat,lot_id,lots!inner(id,numero_lot,prod_desc,prod_code)')
          .eq('result_ar_pending',true)
          .eq('type',aqlTypeForSvc)
        ;(arAqlResRes.data||[]).forEach(function(a){
          arCat.items.push({key:'ar_aql_res_'+a.id,lotId:a.lots.id,lotNum:a.lots.numero_lot,prodDesc:a.lots.prod_desc||a.lots.prod_code,action:'AQL '+a.type+' — AR résultat ('+a.resultat+')'})
        })
      }
      if (arCat.items.length) cats.push(arCat)

      // ── 4. AQL À RÉALISER ──────────────────────────────────────────
      if (svc==='fabrication'||svc==='conditionnement') {
        var aqlCat = makeCat('aql','🔬','Inspections AQL à réaliser')
        var aqlTypeVal = svc==='fabrication'?'fabrication':'conditionnement'
        var aqlRes = await supabase.from('aql_inspections')
          .select('id,type,requested_at,lot_id,lots!inner(id,numero_lot,prod_desc,prod_code)')
          .eq('type',aqlTypeVal)
          .eq('resultat','en_attente')
          .order('requested_at',{ascending:true})
        ;(aqlRes.data||[]).forEach(function(a){
          aqlCat.items.push({key:'aql_'+a.id,lotId:a.lots.id,lotNum:a.lots.numero_lot,prodDesc:a.lots.prod_desc||a.lots.prod_code,action:'AQL '+a.type+' — Résultat à saisir'})
        })
        if (aqlCat.items.length) cats.push(aqlCat)
      }

      // ── 5. DÉVIATIONS BLOQUANTES ───────────────────────────────────
      if (svc==='aq'||svc==='dt'||svc==='admin') {
        var devCat = makeCat('dev','⚠','Déviations bloquantes ouvertes',true)
        var devRes = await supabase.from('deviations')
          .select('id,lot_id,numero_dn,description,lots!inner(id,numero_lot,prod_desc,prod_code)')
          .eq('bloquante',true)
          .in('statut',['ouverte','en_cours'])
          .order('declared_at',{ascending:false})
        ;(devRes.data||[]).forEach(function(d){
          devCat.items.push({key:'dev_'+d.id,lotId:d.lots.id,lotNum:d.lots.numero_lot,prodDesc:d.lots.prod_desc||d.lots.prod_code,action:'Déviation bloquante'+(d.numero_dn?' ('+d.numero_dn+')':''),urgent:true})
        })
        if (devCat.items.length) cats.push(devCat)
      }

      categories.value = cats
      loading.value = false
    }

    onMounted(async function(){
      var u = await supabase.auth.getUser()
      if (u.data.user) {
        var p = await supabase.from('profiles').select('service').eq('id',u.data.user.id).single()
        if (p.data) { userService.value = p.data.service; await load() }
      } else { loading.value = false }
    })

    return {svcLabel,totalCount,loading,categories,load}
  }
}
</script>
<style scoped>
.tp{max-width:900px;margin:0 auto;padding:4px 0 40px}

/* Header */
.tp-hd{display:flex;align-items:center;justify-content:space-between;margin-bottom:24px;flex-wrap:wrap;gap:12px}
.tp-hd-left{display:flex;align-items:center;gap:14px}
.tp-hd-icon{font-size:28px}
.tp-h1{font-size:20px;font-weight:700;color:#111}
.tp-h2{font-size:12px;color:#888;margin-top:2px}
.tp-hd-right{display:flex;align-items:center;gap:12px}
.tp-total{font-size:13px;font-weight:600;padding:4px 12px;border-radius:12px}
.tp-total-bad{background:#FCEBEB;color:#A32D2D}
.tp-total-ok{background:#EAF3DE;color:#3B6D11}
.tp-refresh{padding:6px 14px;font-size:12px;font-family:inherit;border:1px solid #ddd;border-radius:4px;background:#fff;cursor:pointer;color:#555;transition:.15s}.tp-refresh:hover{background:#f5f5f5;border-color:#bbb}.tp-refresh:disabled{opacity:.5;cursor:default}

/* Loading / empty */
.tp-loading{text-align:center;color:#999;font-size:14px;padding:48px;font-style:italic}
.tp-empty{display:flex;flex-direction:column;align-items:center;gap:10px;padding:60px 20px;color:#888}
.tp-empty-icon{font-size:36px;color:#3B6D11}
.tp-empty-txt{font-size:14px}

/* Categories */
.tp-cats{display:flex;flex-direction:column;gap:12px}
.tp-cat{border:1px solid #e8e8e8;border-radius:6px;overflow:hidden;background:#fff;box-shadow:0 1px 4px rgba(0,0,0,.04)}
.tp-cat-hd{display:flex;align-items:center;gap:10px;padding:12px 16px;cursor:pointer;background:#fafafa;user-select:none;transition:.1s}.tp-cat-hd:hover{background:#f0f4ff}
.tp-cat-icon{font-size:16px}
.tp-cat-title{font-size:13px;font-weight:600;color:#222;flex:1}
.tp-cat-badge{font-size:11px;font-weight:700;padding:2px 8px;border-radius:10px;min-width:20px;text-align:center}
.tp-badge-red{background:#FCEBEB;color:#A32D2D}
.tp-badge-orange{background:#FEF5E7;color:#A0620D}
.tp-cat-chev{font-size:10px;color:#bbb;margin-left:4px}

/* Items */
.tp-cat-list{border-top:1px solid #f0f0f0}
.tp-item{display:flex;align-items:center;justify-content:space-between;padding:10px 16px;border-bottom:1px solid #f8f8f8;cursor:pointer;transition:.1s;gap:12px}.tp-item:last-child{border-bottom:none}.tp-item:hover{background:#f5f9ff}
.tp-item-main{display:flex;align-items:center;gap:8px;min-width:0;flex:1}
.tp-item-lot{font-family:'SF Mono','Fira Code',monospace;font-size:12px;font-weight:600;color:#0C447C;white-space:nowrap;background:#E6F1FB;padding:2px 7px;border-radius:3px}
.tp-item-bl{font-size:10px;font-weight:700;color:#A32D2D;background:#FCEBEB;padding:1px 5px;border-radius:2px;white-space:nowrap}
.tp-item-prod{font-size:12px;color:#666;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tp-item-right{display:flex;align-items:center;gap:8px;flex-shrink:0}
.tp-item-action{font-size:12px;font-weight:500;white-space:nowrap}
.tp-action-blue{color:#185FA5}
.tp-action-red{color:#A32D2D}
.tp-item-arr{font-size:12px;color:#bbb}
</style>
