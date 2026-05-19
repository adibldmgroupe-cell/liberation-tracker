<template>
  <div v-if="doc">
    <div class="bc"><span @click="$router.push('/lots/'+$route.params.lotId)">← Retour au lot</span></div>
    <div class="ph"><span class="pt">{{typeLabels[doc.type_document]}}</span><span class="sp" :class="spClass">{{statusLabel}}</span></div>
    <div class="info"><div class="ic"><span class="il">Émetteur</span>{{doc.service_emetteur}}</div><div class="ic"><span class="il">Émis le</span><span class="mono">{{fmtDt(doc.emitted_at)}}</span></div><div class="ic"><span class="il">Approuvé le</span><span class="mono">{{fmtDt(doc.approved_at)}}</span></div></div>

    <div class="flow">
      <div class="flow-step" :class="flowClass(1)"><span class="fs-num">1</span><span class="fs-label">Émission</span></div>
      <div class="flow-arrow">→</div>
      <div class="flow-step" :class="flowClass(2)"><span class="fs-num">2</span><span class="fs-label">Vérif. AQ</span></div>
      <div class="flow-arrow">→</div>
      <div class="flow-step" :class="flowClass(3)"><span class="fs-num">3</span><span class="fs-label">Approbation DT</span></div>
    </div>

    <div class="actions" v-if="doc.is_applicable">
      <!-- ÉMETTEUR : émettre -->
      <button v-if="doc.statut==='non_emis' && canEmit" class="btn" @click="doAct('emettre')">Émettre le document</button>

      <!-- ÉMETTEUR : rectifier après retour -->
      <button v-if="doc.statut==='retour_emetteur' && canRectifier" class="btn" @click="doAct('rectifier')">Rectifier et renvoyer à l'AQ</button>

      <!-- AQ : vérifier et transmettre au DT -->
      <button v-if="(doc.statut==='emis' || doc.statut==='verification_aq') && canVerify" class="btn" @click="doAct('verifier_aq')">Vérifier et transmettre au DT</button>

      <!-- AQ : retourner à l'émetteur -->
      <button v-if="(doc.statut==='emis' || doc.statut==='verification_aq') && canRetourner" class="btn br" @click="prepareRetour('emetteur')">Retourner à l'émetteur</button>

      <!-- DT : approuver -->
      <button v-if="doc.statut==='approuve_aq' && canApprove" class="btn bg" @click="doAct('approuver_dt')">Approuver (DT)</button>

      <!-- DT : retourner à l'AQ -->
      <button v-if="doc.statut==='approuve_aq' && canRetourner" class="btn br" @click="prepareRetour('aq')">Retourner à l'AQ</button>
    </div>

    <div class="rb" v-if="showRetour">
      <label>Motif du retour ({{retourDest === 'emetteur' ? 'vers ' + doc.service_emetteur : 'vers AQ'}}) :</label>
      <textarea v-model="motif" rows="3" placeholder="Préciser le motif..."></textarea>
      <div class="ra">
        <button class="btn br" @click="doRetour">Confirmer le retour</button>
        <button class="btn bc2" @click="showRetour=false">Annuler</button>
      </div>
    </div>

    <div class="section">
      <div class="sh"><span>Historique des mouvements</span></div>
      <div class="tl" v-if="movements.length">
        <div class="ti" v-for="(m,i) in movements" :key="i">
          <div class="td" :class="dotClass(m.action)"></div>
          <div class="tln" v-if="i<movements.length-1"></div>
          <div class="tc">
            <div class="ta">{{actionLabelsMap[m.action]}}</div>
            <div class="tt" v-if="m.from_service || m.to_service">{{m.from_service || '?'}} → {{m.to_service || '?'}}</div>
            <div class="tm" v-if="m.motif_retour">Motif : {{m.motif_retour}}</div>
            <div class="tu"><span>{{m.user}}</span><span class="mono">{{fmtDt(m.performed_at)}}</span></div>
          </div>
        </div>
      </div>
      <div v-else class="em">Aucun mouvement</div>
    </div>
  </div>
</template>
<script>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../supabase'
import { loadPermissions, canPerform } from '../services/permissions'
import { createNotification } from '../services/notifications'
export default {
  setup() {
    var route = useRoute()
    var doc = ref(null), movements = ref([]), showRetour = ref(false), motif = ref(''), userId = ref(null), retourDest = ref('')
    var typeLabels = { if:'IF (Instruction de fabrication)', ic:'IC (Instruction de conditionnement)', da_pc:'DA Physico-chimie', da_micro:'DA Microbiologie', rvp:'RVP', deviation:'Déviation', analyse_risque:'Analyse de risque', autorisation_partenaire:'Autorisation partenaire', autre:'Autre' }
    var actionLabelsMap = { emission:'Émission', transmission:'Transmission', reception:'Réception', retour:'Retour pour rectification', rectification:'Rectification et renvoi', approbation:'Approbation' }
    var statusMap = { non_emis:'Non émis', emis:'Émis — en attente AQ', verification_aq:'En cours de vérification AQ', retour_emetteur:'Retourné à l\'émetteur', rectification:'En cours de rectification', approuve_aq:'Vérifié AQ — en attente DT', approbation_dt:'En cours d\'approbation DT', approuve_dt:'Approuvé DT' }
    var statusLabel = computed(function() { return statusMap[doc.value ? doc.value.statut : ''] || '' })
    var spClass = computed(function() {
      var s = doc.value ? doc.value.statut : ''
      if (s === 'approuve_dt') return 'sp-ok'
      if (s === 'retour_emetteur') return 'sp-ret'
      if (s === 'non_emis') return 'sp-wait'
      if (s === 'approuve_aq') return 'sp-dt'
      return 'sp-prog'
    })

    var flowClass = function(step) {
      var s = doc.value ? doc.value.statut : ''
      if (step === 1) {
        if (s === 'non_emis') return 'fs-active'
        if (s === 'retour_emetteur') return 'fs-ret'
        return 'fs-done'
      }
      if (step === 2) {
        if (s === 'emis' || s === 'verification_aq') return 'fs-active'
        if (s === 'approuve_aq' || s === 'approbation_dt' || s === 'approuve_dt') return 'fs-done'
        return 'fs-wait'
      }
      if (step === 3) {
        if (s === 'approuve_aq' || s === 'approbation_dt') return 'fs-active'
        if (s === 'approuve_dt') return 'fs-done'
        return 'fs-wait'
      }
      return 'fs-wait'
    }

    var fmtDt = function(d) { return d ? new Date(d).toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}) : '—' }
    // Permissions selon type de document courant
    var canEmit = computed(function(){ return doc.value && canPerform('emettre_'+doc.value.type_document) })
    var canVerify = computed(function(){ return doc.value && canPerform('verifier_'+doc.value.type_document) })
    var canApprove = computed(function(){ return doc.value && canPerform('approuver_'+doc.value.type_document) })
    var canRetourner = computed(function(){ return canPerform('retourner_document') })
    var canRectifier = computed(function(){ return canPerform('rectifier_document') })
    var dotClass = function(a) { return a === 'retour' ? 'dot-ret' : a === 'approbation' ? 'dot-ok' : 'dot-prog' }

    var prepareRetour = function(dest) {
      retourDest.value = dest
      showRetour.value = true
    }

    var doAct = async function(action) {
      var now = new Date().toISOString()
      var docId = doc.value.id
      var lotId = parseInt(route.params.lotId)

      if (action === 'emettre') {
        await supabase.from('liberation_documents').update({ statut: 'emis', emitted_at: now, emitted_by: userId.value, updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'emission', from_service: doc.value.service_emetteur, to_service: 'aq', performed_by: userId.value, performed_at: now })
      } else if (action === 'verifier_aq') {
        await supabase.from('liberation_documents').update({ statut: 'approuve_aq', updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'approbation', from_service: 'aq', to_service: 'dt', performed_by: userId.value, performed_at: now })
      } else if (action === 'rectifier') {
        await supabase.from('liberation_documents').update({ statut: 'verification_aq', updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'rectification', from_service: doc.value.service_emetteur, to_service: 'aq', performed_by: userId.value, performed_at: now })
      } else if (action === 'approuver_dt') {
        await supabase.from('liberation_documents').update({ statut: 'approuve_dt', approved_at: now, updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'approbation', from_service: 'dt', performed_by: userId.value, performed_at: now })
        var fieldMap = { 'if': 'if_approved', ic: 'ic_approved', da_pc: 'da_pc_approved', da_micro: 'da_micro_approved' }
        var field = fieldMap[doc.value.type_document]
        if (field) { await supabase.from('liberation_dossiers').update({ [field]: true, updated_at: now }).eq('lot_id', lotId) }
      }

      await supabase.from('lot_events').insert({ lot_id: lotId, event_type: 'document_' + action, description: doc.value.type_document.toUpperCase() + ' — ' + action, triggered_by: userId.value, created_at: now })

      // Notifications
      var lotRes = await supabase.from('lots').select('numero_lot').eq('id', lotId).single()
      var lotNum = lotRes.data ? lotRes.data.numero_lot : ''
      var typeLabel = doc.value.type_document.toUpperCase().replace('_', ' ')
      if (action === 'emettre') {
        await createNotification('aq', lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + typeLabel + ' émis, en attente de vérification', 'document_transmis')
      } else if (action === 'verifier_aq') {
        await createNotification('dt', lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + typeLabel + ' vérifié AQ, en attente d\'approbation DT', 'document_transmis')
      } else if (action === 'rectifier') {
        await createNotification('aq', lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + typeLabel + ' rectifié, en attente de vérification', 'document_transmis')
      } else if (action === 'approuver_dt') {
        await createNotification('aq', lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + typeLabel + ' approuvé par le DT', 'document_approuve')
        var svcMap = { fabrication: 'fabrication', conditionnement: 'conditionnement', lcq: 'lcq' }
        if (svcMap[doc.value.service_emetteur]) {
          await createNotification(svcMap[doc.value.service_emetteur], lotId, doc.value.id, 'Lot ' + lotNum + ' — ' + typeLabel + ' approuvé par le DT', 'document_approuve')
        }
      }

      loadDoc()
    }

    var doRetour = async function() {
      var now = new Date().toISOString()
      var docId = doc.value.id
      var lotId = parseInt(route.params.lotId)

      if (retourDest.value === 'emetteur') {
        // AQ retourne à l'émetteur
        await supabase.from('liberation_documents').update({ statut: 'retour_emetteur', updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'retour', from_service: 'aq', to_service: doc.value.service_emetteur, motif_retour: motif.value, performed_by: userId.value, performed_at: now })
      } else if (retourDest.value === 'aq') {
        // DT retourne à l'AQ
        await supabase.from('liberation_documents').update({ statut: 'verification_aq', updated_at: now }).eq('id', docId)
        await supabase.from('document_movements').insert({ document_id: docId, action: 'retour', from_service: 'dt', to_service: 'aq', motif_retour: motif.value, performed_by: userId.value, performed_at: now })
      }

      await supabase.from('lot_events').insert({ lot_id: lotId, event_type: 'document_retour', description: doc.value.type_document.toUpperCase() + ' — retourné vers ' + retourDest.value, triggered_by: userId.value, created_at: now })

      // Notifications
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
      loadDoc()
    }

    var loadDoc = async function() {
      var res = await supabase.from('liberation_documents').select('*').eq('id', route.params.docId).single()
      doc.value = res.data
      var mvtRes = await supabase.from('document_movements').select('*, profiles(prenom,nom)').eq('document_id', route.params.docId).order('performed_at')
      movements.value = (mvtRes.data||[]).map(function(m) { return { action: m.action, from_service: m.from_service, to_service: m.to_service, motif_retour: m.motif_retour, user: m.profiles ? m.profiles.prenom + ' ' + m.profiles.nom : '', performed_at: m.performed_at } })
    }

    onMounted(async function() {
      var userRes = await supabase.auth.getUser()
      userId.value = userRes.data.user.id
      var profileRes = await supabase.from('profiles').select('service').eq('id', userRes.data.user.id).single()
      if (profileRes.data) await loadPermissions(profileRes.data.service)
      loadDoc()
    })

    return { doc, movements, showRetour, motif, retourDest, typeLabels, actionLabelsMap, statusLabel, spClass, flowClass, fmtDt, dotClass, prepareRetour, doAct, doRetour, canEmit, canVerify, canApprove, canRetourner, canRectifier }
  }
}
</script>
<style scoped>
.bc{font-size:12px;color:#185FA5;cursor:pointer;margin-bottom:8px}
.ph{display:flex;justify-content:space-between;align-items:baseline;padding-bottom:10px;border-bottom:2px solid #0a0a0a;flex-wrap:wrap;gap:6px}.pt{font-size:16px;font-weight:500}
.sp{font-size:11px;padding:3px 10px;border-radius:2px;font-weight:500}
.sp-ok{background:#EAF3DE;color:#3B6D11}.sp-ret{background:#FCEBEB;color:#A32D2D}.sp-wait{background:#f5f5f5;color:#999}.sp-prog{background:#E6F1FB;color:#0C447C}.sp-dt{background:#FAEEDA;color:#854F0B}
.info{display:grid;grid-template-columns:repeat(3,1fr);border:1px solid #e8e8e8;margin:12px 0;font-size:13px}
.ic{padding:10px;border-right:1px solid #e8e8e8}.ic:last-child{border-right:none}.il{display:block;font-size:10px;color:#999;text-transform:uppercase;margin-bottom:2px}.mono{font-family:'SF Mono',monospace;font-size:12px}
.flow{display:flex;align-items:center;gap:0;margin:16px 0;border:1px solid #e8e8e8;border-radius:2px;overflow:hidden}
.flow-step{flex:1;padding:10px 12px;text-align:center;display:flex;align-items:center;justify-content:center;gap:6px;min-height:44px}
.flow-arrow{padding:0 4px;color:#ccc;font-size:14px}
.fs-num{width:20px;height:20px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-size:11px;font-weight:500;flex-shrink:0}
.fs-label{font-size:12px}
.fs-done{background:#EAF3DE}.fs-done .fs-num{background:#1D9E75;color:#fff}.fs-done .fs-label{color:#3B6D11}
.fs-active{background:#E6F1FB}.fs-active .fs-num{background:#185FA5;color:#fff}.fs-active .fs-label{color:#0C447C;font-weight:500}
.fs-wait{background:#fafafa}.fs-wait .fs-num{background:#e8e8e8;color:#999}.fs-wait .fs-label{color:#999}
.fs-ret{background:#FCEBEB}.fs-ret .fs-num{background:#E24B4A;color:#fff}.fs-ret .fs-label{color:#A32D2D}
.actions{display:flex;gap:8px;margin:12px 0;flex-wrap:wrap}.btn{font-size:12px;padding:8px 18px;border-radius:2px;border:none;cursor:pointer;font-weight:500;background:#185FA5;color:#fff;min-height:40px}.btn:hover{opacity:.9}.br{background:#E24B4A}.bg{background:#1D9E75}.bc2{background:#f5f5f5;color:#666}
.rb{border:1px solid #E24B4A;padding:14px;margin:12px 0;border-radius:2px}.rb label{font-size:12px;font-weight:500;display:block;margin-bottom:6px}.rb textarea{width:100%;border:1px solid #ddd;padding:8px;font-size:13px;box-sizing:border-box;resize:vertical;font-family:inherit}.ra{display:flex;gap:8px;margin-top:8px}
.section{margin-top:20px}.sh{font-size:10px;font-weight:500;text-transform:uppercase;letter-spacing:1px;color:#999;padding-bottom:6px;border-bottom:1px solid #e8e8e8}
.tl{padding:12px 0 0 20px;position:relative}.ti{position:relative;padding-bottom:20px;padding-left:16px}.ti:last-child{padding-bottom:0}
.td{width:10px;height:10px;border-radius:50%;position:absolute;left:-5px;top:4px}.dot-ok{background:#1D9E75}.dot-ret{background:#E24B4A}.dot-prog{background:#185FA5}
.tln{position:absolute;left:0;top:18px;bottom:0;width:1px;background:#e8e8e8}
.ta{font-size:14px;font-weight:500}.tt{font-size:12px;color:#666}.tm{font-size:12px;color:#E24B4A;margin-top:2px}
.tu{display:flex;gap:12px;margin-top:4px;font-size:11px;color:#999;flex-wrap:wrap}
.em{text-align:center;padding:16px;color:#999;font-size:12px}
@media(max-width:768px){
  .info{grid-template-columns:1fr 1fr}
  .ic:nth-child(2){border-right:none}
  .ic:nth-child(3){border-top:1px solid #e8e8e8;grid-column:span 2}
  .flow-step{flex-direction:column;gap:4px;padding:8px 6px}
  .fs-label{font-size:10px}
  .flow-arrow{font-size:10px;padding:0 2px}
  .actions{flex-direction:column;gap:6px}
  .btn{width:100%;padding:12px 18px;min-height:44px;font-size:13px;text-align:center}
  .ra{flex-direction:column}
  .ra .btn{width:100%}
  .pt{font-size:14px}
}
@media(max-width:480px){
  .info{grid-template-columns:1fr}
  .ic{border-right:1px solid #e8e8e8;border-top:1px solid #e8e8e8}
  .ic:first-child{border-top:none}
  .ic:nth-child(2){border-right:1px solid #e8e8e8}
  .ic:nth-child(3){grid-column:unset}
  .tl{padding-left:12px}
  .ta{font-size:13px}
}
</style>
