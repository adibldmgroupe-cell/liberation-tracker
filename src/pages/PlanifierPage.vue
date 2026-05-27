<template>
  <div style="max-width:600px">
    <div class="ph"><span class="pt">PLANIFIER DES LOTS</span></div>

    <div class="last-lot" v-if="lastLot">
      Dernier lot attribué : <span class="ll-num">{{lastLot}}</span>
    </div>

    <div class="form">
      <div class="field">
        <label>Code produit</label>
        <div class="auto-wrap">
          <input v-model="codeInput" @input="onCodeInput" @blur="hideAutoDelay" placeholder="Ex: PFABB10" class="input" />
          <div class="auto-list" v-if="showAuto && suggestions.length">
            <div v-for="s in suggestions" :key="s.id" class="auto-item" @mousedown.prevent="selectProduct(s)">
              <span class="auto-code">{{s.code_article}}</span>
              <span class="auto-desc">{{s.description}}</span>
            </div>
          </div>
        </div>
      </div>

      <div class="product-info" v-if="selectedProduct">
        <span class="pi-code">{{selectedProduct.code_article}}</span>
        <span class="pi-desc">{{selectedProduct.description}}</span>
      </div>

      <div class="row">
        <div class="field half">
          <label>Lot début</label>
          <input v-model="lotDebut" type="text" placeholder="Ex: 26485" class="input" @input="calcCount" />
        </div>
        <div class="field half">
          <label>Lot fin</label>
          <input v-model="lotFin" type="text" placeholder="Ex: 26505" class="input" @input="calcCount" />
        </div>
      </div>

      <div class="count-box" v-if="lotCount > 0">
        <span class="count-val">{{lotCount}}</span> lots à planifier
        <span class="count-range">({{lotDebut}} → {{lotFin}})</span>
      </div>

      <div class="count-box count-err" v-if="lotCount === 0 && lotDebut && lotFin">
        Le lot fin doit être supérieur au lot début
      </div>

      <button class="btn-plan" :disabled="!canSubmit" @click="showConfirm = true">
        Planifier {{lotCount}} lot{{lotCount > 1 ? 's' : ''}}
      </button>
    </div>

    <div class="modal-overlay" v-if="showConfirm" @click="showConfirm = false">
      <div class="modal" @click.stop>
        <div class="modal-title">Confirmer la planification</div>
        <div class="modal-body">
          <div class="modal-line"><span class="ml">Produit</span><span>{{selectedProduct.code_article}} — {{selectedProduct.description}}</span></div>
          <div class="modal-line"><span class="ml">Lots</span><span>{{lotDebut}} → {{lotFin}}</span></div>
          <div class="modal-line"><span class="ml">Nombre</span><span class="mono">{{lotCount}} lots</span></div>
        </div>
        <div class="modal-actions">
          <button class="btn-confirm" @click="doCreate" :disabled="creating">{{creating ? 'Création en cours...' : 'Confirmer'}}</button>
          <button class="btn-cancel" @click="showConfirm = false">Annuler</button>
        </div>
      </div>
    </div>

    <div class="result" v-if="result">
      <div class="rh">Planification terminée</div>
      <div class="rg">
        <div class="rc"><div class="rv" style="color:#1D9E75">{{result.created}}</div><div class="rl">Créés</div></div>
        <div class="rc"><div class="rv" style="color:#999">{{result.skipped}}</div><div class="rl">Déjà existants</div></div>
        <div class="rc"><div class="rv" style="color:#E24B4A">{{result.errors}}</div><div class="rl">Erreurs</div></div>
      </div>
      <button class="btn-see" @click="$router.push('/lots?statut=vide')">Voir les lots planifiés →</button>
    </div>
  </div>
</template>
<script>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
export default {
  setup() {
    var codeInput = ref('')
    var suggestions = ref([])
    var showAuto = ref(false)
    var selectedProduct = ref(null)
    var lotDebut = ref('')
    var lotFin = ref('')
    var lotCount = ref(0)
    var showConfirm = ref(false)
    var creating = ref(false)
    var result = ref(null)
    var lastLot = ref('')

    var searchTimeout = null

    onMounted(async function() {
      // Récupère les 500 lots les plus récemment créés (tri par id DESC)
      // puis trouve le max numérique parmi eux — évite le problème de la limite PostgREST
      var res = await supabase.from('lots').select('numero_lot').order('id',{ascending:false}).limit(500)
      if (res.data && res.data.length) {
        var maxNum = 0
        var maxLot = ''
        for (var i = 0; i < res.data.length; i++) {
          var n = parseInt(res.data[i].numero_lot)
          if (!isNaN(n) && n > maxNum) { maxNum = n; maxLot = res.data[i].numero_lot }
        }
        lastLot.value = maxLot || ''
      }
    })

    var onCodeInput = function() {
      selectedProduct.value = null
      result.value = null
      clearTimeout(searchTimeout)
      if (codeInput.value.length < 2) { suggestions.value = []; showAuto.value = false; return }
      searchTimeout = setTimeout(async function() {
        var res = await supabase.from('products').select('id, code_article, description')
          .or('code_article.ilike.%' + codeInput.value + '%,description.ilike.%' + codeInput.value + '%')
          .limit(8)
        suggestions.value = res.data || []
        showAuto.value = true
      }, 200)
    }

    var selectProduct = function(p) {
      selectedProduct.value = p
      codeInput.value = p.code_article
      showAuto.value = false
    }

    var hideAutoDelay = function() {
      setTimeout(function() { showAuto.value = false }, 200)
    }

    var calcCount = function() {
      var d = parseInt(lotDebut.value)
      var f = parseInt(lotFin.value)
      if (!isNaN(d) && !isNaN(f) && f >= d) {
        lotCount.value = f - d + 1
      } else {
        lotCount.value = 0
      }
    }

    var canSubmit = computed(function() {
      return selectedProduct.value && lotCount.value > 0 && !creating.value
    })

    var doCreate = async function() {
      creating.value = true
      var stats = { created: 0, skipped: 0, errors: 0 }

      var d = parseInt(lotDebut.value)
      var f = parseInt(lotFin.value)

      for (var i = d; i <= f; i++) {
        var numLot = String(i)
        try {
          var existing = await supabase.from('lots').select('id').eq('numero_lot', numLot).maybeSingle()
          if (existing.data) {
            stats.skipped++
            continue
          }

          var lotRes = await supabase.from('lots').insert({
            numero_lot: numLot,
            product_id: selectedProduct.value.id,
            statut_sap: 'vide',
            synced_from_excel_at: new Date().toISOString()
          }).select('id').single()

          if (lotRes.error) { stats.errors++; continue }

          var lotId = lotRes.data.id

          await supabase.from('liberation_documents').insert([
            { lot_id: lotId, type_document: 'if', is_applicable: true, is_required: true, service_emetteur: 'fabrication' },
            { lot_id: lotId, type_document: 'ic', is_applicable: true, is_required: true, service_emetteur: 'conditionnement' },
            { lot_id: lotId, type_document: 'da_pc', is_applicable: true, is_required: true, service_emetteur: 'lcq' },
            { lot_id: lotId, type_document: 'da_micro', is_applicable: false, is_required: false, service_emetteur: 'lcq' },
          ])
          await supabase.from('liberation_dossiers').insert({ lot_id: lotId, da_micro_applicable: false })
          await supabase.from('orders_of').insert({ lot_id: lotId, statut: 'planifie', etape_circuit: 'planification' })
          await supabase.from('orders_oc').insert({ lot_id: lotId, statut: 'planifie', etape_circuit: 'planification' })

          var user = await supabase.auth.getUser()
          await supabase.from('lot_events').insert({
            lot_id: lotId, event_type: 'lot_planifie',
            description: 'Lot planifié — ' + selectedProduct.value.code_article,
            triggered_by: user.data.user.id, source: 'app', created_at: new Date().toISOString()
          })

          stats.created++
        } catch (e) {
          stats.errors++
        }
      }

      result.value = stats
      showConfirm.value = false
      creating.value = false
      lastLot.value = lotFin.value
    }

    return {
      codeInput, suggestions, showAuto, selectedProduct, lotDebut, lotFin, lotCount,
      showConfirm, creating, result, canSubmit, lastLot,
      onCodeInput, selectProduct, hideAutoDelay, calcCount, doCreate
    }
  }
}
</script>
<style scoped>
.ph{padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:16px}.pt{font-size:11px;font-weight:500;letter-spacing:1.5px}
.last-lot{padding:10px 12px;border:1px solid #e8e8e8;background:#fafafa;font-size:13px;color:#666;margin-bottom:16px;border-radius:2px}
.ll-num{font-family:'SF Mono',monospace;font-weight:500;font-size:16px;color:#185FA5;margin-left:4px}
.form{margin-top:8px}
.field{margin-bottom:14px}.field label{display:block;font-size:11px;color:#666;text-transform:uppercase;letter-spacing:.3px;margin-bottom:4px}
.input{width:100%;padding:8px 10px;border:1px solid #ddd;font-size:13px;outline:none;box-sizing:border-box;font-family:inherit}.input:focus{border-color:#185FA5}
.row{display:flex;gap:12px}.half{flex:1}
.auto-wrap{position:relative}
.auto-list{position:absolute;top:100%;left:0;right:0;background:#fff;border:1px solid #ddd;border-radius:4px;margin-top:2px;box-shadow:0 4px 12px rgba(0,0,0,.08);z-index:10;max-height:240px;overflow-y:auto}
.auto-item{display:flex;align-items:center;gap:8px;padding:8px 12px;cursor:pointer;font-size:13px}.auto-item:hover{background:#f5f5f5}
.auto-code{font-family:'SF Mono',monospace;font-size:12px;font-weight:500;color:#185FA5;min-width:90px}
.auto-desc{color:#666;font-size:12px}
.product-info{display:flex;align-items:center;gap:8px;padding:10px 12px;border:1px solid #1D9E75;background:#EAF3DE;border-radius:2px;margin-bottom:14px}
.pi-code{font-family:'SF Mono',monospace;font-size:13px;font-weight:500;color:#3B6D11}
.pi-desc{font-size:13px;color:#3B6D11}
.count-box{padding:12px;border:1px solid #e8e8e8;text-align:center;font-size:14px;margin-bottom:14px;border-radius:2px}
.count-val{font-size:24px;font-weight:500;font-family:'SF Mono',monospace;color:#185FA5;margin-right:6px}
.count-range{font-size:12px;color:#999;font-family:'SF Mono',monospace}
.count-err{color:#E24B4A;border-color:#E24B4A;font-size:12px}
.btn-plan{width:100%;padding:12px;font-size:14px;font-weight:500;background:#0a0a0a;color:#fff;border:none;cursor:pointer;border-radius:2px;letter-spacing:.3px}.btn-plan:hover{background:#222}.btn-plan:disabled{opacity:.3;cursor:not-allowed}
.modal-overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:100}
.modal{background:#fff;padding:24px;width:min(90vw,400px);border-radius:4px}
.modal-title{font-size:16px;font-weight:500;margin-bottom:16px}
.modal-body{margin-bottom:20px}
.modal-line{display:flex;justify-content:space-between;padding:6px 0;font-size:13px;border-bottom:1px solid #f5f5f5}
.ml{color:#999}
.mono{font-family:'SF Mono',monospace}
.modal-actions{display:flex;gap:8px}
.btn-confirm{flex:1;padding:10px;background:#185FA5;color:#fff;border:none;font-size:13px;font-weight:500;cursor:pointer;border-radius:2px}.btn-confirm:hover{background:#0C447C}.btn-confirm:disabled{opacity:.5}
.btn-cancel{flex:1;padding:10px;background:#f5f5f5;color:#666;border:none;font-size:13px;cursor:pointer;border-radius:2px}.btn-cancel:hover{background:#eee}
.result{border:1px solid #e8e8e8;padding:20px;margin-top:20px}
.rh{font-size:14px;font-weight:500;margin-bottom:12px}
.rg{display:grid;grid-template-columns:repeat(3,1fr);border:1px solid #e8e8e8}
.rc{padding:12px;text-align:center;border-right:1px solid #e8e8e8}.rc:last-child{border-right:none}
.rv{font-size:20px;font-weight:500;font-family:'SF Mono',monospace}.rl{font-size:10px;color:#999;text-transform:uppercase;margin-top:2px}
.btn-see{margin-top:14px;padding:8px 20px;background:#185FA5;color:#fff;border:none;font-size:13px;cursor:pointer;border-radius:2px}.btn-see:hover{background:#0C447C}
@media(max-width:600px){
  .row{flex-direction:column}
  .input,.auto-list{font-size:16px}
  .modal{padding:16px}
  .btn-confirm,.btn-cancel{min-height:44px;font-size:14px}
  .btn-plan{min-height:44px}
  .rg{grid-template-columns:1fr 1fr}
}
</style>
