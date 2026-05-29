<template>
  <div class="flux-admin">
    <div class="fa-header">
      <div>
        <div class="fa-title">⚙ Paramétrage flux produits</div>
        <div class="fa-sub">Configurez les étapes de fabrication et de conditionnement par produit</div>
      </div>
      <button class="fa-btn-gs-reload" @click="reloadGs" :disabled="gsReloading" :class="{spinning:gsReloading}">
        ↻ Forcer rechargement GS
      </button>
    </div>

    <!-- ── FLUX PAR PRODUIT ── -->
    <div class="tab-body">
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
          <div class="view-toggle">
            <button class="vt-btn" :class="{active:fluxView==='pivot'}" @click="fluxView='pivot'" title="Vue tableau croisé machines">⊞ Pivot</button>
            <button class="vt-btn" :class="{active:fluxView==='cards'}" @click="fluxView='cards'" title="Vue fiches">▤ Fiches</button>
          </div>
          <button class="tb-btn-gs" @click="openGsImport">↑ Google Sheets</button>
          <button class="tb-btn-add" @click="openNewFlux">+ Nouveau flux</button>
        </div>
      </div>

      <div v-if="fluxLoading" class="loading-row">Chargement…</div>

      <!-- ── VUE PIVOT MACHINES ── -->
      <div class="table-scroll" v-else-if="fluxView==='pivot'">
        <div v-if="!pivotMachineRows.length" class="empty-row">Aucun flux configuré — cliquez "+ Nouveau flux"</div>
        <table class="pivot-table" v-else>
          <thead>
            <!-- Ligne 1 : groupes opérations -->
            <tr class="pt-r-op">
              <th class="pt-h-prod pt-sc pt-sc1">Produit</th>
              <th class="pt-h-type pt-sc pt-sc2">Type</th>
              <th class="pt-h-r    pt-sc pt-sc3">R</th>
              <th v-for="g in machineColGroups" :key="g.op_number"
                  :colspan="g.rooms.length" class="pt-h-grp">
                <span class="ptg-num">{{g.op_number}}</span>
                <span class="ptg-lbl">{{g.label}}</span>
              </th>
            </tr>
            <!-- Ligne 2 : noms machines -->
            <tr class="pt-r-mach">
              <th class="pt-sc pt-sc1"></th>
              <th class="pt-sc pt-sc2"></th>
              <th class="pt-sc pt-sc3"></th>
              <th v-for="room in machineColsFlat" :key="room.code" class="pt-h-mach"
                  :title="room.nom">
                {{room.nom}}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in pivotMachineRows" :key="row.product_code+'_'+row.route"
                :class="{'pt-r2':row.route===2}">
              <td class="pt-prod-cell pt-sc pt-sc1">
                <div class="pt-pcode">{{row.product_code}}</div>
                <div class="pt-pname">{{row.product_name}}</div>
              </td>
              <td class="pt-sc pt-sc2">
                <span class="pc-type" :class="'pct-'+row.type_flux">{{row.type_flux}}</span>
              </td>
              <td class="pt-route-num pt-sc pt-sc3">R{{row.route}}</td>
              <td v-for="room in machineColsFlat" :key="room.code"
                  class="pt-cc" @click="toggleMachineFlux(row, room)">
                <span class="pt-cb" :class="{on: row.activeRoomCodes.has(room.code)}"></span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- ── VUE FICHES ── -->
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
          <div class="pc-routes-wrap" v-for="route in p.routes" :key="route.route">
            <div class="pr-label">Route {{route.route}}</div>
            <div class="pr-steps">
              <div class="pr-step" v-for="(step, idx) in route.steps" :key="step.id">
                <div class="prs-num">{{idx+1}}</div>
                <div class="prs-op">
                  <div class="prs-code">{{step.op_code || step.op_number}}</div>
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
              <button class="pr-add-step" @click="openAddStep(p.product_code, p.product_name, route.route, null)">+ Étape</button>
            </div>
          </div>
          <button class="pc-add-route" v-if="!p.has_route_2"
            @click="openAddStep(p.product_code, p.product_name, 2, null)">
            + Ajouter Route 2
          </button>
        </div>
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
              <option v-for="op in opOptions" :key="op.op_number" :value="op.op_number">
                {{op.op_number}} — {{op.op_code}}
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

    <!-- ── MODAL GOOGLE SHEETS IMPORT ── -->
    <div class="modal-overlay" v-if="gsModal.open" @click.self="gsModal.open=false">
      <div class="modal-box modal-wide">
        <div class="modal-hd">↑ Import Google Sheets / CSV<span class="mh-sub"> — product_flux</span></div>
        <div class="modal-body">
          <div class="mf-row">
            <label>URL Google Sheets (export CSV public)</label>
            <div style="display:flex;gap:8px">
              <input class="mf-input" v-model="gsModal.url"
                placeholder="https://docs.google.com/spreadsheets/d/…/export?format=csv" style="flex:1"/>
              <button class="mb-ok" @click="loadGsCsv" :disabled="gsModal.fetching" style="flex-shrink:0">
                {{gsModal.fetching ? '…' : 'Charger'}}
              </button>
            </div>
            <div class="mf-opt" style="font-size:10px;margin-top:4px">
              Format CSV : <code>product_code,product_name,route,op_number,room_code</code>
            </div>
          </div>
          <div class="mf-row">
            <label>Ou collez le contenu CSV directement</label>
            <textarea class="mf-input" v-model="gsModal.csvText" rows="6"
              placeholder="product_code,product_name,route,op_number,room_code&#10;PFABB10,Produit X,1,210,p464"></textarea>
          </div>
          <button class="mb-ok" @click="parseGsCsv" style="margin-top:4px;width:auto;padding:6px 16px">Prévisualiser</button>
          <div class="mf-err" v-if="gsModal.err">{{gsModal.err}}</div>
          <div v-if="gsModal.preview.length" style="margin-top:12px">
            <div style="font-size:11px;font-weight:700;color:#6b7280;margin-bottom:6px;text-transform:uppercase;letter-spacing:1px">
              Aperçu — {{gsModal.preview.length}} ligne{{gsModal.preview.length!==1?'s':''}}
            </div>
            <div class="table-wrap" style="max-height:200px;overflow-y:auto">
              <table class="cad-table">
                <thead><tr><th>code_produit</th><th>nom_produit</th><th>Route</th><th>Op#</th><th>Salle</th></tr></thead>
                <tbody>
                  <tr v-for="(r,i) in gsModal.preview" :key="i">
                    <td><span class="cad-prod-code">{{r.product_code}}</span></td>
                    <td style="font-size:11px;color:#6b7280">{{r.product_name}}</td>
                    <td><span class="room-chip">R{{r.route}}</span></td>
                    <td><span class="op-num">{{r.op_number}}</span></td>
                    <td>{{r.room_code||'flexible'}}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
        <div class="modal-ft">
          <button class="mb-cancel" @click="gsModal.open=false">Annuler</button>
          <button class="mb-ok" @click="confirmGsImport" :disabled="gsModal.saving||!gsModal.preview.length">
            {{gsModal.saving ? 'Import en cours…' : 'Confirmer import ('+gsModal.preview.length+' lignes)'}}
          </button>
        </div>
      </div>
    </div>

  </div>
</template>

<script>
import { ref, computed, onMounted, reactive } from 'vue'
import { supabase } from '../../supabase'
import { getAll as gsGetAll, clearCache as gsClearCache } from '../../services/googleSheets'

// Labels des groupes d'opérations
var OP_LABELS = {
  210: 'PESÉE',
  220: 'GRANULATION',
  230: 'MÉLANGE',
  240: 'COMPRESSION',
  250: 'PELLICULAGE',
  260: 'GÉLULES',
  270: 'CRÈME / POMMADE',
  310: 'COND. PRIMAIRE',
  320: 'COND. SECONDAIRE',
  330: 'INJECTABLES'
}

export default {
  setup() {
    var fluxSearch     = ref('')
    var fluxTypeFilter = ref('')
    var fluxView       = ref('pivot')
    var fluxLoading    = ref(false)
    var gsReloading    = ref(false)

    var productsSummary = ref([])
    var allFluxRows     = ref([])
    var opMaster        = ref([])
    var planRooms       = ref([])   // plan_rooms avec op_number renseigné

    // ── MODALS ──────────────────────────────────────────────────
    var gsModal = reactive({
      open: false, url: '', csvText: '', fetching: false, saving: false, err: '', preview: []
    })
    var stepModal = reactive({
      open: false, id: null, saving: false, err: '',
      product_code: '', product_name: '', route: 1, op_number: '', room_code: ''
    })

    // ── PRODUITS / FLUX ──────────────────────────────────────────
    var groupedProducts = computed(function() {
      var map = new Map()
      allFluxRows.value.forEach(function(row) {
        if (!map.has(row.product_code)) {
          map.set(row.product_code, {
            product_code: row.product_code, product_name: row.product_name,
            routes: {}, type_flux: 'COM_SEC', has_route_2: false
          })
        }
        var prod = map.get(row.product_code)
        if (!prod.routes[row.route]) prod.routes[row.route] = []
        prod.routes[row.route].push(row)
        if (row.route === 2) prod.has_route_2 = true
      })
      productsSummary.value.forEach(function(s) {
        if (map.has(s.product_code)) map.get(s.product_code).type_flux = s.type_flux
      })
      return Array.from(map.values()).map(function(p) {
        return Object.assign({}, p, {
          routes: Object.entries(p.routes).map(function(e) {
            return { route: parseInt(e[0]), steps: e[1].slice().sort(function(a, b) { return a.op_number - b.op_number }) }
          }).sort(function(a, b) { return a.route - b.route })
        })
      }).sort(function(a, b) { return a.product_code.localeCompare(b.product_code) })
    })

    var filteredProducts = computed(function() {
      var q = fluxSearch.value.toLowerCase()
      return groupedProducts.value.filter(function(p) {
        return (!q || p.product_code.toLowerCase().includes(q) || p.product_name.toLowerCase().includes(q)) &&
               (!fluxTypeFilter.value || p.type_flux === fluxTypeFilter.value)
      })
    })

    // ── PIVOT MACHINES ───────────────────────────────────────────
    // Colonnes : plan_rooms triées par op_number puis nom
    var machineColsFlat = computed(function() {
      return planRooms.value
        .filter(function(r) { return r.op_number != null && r.actif !== false })
        .slice()
        .sort(function(a, b) {
          if (a.op_number !== b.op_number) return a.op_number - b.op_number
          return (a.nom || '').localeCompare(b.nom || '')
        })
    })

    // Groupes par op_number pour l'en-tête fusionné
    var machineColGroups = computed(function() {
      var groups = []
      var cur = null
      machineColsFlat.value.forEach(function(r) {
        if (!cur || cur.op_number !== r.op_number) {
          cur = { op_number: r.op_number, label: OP_LABELS[r.op_number] || ('OP' + r.op_number), rooms: [] }
          groups.push(cur)
        }
        cur.rooms.push(r)
      })
      return groups
    })

    // Lignes : produit + route + set des room_codes actifs
    var pivotMachineRows = computed(function() {
      var validCodes = new Set(machineColsFlat.value.map(function(r) { return r.code }))
      var rows = []
      filteredProducts.value.forEach(function(p) {
        p.routes.forEach(function(r) {
          var activeSet = new Set()
          r.steps.forEach(function(s) {
            if (s.room_code && validCodes.has(s.room_code)) activeSet.add(s.room_code)
          })
          rows.push({
            product_code: p.product_code, product_name: p.product_name,
            type_flux: p.type_flux, route: r.route, activeRoomCodes: activeSet
          })
        })
      })
      return rows
    })

    // Clic case à cocher → toggle product_flux
    var toggleMachineFlux = async function(row, room) {
      var isActive = row.activeRoomCodes.has(room.code)
      if (isActive) {
        await supabase.from('product_flux').delete()
          .eq('product_code', row.product_code)
          .eq('route', row.route)
          .eq('op_number', room.op_number)
          .eq('room_code', room.code)
      } else {
        await supabase.from('product_flux').insert({
          product_code: row.product_code,
          product_name: row.product_name,
          op_number: room.op_number,
          route: row.route,
          room_code: room.code
        })
      }
      await loadAll()
    }

    // ── MODAL STEP ───────────────────────────────────────────────
    var opOptions = computed(function() {
      var seen = new Set()
      return opMaster.value.filter(function(m) {
        if (seen.has(m.op_number)) return false
        seen.add(m.op_number); return true
      }).sort(function(a, b) { return a.op_number - b.op_number })
    })

    var roomsForOp = computed(function() {
      if (!stepModal.op_number) return []
      return opMaster.value.filter(function(m) { return m.op_number === parseInt(stepModal.op_number) })
    })

    var getRoomName = function(code) {
      var pr = planRooms.value.find(function(r) { return r.code === code })
      if (pr) return pr.nom
      var m = opMaster.value.find(function(m) { return m.room_code === code })
      return m ? m.equipment_name : '—'
    }

    var onOpChange = function() { stepModal.room_code = '' }

    var openNewFlux = function() {
      stepModal.open = true; stepModal.id = null; stepModal.err = ''
      stepModal.product_code = ''; stepModal.product_name = ''
      stepModal.route = 1; stepModal.op_number = ''; stepModal.room_code = ''
    }

    var openAddStep = function(code, name, route, opNum) {
      stepModal.open = true; stepModal.id = null; stepModal.err = ''
      stepModal.product_code = code; stepModal.product_name = name
      stepModal.route = route; stepModal.op_number = opNum || ''; stepModal.room_code = ''
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
      var pname = stepModal.product_name
      if (!pname) {
        var found = allFluxRows.value.find(function(r) { return r.product_code === stepModal.product_code })
        pname = found ? found.product_name : stepModal.product_code
      }
      var payload = {
        product_code: stepModal.product_code.trim(), product_name: pname,
        op_number: parseInt(stepModal.op_number), route: stepModal.route,
        room_code: stepModal.room_code || null
      }
      var res = stepModal.id
        ? await supabase.from('product_flux').update(payload).eq('id', stepModal.id)
        : await supabase.from('product_flux').insert(payload)
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

    // ── GOOGLE SHEETS IMPORT ─────────────────────────────────────
    var openGsImport = function() {
      Object.assign(gsModal, { open: true, url: '', csvText: '', fetching: false, saving: false, err: '', preview: [] })
    }

    var loadGsCsv = async function() {
      if (!gsModal.url.trim()) { gsModal.err = 'URL requise.'; return }
      gsModal.fetching = true; gsModal.err = ''
      try {
        var r = await fetch(gsModal.url.trim())
        if (!r.ok) throw new Error('HTTP ' + r.status)
        gsModal.csvText = await r.text(); gsModal.err = ''
      } catch (e) {
        gsModal.err = 'Impossible de charger l\'URL : ' + e.message + '. Copiez-collez le CSV directement.'
      }
      gsModal.fetching = false
    }

    var parseGsCsv = function() {
      gsModal.err = ''; gsModal.preview = []
      var text = gsModal.csvText.trim()
      if (!text) { gsModal.err = 'Contenu CSV vide.'; return }
      var lines = text.split(/\r?\n/).filter(function(l) { return l.trim() })
      if (lines.length < 2) { gsModal.err = 'CSV trop court.'; return }
      var startIdx = 0
      var header = lines[0].split(',').map(function(h) { return h.trim().toLowerCase() })
      if (header.includes('product_code') || header.includes('code_produit')) startIdx = 1
      var rows = []
      for (var i = startIdx; i < lines.length; i++) {
        var cols = lines[i].split(',')
        var pcode = (cols[0] || '').trim()
        var pname = (cols[1] || '').trim()
        var route = parseInt((cols[2] || '1').trim())
        var opNum = parseInt((cols[3] || '').trim())
        var room  = (cols[4] || '').trim() || null
        if (!pcode || isNaN(opNum)) continue
        rows.push({ product_code: pcode, product_name: pname, route: isNaN(route) ? 1 : route, op_number: opNum, room_code: room })
      }
      if (!rows.length) { gsModal.err = 'Aucune ligne valide trouvée.'; return }
      gsModal.preview = rows
    }

    var confirmGsImport = async function() {
      if (!gsModal.preview.length) return
      gsModal.saving = true; gsModal.err = ''
      var groups = {}
      gsModal.preview.forEach(function(r) {
        var k = r.product_code + '_' + r.route
        if (!groups[k]) groups[k] = { product_code: r.product_code, route: r.route, rows: [] }
        groups[k].rows.push(r)
      })
      var keys = Object.keys(groups)
      for (var i = 0; i < keys.length; i++) {
        var g = groups[keys[i]]
        await supabase.from('product_flux').delete().eq('product_code', g.product_code).eq('route', g.route)
        await supabase.from('product_flux').insert(g.rows.map(function(r) {
          return { product_code: r.product_code, product_name: r.product_name || r.product_code, op_number: r.op_number, route: r.route, room_code: r.room_code || null }
        }))
      }
      gsModal.saving = false; gsModal.open = false
      await loadAll()
    }

    // ── RELOAD GS ────────────────────────────────────────────────
    var reloadGs = async function() {
      gsReloading.value = true
      gsClearCache()
      await loadAll()
      gsReloading.value = false
    }

    // ── LOAD ─────────────────────────────────────────────────────
    var loadAll = async function() {
      fluxLoading.value = true
      var [gsData, r0, r1] = await Promise.all([
        gsGetAll(),
        supabase.from('product_flux').select('*').order('product_code').order('route').order('op_number'),
        supabase.from('v_product_flux_summary').select('*'),
      ])
      // operations_master et plan_rooms chargés depuis Google Sheets
      opMaster.value  = gsData.operationsMaster
      planRooms.value = gsData.planRooms
        .filter(function(r){ return r.op_number != null })
        .slice()
        .sort(function(a, b) {
          if (a.op_number !== b.op_number) return a.op_number - b.op_number
          return (a.nom || '').localeCompare(b.nom || '')
        })
      if (!r0.error) allFluxRows.value     = r0.data
      if (!r1.error) productsSummary.value = r1.data
      fluxLoading.value = false
    }

    onMounted(loadAll)

    return {
      fluxSearch, fluxTypeFilter, fluxView, fluxLoading,
      gsReloading, reloadGs,
      filteredProducts, opMaster, opOptions, roomsForOp,
      machineColsFlat, machineColGroups, pivotMachineRows,
      stepModal, gsModal,
      getRoomName, onOpChange,
      openNewFlux, openAddStep, openEditStep, saveStep, deleteStep,
      toggleMachineFlux,
      openGsImport, loadGsCsv, parseGsCsv, confirmGsImport,
    }
  }
}
</script>

<style scoped>
.flux-admin { padding: 20px; max-width: 100%; font-family: 'Inter', sans-serif; }
.fa-header { margin-bottom: 20px; display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; }
.fa-title { font-size: 18px; font-weight: 800; color: #1a1a2e; }
.fa-sub { font-size: 12px; color: #6b7280; margin-top: 4px; }
.fa-btn-gs-reload {
  padding: 7px 14px; font-size: 12px; font-weight: 600;
  border: 1px solid #d1d5db; background: #f9fafb; color: #374151;
  border-radius: 4px; cursor: pointer; white-space: nowrap; flex-shrink: 0;
  transition: background .15s;
}
.fa-btn-gs-reload:hover:not(:disabled) { background: #e5e7eb; }
.fa-btn-gs-reload:disabled { opacity: .5; cursor: not-allowed; }
@keyframes fa-spin { from { transform: rotate(0) } to { transform: rotate(360deg) } }
.fa-btn-gs-reload.spinning { animation: fa-spin .7s linear infinite; }

/* Toolbar */
.tb-toolbar { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 16px; flex-wrap: wrap; }
.tb-search-wrap { display: flex; align-items: center; gap: 8px; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px; padding: 6px 12px; min-width: 280px; }
.ts-icon { color: #9ca3af; }
.tb-search { border: none; background: transparent; outline: none; font-size: 13px; flex: 1; }
.tb-filters { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
.tb-sel { border: 1px solid #e5e7eb; border-radius: 5px; padding: 6px 10px; font-size: 12px; color: #374151; }
.tb-btn-add { background: #7c3aed; border: none; border-radius: 5px; color: #fff; padding: 7px 14px; font-size: 12px; font-weight: 600; cursor: pointer; }
.tb-btn-add:hover { background: #6d28d9; }
.tb-btn-gs { background: #059669; border: none; border-radius: 5px; color: #fff; padding: 7px 12px; font-size: 11px; font-weight: 600; cursor: pointer; white-space: nowrap; }
.tb-btn-gs:hover { background: #047857; }
.view-toggle { display: flex; border: 1px solid #e5e7eb; border-radius: 5px; overflow: hidden; }
.vt-btn { border: none; background: #f9fafb; color: #6b7280; font-size: 11px; padding: 5px 10px; cursor: pointer; font-weight: 600; }
.vt-btn.active { background: #7c3aed; color: #fff; }

/* ═══ PIVOT MACHINES ═══════════════════════════════════════════ */
.table-scroll {
  overflow: auto;
  max-height: calc(100vh - 230px);
  border: 1px solid #e5e7eb;
  border-radius: 8px;
}

.pivot-table {
  border-collapse: separate;
  border-spacing: 0;
  font-size: 12px;
  min-width: 100%;
}

/* ── Ligne 1 : groupes op ── */
.pt-r-op th {
  position: sticky;
  top: 0;
  z-index: 4;
  background: #f5f3ff;
  padding: 7px 10px;
  text-align: center;
  border-bottom: 1px solid #ede9fe;
  border-right: 1px solid #ede9fe;
  white-space: nowrap;
}

/* ── Ligne 2 : noms machines ── */
.pt-r-mach th {
  position: sticky;
  top: 38px;
  z-index: 3;
  background: #faf5ff;
  padding: 5px 4px;
  text-align: center;
  border-bottom: 2px solid #7c3aed;
  border-right: 1px solid #ede9fe;
  font-size: 10px;
  font-weight: 600;
  color: #4b5563;
  white-space: nowrap;
  min-width: 52px;
  max-width: 80px;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* ── Colonnes fixes (Produit / Type / R) ── */
.pt-sc { position: sticky; background: inherit; }
.pt-sc1 { left: 0; }
.pt-sc2 { left: 160px; }
.pt-sc3 { left: 250px; border-right: 2px solid #c4b5fd !important; }

/* bump z-index pour que les coins restent au-dessus */
.pt-r-op .pt-sc  { z-index: 6 !important; }
.pt-r-mach .pt-sc { z-index: 5 !important; }

/* body sticky cols */
.pivot-table tbody .pt-sc { z-index: 1; background: #fff; }
.pivot-table tbody .pt-r2 .pt-sc { background: #fafafa; }

/* ── En-têtes op ── */
.pt-h-prod { min-width: 160px; text-align: left !important; }
.pt-h-type { min-width: 90px; text-align: left !important; }
.pt-h-r    { width: 40px; text-align: center !important; }
.pt-h-grp  { text-align: center; }
.ptg-num   { display: block; font-family: monospace; font-size: 12px; font-weight: 800; color: #7c3aed; }
.ptg-lbl   { display: block; font-size: 9px; color: #9ca3af; margin-top: 1px; text-transform: uppercase; letter-spacing: .5px; }

/* ── Body rows ── */
.pivot-table td {
  padding: 5px 6px;
  border-bottom: 1px solid #f3f4f6;
  border-right: 1px solid #f3f4f6;
  vertical-align: middle;
}
.pt-r2 { background: #fafafa; }
.pt-prod-cell { min-width: 160px; }
.pt-pcode { font-family: monospace; font-size: 11px; font-weight: 800; color: #7c3aed; }
.pt-pname { font-size: 10px; color: #6b7280; margin-top: 1px; }
.pt-route-num { text-align: center; font-family: monospace; font-size: 11px; font-weight: 700; color: #374151; }

/* ── Case à cocher ── */
.pt-cc {
  text-align: center;
  cursor: pointer;
  min-width: 52px;
  padding: 4px 2px;
  transition: background .1s;
}
.pt-cc:hover { background: #faf5ff; }

.pt-cb {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  border-radius: 4px;
  border: 1.5px solid #d1d5db;
  transition: all .12s;
  flex-shrink: 0;
}
.pt-cb.on {
  background: #7c3aed;
  border-color: #7c3aed;
}
.pt-cb.on::after {
  content: '✓';
  color: #fff;
  font-size: 12px;
  font-weight: 800;
  line-height: 1;
}
.pt-cc:hover .pt-cb:not(.on) {
  border-color: #a78bfa;
  background: #f5f3ff;
}

/* ═══ VUE FICHES ════════════════════════════════════════════════ */
.products-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(380px, 1fr)); gap: 16px; }
.prod-card { background: #fff; border: 1px solid #e5e7eb; border-radius: 8px; padding: 14px; }
.pc-hd { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px; }
.pc-code { font-size: 11px; font-weight: 800; color: #7c3aed; font-family: monospace; }
.pc-name { font-size: 12px; color: #374151; margin-top: 2px; }
.pc-badges { display: flex; flex-direction: column; gap: 4px; align-items: flex-end; }
.pc-type { font-size: 9px; font-weight: 700; padding: 2px 6px; border-radius: 3px; }
.pct-COM_PELLI { background: #ede9fe; color: #7c3aed; }
.pct-COM_SEC { background: #d1fae5; color: #065f46; }
.pct-GLE { background: #fef3c7; color: #92400e; }
.pct-CREME_POMMADE { background: #dbeafe; color: #1e40af; }
.pct-OTC { background: #f3f4f6; color: #6b7280; }
.pc-routes { font-size: 9px; color: #9ca3af; background: #f3f4f6; padding: 2px 5px; border-radius: 3px; }
.pc-routes-wrap { margin-bottom: 10px; }
.pr-label { font-size: 9px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; color: #9ca3af; margin-bottom: 6px; }
.pr-steps { display: flex; flex-direction: column; gap: 4px; }
.pr-step { display: flex; align-items: center; gap: 8px; padding: 5px 8px; background: #f9fafb; border-radius: 4px; }
.prs-num { width: 18px; height: 18px; background: #e5e7eb; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 9px; font-weight: 700; color: #6b7280; flex-shrink: 0; }
.prs-op { flex: 1; }
.prs-code { font-size: 11px; font-weight: 700; color: #374151; }
.prs-room { font-size: 10px; color: #9ca3af; display: flex; align-items: center; gap: 4px; }
.prs-room-code { background: #ede9fe; color: #7c3aed; border-radius: 2px; padding: 0 3px; font-size: 9px; font-family: monospace; font-weight: 700; }
.prs-flex { font-style: italic; }
.prs-actions { display: flex; gap: 4px; }
.prs-btn { background: none; border: 1px solid #e5e7eb; border-radius: 3px; color: #9ca3af; cursor: pointer; font-size: 10px; padding: 2px 5px; }
.prs-btn:hover { color: #374151; border-color: #9ca3af; }
.prs-del:hover { color: #ef4444; border-color: #ef4444; }
.pr-add-step { background: none; border: 1px dashed #d1d5db; border-radius: 4px; color: #9ca3af; cursor: pointer; font-size: 10px; padding: 4px; text-align: center; width: 100%; }
.pr-add-step:hover { border-color: #7c3aed; color: #7c3aed; background: #faf5ff; }
.pc-add-route { background: none; border: 1px dashed #c4b5fd; border-radius: 4px; color: #7c3aed; cursor: pointer; font-size: 10px; padding: 5px; width: 100%; text-align: center; margin-top: 6px; }
.pc-add-route:hover { background: #faf5ff; }

/* ═══ CADENCES ══════════════════════════════════════════════════ */
.cad-table-wrap { overflow-x: auto; }
.cad-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.cad-table th { background: #f9fafb; padding: 10px 14px; text-align: left; font-size: 11px; font-weight: 700; color: #6b7280; border-bottom: 1px solid #e5e7eb; }
.cad-table td { padding: 10px 14px; border-bottom: 1px solid #f3f4f6; vertical-align: middle; }
.room-chip { background: #ede9fe; color: #7c3aed; font-family: monospace; font-size: 11px; font-weight: 700; padding: 2px 7px; border-radius: 3px; }
.op-num { background: #e0e7ff; color: #3730a3; font-family: monospace; font-size: 11px; font-weight: 700; padding: 2px 7px; border-radius: 3px; }
.op-code { background: #f0fdf4; color: #065f46; font-size: 11px; font-weight: 700; padding: 2px 7px; border-radius: 3px; }
.unit-chip { background: #f3f4f6; color: #374151; font-size: 10px; padding: 2px 6px; border-radius: 3px; }
.cad-val { font-family: monospace; font-weight: 700; color: #1f2937; }
.cad-notes { color: #9ca3af; font-size: 11px; max-width: 180px; }
.cad-prod-code { font-family: monospace; font-size: 11px; font-weight: 700; color: #7c3aed; }

/* ═══ MESSAGES ══════════════════════════════════════════════════ */
.empty-row { text-align: center; color: #9ca3af; font-style: italic; padding: 32px; }
.loading-row { text-align: center; color: #9ca3af; padding: 32px; }
/* ═══ MODALS ════════════════════════════════════════════════════ */
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.5); z-index: 200; display: flex; align-items: center; justify-content: center; }
.modal-box { background: #fff; border-radius: 10px; width: 460px; max-width: 95vw; box-shadow: 0 20px 50px rgba(0,0,0,.2); }
.modal-wide { width: min(95vw, 640px); }
.modal-hd { padding: 16px 20px 12px; font-size: 14px; font-weight: 800; color: #111827; border-bottom: 1px solid #f3f4f6; }
.mh-sub { color: #9ca3af; font-weight: 400; font-size: 12px; }
.modal-body { padding: 16px 20px; display: flex; flex-direction: column; gap: 12px; }
.mf-row { display: flex; flex-direction: column; gap: 4px; }
.mf-row label { font-size: 10px; color: #6b7280; letter-spacing: 1px; text-transform: uppercase; font-weight: 700; }
.mf-opt { color: #9ca3af; font-style: italic; text-transform: none; letter-spacing: 0; font-weight: 400; }
.mf-input { border: 1px solid #e5e7eb; border-radius: 5px; color: #111827; font-size: 12px; padding: 8px 10px; outline: none; width: 100%; box-sizing: border-box; }
.mf-input:focus { border-color: #7c3aed; }
.mf-err { font-size: 11px; color: #ef4444; background: #fef2f2; border-radius: 4px; padding: 6px 10px; }
.modal-ft { display: flex; justify-content: flex-end; gap: 8px; padding: 12px 20px; border-top: 1px solid #f3f4f6; }
.mb-cancel { background: transparent; border: 1px solid #e5e7eb; border-radius: 5px; color: #6b7280; padding: 7px 16px; font-size: 12px; cursor: pointer; }
.mb-ok { background: #7c3aed; border: none; border-radius: 5px; color: #fff; padding: 7px 16px; font-size: 12px; cursor: pointer; font-weight: 700; }
.mb-ok:hover:not(:disabled) { background: #6d28d9; }
.mb-ok:disabled { opacity: .4; cursor: not-allowed; }
.lot-search-wrap { position: relative; }
.lot-dropdown { position: absolute; top: 100%; left: 0; right: 0; background: #fff; border: 1px solid #e5e7eb; border-radius: 6px; z-index: 10; max-height: 180px; overflow-y: auto; box-shadow: 0 4px 12px rgba(0,0,0,.1); margin-top: 2px; }
.ld-item { padding: 8px 12px; font-size: 11px; color: #374151; cursor: pointer; border-bottom: 1px solid #f3f4f6; }
.ld-item:hover { background: #f5f3ff; }
.lot-chip { font-size: 11px; color: #059669; background: #d1fae5; border-radius: 4px; padding: 4px 10px; margin-top: 4px; }
.table-wrap { overflow-x: auto; -webkit-overflow-scrolling: touch; }
.gs-row-err { background: #fef2f2; }

/* ═══ RESPONSIVE ════════════════════════════════════════════════ */
@media (max-width: 768px) {
  .fa-tabs { flex-wrap: wrap; }
  .fa-tab { flex: 1; min-height: 40px; font-size: 12px; padding: 8px 6px; }
  .tb-toolbar { flex-direction: column; }
  .tb-filters { flex-direction: column; width: 100%; }
  .products-grid { grid-template-columns: 1fr; }
  .table-scroll { max-height: calc(100vh - 180px); }
}
</style>
