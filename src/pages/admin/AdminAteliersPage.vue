<template>
  <div class="admin-ateliers">
    <div class="ph">
      <span class="pt">ADMIN — PROCESSUS & ATELIERS</span>
      <div class="ph-tabs">
        <button class="tab-btn" :class="{active:tab==='processus'}" @click="tab='processus'">Processus ({{processus.length}})</button>
        <button class="tab-btn" :class="{active:tab==='ateliers'}" @click="tab='ateliers'">Ateliers ({{ateliers.length}})</button>
      </div>
    </div>

    <!-- ══════════ PROCESSUS ══════════ -->
    <div v-show="tab==='processus'">
      <div class="sec-toolbar">
        <span class="sec-desc">Les processus regroupent les ateliers de fabrication (ex : Granulation, Compression, Stérilisation…)</span>
        <button class="btn-add" @click="openProc(null)">+ Nouveau processus</button>
      </div>

      <table class="admin-table">
        <thead>
          <tr>
            <th style="width:50px">Ordre</th>
            <th>Nom du processus</th>
            <th style="width:80px">Couleur</th>
            <th style="width:100px">Ateliers</th>
            <th style="width:80px">Actif</th>
            <th style="width:100px"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="p in sortedProcessus" :key="p.id" :class="{inactive:!p.actif}">
            <td class="num">{{p.ordre||'—'}}</td>
            <td>
              <div class="item-name">{{p.nom_process}}</div>
            </td>
            <td>
              <span class="color-dot" :style="{background:p.couleur||'#888'}"></span>
              <span class="color-code">{{p.couleur||'—'}}</span>
            </td>
            <td class="num">{{getAtelierCount(p.id)}}</td>
            <td>
              <span class="badge" :class="p.actif?'badge-on':'badge-off'">{{p.actif?'Actif':'Inactif'}}</span>
            </td>
            <td class="acts">
              <button class="ia" @click="openProc(p)" title="Modifier">✏️</button>
              <button class="ia del" @click="toggleActifProc(p)" :title="p.actif?'Désactiver':'Activer'">{{p.actif?'⏸':'▶'}}</button>
            </td>
          </tr>
          <tr v-if="!processus.length"><td colspan="6" class="empty">Aucun processus — cliquez sur "+ Nouveau processus"</td></tr>
        </tbody>
      </table>
    </div>

    <!-- ══════════ ATELIERS ══════════ -->
    <div v-show="tab==='ateliers'">
      <div class="sec-toolbar">
        <div class="at-filters">
          <select class="t-sel" v-model="filterProcId">
            <option :value="null">Tous processus</option>
            <option v-for="p in processus" :key="p.id" :value="p.id">{{p.nom_process}}</option>
          </select>
          <label class="chk-label">
            <input type="checkbox" v-model="showInactif"> Inclure inactifs
          </label>
        </div>
        <button class="btn-add" @click="openAtelier(null)" :disabled="!processus.length" :title="!processus.length?'Créez d\'abord un processus':''">+ Nouvel atelier</button>
      </div>

      <div v-if="!processus.length" class="warn-box">
        ⚠ Aucun processus trouvé. Créez d'abord des processus dans l'onglet <strong>Processus</strong>.
      </div>

      <table class="admin-table" v-else>
        <thead>
          <tr>
            <th>Atelier</th>
            <th>Processus</th>
            <th>Lots actifs</th>
            <th>Actif</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <template v-for="p in filteredProcForAteliers" :key="p.id">
            <tr class="proc-group-hd">
              <td colspan="5">
                <span class="proc-dot" :style="{background:p.couleur||'#888'}"></span>
                {{p.nom_process}}
                <span class="proc-count">({{getAteliersByProc(p.id).length}} atelier{{getAteliersByProc(p.id).length>1?'s':''}})</span>
              </td>
            </tr>
            <tr v-for="at in getAteliersByProc(p.id)" :key="at.id" :class="{inactive:!at.actif}" class="atelier-row">
              <td>
                <div class="item-name">{{at.nom_atelier}}</div>
              </td>
              <td>
                <span class="proc-chip" :style="{background:(p.couleur||'#888')+'22',color:p.couleur||'#888'}">{{p.nom_process}}</span>
              </td>
              <td class="num">{{getActiveFabCount(at.id)}}</td>
              <td>
                <span class="badge" :class="at.actif?'badge-on':'badge-off'">{{at.actif?'Actif':'Inactif'}}</span>
              </td>
              <td class="acts">
                <button class="ia" @click="openAtelier(at)" title="Modifier">✏️</button>
                <button class="ia del" @click="toggleActifAtelier(at)" :title="at.actif?'Désactiver':'Activer'">{{at.actif?'⏸':'▶'}}</button>
              </td>
            </tr>
            <tr v-if="!getAteliersByProc(p.id).length" class="atelier-row">
              <td colspan="5" class="empty-proc">
                Aucun atelier — <button class="link-btn" @click="openAtelier(null, p.id)">+ Ajouter un atelier</button>
              </td>
            </tr>
          </template>
          <tr v-if="!filteredProcForAteliers.length"><td colspan="5" class="empty">Aucun résultat</td></tr>
        </tbody>
      </table>
    </div>

    <!-- ══ MODAL PROCESSUS ══ -->
    <div class="overlay" v-if="procModal.show" @click.self="procModal.show=false">
      <div class="modal">
        <div class="modal-hd">{{procModal.id?'Modifier processus':'Nouveau processus'}}</div>
        <div class="modal-body">
          <label class="lbl">Nom du processus *</label>
          <input class="inp" v-model="procModal.nom_process" placeholder="ex : Granulation humide" maxlength="80" />

          <label class="lbl">Ordre d'affichage</label>
          <input type="number" class="inp" v-model.number="procModal.ordre" min="1" placeholder="1, 2, 3…" />

          <label class="lbl">Couleur</label>
          <div class="color-row">
            <input type="color" class="inp-color" v-model="procModal.couleur" />
            <div class="color-presets">
              <span v-for="c in colorPresets" :key="c" class="cp" :style="{background:c}"
                :class="{selected:procModal.couleur===c}" @click="procModal.couleur=c"></span>
            </div>
          </div>

          <label class="lbl">
            <input type="checkbox" v-model="procModal.actif" style="margin-right:6px"> Actif
          </label>

          <div class="form-err" v-if="procModal.err">{{procModal.err}}</div>
        </div>
        <div class="modal-ft">
          <button class="btn-cancel" @click="procModal.show=false">Annuler</button>
          <button class="btn-save" @click="saveProc" :disabled="procModal.saving">{{procModal.saving?'…':'Enregistrer'}}</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL ATELIER ══ -->
    <div class="overlay" v-if="atelierModal.show" @click.self="atelierModal.show=false">
      <div class="modal">
        <div class="modal-hd">{{atelierModal.id?'Modifier atelier':'Nouvel atelier'}}</div>
        <div class="modal-body">
          <label class="lbl">Nom de l'atelier *</label>
          <input class="inp" v-model="atelierModal.nom_atelier" placeholder="ex : Atelier Granulation A" maxlength="80" />

          <label class="lbl">Processus *</label>
          <select class="inp" v-model="atelierModal.processus_id">
            <option :value="null">— Choisir un processus —</option>
            <option v-for="p in processus" :key="p.id" :value="p.id">{{p.nom_process}}</option>
          </select>

          <label class="lbl">
            <input type="checkbox" v-model="atelierModal.actif" style="margin-right:6px"> Actif
          </label>

          <div class="form-err" v-if="atelierModal.err">{{atelierModal.err}}</div>
        </div>
        <div class="modal-ft">
          <button class="btn-cancel" @click="atelierModal.show=false">Annuler</button>
          <button class="btn-save" @click="saveAtelier" :disabled="atelierModal.saving">{{atelierModal.saving?'…':'Enregistrer'}}</button>
        </div>
      </div>
    </div>

  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'

export default {
  setup() {
    var tab = ref('processus')
    var processus = ref([])
    var ateliers = ref([])
    var suiviFab = ref([])
    var filterProcId = ref(null)
    var showInactif = ref(false)

    var colorPresets = [
      '#3b82f6','#10b981','#f59e0b','#ef4444','#8b5cf6',
      '#06b6d4','#f97316','#ec4899','#6366f1','#14b8a6',
      '#84cc16','#a16207','#0369a1','#7c3aed','#be185d',
    ]

    var procModal = ref({ show:false, id:null, nom_process:'', ordre:null, couleur:'#3b82f6', actif:true, err:'', saving:false })
    var atelierModal = ref({ show:false, id:null, nom_atelier:'', processus_id:null, actif:true, err:'', saving:false })

    // ─── LOAD ─────────────────────────────────────────────────
    var loadAll = async function() {
      var [r1,r2,r3] = await Promise.all([
        supabase.from('processus').select('*').order('ordre').order('nom_process'),
        supabase.from('ateliers').select('*').order('nom_atelier'),
        supabase.from('suivi_fabrication').select('id,atelier_id,statut').is('deleted_at',null)
      ])
      if (!r1.error) processus.value = r1.data
      if (!r2.error) ateliers.value = r2.data
      if (!r3.error) suiviFab.value = r3.data
    }

    // ─── COMPUTED ─────────────────────────────────────────────
    var sortedProcessus = computed(function() {
      return processus.value.slice().sort(function(a,b){
        var oa = a.ordre||999, ob = b.ordre||999
        return oa!==ob ? oa-ob : (a.nom_process||'').localeCompare(b.nom_process||'')
      })
    })

    var filteredProcForAteliers = computed(function() {
      var list = processus.value
      if (filterProcId.value) list = list.filter(function(p){ return p.id===filterProcId.value })
      return list
    })

    var getAteliersByProc = function(procId) {
      return ateliers.value.filter(function(a) {
        if (a.processus_id !== procId) return false
        if (!showInactif.value && !a.actif) return false
        return true
      })
    }

    var getAtelierCount = function(procId) {
      return ateliers.value.filter(function(a){ return a.processus_id===procId }).length
    }

    var getActiveFabCount = function(atelierId) {
      return suiviFab.value.filter(function(sf){ return sf.atelier_id===atelierId && (sf.statut==='En cours'||sf.statut==='Arrêt') }).length
    }

    // ─── PROCESSUS CRUD ───────────────────────────────────────
    var openProc = function(p) {
      if (p) {
        procModal.value = { show:true, id:p.id, nom_process:p.nom_process, ordre:p.ordre, couleur:p.couleur||'#3b82f6', actif:p.actif, err:'', saving:false }
      } else {
        var maxOrdre = processus.value.reduce(function(m,x){ return Math.max(m,x.ordre||0) },0)
        procModal.value = { show:true, id:null, nom_process:'', ordre:maxOrdre+1, couleur:'#3b82f6', actif:true, err:'', saving:false }
      }
    }

    var saveProc = async function() {
      if (!procModal.value.nom_process.trim()) { procModal.value.err='Nom requis'; return }
      procModal.value.saving = true; procModal.value.err = ''
      var payload = {
        nom_process: procModal.value.nom_process.trim(),
        ordre: procModal.value.ordre||null,
        couleur: procModal.value.couleur,
        actif: procModal.value.actif
      }
      var res
      if (procModal.value.id) {
        res = await supabase.from('processus').update(payload).eq('id', procModal.value.id)
      } else {
        res = await supabase.from('processus').insert(payload)
      }
      procModal.value.saving = false
      if (res.error) { procModal.value.err = res.error.message; return }
      procModal.value.show = false
      await loadAll()
    }

    var toggleActifProc = async function(p) {
      await supabase.from('processus').update({ actif: !p.actif }).eq('id', p.id)
      await loadAll()
    }

    // ─── ATELIERS CRUD ────────────────────────────────────────
    var openAtelier = function(at, defaultProcId) {
      if (at) {
        atelierModal.value = { show:true, id:at.id, nom_atelier:at.nom_atelier, processus_id:at.processus_id, actif:at.actif, err:'', saving:false }
      } else {
        atelierModal.value = { show:true, id:null, nom_atelier:'', processus_id:defaultProcId||filterProcId.value||null, actif:true, err:'', saving:false }
      }
    }

    var saveAtelier = async function() {
      if (!atelierModal.value.nom_atelier.trim()) { atelierModal.value.err='Nom requis'; return }
      if (!atelierModal.value.processus_id) { atelierModal.value.err='Processus requis'; return }
      atelierModal.value.saving = true; atelierModal.value.err = ''
      var payload = {
        nom_atelier: atelierModal.value.nom_atelier.trim(),
        processus_id: atelierModal.value.processus_id,
        actif: atelierModal.value.actif
      }
      var res
      if (atelierModal.value.id) {
        res = await supabase.from('ateliers').update(payload).eq('id', atelierModal.value.id)
      } else {
        res = await supabase.from('ateliers').insert(payload)
      }
      atelierModal.value.saving = false
      if (res.error) { atelierModal.value.err = res.error.message; return }
      atelierModal.value.show = false
      await loadAll()
    }

    var toggleActifAtelier = async function(at) {
      await supabase.from('ateliers').update({ actif: !at.actif }).eq('id', at.id)
      await loadAll()
    }

    onMounted(loadAll)

    return {
      tab, processus, ateliers, suiviFab, filterProcId, showInactif, colorPresets,
      procModal, atelierModal,
      sortedProcessus, filteredProcForAteliers,
      getAteliersByProc, getAtelierCount, getActiveFabCount,
      openProc, saveProc, toggleActifProc,
      openAtelier, saveAtelier, toggleActifAtelier,
    }
  }
}
</script>

<style scoped>
.admin-ateliers { font-family:'Inter',sans-serif; font-size:13px; }

.ph { display:flex; align-items:center; justify-content:space-between; padding-bottom:10px; border-bottom:2px solid #0a0a0a; margin-bottom:16px; flex-wrap:wrap; gap:8px; }
.pt { font-size:11px; font-weight:600; letter-spacing:1.5px; text-transform:uppercase; }
.ph-tabs { display:flex; gap:4px; }
.tab-btn { padding:6px 16px; border:1px solid #d1d5db; border-radius:4px; background:#fff; font-size:12px; cursor:pointer; color:#555; }
.tab-btn.active { background:#0a0a0a; color:#fff; border-color:#0a0a0a; }

.sec-toolbar { display:flex; align-items:center; justify-content:space-between; margin-bottom:12px; gap:8px; flex-wrap:wrap; }
.sec-desc { font-size:12px; color:#666; }
.at-filters { display:flex; align-items:center; gap:8px; }

.btn-add { padding:7px 14px; background:#0a0a0a; color:#fff; border:none; border-radius:4px; font-size:12px; cursor:pointer; font-weight:500; }
.btn-add:hover { background:#333; }
.btn-add:disabled { opacity:.4; cursor:not-allowed; }

.warn-box { background:#fffbeb; border:1px solid #fbbf24; border-radius:4px; padding:12px 16px; color:#92400e; font-size:13px; margin-bottom:12px; }

.admin-table { width:100%; border-collapse:collapse; }
.admin-table th { padding:8px 12px; text-align:left; background:#f9fafb; border-bottom:2px solid #e5e7eb; font-size:11px; font-weight:600; color:#374151; text-transform:uppercase; letter-spacing:.5px; }
.admin-table td { padding:8px 12px; border-bottom:1px solid #f0f0f0; vertical-align:middle; }
.admin-table tr:hover td { background:#f9fafb; }
.admin-table tr.inactive td { opacity:.5; }

.proc-group-hd td { background:#f3f4f6; padding:6px 12px; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:.5px; color:#374151; border-bottom:1px solid #e5e7eb; }
.atelier-row td { padding-left:28px; }

.proc-dot { display:inline-block; width:8px; height:8px; border-radius:50%; margin-right:6px; vertical-align:middle; }
.proc-count { font-weight:400; color:#888; text-transform:none; letter-spacing:0; }

.item-name { font-weight:600; }

.color-dot { display:inline-block; width:14px; height:14px; border-radius:3px; vertical-align:middle; margin-right:5px; }
.color-code { font-family:monospace; font-size:11px; color:#666; }

.proc-chip { font-size:11px; padding:2px 8px; border-radius:3px; font-weight:500; }

.num { text-align:center; font-variant-numeric:tabular-nums; }
.badge { font-size:10px; padding:2px 8px; border-radius:3px; font-weight:500; }
.badge-on { background:#d1fae5; color:#065f46; }
.badge-off { background:#f3f4f6; color:#9ca3af; }

.acts { white-space:nowrap; }
.ia { background:none; border:none; cursor:pointer; padding:3px 6px; font-size:13px; border-radius:3px; }
.ia:hover { background:#f3f4f6; }
.ia.del { color:#ef4444; }
.ia.del:hover { background:#fee2e2; }

.empty { text-align:center; padding:40px; color:#bbb; font-style:italic; }
.empty-proc { padding:8px 12px; color:#bbb; font-style:italic; }
.link-btn { background:none; border:none; color:#3b82f6; cursor:pointer; font-size:13px; text-decoration:underline; padding:0; }

.t-sel { padding:6px 10px; border:1px solid #d1d5db; border-radius:4px; font-size:12px; background:#fff; }
.chk-label { display:flex; align-items:center; font-size:12px; color:#555; cursor:pointer; }

/* ── Modals ── */
.overlay { position:fixed; inset:0; background:rgba(0,0,0,.5); z-index:100; display:flex; align-items:center; justify-content:center; }
.modal { background:#fff; border-radius:8px; width:440px; max-width:95vw; box-shadow:0 20px 60px rgba(0,0,0,.3); display:flex; flex-direction:column; max-height:90vh; overflow:hidden; }
.modal-hd { padding:16px 20px; border-bottom:1px solid #e5e7eb; font-weight:600; font-size:14px; }
.modal-body { padding:20px; display:flex; flex-direction:column; gap:12px; overflow-y:auto; }
.modal-ft { padding:14px 20px; border-top:1px solid #e5e7eb; display:flex; justify-content:flex-end; gap:8px; }

.lbl { font-size:11px; font-weight:600; color:#374151; text-transform:uppercase; letter-spacing:.5px; margin-bottom:2px; }
.inp { padding:7px 10px; border:1px solid #d1d5db; border-radius:4px; font-size:13px; width:100%; box-sizing:border-box; }
.inp:focus { outline:none; border-color:#0a0a0a; }

.color-row { display:flex; align-items:center; gap:10px; }
.inp-color { width:44px; height:36px; padding:2px; border:1px solid #d1d5db; border-radius:4px; cursor:pointer; }
.color-presets { display:flex; flex-wrap:wrap; gap:5px; }
.cp { display:inline-block; width:20px; height:20px; border-radius:3px; cursor:pointer; transition:.1s; border:2px solid transparent; }
.cp:hover { transform:scale(1.15); }
.cp.selected { border-color:#0a0a0a; transform:scale(1.1); }

.form-err { color:#ef4444; font-size:12px; padding:6px 10px; background:#fff5f5; border-radius:4px; }
.btn-cancel { padding:7px 16px; border:1px solid #d1d5db; border-radius:4px; background:#fff; font-size:13px; cursor:pointer; }
.btn-save { padding:7px 20px; border:none; border-radius:4px; background:#0a0a0a; color:#fff; font-size:13px; cursor:pointer; font-weight:500; }
.btn-save:hover { background:#333; }
.btn-save:disabled { opacity:.5; cursor:not-allowed; }
</style>
