<template>
  <div class="flux-admin">
    <div class="fa-header">
      <div class="fa-title">⚙ Paramétrage flux produits</div>
      <div class="fa-sub">Configurez les étapes de fabrication et de conditionnement par produit</div>
    </div>

    <!-- TABS -->
    <div class="fa-tabs">
      <button class="fa-tab" :class="{active:tab==='flux'}" @click="tab='flux'">
        🔀 Flux par produit
      </button>
      <button class="fa-tab" :class="{active:tab==='cadences'}" @click="tab='cadences'">
        ⚡ Cadences
      </button>
      <button class="fa-tab" :class="{active:tab==='master'}" @click="tab='master'">
        🏭 Ateliers référence
      </button>
    </div>

    <!-- ── TAB : FLUX PAR PRODUIT ── -->
    <div v-if="tab==='flux'" class="tab-body">
      <div class="tb-toolbar">
        <div class="tb-search-wrap">
          <span class="ts-icon">🔍</span>
          <input class="tb-search" placeholder="Rechercher produit ou code…" v-model="fluxSearch"/>
        </div>
        <div class="tb-filters">
          <select class="tb-sel" v-model="fluxTypeFilter">
            <option value="">Tous les types</option>
            <option value="COM_PELLI">COM_PELLI</option>
            <option value="COM_SEC">COM_SEC</option>
            <option value="GLE">GLE</option>
            <option value="CREME_POMMADE">CREME_POMMADE</option>
            <option value="OTC">OTC</option>
          </select>
          <button class="tb-btn-add" @click="openNewFlux">+ Nouveau flux</button>
        </div>
      </div>

      <div v-if="fluxLoading" class="loading-row">Chargement…</div>

      <!-- Product cards -->
      <div class="products-grid" v-else>
        <div class="prod-card" v-for="p in filteredProducts" :key="p.product_code">
          <div class="pc-hd">
            <div>
              <div class="pc-code">{{p.product_code}}</div>
              <div class="pc-name">{{p.product_name}}</div>
            </div>
            <div class="pc-badges">
              <span class="pc-type" :class="'pct-'+p.type_flux">{{p.type_flux}}</span>
              <span class="pc-routes" v-if="p.has_route_2">2 routes</span>
            </div>
          </div>

          <!-- Routes -->
          <div class="pc-routes-wrap" v-for="route in p.routes" :key="route.route">
            <div class="pr-label">Route {{route.route}}</div>
            <div class="pr-steps">
              <div class="pr-step" v-for="(step, idx) in route.steps" :key="step.id">
                <div class="prs-num">{{idx+1}}</div>
                <div class="prs-op">
                  <div class="prs-code">{{step.op_code}}</div>
                  <div class="prs-room" v-if="step.room_code">
                    <span class="prs-room-code">{{step.room_code}}</span>
                    {{getRoomName(step.room_code)}}
                  </div>
                  <div class="prs-room prs-flex" v-else>flexible</div>
                </div>
                <div class="prs-actions">
                  <button class="prs-btn" @click="openEditStep(step)" title="Modifier">✏</button>
                  <button class="prs-btn prs-del" @click="deleteStep(step)" title="Supprimer">✕</button>
                </div>
              </div>
              <button class="pr-add-step" @click="openAddStep(p.product_code, p.product_name, route.route)">
                + Étape
              </button>
            </div>
          </div>

          <button class="pc-add-route" v-if="!p.has_route_2"
            @click="openAddStep(p.product_code, p.product_name, 2)">
            + Ajouter Route 2
          </button>
        </div>
      </div>
    </div>

    <!-- ── TAB : CADENCES ── -->
    <div v-if="tab==='cadences'" class="tab-body">
      <div class="tb-toolbar">
        <div class="tb-search-wrap">
          <span class="ts-icon">🔍</span>
          <input class="tb-search" placeholder="Chercher équipement ou produit…" v-model="cadSearch"/>
        </div>
        <button class="tb-btn-add" @click="openNewCad">+ Nouvelle cadence</button>
      </div>

      <div class="cad-table-wrap table-wrap">
        <table class="cad-table">
          <thead>
            <tr>
              <th>Salle</th>
              <th>Désignation</th>
              <th>Produit</th>
              <th>Cadence théorique</th>
              <th>Unité</th>
              <th>Notes</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!filteredCadences.length">
              <td colspan="7" class="empty-row">
                {{cadences.length ? 'Aucun résultat' : 'Aucune cadence définie — cliquez "+ Nouvelle cadence"'}}
              </td>
            </tr>
            <tr v-for="c in filteredCadences" :key="c.id">
              <td><span class="room-chip">{{c.room_code}}</span></td>
              <td>{{getRoomName(c.room_code)}}</td>
              <td>
                <div class="cad-prod-code">{{c.product_code}}</div>
              </td>
              <td class="cad-val">{{c.cadence_theorique?.toLocaleString('fr-FR') ?? '—'}}</td>
              <td><span class="unit-chip">{{c.unite}}</span></td>
              <td class="cad-notes">{{c.notes||'—'}}</td>
              <td>
                <button class="prs-btn" @click="openEditCad(c)">✏</button>
                <button class="prs-btn prs-del" @click="deleteCad(c)">✕</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ── TAB : MASTER ATELIERS ── -->
    <div v-if="tab==='master'" class="tab-body">
      <div class="table-wrap">
      <table class="cad-table">
        <thead>
          <tr>
            <th>Op#</th>
            <th>Code</th>
            <th>Code opération</th>
            <th>Désignation</th>
            <th>Équipement</th>
            <th>Processus</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="m in opMaster" :key="m.id">
            <td><span class="op-num">{{m.op_number}}</span></td>
            <td><span class="room-chip">{{m.room_code}}</span></td>
            <td><span class="op-code">{{m.op_code}}</span></td>
            <td>{{m.room_name}}</td>
            <td>{{m.equipment_name}}</td>
            <td>{{m.processus}}</td>
          </tr>
        </tbody>
      </table>
      </div>
    </div>

    <!-- ── MODAL ÉTAPE FLUX ── -->
    <div class="modal-overlay" v-if="stepModal.open" @click.self="stepModal.open=false">
      <div class="modal-box">
        <div class="modal-hd">
          {{stepModal.id ? '✏ Modifier étape' : '+ Ajouter étape'}}
          <span class="mh-sub">— {{stepModal.product_code}}</span>
        </div>
        <div class="modal-body">
          <div class="mf-row">
            <label>Route</label>
            <select class="mf-input" v-model="stepModal.route">
              <option :value="1">Route 1</option>
              <option :value="2">Route 2</option>
            </select>
          </div>
          <div class="mf-row">
            <label>Opération</label>
            <select class="mf-input" v-model="stepModal.op_number" @change="onOpChange">
              <option value="">— Choisir —</option>
              <option v-for="op in opOptions" :key="op.op_number+'_'+op.room_code" :value="op.op_number">
                {{op.op_number}} — {{op.op_code}} ({{op.room_code}} {{op.equipment_name}})
              </option>
            </select>
          </div>
          <div class="mf-row">
            <label>Machine spécifique <span class="mf-opt">(laisser vide = flexible)</span></label>
            <select class="mf-input" v-model="stepModal.room_code">
              <option value="">Flexible (toute machine de ce type)</option>
              <option v-for="rm in roomsForOp" :key="rm.room_code" :value="rm.room_code">
                {{rm.room_code}} — {{rm.room_name}} ({{rm.equipment_name}})
              </option>
            </select>
          </div>
          <div class="mf-err" v-if="stepModal.err">{{stepModal.err}}</div>
        </div>
        <div class="modal-ft">
          <button class="mb-cancel" @click="stepModal.open=false">Annuler</button>
          <button class="mb-ok" @click="saveStep" :disabled="stepModal.saving">
            {{stepModal.saving ? '…' : stepModal.id ? 'Enregistrer' : 'Ajouter'}}
          </button>
        </div>
      </div>
    </div>

    <!-- ── MODAL CADENCE ── -->
    <div class="modal-overlay" v-if="cadModal.open" @click.self="cadModal.open=false">
      <div class="modal-box">
        <div class="modal-hd">{{cadModal.id ? '✏ Modifier cadence' : '+ Nouvelle cadence'}}</div>
        <div class="modal-body">
          <div class="mf-row">
            <label>Salle / Équipement</label>
            <select class="mf-input" v-model="cadModal.room_code">
              <option value="">— Choisir —</option>
              <option v-for="m in opMaster" :key="m.room_code" :value="m.room_code">
                {{m.room_code}} — {{m.room_name}} ({{m.equipment_name}})
              </option>
            </select>
          </div>
          <div class="mf-row">
            <label>Code produit</label>
            <div class="lot-search-wrap">
              <input class="mf-input" placeholder="Ex: PFLDM05…" v-model="cadModal.prodSearch"
                @input="searchCadProds"/>
              <div class="lot-dropdown" v-if="cadModal.prodDropdown.length">
                <div v-for="p in cadModal.prodDropdown" :key="p.product_code" class="ld-item"
                  @click="selectCadProd(p)">
                  <b>{{p.product_code}}</b> — {{p.product_name}}
                </div>
              </div>
            </div>
            <div v-if="cadModal.product_code" class="lot-chip">✓ {{cadModal.product_code}}</div>
          </div>
          <div class="mf-row">
            <label>Cadence théorique</label>
            <input class="mf-input" type="number" v-model="cadModal.cadence" placeholder="Ex: 120000"/>
          </div>
          <div class="mf-row">
            <label>Unité</label>
            <select class="mf-input" v-model="cadModal.unite">
              <option value="cp/h">cp/h — comprimés/heure</option>
              <option value="gel/h">gel/h — gélules/heure</option>
              <option value="tube/h">tube/h — tubes/heure</option>
              <option value="b/h">b/h — boîtes/heure</option>
              <option value="kg/h">kg/h — kg/heure</option>
            </select>
          </div>
          <div class="mf-row">
            <label>Notes <span class="mf-opt">(optionnel)</span></label>
            <input class="mf-input" v-model="cadModal.notes" placeholder="Conditions, format spécifique…"/>
          </div>
          <div class="mf-err" v-if="cadModal.err">{{cadModal.err}}</div>
        </div>
        <div class="modal-ft">
          <button class="mb-cancel" @click="cadModal.open=false">Annuler</button>
          <button class="mb-ok" @click="saveCad" :disabled="cadModal.saving">
            {{cadModal.saving ? '…' : cadModal.id ? 'Enregistrer' : 'Ajouter'}}
          </button>
        </div>
      </div>
    </div>

  </div>
</template>

<script>
import { ref, computed, onMounted, reactive } from 'vue'
import { supabase } from '../../supabase'

export default {
  setup() {
    var tab          = ref('flux')
    var fluxSearch   = ref('')
    var fluxTypeFilter = ref('')
    var cadSearch    = ref('')
    var fluxLoading  = ref(false)

    var productsSummary = ref([])   // from v_product_flux_summary
    var allFluxRows     = ref([])   // from product_flux
    var cadences        = ref([])
    var opMaster        = ref([])

    // ── STEP MODAL ──────────────────────────────────────────────
    var stepModal = reactive({
      open: false, id: null, saving: false, err: '',
      product_code: '', product_name: '',
      route: 1, op_number: '', room_code: ''
    })

    // ── CADENCE MODAL ────────────────────────────────────────────
    var cadModal = reactive({
      open: false, id: null, saving: false, err: '',
      room_code: '', product_code: '', prodSearch: '',
      prodDropdown: [], cadence: null, unite: 'cp/h', notes: ''
    })

    // ─── COMPUTED ────────────────────────────────────────────────
    var groupedProducts = computed(function() {
      var map = new Map()
      allFluxRows.value.forEach(function(row) {
        var key = row.product_code
        if (!map.has(key)) {
          map.set(key, { product_code: row.product_code, product_name: row.product_name, routes: {}, type_flux: 'COM_SEC', has_route_2: false })
        }
        var prod = map.get(key)
        if (!prod.routes[row.route]) prod.routes[row.route] = []
        prod.routes[row.route].push(row)
        if (row.route === 2) prod.has_route_2 = true
      })
      // Get type_flux from summary
      productsSummary.value.forEach(function(s) {
        if (map.has(s.product_code)) {
          map.get(s.product_code).type_flux = s.type_flux
        }
      })
      return Array.from(map.values()).map(function(p) {
        return Object.assign({}, p, {
          routes: Object.entries(p.routes).map(function(entry) {
            return {
              route: parseInt(entry[0]),
              steps: entry[1].slice().sort(function(a, b) { return a.op_number - b.op_number })
            }
          }).sort(function(a, b) { return a.route - b.route })
        })
      }).sort(function(a, b) { return a.product_code.localeCompare(b.product_code) })
    })

    var filteredProducts = computed(function() {
      var q = fluxSearch.value.toLowerCase()
      return groupedProducts.value.filter(function(p) {
        var matchQ = !q || p.product_code.toLowerCase().includes(q) || p.product_name.toLowerCase().includes(q)
        var matchT = !fluxTypeFilter.value || p.type_flux === fluxTypeFilter.value
        return matchQ && matchT
      })
    })

    var filteredCadences = computed(function() {
      var q = cadSearch.value.toLowerCase()
      if (!q) return cadences.value
      return cadences.value.filter(function(c) {
        return c.room_code.toLowerCase().includes(q) || c.product_code.toLowerCase().includes(q)
      })
    })

    var opOptions = computed(function() {
      // Deduplicated list of unique op_numbers from opMaster
      var seen = new Set()
      return opMaster.value.filter(function(m) {
        if (seen.has(m.op_number)) return false
        seen.add(m.op_number)
        return true
      }).sort(function(a, b) { return a.op_number - b.op_number })
    })

    var roomsForOp = computed(function() {
      if (!stepModal.op_number) return []
      return opMaster.value.filter(function(m) {
        return m.op_number === parseInt(stepModal.op_number)
      })
    })

    // ─── HELPERS ─────────────────────────────────────────────────
    var getRoomName = function(code) {
      var found = opMaster.value.find(function(m) { return m.room_code === code })
      return found ? found.equipment_name : '—'
    }

    var onOpChange = function() {
      stepModal.room_code = ''
    }

    // ─── FLUX STEP CRUD ───────────────────────────────────────────
    var openNewFlux = function() {
      stepModal.open = true; stepModal.id = null; stepModal.err = ''
      stepModal.product_code = ''; stepModal.product_name = ''
      stepModal.route = 1; stepModal.op_number = ''; stepModal.room_code = ''
    }

    var openAddStep = function(code, name, route) {
      stepModal.open = true; stepModal.id = null; stepModal.err = ''
      stepModal.product_code = code; stepModal.product_name = name
      stepModal.route = route; stepModal.op_number = ''; stepModal.room_code = ''
    }

    var openEditStep = function(step) {
      stepModal.open = true; stepModal.id = step.id; stepModal.err = ''
      stepModal.product_code = step.product_code; stepModal.product_name = step.product_name
      stepModal.route = step.route; stepModal.op_number = step.op_number
      stepModal.room_code = step.room_code || ''
    }

    var saveStep = async function() {
      if (!stepModal.product_code.trim()) { stepModal.err = 'Code produit requis.'; return }
      if (!stepModal.op_number) { stepModal.err = 'Opération requise.'; return }
      stepModal.saving = true; stepModal.err = ''
      // Get product_name if not set
      var pname = stepModal.product_name
      if (!pname) {
        var found = allFluxRows.value.find(function(r) { return r.product_code === stepModal.product_code })
        pname = found ? found.product_name : stepModal.product_code
      }
      var payload = {
        product_code: stepModal.product_code.trim(),
        product_name: pname,
        op_number: parseInt(stepModal.op_number),
        route: stepModal.route,
        room_code: stepModal.room_code || null
      }
      var res
      if (stepModal.id) {
        res = await supabase.from('product_flux').update(payload).eq('id', stepModal.id)
      } else {
        res = await supabase.from('product_flux').insert(payload)
      }
      stepModal.saving = false
      if (res.error) { stepModal.err = res.error.message; return }
      stepModal.open = false
      await loadAll()
    }

    var deleteStep = async function(step) {
      if (!confirm('Supprimer cette étape ?')) return
      var res = await supabase.from('product_flux').delete().eq('id', step.id)
      if (!res.error) await loadAll()
    }

    // ─── CADENCE CRUD ─────────────────────────────────────────────
    var openNewCad = function() {
      Object.assign(cadModal, {
        open: true, id: null, saving: false, err: '',
        room_code: '', product_code: '', prodSearch: '',
        prodDropdown: [], cadence: null, unite: 'cp/h', notes: ''
      })
    }

    var openEditCad = function(c) {
      Object.assign(cadModal, {
        open: true, id: c.id, saving: false, err: '',
        room_code: c.room_code, product_code: c.product_code,
        prodSearch: c.product_code, prodDropdown: [],
        cadence: c.cadence_theorique, unite: c.unite||'cp/h', notes: c.notes||''
      })
    }

    var searchCadProds = async function() {
      var q = cadModal.prodSearch
      if (!q || q.length < 2) { cadModal.prodDropdown = []; return }
      // Search from product_flux unique products
      var results = allFluxRows.value.filter(function(r) {
        return r.product_code.toLowerCase().includes(q.toLowerCase()) ||
               r.product_name.toLowerCase().includes(q.toLowerCase())
      }).reduce(function(acc, r) {
        if (!acc.find(function(x) { return x.product_code === r.product_code })) {
          acc.push({ product_code: r.product_code, product_name: r.product_name })
        }
        return acc
      }, []).slice(0, 10)
      cadModal.prodDropdown = results
    }

    var selectCadProd = function(p) {
      cadModal.product_code = p.product_code
      cadModal.prodSearch = p.product_code
      cadModal.prodDropdown = []
    }

    var saveCad = async function() {
      if (!cadModal.room_code) { cadModal.err = 'Salle requise.'; return }
      if (!cadModal.product_code) { cadModal.err = 'Produit requis.'; return }
      cadModal.saving = true; cadModal.err = ''
      var payload = {
        room_code: cadModal.room_code,
        product_code: cadModal.product_code,
        cadence_theorique: cadModal.cadence ? parseFloat(cadModal.cadence) : null,
        unite: cadModal.unite,
        notes: cadModal.notes || null
      }
      var res
      if (cadModal.id) {
        res = await supabase.from('equipment_cadences').update(payload).eq('id', cadModal.id)
      } else {
        res = await supabase.from('equipment_cadences').insert(payload)
      }
      cadModal.saving = false
      if (res.error) { cadModal.err = res.error.message; return }
      cadModal.open = false
      await loadAll()
    }

    var deleteCad = async function(c) {
      if (!confirm('Supprimer cette cadence ?')) return
      var res = await supabase.from('equipment_cadences').delete().eq('id', c.id)
      if (!res.error) await loadAll()
    }

    // ─── LOAD ─────────────────────────────────────────────────────
    var loadAll = async function() {
      fluxLoading.value = true
      var [r1, r2, r3, r4] = await Promise.all([
        supabase.from('product_flux').select('*').order('product_code').order('route').order('op_number'),
        supabase.from('v_product_flux_summary').select('*'),
        supabase.from('equipment_cadences').select('*').order('room_code'),
        supabase.from('operations_master').select('*').order('op_number'),
      ])
      if (!r1.error) allFluxRows.value     = r1.data
      if (!r2.error) productsSummary.value = r2.data
      if (!r3.error) cadences.value        = r3.data
      if (!r4.error) opMaster.value        = r4.data
      fluxLoading.value = false
    }

    onMounted(loadAll)

    return {
      tab, fluxSearch, fluxTypeFilter, cadSearch, fluxLoading,
      filteredProducts, filteredCadences, opMaster, opOptions, roomsForOp,
      stepModal, cadModal,
      getRoomName, onOpChange,
      openNewFlux, openAddStep, openEditStep, saveStep, deleteStep,
      openNewCad, openEditCad, searchCadProds, selectCadProd, saveCad, deleteCad,
    }
  }
}
</script>

<style scoped>
.flux-admin { padding:20px; max-width:1400px; font-family:'Inter',sans-serif; }
.fa-header { margin-bottom:20px; }
.fa-title { font-size:18px; font-weight:800; color:#1a1a2e; }
.fa-sub { font-size:12px; color:#6b7280; margin-top:4px; }

/* Tabs */
.fa-tabs { display:flex; gap:4px; border-bottom:1px solid #e5e7eb; margin-bottom:20px; }
.fa-tab { padding:8px 18px; border:none; background:none; font-size:13px; font-weight:600; color:#6b7280; cursor:pointer; border-bottom:2px solid transparent; margin-bottom:-1px; }
.fa-tab.active { color:#7c3aed; border-bottom-color:#7c3aed; }

/* Toolbar */
.tb-toolbar { display:flex; align-items:center; justify-content:space-between; gap:12px; margin-bottom:16px; flex-wrap:wrap; }
.tb-search-wrap { display:flex; align-items:center; gap:8px; background:#f9fafb; border:1px solid #e5e7eb; border-radius:6px; padding:6px 12px; min-width:280px; }
.ts-icon { color:#9ca3af; }
.tb-search { border:none; background:transparent; outline:none; font-size:13px; flex:1; }
.tb-filters { display:flex; gap:8px; }
.tb-sel { border:1px solid #e5e7eb; border-radius:5px; padding:6px 10px; font-size:12px; color:#374151; }
.tb-btn-add { background:#7c3aed; border:none; border-radius:5px; color:#fff; padding:7px 14px; font-size:12px; font-weight:600; cursor:pointer; }
.tb-btn-add:hover { background:#6d28d9; }

/* Products grid */
.products-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(380px,1fr)); gap:16px; }
.prod-card { background:#fff; border:1px solid #e5e7eb; border-radius:8px; padding:14px; }
.pc-hd { display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:12px; }
.pc-code { font-size:11px; font-weight:800; color:#7c3aed; font-family:monospace; }
.pc-name { font-size:12px; color:#374151; margin-top:2px; }
.pc-badges { display:flex; flex-direction:column; gap:4px; align-items:flex-end; }
.pc-type { font-size:9px; font-weight:700; padding:2px 6px; border-radius:3px; }
.pct-COM_PELLI { background:#ede9fe; color:#7c3aed; }
.pct-COM_SEC { background:#d1fae5; color:#065f46; }
.pct-GLE { background:#fef3c7; color:#92400e; }
.pct-CREME_POMMADE { background:#dbeafe; color:#1e40af; }
.pct-OTC { background:#f3f4f6; color:#6b7280; }
.pc-routes { font-size:9px; color:#9ca3af; background:#f3f4f6; padding:2px 5px; border-radius:3px; }
.pc-routes-wrap { margin-bottom:10px; }
.pr-label { font-size:9px; font-weight:700; letter-spacing:1px; text-transform:uppercase; color:#9ca3af; margin-bottom:6px; }
.pr-steps { display:flex; flex-direction:column; gap:4px; }
.pr-step { display:flex; align-items:center; gap:8px; padding:5px 8px; background:#f9fafb; border-radius:4px; }
.prs-num { width:18px; height:18px; background:#e5e7eb; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:9px; font-weight:700; color:#6b7280; flex-shrink:0; }
.prs-op { flex:1; }
.prs-code { font-size:11px; font-weight:700; color:#374151; }
.prs-room { font-size:10px; color:#9ca3af; display:flex; align-items:center; gap:4px; }
.prs-room-code { background:#ede9fe; color:#7c3aed; border-radius:2px; padding:0 3px; font-size:9px; font-family:monospace; font-weight:700; }
.prs-flex { font-style:italic; }
.prs-actions { display:flex; gap:4px; }
.prs-btn { background:none; border:1px solid #e5e7eb; border-radius:3px; color:#9ca3af; cursor:pointer; font-size:10px; padding:2px 5px; }
.prs-btn:hover { color:#374151; border-color:#9ca3af; }
.prs-del:hover { color:#ef4444; border-color:#ef4444; }
.pr-add-step { background:none; border:1px dashed #d1d5db; border-radius:4px; color:#9ca3af; cursor:pointer; font-size:10px; padding:4px; text-align:center; width:100%; }
.pr-add-step:hover { border-color:#7c3aed; color:#7c3aed; background:#faf5ff; }
.pc-add-route { background:none; border:1px dashed #c4b5fd; border-radius:4px; color:#7c3aed; cursor:pointer; font-size:10px; padding:5px; width:100%; text-align:center; margin-top:6px; }
.pc-add-route:hover { background:#faf5ff; }

/* Cadences table */
.cad-table-wrap { overflow-x:auto; }
.cad-table { width:100%; border-collapse:collapse; font-size:13px; }
.cad-table th { background:#f9fafb; padding:10px 14px; text-align:left; font-size:11px; font-weight:700; color:#6b7280; border-bottom:1px solid #e5e7eb; }
.cad-table td { padding:10px 14px; border-bottom:1px solid #f3f4f6; vertical-align:middle; }
.room-chip { background:#ede9fe; color:#7c3aed; font-family:monospace; font-size:11px; font-weight:700; padding:2px 7px; border-radius:3px; }
.op-num { background:#e0e7ff; color:#3730a3; font-family:monospace; font-size:11px; font-weight:700; padding:2px 7px; border-radius:3px; }
.op-code { background:#f0fdf4; color:#065f46; font-size:11px; font-weight:700; padding:2px 7px; border-radius:3px; }
.unit-chip { background:#f3f4f6; color:#374151; font-size:10px; padding:2px 6px; border-radius:3px; }
.cad-val { font-family:monospace; font-weight:700; color:#1f2937; }
.cad-notes { color:#9ca3af; font-size:11px; max-width:180px; }
.cad-prod-code { font-family:monospace; font-size:11px; font-weight:700; color:#7c3aed; }
.empty-row { text-align:center; color:#9ca3af; font-style:italic; padding:24px; }
.loading-row { text-align:center; color:#9ca3af; padding:32px; }

/* Modal */
.modal-overlay { position:fixed; inset:0; background:rgba(0,0,0,.5); z-index:200; display:flex; align-items:center; justify-content:center; }
.modal-box { background:#fff; border-radius:10px; width:460px; max-width:95vw; box-shadow:0 20px 50px rgba(0,0,0,.2); }
.modal-hd { padding:16px 20px 12px; font-size:14px; font-weight:800; color:#111827; border-bottom:1px solid #f3f4f6; }
.mh-sub { color:#9ca3af; font-weight:400; font-size:12px; }
.modal-body { padding:16px 20px; display:flex; flex-direction:column; gap:12px; }
.mf-row { display:flex; flex-direction:column; gap:4px; }
.mf-row label { font-size:10px; color:#6b7280; letter-spacing:1px; text-transform:uppercase; font-weight:700; }
.mf-opt { color:#9ca3af; font-style:italic; text-transform:none; letter-spacing:0; font-weight:400; }
.mf-input { border:1px solid #e5e7eb; border-radius:5px; color:#111827; font-size:12px; padding:8px 10px; outline:none; width:100%; box-sizing:border-box; }
.mf-input:focus { border-color:#7c3aed; }
.mf-err { font-size:11px; color:#ef4444; background:#fef2f2; border-radius:4px; padding:6px 10px; }
.modal-ft { display:flex; justify-content:flex-end; gap:8px; padding:12px 20px; border-top:1px solid #f3f4f6; }
.mb-cancel { background:transparent; border:1px solid #e5e7eb; border-radius:5px; color:#6b7280; padding:7px 16px; font-size:12px; cursor:pointer; }
.mb-ok { background:#7c3aed; border:none; border-radius:5px; color:#fff; padding:7px 16px; font-size:12px; cursor:pointer; font-weight:700; }
.mb-ok:hover:not(:disabled) { background:#6d28d9; }
.mb-ok:disabled { opacity:.4; cursor:not-allowed; }
.lot-search-wrap { position:relative; }
.lot-dropdown { position:absolute; top:100%; left:0; right:0; background:#fff; border:1px solid #e5e7eb; border-radius:6px; z-index:10; max-height:180px; overflow-y:auto; box-shadow:0 4px 12px rgba(0,0,0,.1); margin-top:2px; }
.ld-item { padding:8px 12px; font-size:11px; color:#374151; cursor:pointer; border-bottom:1px solid #f3f4f6; }
.ld-item:hover { background:#f5f3ff; }
.lot-chip { font-size:11px; color:#059669; background:#d1fae5; border-radius:4px; padding:4px 10px; margin-top:4px; }
.table-wrap{overflow-x:auto;-webkit-overflow-scrolling:touch}
@media(max-width:768px){
  .cad-table{min-width:560px}
  .fa-tabs{flex-wrap:wrap;gap:4px}
  .fa-tab{flex:1;min-height:40px;font-size:12px;padding:8px 10px}
  .tb-toolbar{flex-direction:column;gap:8px}
  .tb-filters{flex-direction:column;gap:6px;width:100%}
  .tb-sel,.tb-search{width:100%;font-size:13px}
  .tb-btn-add{width:100%;min-height:44px;text-align:center}
  .products-grid{grid-template-columns:1fr}
  .modal-box{width:min(96vw,460px)}
  .mb-ok,.mb-cancel{min-height:44px}
}
@media(max-width:480px){
  .cad-table{min-width:480px}
  .fa-title{font-size:14px}
  .mf-input{font-size:16px}
  .modal-ft{flex-direction:column;gap:6px}
  .mb-ok,.mb-cancel{width:100%}
}
</style>
