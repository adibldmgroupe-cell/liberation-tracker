<template>
  <div>
    <div class="ph">
      <span class="pt">ACTIONS EN MASSE</span>
      <span class="pc" v-if="selected.length">{{ selected.length }} lot(s) sélectionné(s)</span>
    </div>

    <div class="toolbar">
      <div class="tool-left">
        <select v-model="actionType" class="sel">
          <option value="">— Choisir une action —</option>
          <optgroup label="Circuit OF">
            <option value="of_planification">OF — Mise en circuit</option>
            <option value="of_stock">OF — Validation Stock</option>
            <option value="of_aq">OF — Validation AQ</option>
            <option value="of_dt">OF — Autorisation DT</option>
            <option value="of_aq_dap">OF — Remise AQ DAP</option>
            <option value="of_production">OF — Accusé réception</option>
          </optgroup>
          <optgroup label="Circuit OC">
            <option value="oc_planification">OC — Mise en circuit</option>
            <option value="oc_stock">OC — Validation Stock</option>
            <option value="oc_aq">OC — Validation AQ</option>
            <option value="oc_dt">OC — Autorisation DT</option>
            <option value="oc_aq_dap">OC — Remise AQ DAP</option>
            <option value="oc_production">OC — Accusé réception</option>
          </optgroup>
          <optgroup label="Documents — Émission">
            <option value="doc_if">IF — Émettre</option>
            <option value="doc_ic">IC — Émettre</option>
            <option value="doc_da_pc">DA Physico — Émettre</option>
            <option value="doc_da_micro">DA Micro — Émettre</option>
          </optgroup>
          <optgroup label="Documents — Vérification AQ → DT">
            <option value="doc_if_verifier">IF — Vérifier AQ et transmettre au DT</option>
            <option value="doc_ic_verifier">IC — Vérifier AQ et transmettre au DT</option>
            <option value="doc_da_pc_verifier">DA Physico — Vérifier AQ et transmettre au DT</option>
            <option value="doc_da_micro_verifier">DA Micro — Vérifier AQ et transmettre au DT</option>
          </optgroup>
          <optgroup label="Documents — Approbation DT">
            <option value="doc_if_approuver">IF — Approuver DT</option>
            <option value="doc_ic_approuver">IC — Approuver DT</option>
            <option value="doc_da_pc_approuver">DA Physico — Approuver DT</option>
            <option value="doc_da_micro_approuver">DA Micro — Approuver DT</option>
          </optgroup>
          <optgroup label="Documents — Retour">
            <option value="doc_if_retour_emetteur">IF — Retourner à l'émetteur</option>
            <option value="doc_ic_retour_emetteur">IC — Retourner à l'émetteur</option>
            <option value="doc_da_pc_retour_emetteur">DA Physico — Retourner à l'émetteur</option>
            <option value="doc_da_micro_retour_emetteur">DA Micro — Retourner à l'émetteur</option>
            <option value="doc_if_retour_aq">IF — DT retourne à l'AQ</option>
            <option value="doc_ic_retour_aq">IC — DT retourne à l'AQ</option>
            <option value="doc_da_pc_retour_aq">DA Physico — DT retourne à l'AQ</option>
            <option value="doc_da_micro_retour_aq">DA Micro — DT retourne à l'AQ</option>
          </optgroup>
        </select>
        <button class="btn-exec" :disabled="!canExecute" @click="showConfirm = true">
          Exécuter ({{ selected.length }})
        </button>
      </div>
      <div class="tool-right">
        <input v-model="search" placeholder="Filtrer les lots..." class="input-filter" />
        <select v-model="filterStatut" class="sel-sm">
          <option value="">Tous statuts</option>
          <option value="vide">Sans statut</option>
          <option value="quarantaine">Quarantaine</option>
          <option value="sous_investigation">Investigation</option>
          <option value="accepte">Accepté</option>
        </select>
      </div>
    </div>

    <div v-if="loading" class="empty">Chargement...</div>
    <div v-else-if="!filteredLots.length" class="empty">Aucun lot trouvé</div>
    <div v-else class="table-wrap">
      <table class="tb">
        <thead><tr>
          <th class="th-check"><input type="checkbox" @change="toggleAll" :checked="allChecked" /></th>
          <th>N° Lot</th><th>Produit</th><th>Statut SAP</th><th>OF</th><th>OC</th><th>IF</th><th>IC</th><th>DA PC</th><th>DA Micro</th>
        </tr></thead>
        <tbody>
          <tr v-for="l in filteredLots" :key="l.id" :class="{ 'row-selected': isSelected(l.id) }" @click="toggleLot(l.id)">
            <td class="td-check"><input type="checkbox" :checked="isSelected(l.id)" @click.stop="toggleLot(l.id)" /></td>
            <td class="mono bold">{{ l.numero_lot }}</td>
            <td class="td-prod">{{ l.prod_desc }}<span class="code">{{ l.prod_code }}</span></td>
            <td><span class="sp" :class="'s-'+l.statut_sap">{{ statusLabels[l.statut_sap] }}</span></td>
            <td><span class="pip" :class="l.of_done ? 'pip-done' : 'pip-prog'"></span> <span class="pip-label">{{ l.of_label }}</span></td>
            <td><span class="pip" :class="l.oc_done ? 'pip-done' : 'pip-prog'"></span> <span class="pip-label">{{ l.oc_label }}</span></td>
            <td><span class="doc-pip" :class="l.if_class">{{ l.if_label }}</span></td>
            <td><span class="doc-pip" :class="l.ic_class">{{ l.ic_label }}</span></td>
            <td><span class="doc-pip" :class="l.dapc_class">{{ l.dapc_label }}</span></td>
            <td><span class="doc-pip" :class="l.damicro_class">{{ l.damicro_label }}</span></td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="modal-overlay" v-if="showConfirm" @click="showConfirm = false">
      <div class="modal" @click.stop>
        <div class="modal-title">Confirmer l'action en masse</div>
        <div class="modal-body">
          <div class="modal-line"><span class="ml">Action</span><span>{{ actionLabel }}</span></div>
          <div class="modal-line"><span class="ml">Lots concernés</span><span class="mono">{{ selected.length }}</span></div>
          <div class="modal-lots">
            <span v-for="id in selected.slice(0, 20)" :key="id" class="lot-chip">{{ getLotNum(id) }}</span>
            <span v-if="selected.length > 20" class="lot-chip more">+{{ selected.length - 20 }} autres</span>
          </div>
        </div>
        <div class="modal-actions">
          <button class="btn-confirm" @click="executeAction" :disabled="executing">{{ executing ? 'En cours... ' + progress + '/' + selected.length : 'Confirmer' }}</button>
          <button class="btn-cancel" @click="showConfirm = false">Annuler</button>
        </div>
      </div>
    </div>

    <div class="result" v-if="execResult">
      <div class="rh">Exécution terminée</div>
      <div class="rg">
        <div class="rc"><div class="rv" style="color:#1D9E75">{{ execResult.ok }}</div><div class="rl">Réussis</div></div>
        <div class="rc"><div class="rv" style="color:#E24B4A">{{ execResult.fail }}</div><div class="rl">Échoués</div></div>
      </div>
      <div class="errors-list" v-if="execResult.errors.length">
        <div v-for="(e, i) in execResult.errors" :key="i" class="err-line">{{ e }}</div>
      </div>
    </div>
  </div>
</template>
<script>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
export default {
  setup() {
    var lots = ref([])
    var selected = ref([])
    var actionType = ref('')
    var search = ref('')
    var filterStatut = ref('')
    var loading = ref(true)
    var showConfirm = ref(false)
    var executing = ref(false)
    var progress = ref(0)
    var execResult = ref(null)

    var statusLabels = { vide: 'En prod.', quarantaine: 'Quarantaine', sous_investigation: 'Investigation', accepte: 'Accepté' }
    var etapeLabels = { planification: 'Planif.', stock: 'Stock', aq: 'AQ', dt: 'DT', aq_dap: 'AQ DAP', production: 'Prod.' }
    var docStatutLabels = { non_emis: 'Non émis', emis: 'Émis', verification_aq: 'Vérif AQ', retour_emetteur: 'Retourné', rectification: 'Rectif.', approuve_aq: 'Appr. AQ', approbation_dt: 'Appr. DT', approuve_dt: 'Approuvé' }

    var actionLabels = {
      of_planification: 'OF — Mise en circuit', of_stock: 'OF — Validation Stock', of_aq: 'OF — Validation AQ',
      of_dt: 'OF — Autorisation DT', of_aq_dap: 'OF — Remise AQ DAP', of_production: 'OF — Accusé réception',
      oc_planification: 'OC — Mise en circuit', oc_stock: 'OC — Validation Stock', oc_aq: 'OC — Validation AQ',
      oc_dt: 'OC — Autorisation DT', oc_aq_dap: 'OC — Remise AQ DAP', oc_production: 'OC — Accusé réception',
      doc_if: 'IF — Émettre', doc_ic: 'IC — Émettre', doc_da_pc: 'DA Physico — Émettre', doc_da_micro: 'DA Micro — Émettre',
      doc_if_verifier: 'IF — Vérifier AQ → DT', doc_ic_verifier: 'IC — Vérifier AQ → DT',
      doc_da_pc_verifier: 'DA Physico — Vérifier AQ → DT', doc_da_micro_verifier: 'DA Micro — Vérifier AQ → DT',
      doc_if_approuver: 'IF — Approuver DT', doc_ic_approuver: 'IC — Approuver DT',
      doc_da_pc_approuver: 'DA Physico — Approuver DT', doc_da_micro_approuver: 'DA Micro — Approuver DT',
      doc_if_retour_emetteur: 'IF — Retour émetteur', doc_ic_retour_emetteur: 'IC — Retour émetteur',
      doc_da_pc_retour_emetteur: 'DA Physico — Retour émetteur', doc_da_micro_retour_emetteur: 'DA Micro — Retour émetteur',
      doc_if_retour_aq: 'IF — DT retourne à AQ', doc_ic_retour_aq: 'IC — DT retourne à AQ',
      doc_da_pc_retour_aq: 'DA Physico — DT retourne à AQ', doc_da_micro_retour_aq: 'DA Micro — DT retourne à AQ',
    }

    var actionLabel = computed(function () { return actionLabels[actionType.value] || '' })
    var canExecute = computed(function () { return selected.value.length > 0 && actionType.value !== '' })

    var getDocInfo = function (docs, type) {
      var d = null
      if (docs) { for (var i = 0; i < docs.length; i++) { if (docs[i].type_document === type) { d = docs[i]; break } } }
      if (!d) return { label: '—', cls: 'dc-na' }
      if (!d.is_applicable) return { label: 'N/A', cls: 'dc-na' }
      var label = docStatutLabels[d.statut] || d.statut
      var cls = 'dc-wait'
      if (d.statut === 'approuve_dt') cls = 'dc-ok'
      else if (d.statut === 'retour_emetteur') cls = 'dc-ret'
      else if (d.statut !== 'non_emis') cls = 'dc-prog'
      return { label: label, cls: cls }
    }

    var getOfOcLabel = function (order, statutSap) {
      var inStock = statutSap === 'quarantaine' || statutSap === 'sous_investigation' || statutSap === 'accepte'
      if (inStock) return { label: 'Terminé', done: true }
      if (!order) return { label: '—', done: false }
      if (order.statut === 'termine') return { label: 'Terminé', done: true }
      return { label: etapeLabels[order.etape_circuit] || order.etape_circuit || '—', done: false }
    }

    var loadLots = async function () {
      loading.value = true
      var res = await supabase.from('lots').select('*, products(code_article, description), orders_of(id, statut, etape_circuit), orders_oc(id, statut, etape_circuit), liberation_documents(id, type_document, statut, is_applicable)')
        .order('numero_lot', { ascending: false }).limit(500)

      lots.value = (res.data || []).map(function (l) {
        var docs = l.liberation_documents || []
        var of = Array.isArray(l.orders_of) ? l.orders_of[0] : l.orders_of
        var oc = Array.isArray(l.orders_oc) ? l.orders_oc[0] : l.orders_oc
        var ofInfo = getOfOcLabel(of, l.statut_sap)
        var ocInfo = getOfOcLabel(oc, l.statut_sap)
        var ifInfo = getDocInfo(docs, 'if')
        var icInfo = getDocInfo(docs, 'ic')
        var dapcInfo = getDocInfo(docs, 'da_pc')
        var damicroInfo = getDocInfo(docs, 'da_micro')
        return {
          id: l.id, numero_lot: l.numero_lot, statut_sap: l.statut_sap,
          prod_desc: l.products ? l.products.description : '', prod_code: l.products ? l.products.code_article : '',
          of_id: of ? of.id : null, oc_id: oc ? oc.id : null,
          of_label: ofInfo.label, of_done: ofInfo.done, of_etape: of ? of.etape_circuit : '',
          oc_label: ocInfo.label, oc_done: ocInfo.done, oc_etape: oc ? oc.etape_circuit : '',
          if_label: ifInfo.label, if_class: ifInfo.cls,
          ic_label: icInfo.label, ic_class: icInfo.cls,
          dapc_label: dapcInfo.label, dapc_class: dapcInfo.cls,
          damicro_label: damicroInfo.label, damicro_class: damicroInfo.cls,
          docs: docs,
        }
      })
      loading.value = false
    }

    var filteredLots = computed(function () {
      return lots.value.filter(function (l) {
        if (filterStatut.value && l.statut_sap !== filterStatut.value) return false
        if (search.value) {
          var q = search.value.toLowerCase()
          var match = l.numero_lot.toLowerCase().includes(q) || l.prod_desc.toLowerCase().includes(q) || l.prod_code.toLowerCase().includes(q)
          if (!match) return false
        }
        return true
      })
    })

    var isSelected = function (id) { return selected.value.indexOf(id) >= 0 }
    var toggleLot = function (id) {
      var idx = selected.value.indexOf(id)
      if (idx >= 0) selected.value.splice(idx, 1)
      else selected.value.push(id)
    }
    var allChecked = computed(function () {
      return filteredLots.value.length > 0 && filteredLots.value.every(function (l) { return isSelected(l.id) })
    })
    var toggleAll = function () {
      if (allChecked.value) {
        selected.value = []
      } else {
        selected.value = filteredLots.value.map(function (l) { return l.id })
      }
    }
    var getLotNum = function (id) {
      var l = lots.value.find(function (x) { return x.id === id })
      return l ? l.numero_lot : id
    }

    var executeAction = async function () {
      executing.value = true
      progress.value = 0
      var result = { ok: 0, fail: 0, errors: [] }
      var now = new Date().toISOString()
      var userRes = await supabase.auth.getUser()
      var userId = userRes.data.user.id

      for (var i = 0; i < selected.value.length; i++) {
        var lotId = selected.value[i]
        var lot = lots.value.find(function (x) { return x.id === lotId })
        if (!lot) { result.fail++; continue }

        try {
          var action = actionType.value

          if (action.startsWith('of_') || action.startsWith('oc_')) {
            var parts = action.split('_')
            var orderType = parts[0]
            var etape = parts.slice(1).join('_')
            var orderId = orderType === 'of' ? lot.of_id : lot.oc_id
            if (!orderId) { result.errors.push(lot.numero_lot + ': pas d\'ordre ' + orderType.toUpperCase()); result.fail++; continue }

            var flow = ['planification', 'stock', 'aq', 'dt', 'aq_dap', 'production']
            var idx2 = flow.indexOf(etape)
            var nextEtape = idx2 < flow.length - 1 ? flow[idx2 + 1] : null
            var table = orderType === 'of' ? 'orders_of' : 'orders_oc'

            await supabase.from('order_validations').insert({
              order_type: orderType, order_id: orderId, etape: etape,
              action: 'valide', validated_by: userId, validated_at: now
            })
            await supabase.from(table).update({
              statut: nextEtape ? 'en_circuit' : 'termine',
              etape_circuit: nextEtape || etape, updated_at: now
            }).eq('id', orderId)

            var typeLabel = orderType.toUpperCase()
            var nextLabel = nextEtape ? (etapeLabels[nextEtape] || nextEtape) : 'Terminé'
            await supabase.from('lots').update({
              statut_operationnel: typeLabel + ' — ' + nextLabel, updated_at: now
            }).eq('id', lotId)

            await supabase.from('lot_events').insert({
              lot_id: lotId, event_type: 'validation_' + orderType,
              description: 'Circuit ' + typeLabel + ' — ' + etape + ' validé (masse)',
              triggered_by: userId, created_at: now
            })

            result.ok++
          } else if (action.startsWith('doc_')) {
            var docAction = action.replace('doc_', '')
            var isApprouver = docAction.endsWith('_approuver')
            var isVerifier = docAction.endsWith('_verifier')
            var isRetourEmetteur = docAction.endsWith('_retour_emetteur')
            var isRetourAQ = docAction.endsWith('_retour_aq')
            var docType = docAction
            if (isApprouver) docType = docAction.replace('_approuver', '')
            if (isVerifier) docType = docAction.replace('_verifier', '')
            if (isRetourEmetteur) docType = docAction.replace('_retour_emetteur', '')
            if (isRetourAQ) docType = docAction.replace('_retour_aq', '')

            var doc = null
            if (lot.docs) {
              for (var j = 0; j < lot.docs.length; j++) {
                if (lot.docs[j].type_document === docType) { doc = lot.docs[j]; break }
              }
            }
            if (!doc) { result.errors.push(lot.numero_lot + ': document ' + docType + ' non trouvé'); result.fail++; continue }

            if (isApprouver) {
              await supabase.from('liberation_documents').update({
                statut: 'approuve_dt', approved_at: now, updated_at: now
              }).eq('id', doc.id)

              var fieldMap = { 'if': 'if_approved', ic: 'ic_approved', da_pc: 'da_pc_approved', da_micro: 'da_micro_approved' }
              var field = fieldMap[docType]
              if (field) {
                await supabase.from('liberation_dossiers').update({ [field]: true, updated_at: now }).eq('lot_id', lotId)
              }

              await supabase.from('document_movements').insert({
                document_id: doc.id, action: 'approbation', from_service: 'dt',
                performed_by: userId, performed_at: now
              })
            } else if (isVerifier) {
              await supabase.from('liberation_documents').update({
                statut: 'approuve_aq', updated_at: now
              }).eq('id', doc.id)

              await supabase.from('document_movements').insert({
                document_id: doc.id, action: 'approbation', from_service: 'aq', to_service: 'dt',
                performed_by: userId, performed_at: now
              })
            } else if (isRetourEmetteur) {
              var serviceMap2 = { 'if': 'fabrication', ic: 'conditionnement', da_pc: 'lcq', da_micro: 'lcq' }
              await supabase.from('liberation_documents').update({
                statut: 'retour_emetteur', updated_at: now
              }).eq('id', doc.id)

              await supabase.from('document_movements').insert({
                document_id: doc.id, action: 'retour', from_service: 'aq', to_service: serviceMap2[docType] || '',
                motif_retour: 'Retour en masse', performed_by: userId, performed_at: now
              })
            } else if (isRetourAQ) {
              await supabase.from('liberation_documents').update({
                statut: 'verification_aq', updated_at: now
              }).eq('id', doc.id)

              await supabase.from('document_movements').insert({
                document_id: doc.id, action: 'retour', from_service: 'dt', to_service: 'aq',
                motif_retour: 'Retour DT en masse', performed_by: userId, performed_at: now
              })
            } else {
              if (docType === 'da_micro') {
                await supabase.from('liberation_documents').update({
                  statut: 'emis', emitted_at: now, emitted_by: userId, is_applicable: true, is_required: true, updated_at: now
                }).eq('id', doc.id)
                await supabase.from('liberation_dossiers').update({ da_micro_applicable: true, updated_at: now }).eq('lot_id', lotId)
              } else {
                await supabase.from('liberation_documents').update({
                  statut: 'emis', emitted_at: now, emitted_by: userId, updated_at: now
                }).eq('id', doc.id)
              }

              var serviceMap = { 'if': 'fabrication', ic: 'conditionnement', da_pc: 'lcq', da_micro: 'lcq' }
              await supabase.from('document_movements').insert({
                document_id: doc.id, action: 'emission', from_service: serviceMap[docType] || '', to_service: 'aq',
                performed_by: userId, performed_at: now
              })
            }

            var actionDesc = isApprouver ? 'approuvé DT' : isVerifier ? 'vérifié AQ → DT' : isRetourEmetteur ? 'retourné à l\'émetteur' : isRetourAQ ? 'retourné DT → AQ' : 'émis'
            await supabase.from('lot_events').insert({
              lot_id: lotId, event_type: 'document_masse',
              description: docType.toUpperCase() + ' — ' + actionDesc + ' (masse)',
              triggered_by: userId, created_at: now
            })

            result.ok++
          }
        } catch (e) {
          result.errors.push(lot.numero_lot + ': ' + e.message)
          result.fail++
        }
        progress.value = i + 1
      }

      execResult.value = result
      executing.value = false
      showConfirm.value = false
      selected.value = []
      loadLots()
    }

    onMounted(loadLots)

    return {
      lots, selected, actionType, search, filterStatut, loading, showConfirm, executing, progress, execResult,
      statusLabels, actionLabel, canExecute, filteredLots, allChecked,
      isSelected, toggleLot, toggleAll, getLotNum, executeAction
    }
  }
}
</script>
<style scoped>
.ph{display:flex;align-items:baseline;justify-content:space-between;padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:2px}
.pt{font-size:11px;font-weight:500;letter-spacing:1.5px}.pc{font-size:11px;color:#185FA5;font-family:'SF Mono',monospace}
.toolbar{display:flex;align-items:center;justify-content:space-between;padding:10px 0;gap:12px;flex-wrap:wrap}
.tool-left{display:flex;align-items:center;gap:8px}.tool-right{display:flex;align-items:center;gap:8px}
.sel{padding:6px 8px;font-size:12px;border:1px solid #ddd;border-radius:3px;outline:none;font-family:inherit;min-width:220px}.sel:focus{border-color:#185FA5}
.sel-sm{padding:6px 8px;font-size:11px;border:1px solid #ddd;border-radius:3px;outline:none;font-family:inherit}
.input-filter{padding:6px 8px;font-size:12px;border:1px solid #ddd;border-radius:3px;outline:none;width:160px;font-family:inherit}.input-filter:focus{border-color:#185FA5}
.btn-exec{padding:6px 16px;font-size:12px;font-weight:500;background:#185FA5;color:#fff;border:none;border-radius:3px;cursor:pointer}.btn-exec:hover{background:#0C447C}.btn-exec:disabled{opacity:.3;cursor:not-allowed}
.table-wrap{overflow-x:auto;max-height:60vh;overflow-y:auto}
.tb{width:100%;border-collapse:collapse;font-size:12px;white-space:nowrap}.tb th{font-size:10px;text-transform:uppercase;color:#999;font-weight:500;padding:6px 6px;text-align:left;border-bottom:1px solid #e8e8e8;position:sticky;top:0;background:#fff;z-index:1}
.tb td{padding:5px 6px;border-bottom:1px solid #f5f5f5}.tb tr{cursor:pointer}.tb tr:hover td{background:#f5f8ff}
.row-selected td{background:#E6F1FB !important}
.th-check,.td-check{width:30px;text-align:center}
.bold{font-weight:500}.mono{font-family:'SF Mono',monospace;font-size:11px}.dim{color:#999;font-size:11px}
.td-prod{max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.code{font-size:10px;color:#999;font-family:'SF Mono',monospace;margin-left:4px}
.sp{font-size:10px;padding:2px 6px;border-radius:2px;font-weight:500;white-space:nowrap}
.s-quarantaine{background:#FAEEDA;color:#854F0B}.s-accepte{background:#EAF3DE;color:#3B6D11}.s-sous_investigation{background:#FCEBEB;color:#A32D2D}.s-vide{background:#f5f5f5;color:#999}
.pip{display:inline-block;width:7px;height:7px;border-radius:50%;vertical-align:middle}.pip-done{background:#1D9E75}.pip-prog{background:#BA7517}
.pip-label{font-size:10px;color:#666}
.doc-pip{font-size:10px;padding:2px 5px;border-radius:2px;font-weight:500}
.dc-ok{background:#EAF3DE;color:#3B6D11}.dc-ret{background:#FCEBEB;color:#A32D2D}.dc-wait{background:#f5f5f5;color:#999}.dc-prog{background:#E6F1FB;color:#0C447C}.dc-na{background:transparent;color:#ccc}
.modal-overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:100}
.modal{background:#fff;padding:24px;width:440px;border-radius:4px;max-height:80vh;overflow-y:auto}
.modal-title{font-size:16px;font-weight:500;margin-bottom:16px}
.modal-body{margin-bottom:20px}
.modal-line{display:flex;justify-content:space-between;padding:6px 0;font-size:13px;border-bottom:1px solid #f5f5f5}.ml{color:#999}
.modal-lots{display:flex;flex-wrap:wrap;gap:4px;margin-top:10px}
.lot-chip{font-size:11px;font-family:'SF Mono',monospace;padding:2px 8px;background:#f5f5f5;border-radius:2px;color:#666}
.lot-chip.more{background:#E6F1FB;color:#185FA5}
.modal-actions{display:flex;gap:8px}
.btn-confirm{flex:1;padding:10px;background:#185FA5;color:#fff;border:none;font-size:13px;font-weight:500;cursor:pointer;border-radius:2px}.btn-confirm:hover{background:#0C447C}.btn-confirm:disabled{opacity:.5}
.btn-cancel{flex:1;padding:10px;background:#f5f5f5;color:#666;border:none;font-size:13px;cursor:pointer;border-radius:2px}
.result{border:1px solid #e8e8e8;padding:20px;margin-top:16px}
.rh{font-size:14px;font-weight:500;margin-bottom:12px}
.rg{display:grid;grid-template-columns:repeat(2,1fr);border:1px solid #e8e8e8}
.rc{padding:12px;text-align:center;border-right:1px solid #e8e8e8}.rc:last-child{border-right:none}
.rv{font-size:20px;font-weight:500;font-family:'SF Mono',monospace}.rl{font-size:10px;color:#999;text-transform:uppercase;margin-top:2px}
.errors-list{margin-top:12px}.err-line{font-size:12px;color:#E24B4A;padding:3px 0;border-bottom:1px solid #f5f5f5}
.empty{text-align:center;padding:40px;color:#999}
</style>
