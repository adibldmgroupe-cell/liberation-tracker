<template>
  <div class="admin-ateliers">
    <div class="ph">
      <span class="pt">ADMIN — PROCESSUS & ATELIERS</span>
      <div class="ph-tabs">
        <button class="tab-btn" :class="{active:tab==='processus'}" @click="tab='processus'">Processus ({{processus.length}})</button>
        <button class="tab-btn" :class="{active:tab==='ateliers'}" @click="tab='ateliers'">Ateliers ({{ateliers.length}})</button>
        <button class="tab-btn tab-btn-gs" :class="{active:tab==='gs-ref'}" @click="switchGsTab('gs-ref')">📋 GS Référentiel ({{gsRows.length}})</button>
        <button class="tab-btn tab-btn-gs" :class="{active:tab==='gs-cad'}" @click="switchGsTab('gs-cad')">⚡ GS Cadences ({{gsCadences.length}})</button>
      </div>
      <button class="btn-gs-reload" v-if="tab==='gs-ref'||tab==='gs-cad'" @click="reloadGs" :disabled="gsLoading" :class="{spinning:gsLoading}">↻</button>
    </div>

    <!-- ══════════ PROCESSUS ══════════ -->
    <div v-show="tab==='processus'">
      <div class="sec-toolbar">
        <span class="sec-desc">Les processus regroupent les ateliers de fabrication (ex : Granulation, Compression, Stérilisation…)</span>
        <button class="btn-add" @click="openProc(null)">+ Nouveau processus</button>
      </div>

      <div class="table-wrap">
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

      <div class="table-wrap" v-else>
      <table class="admin-table">
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
    </div>

    <!-- ══════════ GS RÉFÉRENTIEL ══════════ -->
    <div v-show="tab==='gs-ref'">
      <div class="gs-filters">
        <select class="t-sel" v-model="gsFilterProc">
          <option value="">Tous les processus</option>
          <option v-for="p in gsProcessusUniques" :key="p" :value="p">{{p}}</option>
        </select>
        <input class="t-inp" v-model="gsSearch" placeholder="Chercher nom, équipement, N°…" />
        <button class="btn-sync" @click="syncRefToSupabase" :disabled="syncRefSaving||gsLoading||!gsRows.length">
          {{syncRefSaving?'⟳ Synchronisation…':'💾 Sync plan_rooms'}}
        </button>
        <span v-if="syncRefResult" class="sync-result" :class="syncRefResult.errors&&syncRefResult.errors.length?'sync-warn':'sync-ok'">
          {{syncRefResult.err || (syncRefResult.updated+' salles'+(syncRefResult.errors&&syncRefResult.errors.length?' · '+syncRefResult.errors.length+' erreur(s)':''))}}
        </span>
        <button class="btn-sync" @click="syncOpMasterToSupabase" :disabled="syncOpSaving||gsLoading||!gsRows.length">
          {{syncOpSaving?'⟳ Synchronisation…':'💾 Sync operations_master'}}
        </button>
        <span v-if="syncOpResult" class="sync-result" :class="syncOpResult.err?'sync-warn':'sync-ok'">
          {{syncOpResult.err || (syncOpResult.updated+' opérations synchronisées')}}
        </span>
      </div>
      <div v-if="gsLoading" class="gs-loading">Chargement GS…</div>
      <template v-else>
        <div v-for="bloc in gsRefGrouped" :key="bloc.nom" style="margin-bottom:20px">
          <div class="gs-proc-hd">
            <span class="proc-dot" :style="{background:bloc.couleur}"></span>
            {{bloc.nom}}
            <span class="proc-count">({{bloc.rows.length}})</span>
          </div>
          <div class="table-wrap">
            <table class="admin-table gs-table">
              <thead>
                <tr>
                  <th>N° salle</th><th>id Supabase</th><th>Désignation</th>
                  <th>N° Op.</th><th>Opération</th><th>Équipement</th>
                  <th class="gs-r">TRS cible</th><th class="gs-r">TO shift</th>
                  <th class="gs-r">Pause</th><th class="gs-r">VDLP</th>
                  <th class="gs-r">VDLC</th><th class="gs-r">Chgt fmt</th>
                  <th class="gs-r">Régl.</th><th class="gs-r">Micro-arr.</th><th class="gs-r">Maint.</th>
                  <th>Code SVG</th><th>Dans schéma</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="r in bloc.rows" :key="r.room_code">
                  <td class="gs-mono">{{r.atelier_id}}</td>
                  <td class="gs-mono" :class="{'gs-missing':!r.id_supabase}">{{r.id_supabase||'—'}}</td>
                  <td>{{r.atelier_nom}}</td>
                  <td class="gs-mono">{{r.op_number||'—'}}</td>
                  <td>{{r.op_code||'—'}}</td>
                  <td>{{r.equipment_name||'—'}}</td>
                  <td class="gs-r">{{r.trs_cible_pct!=null?r.trs_cible_pct+'%':'—'}}</td>
                  <td class="gs-r">{{r.to_shift_min!=null?r.to_shift_min+' min':'—'}}</td>
                  <td class="gs-r">{{r.pause_min!=null?r.pause_min+' min':'—'}}</td>
                  <td class="gs-r">{{r.vdlp_min!=null?r.vdlp_min+' min':'—'}}</td>
                  <td class="gs-r">{{r.vdlc_min!=null?r.vdlc_min+' min':'—'}}</td>
                  <td class="gs-r">{{r.chgt_format_min!=null?r.chgt_format_min+' min':'—'}}</td>
                  <td class="gs-r">{{r.reglage_lancement_min!=null?r.reglage_lancement_min+' min':'—'}}</td>
                  <td class="gs-r">{{r.micro_arrets_shift_min!=null?r.micro_arrets_shift_min+' min':'—'}}</td>
                  <td class="gs-r">{{r.maint_curative_shift_min!=null?r.maint_curative_shift_min+' min':'—'}}</td>
                  <td class="gs-mono">{{r.room_code}}</td>
                  <td>
                    <span v-if="r.inSchema" class="badge badge-on">✓ Schéma</span>
                    <span v-else class="badge badge-off">⚠ Absent</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <div v-if="gsRefGrouped.length===0" class="empty">Aucun atelier.</div>
      </template>
    </div>

    <!-- ══════════ GS CADENCES ══════════ -->
    <div v-show="tab==='gs-cad'">
      <div class="gs-filters">
        <input class="t-inp" v-model="gsCadSalle"   placeholder="N° salle…" style="max-width:120px" />
        <input class="t-inp" v-model="gsCadArticle" placeholder="Code article…" />
        <input class="t-inp" v-model="gsCadDesc"    placeholder="Description…" />
        <button class="btn-sync" @click="syncCadencesToSupabase" :disabled="syncCadSaving||gsLoading||!gsCadences.length">
          {{syncCadSaving?'⟳ Synchronisation…':'💾 Synchroniser vers Supabase'}}
        </button>
        <span v-if="syncCadResult" class="sync-result" :class="syncCadResult.err?'sync-warn':'sync-ok'">
          {{syncCadResult.err || (syncCadResult.updated+' cadences synchronisées')}}
        </span>
      </div>
      <div v-if="gsLoading" class="gs-loading">Chargement GS…</div>
      <div class="table-wrap" v-else>
        <table class="admin-table gs-table">
          <thead>
            <tr>
              <th>N° salle</th><th>Code article</th><th>Description</th>
              <th>Équipement</th><th class="gs-r">Taille lot</th><th class="gs-r">Cadence obj. (b/min)</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(c,i) in gsCadencesFiltrees" :key="i">
              <td class="gs-mono">{{c.numero_atelier}}</td>
              <td class="gs-mono">{{c.code_article}}</td>
              <td>{{c.description}}</td>
              <td>{{c.equipment_name}}</td>
              <td class="gs-r">{{c.taille_lot!=null?c.taille_lot.toLocaleString('fr-FR'):'—'}}</td>
              <td class="gs-r gs-cad-val">{{c.cadence_objectif_b_min!=null?c.cadence_objectif_b_min:'—'}}</td>
            </tr>
            <tr v-if="!gsCadencesFiltrees.length"><td colspan="6" class="empty">Aucune cadence.</td></tr>
          </tbody>
        </table>
      </div>
      <div class="gs-footer">{{gsCadencesFiltrees.length}} / {{gsCadences.length}} entrée(s)</div>
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
import { getAll as gsGetAll, clearCache as gsClearCache } from '../../services/googleSheets'

// Codes présents dans NODES_DEF de ProductionFlowPage (source de vérité schéma SVG)
var SCHEMA_CODES_SET = new Set([
  'p464','p471',
  'n140','n138','n131','n143',
  'n137','n134','n136','n128',
  'n425','n448','n445','n429',
  'n442','n436',
  'n200','n206',
  'c149','c148','c147','c146','c220','c222','c223',
  'n416','n155',
  'n101','n102','n103','n104','n105',
])

var GS_PROC_COLORS = {
  'Fabrication':                      '#7c3aed',
  'Conditionnement':                  '#059669',
  'PF en attente de livraison':       '#d97706',
  'SF en attente de conditionnement': '#2563eb',
}
var GS_PROC_ORDER = ['Fabrication','Conditionnement','PF en attente de livraison','SF en attente de conditionnement']

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

    // ─── GS DATA ──────────────────────────────────────────────────
    var gsLoading  = ref(false)
    var gsRows     = ref([])      // onglet 1
    var gsCadences = ref([])      // onglet 2
    var syncRefSaving = ref(false), syncRefResult = ref(null)
    var syncCadSaving = ref(false), syncCadResult = ref(null)
    var syncOpSaving  = ref(false), syncOpResult  = ref(null)

    // Filtres GS onglet 1
    var gsFilterProc = ref('')
    var gsSearch     = ref('')

    // Filtres GS onglet 2
    var gsCadSalle   = ref('')
    var gsCadArticle = ref('')
    var gsCadDesc    = ref('')

    var loadGs = async function() {
      gsLoading.value = true
      var gsData = await gsGetAll()
      gsRows.value = (gsData.operationsMaster || []).map(function(om) {
        return {
          processus_nom:            om.processus,
          atelier_id:               parseInt((om.room_code || '').replace(/^[a-z]/, '')),
          id_supabase:              om.id,
          atelier_nom:              om.room_name,
          op_number:                om.op_number,
          op_code:                  om.op_code,
          equipment_name:           om.equipment_name,
          trs_cible_pct:            om.trs_cible_pct,
          to_shift_min:             om.to_shift_min,
          pause_min:                om.pause_min,
          vdlp_min:                 om.vdlp_min,
          vdlc_min:                 om.vdlc_min,
          chgt_format_min:          om.chgt_format_min,
          reglage_lancement_min:    om.reglage_lancement_min,
          micro_arrets_shift_min:   om.micro_arrets_shift_min,
          maint_curative_shift_min: om.maint_curative_shift_min,
          room_code:                om.room_code,
          inSchema:                 SCHEMA_CODES_SET.has(om.room_code),
        }
      })
      gsCadences.value = gsData.cadences || []
      gsLoading.value = false
    }

    var reloadGs = async function() {
      gsClearCache()
      await loadGs()
    }

    // ── Synchroniser GS Référentiel → plan_rooms (colonnes TRS) ──
    var syncRefToSupabase = async function() {
      if (!gsRows.value.length) return
      syncRefSaving.value = true; syncRefResult.value = null
      var updated = 0, errors = []
      for (var i = 0; i < gsRows.value.length; i++) {
        var r = gsRows.value[i]
        if (!r.room_code) continue
        var payload = {
          trs_cible_pct:    r.trs_cible_pct,
          to_shift_min:     r.to_shift_min,
          pause_min:        r.pause_min,
          vdlp_min:         r.vdlp_min,
          vdlc_min:         r.vdlc_min,
          chgt_format_min:  r.chgt_format_min,
          reglage_min:      r.reglage_lancement_min,
          micro_arrets_min: r.micro_arrets_shift_min,
          maint_min:        r.maint_curative_shift_min,
          // op_number exclu volontairement : géré par migration 008, pas par le GS
          // (les numéros SAP du GS sont spécifiques machines et cassent le groupement du tableau croisé)
          op_code:          r.op_code || null,
          equipment_name:   r.equipment_name || null
        }
        var res = await supabase.from('plan_rooms').update(payload).eq('code', r.room_code)
        if (res.error) errors.push(r.room_code + ' : ' + res.error.message)
        else updated++
      }
      syncRefResult.value = { updated, errors }
      syncRefSaving.value = false
    }

    // ── Synchroniser GS Cadences → table cadences ──
    var syncCadencesToSupabase = async function() {
      if (!gsCadences.value.length) return
      syncCadSaving.value = true; syncCadResult.value = null
      var rows = gsCadences.value
        .filter(function(c) { return c.numero_atelier && c.code_article && c.taille_lot != null && c.cadence_objectif_b_min != null })
        .map(function(c) {
          return {
            numero_salle:           c.numero_atelier,
            code_article:           c.code_article,
            description:            c.description || null,
            equipment_name:         c.equipment_name || null,
            taille_lot:             c.taille_lot,
            cadence_objectif_b_min: c.cadence_objectif_b_min,
            updated_at:             new Date().toISOString()
          }
        })
      var res = await supabase.from('cadences').upsert(rows, { onConflict: 'numero_salle,code_article,taille_lot' })
      if (res.error) syncCadResult.value = { err: res.error.message }
      else syncCadResult.value = { updated: rows.length }
      syncCadSaving.value = false
    }

    // ── Synchroniser GS Référentiel → operations_master ──
    var syncOpMasterToSupabase = async function() {
      if (!gsRows.value.length) return
      syncOpSaving.value = true; syncOpResult.value = null
      var rows = gsRows.value
        .filter(function(r) { return r.room_code && r.op_number != null })
        .map(function(r) {
          return {
            room_code:       r.room_code,
            room_name:       r.atelier_nom,
            processus:       r.processus_nom,
            op_number:       r.op_number,
            op_code:         r.op_code || '',
            equipment_name:  r.equipment_name || '',
            trs_cible_pct:   r.trs_cible_pct,
            to_shift_min:    r.to_shift_min,
            pause_min:       r.pause_min,
            vdlp_min:        r.vdlp_min,
            vdlc_min:        r.vdlc_min,
            chgt_format_min: r.chgt_format_min,
            reglage_min:     r.reglage_lancement_min,
            micro_arrets_min: r.micro_arrets_shift_min,
            maint_min:       r.maint_curative_shift_min,
            updated_at:      new Date().toISOString()
          }
        })
      var res = await supabase.from('operations_master').upsert(rows, { onConflict: 'room_code' })
      if (res.error) syncOpResult.value = { err: res.error.message }
      else syncOpResult.value = { updated: rows.length }
      syncOpSaving.value = false
    }

    var switchGsTab = async function(t) {
      tab.value = t
      if (!gsRows.value.length && !gsLoading.value) await loadGs()
    }

    var gsProcessusUniques = computed(function() {
      var seen = new Set()
      gsRows.value.forEach(function(r) { seen.add(r.processus_nom) })
      return GS_PROC_ORDER.filter(function(p) { return seen.has(p) })
        .concat(Array.from(seen).filter(function(p) { return !GS_PROC_ORDER.includes(p) }))
    })

    var gsRefFiltered = computed(function() {
      var q = gsSearch.value.toLowerCase()
      return gsRows.value.filter(function(r) {
        if (gsFilterProc.value && r.processus_nom !== gsFilterProc.value) return false
        if (q) {
          var hay = [r.atelier_nom, r.equipment_name, String(r.atelier_id), r.op_code].join(' ').toLowerCase()
          if (!hay.includes(q)) return false
        }
        return true
      })
    })

    var gsRefGrouped = computed(function() {
      var map = {}
      gsRefFiltered.value.forEach(function(r) {
        if (!map[r.processus_nom]) {
          map[r.processus_nom] = { nom: r.processus_nom, couleur: GS_PROC_COLORS[r.processus_nom] || '#888', rows: [] }
        }
        map[r.processus_nom].rows.push(r)
      })
      return GS_PROC_ORDER.filter(function(p) { return map[p] }).map(function(p) { return map[p] })
        .concat(Object.keys(map).filter(function(p) { return !GS_PROC_ORDER.includes(p) }).map(function(p) { return map[p] }))
    })

    var gsCadencesFiltrees = computed(function() {
      var qs = gsCadSalle.value.trim()
      var qa = gsCadArticle.value.toLowerCase()
      var qd = gsCadDesc.value.toLowerCase()
      return gsCadences.value.filter(function(c) {
        if (qs && String(c.numero_atelier) !== qs) return false
        if (qa && !(c.code_article || '').toLowerCase().includes(qa)) return false
        if (qd && !(c.description || '').toLowerCase().includes(qd)) return false
        return true
      })
    })

    onMounted(loadAll)

    return {
      tab, processus, ateliers, suiviFab, filterProcId, showInactif, colorPresets,
      procModal, atelierModal,
      sortedProcessus, filteredProcForAteliers,
      getAteliersByProc, getAtelierCount, getActiveFabCount,
      openProc, saveProc, toggleActifProc,
      openAtelier, saveAtelier, toggleActifAtelier,
      // GS
      gsLoading, gsRows, gsCadences,
      gsFilterProc, gsSearch, gsCadSalle, gsCadArticle, gsCadDesc,
      gsProcessusUniques, gsRefGrouped, gsCadencesFiltrees,
      reloadGs, switchGsTab,
      syncRefSaving, syncRefResult, syncRefToSupabase,
      syncCadSaving, syncCadResult, syncCadencesToSupabase,
      syncOpSaving,  syncOpResult,  syncOpMasterToSupabase,
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
/* ── GS onglets ── */
.tab-btn-gs { border-color:#dbeafe; color:#1d4ed8; }
.tab-btn-gs.active { background:#1d4ed8; border-color:#1d4ed8; }
.btn-gs-reload { margin-left:auto; padding:5px 10px; border:1px solid #d1d5db; border-radius:4px; background:#fff; font-size:15px; cursor:pointer; line-height:1; }
.btn-gs-reload:disabled { opacity:.5; cursor:default; }
.btn-gs-reload.spinning { animation:gs-spin .7s linear infinite; }
@keyframes gs-spin { to { transform:rotate(360deg); } }

.gs-filters { display:flex; gap:8px; flex-wrap:wrap; margin-bottom:12px; }
.t-inp { padding:6px 10px; border:1px solid #d1d5db; border-radius:4px; font-size:12px; }
.gs-loading { padding:24px; color:#9ca3af; font-size:13px; }
.gs-proc-hd { display:flex; align-items:center; gap:8px; padding:7px 12px; background:#f3f4f6; border-radius:4px 4px 0 0; border:1px solid #e5e7eb; border-bottom:none; font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:.5px; color:#374151; }
.gs-table th { font-size:9px; }
.gs-table td { font-size:11px; padding:5px 8px; }
.gs-mono { font-family:monospace; font-size:10px; color:#6b7280; }
.gs-r { text-align:right; }
.gs-cad-val { font-weight:700; color:#059669; }
.gs-missing { color:#ef4444 !important; }
.gs-footer { font-size:11px; color:#9ca3af; text-align:right; padding:8px 0; }
.btn-sync { padding:5px 14px; font-size:12px; font-weight:600; border:1px solid #185FA5; border-radius:3px; background:#E6F1FB; color:#0C447C; cursor:pointer; font-family:inherit; white-space:nowrap; }
.btn-sync:hover:not(:disabled) { background:#d0e3f5; }
.btn-sync:disabled { opacity:.4; cursor:not-allowed; }
.sync-result { font-size:11px; padding:3px 10px; border-radius:3px; white-space:nowrap; }
.sync-ok { background:#EAF3DE; color:#3B6D11; }
.sync-warn { background:#FEF5E7; color:#A0620D; }
.table-wrap{overflow-x:auto;-webkit-overflow-scrolling:touch}
@media(max-width:768px){
  .admin-table{min-width:480px}
  .sec-toolbar{flex-direction:column;align-items:flex-start;gap:8px}
  .at-filters{flex-direction:column;gap:8px;width:100%}
  .t-sel{width:100%;font-size:13px}
  .ph-tabs{flex-wrap:wrap;gap:4px}
  .tab-btn{flex:1;min-height:36px;font-size:12px}
  .btn-add{min-height:44px;padding:8px 16px;font-size:13px}
}
@media(max-width:480px){
  .admin-table{min-width:400px}
  .modal{width:min(96vw,440px)}
  .modal-body{padding:14px}
  .inp{font-size:16px}
  .btn-save,.btn-cancel{min-height:44px;font-size:14px}
}
</style>
