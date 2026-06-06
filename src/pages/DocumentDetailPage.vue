<template>
  <div v-if="doc">
    <div class="bc"><span @click="goBack">← Retour au lot</span></div>
    <div class="lh">
      <div class="lh-info">
        <div class="lh-type"><span class="lt-short">{{shortType}}</span> <span class="lt-full" v-if="typeFull">({{typeFull}})</span></div>
        <div class="lh-lot"><span class="ll-num">{{lotNum}}</span><span class="ll-prod">{{prodDesc}}</span></div>
      </div>
      <div class="lh-right"><span class="ttl">{{statusLabel}}</span></div>
    </div>

    <div v-if="submitting" class="detail-reloading">⟳ Actualisation…</div>

    <!-- DA Micro non applicable : permettre de la déclarer applicable -->
    <div class="na-bloc" v-if="!doc.is_applicable && doc.type_document==='da_micro'">
      <div class="na-icon">🧫</div>
      <div class="na-msg">
        <strong>DA Microbiologie — Non applicable</strong><br>
        Ce document n'est pas encore requis pour ce lot. Le LCQ peut le déclarer applicable si des analyses microbiologiques sont nécessaires.
      </div>
      <button v-if="canEmit" class="btn bg" @click="doSetApplicable">Déclarer applicable et lancer le circuit</button>
    </div>
    <div class="na-bloc na-info" v-else-if="!doc.is_applicable">
      <div class="na-msg">Ce document est marqué <strong>Non applicable</strong> pour ce lot.</div>
    </div>

    <!-- Circuit du document (même affichage que circuits OF/OC / AQL) -->
    <div class="section" v-if="doc.is_applicable">
      <div class="sh"><span>Étapes du circuit {{shortType}}</span><span class="dc">{{doneCount}}/{{steps.length}}</span></div>
      <div class="dg dg-1">
        <div class="di" v-for="(s,idx) in steps" :key="s.n" :class="{'di-act': stepClickable(s.n)}" @click="stepClick(s.n)">
          <div class="dind" :class="stepIndClass(s.n)"></div>
          <div class="di-body">
            <div class="dn">{{idx+1}}. {{s.label}}</div>
            <div class="ds" :class="stepDsClass(s.n)">{{stepStatus(s.n)}}</div>
            <div class="di-svc">Service : {{s.service}}</div>
            <!-- Action secondaire (retour) : petit bouton, comme la relance AQL -->
            <div v-if="stepActionable(s.n) && retourAct" class="step-acts" @click.stop>
              <button class="btn-ret" @click="prepareRetour(retourAct.dest)">↩ {{retourAct.label}}</button>
            </div>
          </div>
        </div>
      </div>

      <div class="rb" v-if="showRetour">
        <label>Motif du retour ({{retourDest === 'emetteur' ? 'vers ' + doc.service_emetteur : 'vers AQ'}}) :</label>
        <textarea v-model="motif" rows="3" placeholder="Préciser le motif..."></textarea>
        <div class="ra">
          <button class="btn br" @click="doRetour">Confirmer le retour</button>
          <button class="btn bc2" @click="showRetour=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- Historique (même affichage que circuits / AQL) -->
    <div class="section">
      <div class="sh"><span>Historique des mouvements</span></div>
      <div class="circ-hist" v-if="movements.length">
        <div class="circ-hist-row" v-for="(m,i) in movements" :key="i">
          <span class="circ-hist-dot" :class="dotClass(m.action)"></span>
          <span class="circ-hist-step">{{actionLabelsMap[m.action]}}<span v-if="m.motif_retour" class="hist-motif"> · {{m.motif_retour}}</span></span>
          <span class="circ-hist-who">{{(m.from_service||'?')}} → {{(m.to_service||'?')}} · {{m.user}}</span>
          <span class="circ-hist-at">{{fmtDt(m.performed_at)}}</span>
        </div>
      </div>
      <div v-else class="em">Aucun mouvement</div>
    </div>
  </div>
  <div v-else class="loading">Chargement...</div>
</template>
<script>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { loadPermissions, canPerform } from '../services/permissions'
import { createNotification } from '../services/notifications'
export default {
  setup() {
    var route = useRoute(), router = useRouter()
    var doc = ref(null), movements = ref([]), showRetour = ref(false), motif = ref(''), userId = ref(null), retourDest = ref(''), userService = ref('')
    var lotNum = ref(''), prodDesc = ref(''), submitting = ref(false)
    var typeLabels = { if:'IF (Instruction de fabrication)', ic:'IC (Instruction de conditionnement)', da_pc:'DA Physico-chimie (Dossier analytique)', da_micro:'DA Microbiologie (Dossier analytique)', ccl:'CCL (Certificat de Conformité du Lot)', rvp:'RVP', deviation:'Déviation', analyse_risque:'Analyse de risque', autorisation_partenaire:'Autorisation partenaire', autre:'Autre', maj_if:'MàJ IF', maj_ic:'MàJ IC', maj_nmcl_of:'MàJ Nomenclature OF', maj_nmcl_oc:'MàJ Nomenclature OC', cloture_sap_of:'Clôture SAP OF', cloture_sap_oc:'Clôture SAP OC' }
    var actionLabelsMap = { emission:'Émission', transmission:'Transmission', reception:'Réception', retour:'Retour pour rectification', rectification:'Rectification et renvoi', approbation:'Approbation', validation:'Validation Planification', cloture:'Demande de clôture', cloture_confirmee:'Clôture confirmée' }
    var statusMap = { non_emis:'Non émis', emis:'Émis — en attente', verification_aq:'En cours de vérification AQ', retour_emetteur:'Retourné à l\'émetteur', rectification:'En cours de rectification', approuve_aq:'Vérifié AQ — en attente DT', approbation_dt:'En cours d\'approbation DT', approuve_dt:'Approuvé DT', valide_planif:'Validé Planif. — en attente demande clôture', cloture_demandee:'Clôture demandée — en attente confirmation', cloture:'Clôturé' }
    var statusLabel = computed(function() { return statusMap[doc.value ? doc.value.statut : ''] || '' })
    var isClotSap = computed(function(){ return doc.value && doc.value.type_document && doc.value.type_document.startsWith('cloture_sap_') })
    var isMajDoc = computed(function(){ return doc.value && doc.value.type_document && doc.value.type_document.startsWith('maj_') })
    var isCCL = computed(function(){ return doc.value && doc.value.type_document === 'ccl' })

    var flowClass = function(step) {
      var s = doc.value ? doc.value.statut : ''
      var clot = isClotSap.value
      var ccl = isCCL.value
      if (step === 1) {
        if (s === 'non_emis') return 'fs-active'
        if (s === 'retour_emetteur') return 'fs-ret'
        return 'fs-done'
      }
      if (step === 2) {
        if (ccl) {
          if (s === 'emis') return 'fs-active'
          if (s === 'approuve_dt') return 'fs-done'
          return 'fs-wait'
        }
        if (clot) {
          if (s === 'emis') return 'fs-active'
          if (s === 'valide_planif' || s === 'cloture_demandee' || s === 'cloture') return 'fs-done'
          return 'fs-wait'
        }
        if (s === 'emis' || s === 'verification_aq') return 'fs-active'
        if (s === 'approuve_aq' || s === 'approbation_dt' || s === 'approuve_dt') return 'fs-done'
        return 'fs-wait'
      }
      if (step === 3) {
        if (clot) {
          if (s === 'valide_planif') return 'fs-active'
          if (s === 'cloture_demandee' || s === 'cloture') return 'fs-done'
          return 'fs-wait'
        }
        if (s === 'approuve_aq' || s === 'approbation_dt') return 'fs-active'
        if (s === 'approuve_dt') return 'fs-done'
        return 'fs-wait'
      }
      if (step === 4) {
        if (clot) {
          if (s === 'cloture_demandee') return 'fs-active'
          if (s === 'cloture') return 'fs-done'
          return 'fs-wait'
        }
        return 'fs-wait'
      }
      return 'fs-wait'
    }

    var fmtDt = function(d) { return d ? new Date(d).toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}) : '—' }

    // ── Affichage parcours (dérivé de flowClass — logique INCHANGÉE) ──
    var FC_IND = { 'fs-done':'ind-done', 'fs-active':'ind-prog', 'fs-ret':'ind-ret', 'fs-wait':'ind-wait' }
    var stepIndClass = function(n){ return FC_IND[flowClass(n)] || 'ind-wait' }
    var stepDsClass = function(n){ var f=flowClass(n); return f==='fs-done'?'ds-ok':(f==='fs-ret'?'ds-ret':'') }
    var stepActionable = function(n){ var f=flowClass(n); return f==='fs-active' || f==='fs-ret' }
    var RVP_SVC = {fabrication:'Fab',conditionnement:'Cond',lcq:'LCQ'}
    var shortType = computed(function(){
      if(!doc.value) return 'Document'
      var t = doc.value.type_document
      if(t==='rvp') return 'RVP '+(RVP_SVC[doc.value.service_emetteur]||doc.value.service_emetteur||'')
      var m={if:'IF',ic:'IC',da_pc:'DA Physico',da_micro:'DA Micro',ccl:'CCL',maj_if:'MàJ IF',maj_ic:'MàJ IC',maj_nmcl_of:'MàJ Nmcl OF',maj_nmcl_oc:'MàJ Nmcl OC',cloture_sap_of:'Clôt. SAP OF',cloture_sap_oc:'Clôt. SAP OC'}
      return m[t]||'Document'
    })
    var TYPE_FULL = {if:'Instruction de fabrication',ic:'Instruction de conditionnement',da_pc:'Dossier analytique physico-chimie',da_micro:'Dossier analytique microbiologie',ccl:'Certificat de conformité du lot',rvp:'Rapport de validation process',maj_if:'Mise à jour de l’instruction de fabrication',maj_ic:'Mise à jour de l’instruction de conditionnement',maj_nmcl_of:'Mise à jour de la nomenclature de fabrication',maj_nmcl_oc:'Mise à jour de la nomenclature de conditionnement',cloture_sap_of:'Clôture SAP de l’ordre de fabrication',cloture_sap_oc:'Clôture SAP de l’ordre de conditionnement'}
    var typeFull = computed(function(){ return TYPE_FULL[doc.value?doc.value.type_document:''] || '' })
    var steps = computed(function(){
      if (!doc.value) return []
      var em = doc.value.service_emetteur || 'Émetteur'
      if (isCCL.value) return [{n:1,label:'Transmission AQ',service:'AQ'},{n:2,label:'Libération DT',service:'DT'}]
      if (isClotSap.value) return [{n:1,label:'Demande validation',service:em},{n:2,label:'Validation Planification',service:'Planification'},{n:3,label:'Demande clôture',service:em},{n:4,label:'Clôture',service:'Planification'}]
      return [{n:1,label:'Émission',service:em},{n:2,label:'Vérification AQ',service:'AQ'},{n:3,label:'Approbation DT',service:'DT'}]
    })
    var doneCount = computed(function(){ var c=0; steps.value.forEach(function(s){ if (flowClass(s.n)==='fs-done') c++ }); return c })
    var stepStatus = function(n){
      var d = doc.value, f = flowClass(n)
      if (f==='fs-done'){
        if (n===1 && d.emitted_at) return '✓ Émis — ' + fmtDt(d.emitted_at)
        if (n===steps.value.length && !isClotSap.value && d.approved_at) return '✓ Approuvé — ' + fmtDt(d.approved_at)
        return '✓ Fait'
      }
      if (f==='fs-active' || f==='fs-ret'){
        if (d.pending_ar_service && !isClotSap.value && !isMajDoc.value) return canAR.value ? '＋ Accuser réception' : '⏳ En attente AR — ' + d.pending_ar_service
        if (stepCanPrimary()) return '＋ ' + primaryLabel()
        return f==='fs-ret' ? '↩ Retourné — à rectifier' : 'En cours'
      }
      return 'À venir'
    }
    var goBack = function(){ router.push('/lots/'+route.params.lotId) }

    var canEmit = computed(function(){
      if (!doc.value) return false
      var t = doc.value.type_document
      if (t === 'maj_if') return canPerform('emettre_maj_if')
      if (t === 'maj_ic') return canPerform('emettre_maj_ic')
      if (t === 'maj_nmcl_of') return canPerform('emettre_maj_nmcl_of')
      if (t === 'maj_nmcl_oc') return canPerform('emettre_maj_nmcl_oc')
      if (t === 'cloture_sap_of') return canPerform('emettre_cloture_sap_of')
      if (t === 'cloture_sap_oc') return canPerform('emettre_cloture_sap_oc')
      if (t === 'ccl') return canPerform('emettre_ccl')
      return canPerform('emettre_' + t)
    })
    var canVerify = computed(function(){
      if (!doc.value) return false
      var t = doc.value.type_document
      if (t.startsWith('maj_')) return canPerform('verifier_maj_doc')
      if (t === 'cloture_sap_of') return canPerform('valider_cloture_sap_of')
      if (t === 'cloture_sap_oc') return canPerform('valider_cloture_sap_oc')
      return canPerform('verifier_' + t)
    })
    var canApprove = computed(function(){
      if (!doc.value) return false
      var t = doc.value.type_document
      if (t.startsWith('maj_')) return canPerform('approuver_maj_doc')
      if (t === 'cloture_sap_of') return canPerform('demander_cloture_sap_of')
      if (t === 'cloture_sap_oc') return canPerform('demander_cloture_sap_oc')
      if (t === 'ccl') return canPerform('approuver_ccl')
      return canPerform('approuver_' + t)
    })
    var canConfirmClot = computed(function(){
      if (!doc.value) return false
      var t = doc.value.type_document
      if (t === 'cloture_sap_of') return canPerform('confirmer_cloture_sap_of')
      if (t === 'cloture_sap_oc') return canPerform('confirmer_cloture_sap_oc')
      return false
    })
    var canRetourner = computed(function(){ return canPerform('retourner_document') })
    var canRectifier = computed(function(){ return canPerform('rectifier_document') })
    var dotClass = function(a) { return a === 'retour' ? 'dot-ko' : a === 'approbation' ? 'dot-ok' : 'dot-wait' }

    var prepareRetour = function(dest) {
      retourDest.value = dest
      showRetour.value = true
    }

    var doSetApplicable = async function() {
      if (submitting.value) return
      submitting.value = true
      try {
        var now = new Date().toISOString()
        var lotId = parseInt(route.params.lotId)
        await supabase.from('liberation_documents').update({is_applicable:true,is_required:true,updated_at:now}).eq('id',doc.value.id)
        await supabase.from('liberation_dossiers').update({da_micro_applicable:true,updated_at:now}).eq('lot_id',lotId)
        await supabase.from('lot_events').insert({lot_id:lotId,event_type:'da_micro_applicable',description:'DA Microbiologie déclarée applicable',triggered_by:userId.value,created_at:now})
        await loadDoc()
      } finally { submitting.value = false }
    }

    var doAct = async function(action) {
      var now = new Date().toISOString()
      var docId = doc.value.id
      var lotId = parseInt(route.params.lotId)
      var t = doc.value.type_document
      var clot = t.startsWith('cloture_sap_')

      var ccl = isCCL.value
      if (action === 'emettre') {
        var toSvc = clot ? 'planification' : ccl ? 'dt' : 'aq'
        var arSvcEmit = clot ? null : ccl ? 'dt' : 'aq'
        await supabase.from('liberation_documents').update({ statut: 'emis', emitted_at: now, emitted_by: userId.value, pending_ar_service: arSvcEmit, updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'emission', from_service: doc.value.service_emetteur, to_service: toSvc, performed_by: userId.value, performed_at: now })
      } else if (action === 'verifier_aq') {
        await supabase.from('liberation_documents').update({ statut: 'approuve_aq', pending_ar_service: 'dt', updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'approbation', from_service: 'aq', to_service: 'dt', performed_by: userId.value, performed_at: now })
      } else if (action === 'valider_planif') {
        await supabase.from('liberation_documents').update({ statut: 'valide_planif', updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'validation', from_service: 'planification', to_service: doc.value.service_emetteur, performed_by: userId.value, performed_at: now })
      } else if (action === 'rectifier') {
        var rectToSvc = ccl ? 'dt' : 'aq'
        var rectPending = ccl ? 'dt' : 'aq'
        var rectStatut = ccl ? 'emis' : 'verification_aq'
        var rectUpdate = { statut: rectStatut, pending_ar_service: rectPending, updated_at: now }
        if (ccl) { rectUpdate.emitted_at = now; rectUpdate.emitted_by = userId.value }
        await supabase.from('liberation_documents').update(rectUpdate).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'rectification', from_service: doc.value.service_emetteur, to_service: rectToSvc, performed_by: userId.value, performed_at: now })
      } else if (action === 'approuver_dt') {
        await supabase.from('liberation_documents').update({ statut: 'approuve_dt', approved_at: now, pending_ar_service: null, updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'approbation', from_service: 'dt', performed_by: userId.value, performed_at: now })
        if (ccl) {
          await supabase.from('lots').update({ statut_sap: 'accepte', date_liberation: now, updated_at: now }).eq('id', lotId)
          await supabase.from('liberation_dossiers').update({ statut: 'libere', if_approved: true, ic_approved: true, da_pc_approved: true, deviations_closed: true, pieces_complementaires_ok: true, updated_at: now }).eq('lot_id', lotId)
        } else {
          var fieldMap = { 'if': 'if_approved', ic: 'ic_approved', da_pc: 'da_pc_approved', da_micro: 'da_micro_approved' }
          var field = fieldMap[t]
          if (field) { await supabase.from('liberation_dossiers').update({ [field]: true, updated_at: now }).eq('lot_id', lotId) }
        }
      } else if (action === 'demander_cloture') {
        await supabase.from('liberation_documents').update({ statut: 'cloture_demandee', updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'cloture', from_service: doc.value.service_emetteur, to_service: 'planification', performed_by: userId.value, performed_at: now })
      } else if (action === 'cloturer') {
        await supabase.from('liberation_documents').update({ statut: 'cloture', updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'cloture_confirmee', from_service: 'planification', performed_by: userId.value, performed_at: now })
      }

      await supabase.from('lot_events').insert({ lot_id: lotId, event_type: 'document_' + action, description: t.toUpperCase() + ' — ' + action, triggered_by: userId.value, created_at: now })

      // Notifications
      var lotRes = await supabase.from('lots').select('numero_lot').eq('id', lotId).single()
      var lotNum = lotRes.data ? lotRes.data.numero_lot : ''
      var typeLabel = typeLabels[t] || t.toUpperCase().replace(/_/g, ' ')
      var svc = doc.value.service_emetteur
      if (action === 'emettre') {
        var notifSvc = clot ? 'planification' : ccl ? 'dt' : 'aq'
        await createNotification(notifSvc, lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + typeLabel + ' émis, en attente', 'document_transmis')
      } else if (action === 'verifier_aq') {
        await createNotification('dt', lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + typeLabel + ' vérifié AQ, en attente approbation DT', 'document_transmis')
      } else if (action === 'valider_planif') {
        if (svc) await createNotification(svc, lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + typeLabel + ' validé Planif., demande clôture possible', 'document_transmis')
      } else if (action === 'rectifier') {
        var rectNotifSvc = ccl ? 'dt' : 'aq'
        await createNotification(rectNotifSvc, lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + typeLabel + (ccl ? ' retransmis au DT' : ' rectifié, en attente de vérification'), 'document_transmis')
      } else if (action === 'approuver_dt') {
        await createNotification('aq', lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + (ccl ? 'Lot libéré par le DT' : typeLabel + ' approuvé par le DT'), ccl ? 'lot_libere' : 'document_approuve')
        if (!ccl) { var svcMap = { fabrication: 'fabrication', conditionnement: 'conditionnement', lcq: 'lcq' }; if (svcMap[svc]) { await createNotification(svcMap[svc], lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + typeLabel + ' approuvé par le DT', 'document_approuve') } }
      } else if (action === 'demander_cloture') {
        await createNotification('planification', lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + typeLabel + ' : clôture demandée, en attente confirmation', 'document_approuve')
      } else if (action === 'cloturer') {
        if (svc) await createNotification(svc, lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + typeLabel + ' : clôturé par Planification', 'document_approuve')
      }

      await loadDoc()
    }

    var doRetour = async function() {
      if (submitting.value) return
      submitting.value = true
      try {
      var now = new Date().toISOString()
      var docId = doc.value.id
      var lotId = parseInt(route.params.lotId)

      var docIsCCL = doc.value && doc.value.type_document === 'ccl'
      if (retourDest.value === 'emetteur') {
        await supabase.from('liberation_documents').update({ statut: 'retour_emetteur', pending_ar_service: doc.value.service_emetteur || null, updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'retour', from_service: 'aq', to_service: doc.value.service_emetteur, motif_retour: motif.value, performed_by: userId.value, performed_at: now })
      } else if (retourDest.value === 'aq') {
        if (docIsCCL) {
          await supabase.from('liberation_documents').update({ statut: 'retour_emetteur', pending_ar_service: 'aq', updated_at: now }).eq('id', docId)
          await supabase.from('document_movements').insert({ document_id: docId, action: 'retour', from_service: 'dt', to_service: 'aq', motif_retour: motif.value, performed_by: userId.value, performed_at: now })
        } else {
          await supabase.from('liberation_documents').update({ statut: 'verification_aq', pending_ar_service: 'aq', updated_at: now }).eq('id', docId)
          await supabase.from('document_movements').insert({ document_id: docId, action: 'retour', from_service: 'dt', to_service: 'aq', motif_retour: motif.value, performed_by: userId.value, performed_at: now })
        }
      }

      await supabase.from('lot_events').insert({ lot_id: lotId, event_type: 'document_retour', description: doc.value.type_document.toUpperCase() + ' — retourné vers ' + retourDest.value, triggered_by: userId.value, created_at: now })

      var lotRes2 = await supabase.from('lots').select('numero_lot').eq('id', lotId).single()
      var lotNum2 = lotRes2.data ? lotRes2.data.numero_lot : ''
      var typeLabel2 = doc.value.type_document.toUpperCase().replace('_', ' ')
      if (retourDest.value === 'emetteur') {
        var svcMap2 = { fabrication: 'fabrication', conditionnement: 'conditionnement', lcq: 'lcq' }
        if (svcMap2[doc.value.service_emetteur]) {
          await createNotification(svcMap2[doc.value.service_emetteur], lotId, doc.value.id, 'Lot ' + lotNum2 + ' — ' + typeLabel2 + ' retourné pour rectification', 'document_retourne')
        }
      } else if (retourDest.value === 'aq') {
        await createNotification('aq', lotId, doc.value.id, 'Lot ' + lotNum2 + ' — ' + typeLabel2 + ' retourné par le DT', 'document_retourne')
      }

      showRetour.value = false
      motif.value = ''
      await loadDoc()
      } finally { submitting.value = false }
    }

    var doAR = async function() {
      var now = new Date().toISOString()
      var docId = doc.value.id
      var lotId = parseInt(route.params.lotId)
      var res = await supabase.from('liberation_documents').update({ pending_ar_service: null, updated_at: now }).eq('id', docId)
      if (res.error) { alert('Erreur AR : ' + res.error.message); return }
      await supabase.from('lot_events').insert({ lot_id: lotId, event_type: 'ar_document', description: doc.value.type_document.toUpperCase() + ' — accusé de réception', triggered_by: userId.value, created_at: now })
      await loadDoc()
    }

    var canAR = computed(function() {
      if (!doc.value || !doc.value.pending_ar_service) return false
      if (isClotSap.value || isMajDoc.value) return false
      return (doc.value.pending_ar_service === userService.value || userService.value === 'admin') && canPerform('accuser_reception_document')
    })

    // ── Action principale = clic sur l'étape active (façon OF/OC/AQL), retour = petit bouton ──
    var primaryLabel = function(){
      var d = doc.value, s = d.statut
      if (isCCL.value){ if(s==='non_emis') return 'Transmettre au DT'; if(s==='retour_emetteur') return 'Retransmettre au DT'; if(s==='emis') return 'Libérer le lot (DT)' }
      else if (isClotSap.value){ if(s==='emis') return 'Valider (Planification)'; if(s==='valide_planif') return 'Demander la clôture SAP'; if(s==='cloture_demandee') return 'Confirmer la clôture SAP' }
      else { if(s==='non_emis') return 'Émettre le document'; if(s==='retour_emetteur') return 'Rectifier et renvoyer'; if(s==='emis'||s==='verification_aq') return 'Vérifier et transmettre'; if(s==='approuve_aq') return 'Approuver (DT)' }
      return 'Action'
    }
    var stepCanPrimary = function(){
      var d = doc.value; if(!d) return false; var s = d.statut
      if (d.pending_ar_service && !isClotSap.value && !isMajDoc.value) return canAR.value
      if (isCCL.value){ if(s==='non_emis') return canEmit.value; if(s==='retour_emetteur') return canRectifier.value; if(s==='emis') return canApprove.value; return false }
      if (isClotSap.value){ if(s==='emis') return canVerify.value; if(s==='valide_planif') return canApprove.value; if(s==='cloture_demandee') return canConfirmClot.value; return false }
      if (s==='non_emis') return canEmit.value
      if (s==='retour_emetteur') return canRectifier.value
      if (s==='emis'||s==='verification_aq') return canVerify.value
      if (s==='approuve_aq') return canApprove.value
      return false
    }
    var stepClickable = function(n){ if (submitting.value) return false; return stepActionable(n) && stepCanPrimary() }
    // Garde anti-double-clic (RÈGLE N°26) : submitting posé DÈS l'entrée, avant tout await
    // (doAct/doAR écrivent avant loadDoc → fenêtre de double-soumission = doublon document_movements/lot_events)
    var stepClick = async function(n){
      if (submitting.value || !stepClickable(n)) return
      var d = doc.value, s = d.statut
      submitting.value = true
      try {
        if (d.pending_ar_service && !isClotSap.value && !isMajDoc.value) { await doAR(); return }
        if (isCCL.value){ if(s==='non_emis') await doAct('emettre'); else if(s==='retour_emetteur') await doAct('rectifier'); else if(s==='emis') await doAct('approuver_dt'); return }
        if (isClotSap.value){ if(s==='emis') await doAct('valider_planif'); else if(s==='valide_planif') await doAct('demander_cloture'); else if(s==='cloture_demandee') await doAct('cloturer'); return }
        if (s==='non_emis') await doAct('emettre')
        else if (s==='retour_emetteur') await doAct('rectifier')
        else if (s==='emis'||s==='verification_aq') await doAct('verifier_aq')
        else if (s==='approuve_aq') await doAct('approuver_dt')
      } finally { submitting.value = false }
    }
    var retourAct = computed(function(){
      var d = doc.value; if (!d) return null
      if (d.pending_ar_service && !isClotSap.value && !isMajDoc.value) return null
      var s = d.statut
      if (isCCL.value) return (s==='emis' && canRetourner.value) ? {dest:'aq', label:'Retourner à l\'AQ'} : null
      if (isClotSap.value || isMajDoc.value) return null
      if ((s==='emis'||s==='verification_aq') && canRetourner.value) return {dest:'emetteur', label:'Retourner à l\'émetteur'}
      if (s==='approuve_aq' && canRetourner.value) return {dest:'aq', label:'Retourner à l\'AQ'}
      return null
    })

    var loadDoc = async function() {
      var res = await supabase.from('liberation_documents').select('*').eq('id', route.params.docId).single()
      doc.value = res.data
      if (!lotNum.value) {
        var lotR = await supabase.from('lots').select('numero_lot, product_id').eq('id', route.params.lotId).single()
        if (lotR.data) {
          lotNum.value = lotR.data.numero_lot
          if (lotR.data.product_id) { var pR = await supabase.from('products').select('description').eq('id', lotR.data.product_id).single(); prodDesc.value = pR.data ? pR.data.description : '' }
        }
      }
      var mvtRes = await supabase.from('document_movements').select('*, profiles(prenom,nom)').eq('document_id', route.params.docId).order('performed_at')
      movements.value = (mvtRes.data||[]).map(function(m) { return { action: m.action, from_service: m.from_service, to_service: m.to_service, motif_retour: m.motif_retour, user: m.profiles ? m.profiles.prenom + ' ' + m.profiles.nom : '', performed_at: m.performed_at } })
    }

    onMounted(async function() {
      var userRes = await supabase.auth.getUser()
      userId.value = userRes.data.user.id
      var profileRes = await supabase.from('profiles').select('service').eq('id', userRes.data.user.id).single()
      if (profileRes.data) { userService.value = profileRes.data.service; await loadPermissions(profileRes.data.service) }
      await loadDoc()
    })
    // Naviguer directement vers un autre document sans démonter le composant → recharger
    watch(function(){ return route.params.docId }, function(nv, ov){ if (nv && nv !== ov) loadDoc() })

    return { doc, movements, showRetour, motif, retourDest, userService, typeLabels, actionLabelsMap, statusLabel, fmtDt, dotClass, prepareRetour, doAct, doRetour, doSetApplicable, doAR, canAR, canEmit, canVerify, canApprove, canConfirmClot, canRetourner, canRectifier, isClotSap, isMajDoc, isCCL,
      shortType, typeFull, lotNum, prodDesc, submitting, steps, doneCount, stepIndClass, stepDsClass, stepActionable, stepStatus, stepClickable, stepClick, retourAct, goBack }
  }
}
</script>
<style scoped>
.bc{font-size:12px;color:#7c3aed;cursor:pointer;margin-bottom:8px}
.lh{display:flex;align-items:flex-start;justify-content:space-between;padding-bottom:10px;border-bottom:1px solid #e5e7eb;flex-wrap:wrap;gap:10px}
.lh-info{display:flex;flex-direction:column;gap:4px;min-width:0}
.lh-type{font-size:17px;line-height:1.25}.lt-short{font-weight:700}.lt-full{font-size:13px;color:#999;font-weight:400}
.lh-lot{font-size:13px;display:flex;align-items:baseline;gap:8px;flex-wrap:wrap}.ll-num{font-family:'SF Mono',monospace;font-weight:600;font-size:15px}.ll-prod{color:#999}
.lh-right{flex-shrink:0}
.ttl{font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:1px;color:#7c3aed;background:#f5f3ff;border:1px solid #ede9fe;padding:4px 12px;border-radius:3px;white-space:nowrap}
.loading{text-align:center;padding:60px;color:#999}
.detail-reloading{font-size:11px;color:#999;padding:4px 0 6px;letter-spacing:.3px;animation:spin-txt 1s linear infinite}
@keyframes spin-txt{0%{opacity:1}50%{opacity:.4}100%{opacity:1}}
.section{margin-top:16px}.sh{display:flex;justify-content:space-between;align-items:center;font-size:10px;font-weight:500;text-transform:uppercase;letter-spacing:1px;color:#999;padding-bottom:6px;border-bottom:1px solid #e8e8e8}
.dc{font-family:'SF Mono',monospace;color:#BA7517}
.dg{display:grid;grid-template-columns:1fr 1fr;border:1px solid #e8e8e8}
.dg-1{grid-template-columns:1fr}
.di{padding:10px 12px;border-right:1px solid #e8e8e8;border-bottom:1px solid #e8e8e8;display:flex;gap:10px}.dg-1 .di{border-right:none}.di:last-child{border-bottom:none}
.di-act{cursor:pointer}.di-act:hover{background:#f5f3ff}.di-act .ds{color:#7c3aed;font-weight:500}
.dind{width:3px;min-height:36px;border-radius:1px;flex-shrink:0}.ind-wait{background:#e8e8e8}.ind-prog{background:#7c3aed}.ind-done{background:#1D9E75}.ind-ret{background:#E24B4A}
.di-body{flex:1;min-width:0}
.dn{font-size:13px;font-weight:500}.ds{font-size:11px;color:#999;margin-top:1px}.ds-ok{color:#1D9E75}.ds-ret{color:#E24B4A}
.di-svc{font-size:10px;color:#bbb;margin-top:2px}
.step-acts{display:flex;gap:8px;margin-top:8px;flex-wrap:wrap;align-items:center}
.btn-ret{font-size:11px;font-weight:600;padding:5px 12px;border-radius:3px;border:1px solid #E24B4A;background:transparent;color:#E24B4A;cursor:pointer}.btn-ret:hover{background:rgba(226,75,74,.08)}
.btn{font-size:11px;padding:6px 14px;border-radius:3px;border:none;cursor:pointer;font-weight:600;background:#7c3aed;color:#fff}.btn:hover{opacity:.9}
.br{background:#E24B4A}.bg{background:#1D9E75}.bc2{background:#ece9f7;color:#7c3aed}
.rb{border:1px solid #E24B4A;padding:14px;margin:12px 0;border-radius:3px}.rb label{font-size:12px;font-weight:500;display:block;margin-bottom:6px}.rb textarea{width:100%;border:1px solid #ddd;padding:8px;font-size:13px;box-sizing:border-box;resize:vertical;font-family:inherit;background:var(--th-input-bg,#fff);color:inherit}.ra{display:flex;gap:8px;margin-top:8px}
.na-bloc{display:flex;align-items:flex-start;gap:12px;padding:14px;border:1px solid #e8e8e8;border-radius:4px;margin:12px 0}
.na-info{opacity:.85}.na-icon{font-size:26px;flex-shrink:0}.na-msg{flex:1;font-size:13px;line-height:1.5;color:#999}.na-msg strong{color:inherit}
.na-bloc .btn{margin-top:10px;white-space:nowrap;flex-shrink:0}
.circ-hist{margin-top:10px;border:1px solid #e8e8e8;padding:8px 12px;display:flex;flex-direction:column;gap:2px}
.circ-hist-row{display:flex;align-items:center;gap:8px;font-size:11px;padding:4px 0;border-bottom:1px solid #f8f8f8}.circ-hist-row:last-child{border-bottom:none}
.circ-hist-dot{width:6px;height:6px;border-radius:50%;flex-shrink:0;background:#bbb}.dot-ok{background:#1D9E75}.dot-ko{background:#E24B4A}.dot-wait{background:#7c3aed}
.circ-hist-step{font-weight:500;flex:1}.hist-motif{font-weight:400;color:#E24B4A}
.circ-hist-who{color:#999}
.circ-hist-at{font-family:'SF Mono',monospace;font-size:10px;color:#bbb}
.em{text-align:center;padding:16px;color:#999;font-size:12px}
@media(max-width:768px){.dg{grid-template-columns:1fr}.na-bloc{flex-direction:column}.ra{flex-direction:column}.ra .btn{width:100%}}
</style>
