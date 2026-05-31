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
        <select v-if="isAdmin" v-model="selectedSvc" @change="load" class="tp-svc-sel">
          <option v-for="(label,key) in SVC_LABELS_ALL" :key="key" :value="key">{{label}}</option>
        </select>
        <span class="tp-total" :class="totalCount>0?'tp-total-bad':'tp-total-ok'">
          {{totalCount}} tâche{{totalCount!==1?'s':''}} en attente
        </span>
        <button class="tp-refresh" @click="load" :disabled="loading">{{loading?'⟳':'↻'}} Rafraîchir</button>
      </div>
    </div>

    <!-- Barre de recherche -->
    <div v-if="!loading && totalCount>0" class="tp-search-bar">
      <span class="tp-search-icon">🔍</span>
      <input v-model="searchQuery" class="tp-search-inp" type="text" placeholder="Rechercher par numéro de lot ou désignation…" autocomplete="off" />
      <span v-if="searchQuery.trim()" class="tp-search-count">
        {{searchResultCount}} résultat{{searchResultCount!==1?'s':''}}
      </span>
      <button v-if="searchQuery" class="tp-search-clear" @click="searchQuery=''">✕</button>
    </div>

    <div v-if="loading" class="tp-loading">⟳ Chargement…</div>

    <div v-else-if="!loading && totalCount===0" class="tp-empty">
      <span class="tp-empty-icon">✓</span>
      <div class="tp-empty-txt">Aucune tâche en attente pour ce service</div>
    </div>

    <div v-else class="tp-cats">
      <div v-for="cat in categories" :key="cat.id" v-show="isCatVisible(cat)" class="tp-cat">

        <!-- En-tête catégorie — barre gauche colorée + titre uppercase -->
        <div class="tp-cat-hd" :class="{'tp-cat-urgent': cat.urgent}" @click="cat.open=!cat.open">
          <span class="tp-cat-icon">{{cat.icon}}</span>
          <span class="tp-cat-title">{{cat.title}}</span>
          <span class="tp-cat-badge" :class="cat.urgent?'tp-badge-red':'tp-badge-blue'">{{cat.items.length}} tâche{{cat.items.length>1?'s':''}}</span>
          <span class="tp-cat-chev">{{cat.open?'▲':'▼'}}</span>
        </div>

        <!-- Documents : groupes par type -->
        <div v-if="cat.open && cat.groups" class="tp-cat-list">
          <div v-for="grp in visibleGroups(cat)" :key="grp.typeKey" class="tp-grp">
            <!-- En-tête groupe — indenté, bordure gauche bleue -->
            <div class="tp-grp-hd" @click.stop="grp.open=!grp.open">
              <span class="tp-doc-type-tag">{{grp.typeLabel}}</span>
              <span class="tp-grp-sep">›</span>
              <span class="tp-grp-action">{{grp.action}}</span>
              <span class="tp-grp-badge">{{getDocsForGroup(grp).length}} lot{{getDocsForGroup(grp).length>1?'s':''}}</span>
              <span class="tp-grp-chev">{{grp.open?'▲':'▼'}}</span>
            </div>
            <div v-if="grp.open" class="tp-grp-body">
              <!-- En-tête colonnes tri -->
              <div class="tp-grp-sort-hd">
                <span class="tp-sort-col tp-sort-sap">Statut</span>
                <span class="tp-sort-col tp-sort-lot" @click.stop="toggleSort(grp,'lotNum')">
                  N° Lot <span class="tp-sort-icon">{{sortIcon(grp,'lotNum')}}</span>
                </span>
                <span class="tp-sort-col tp-sort-desc" @click.stop="toggleSort(grp,'prodDesc')">
                  Désignation <span class="tp-sort-icon">{{sortIcon(grp,'prodDesc')}}</span>
                </span>
                <span class="tp-sort-col tp-sort-since">Depuis</span>
                <span class="tp-sort-col tp-sort-acts">Actions</span>
              </div>
              <template v-for="d in getDocsForGroup(grp)" :key="d.key">
                <!-- Motif retour inline -->
                <div v-if="d.showReturnInput" class="tp-return-row">
                  <span class="tp-lot-mono">{{d.lotNum}}</span>
                  <span class="tp-return-label">↩ {{d.returnLabel}} — motif :</span>
                  <textarea v-model="d.returnMotif" class="tp-return-motif" placeholder="Motif (optionnel)…" rows="1"></textarea>
                  <button class="tp-do-btn tp-do-nok" :disabled="d.acting" @click.stop="doDocReturn(d,grp,cat)">{{d.acting?'…':'Confirmer'}}</button>
                  <button class="tp-btn-cancel" @click.stop="d.showReturnInput=false;d.returnMotif=''">Annuler</button>
                </div>
                <!-- Ligne normale -->
                <div v-else class="tp-doc-item">
                  <span class="tp-sap-badge" :class="'sap-'+(d.statutSap||'vide')">{{SAP_SHORT[d.statutSap]||''}}</span>
                  <span class="tp-lot-mono" @click="$router.push('/lots/'+d.lotId)">{{d.lotNum}}</span>
                  <span class="tp-prod-desc">{{d.prodDesc}}<span class="tp-prod-code">{{d.prodCode}}</span></span>
                  <span v-if="d.sinceText" class="tp-doc-since" :class="d.sinceClass">{{d.sinceText}}</span>
                  <div class="tp-doc-btns">
                    <button v-if="d.canAct" class="tp-do-btn" :disabled="d.acting" @click.stop="doDocAction(d,grp,cat)">{{d.acting?'…':d.btnLabel}}</button>
                    <button v-if="d.canReturn" class="tp-do-btn tp-do-ret" :disabled="d.acting" @click.stop="d.showReturnInput=true">{{d.returnBtnLabel}}</button>
                  </div>
                  <span class="tp-item-arr" @click="$router.push('/lots/'+d.lotId)">→</span>
                </div>
              </template>
            </div>
          </div>
        </div>

        <!-- Autres catégories (flat) -->
        <div v-else-if="cat.open" class="tp-cat-list">
          <div v-for="item in getItemsForCat(cat)" :key="item.key" class="tp-item">
            <div class="tp-item-main" @click="$router.push('/lots/'+item.lotId)">
              <span class="tp-sap-badge" :class="'sap-'+(item.statutSap||'vide')">{{SAP_SHORT[item.statutSap]||''}}</span>
              <span class="tp-item-lot">{{item.lotNum}}</span>
              <span v-if="item.urgent" class="tp-item-bl">⚠ BLQ</span>
              <span class="tp-item-prod">{{item.prodDesc}}</span>
            </div>
            <div class="tp-item-right">
              <span class="tp-item-action" :class="item.urgent?'tp-action-red':'tp-action-blue'">{{item.action}}</span>
              <template v-if="item.canAqlSaisir">
                <button class="tp-do-btn tp-do-ok" :disabled="item.acting" @click.stop="doAqlSaisir(item,cat,'conforme')">{{item.acting?'…':'✓ Conf.'}}</button>
                <button class="tp-do-btn tp-do-nok" :disabled="item.acting" @click.stop="doAqlSaisir(item,cat,'non_conforme')">{{item.acting?'…':'✗ N.C.'}}</button>
              </template>
              <button v-else-if="item.canAct" class="tp-do-btn" :disabled="item.acting" @click.stop="doItemAction(item,cat)">
                {{item.acting?'…':item.btnLabel}}
              </button>
              <span class="tp-item-arr" @click="$router.push('/lots/'+item.lotId)">→</span>
            </div>
          </div>
        </div>

      </div>
    </div>

    <!-- ── MODAL AVIS AQL NON CONFORME ── -->
    <div class="tp-ov" v-if="aqlAvisModal.show" @click.self="aqlAvisModal.show=false">
      <div class="tp-modal">
        <div class="tp-modal-hd">✗ AQL Non conforme — Remarque AQ</div>
        <div class="tp-modal-ctx">{{aqlAvisModal.lotNum}} — AQL {{aqlAvisModal.aqlType==='fabrication'?'Fabrication':'Conditionnement'}}</div>
        <label class="tp-modal-lbl">Remarque (obligatoire)</label>
        <textarea class="tp-modal-ta" v-model="aqlAvisModal.avis" placeholder="Saisir la remarque AQ…" rows="3" autofocus></textarea>
        <div class="tp-modal-err" v-if="aqlAvisModal.err">{{aqlAvisModal.err}}</div>
        <div class="tp-modal-acts">
          <button class="tp-btn-nok" @click="confirmAqlNonConforme" :disabled="aqlAvisModal.saving">{{aqlAvisModal.saving?'…':'Confirmer Non conforme'}}</button>
          <button class="tp-btn-cancel" @click="aqlAvisModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

  </div>
</template>

<script>
import { ref, computed, watch, onMounted } from 'vue'
import { supabase } from '../supabase'
import { canPerform, loadPermissions, getPermissionForEtape } from '../services/permissions'
import { createNotification } from '../services/notifications'

export default {
  setup() {
    var userService = ref('')
    var selectedSvc = ref('')
    var loading = ref(true)
    var categories = ref([])
    var searchQuery = ref('')

    var SVC_LABELS = {planification:'Planification',stock:'Stock',aq:'Assurance Qualité',aq_dap:'AQ DAP',dt:'Direction Technique',fabrication:'Fabrication',conditionnement:'Conditionnement',lcq:'Laboratoire CQ',admin:'Administration'}
    var SVC_LABELS_ALL = {aq:'Assurance Qualité',dt:'Direction Technique',planification:'Planification',stock:'Stock',fabrication:'Fabrication',conditionnement:'Conditionnement',lcq:'Laboratoire CQ',aq_dap:'AQ DAP'}
    var SAP_SHORT = {quarantaine:'Quarantaine',sous_investigation:'Sous investigation',refuse:'Refusé',vide:''}
    var DOC_TYPE_LABELS = {if:'IF',ic:'IC',da_pc:'DA Physico',da_micro:'DA Micro',ccl:'CCL',rvp:'RVP',maj_if:'MàJ IF',maj_ic:'MàJ IC',maj_nmcl_of:'MàJ N. OF',maj_nmcl_oc:'MàJ N. OC',cloture_sap_of:'Clôt. OF',cloture_sap_oc:'Clôt. OC'}
    var SVC_MAP = {'if':'fabrication',ic:'conditionnement',da_pc:'lcq',da_micro:'lcq',maj_if:'fabrication',maj_ic:'conditionnement',maj_nmcl_of:'planification',maj_nmcl_oc:'planification'}
    var FLOW = ['planification','stock','aq','dt','aq_dap']
    var AR_NEXT = {planification:'stock',stock:'aq',aq:'dt',dt:'aq_dap'}
    var ETAPE_LABELS_LONG = {planification:'Mise en circuit',stock:'Valid. Stock',aq:'Valid. AQ',dt:'Autor. DT',aq_dap:'Remise AQ DAP',production:'Accusé récp.'}

    var isAdmin = computed(function(){ return userService.value === 'admin' })
    var svcLabel = computed(function(){ return SVC_LABELS[selectedSvc.value] || selectedSvc.value })
    var totalCount = computed(function(){ return categories.value.reduce(function(s,c){ return s+c.items.length },0) })

    // ── RECHERCHE ────────────────────────────────────────────────────────

    var matchesSearch = function(lotNum, prodDesc) {
      var q = searchQuery.value.trim().toLowerCase()
      if (!q) return true
      return (lotNum||'').toLowerCase().indexOf(q) >= 0 || (prodDesc||'').toLowerCase().indexOf(q) >= 0
    }

    var searchResultCount = computed(function() {
      var q = searchQuery.value.trim().toLowerCase()
      if (!q) return 0
      var count = 0
      categories.value.forEach(function(cat) {
        if (cat.groups) {
          cat.groups.forEach(function(grp) {
            grp.docs.forEach(function(d) {
              if ((d.lotNum||'').toLowerCase().indexOf(q)>=0 || (d.prodDesc||'').toLowerCase().indexOf(q)>=0) count++
            })
          })
        } else {
          cat.items.forEach(function(item) {
            if ((item.lotNum||'').toLowerCase().indexOf(q)>=0 || (item.prodDesc||'').toLowerCase().indexOf(q)>=0) count++
          })
        }
      })
      return count
    })

    // Ouvre automatiquement les groupes qui ont des résultats quand on tape
    watch(searchQuery, function(q) {
      if (!q) return
      var lq = q.trim().toLowerCase()
      categories.value.forEach(function(cat) {
        if (!cat.groups) return
        cat.groups.forEach(function(grp) {
          var hasMatch = grp.docs.some(function(d) {
            return (d.lotNum||'').toLowerCase().indexOf(lq)>=0 || (d.prodDesc||'').toLowerCase().indexOf(lq)>=0
          })
          if (hasMatch) grp.open = true
        })
      })
    })

    var isCatVisible = function(cat) {
      var q = searchQuery.value.trim().toLowerCase()
      if (!q) return cat.items.length > 0
      if (cat.groups) {
        return cat.groups.some(function(grp) {
          return grp.docs.some(function(d) {
            return (d.lotNum||'').toLowerCase().indexOf(q)>=0 || (d.prodDesc||'').toLowerCase().indexOf(q)>=0
          })
        })
      }
      return cat.items.some(function(item) {
        return (item.lotNum||'').toLowerCase().indexOf(q)>=0 || (item.prodDesc||'').toLowerCase().indexOf(q)>=0
      })
    }

    var visibleGroups = function(cat) {
      if (!cat.groups) return []
      var q = searchQuery.value.trim().toLowerCase()
      if (!q) return cat.groups
      return cat.groups.filter(function(grp) {
        return grp.docs.some(function(d) {
          return (d.lotNum||'').toLowerCase().indexOf(q)>=0 || (d.prodDesc||'').toLowerCase().indexOf(q)>=0
        })
      })
    }

    var getItemsForCat = function(cat) {
      var q = searchQuery.value.trim().toLowerCase()
      if (!q) return cat.items
      return cat.items.filter(function(item) {
        return (item.lotNum||'').toLowerCase().indexOf(q)>=0 || (item.prodDesc||'').toLowerCase().indexOf(q)>=0
      })
    }

    // ── TRI ──────────────────────────────────────────────────────────────

    var toggleSort = function(grp, key) {
      if (grp.sortKey === key) {
        grp.sortDir = grp.sortDir === 'asc' ? 'desc' : 'asc'
      } else {
        grp.sortKey = key
        grp.sortDir = 'asc'
      }
    }

    var sortIcon = function(grp, key) {
      if (grp.sortKey !== key) return '↕'
      return grp.sortDir === 'asc' ? '↑' : '↓'
    }

    var getDocsForGroup = function(grp) {
      var q = searchQuery.value.trim().toLowerCase()
      var docs = q ? grp.docs.filter(function(d) {
        return (d.lotNum||'').toLowerCase().indexOf(q)>=0 || (d.prodDesc||'').toLowerCase().indexOf(q)>=0
      }) : grp.docs.slice()
      if (grp.sortKey) {
        var sk = grp.sortKey
        var sd = grp.sortDir
        docs = docs.slice().sort(function(a, b) {
          var va = (sk === 'lotNum' ? a.lotNum : a.prodDesc) || ''
          var vb = (sk === 'lotNum' ? b.lotNum : b.prodDesc) || ''
          var cmp = va.localeCompare(vb, 'fr', {sensitivity:'base'})
          return sd === 'desc' ? -cmp : cmp
        })
      }
      return docs
    }

    // ── HELPERS ──────────────────────────────────────────────────────────

    var makeCat = function(id, icon, title, urgent) {
      return {id:id,icon:icon,title:title,urgent:urgent||false,open:true,items:[]}
    }

    var makeGrp = function(typeKey, typeLabel, action) {
      return {typeKey:typeKey,typeLabel:typeLabel,action:action,open:false,docs:[],sortKey:null,sortDir:'asc'}
    }

    var fmtSince = function(dateStr) {
      if (!dateStr) return null
      var ms = Date.now() - new Date(dateStr).getTime()
      if (ms < 0) return null
      var h = Math.floor(ms / 3600000)
      if (h < 1) return {text:'depuis < 1h',cls:'since-ok'}
      if (h < 24) return {text:'depuis '+h+'h',cls:'since-ok'}
      var d = Math.floor(h/24); var rh = h%24
      var txt = 'depuis '+d+'j'+(rh>0?' '+rh+'h':'')
      return {text:txt, cls:d>=3?'since-red':d>=2?'since-orange':'since-ok'}
    }

    var getLotsMap = async function(lotIds) {
      var uniq = lotIds.filter(function(id,i,a){ return id!=null && a.indexOf(id)===i })
      if (!uniq.length) return {}
      var res = await supabase.from('lots').select('id,numero_lot,product_id,statut_sap').in('id',uniq)
      var map = {}
      ;(res.data||[]).forEach(function(l){ if(l.statut_sap!=='accepte'&&l.statut_sap!=='refuse') map[l.id]=l })
      var prodIds = (res.data||[]).map(function(l){return l.product_id}).filter(function(id,i,a){return id!=null&&a.indexOf(id)===i})
      if (prodIds.length) {
        var pRes = await supabase.from('products').select('id,code_article,description').in('id',prodIds)
        var pMap = {}
        ;(pRes.data||[]).forEach(function(p){ pMap[p.id]=p })
        Object.keys(map).forEach(function(lid){
          var l=map[lid]; var p=pMap[l.product_id]
          l.prod_desc = p?(p.description||p.code_article):''
          l.prod_code = p?p.code_article:''
        })
      }
      return map
    }

    // ── ACTIONS ──────────────────────────────────────────────────────────

    var removeDocItem = function(d, grp, cat) {
      var di = grp.docs.indexOf(d); if(di>=0) grp.docs.splice(di,1)
      var fi = cat.items.findIndex(function(i){return i.key===d.key}); if(fi>=0) cat.items.splice(fi,1)
      if (grp.docs.length===0) { var gi=cat.groups.indexOf(grp); if(gi>=0) cat.groups.splice(gi,1) }
    }

    var removeCatItem = function(item, cat) {
      var idx = cat.items.indexOf(item); if(idx>=0) cat.items.splice(idx,1)
    }

    // Après AR demande AQL → ajoute immédiatement l'item "à réaliser" dans la catégorie AQL
    var addToAqlCatAfterAr = function(arItem) {
      var isAdm = userService.value === 'admin'
      var canAqlSaisir = isAdm || canPerform('realiser_aql')
      var newItem = {key:'aql_'+arItem.aqlId, lotId:arItem.lotId, lotNum:arItem.lotNum,
        prodDesc:arItem.prodDesc, statutSap:arItem.statutSap||'',
        action:'AQL '+arItem.aqlTypeLabel+' — Résultat à saisir',
        canAqlSaisir:canAqlSaisir, acting:false,
        aqlId:arItem.aqlId, aqlType:arItem.aqlType}
      var aqlCatObj = categories.value.find(function(c){ return c.id==='aql' })
      if (aqlCatObj) {
        aqlCatObj.items.push(newItem)
        aqlCatObj.open = true
      } else {
        var newCat = makeCat('aql','🔬','Inspections AQL à réaliser')
        newCat.items.push(newItem)
        newCat.open = true
        categories.value.push(newCat)
      }
    }

    var addToDocsCatAfterAr = function(arItem) {
      var svc = selectedSvc.value
      var isAdm = userService.value === 'admin'
      var typeKey = arItem.typeDocument
      var typeLabel = DOC_TYPE_LABELS[typeKey] || typeKey
      var action, actionClass, btnLabel, statut, canReturn, returnBtnLabel, returnLabel
      if (svc==='aq' && typeKey==='ccl') {
        // CCL : AQ doit transmettre (non applicable ici car CCL AR vient du DT, mais par sécurité)
        action='Transmettre au DT'; actionClass='act-blue'; btnLabel='↑ Transmettre'; statut='emis'
        canReturn=false
      } else if (svc==='aq') {
        action='Vérifier AQ → DT'; actionClass='act-blue'; btnLabel='✓ Valider'; statut='emis'
        canReturn=isAdm||canPerform('retourner_document'); returnBtnLabel='↩ Retourner'; returnLabel='Retourner à l\'émetteur'
      } else if (svc==='dt' && typeKey==='ccl') {
        action='Libérer le lot'; actionClass='act-purple'; btnLabel='✓ Libérer'; statut='emis'
        canReturn=isAdm||canPerform('retourner_document'); returnBtnLabel='↩ Retour AQ'; returnLabel="Retourner à l'AQ"
      } else if (svc==='dt') {
        action='Approuver DT'; actionClass='act-purple'; btnLabel='✓ Approuver'; statut='approuve_aq'
        canReturn=isAdm||canPerform('retourner_document'); returnBtnLabel='↩ Retour AQ'; returnLabel='Retourner à l\'AQ'
      } else {
        action='Rectifier et réémettre'; actionClass='act-red'; btnLabel='↑ Réémettre'; statut='retour_emetteur'
        canReturn=false
      }
      var canAct = (svc==='aq'&&typeKey==='ccl')?(isAdm||canPerform('emettre_ccl')):svc==='aq'?(isAdm||canPerform('verifier_'+typeKey)):(svc==='dt'&&typeKey==='ccl')?(isAdm||canPerform('approuver_ccl')):svc==='dt'?(isAdm||canPerform('approuver_'+typeKey)):(isAdm||canPerform('emettre_'+typeKey))
      var newDoc = {key:'doc_'+arItem.docId,docId:arItem.docId,typeDocument:typeKey,statut:statut,
        lotId:arItem.lotId,lotNum:arItem.lotNum,prodDesc:arItem.prodDesc,prodCode:arItem.prodCode||'',statutSap:arItem.statutSap||'',
        action:action,actionClass:actionClass,sinceText:null,sinceClass:'',
        canAct:canAct,btnLabel:btnLabel,canReturn:canReturn||false,
        returnBtnLabel:returnBtnLabel,returnLabel:returnLabel,showReturnInput:false,returnMotif:'',acting:false}
      var docCatObj = categories.value.find(function(c){ return c.id==='docs' })
      if (docCatObj) {
        var grp = docCatObj.groups.find(function(g){ return g.typeKey===typeKey })
        if (!grp) { grp=makeGrp(typeKey,typeLabel,action); grp.open=true; docCatObj.groups.push(grp) }
        grp.docs.push(newDoc)
        docCatObj.items.push({key:'doc_'+arItem.docId,lotId:arItem.lotId,lotNum:arItem.lotNum})
      } else {
        var g2 = makeGrp(typeKey,typeLabel,action); g2.open=true; g2.docs=[newDoc]
        var newCat = {id:'docs',icon:'📄',title:'Documents à traiter',urgent:false,open:true,
          items:[{key:'doc_'+arItem.docId,lotId:arItem.lotId,lotNum:arItem.lotNum}],
          groups:[g2]}
        categories.value.splice(1, 0, newCat)
      }
    }

    var doDocReturn = async function(d, grp, cat) {
      d.acting = true
      var u = await supabase.auth.getUser(); var uid = u.data.user.id; var n = new Date().toISOString()
      var motif = (d.returnMotif||'').trim() || null
      var svc = selectedSvc.value
      var res
      if (svc==='aq') {
        var emSvc = SVC_MAP[d.typeDocument] || null
        res = await supabase.from('liberation_documents').update({statut:'retour_emetteur',pending_ar_service:emSvc,updated_at:n}).eq('id',d.docId)
        if (res.error) { alert('Erreur : '+res.error.message); d.acting=false; return }
        await supabase.from('document_movements').insert({document_id:d.docId,action:'retour',from_service:'aq',to_service:emSvc,motif_retour:motif,performed_by:uid,performed_at:n})
        if (emSvc) await createNotification(emSvc,d.lotId,d.docId,'Lot '+d.lotNum+' — '+d.typeDocument.toUpperCase()+' retourné pour rectification','document_retourne')
      } else if (svc==='dt') {
        var dtRetStatut = d.typeDocument === 'ccl' ? 'retour_emetteur' : 'verification_aq'
        res = await supabase.from('liberation_documents').update({statut:dtRetStatut,pending_ar_service:'aq',updated_at:n}).eq('id',d.docId)
        if (res.error) { alert('Erreur : '+res.error.message); d.acting=false; return }
        await supabase.from('document_movements').insert({document_id:d.docId,action:'retour',from_service:'dt',to_service:'aq',motif_retour:motif,performed_by:uid,performed_at:n})
        await createNotification('aq',d.lotId,d.docId,'Lot '+d.lotNum+' — '+d.typeDocument.toUpperCase()+' retourné par DT','document_retourne')
      }
      removeDocItem(d, grp, cat)
    }

    var doDocAction = async function(d, grp, cat) {
      d.acting = true
      var u = await supabase.auth.getUser(); var uid = u.data.user.id; var n = new Date().toISOString()
      var svc = selectedSvc.value
      var res
      if (svc==='aq' && d.typeDocument==='ccl') {
        // CCL : AQ transmet directement au DT
        res = await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,pending_ar_service:'dt',updated_at:n}).eq('id',d.docId)
        if (res.error) { alert('Erreur : '+res.error.message); d.acting=false; return }
        await supabase.from('document_movements').insert({document_id:d.docId,action:'emission',from_service:'aq',to_service:'dt',performed_by:uid,performed_at:n})
        await createNotification('dt',d.lotId,d.docId,'Lot '+d.lotNum+' — CCL transmis au DT','document_transmis')
      } else if (svc==='aq') {
        res = await supabase.from('liberation_documents').update({statut:'approuve_aq',pending_ar_service:'dt',updated_at:n}).eq('id',d.docId)
        if (res.error) { alert('Erreur : '+res.error.message); d.acting=false; return }
        await supabase.from('document_movements').insert({document_id:d.docId,action:'approbation',from_service:'aq',to_service:'dt',performed_by:uid,performed_at:n})
        await createNotification('dt',d.lotId,d.docId,'Lot '+d.lotNum+' — '+d.typeDocument.toUpperCase()+' vérifié AQ → DT','document_transmis')
      } else if (svc==='dt') {
        res = await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:n,pending_ar_service:null,updated_at:n}).eq('id',d.docId)
        if (res.error) { alert('Erreur : '+res.error.message); d.acting=false; return }
        await supabase.from('document_movements').insert({document_id:d.docId,action:'approbation',from_service:'dt',performed_by:uid,performed_at:n})
        if (d.typeDocument === 'ccl') {
          await supabase.from('lots').update({statut_sap:'accepte',date_liberation:n,updated_at:n}).eq('id',d.lotId)
          await supabase.from('liberation_dossiers').update({statut:'libere',if_approved:true,ic_approved:true,da_pc_approved:true,deviations_closed:true,pieces_complementaires_ok:true,updated_at:n}).eq('lot_id',d.lotId)
          await createNotification('aq',d.lotId,d.docId,'Lot '+d.lotNum+' — Lot libéré par le DT','lot_libere')
        } else {
          await createNotification('aq',d.lotId,d.docId,'Lot '+d.lotNum+' — '+d.typeDocument.toUpperCase()+' approuvé DT','document_approuve')
          if (SVC_MAP[d.typeDocument]) await createNotification(SVC_MAP[d.typeDocument],d.lotId,d.docId,'Lot '+d.lotNum+' — '+d.typeDocument.toUpperCase()+' approuvé DT','document_approuve')
        }
      } else {
        var pendingAfterRect = d.typeDocument === 'ccl' ? 'dt' : 'aq'
        var toSvcRect = d.typeDocument === 'ccl' ? 'dt' : 'aq'
        res = await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,pending_ar_service:pendingAfterRect,updated_at:n}).eq('id',d.docId)
        if (res.error) { alert('Erreur : '+res.error.message); d.acting=false; return }
        await supabase.from('document_movements').insert({document_id:d.docId,action:'rectification',from_service:SVC_MAP[d.typeDocument]||'',to_service:toSvcRect,performed_by:uid,performed_at:n})
        await createNotification(toSvcRect,d.lotId,d.docId,'Lot '+d.lotNum+' — '+d.typeDocument.toUpperCase().replace('_',' ')+' rectifié et réémis','document_transmis')
      }
      removeDocItem(d, grp, cat)
    }

    var doItemAction = async function(item, cat) {
      item.acting = true
      var u = await supabase.auth.getUser(); var uid = u.data.user.id; var n = new Date().toISOString()
      var res
      if (item.arType==='doc') {
        res = await supabase.from('liberation_documents').update({pending_ar_service:null,updated_at:n}).eq('id',item.docId)
        if (res.error) { alert('Erreur : '+res.error.message); item.acting=false; return }
        await supabase.from('lot_events').insert({lot_id:item.lotId,event_type:'ar_document',description:(DOC_TYPE_LABELS[item.typeDocument]||item.typeDocument||'DOC')+' — Accusé réception',triggered_by:uid,created_at:n})
        removeCatItem(item, cat)
        addToDocsCatAfterAr(item)
        return
      } else if (item.arType==='circuit') {
        res = await supabase.from(item.orderTable).update({pending_ar_service:null,updated_at:n}).eq('id',item.orderId)
        if (res.error) { alert('Erreur : '+res.error.message); item.acting=false; return }
        await supabase.from('lot_events').insert({lot_id:item.lotId,event_type:'ar_circuit',description:'Circuit '+item.orderType.toUpperCase()+' — Accusé réception',triggered_by:uid,created_at:n})
      } else if (item.arType==='aql_demande') {
        res = await supabase.from('aql_inspections').update({request_ar_pending:false}).eq('id',item.aqlId)
        if (res.error) { alert('Erreur : '+res.error.message); item.acting=false; return }
        await supabase.from('lot_events').insert({lot_id:item.lotId,event_type:'ar_aql_demande',description:'AQL '+item.aqlTypeLabel+' — Accusé réception demande',triggered_by:uid,created_at:n})
        removeCatItem(item, cat)
        addToAqlCatAfterAr(item)  // Affiche immédiatement l'item "à réaliser"
        return
      } else if (item.arType==='aql_resultat') {
        res = await supabase.from('aql_inspections').update({result_ar_pending:false}).eq('id',item.aqlId)
        if (res.error) { alert('Erreur : '+res.error.message); item.acting=false; return }
        await supabase.from('lot_events').insert({lot_id:item.lotId,event_type:'ar_aql_resultat',description:'AQL '+item.aqlTypeLabel+' — Accusé réception résultat',triggered_by:uid,created_at:n})
      } else if (item.circuitValidate) {
        var etape = item.etape
        var flowIdx = FLOW.indexOf(etape)
        var nextEtape = flowIdx < FLOW.length-1 ? FLOW[flowIdx+1] : null
        var arSvc = AR_NEXT[etape] || null
        await supabase.from('order_validations').insert({order_type:item.orderType,order_id:item.orderId,etape:etape,action:'valide',validated_by:uid,validated_at:n})
        res = await supabase.from(item.orderTable).update({statut:nextEtape?'en_circuit':'termine',etape_circuit:nextEtape||etape,pending_ar_service:arSvc,updated_at:n}).eq('id',item.orderId)
        if (res.error) { alert('Erreur : '+res.error.message); item.acting=false; return }
        var nextLabel = nextEtape?(ETAPE_LABELS_LONG[nextEtape]||nextEtape):'Terminé'
        await supabase.from('lots').update({statut_operationnel:item.orderType.toUpperCase()+' — '+nextLabel,updated_at:n}).eq('id',item.lotId)
        var notifSvc = nextEtape==='stock'?'stock':nextEtape==='aq'?'aq':nextEtape==='dt'?'dt':nextEtape==='aq_dap'?'aq_dap':nextEtape==='production'?(item.orderType==='of'?'fabrication':'conditionnement'):'planification'
        await createNotification(notifSvc,item.lotId,null,'Lot '+item.lotNum+' — Circuit '+item.orderType.toUpperCase()+' : '+(ETAPE_LABELS_LONG[etape]||etape)+' validé','circuit_avance')
      }
      removeCatItem(item, cat)
    }

    var aqlAvisModal = ref({ show:false, item:null, cat:null, avis:'', aqlType:'', lotNum:'', err:'', saving:false })

    var doAqlSaisir = async function(item, cat, resultat) {
      if (resultat === 'non_conforme') {
        aqlAvisModal.value = { show:true, item, cat, avis:'', aqlType:item.aqlType, lotNum:item.lotNum, err:'', saving:false }
        return
      }
      item.acting = true
      var u = await supabase.auth.getUser(); var uid = u.data.user.id; var n = new Date().toISOString()
      var res = await supabase.from('aql_inspections').update({resultat:'conforme',avis_aq:'',inspected_at:n,inspected_by:uid,request_ar_pending:false,result_ar_pending:true}).eq('id',item.aqlId)
      if (res.error) { alert('Erreur : '+res.error.message); item.acting=false; return }
      var aLabel = item.aqlType==='fabrication'?'Fabrication':'Conditionnement'
      await createNotification('planification',item.lotId,null,'Lot '+item.lotNum+' — AQL '+aLabel+' : conforme','aql_resultat')
      removeCatItem(item, cat)
    }

    var confirmAqlNonConforme = async function() {
      var m = aqlAvisModal.value
      if (!m.avis.trim()) { m.err = 'La remarque est obligatoire.'; return }
      m.saving = true; m.err = ''
      var u = await supabase.auth.getUser(); var uid = u.data.user.id; var n = new Date().toISOString()
      var res = await supabase.from('aql_inspections').update({resultat:'non_conforme',avis_aq:m.avis.trim(),inspected_at:n,inspected_by:uid,request_ar_pending:false,result_ar_pending:true}).eq('id',m.item.aqlId)
      if (res.error) { m.err = res.error.message; m.saving=false; return }
      var aLabel = m.aqlType==='fabrication'?'Fabrication':'Conditionnement'
      await createNotification('planification',m.item.lotId,null,'Lot '+m.item.lotNum+' — AQL '+aLabel+' : non conforme','aql_resultat')
      removeCatItem(m.item, m.cat)
      m.show = false
    }

    // ── LOAD ─────────────────────────────────────────────────────────────

    var load = async function() {
      loading.value = true
      searchQuery.value = ''
      var cats = []
      var svc = selectedSvc.value
      if (!svc) { loading.value = false; return }
      await loadPermissions(userService.value)
      var isAdm = userService.value === 'admin'

      // ── 1. CIRCUITS ───────────────────────────────────────────────────
      var circEtapeMap = {planification:'planification',stock:'stock',aq:'aq',dt:'dt',aq_dap:'aq_dap'}
      var circEtape = circEtapeMap[svc]
      if (circEtape || svc==='fabrication' || svc==='conditionnement') {
        var circCat = makeCat('circuits','🔄','Circuits à valider / réceptionner')
        var ofEtape = svc==='fabrication'?'production':circEtape
        var ocEtape = svc==='conditionnement'?'production':(svc==='fabrication'?null:circEtape)
        if (ofEtape) {
          var ofRes = await supabase.from('orders_of').select('id,lot_id,etape_circuit,pending_ar_service').eq('statut','en_circuit').eq('etape_circuit',ofEtape).limit(200)
          var ofMap = await getLotsMap((ofRes.data||[]).map(function(o){return o.lot_id}))
          ;(ofRes.data||[]).forEach(function(o){
            var l=ofMap[o.lot_id]; if(!l) return
            var isPendingAr = o.pending_ar_service === svc
            var permKey = isPendingAr ? 'accuser_reception_circuit' : getPermissionForEtape(ofEtape,'of')
            var canAct = isAdm || (permKey ? canPerform(permKey) : false)
            circCat.items.push({key:'of_'+o.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,statutSap:l.statut_sap||'',
              action:'Circuit OF — '+(isPendingAr?'AR en attente':'Valider : '+(ETAPE_LABELS_LONG[ofEtape]||ofEtape)),
              canAct:canAct, btnLabel:isPendingAr?'✅ AR':'✓ Valider', acting:false,
              orderId:o.id, orderTable:'orders_of', orderType:'of', etape:o.etape_circuit,
              arType:isPendingAr?'circuit':null, circuitValidate:!isPendingAr})
          })
        }
        if (ocEtape) {
          var ocRes = await supabase.from('orders_oc').select('id,lot_id,etape_circuit,pending_ar_service').eq('statut','en_circuit').eq('etape_circuit',ocEtape).limit(200)
          var ocMap = await getLotsMap((ocRes.data||[]).map(function(o){return o.lot_id}))
          ;(ocRes.data||[]).forEach(function(o){
            var l=ocMap[o.lot_id]; if(!l) return
            var isPendingAr = o.pending_ar_service === svc
            var permKey = isPendingAr ? 'accuser_reception_circuit' : getPermissionForEtape(ocEtape,'oc')
            var canAct = isAdm || (permKey ? canPerform(permKey) : false)
            circCat.items.push({key:'oc_'+o.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,statutSap:l.statut_sap||'',
              action:'Circuit OC — '+(isPendingAr?'AR en attente':'Valider : '+(ETAPE_LABELS_LONG[ocEtape]||ocEtape)),
              canAct:canAct, btnLabel:isPendingAr?'✅ AR':'✓ Valider', acting:false,
              orderId:o.id, orderTable:'orders_oc', orderType:'oc', etape:o.etape_circuit,
              arType:isPendingAr?'circuit':null, circuitValidate:!isPendingAr})
          })
        }
        if (circCat.items.length) cats.push(circCat)
      }

      // ── 2. DOCUMENTS (groupés par type_document) ──────────────────────
      var docCat = {id:'docs',icon:'📄',title:'Documents à traiter',urgent:false,open:true,items:[],groups:[]}
      var docRaw = []
      if (svc==='aq') {
        var daqRes = await supabase.from('liberation_documents')
          .select('id,type_document,statut,lot_id,updated_at')
          .in('statut',['emis','verification_aq']).eq('is_applicable',true).is('pending_ar_service',null).neq('type_document','ccl').limit(500)
        docRaw = daqRes.data||[]
        var daqMap = await getLotsMap(docRaw.map(function(d){return d.lot_id}))
        var grpMap = {}
        docRaw.forEach(function(d){
          var l=daqMap[d.lot_id]; if(!l) return
          var lbl=d.statut==='verification_aq'?'Vérifier (retour DT)':'Vérifier AQ → DT'
          var since=fmtSince(d.updated_at)
          var typeKey=d.type_document||'autre'; var typeLabel=DOC_TYPE_LABELS[typeKey]||typeKey
          var actCls=d.statut==='verification_aq'?'act-orange':'act-blue'
          var canAct=isAdm||canPerform('verifier_'+typeKey)
          var canReturn=isAdm||canPerform('retourner_document')
          docCat.items.push({key:'doc_'+d.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||'',prodCode:l.prod_code||'',statutSap:l.statut_sap||''})
          if(!grpMap[typeKey]) grpMap[typeKey]=makeGrp(typeKey,typeLabel,lbl)
          grpMap[typeKey].docs.push({key:'doc_'+d.id,docId:d.id,typeDocument:typeKey,statut:d.statut,
            lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||'',prodCode:l.prod_code||'',statutSap:l.statut_sap||'',
            action:lbl,actionClass:actCls,sinceText:since?since.text:null,sinceClass:since?since.cls:'',
            canAct:canAct,btnLabel:'✓ Valider',
            canReturn:canReturn,returnBtnLabel:'↩ Retourner',returnLabel:'Retourner à l\'émetteur',
            showReturnInput:false,returnMotif:'',acting:false})
        })
        // CCL non émis (AQ doit transmettre au DT)
        var cclAqRes = await supabase.from('liberation_documents')
          .select('id,type_document,statut,lot_id,updated_at')
          .eq('type_document','ccl').eq('statut','non_emis').eq('is_applicable',true).limit(200)
        var cclAqMap = await getLotsMap((cclAqRes.data||[]).map(function(d){return d.lot_id}))
        ;(cclAqRes.data||[]).forEach(function(d){
          var l=cclAqMap[d.lot_id]; if(!l) return
          var since=fmtSince(d.updated_at)
          var canAct=isAdm||canPerform('emettre_ccl')
          docCat.items.push({key:'doc_'+d.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||'',prodCode:l.prod_code||'',statutSap:l.statut_sap||''})
          if(!grpMap['ccl']) grpMap['ccl']=makeGrp('ccl','CCL','Transmettre au DT')
          grpMap['ccl'].docs.push({key:'doc_'+d.id,docId:d.id,typeDocument:'ccl',statut:d.statut,
            lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||'',prodCode:l.prod_code||'',statutSap:l.statut_sap||'',
            action:'Transmettre au DT',actionClass:'act-blue',sinceText:since?since.text:null,sinceClass:since?since.cls:'',
            canAct:canAct,btnLabel:'↑ Transmettre',canReturn:false,
            showReturnInput:false,returnMotif:'',acting:false})
        })
        docCat.groups = Object.values(grpMap)
      } else if (svc==='dt') {
        var ddtRes = await supabase.from('liberation_documents')
          .select('id,type_document,statut,lot_id,updated_at')
          .eq('statut','approuve_aq').eq('is_applicable',true).is('pending_ar_service',null).limit(500)
        docRaw = ddtRes.data||[]
        var ddtMap = await getLotsMap(docRaw.map(function(d){return d.lot_id}))
        var grpMapDt = {}
        docRaw.forEach(function(d){
          var l=ddtMap[d.lot_id]; if(!l) return
          var since=fmtSince(d.updated_at)
          var typeKey=d.type_document||'autre'; var typeLabel=DOC_TYPE_LABELS[typeKey]||typeKey
          var canAct=isAdm||canPerform('approuver_'+typeKey)
          var canReturn=isAdm||canPerform('retourner_document')
          docCat.items.push({key:'doc_'+d.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||'',prodCode:l.prod_code||'',statutSap:l.statut_sap||''})
          if(!grpMapDt[typeKey]) grpMapDt[typeKey]=makeGrp(typeKey,typeLabel,'Approuver DT')
          grpMapDt[typeKey].docs.push({key:'doc_'+d.id,docId:d.id,typeDocument:typeKey,statut:d.statut,
            lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||'',prodCode:l.prod_code||'',statutSap:l.statut_sap||'',
            action:'Approuver DT',actionClass:'act-purple',sinceText:since?since.text:null,sinceClass:since?since.cls:'',
            canAct:canAct,btnLabel:'✓ Approuver',
            canReturn:canReturn,returnBtnLabel:'↩ Retour AQ',returnLabel:'Retourner à l\'AQ',
            showReturnInput:false,returnMotif:'',acting:false})
        })
        // CCL émis en attente de libération DT
        var cclDtRes = await supabase.from('liberation_documents')
          .select('id,type_document,statut,lot_id,updated_at')
          .eq('type_document','ccl').eq('statut','emis').eq('is_applicable',true).is('pending_ar_service',null).limit(200)
        var cclDtMap = await getLotsMap((cclDtRes.data||[]).map(function(d){return d.lot_id}))
        ;(cclDtRes.data||[]).forEach(function(d){
          var l=cclDtMap[d.lot_id]; if(!l) return
          var since=fmtSince(d.updated_at)
          var canAct=isAdm||canPerform('approuver_ccl')
          var canReturn=isAdm||canPerform('retourner_document')
          docCat.items.push({key:'doc_'+d.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||'',prodCode:l.prod_code||'',statutSap:l.statut_sap||''})
          if(!grpMapDt['ccl']) grpMapDt['ccl']=makeGrp('ccl','CCL','Libérer le lot')
          grpMapDt['ccl'].docs.push({key:'doc_'+d.id,docId:d.id,typeDocument:'ccl',statut:d.statut,
            lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||'',prodCode:l.prod_code||'',statutSap:l.statut_sap||'',
            action:'Libérer le lot',actionClass:'act-purple',sinceText:since?since.text:null,sinceClass:since?since.cls:'',
            canAct:canAct,btnLabel:'✓ Libérer',
            canReturn:canReturn,returnBtnLabel:'↩ Retour AQ',returnLabel:"Retourner à l'AQ",
            showReturnInput:false,returnMotif:'',acting:false})
        })
        docCat.groups = Object.values(grpMapDt)
      } else {
        var dEmtRes = await supabase.from('liberation_documents')
          .select('id,type_document,lot_id,updated_at')
          .eq('statut','retour_emetteur').eq('service_emetteur',svc).eq('is_applicable',true).is('pending_ar_service',null).limit(500)
        docRaw = dEmtRes.data||[]
        var dEmtMap = await getLotsMap(docRaw.map(function(d){return d.lot_id}))
        var grpMapEmt = {}
        docRaw.forEach(function(d){
          var l=dEmtMap[d.lot_id]; if(!l) return
          var since=fmtSince(d.updated_at)
          var typeKey=d.type_document||'autre'; var typeLabel=DOC_TYPE_LABELS[typeKey]||typeKey
          var canAct=isAdm||canPerform('emettre_'+typeKey)
          docCat.items.push({key:'doc_'+d.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||'',prodCode:l.prod_code||'',statutSap:l.statut_sap||''})
          if(!grpMapEmt[typeKey]) grpMapEmt[typeKey]=makeGrp(typeKey,typeLabel,'Rectifier et réémettre')
          grpMapEmt[typeKey].docs.push({key:'doc_'+d.id,docId:d.id,typeDocument:typeKey,statut:'retour_emetteur',
            lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||'',prodCode:l.prod_code||'',statutSap:l.statut_sap||'',
            action:'Rectifier et réémettre',actionClass:'act-red',sinceText:since?since.text:null,sinceClass:since?since.cls:'',
            canAct:canAct,btnLabel:'↑ Réémettre',canReturn:false,
            showReturnInput:false,returnMotif:'',acting:false})
        })
        docCat.groups = Object.values(grpMapEmt)
      }
      if (docCat.items.length) cats.push(docCat)

      // ── 3. ACCUSÉS DE RÉCEPTION ───────────────────────────────────────
      var arCat = makeCat('ar','✅','Accusés de réception à confirmer')
      var arCanDoc = isAdm || canPerform('accuser_reception_document')
      var arCanCirc = isAdm || canPerform('accuser_reception_circuit')

      var arDocR = await supabase.from('liberation_documents').select('id,type_document,lot_id').eq('pending_ar_service',svc).limit(200)
      var arDocMap = await getLotsMap((arDocR.data||[]).map(function(d){return d.lot_id}))
      ;(arDocR.data||[]).forEach(function(d){
        var l=arDocMap[d.lot_id]; if(!l) return
        arCat.items.push({key:'ar_doc_'+d.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||'',prodCode:l.prod_code||'',statutSap:l.statut_sap||'',
          action:(DOC_TYPE_LABELS[d.type_document]||d.type_document)+' — Accuser réception',
          canAct:arCanDoc,btnLabel:'✅ AR',acting:false,
          arType:'doc',docId:d.id,typeDocument:d.type_document})
      })

      var arOfR = await supabase.from('orders_of').select('id,lot_id,etape_circuit').eq('pending_ar_service',svc).limit(200)
      var arOfMap = await getLotsMap((arOfR.data||[]).map(function(o){return o.lot_id}))
      ;(arOfR.data||[]).forEach(function(o){
        var l=arOfMap[o.lot_id]; if(!l) return
        arCat.items.push({key:'ar_of_'+o.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,statutSap:l.statut_sap||'',
          action:'Circuit OF — AR ('+o.etape_circuit+')',
          canAct:arCanCirc,btnLabel:'✅ AR',acting:false,
          arType:'circuit',orderId:o.id,orderTable:'orders_of',orderType:'of',etape:o.etape_circuit})
      })

      var arOcR = await supabase.from('orders_oc').select('id,lot_id,etape_circuit').eq('pending_ar_service',svc).limit(200)
      var arOcMap = await getLotsMap((arOcR.data||[]).map(function(o){return o.lot_id}))
      ;(arOcR.data||[]).forEach(function(o){
        var l=arOcMap[o.lot_id]; if(!l) return
        arCat.items.push({key:'ar_oc_'+o.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,statutSap:l.statut_sap||'',
          action:'Circuit OC — AR ('+o.etape_circuit+')',
          canAct:arCanCirc,btnLabel:'✅ AR',acting:false,
          arType:'circuit',orderId:o.id,orderTable:'orders_oc',orderType:'oc',etape:o.etape_circuit})
      })

      if (svc==='aq'||svc==='lcq') {
        var arCanAqlD = isAdm || canPerform('accuser_reception_aql_demande')
        var arAqlDR = await supabase.from('aql_inspections').select('id,type,lot_id').eq('request_ar_pending',true).limit(200)
        var arAqlDMap = await getLotsMap((arAqlDR.data||[]).map(function(a){return a.lot_id}))
        ;(arAqlDR.data||[]).forEach(function(a){
          var l=arAqlDMap[a.lot_id]; if(!l) return
          var aLabel=a.type==='fabrication'?'Fabrication':'Conditionnement'
          arCat.items.push({key:'ar_aql_d_'+a.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,statutSap:l.statut_sap||'',
            action:'AQL '+aLabel+' — AR demande',
            canAct:arCanAqlD,btnLabel:'✅ AR',acting:false,
            arType:'aql_demande',aqlId:a.id,aqlTypeLabel:aLabel})
        })
      }

      if (svc==='fabrication'||svc==='conditionnement') {
        var arCanAqlR = isAdm || canPerform('accuser_reception_aql_resultat')
        var aqlTypeSvc = svc==='fabrication'?'fabrication':'conditionnement'
        var arAqlRR = await supabase.from('aql_inspections').select('id,type,resultat,lot_id').eq('result_ar_pending',true).eq('type',aqlTypeSvc).limit(200)
        var arAqlRMap = await getLotsMap((arAqlRR.data||[]).map(function(a){return a.lot_id}))
        ;(arAqlRR.data||[]).forEach(function(a){
          var l=arAqlRMap[a.lot_id]; if(!l) return
          var aLabel=a.type==='fabrication'?'Fabrication':'Conditionnement'
          arCat.items.push({key:'ar_aql_r_'+a.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,statutSap:l.statut_sap||'',
            action:'AQL '+aLabel+' — AR résultat ('+a.resultat+')',
            canAct:arCanAqlR,btnLabel:'✅ AR',acting:false,
            arType:'aql_resultat',aqlId:a.id,aqlTypeLabel:aLabel})
        })
      }
      if (arCat.items.length) cats.push(arCat)

      // ── 4. AQL À RÉALISER ─────────────────────────────────────────────
      if (svc==='fabrication'||svc==='conditionnement') {
        var aqlCat = makeCat('aql','🔬','Inspections AQL à réaliser')
        var aqlTypeVal = svc==='fabrication'?'fabrication':'conditionnement'
        var canAqlSaisir = isAdm || canPerform('realiser_aql')
        var aqlR = await supabase.from('aql_inspections').select('id,type,lot_id').eq('type',aqlTypeVal).eq('resultat','en_attente').order('requested_at',{ascending:true}).limit(200)
        var aqlMap = await getLotsMap((aqlR.data||[]).map(function(a){return a.lot_id}))
        ;(aqlR.data||[]).forEach(function(a){
          var l=aqlMap[a.lot_id]; if(!l) return
          aqlCat.items.push({key:'aql_'+a.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,statutSap:l.statut_sap||'',
            action:'AQL '+a.type+' — Résultat à saisir',
            canAqlSaisir:canAqlSaisir,acting:false,
            aqlId:a.id,aqlType:a.type})
        })
        if (aqlCat.items.length) cats.push(aqlCat)
      }

      // ── 5. DÉVIATIONS BLOQUANTES ──────────────────────────────────────
      if (svc==='aq'||svc==='dt'||svc==='admin') {
        var devCat = makeCat('dev','⚠','Déviations bloquantes ouvertes',true)
        var devR = await supabase.from('deviations').select('id,lot_id,numero_dn').eq('bloquante',true).in('statut',['ouverte','en_cours']).order('declared_at',{ascending:false}).limit(200)
        var devMap = await getLotsMap((devR.data||[]).map(function(d){return d.lot_id}))
        ;(devR.data||[]).forEach(function(d){
          var l=devMap[d.lot_id]; if(!l) return
          devCat.items.push({key:'dev_'+d.id,lotId:l.id,lotNum:l.numero_lot,prodDesc:l.prod_desc||l.prod_code,statutSap:l.statut_sap||'',
            action:'Déviation bloquante'+(d.numero_dn?' ('+d.numero_dn+')':''),urgent:true,canAct:false,acting:false})
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
        if (p.data) {
          userService.value = p.data.service
          selectedSvc.value = p.data.service === 'admin' ? 'aq' : p.data.service
          await load()
        }
      } else { loading.value = false }
    })

    return {
      svcLabel, isAdmin, selectedSvc, totalCount, loading, categories, load, SVC_LABELS_ALL,
      searchQuery, searchResultCount, isCatVisible, visibleGroups, getItemsForCat, getDocsForGroup,
      toggleSort, sortIcon, SAP_SHORT,
      doDocAction, doDocReturn, doItemAction, doAqlSaisir, aqlAvisModal, confirmAqlNonConforme
    }
  }
}
</script>

<style scoped>
.tp{max-width:960px;margin:0 auto;padding:4px 0 40px}

/* Header */
.tp-hd{display:flex;align-items:center;justify-content:space-between;margin-bottom:16px;flex-wrap:wrap;gap:12px}
.tp-hd-left{display:flex;align-items:center;gap:14px}
.tp-hd-icon{font-size:28px}
.tp-h1{font-size:20px;font-weight:700;color:#111}
.tp-h2{font-size:12px;color:#888;margin-top:2px}
.tp-hd-right{display:flex;align-items:center;gap:12px;flex-wrap:wrap}
.tp-total{font-size:13px;font-weight:600;padding:4px 12px;border-radius:12px}
.tp-total-bad{background:#FCEBEB;color:#A32D2D}
.tp-total-ok{background:#EAF3DE;color:#3B6D11}
.tp-refresh{padding:6px 14px;font-size:12px;font-family:inherit;border:1px solid #ddd;border-radius:4px;background:#fff;cursor:pointer;color:#555;transition:.15s}.tp-refresh:hover{background:#f5f5f5;border-color:#bbb}.tp-refresh:disabled{opacity:.5;cursor:default}
.tp-svc-sel{padding:6px 10px;font-size:12px;font-family:inherit;border:1px solid #ddd;border-radius:4px;background:#fff;color:#333;cursor:pointer;outline:none}

/* Barre de recherche */
.tp-search-bar{display:flex;align-items:center;gap:8px;margin-bottom:16px;background:#fff;border:1px solid #ddd;border-radius:6px;padding:8px 14px;box-shadow:0 1px 3px rgba(0,0,0,.04)}
.tp-search-icon{font-size:15px;color:#aaa;flex-shrink:0}
.tp-search-inp{flex:1;border:none;outline:none;font-size:13px;font-family:inherit;color:#333;background:transparent;min-width:0}
.tp-search-inp::placeholder{color:#c0c0c0}
.tp-search-count{font-size:11px;font-weight:600;color:#7c3aed;background:#ede9fe;padding:2px 10px;border-radius:10px;white-space:nowrap;flex-shrink:0}
.tp-search-clear{border:none;background:none;cursor:pointer;color:#bbb;font-size:14px;padding:0 2px;line-height:1;flex-shrink:0}.tp-search-clear:hover{color:#555}

/* Loading / empty */
.tp-loading{text-align:center;color:#999;font-size:14px;padding:48px;font-style:italic}
.tp-empty{display:flex;flex-direction:column;align-items:center;gap:10px;padding:60px 20px;color:#888}
.tp-empty-icon{font-size:36px;color:#3B6D11}
.tp-empty-txt{font-size:14px}

/* ── Categories ──────────────────────────────────────────────────── */
.tp-cats{display:flex;flex-direction:column;gap:14px}
.tp-cat{border:1px solid #ede9fe;border-radius:8px;overflow:hidden;background:#fff;box-shadow:0 2px 8px rgba(0,0,0,.05)}

/* Niveau 1 — Catégorie : bandeau avec barre gauche colorée */
.tp-cat-hd{display:flex;align-items:center;gap:10px;padding:13px 18px;cursor:pointer;user-select:none;transition:.1s;background:#f5f3ff;border-left:4px solid #7c3aed}
.tp-cat-hd:hover{background:#ede9fe}
.tp-cat-urgent{border-left-color:#E24B4A;background:#fdf5f5}
.tp-cat-urgent:hover{background:#faeaea}
.tp-cat-icon{font-size:15px;flex-shrink:0}
.tp-cat-title{font-size:11px;font-weight:700;color:#1a2a3a;text-transform:uppercase;letter-spacing:.9px;flex:1}
.tp-cat-badge{font-size:10px;font-weight:700;padding:2px 9px;border-radius:10px;white-space:nowrap;flex-shrink:0}
.tp-badge-blue{background:#ede9fe;color:#6d28d9}
.tp-badge-red{background:#FCEBEB;color:#A32D2D}
.tp-cat-chev{font-size:10px;color:#aab;flex-shrink:0;margin-left:2px}

/* ── Groupes (niveau 2) ───────────────────────────────────────────── */
.tp-cat-list{border-top:1px solid #e8eef5}
.tp-grp{border-bottom:1px solid #edf2f7}.tp-grp:last-child{border-bottom:none}

/* En-tête groupe — indenté + bordure gauche subtile */
.tp-grp-hd{display:flex;align-items:center;gap:8px;padding:9px 18px 9px 24px;cursor:pointer;background:#fff;user-select:none;transition:.1s;border-left:3px solid #ddd6fe}
.tp-grp-hd:hover{background:#faf5ff;border-left-color:#7c3aed}
.tp-doc-type-tag{font-size:11px;font-weight:700;color:#6d28d9;background:#ede9fe;padding:2px 8px;border-radius:3px;white-space:nowrap;flex-shrink:0;min-width:52px;text-align:center;box-sizing:border-box}
.tp-grp-sep{font-size:11px;color:#bbb;flex-shrink:0}
.tp-grp-action{font-size:12px;color:#444;font-weight:500;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tp-grp-badge{font-size:10px;font-weight:600;color:#7c3aed;background:#ede9fe;padding:1px 7px;border-radius:8px;white-space:nowrap;flex-shrink:0}
.tp-grp-chev{font-size:10px;color:#bbb;flex-shrink:0}

/* ── Statut SAP badge (colonne 1, avant N° lot) ─────────────────── */
/* Largeurs fixes synchronisées avec l'en-tête de tri */
.tp-sap-badge{font-size:9px;font-weight:700;padding:2px 6px;border-radius:3px;white-space:nowrap;flex-shrink:0;width:110px;text-align:center;box-sizing:border-box;display:inline-block}
.sap-quarantaine{background:#FAEEDA;color:#854F0B}
.sap-sous_investigation{background:#FCEBEB;color:#A32D2D}
.sap-refuse{background:#e8e8e8;color:#555}
.sap-vide,.sap-{visibility:hidden}  /* réserve l'espace, badge invisible si vide */

/* ── En-tête colonnes tri (niveau 3) ─────────────────────────────── */
.tp-grp-body{background:#faf5ff;border-top:1px solid #eef3fb}
.tp-grp-sort-hd{display:flex;align-items:center;gap:8px;padding:5px 18px 5px 32px;background:#f5f3ff;border-bottom:1px solid #e2eaf5}
.tp-sort-col{font-size:9px;font-weight:700;color:#9aabbf;text-transform:uppercase;letter-spacing:.4px;display:flex;align-items:center;gap:3px;user-select:none;padding:2px 0;flex-shrink:0}
.tp-sort-col.tp-sort-lot,.tp-sort-col.tp-sort-desc{cursor:pointer;transition:.1s}.tp-sort-col.tp-sort-lot:hover,.tp-sort-col.tp-sort-desc:hover{color:#7c3aed}
.tp-sort-sap{width:110px}
.tp-sort-lot{width:116px}   /* badge(52) + gap(8) + padding lot = alignement exact */
.tp-sort-desc{flex:1;min-width:0}
.tp-sort-since{width:96px}
.tp-sort-acts{width:200px;text-align:right}
.tp-sort-icon{font-size:10px}

/* ── Items dans groupes (niveau 4) ───────────────────────────────── */
.tp-doc-item{display:flex;align-items:center;padding:7px 18px 7px 32px;border-bottom:1px solid #f0f4f8;gap:8px;min-width:0}.tp-doc-item:last-child{border-bottom:none}.tp-doc-item:hover{background:#f5f3ff}
.tp-lot-mono{font-family:'SF Mono','Fira Code',monospace;font-size:10px;font-weight:600;white-space:nowrap;flex-shrink:0;cursor:pointer;color:#6d28d9;width:108px;background:#f5f3ff;padding:2px 5px;border-radius:2px}
.tp-lot-mono:hover{text-decoration:underline}
.tp-prod-desc{font-size:11px;color:#444;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1;min-width:0}
.tp-prod-code{font-size:9px;color:#aaa;font-family:'SF Mono',monospace;margin-left:4px}
.tp-doc-since{font-size:10px;font-weight:600;white-space:nowrap;flex-shrink:0;padding:2px 8px;border-radius:8px;width:88px;text-align:center;box-sizing:border-box}
.since-ok{background:#EAF3DE;color:#3B6D11}
.since-orange{background:#FEF5E7;color:#A0620D}
.since-red{background:#FCEBEB;color:#A32D2D}

/* Action buttons */
.tp-doc-btns{display:flex;gap:4px;flex-shrink:0;width:200px;justify-content:flex-end}
.tp-do-btn{padding:3px 11px;font-size:11px;font-weight:600;font-family:inherit;border-radius:3px;border:1px solid #7c3aed;background:#ede9fe;color:#7c3aed;cursor:pointer;white-space:nowrap;flex-shrink:0;transition:.1s}.tp-do-btn:hover{background:#7c3aed;color:#fff}.tp-do-btn:disabled{opacity:.5;cursor:default}
.tp-do-ok{border-color:#1D9E75;background:#EAF3DE;color:#1D9E75}.tp-do-ok:hover{background:#1D9E75;color:#fff}
.tp-do-nok{border-color:#A32D2D;background:#FCEBEB;color:#A32D2D}.tp-do-nok:hover{background:#A32D2D;color:#fff}
.tp-do-ret{border-color:#A0620D;background:#FEF5E7;color:#A0620D}.tp-do-ret:hover{background:#A0620D;color:#fff}
.tp-item-arr{font-size:12px;color:#ccc;cursor:pointer;padding:0 2px;flex-shrink:0;margin-left:4px}.tp-item-arr:hover{color:#7c3aed}

/* Motif retour inline */
.tp-return-row{display:flex;align-items:center;gap:8px;padding:8px 18px 8px 32px;background:#FEF5E7;border-bottom:1px solid #f0e0c0;flex-wrap:wrap}
.tp-return-label{font-size:11px;font-weight:600;color:#A0620D;white-space:nowrap;flex-shrink:0}
.tp-return-motif{flex:1;min-width:160px;font-size:11px;font-family:inherit;border:1px solid #E89C3A;border-radius:3px;padding:4px 8px;resize:none;outline:none;background:#fff}
.tp-btn-cancel{padding:3px 8px;font-size:11px;font-family:inherit;border:1px solid #ccc;border-radius:3px;background:#fff;color:#666;cursor:pointer}.tp-btn-cancel:hover{background:#f5f5f5}

/* ── Items plats (autres catégories) ─────────────────────────────── */
.tp-item{display:flex;align-items:center;justify-content:space-between;padding:10px 18px 10px 24px;border-bottom:1px solid #f5f8fb;gap:12px;border-left:3px solid transparent;transition:.1s}.tp-item:last-child{border-bottom:none}.tp-item:hover{background:#faf5ff;border-left-color:#7c3aed}
.tp-item-main{display:flex;align-items:center;gap:8px;min-width:0;flex:1;cursor:pointer}
.tp-item-lot{font-family:'SF Mono','Fira Code',monospace;font-size:11px;font-weight:600;color:#6d28d9;white-space:nowrap;background:#f5f3ff;padding:2px 7px;border-radius:3px;flex-shrink:0}
.tp-item-bl{font-size:10px;font-weight:700;color:#A32D2D;background:#FCEBEB;padding:1px 5px;border-radius:2px;white-space:nowrap;flex-shrink:0}
.tp-item-prod{font-size:12px;color:#555;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1;min-width:0}
.tp-item-right{display:flex;align-items:center;gap:8px;flex-shrink:0}
.tp-item-action{font-size:11px;font-weight:500;white-space:nowrap;max-width:220px;overflow:hidden;text-overflow:ellipsis}
.tp-action-blue{color:#7c3aed}
.tp-action-red{color:#A32D2D}

/* ── Responsive mobile ───────────────────────────────────────────── */
@media (max-width: 640px) {
  .tp{padding:2px 0 32px}
  /* Catégorie : titre plus compact */
  .tp-cat-hd{padding:10px 14px}
  .tp-cat-title{font-size:10px;letter-spacing:.6px}

  /* Groupe : moins d'indent */
  .tp-grp-hd{padding:8px 12px 8px 16px}

  /* En-tête tri : masqué sur mobile (trop étroit) */
  .tp-grp-sort-hd{display:none}

  /* Items groupes : 2 lignes empilées */
  .tp-doc-item{flex-wrap:wrap;padding:8px 12px 8px 18px;gap:4px 8px;align-items:flex-start}
  /* Ligne 1 : badge + N° lot + désignation */
  .tp-sap-badge{width:auto;flex-shrink:0;align-self:center}
  .tp-lot-mono{width:auto;align-self:center}
  .tp-prod-desc{order:1;width:100%;flex:none;margin-top:2px;padding-left:0}
  /* Ligne 2 : depuis + boutons */
  .tp-doc-since{order:2;margin-top:4px;width:auto}
  .tp-doc-btns{order:3;margin-top:4px;width:auto;margin-left:auto}
  .tp-item-arr{order:4;align-self:flex-start;margin-top:4px}

  /* Items plats : stack */
  .tp-item{flex-wrap:wrap;padding:10px 12px 10px 16px;gap:6px}
  .tp-item-main{width:100%}
  .tp-item-right{width:100%;justify-content:flex-end}
  .tp-item-action{flex:1;max-width:none}

  /* Retour motif */
  .tp-return-row{padding:8px 12px 8px 18px}

  /* Cacher la désignation dans l'en-tête groupe sur mobile */
  .tp-grp-action{display:none}
  .tp-grp-sep{display:none}
}

/* ── MODAL AVIS AQL ── */
.tp-ov{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.45);display:flex;align-items:center;justify-content:center;z-index:300}
.tp-modal{background:#fff;border-radius:8px;padding:22px 24px;width:420px;max-width:96vw;box-shadow:0 12px 40px rgba(0,0,0,.18)}
.tp-modal-hd{font-size:14px;font-weight:600;color:#A32D2D;margin-bottom:10px}
.tp-modal-ctx{font-size:11px;color:#666;background:#f5f5f5;padding:5px 10px;border-radius:3px;margin-bottom:12px}
.tp-modal-lbl{display:block;font-size:11px;color:#555;font-weight:500;margin-bottom:4px}
.tp-modal-ta{width:100%;box-sizing:border-box;padding:8px 10px;border:1px solid #ddd;border-radius:4px;font-size:13px;font-family:inherit;resize:vertical;outline:none}
.tp-modal-ta:focus{border-color:#A32D2D}
.tp-modal-err{font-size:12px;color:#A32D2D;margin-top:6px}
.tp-modal-acts{display:flex;gap:8px;margin-top:14px}
.tp-btn-nok{flex:1;padding:9px;background:#A32D2D;color:#fff;border:none;border-radius:4px;font-size:13px;font-weight:500;cursor:pointer}
.tp-btn-nok:hover:not(:disabled){background:#8a2020}
.tp-btn-nok:disabled{opacity:.5;cursor:not-allowed}
</style>
