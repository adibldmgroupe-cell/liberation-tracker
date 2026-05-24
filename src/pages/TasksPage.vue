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

    // Helper : résout un tableau de lot_id → map {id: {id,numero_lot,prod_desc,prod_code}}
    var getLotsMap = async function(lotIds) {
      var uniq = lotIds.filter(function(id,i,a){ return id!=null && a.indexOf(id)===i })
      if (!uniq.length) return {}
      var res = await supabase.from('lots').select('id,numero_lot,prod_desc,prod_code').in('id',uniq)
      var map = {}
      ;(res.data||[]).forEach(function(l){ map[l.id]=l })
      return map
    }

    var load = async function() {
      loading.value = true
      var cats = []
      var svc = userService.value
      if (!svc) { loading.value = false; return }

      // ── 1. CIRCUITS À VALIDER ──────────────────────────────────────
      var circEtapeMap = {planification:'planification',stock:'stock',aq:'aq',dt:'dt',aq_dap:'aq_dap'}
      var circEtape = circEtapeMap[svc]
      if (circEtape || svc==='fabrication' || svc==='conditionnement') {
        var circCat = makeCat('circuits','🔄','Circuits à valider / réceptionner')
        var ofEtape = svc==='fabrication' ? 'production' : circEtape
        var ocEtape = svc==='conditionnement' ? 'production' : (svc==='fabrication' ? null : circEtape)
        if (ofEtape) {
          var ofRes = await supabase.from('orders_of').select('id,lot_id,etape_circuit').eq('statut','en_circuit').eq('etape_circuit',ofEtape).limit(200)
          var ofMap = await getLotsMap((ofRes.data||[]).map(function(o){return o.lot_id}))
          ;(ofRes.data||[]).forEach(function(o){
            var l=ofMap[o.lot_id]; if(!l) return
            circCat.items.push({key:'of_'+o.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,action:'Circuit OF — étape : '+(o.etape_circuit||'')})
          })
        }
        if (ocEtape) {
          var ocRes = await supabase.from('orders_oc').select('id,lot_id,etape_circuit').eq('statut','en_circuit').eq('etape_circuit',ocEtape).limit(200)
          var ocMap = await getLotsMap((ocRes.data||[]).map(function(o){return o.lot_id}))
          ;(ocRes.data||[]).forEach(function(o){
            var l=ocMap[o.lot_id]; if(!l) return
            circCat.items.push({key:'oc_'+o.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,action:'Circuit OC — étape : '+(o.etape_circuit||'')})
          })
        }
        if (circCat.items.length) cats.push(circCat)
      }

      // ── 2. DOCUMENTS À TRAITER ─────────────────────────────────────
      var docCat = makeCat('docs','📄','Documents à traiter')
      var docRaw = []
      if (svc==='aq') {
        var daqRes = await supabase.from('liberation_documents')
          .select('id,type_document,statut,lot_id')
          .in('statut',['emis','verification_aq'])
          .in('type_document',['if','ic','da_pc','da_micro','rvp','maj_if','maj_ic','maj_nmcl_of','maj_nmcl_oc'])
          .eq('is_applicable',true).limit(500)
        docRaw = daqRes.data||[]
        var daqMap = await getLotsMap(docRaw.map(function(d){return d.lot_id}))
        docRaw.forEach(function(d){
          var l=daqMap[d.lot_id]; if(!l) return
          var lbl=d.statut==='verification_aq'?'Vérifier (retour DT)':'Vérifier AQ → DT'
          docCat.items.push({key:'doc_'+d.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,action:(DOC_TYPE_LABELS[d.type_document]||d.type_document)+' — '+lbl})
        })
      } else if (svc==='dt') {
        var ddtRes = await supabase.from('liberation_documents')
          .select('id,type_document,statut,lot_id')
          .eq('statut','approuve_aq')
          .in('type_document',['if','ic','da_pc','da_micro','rvp','maj_if','maj_ic','maj_nmcl_of','maj_nmcl_oc'])
          .eq('is_applicable',true).limit(500)
        docRaw = ddtRes.data||[]
        var ddtMap = await getLotsMap(docRaw.map(function(d){return d.lot_id}))
        docRaw.forEach(function(d){
          var l=ddtMap[d.lot_id]; if(!l) return
          docCat.items.push({key:'doc_'+d.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,action:(DOC_TYPE_LABELS[d.type_document]||d.type_document)+' — Approuver DT'})
        })
      } else {
        var dEmtRes = await supabase.from('liberation_documents')
          .select('id,type_document,lot_id')
          .eq('statut','retour_emetteur')
          .eq('service_emetteur',svc)
          .eq('is_applicable',true).limit(500)
        docRaw = dEmtRes.data||[]
        var dEmtMap = await getLotsMap(docRaw.map(function(d){return d.lot_id}))
        docRaw.forEach(function(d){
          var l=dEmtMap[d.lot_id]; if(!l) return
          docCat.items.push({key:'doc_'+d.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,action:(DOC_TYPE_LABELS[d.type_document]||d.type_document)+' — Rectifier et réémettre'})
        })
      }
      if (docCat.items.length) cats.push(docCat)

      // ── 3. ACCUSÉS DE RÉCEPTION ────────────────────────────────────
      var arCat = makeCat('ar','✅','Accusés de réception à confirmer')
      var arDocR = await supabase.from('liberation_documents').select('id,type_document,lot_id').eq('pending_ar_service',svc).limit(200)
      var arDocMap = await getLotsMap((arDocR.data||[]).map(function(d){return d.lot_id}))
      ;(arDocR.data||[]).forEach(function(d){
        var l=arDocMap[d.lot_id]; if(!l) return
        arCat.items.push({key:'ar_doc_'+d.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,action:(DOC_TYPE_LABELS[d.type_document]||d.type_document)+' — Accuser réception'})
      })
      var arOfR = await supabase.from('orders_of').select('id,lot_id,etape_circuit').eq('pending_ar_service',svc).limit(200)
      var arOfMap = await getLotsMap((arOfR.data||[]).map(function(o){return o.lot_id}))
      ;(arOfR.data||[]).forEach(function(o){
        var l=arOfMap[o.lot_id]; if(!l) return
        arCat.items.push({key:'ar_of_'+o.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,action:'Circuit OF — AR ('+o.etape_circuit+')'})
      })
      var arOcR = await supabase.from('orders_oc').select('id,lot_id,etape_circuit').eq('pending_ar_service',svc).limit(200)
      var arOcMap = await getLotsMap((arOcR.data||[]).map(function(o){return o.lot_id}))
      ;(arOcR.data||[]).forEach(function(o){
        var l=arOcMap[o.lot_id]; if(!l) return
        arCat.items.push({key:'ar_oc_'+o.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,action:'Circuit OC — AR ('+o.etape_circuit+')'})
      })
      if (svc==='aq'||svc==='lcq') {
        var arAqlDR = await supabase.from('aql_inspections').select('id,type,lot_id').eq('request_ar_pending',true).limit(200)
        var arAqlDMap = await getLotsMap((arAqlDR.data||[]).map(function(a){return a.lot_id}))
        ;(arAqlDR.data||[]).forEach(function(a){
          var l=arAqlDMap[a.lot_id]; if(!l) return
          arCat.items.push({key:'ar_aql_d_'+a.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,action:'AQL '+a.type+' — AR demande'})
        })
      }
      if (svc==='fabrication'||svc==='conditionnement') {
        var aqlTypeSvc = svc==='fabrication'?'fabrication':'conditionnement'
        var arAqlRR = await supabase.from('aql_inspections').select('id,type,resultat,lot_id').eq('result_ar_pending',true).eq('type',aqlTypeSvc).limit(200)
        var arAqlRMap = await getLotsMap((arAqlRR.data||[]).map(function(a){return a.lot_id}))
        ;(arAqlRR.data||[]).forEach(function(a){
          var l=arAqlRMap[a.lot_id]; if(!l) return
          arCat.items.push({key:'ar_aql_r_'+a.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,action:'AQL '+a.type+' — AR résultat ('+a.resultat+')'})
        })
      }
      if (arCat.items.length) cats.push(arCat)

      // ── 4. AQL À RÉALISER ──────────────────────────────────────────
      if (svc==='fabrication'||svc==='conditionnement') {
        var aqlCat = makeCat('aql','🔬','Inspections AQL à réaliser')
        var aqlTypeVal = svc==='fabrication'?'fabrication':'conditionnement'
        var aqlR = await supabase.from('aql_inspections').select('id,type,lot_id').eq('type',aqlTypeVal).eq('resultat','en_attente').order('requested_at',{ascending:true}).limit(200)
        var aqlMap = await getLotsMap((aqlR.data||[]).map(function(a){return a.lot_id}))
        ;(aqlR.data||[]).forEach(function(a){
          var l=aqlMap[a.lot_id]; if(!l) return
          aqlCat.items.push({key:'aql_'+a.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,action:'AQL '+a.type+' — Résultat à saisir'})
        })
        if (aqlCat.items.length) cats.push(aqlCat)
      }

      // ── 5. DÉVIATIONS BLOQUANTES ───────────────────────────────────
      if (svc==='aq'||svc==='dt'||svc==='admin') {
        var devCat = makeCat('dev','⚠','Déviations bloquantes ouvertes',true)
        var devR = await supabase.from('deviations').select('id,lot_id,numero_dn').eq('bloquante',true).in('statut',['ouverte','en_cours']).order('declared_at',{ascending:false}).limit(200)
        var devMap = await getLotsMap((devR.data||[]).map(function(d){return d.lot_id}))
        ;(devR.data||[]).forEach(function(d){
          var l=devMap[d.lot_id]; if(!l) return
          devCat.items.push({key:'dev_'+d.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,action:'Déviation bloquante'+(d.numero_dn?' ('+d.numero_dn+')':''),urgent:true})
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
