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
          <div class="view-toggle">
            <button class="vt-btn" :class="{active:fluxView==='pivot'}" @click="fluxView='pivot'" title="Vue tableau croisé machines">⊞ Pivot</button>
            <button class="vt-btn" :class="{active:fluxView==='cards'}" @click="fluxView='cards'" title="Vue fiches">▤ Fiches</button>
          </div>
          <button class="tb-btn-gs" @click="openGsImport">↑ Google Sheets</button>
          <button class="tb-btn-add" @click="openNewFlux">+ Nouveau flux</button>
          <button class="tb-btn-clear" @click="clearFlux" title="Vider tous les flux importés">🗑 Vider l'import</button>
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
              <th class="pt-sc pt-sc0"><input type="checkbox" :checked="allRowsSelected" @change="toggleAllSelect" class="pt-chkbox" /></th>
              <th class="pt-h-prod pt-sc pt-sc1">Produit</th>
              <th class="pt-h-r    pt-sc pt-sc2">R</th>
              <th v-for="g in machineColGroups" :key="g.op_number"
                  :colspan="g.rooms.length" class="pt-h-grp">
                <span class="ptg-num">{{g.op_number}}</span>
                <span class="ptg-lbl">{{g.label}}</span>
              </th>
            </tr>
            <!-- Ligne 2 : noms machines -->
            <tr class="pt-r-mach">
              <th class="pt-sc pt-sc0"></th>
              <th class="pt-sc pt-sc1"></th>
              <th class="pt-sc pt-sc2"></th>
              <th v-for="room in machineColsFlat" :key="room.code" class="pt-h-mach">{{room.nom}}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in pivotMachineRows" :key="row.product_code+'_'+row.route"
                :class="{'pt-r2':row.route===2, 'pt-sel':isRowSelected(row)}">
              <td class="pt-chk pt-sc pt-sc0">
                <input type="checkbox" :checked="isRowSelected(row)" @change="toggleSelectRow(row)" class="pt-chkbox" />
              </td>
              <td class="pt-prod-cell pt-sc pt-sc1">
                <div class="pt-pcode">{{row.product_code}}</div>
                <div class="pt-pname">{{row.product_name}}</div>
              </td>
              <td class="pt-route-num pt-sc pt-sc2">R{{row.route}}</td>
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

    <!-- ── BARRE SÉLECTION MULTIPLE (fixe en bas) ── -->
    <transition name="bulk-slide">
      <div class="bulk-assign-bar" v-if="selectedRows.length">
        <span class="ba-count">{{selectedRows.length}} produit(s) sélectionné(s)</span>
        <select v-model="bulkRoom" class="ba-sel">
          <option :value="null">— Choisir une machine —</option>
          <optgroup v-for="g in machineColGroups" :key="g.op_number" :label="g.op_number+' — '+g.label">
            <option v-for="r in g.rooms" :key="r.code" :value="r">{{r.nom}}</option>
          </optgroup>
        </select>
        <button class="ba-btn ba-on" :disabled="!bulkRoom" @click="bulkAssign(true)">✓ Cocher</button>
        <button class="ba-btn ba-off" :disabled="!bulkRoom" @click="bulkAssign(false)">✕ Décocher</button>
        <button class="ba-clear" @click="selectedRows=[]">✕ Tout désélectionner</button>
      </div>
    </transition>

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

// Labels des groupes d'opérations
var OP_LABELS = {
  210: 'PESÉE',
  220: 'GRANULATION',
  230: 'MÉLANGE',
  240: 'COMPRESSION',
  250: 'PELLICULAGE',
  260: 'GÉLULES',
  270: 'CRÈME / POMMADE'
  // op 310-380 = conditionnement (libellé « CONDITIONNEMENT » via fallback dans machineColGroups)
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

    // ── Sélection multiple ────────────────────────────────────────
    var selectedRows = ref([])   // array de "product_code||route"
    var bulkRoom     = ref(null)
    var rowKey = function(row) { return row.product_code + '||' + row.route }
    var isRowSelected = function(row) { return selectedRows.value.indexOf(rowKey(row)) >= 0 }
    var toggleSelectRow = function(row) {
      var k = rowKey(row), idx = selectedRows.value.indexOf(k)
      if (idx >= 0) selectedRows.value.splice(idx, 1); else selectedRows.value.push(k)
    }
    var allRowsSelected = computed(function() {
      return pivotMachineRows.value.length > 0 &&
        pivotMachineRows.value.every(function(r) { return isRowSelected(r) })
    })
    var toggleAllSelect = function() {
      if (allRowsSelected.value) selectedRows.value = []
      else selectedRows.value = pivotMachineRows.value.map(rowKey)
    }
    var bulkAssign = async function(assign) {
      if (!bulkRoom.value || !selectedRows.value.length) return
      var room = bulkRoom.value
      var toInsert = [], toDelete = []
      selectedRows.value.forEach(function(k) {
        var parts = k.split('||'), pcode = parts[0], route = parseInt(parts[1])
        var row = pivotMachineRows.value.find(function(r) { return r.product_code === pcode && r.route === route })
        if (!row) return
        if (assign && !row.activeRoomCodes.has(room.code))
          toInsert.push({ product_code: pcode, product_name: row.product_name, op_number: room.op_number, route: route, room_code: room.code })
        else if (!assign && row.activeRoomCodes.has(room.code))
          toDelete.push({ pcode: pcode, route: route })
      })
      if (toInsert.length) {
        await supabase.from('product_flux').insert(toInsert)
        toInsert.forEach(function(r) { allFluxRows.value.push(Object.assign({ id: Date.now() }, r)) })
      }
      if (toDelete.length) {
        var pcodes = toDelete.map(function(d) { return d.pcode })
        await supabase.from('product_flux').delete().in('product_code', pcodes).eq('op_number', room.op_number).eq('room_code', room.code)
        toDelete.forEach(function(d) {
          var idx = allFluxRows.value.findIndex(function(fr) {
            return fr.product_code === d.pcode && fr.route === d.route && fr.op_number === room.op_number && fr.room_code === room.code
          })
          if (idx >= 0) allFluxRows.value.splice(idx, 1)
        })
      }
    }
    var opMaster        = ref([])
    var planRooms       = ref([])   // plan_rooms avec op_number renseigné

    // ── MODALS ──────────────────────────────────────────────────
    // URL par défaut de la feuille « Flux produits » (Google Sheets publié en CSV) — contient tous les produits
    var GS_FLUX_URL_DEFAULT = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vQqKb5_i0U7YeQYMiNEDy4X2gq6W_78NA2EuC2gRqSVXOKuBcBuXR8ASrE9Eq3admceATv4_gdAUppc/pub?gid=2014351149&single=true&output=csv'
    var gsModal = reactive({
      open: false, url: GS_FLUX_URL_DEFAULT, csvText: '', fetching: false, saving: false, err: '', preview: []
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
        return !q || p.product_code.toLowerCase().includes(q) || p.product_name.toLowerCase().includes(q)
      })
    })

    // ── PIVOT MACHINES ───────────────────────────────────────────
    // Colonnes : plan_rooms triées par op_number puis nom
    var machineColsFlat = computed(function() {
      // op_number depuis operations_master (liaison op×machine du référentiel) — plan_rooms regroupe à tort les cond sous 310
      var opByRoom = {}
      opMaster.value.forEach(function(om) { if (om.room_code) opByRoom[om.room_code] = om.op_number })
      return planRooms.value
        // n'afficher que les machines réellement référencées dans operations_master
        // (exclut les salles résiduelles de plan_rooms : Formulation, Remplissage Tubes, Cond. Sec., Réception Injectables…)
        .filter(function(r) { return r.actif !== false && opByRoom[r.code] != null })
        .map(function(r) {
          return Object.assign({}, r, { op_number: opByRoom[r.code] })
        })
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
          cur = { op_number: r.op_number, label: OP_LABELS[r.op_number] || (r.op_number >= 300 ? 'CONDITIONNEMENT' : ('OP' + r.op_number)), rooms: [] }
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

    // Clic case à cocher → toggle product_flux (mise à jour locale, pas de loadAll)
    var toggleMachineFlux = async function(row, room) {
      var isActive = row.activeRoomCodes.has(room.code)
      if (isActive) {
        await supabase.from('product_flux').delete()
          .eq('product_code', row.product_code).eq('route', row.route)
          .eq('op_number', room.op_number).eq('room_code', room.code)
        var idx = allFluxRows.value.findIndex(function(fr) {
          return fr.product_code === row.product_code && fr.route === row.route &&
                 fr.op_number === room.op_number && fr.room_code === room.code
        })
        if (idx >= 0) allFluxRows.value.splice(idx, 1)
      } else {
        await supabase.from('product_flux').insert({
          product_code: row.product_code, product_name: row.product_name,
          op_number: room.op_number, route: row.route, room_code: room.code
        })
        allFluxRows.value.push({
          id: Date.now(), product_code: row.product_code, product_name: row.product_name,
          op_number: room.op_number, route: row.route, room_code: room.code
        })
      }
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

    // ── VIDER L'IMPORT ────────────────────────────────────────────
    var clearFlux = async function() {
      if (!confirm('Vider tous les flux produits importés ?\nCette action est irréversible.')) return
      var res = await supabase.from('product_flux').delete().neq('id', 0)
      if (res.error) { alert('Erreur : ' + res.error.message); return }
      await loadAll()
    }

    // ── GOOGLE SHEETS IMPORT ─────────────────────────────────────
    var openGsImport = function() {
      Object.assign(gsModal, { open: true, url: GS_FLUX_URL_DEFAULT, csvText: '', fetching: false, saving: false, err: '', preview: [] })
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

    // Parse une ligne CSV en gérant les guillemets et les virgules internes (ex. "ATOSTINE® 10mg, COM PELLI")
    var parseCsvLine = function(line) {
      var result = [], inQuote = false, cur = ''
      for (var i = 0; i < line.length; i++) {
        var c = line[i]
        if (c === '"' && inQuote && line[i + 1] === '"') { cur += '"'; i++ }
        else if (c === '"') { inQuote = !inQuote }
        else if (c === ',' && !inQuote) { result.push(cur); cur = '' }
        else { cur += c }
      }
      result.push(cur)
      return result
    }

    var parseGsCsv = function() {
      gsModal.err = ''; gsModal.preview = []
      var text = gsModal.csvText.trim()
      if (!text) { gsModal.err = 'Contenu CSV vide.'; return }
      var lines = text.split(/\r?\n/).filter(function(l) { return l.trim() })
      if (lines.length < 2) { gsModal.err = 'CSV trop court.'; return }

      // ── Détection entête flexible ──────────────────────────────
      var norm = function(s) { return (s||'').trim().toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'') }
      var header = parseCsvLine(lines[0]).map(norm)
      var hasHeader = header.some(function(h) {
        return ['product_code','code_produit','code_article','product_name','description','op_number','numero','operation'].includes(h)
      })
      var startIdx = hasHeader ? 1 : 0

      // Mapping colonnes par nom (priorité) ou par position (fallback)
      var iCode  = Math.max(header.indexOf('product_code'), header.indexOf('code_produit'), header.indexOf('code_article'), 0)
      var iName  = Math.max(header.indexOf('product_name'), header.indexOf('nom_produit'),  header.indexOf('description'),  1)
      var iRoute = Math.max(header.indexOf('route'), -1)
      var iOp    = Math.max(header.indexOf('op_number'), header.indexOf('numero'), header.indexOf('operation'), header.indexOf('op'), -1)
      var iRoom  = Math.max(header.indexOf('room_code'), header.indexOf('salle'), header.indexOf('room'), -1)

      // Fallback positionnel si header absent ou colonnes non trouvées
      if (!hasHeader) { iCode=0; iName=1; iRoute=2; iOp=3; iRoom=4 }
      else {
        if (iOp  < 0) iOp  = iRoute >= 0 ? iRoute + 1 : 2
        if (iRoom < 0) iRoom = iOp + 1
        if (iRoute < 0) iRoute = -1
      }

      var rows = []
      for (var i = startIdx; i < lines.length; i++) {
        var cols = parseCsvLine(lines[i])
        var pcode = (cols[iCode] || '').trim()
        var pname = (cols[iName] || '').trim()
        var route = iRoute >= 0 ? parseInt((cols[iRoute] || '1').trim()) : 1
        var opNum = parseInt((cols[iOp]  || '').trim())
        var room  = iRoom >= 0 ? ((cols[iRoom] || '').trim() || null) : null
        if (!pcode || isNaN(opNum)) continue
        rows.push({ product_code: pcode, product_name: pname, route: isNaN(route) ? 1 : route, op_number: opNum, room_code: room })
      }
      if (!rows.length) { gsModal.err = 'Aucune ligne valide. Colonnes attendues : product_code, op_number (ou code_article, Numéro).'; return }
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
        // Import NON-destructif : on ne touche QUE les lignes flexibles (room_code null) ;
        // les salles cochées à la main (room_code spécifique) sont PRÉSERVÉES.
        await supabase.from('product_flux').delete().eq('product_code', g.product_code).eq('route', g.route).is('room_code', null)
        await supabase.from('product_flux').insert(g.rows.map(function(r) {
          return { product_code: r.product_code, product_name: r.product_name || r.product_code, op_number: r.op_number, route: r.route, room_code: r.room_code || null }
        }))
      }
      gsModal.saving = false; gsModal.open = false
      await loadAll()
    }

    var reloadGs = async function() {
      gsReloading.value = true
      await loadAll()
      gsReloading.value = false
    }

    // ── LOAD ─────────────────────────────────────────────────────
    var loadAll = async function() {
      fluxLoading.value = true
      var [rOm, rPr, r0, r1] = await Promise.all([
        supabase.from('operations_master').select('op_number,equipment_name,room_code,processus,room_name').order('op_number'),
        supabase.from('plan_rooms').select('code,nom,op_number,actif').not('op_number','is',null).order('op_number'),
        supabase.from('product_flux').select('*').order('product_code').order('route').order('op_number'),
        supabase.from('v_product_flux_summary').select('*'),
      ])
      opMaster.value  = rOm.data || []
      planRooms.value = (rPr.data || []).sort(function(a, b) {
        if (a.op_number !== b.op_number) return a.op_number - b.op_number
        return (a.nom || '').localeCompare(b.nom || '')
      })
      if (!r0.error) allFluxRows.value     = r0.data
      if (!r1.error) productsSummary.value = r1.data
      fluxLoading.value = false
    }

    onMounted(loadAll)

    return {
      fluxSearch, fluxView, fluxLoading,
      gsReloading, reloadGs,
      filteredProducts, opMaster, opOptions, roomsForOp,
      machineColsFlat, machineColGroups, pivotMachineRows,
      selectedRows, bulkRoom, isRowSelected, allRowsSelected, toggleSelectRow, toggleAllSelect, bulkAssign,
      stepModal, gsModal,
      getRoomName, onOpChange,
      openNewFlux, openAddStep, openEditStep, saveStep, deleteStep,
      toggleMachineFlux, clearFlux,
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
.tb-btn-clear { background: #fff; border: 1px solid #e5e7eb; border-radius: 5px; color: #E24B4A; padding: 7px 12px; font-size: 11px; font-weight: 600; cursor: pointer; white-space: nowrap; }
.tb-btn-clear:hover { background: #FCEBEB; border-color: #E24B4A; }
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

/* ── Ligne 2 : noms machines (texte vertical) ── */
.pt-r-mach th {
  position: sticky;
  top: 40px;
  z-index: 3;
  background: #faf5ff;
  padding: 6px 2px;
  text-align: center;
  border-bottom: 2px solid #7c3aed;
  border-right: 1px solid #ede9fe;
  font-size: 10px;
  font-weight: 600;
  color: #4b5563;
  writing-mode: vertical-lr;
  height: 130px;
  width: 36px;
  min-width: 36px;
  max-width: 36px;
  white-space: nowrap;
  overflow: hidden;
}

/* ── Colonnes fixes (Checkbox / Produit / R) ── */
.pt-sc { position: sticky; background: inherit; }
.pt-sc0 { left: 0;   width: 36px; min-width: 36px; }
.pt-sc1 { left: 36px; }
.pt-sc2 { left: 196px; border-right: 2px solid #c4b5fd !important; }

/* bump z-index pour que les coins restent au-dessus */
.pt-r-op .pt-sc  { z-index: 6 !important; }
.pt-r-mach .pt-sc { z-index: 5 !important; }

/* body sticky cols */
.pivot-table tbody .pt-sc { z-index: 1; background: #fff; }
.pivot-table tbody .pt-r2 .pt-sc { background: #fafafa; }

/* ── En-têtes op ── */
.pt-h-prod { min-width: 160px; text-align: left !important; }
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

/* ── Checkbox sélection ── */
.pt-chk { text-align: center; cursor: pointer; width: 36px; padding: 4px 2px; }
.pt-chkbox { cursor: pointer; accent-color: #7c3aed; width: 14px; height: 14px; }
.pt-sel td { background: #f5f3ff !important; }

/* ── Case à cocher machine ── */
.pt-cc {
  text-align: center;
  cursor: pointer;
  width: 36px;
  min-width: 36px;
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

/* ── Barre sélection multiple ── */
.bulk-assign-bar {
  position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%);
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  background: #1e1b4b; color: #e0e7ff; border-radius: 10px;
  padding: 12px 18px; box-shadow: 0 8px 32px rgba(0,0,0,.25); z-index: 200;
}
.ba-count { font-size: 13px; font-weight: 600; white-space: nowrap; }
.ba-sel { padding: 6px 10px; border-radius: 5px; font-size: 12px; border: none; background: #312e81; color: #e0e7ff; cursor: pointer; min-width: 200px; }
.ba-btn { padding: 7px 16px; border: none; border-radius: 5px; font-size: 12px; font-weight: 600; cursor: pointer; }
.ba-btn:disabled { opacity: .4; cursor: not-allowed; }
.ba-on  { background: #7c3aed; color: #fff; }
.ba-on:hover:not(:disabled)  { background: #6d28d9; }
.ba-off { background: #374151; color: #e5e7eb; }
.ba-off:hover:not(:disabled) { background: #1f2937; }
.ba-clear { background: none; border: 1px solid #4338ca; color: #a5b4fc; border-radius: 5px; padding: 6px 12px; font-size: 11px; cursor: pointer; }
.ba-clear:hover { background: #312e81; }
.bulk-slide-enter-active, .bulk-slide-leave-active { transition: all .2s ease; }
.bulk-slide-enter-from, .bulk-slide-leave-to { transform: translateX(-50%) translateY(20px); opacity: 0; }

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
