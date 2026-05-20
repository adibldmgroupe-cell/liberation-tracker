<template>
  <div @click="closeAll">
    <div class="ph">
      <span class="pt">LOTS</span>
      <div class="ph-right">
        <span class="pc" v-if="total">{{total}} lots</span>
        <button class="btn-toggle" @click.stop="showDates=!showDates">{{showDates?'Voir statuts':'Voir dates'}}</button>
        <div class="col-panel-wrap" @click.stop>
          <button class="btn-cols" :class="{'btn-cols-on':showColPanel}" @click="showColPanel=!showColPanel">⚙ Colonnes</button>
          <div class="col-panel" v-if="showColPanel">
            <div class="col-panel-title">Afficher / masquer</div>
            <label v-for="col in colDefs" :key="col.key" class="col-item">
              <input type="checkbox" :checked="isColVisible(col.key)" @change="toggleCol(col.key)" />
              {{col.label}}
            </label>
            <button class="col-reset" @click="resetCols">Tout afficher</button>
          </div>
        </div>
        <button class="btn-exp" @click="doExportExcel">📥 Excel</button>
        <button class="btn-exp" @click="doExportPDF">📄 PDF</button>
      </div>
    </div>
    <div class="filters">
      <button v-for="f in filterOptions" :key="f.value" class="fbtn" :class="{active:activeFilters.includes(f.value)}" @click="toggleFilter(f.value)">
        <span class="fdot" :style="{background:f.color}"></span>{{f.label}}
      </button>
    </div>

    <!-- Barre d'actions en masse -->
    <div class="bulk-bar">
      <select v-model="actionType" class="bulk-sel">
        <option value="">— Choisir une action —</option>
        <template v-for="grp in actionGroups" :key="grp.label">
          <optgroup :label="grp.label">
            <option v-for="opt in grp.actions" :key="opt.value" :value="opt.value">{{opt.label}}</option>
          </optgroup>
        </template>
      </select>
      <!-- Date input pour les actions de planification -->
      <div v-if="actionType.startsWith('plan_')" class="bulk-date-wrap">
        <label class="bulk-date-lbl">Date :</label>
        <input type="date" v-model="bulkDate" class="bulk-date-in" />
      </div>
      <button class="bulk-btn" :disabled="!canExecute" @click="showConfirm=true">
        Exécuter<span v-if="selected.length"> ({{selected.length}})</span>
      </button>
      <span v-if="selected.length" class="bulk-info">{{selected.length}} lot(s) sélectionné(s)</span>
      <button v-if="selected.length" class="bulk-clear" @click="selected=[]">✕ Tout désélectionner</button>
    </div>

    <!-- Chips filtres colonnes actifs -->
    <div v-if="hasColumnFilters" class="cf-bar">
      <span class="cf-label">Filtres actifs :</span>
      <span v-for="(val,col) in columnFilters" :key="col" class="cf-chip">
        {{col}} : <strong>{{val}}</strong>
        <button class="cf-rm" @click="removeColumnFilter(col)">✕</button>
      </span>
      <button class="cf-clear" @click="clearColumnFilters">Tout effacer</button>
    </div>

    <div v-if="!filteredLots.length" class="empty">Aucun lot trouvé</div>
    <div v-else class="table-wrap">
      <table class="tb">
        <thead><tr>
          <th class="th-chk"><input type="checkbox" :checked="allVisibleChecked" @change="toggleAll" /></th>
          <th><div class="th-i"><span class="th-txt sortable" @click="sortBy('numero_lot')">N° Lot <span class="sort-arrow">{{sortIcon('numero_lot')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['numero_lot']}" @click="openDropdown('numero_lot',$event)">⌄</button></div></th>
          <th><div class="th-i"><span class="th-txt sortable" @click="sortBy('prod_desc')">Produit <span class="sort-arrow">{{sortIcon('prod_desc')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['prod_desc']}" @click="openDropdown('prod_desc',$event)">⌄</button></div></th>
          <th><div class="th-i"><span class="th-txt sortable" @click="sortBy('statut_label')">Statut <span class="sort-arrow">{{sortIcon('statut_label')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['statut_label']}" @click="openDropdown('statut_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('of')"><div class="th-i"><span class="th-txt sortable" @click="sortBy('of_label')">OF <span class="sort-arrow">{{sortIcon('of_label')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['of_label']}" @click="openDropdown('of_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('oc')"><div class="th-i"><span class="th-txt sortable" @click="sortBy('oc_label')">OC <span class="sort-arrow">{{sortIcon('oc_label')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['oc_label']}" @click="openDropdown('oc_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('aql_fab')"><div class="th-i"><span class="th-txt">AQL Fab</span><button class="th-f" :class="{'th-f-on':columnFilters['aql_fab_label']}" @click="openDropdown('aql_fab_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('aql_cond')"><div class="th-i"><span class="th-txt">AQL Cond</span><button class="th-f" :class="{'th-f-on':columnFilters['aql_cond_label']}" @click="openDropdown('aql_cond_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('if')"><div class="th-i"><span class="th-txt sortable" @click="sortBy('if_label')">IF <span class="sort-arrow">{{sortIcon('if_label')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['if_label']}" @click="openDropdown('if_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('ic')"><div class="th-i"><span class="th-txt sortable" @click="sortBy('ic_label')">IC <span class="sort-arrow">{{sortIcon('ic_label')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['ic_label']}" @click="openDropdown('ic_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('da_pc')"><div class="th-i"><span class="th-txt">DA PC</span><button class="th-f" :class="{'th-f-on':columnFilters['dapc_label']}" @click="openDropdown('dapc_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('da_micro')"><div class="th-i"><span class="th-txt">DA Micro</span><button class="th-f" :class="{'th-f-on':columnFilters['damicro_label']}" @click="openDropdown('damicro_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('dev')"><div class="th-i"><span class="th-txt">Dév.</span><button class="th-f" :class="{'th-f-on':columnFilters['dev_label']}" @click="openDropdown('dev_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('rvp_fab')"><div class="th-i"><span class="th-txt">RVP Fab</span><button class="th-f" :class="{'th-f-on':columnFilters['rvp_fab_label']}" @click="openDropdown('rvp_fab_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('rvp_cond')"><div class="th-i"><span class="th-txt">RVP Cond</span><button class="th-f" :class="{'th-f-on':columnFilters['rvp_cond_label']}" @click="openDropdown('rvp_cond_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('rvp_lcq')"><div class="th-i"><span class="th-txt">RVP LCQ</span><button class="th-f" :class="{'th-f-on':columnFilters['rvp_lcq_label']}" @click="openDropdown('rvp_lcq_label',$event)">⌄</button></div></th>
          <th v-show="isColVisible('plan_lcq')"><div class="th-i"><span class="th-txt">Lib. LCQ</span><button class="th-f" :class="{'th-f-on':columnFilters['plan_lcq']}" @click="openDropdown('plan_lcq',$event)">⌄</button></div></th>
          <th v-show="isColVisible('plan_aq')"><div class="th-i"><span class="th-txt">Lib. AQ</span><button class="th-f" :class="{'th-f-on':columnFilters['plan_aq']}" @click="openDropdown('plan_aq',$event)">⌄</button></div></th>
          <th v-show="isColVisible('plan_dt1')"><div class="th-i"><span class="th-txt">Lib. DT1</span><button class="th-f" :class="{'th-f-on':columnFilters['plan_dt1']}" @click="openDropdown('plan_dt1',$event)">⌄</button></div></th>
          <th v-show="isColVisible('plan_dt2')"><div class="th-i"><span class="th-txt">Lib. DT2</span><button class="th-f" :class="{'th-f-on':columnFilters['plan_dt2']}" @click="openDropdown('plan_dt2',$event)">⌄</button></div></th>
          <th v-show="isColVisible('date')"><div class="th-i"><span class="th-txt sortable" @click="sortBy('date_fmt')">{{showDates?'Libération':'Entrée'}} <span class="sort-arrow">{{sortIcon('date_fmt')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['date_fmt']}" @click="openDropdown('date_fmt',$event)">⌄</button></div></th>
        </tr></thead>
        <tbody>
          <tr v-for="l in filteredLots" :key="l.id" :class="{'row-sel':isSelected(l.id)}" @click="goToLot(l.id)">
            <td class="td-chk" @click.stop><input type="checkbox" :value="l.id" v-model="selected" /></td>
            <td class="mono bold">{{l.numero_lot}}</td>
            <td class="td-prod">{{l.prod_desc}}<span class="code">{{l.prod_code}}</span></td>
            <td><span class="sp" :class="l.statut_class">{{l.statut_label}}</span></td>
            <td v-show="isColVisible('of')" class="td-action" @click.stop="openInlineMenu($event,l,'of')"><span class="doc-pip" :class="showDates&&l.of_date?'dc-date':l.of_done?'pip-done-t':'pip-prog-t'">{{showDates&&l.of_date?l.of_date:l.of_label}}</span></td>
            <td v-show="isColVisible('oc')" class="td-action" @click.stop="openInlineMenu($event,l,'oc')"><span class="doc-pip" :class="showDates&&l.oc_date?'dc-date':l.oc_done?'pip-done-t':'pip-prog-t'">{{showDates&&l.oc_date?l.oc_date:l.oc_label}}</span></td>
            <td v-show="isColVisible('aql_fab')" class="td-action" @click.stop="openInlineMenu($event,l,'aql_fab')"><span class="doc-pip" :class="l.aql_fab_class">{{showDates&&l.aql_fab_date?l.aql_fab_date:l.aql_fab_label}}</span></td>
            <td v-show="isColVisible('aql_cond')" class="td-action" @click.stop="openInlineMenu($event,l,'aql_cond')"><span class="doc-pip" :class="l.aql_cond_class">{{showDates&&l.aql_cond_date?l.aql_cond_date:l.aql_cond_label}}</span></td>
            <td v-show="isColVisible('if')" class="td-action" @click.stop="openInlineMenu($event,l,'if')"><span class="doc-pip" :class="showDates&&l.if_date?'dc-date':l.if_class">{{showDates&&l.if_date?l.if_date:l.if_label}}</span></td>
            <td v-show="isColVisible('ic')" class="td-action" @click.stop="openInlineMenu($event,l,'ic')"><span class="doc-pip" :class="showDates&&l.ic_date?'dc-date':l.ic_class">{{showDates&&l.ic_date?l.ic_date:l.ic_label}}</span></td>
            <td v-show="isColVisible('da_pc')" class="td-action" @click.stop="openInlineMenu($event,l,'da_pc')"><span class="doc-pip" :class="showDates&&l.dapc_date?'dc-date':l.dapc_class">{{showDates&&l.dapc_date?l.dapc_date:l.dapc_label}}</span></td>
            <td v-show="isColVisible('da_micro')" class="td-action" @click.stop="openInlineMenu($event,l,'da_micro')"><span class="doc-pip" :class="showDates&&l.damicro_date?'dc-date':l.damicro_class">{{showDates&&l.damicro_date?l.damicro_date:l.damicro_label}}</span></td>
            <td v-show="isColVisible('dev')" class="td-action" @click.stop="openInlineMenu($event,l,'dev')">
              <span v-if="l.dev_count>0" class="dev-badge" :class="l.dev_open>0?'dev-open':'dev-closed'">{{l.dev_open>0?'Ouverte':'Clôturée'}}</span>
              <span v-else class="dim">—</span>
            </td>
            <td v-show="isColVisible('rvp_fab')" class="td-action" @click.stop="openInlineMenu($event,l,'rvp_fab')"><span class="doc-pip" :class="l.rvp_fab_class">{{l.rvp_fab_label}}</span></td>
            <td v-show="isColVisible('rvp_cond')" class="td-action" @click.stop="openInlineMenu($event,l,'rvp_cond')"><span class="doc-pip" :class="l.rvp_cond_class">{{l.rvp_cond_label}}</span></td>
            <td v-show="isColVisible('rvp_lcq')" class="td-action" @click.stop="openInlineMenu($event,l,'rvp_lcq')"><span class="doc-pip" :class="l.rvp_lcq_class">{{l.rvp_lcq_label}}</span></td>
            <!-- Dates prévisionnelles -->
            <td v-show="isColVisible('plan_lcq')" class="td-plan td-action" @click.stop="openDatePicker($event,l,'plan_lcq')">
              <span v-if="l.plan_lcq" class="plan-date" :class="getPlanClass(l,'lcq')">{{l.plan_lcq}}</span>
              <span v-else class="plan-empty">＋</span>
            </td>
            <td v-show="isColVisible('plan_aq')" class="td-plan td-action" @click.stop="openDatePicker($event,l,'plan_aq')">
              <span v-if="l.plan_aq" class="plan-date" :class="getPlanClass(l,'aq')">{{l.plan_aq}}</span>
              <span v-else class="plan-empty">＋</span>
            </td>
            <td v-show="isColVisible('plan_dt1')" class="td-plan td-action" @click.stop="openDatePicker($event,l,'plan_dt1')">
              <span v-if="l.plan_dt1" class="plan-date" :class="getPlanClass(l,'dt')">{{l.plan_dt1}}</span>
              <span v-else class="plan-empty">＋</span>
            </td>
            <td v-show="isColVisible('plan_dt2')" class="td-plan td-action" @click.stop="openDatePicker($event,l,'plan_dt2')">
              <span v-if="l.plan_dt2" class="plan-date plan-revised" :class="getPlanClass(l,'dt')">{{l.plan_dt2}}</span>
              <span v-else class="plan-empty">＋</span>
            </td>
            <td v-show="isColVisible('date')" class="mono dim">{{showDates?(l.date_lib||l.date_fmt):l.date_fmt}}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Dropdown filtre colonne (position:fixed) -->
    <div v-if="activeDropdown" class="col-dd" :style="{top:ddPos.top+'px',left:ddPos.left+'px'}" @click.stop>
      <div class="col-dd-item col-dd-all" @click="setColumnFilter(null)">— Tout —</div>
      <div v-for="v in getColumnValues(activeDropdown)" :key="v" class="col-dd-item" :class="{'col-dd-on':columnFilters[activeDropdown]===v}" @click="setColumnFilter(v)">{{v}}</div>
    </div>

    <!-- Menu inline actions (position:fixed) -->
    <div v-if="inlineMenu" class="inline-menu" :style="{top:inlineMenu.top+'px',left:inlineMenu.left+'px'}" @click.stop>
      <div class="inline-menu-title">{{inlineMenu.colLabel}}</div>
      <button v-for="(act,idx) in inlineMenu.actions" :key="idx" class="inline-act" @click="executeInline(act.fn)">{{act.label}}</button>
      <div v-if="!inlineMenu.actions.length" class="inline-empty">Aucune action disponible</div>
    </div>

    <!-- Date picker inline planification (position:fixed) -->
    <div v-if="datePicker" class="date-picker-pop" :style="{top:datePicker.top+'px',left:datePicker.left+'px'}" @click.stop>
      <div class="dp-title">{{datePicker.label}}</div>
      <input type="date" v-model="datePicker.value" class="dp-input" @change="loadCharge" @keydown.enter="savePlanning" @keydown.escape="datePicker=null" ref="dpInput" />
      <div class="dp-charge" v-if="datePicker.value">
        <span v-if="chargeLoading" class="charge-loading">⟳ Vérification…</span>
        <span v-else-if="chargeCount===0" class="charge-ok">✓ Aucun autre lot prévu ce jour</span>
        <span v-else-if="chargeCount!==null" :class="chargeCount>=15?'charge-high':chargeCount>=8?'charge-med':'charge-low'">
          📅 {{chargeCount}} autre{{chargeCount>1?'s':''}} lot{{chargeCount>1?'s':''}} prévu{{chargeCount>1?'s':''}} ce jour
        </span>
      </div>
      <div class="dp-actions">
        <button class="dp-ok" @click="savePlanning">✓ Valider</button>
        <button class="dp-cancel" @click="datePicker=null">✕</button>
      </div>
    </div>

    <!-- Modal confirmation action en masse -->
    <div class="m-overlay" v-if="showConfirm" @click.self="showConfirm=false">
      <div class="m-box">
        <div class="m-title">Confirmer l'action en masse</div>
        <div class="m-body">
          <div class="m-line"><span class="m-lbl">Action</span><span>{{actionLabel}}</span></div>
          <div class="m-line"><span class="m-lbl">Lots concernés</span><span class="mono">{{selected.length}}</span></div>
          <div class="m-line" v-if="actionType.startsWith('plan_')">
            <span class="m-lbl">Date</span>
            <input type="date" v-model="bulkDate" class="bulk-date-in" style="font-size:13px;padding:4px 8px;border:1px solid #ddd;border-radius:2px" />
          </div>
          <div class="m-chips">
            <span v-for="id in selected.slice(0,20)" :key="id" class="m-chip">{{getLotNum(id)}}</span>
            <span v-if="selected.length>20" class="m-chip m-more">+{{selected.length-20}} autres</span>
          </div>
        </div>
        <div class="m-result" v-if="execResult">
          <div class="m-rh">Exécution terminée</div>
          <div class="m-rg">
            <div class="m-rc"><div class="m-rv" style="color:#1D9E75">{{execResult.ok}}</div><div class="m-rl">Réussis</div></div>
            <div class="m-rc"><div class="m-rv" style="color:#E24B4A">{{execResult.fail}}</div><div class="m-rl">Échoués</div></div>
          </div>
          <div v-if="execResult.errors.length" class="m-errs">
            <div v-for="(e,i) in execResult.errors" :key="i" class="m-err">{{e}}</div>
          </div>
        </div>
        <div class="m-actions">
          <button class="m-btn-ok" @click="executeAction" :disabled="executing">{{executing?'En cours... '+progress+'/'+selected.length:'Confirmer'}}</button>
          <button class="m-btn-cancel" @click="showConfirm=false;execResult=null">Annuler</button>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { exportToExcel, exportToPDF } from '../services/export'
import { createNotification } from '../services/notifications'
import { canPerform, loadPermissions, getPermissionForBulkAction, getPermissionForEtape } from '../services/permissions'
export default {
  setup() {
    var route = useRoute(), router = useRouter()
    var lots = ref([]), total = ref(0), activeFilters = ref([])
    var sortCol = ref(''), sortDir = ref('asc'), showDates = ref(false)
    var selected = ref([]), actionType = ref(''), showConfirm = ref(false)
    var executing = ref(false), progress = ref(0), execResult = ref(null)
    var userService = ref(''), bulkDate = ref('')
    var dpInput = ref(null)

    // ── Autorisation via table permissions DB ─────────────────────────
    var canAction = function(action) {
      if (userService.value === 'admin') return true
      var permKey = getPermissionForBulkAction(action)
      return permKey ? canPerform(permKey) : false
    }

    // ── Définition complète des groupes d'actions ──────────────────────
    var actionGroupDefs = [
      {label:'Circuit OF',actions:[{value:'of_planification',label:'OF — Mise en circuit'},{value:'of_stock',label:'OF — Validation Stock'},{value:'of_aq',label:'OF — Validation AQ'},{value:'of_dt',label:'OF — Autorisation DT'},{value:'of_aq_dap',label:'OF — Remise AQ DAP'},{value:'of_production',label:'OF — Accusé réception'}]},
      {label:'Circuit OC',actions:[{value:'oc_planification',label:'OC — Mise en circuit'},{value:'oc_stock',label:'OC — Validation Stock'},{value:'oc_aq',label:'OC — Validation AQ'},{value:'oc_dt',label:'OC — Autorisation DT'},{value:'oc_aq_dap',label:'OC — Remise AQ DAP'},{value:'oc_production',label:'OC — Accusé réception'}]},
      {label:'Documents — Émission',actions:[{value:'doc_if',label:'IF — Émettre'},{value:'doc_ic',label:'IC — Émettre'},{value:'doc_da_pc',label:'DA Physico — Émettre'},{value:'doc_da_micro',label:'DA Micro — Émettre'}]},
      {label:'Documents — Vérification AQ → DT',actions:[{value:'doc_if_verifier',label:'IF — Vérifier AQ → DT'},{value:'doc_ic_verifier',label:'IC — Vérifier AQ → DT'},{value:'doc_da_pc_verifier',label:'DA Physico — Vérifier AQ → DT'},{value:'doc_da_micro_verifier',label:'DA Micro — Vérifier AQ → DT'}]},
      {label:'Documents — Approbation DT',actions:[{value:'doc_if_approuver',label:'IF — Approuver DT'},{value:'doc_ic_approuver',label:'IC — Approuver DT'},{value:'doc_da_pc_approuver',label:'DA Physico — Approuver DT'},{value:'doc_da_micro_approuver',label:'DA Micro — Approuver DT'}]},
      {label:'Documents — Retour',actions:[{value:'doc_if_retour_emetteur',label:"IF — Retourner à l'émetteur"},{value:'doc_ic_retour_emetteur',label:"IC — Retourner à l'émetteur"},{value:'doc_da_pc_retour_emetteur',label:"DA Physico — Retourner à l'émetteur"},{value:'doc_da_micro_retour_emetteur',label:"DA Micro — Retourner à l'émetteur"},{value:'doc_if_retour_aq',label:"IF — DT retourne à l'AQ"},{value:'doc_ic_retour_aq',label:"IC — DT retourne à l'AQ"},{value:'doc_da_pc_retour_aq',label:"DA Physico — DT retourne à l'AQ"},{value:'doc_da_micro_retour_aq',label:"DA Micro — DT retourne à l'AQ"}]},
      {label:'AQL',actions:[{value:'aql_fab_demander',label:'AQL Fabrication — Demander'},{value:'aql_fab_relancer',label:'AQL Fabrication — Relancer'},{value:'aql_fab_conforme',label:'AQL Fabrication — Conforme'},{value:'aql_fab_non_conforme',label:'AQL Fabrication — Non conforme'},{value:'aql_cond_demander',label:'AQL Conditionnement — Demander'},{value:'aql_cond_relancer',label:'AQL Conditionnement — Relancer'},{value:'aql_cond_conforme',label:'AQL Conditionnement — Conforme'},{value:'aql_cond_non_conforme',label:'AQL Conditionnement — Non conforme'}]},
      {label:'RVP — Émission',actions:[{value:'rvp_fab_emettre',label:'RVP Fabrication — Émettre'},{value:'rvp_cond_emettre',label:'RVP Conditionnement — Émettre'},{value:'rvp_lcq_emettre',label:'RVP LCQ — Émettre'}]},
      {label:'RVP — Vérification AQ → DT',actions:[{value:'rvp_fab_verifier',label:'RVP Fabrication — Vérifier AQ → DT'},{value:'rvp_cond_verifier',label:'RVP Conditionnement — Vérifier AQ → DT'},{value:'rvp_lcq_verifier',label:'RVP LCQ — Vérifier AQ → DT'}]},
      {label:'RVP — Approbation DT',actions:[{value:'rvp_fab_approuver',label:'RVP Fabrication — Approuver DT'},{value:'rvp_cond_approuver',label:'RVP Conditionnement — Approuver DT'},{value:'rvp_lcq_approuver',label:'RVP LCQ — Approuver DT'}]},
      {label:'RVP — Retour',actions:[{value:'rvp_fab_retour_emetteur',label:"RVP Fabrication — Retourner à l'émetteur"},{value:'rvp_cond_retour_emetteur',label:"RVP Conditionnement — Retourner à l'émetteur"},{value:'rvp_lcq_retour_emetteur',label:"RVP LCQ — Retourner à l'émetteur"},{value:'rvp_fab_retour_aq',label:"RVP Fabrication — DT retourne à l'AQ"},{value:'rvp_cond_retour_aq',label:"RVP Conditionnement — DT retourne à l'AQ"},{value:'rvp_lcq_retour_aq',label:"RVP LCQ — DT retourne à l'AQ"}]},
      {label:'Déviation',actions:[{value:'dev_declarer',label:'Déviation — Déclarer'},{value:'dev_cloture',label:'Déviation — Clôturer'}]},
      {label:'Dates prévisionnelles',actions:[{value:'plan_lcq_cible',label:'Libération LCQ — Date cible'},{value:'plan_lcq',label:'Libération LCQ — Date révisée'},{value:'plan_aq_cible',label:'Libération AQ — Date cible'},{value:'plan_aq',label:'Libération AQ — Date révisée'},{value:'plan_dt1',label:'Libération DT — Date cible'},{value:'plan_dt2',label:'Libération DT — Date révisée'}]},
    ]
    var actionGroups = computed(function(){
      return actionGroupDefs.map(function(g){
        return {label:g.label,actions:g.actions.filter(function(a){return canAction(a.value)})}
      }).filter(function(g){return g.actions.length>0})
    })

    // ── Colonnes show/hide ─────────────────────────────────────────────
    var ALL_COLS = ['of','oc','aql_fab','aql_cond','if','ic','da_pc','da_micro','dev','rvp_fab','rvp_cond','rvp_lcq','plan_lcq','plan_aq','plan_dt1','plan_dt2','date']
    var COL_LABELS = {of:'OF',oc:'OC',aql_fab:'AQL Fab',aql_cond:'AQL Cond','if':'IF',ic:'IC',da_pc:'DA PC',da_micro:'DA Micro',dev:'Dév.',rvp_fab:'RVP Fab',rvp_cond:'RVP Cond',rvp_lcq:'RVP LCQ',plan_lcq:'Lib. LCQ',plan_aq:'Lib. AQ',plan_dt1:'Lib. DT1',plan_dt2:'Lib. DT2',date:'Date entrée'}
    var savedCols = null
    try { savedCols = JSON.parse(localStorage.getItem('lots_vis_cols')) } catch(e) {}
    var visibleCols = ref(savedCols || ALL_COLS.slice())
    var showColPanel = ref(false)
    var colDefs = ALL_COLS.map(function(k){return{key:k,label:COL_LABELS[k]}})
    var isColVisible = function(col){ return visibleCols.value.indexOf(col) >= 0 }
    var toggleCol = function(col){
      var idx = visibleCols.value.indexOf(col)
      if(idx>=0) visibleCols.value.splice(idx,1); else visibleCols.value.push(col)
      try { localStorage.setItem('lots_vis_cols', JSON.stringify(visibleCols.value)) } catch(e) {}
    }
    var resetCols = function(){ visibleCols.value = ALL_COLS.slice(); try{localStorage.removeItem('lots_vis_cols')}catch(e){} }
    // ──────────────────────────────────────────────────────────────────

    var statusLabels = {vide:'Planifié',quarantaine:'Quarantaine',sous_investigation:'Investigation',accepte:'Accepté',refuse:'Refusé'}
    var filterOptions = [
      {label:'Planifié',value:'planifie',color:'#999'},
      {label:'En préparation',value:'en_preparation',color:'#5B3CC4'},
      {label:'En production',value:'en_production',color:'#185FA5'},
      {label:'Quarantaine',value:'quarantaine',color:'#FFA94D'},
      {label:'Investigation',value:'sous_investigation',color:'#E24B4A'},
      {label:'Acceptés',value:'accepte',color:'#1D9E75'},
      {label:'Refusé',value:'refuse',color:'#666'},
    ]
    var etapeLabels = {planification:'Planif.',stock:'Stock',aq:'AQ',dt:'DT',aq_dap:'AQ DAP',production:'Prod.'}
    var docStatutLabels = {non_emis:'Non émis',emis:'Émis',verification_aq:'Vérif AQ',retour_emetteur:'Retourné',rectification:'Rectif.',approuve_aq:'Appr. AQ',approbation_dt:'Appr. DT',approuve_dt:'Approuvé'}
    var fmt = function(d){return d?new Date(d).toLocaleDateString('fr-FR'):'—'}
    var fmtPlan = function(d){return d?new Date(d+'T00:00:00').toLocaleDateString('fr-FR'):null}

    var getGranularStatus = function(of,oc,docs,statutSap) {
      if(statutSap==='accepte')return{label:'Accepté',cls:'s-accepte',filter:'accepte'}
      if(statutSap==='quarantaine')return{label:'Quarantaine',cls:'s-quarantaine',filter:'quarantaine'}
      if(statutSap==='sous_investigation')return{label:'Investigation',cls:'s-sous_investigation',filter:'sous_investigation'}
      if(statutSap==='refuse')return{label:'Refusé',cls:'s-refuse',filter:'refuse'}
      var anyDocEmis=false
      if(docs){for(var i=0;i<docs.length;i++){var t=docs[i].type_document;if((t==='if'||t==='ic'||t==='da_pc'||t==='da_micro')&&docs[i].statut!=='non_emis'){anyDocEmis=true;break}}}
      if(anyDocEmis)return{label:'En production',cls:'s-enprod',filter:'en_production'}
      var ofRecu=of&&(of.etape_circuit==='production'||of.statut==='termine')
      var ocRecu=oc&&(oc.etape_circuit==='production'||oc.statut==='termine')
      if(ofRecu||ocRecu)return{label:'En production',cls:'s-enprod',filter:'en_production'}
      var ofStarted=of&&of.etape_circuit!=='planification'
      var ocStarted=oc&&oc.etape_circuit!=='planification'
      if(ofStarted||ocStarted)return{label:'En préparation',cls:'s-enprep',filter:'en_preparation'}
      return{label:'Planifié',cls:'s-vide',filter:'planifie'}
    }

    var getDocInfo = function(docs,type){
      var d=null;if(docs){for(var i=0;i<docs.length;i++){if(docs[i].type_document===type){d=docs[i];break}}}
      if(!d)return{label:'—',cls:'dc-na',date:null}
      if(!d.is_applicable)return{label:'N/A',cls:'dc-na',date:null}
      var label=docStatutLabels[d.statut]||d.statut
      var cls='dc-wait';if(d.statut==='approuve_dt')cls='dc-ok';else if(d.statut==='retour_emetteur')cls='dc-ret';else if(d.statut!=='non_emis')cls='dc-prog'
      var date=d.approved_at||d.emitted_at;return{label:label,cls:cls,date:date?fmt(date):null}
    }

    var getRvpInfo = function(docs,emetteur){
      var d=null;if(docs){for(var i=0;i<docs.length;i++){if(docs[i].type_document==='rvp'&&docs[i].service_emetteur===emetteur){d=docs[i];break}}}
      if(!d)return{label:'—',cls:'dc-na'}
      var label=docStatutLabels[d.statut]||d.statut
      var cls='dc-wait';if(d.statut==='approuve_dt')cls='dc-ok';else if(d.statut==='retour_emetteur')cls='dc-ret';else if(d.statut!=='non_emis')cls='dc-prog'
      return{label:label,cls:cls}
    }

    var getAqlInfo = function(aqls,type){
      if(!aqls||!aqls.length)return{label:'—',cls:'dc-na',date:null}
      var latest=null;for(var i=0;i<aqls.length;i++){if(aqls[i].type===type){if(!latest||new Date(aqls[i].requested_at||0)>new Date(latest.requested_at||0))latest=aqls[i]}}
      if(!latest)return{label:'—',cls:'dc-na',date:null}
      if(latest.resultat==='conforme')return{label:'Conforme',cls:'dc-ok',date:latest.inspected_at?fmt(latest.inspected_at):null}
      if(latest.resultat==='non_conforme')return{label:'Non conf.',cls:'dc-ret',date:latest.inspected_at?fmt(latest.inspected_at):null}
      return{label:'En attente',cls:'dc-prog',date:latest.requested_at?fmt(latest.requested_at):null}
    }

    var getOfOcInfo = function(order,statutSap){
      var inStock=statutSap==='quarantaine'||statutSap==='sous_investigation'||statutSap==='accepte'||statutSap==='refuse'
      if(inStock)return{label:'Terminé',done:true,date:null}
      if(!order)return{label:'—',done:false,date:null}
      if(order.statut==='termine')return{label:'Terminé',done:true,date:order.updated_at?fmt(order.updated_at):null}
      return{label:etapeLabels[order.etape_circuit]||order.etape_circuit||'—',done:false,date:order.updated_at?fmt(order.updated_at):null}
    }

    var getPlanClass = function(lot, type) {
      var today = new Date(); today.setHours(0,0,0,0)
      var tomorrow = new Date(today); tomorrow.setDate(tomorrow.getDate()+1)
      var rawDate = type==='lcq'?(lot.plan_lcq_raw):type==='aq'?(lot.plan_aq_raw):type==='dt'?(lot.plan_dt2_raw||lot.plan_dt1_raw):null
      if (!rawDate) return ''
      var d = new Date(rawDate+'T00:00:00')
      if (d < today) return 'plan-crit'
      if (d.getTime() === today.getTime()) return 'plan-urgent'
      if (d.getTime() === tomorrow.getTime()) return 'plan-warn'
      return ''
    }

    var load = async function() {
      var query = supabase.from('lots').select('*, products(code_article,description), orders_of(id,statut,etape_circuit,updated_at), orders_oc(id,statut,etape_circuit,updated_at), liberation_documents(id,type_document,statut,is_applicable,service_emetteur,emitted_at,approved_at), deviations(statut), aql_inspections(id,type,resultat,requested_at,inspected_at), lot_planning(date_lcq_cible,date_lcq_revisee,date_aq_cible,date_aq_revisee,date_dt_cible,date_dt_revisee)', {count:'exact'})

      var q = route.query.q
      if(q){
        var matchRes=await supabase.from('products').select('id').or('code_article.ilike.%'+q+'%,description.ilike.%'+q+'%')
        var prodIds=(matchRes.data||[]).map(function(p){return p.id})
        if(prodIds.length){query=query.or('numero_lot.ilike.%'+q+'%,product_id.in.('+prodIds.join(',')+')')}
        else{query=query.ilike('numero_lot','%'+q+'%')}
      }

      query=query.order('date_enregistrement',{ascending:false,nullsFirst:false})
      var result=await query
      total.value=result.count||(result.data?result.data.length:0)

      lots.value=(result.data||[]).map(function(l){
        var docs=l.liberation_documents||[]
        var devs=l.deviations||[]
        var aqls=l.aql_inspections||[]
        var of=Array.isArray(l.orders_of)?l.orders_of[0]:l.orders_of
        var oc=Array.isArray(l.orders_oc)?l.orders_oc[0]:l.orders_oc
        var planning=Array.isArray(l.lot_planning)?l.lot_planning[0]:l.lot_planning

        var statutInfo=getGranularStatus(of,oc,docs,l.statut_sap)
        var ofInfo=getOfOcInfo(of,l.statut_sap)
        var ocInfo=getOfOcInfo(oc,l.statut_sap)
        var ifInfo=getDocInfo(docs,'if')
        var icInfo=getDocInfo(docs,'ic')
        var dapcInfo=getDocInfo(docs,'da_pc')
        var damicroInfo=getDocInfo(docs,'da_micro')
        var aqlFab=getAqlInfo(aqls,'fabrication')
        var aqlCond=getAqlInfo(aqls,'conditionnement')
        var rvpFab=getRvpInfo(docs,'fabrication')
        var rvpCond=getRvpInfo(docs,'conditionnement')
        var rvpLcq=getRvpInfo(docs,'lcq')
        var devOpen=0;for(var j=0;j<devs.length;j++){if(devs[j].statut==='ouverte'||devs[j].statut==='en_cours')devOpen++}

        var planLcqRaw = planning ? (planning.date_lcq_revisee || planning.date_lcq_cible) : null
        var planAqRaw  = planning ? (planning.date_aq_revisee  || planning.date_aq_cible)  : null
        var planDt1Raw = planning ? planning.date_dt_cible   : null
        var planDt2Raw = planning ? planning.date_dt_revisee : null

        return{
          id:l.id,numero_lot:l.numero_lot,statut_sap:l.statut_sap,
          statut_label:statutInfo.label,statut_class:statutInfo.cls,statut_filter:statutInfo.filter,
          date_fmt:fmt(l.date_enregistrement),date_lib:l.date_liberation?fmt(l.date_liberation):null,
          prod_desc:l.products?l.products.description:'',prod_code:l.products?l.products.code_article:'',
          of_label:ofInfo.label,of_done:ofInfo.done,of_date:ofInfo.date,
          oc_label:ocInfo.label,oc_done:ocInfo.done,oc_date:ocInfo.date,
          if_label:ifInfo.label,if_class:ifInfo.cls,if_date:ifInfo.date,
          ic_label:icInfo.label,ic_class:icInfo.cls,ic_date:icInfo.date,
          dapc_label:dapcInfo.label,dapc_class:dapcInfo.cls,dapc_date:dapcInfo.date,
          damicro_label:damicroInfo.label,damicro_class:damicroInfo.cls,damicro_date:damicroInfo.date,
          aql_fab_label:aqlFab.label,aql_fab_class:aqlFab.cls,aql_fab_date:aqlFab.date,
          aql_cond_label:aqlCond.label,aql_cond_class:aqlCond.cls,aql_cond_date:aqlCond.date,
          rvp_fab_label:rvpFab.label,rvp_fab_class:rvpFab.cls,
          rvp_cond_label:rvpCond.label,rvp_cond_class:rvpCond.cls,
          rvp_lcq_label:rvpLcq.label,rvp_lcq_class:rvpLcq.cls,
          dev_count:devs.length,dev_open:devOpen,dev_label:devs.length>0?(devOpen>0?'Ouverte':'Clôturée'):'—',
          plan_lcq:fmtPlan(planLcqRaw),plan_lcq_raw:planLcqRaw,
          plan_lcq_cible_raw:planning?planning.date_lcq_cible:null,
          plan_aq:fmtPlan(planAqRaw),plan_aq_raw:planAqRaw,
          plan_aq_cible_raw:planning?planning.date_aq_cible:null,
          plan_dt1:fmtPlan(planDt1Raw),plan_dt1_raw:planDt1Raw,
          plan_dt2:fmtPlan(planDt2Raw),plan_dt2_raw:planDt2Raw,
          of_id:of?of.id:null,oc_id:oc?oc.id:null,docs:docs,aqls_raw:aqls,
          of_etape:of?of.etape_circuit:null,oc_etape:oc?oc.etape_circuit:null,
          of_statut:of?of.statut:null,oc_statut:oc?oc.statut:null,
        }
      })
    }

    // ── Filtres par colonne ────────────────────────────────────────────
    var columnFilters = ref({})
    var activeDropdown = ref(null)
    var ddPos = ref({top:0,left:0})

    var openDropdown = function(col, event) {
      event.stopPropagation()
      if (activeDropdown.value === col) { activeDropdown.value = null; return }
      var rect = event.currentTarget.getBoundingClientRect()
      ddPos.value = { top: rect.bottom + 2, left: rect.left }
      activeDropdown.value = col
    }
    var getColumnValues = function(col) {
      var seen = {}, vals = []
      lots.value.forEach(function(l) {
        var v = l[col]
        if(v!==undefined&&v!==null&&v!==''&&v!=='—'&&!seen[v]){seen[v]=true;vals.push(v)}
      })
      return vals.sort()
    }
    var setColumnFilter = function(val) {
      var col = activeDropdown.value
      if(val===null){var nf={};Object.keys(columnFilters.value).forEach(function(k){if(k!==col)nf[k]=columnFilters.value[k]});columnFilters.value=nf}
      else{columnFilters.value=Object.assign({},columnFilters.value,{[col]:val})}
      activeDropdown.value = null
    }
    var clearColumnFilters = function(){columnFilters.value={};activeDropdown.value=null}
    var removeColumnFilter = function(col){var nf={};Object.keys(columnFilters.value).forEach(function(k){if(k!==col)nf[k]=columnFilters.value[k]});columnFilters.value=nf}
    var hasColumnFilters = computed(function(){return Object.keys(columnFilters.value).length>0})
    // ──────────────────────────────────────────────────────────────────

    // ── Inline action menu ─────────────────────────────────────────────
    var inlineMenu = ref(null)
    var FLOW = ['planification','stock','aq','dt','aq_dap','production']
    var ETAPE_LABELS_LONG = {planification:'Mise en circuit',stock:'Valid. Stock',aq:'Valid. AQ',dt:'Autor. DT',aq_dap:'Remise AQ DAP',production:'Accusé récp.'}
    var SVC_MAP = {'if':'fabrication',ic:'conditionnement',da_pc:'lcq',da_micro:'lcq'}
    var COL_LABELS2 = {of:'OF',oc:'OC','if':'IF',ic:'IC',da_pc:'DA PC',da_micro:'DA Micro',aql_fab:'AQL Fab',aql_cond:'AQL Cond',dev:'Déviation',rvp_fab:'RVP Fab',rvp_cond:'RVP Cond',rvp_lcq:'RVP LCQ'}

    var buildInlineActions = function(lot, col) {
      var actions = []
      var isAdmin = userService.value === 'admin'

      if (col === 'of' || col === 'oc') {
        var etape = col === 'of' ? lot.of_etape : lot.oc_etape
        var orderId = col === 'of' ? lot.of_id : lot.oc_id
        if (etape && orderId && (col==='of'?lot.of_statut:lot.oc_statut) !== 'termine') {
          var permKey = getPermissionForEtape(etape, col)
          if (isAdmin || (permKey && canPerform(permKey))) {
            var flowIdx = FLOW.indexOf(etape)
            var nextEtape = flowIdx < FLOW.length-1 ? FLOW[flowIdx+1] : null
            ;(function(e, oid, col2, next) {
              actions.push({
                label: 'Valider — ' + (ETAPE_LABELS_LONG[e]||e),
                fn: async function() {
                  var u = await supabase.auth.getUser(); var uid = u.data.user.id; var n = new Date().toISOString()
                  var tbl = col2==='of'?'orders_of':'orders_oc'
                  var nextLabel = next?(etapeLabels[next]||next):'Terminé'
                  await supabase.from('order_validations').insert({order_type:col2,order_id:oid,etape:e,action:'valide',validated_by:uid,validated_at:n})
                  await supabase.from(tbl).update({statut:next?'en_circuit':'termine',etape_circuit:next||e,updated_at:n}).eq('id',oid)
                  await supabase.from('lots').update({statut_operationnel:col2.toUpperCase()+' — '+nextLabel,updated_at:n}).eq('id',lot.id)
                  var notifSvc = next==='stock'?'stock':next==='aq'?'aq':next==='dt'?'dt':next==='aq_dap'?'aq_dap':next==='production'?(col2==='of'?'fabrication':'conditionnement'):'planification'
                  await createNotification(notifSvc,lot.id,null,'Lot '+lot.numero_lot+' — Circuit '+col2.toUpperCase()+' : '+(ETAPE_LABELS_LONG[e]||e)+' validé','circuit_avance')
                }
              })
            })(etape, orderId, col, nextEtape)
          }
        }

      } else if (col==='if'||col==='ic'||col==='da_pc'||col==='da_micro') {
        var doc = null
        if (lot.docs) { for (var i=0;i<lot.docs.length;i++){if(lot.docs[i].type_document===col){doc=lot.docs[i];break}} }
        if (doc) {
          ;(function(d, col3) {
            // DA Micro : si non applicable, proposer de la déclarer applicable en priorité
            if (col3==='da_micro' && !d.is_applicable) {
              if (isAdmin||canPerform('emettre_da_micro')) {
                actions.push({label:'Déclarer DA Micro applicable', fn: async function(){
                  var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                  await supabase.from('liberation_documents').update({is_applicable:true,is_required:true,updated_at:n}).eq('id',d.id)
                  await supabase.from('liberation_dossiers').update({da_micro_applicable:true,updated_at:n}).eq('lot_id',lot.id)
                  await supabase.from('lot_events').insert({lot_id:lot.id,event_type:'da_micro_applicable',description:'DA Microbiologie déclarée applicable depuis le tableau',triggered_by:uid,created_at:n})
                  await createNotification('lcq',lot.id,d.id,'Lot '+lot.numero_lot+' — DA Microbiologie déclarée applicable','da_micro_applicable')
                }})
              }
              return // ne pas afficher les autres actions tant que non applicable
            }
            if (!d.is_applicable) return // doc non applicable, pas d'action
            if (d.statut==='non_emis' && (isAdmin||canPerform('emettre_'+col3))) {
              actions.push({label:'Émettre '+col3.toUpperCase().replace('_',' '), fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'emission',from_service:SVC_MAP[col3]||'',to_service:'aq',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase()+' émis','document_transmis')
              }})
            }
            if (d.statut==='emis' && (isAdmin||canPerform('verifier_'+col3))) {
              actions.push({label:'Vérifier AQ → DT', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'approuve_aq',updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'approbation',from_service:'aq',to_service:'dt',performed_by:uid,performed_at:n})
                await createNotification('dt',lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase()+' vérifié AQ → DT','document_transmis')
              }})
            }
            if (d.statut==='approuve_aq' && (isAdmin||canPerform('approuver_'+col3))) {
              actions.push({label:'Approuver DT', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:n,updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'approbation',from_service:'dt',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase()+' approuvé DT','document_approuve')
                if(SVC_MAP[col3])await createNotification(SVC_MAP[col3],lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase()+' approuvé DT','document_approuve')
              }})
            }
            if (d.statut==='retour_emetteur' && (isAdmin||canPerform('emettre_'+col3))) {
              actions.push({label:'Rectifier / Réémettre', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'rectification',from_service:SVC_MAP[col3]||'',to_service:'aq',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase().replace('_',' ')+' rectifié et réémis','document_transmis')
              }})
            }
            if ((d.statut==='emis'||d.statut==='verification_aq'||d.statut==='approuve_aq') && (isAdmin||canPerform('retourner_document'))) {
              var fromSvc = d.statut==='approuve_aq'||d.statut==='verification_aq' ? 'aq' : (SVC_MAP[col3]||'')
              actions.push({label:'Retourner', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'retour_emetteur',updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'retour',from_service:fromSvc,to_service:SVC_MAP[col3]||'',motif_retour:'Retour direct tableau',performed_by:uid,performed_at:n})
                if(SVC_MAP[col3])await createNotification(SVC_MAP[col3],lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase()+' retourné pour rectification','document_retourne')
              }})
            }
          })(doc, col)
        }

      } else if (col==='aql_fab'||col==='aql_cond') {
        var aqlType2 = col==='aql_fab'?'fabrication':'conditionnement'
        var aqlPerm = col==='aql_fab'?'demander_aql_fab':'demander_aql_cond'
        var aqlLabel = col==='aql_fab'?'Fabrication':'Conditionnement'
        // Trouver le dernier AQL de ce type
        var typeAqls = (lot.aqls_raw||[]).filter(function(a){return a.type===aqlType2})
        var latestAql2 = null
        for (var ka=0;ka<typeAqls.length;ka++){if(!latestAql2||new Date(typeAqls[ka].requested_at||0)>new Date(latestAql2.requested_at||0))latestAql2=typeAqls[ka]}
        ;(function(aType, aLabel, latest) {
          if (!latest) {
            // Aucun AQL → Demander
            if (isAdmin||canPerform(aqlPerm)) {
              actions.push({label:'Demander AQL '+aLabel, fn: async function(){
                var u=await supabase.auth.getUser();var n=new Date().toISOString()
                await supabase.from('aql_inspections').insert({lot_id:lot.id,type:aType,resultat:'en_attente',requested_at:n})
                await createNotification('aq',lot.id,null,'Lot '+lot.numero_lot+' — AQL '+aLabel+' demandé','aql_demande')
              }})
            }
          } else if (latest.resultat===null||latest.resultat===undefined||latest.resultat==='en_attente') {
            // En attente → Conforme / Non conforme uniquement
            if (isAdmin||canPerform('realiser_aql')) {
              actions.push({label:'AQL Conforme', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('aql_inspections').update({resultat:'conforme',inspected_at:n,inspected_by:uid}).eq('id',latest.id)
                await createNotification('planification',lot.id,null,'Lot '+lot.numero_lot+' — AQL '+aLabel+' : conforme','aql_resultat')
              }})
              actions.push({label:'AQL Non conforme', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('aql_inspections').update({resultat:'non_conforme',inspected_at:n,inspected_by:uid}).eq('id',latest.id)
                await createNotification('planification',lot.id,null,'Lot '+lot.numero_lot+' — AQL '+aLabel+' : non conforme','aql_resultat')
              }})
            }
          } else if (latest.resultat==='non_conforme') {
            // Non conforme → Relancer
            if (isAdmin||canPerform(aqlPerm)) {
              actions.push({label:'Relancer AQL '+aLabel, fn: async function(){
                var u=await supabase.auth.getUser();var n=new Date().toISOString()
                await supabase.from('aql_inspections').insert({lot_id:lot.id,type:aType,resultat:'en_attente',requested_at:n})
                await createNotification('aq',lot.id,null,'Lot '+lot.numero_lot+' — AQL '+aLabel+' relancé','aql_demande')
              }})
            }
          }
          // Conforme → aucune action
        })(aqlType2, aqlLabel, latestAql2)

      } else if (col==='dev') {
        if (isAdmin||canPerform('declarer_nc')) {
          actions.push({label:'Déclarer déviation', fn: async function(){
            var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
            // Générer le numéro de déviation comme dans actions.js
            var countRes = await supabase.from('deviations').select('*',{count:'exact',head:true})
            var numero = 'DEV-' + new Date().getFullYear() + '-' + String(((countRes.count||0)+1)).padStart(3,'0')
            await supabase.from('deviations').insert({lot_id:lot.id,numero_deviation:numero,type:'deviation',statut:'ouverte',description:'Déclaration rapide tableau',declared_by:uid,declared_at:n})
            await supabase.from('liberation_dossiers').update({deviations_closed:false,updated_at:n}).eq('lot_id',lot.id)
            await createNotification('aq',lot.id,null,'Lot '+lot.numero_lot+' — Déviation '+numero+' déclarée','deviation_declaree')
          }})
        }
        if (lot.dev_open>0 && (isAdmin||canPerform('cloturer_deviation'))) {
          actions.push({label:'Clôturer déviations', fn: async function(){
            var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
            await supabase.from('deviations').update({statut:'cloturee',closed_at:n,closed_by:uid,updated_at:n}).eq('lot_id',lot.id).in('statut',['ouverte','en_cours'])
          }})
        }

      } else if (col==='rvp_fab'||col==='rvp_cond'||col==='rvp_lcq') {
        var rvpSvcMap2 = {rvp_fab:'fabrication',rvp_cond:'conditionnement',rvp_lcq:'lcq'}
        var rvpEmetteur = rvpSvcMap2[col]
        var rvpDoc = null
        if (lot.docs) { for(var jj=0;jj<lot.docs.length;jj++){if(lot.docs[jj].type_document==='rvp'&&lot.docs[jj].service_emetteur===rvpEmetteur){rvpDoc=lot.docs[jj];break}} }
        if (!rvpDoc) {
          // Le document RVP n'existe pas encore — proposer de le déclarer
          ;(function(re) {
            if (isAdmin||canPerform('emettre_rvp')) {
              actions.push({label:'Déclarer RVP '+re, fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                var ins = await supabase.from('liberation_documents').insert({lot_id:lot.id,type_document:'rvp',statut:'non_emis',is_applicable:true,is_required:true,service_emetteur:re,created_at:n,updated_at:n}).select().single()
                await supabase.from('liberation_dossiers').update({pieces_complementaires_ok:false,updated_at:n}).eq('lot_id',lot.id)
                await supabase.from('lot_events').insert({lot_id:lot.id,event_type:'rvp_declare',description:'RVP '+re+' déclaré depuis le tableau',triggered_by:uid,created_at:n})
                await createNotification(re,lot.id,ins.data?ins.data.id:null,'Lot '+lot.numero_lot+' — RVP '+re+' à émettre','rvp_declare')
              }})
            }
          })(rvpEmetteur)
        } else if (rvpDoc) {
          ;(function(rd, re) {
            if (rd.statut==='non_emis' && (isAdmin||canPerform('emettre_rvp'))) {
              actions.push({label:'Émettre RVP '+re, fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,updated_at:n}).eq('id',rd.id)
                await supabase.from('document_movements').insert({document_id:rd.id,action:'emission',from_service:re,to_service:'aq',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,rd.id,'Lot '+lot.numero_lot+' — RVP '+re+' émis','document_transmis')
              }})
            }
            if (rd.statut==='emis' && (isAdmin||canPerform('verifier_rvp'))) {
              actions.push({label:'Vérifier AQ → DT', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'approuve_aq',updated_at:n}).eq('id',rd.id)
                await supabase.from('document_movements').insert({document_id:rd.id,action:'approbation',from_service:'aq',to_service:'dt',performed_by:uid,performed_at:n})
                await createNotification('dt',lot.id,rd.id,'Lot '+lot.numero_lot+' — RVP '+re+' vérifié AQ → DT','document_transmis')
              }})
            }
            if (rd.statut==='approuve_aq' && (isAdmin||canPerform('approuver_rvp'))) {
              actions.push({label:'Approuver DT', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:n,updated_at:n}).eq('id',rd.id)
                await supabase.from('document_movements').insert({document_id:rd.id,action:'approbation',from_service:'dt',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,rd.id,'Lot '+lot.numero_lot+' — RVP '+re+' approuvé DT','document_approuve')
                await createNotification(re,lot.id,rd.id,'Lot '+lot.numero_lot+' — RVP '+re+' approuvé DT','document_approuve')
              }})
            }
          })(rvpDoc, rvpEmetteur)
        }
      }
      return actions
    }

    var openInlineMenu = function(event, lot, col) {
      var actions = buildInlineActions(lot, col)
      var rect = event.currentTarget.getBoundingClientRect()
      var top = rect.bottom + 2, left = rect.left
      // Ajust pour sortir du bord droit
      if (left + 200 > window.innerWidth) left = window.innerWidth - 210
      inlineMenu.value = { top: top, left: left, colLabel: COL_LABELS2[col]||col, actions: actions }
    }

    var executeInline = async function(fn) {
      inlineMenu.value = null
      await fn()
      await load()
    }
    // ──────────────────────────────────────────────────────────────────

    // ── Date picker planification ──────────────────────────────────────
    var datePicker = ref(null)
    var PLAN_LABELS = {
      plan_lcq_cible:'Lib. LCQ — Date cible', plan_lcq:'Lib. LCQ — Date révisée',
      plan_aq_cible:'Lib. AQ — Date cible',   plan_aq:'Lib. AQ — Date révisée',
      plan_dt1:'Lib. DT — Date cible',         plan_dt2:'Lib. DT — Date révisée'
    }
    var PLAN_DB_FIELD = {
      plan_lcq_cible:'date_lcq_cible', plan_lcq:'date_lcq_revisee',
      plan_aq_cible:'date_aq_cible',   plan_aq:'date_aq_revisee',
      plan_dt1:'date_dt_cible',        plan_dt2:'date_dt_revisee'
    }

    var openDatePicker = function(event, lot, col) {
      // Pour LCQ et AQ : saisir la cible d'abord, puis la révisée si cible déjà présente
      var effectiveCol = col
      if (col === 'plan_lcq') effectiveCol = lot.plan_lcq_cible_raw ? 'plan_lcq' : 'plan_lcq_cible'
      if (col === 'plan_aq')  effectiveCol = lot.plan_aq_cible_raw  ? 'plan_aq'  : 'plan_aq_cible'
      var rawVal = lot[effectiveCol+'_raw'] || lot[col+'_raw'] || ''
      if (typeof rawVal === 'string' && rawVal.length > 10) rawVal = rawVal.split('T')[0]
      var rect = event.currentTarget.getBoundingClientRect()
      var top = rect.bottom + 2, left = rect.left
      if (left + 200 > window.innerWidth) left = window.innerWidth - 210
      datePicker.value = { lotId: lot.id, col: effectiveCol, label: PLAN_LABELS[effectiveCol]||effectiveCol, top: top, left: left, value: rawVal }
      chargeCount.value = null
      if (rawVal) loadCharge()
    }

    var chargeCount = ref(null)
    var chargeLoading = ref(false)

    var CHARGE_FIELDS = {
      plan_lcq_cible: ['date_lcq_cible','date_lcq_revisee'],
      plan_lcq:       ['date_lcq_cible','date_lcq_revisee'],
      plan_aq_cible:  ['date_aq_cible','date_aq_revisee'],
      plan_aq:        ['date_aq_cible','date_aq_revisee'],
      plan_dt1:       ['date_dt_cible','date_dt_revisee'],
      plan_dt2:       ['date_dt_cible','date_dt_revisee']
    }

    var loadCharge = async function() {
      if (!datePicker.value || !datePicker.value.value) { chargeCount.value = null; return }
      var fields = CHARGE_FIELDS[datePicker.value.col]
      if (!fields) { chargeCount.value = null; return }
      chargeLoading.value = true
      var dateStr = datePicker.value.value // 'YYYY-MM-DD'
      var cibleF = fields[0], reviseeF = fields[1]
      // Récupérer les deux champs (cible + révisée) de tous les autres lots
      var res = await supabase.from('lot_planning')
        .select('lot_id,' + cibleF + ',' + reviseeF)
        .neq('lot_id', datePicker.value.lotId)
      var count = 0
      if (res.data) {
        for (var i = 0; i < res.data.length; i++) {
          var row = res.data[i]
          // Date effective = révisée si elle existe, sinon cible
          var eff = row[reviseeF] || row[cibleF]
          if (eff && eff.substring(0, 10) === dateStr) count++
        }
      }
      chargeCount.value = count
      chargeLoading.value = false
    }

    var savePlanning = async function() {
      if (!datePicker.value) return
      var u = await supabase.auth.getUser()
      var uid = u.data.user.id
      var dbField = PLAN_DB_FIELD[datePicker.value.col]
      if (!dbField) { datePicker.value = null; return }
      await supabase.from('lot_planning').upsert(
        { lot_id: datePicker.value.lotId, [dbField]: datePicker.value.value || null, updated_at: new Date().toISOString(), updated_by: uid },
        { onConflict: 'lot_id' }
      )
      datePicker.value = null
      chargeCount.value = null
      await load()
    }
    // ──────────────────────────────────────────────────────────────────

    var closeAll = function() { activeDropdown.value = null; inlineMenu.value = null; showColPanel.value = false; if(datePicker.value) datePicker.value = null }

    var filteredLots = computed(function(){
      var result = lots.value
      if(activeFilters.value.length>0){result=result.filter(function(l){return activeFilters.value.indexOf(l.statut_filter)>=0})}
      var cf=columnFilters.value,cfk=Object.keys(cf)
      if(cfk.length>0){result=result.filter(function(l){return cfk.every(function(k){return l[k]===cf[k]})})}
      if(sortCol.value){
        var col=sortCol.value,dir=sortDir.value
        result=result.slice().sort(function(a,b){
          var va=a[col]||'',vb=b[col]||''
          if(typeof va==='string')va=va.toLowerCase()
          if(typeof vb==='string')vb=vb.toLowerCase()
          if(va<vb)return dir==='asc'?-1:1;if(va>vb)return dir==='asc'?1:-1;return 0
        })
      }
      return result
    })

    var toggleFilter = function(value){var idx=activeFilters.value.indexOf(value);if(idx>=0)activeFilters.value.splice(idx,1);else activeFilters.value.push(value)}
    var sortBy = function(col){if(sortCol.value===col){sortDir.value=sortDir.value==='asc'?'desc':'asc'}else{sortCol.value=col;sortDir.value='asc'}}
    var sortIcon = function(col){if(sortCol.value!==col)return'↕';return sortDir.value==='asc'?'↑':'↓'}
    var goToLot = function(id){var query={};if(route.query.q)query.q=route.query.q;if(activeFilters.value.length)query.filters=activeFilters.value.join(',');router.push({path:'/lots/'+id,query:query})}

    var exportCols=[
      {key:'numero_lot',label:'N° Lot',width:12},{key:'prod_desc',label:'Produit',width:28},{key:'prod_code',label:'Code',width:12},
      {key:'statut_label',label:'Statut',width:14},{key:'of_label',label:'OF',width:10},{key:'oc_label',label:'OC',width:10},
      {key:'aql_fab_label',label:'AQL Fab',width:10},{key:'aql_cond_label',label:'AQL Cond',width:10},
      {key:'if_label',label:'IF',width:10},{key:'ic_label',label:'IC',width:10},
      {key:'dapc_label',label:'DA PC',width:10},{key:'damicro_label',label:'DA Micro',width:10},
      {key:'rvp_fab_label',label:'RVP Fab',width:10},{key:'rvp_cond_label',label:'RVP Cond',width:10},{key:'rvp_lcq_label',label:'RVP LCQ',width:10},
      {key:'plan_lcq',label:'Lib. LCQ',width:12},{key:'plan_aq',label:'Lib. AQ',width:12},{key:'plan_dt1',label:'Lib. DT1',width:12},{key:'plan_dt2',label:'Lib. DT2',width:12},
      {key:'date_fmt',label:'Entrée',width:12}
    ]
    var doExportExcel = function(){exportToExcel(filteredLots.value,exportCols,'lots_liberation')}
    var doExportPDF = function(){exportToPDF(filteredLots.value,exportCols,'lots_liberation')}

    // ── Actions en masse ───────────────────────────────────────────────
    var actionLabels = {
      of_planification:'OF — Mise en circuit',of_stock:'OF — Validation Stock',of_aq:'OF — Validation AQ',
      of_dt:'OF — Autorisation DT',of_aq_dap:'OF — Remise AQ DAP',of_production:'OF — Accusé réception',
      oc_planification:'OC — Mise en circuit',oc_stock:'OC — Validation Stock',oc_aq:'OC — Validation AQ',
      oc_dt:'OC — Autorisation DT',oc_aq_dap:'OC — Remise AQ DAP',oc_production:'OC — Accusé réception',
      doc_if:'IF — Émettre',doc_ic:'IC — Émettre',doc_da_pc:'DA Physico — Émettre',doc_da_micro:'DA Micro — Émettre',
      doc_if_verifier:'IF — Vérifier',doc_ic_verifier:'IC — Vérifier',doc_da_pc_verifier:'DA Physico — Vérifier',doc_da_micro_verifier:'DA Micro — Vérifier',
      doc_if_approuver:'IF — Approuver',doc_ic_approuver:'IC — Approuver',doc_da_pc_approuver:'DA Physico — Approuver',doc_da_micro_approuver:'DA Micro — Approuver',
      doc_if_retour_emetteur:'IF — Retourner',doc_ic_retour_emetteur:'IC — Retourner',doc_da_pc_retour_emetteur:'DA Physico — Retourner',doc_da_micro_retour_emetteur:'DA Micro — Retourner',
      doc_if_retour_aq:'IF — DT → AQ',doc_ic_retour_aq:'IC — DT → AQ',doc_da_pc_retour_aq:'DA Physico — DT → AQ',doc_da_micro_retour_aq:'DA Micro — DT → AQ',
      aql_fab_demander:'AQL Fab — Demander',aql_fab_relancer:'AQL Fab — Relancer',aql_fab_conforme:'AQL Fab — Conforme',aql_fab_non_conforme:'AQL Fab — Non conforme',
      aql_cond_demander:'AQL Cond — Demander',aql_cond_relancer:'AQL Cond — Relancer',aql_cond_conforme:'AQL Cond — Conforme',aql_cond_non_conforme:'AQL Cond — Non conforme',
      rvp_fab_emettre:'RVP Fab — Émettre',rvp_cond_emettre:'RVP Cond — Émettre',rvp_lcq_emettre:'RVP LCQ — Émettre',
      rvp_fab_verifier:'RVP Fab — Vérifier',rvp_cond_verifier:'RVP Cond — Vérifier',rvp_lcq_verifier:'RVP LCQ — Vérifier',
      rvp_fab_approuver:'RVP Fab — Approuver',rvp_cond_approuver:'RVP Cond — Approuver',rvp_lcq_approuver:'RVP LCQ — Approuver',
      rvp_fab_retour_emetteur:"RVP Fab — Retourner",rvp_cond_retour_emetteur:"RVP Cond — Retourner",rvp_lcq_retour_emetteur:"RVP LCQ — Retourner",
      rvp_fab_retour_aq:"RVP Fab — DT → AQ",rvp_cond_retour_aq:"RVP Cond — DT → AQ",rvp_lcq_retour_aq:"RVP LCQ — DT → AQ",
      dev_declarer:'Déviation — Déclarer',dev_cloture:'Déviation — Clôturer',
      plan_lcq_cible:'Lib. LCQ — Date cible',plan_lcq:'Lib. LCQ — Date révisée',
      plan_aq_cible:'Lib. AQ — Date cible',plan_aq:'Lib. AQ — Date révisée',
      plan_dt1:'Lib. DT — Date cible',plan_dt2:'Lib. DT — Date révisée',
    }
    var actionLabel = computed(function(){return actionLabels[actionType.value]||''})
    var canExecute = computed(function(){
      if(!selected.value.length||!actionType.value)return false
      if(actionType.value.startsWith('plan_')&&!bulkDate.value)return false
      return true
    })

    var isSelected = function(id){return selected.value.indexOf(id)>=0}
    var toggleLot = function(id){var idx=selected.value.indexOf(id);if(idx>=0)selected.value.splice(idx,1);else selected.value.push(id)}
    var allVisibleChecked = computed(function(){return filteredLots.value.length>0&&filteredLots.value.every(function(l){return isSelected(l.id)})})
    var someVisibleChecked = computed(function(){return filteredLots.value.some(function(l){return isSelected(l.id)})})
    var toggleAll = function(){
      if(allVisibleChecked.value){filteredLots.value.forEach(function(l){var i=selected.value.indexOf(l.id);if(i>=0)selected.value.splice(i,1)})}
      else{filteredLots.value.forEach(function(l){if(!isSelected(l.id))selected.value.push(l.id)})}
    }
    var getLotNum = function(id){var l=lots.value.find(function(x){return x.id===id});return l?l.numero_lot:id}

    var executeAction = async function() {
      if (!canAction(actionType.value)) {
        execResult.value = {ok:0,fail:selected.value.length,errors:['Action non autorisée pour votre service ('+userService.value+')']}
        showConfirm.value = false; return
      }
      executing.value = true; progress.value = 0
      var result = {ok:0,fail:0,errors:[]}
      var now = new Date().toISOString()
      var userRes = await supabase.auth.getUser()
      var userId = userRes.data.user.id
      var flow = ['planification','stock','aq','dt','aq_dap','production']

      for (var i=0; i<selected.value.length; i++) {
        var lotId = selected.value[i]
        var lot = lots.value.find(function(x){return x.id===lotId})
        if (!lot) {result.fail++;continue}
        try {
          var action = actionType.value

          if (action.startsWith('of_')||action.startsWith('oc_')) {
            var parts=action.split('_'),orderType=parts[0],etape=parts.slice(1).join('_')
            var orderId=orderType==='of'?lot.of_id:lot.oc_id
            if(!orderId){result.errors.push(lot.numero_lot+': pas d\'ordre '+orderType.toUpperCase());result.fail++;continue}
            var idx2=flow.indexOf(etape),nextEtape=idx2<flow.length-1?flow[idx2+1]:null
            var tbl=orderType==='of'?'orders_of':'orders_oc'
            await supabase.from('order_validations').insert({order_type:orderType,order_id:orderId,etape:etape,action:'valide',validated_by:userId,validated_at:now})
            await supabase.from(tbl).update({statut:nextEtape?'en_circuit':'termine',etape_circuit:nextEtape||etape,updated_at:now}).eq('id',orderId)
            var nextLabel=nextEtape?(etapeLabels[nextEtape]||nextEtape):'Terminé'
            await supabase.from('lots').update({statut_operationnel:orderType.toUpperCase()+' — '+nextLabel,updated_at:now}).eq('id',lotId)
            await supabase.from('lot_events').insert({lot_id:lotId,event_type:'validation_'+orderType,description:'Circuit '+orderType.toUpperCase()+' — '+etape+' validé (masse)',triggered_by:userId,created_at:now})
            var notifSvc=nextEtape==='stock'?'stock':nextEtape==='aq'?'aq':nextEtape==='dt'?'dt':nextEtape==='aq_dap'?'aq_dap':nextEtape==='production'?(orderType==='of'?'fabrication':'conditionnement'):'planification'
            await createNotification(notifSvc,lotId,null,'Lot '+lot.numero_lot+' — Circuit '+orderType.toUpperCase()+' : '+(etapeLabels[etape]||etape)+' validé','circuit_avance')
            result.ok++

          } else if (action.startsWith('doc_')) {
            var docAction=action.replace('doc_','')
            var isApprouver=docAction.endsWith('_approuver'),isVerifier=docAction.endsWith('_verifier')
            var isRetourEmetteur=docAction.endsWith('_retour_emetteur'),isRetourAQ=docAction.endsWith('_retour_aq')
            var docType=docAction
            if(isApprouver)docType=docAction.replace('_approuver','')
            if(isVerifier)docType=docAction.replace('_verifier','')
            if(isRetourEmetteur)docType=docAction.replace('_retour_emetteur','')
            if(isRetourAQ)docType=docAction.replace('_retour_aq','')
            var doc2=null;if(lot.docs){for(var j=0;j<lot.docs.length;j++){if(lot.docs[j].type_document===docType){doc2=lot.docs[j];break}}}
            if(!doc2){result.errors.push(lot.numero_lot+': document '+docType+' non trouvé');result.fail++;continue}
            if(isApprouver){
              await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:now,updated_at:now}).eq('id',doc2.id)
              var fldMap={'if':'if_approved',ic:'ic_approved',da_pc:'da_pc_approved',da_micro:'da_micro_approved'}
              var fld=fldMap[docType];if(fld)await supabase.from('liberation_dossiers').update({[fld]:true,updated_at:now}).eq('lot_id',lotId)
              await supabase.from('document_movements').insert({document_id:doc2.id,action:'approbation',from_service:'dt',performed_by:userId,performed_at:now})
            } else if(isVerifier){
              await supabase.from('liberation_documents').update({statut:'approuve_aq',updated_at:now}).eq('id',doc2.id)
              await supabase.from('document_movements').insert({document_id:doc2.id,action:'approbation',from_service:'aq',to_service:'dt',performed_by:userId,performed_at:now})
            } else if(isRetourEmetteur){
              var svcMap2={'if':'fabrication',ic:'conditionnement',da_pc:'lcq',da_micro:'lcq'}
              await supabase.from('liberation_documents').update({statut:'retour_emetteur',updated_at:now}).eq('id',doc2.id)
              await supabase.from('document_movements').insert({document_id:doc2.id,action:'retour',from_service:'aq',to_service:svcMap2[docType]||'',motif_retour:'Retour en masse',performed_by:userId,performed_at:now})
            } else if(isRetourAQ){
              await supabase.from('liberation_documents').update({statut:'verification_aq',updated_at:now}).eq('id',doc2.id)
              await supabase.from('document_movements').insert({document_id:doc2.id,action:'retour',from_service:'dt',to_service:'aq',motif_retour:'Retour DT en masse',performed_by:userId,performed_at:now})
            } else {
              if(docType==='da_micro'){
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,is_applicable:true,is_required:true,updated_at:now}).eq('id',doc2.id)
                await supabase.from('liberation_dossiers').update({da_micro_applicable:true,updated_at:now}).eq('lot_id',lotId)
              } else {
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,updated_at:now}).eq('id',doc2.id)
              }
              var svcMap3={'if':'fabrication',ic:'conditionnement',da_pc:'lcq',da_micro:'lcq'}
              await supabase.from('document_movements').insert({document_id:doc2.id,action:'emission',from_service:svcMap3[docType]||'',to_service:'aq',performed_by:userId,performed_at:now})
            }
            await supabase.from('lot_events').insert({lot_id:lotId,event_type:'document_masse',description:docType.toUpperCase()+' — '+docAction+' (masse)',triggered_by:userId,created_at:now})
            var typeLabel=docType.toUpperCase().replace('_',' ')
            if(!isApprouver&&!isVerifier&&!isRetourEmetteur&&!isRetourAQ){await createNotification('aq',lotId,doc2.id,'Lot '+lot.numero_lot+' — '+typeLabel+' émis','document_transmis')}
            else if(isVerifier){await createNotification('dt',lotId,doc2.id,'Lot '+lot.numero_lot+' — '+typeLabel+' vérifié AQ → DT','document_transmis')}
            else if(isRetourEmetteur){var s4={'if':'fabrication',ic:'conditionnement',da_pc:'lcq',da_micro:'lcq'};if(s4[docType])await createNotification(s4[docType],lotId,doc2.id,'Lot '+lot.numero_lot+' — '+typeLabel+' retourné','document_retourne')}
            else if(isRetourAQ){await createNotification('aq',lotId,doc2.id,'Lot '+lot.numero_lot+' — '+typeLabel+' retourné par DT','document_retourne')}
            else if(isApprouver){await createNotification('aq',lotId,doc2.id,'Lot '+lot.numero_lot+' — '+typeLabel+' approuvé DT','document_approuve')}
            result.ok++

          } else if (action.startsWith('aql_')) {
            var aqlParts=action.split('_'),aqlSvc=aqlParts[1],aqlOp=aqlParts.slice(2).join('_')
            var aqlTypeVal=aqlSvc==='fab'?'fabrication':'conditionnement'
            var aqlSvcLabel=aqlSvc==='fab'?'Fabrication':'Conditionnement'
            if(aqlOp==='demander'||aqlOp==='relancer'){
              await supabase.from('aql_inspections').insert({lot_id:lotId,type:aqlTypeVal,resultat:'en_attente',requested_at:now})
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'aql_demande',description:'AQL '+aqlSvcLabel+' — '+(aqlOp==='relancer'?'relancé':'demandé')+' (masse)',triggered_by:userId,created_at:now})
              await createNotification('aq',lotId,null,'Lot '+lot.numero_lot+' — AQL '+aqlSvcLabel+(aqlOp==='relancer'?' relancé':' demandé'),'aql_demande')
              result.ok++
            } else if(aqlOp==='conforme'||aqlOp==='non_conforme'){
              var aqlRes=await supabase.from('aql_inspections').select('id').eq('lot_id',lotId).eq('type',aqlTypeVal).or('resultat.is.null,resultat.eq.en_attente').order('requested_at',{ascending:false}).limit(1)
              var latestAql=aqlRes.data&&aqlRes.data[0]
              if(!latestAql){result.errors.push(lot.numero_lot+': pas d\'AQL '+aqlSvcLabel+' en attente');result.fail++;continue}
              await supabase.from('aql_inspections').update({resultat:aqlOp,inspected_at:now,inspected_by:userId}).eq('id',latestAql.id)
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'aql_resultat',description:'AQL '+aqlSvcLabel+' — '+aqlOp.replace('_',' ')+' (masse)',triggered_by:userId,created_at:now})
              await createNotification('planification',lotId,null,'Lot '+lot.numero_lot+' — AQL '+aqlSvcLabel+' : '+aqlOp.replace('_',' '),'aql_resultat')
              result.ok++
            } else {result.errors.push(lot.numero_lot+': action AQL inconnue');result.fail++}

          } else if (action.startsWith('rvp_')) {
            var rvpParts=action.split('_'),rvpSvc=rvpParts[1],rvpOp=rvpParts.slice(2).join('_')
            var rvpSvcMap={fab:'fabrication',cond:'conditionnement',lcq:'lcq'}
            var rvpEmetteur2=rvpSvcMap[rvpSvc]||rvpSvc
            var rvpDoc2=null
            if(lot.docs){for(var jj2=0;jj2<lot.docs.length;jj2++){if(lot.docs[jj2].type_document==='rvp'&&lot.docs[jj2].service_emetteur===rvpEmetteur2){rvpDoc2=lot.docs[jj2];break}}}
            if(!rvpDoc2){result.errors.push(lot.numero_lot+': RVP '+rvpEmetteur2+' non trouvé');result.fail++;continue}
            if(rvpOp==='emettre'){
              await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,updated_at:now}).eq('id',rvpDoc2.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc2.id,action:'emission',from_service:rvpEmetteur2,to_service:'aq',performed_by:userId,performed_at:now})
              await createNotification('aq',lotId,rvpDoc2.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur2+' émis','document_transmis')
            } else if(rvpOp==='verifier'){
              await supabase.from('liberation_documents').update({statut:'approuve_aq',updated_at:now}).eq('id',rvpDoc2.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc2.id,action:'approbation',from_service:'aq',to_service:'dt',performed_by:userId,performed_at:now})
              await createNotification('dt',lotId,rvpDoc2.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur2+' vérifié','document_transmis')
            } else if(rvpOp==='approuver'){
              await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:now,updated_at:now}).eq('id',rvpDoc2.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc2.id,action:'approbation',from_service:'dt',performed_by:userId,performed_at:now})
              await createNotification('aq',lotId,rvpDoc2.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur2+' approuvé DT','document_approuve')
              await createNotification(rvpEmetteur2,lotId,rvpDoc2.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur2+' approuvé DT','document_approuve')
            } else if(rvpOp==='retour_emetteur'){
              await supabase.from('liberation_documents').update({statut:'retour_emetteur',updated_at:now}).eq('id',rvpDoc2.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc2.id,action:'retour',from_service:'aq',to_service:rvpEmetteur2,motif_retour:'Retour en masse',performed_by:userId,performed_at:now})
              await createNotification(rvpEmetteur2,lotId,rvpDoc2.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur2+' retourné','document_retourne')
            } else if(rvpOp==='retour_aq'){
              await supabase.from('liberation_documents').update({statut:'verification_aq',updated_at:now}).eq('id',rvpDoc2.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc2.id,action:'retour',from_service:'dt',to_service:'aq',motif_retour:'Retour DT en masse',performed_by:userId,performed_at:now})
              await createNotification('aq',lotId,rvpDoc2.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur2+' retourné par DT','document_retourne')
            } else {result.errors.push(lot.numero_lot+': action RVP inconnue');result.fail++;continue}
            await supabase.from('lot_events').insert({lot_id:lotId,event_type:'rvp_masse',description:'RVP '+rvpEmetteur2+' — '+rvpOp.replace(/_/g,' ')+' (masse)',triggered_by:userId,created_at:now})
            result.ok++

          } else if (action.startsWith('dev_')) {
            var devOp=action.replace('dev_','')
            if(devOp==='declarer'){
              var devCountRes=await supabase.from('deviations').select('*',{count:'exact',head:true})
              var devNumero='DEV-'+new Date().getFullYear()+'-'+String(((devCountRes.count||0)+1)).padStart(3,'0')
              await supabase.from('deviations').insert({lot_id:lotId,numero_deviation:devNumero,type:'deviation',statut:'ouverte',description:'Déclaration en masse',declared_by:userId,declared_at:now})
              await supabase.from('liberation_dossiers').update({deviations_closed:false,updated_at:now}).eq('lot_id',lotId)
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'deviation_declaree',description:'Déviation '+devNumero+' déclarée (masse)',triggered_by:userId,created_at:now})
              await createNotification('aq',lotId,null,'Lot '+lot.numero_lot+' — Déviation '+devNumero+' déclarée','deviation_declaree')
              result.ok++
            } else if(devOp==='cloture'){
              var openDevs=await supabase.from('deviations').select('id').eq('lot_id',lotId).in('statut',['ouverte','en_cours'])
              if(!openDevs.data||!openDevs.data.length){result.errors.push(lot.numero_lot+': aucune déviation ouverte');result.fail++;continue}
              for(var kk=0;kk<openDevs.data.length;kk++){await supabase.from('deviations').update({statut:'cloturee',closed_at:now,closed_by:userId,updated_at:now}).eq('id',openDevs.data[kk].id)}
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'deviation_cloturee',description:openDevs.data.length+' déviation(s) clôturée(s) (masse)',triggered_by:userId,created_at:now})
              result.ok++
            } else {result.errors.push(lot.numero_lot+': action déviation inconnue');result.fail++}

          } else if (action.startsWith('plan_')) {
            var dbField2 = PLAN_DB_FIELD[action]
            if (!dbField2||!bulkDate.value){result.errors.push(lot.numero_lot+': date manquante');result.fail++;continue}
            await supabase.from('lot_planning').upsert({lot_id:lotId,[dbField2]:bulkDate.value,updated_at:now,updated_by:userId},{onConflict:'lot_id'})
            result.ok++
          }

        } catch(e) {result.errors.push(lot.numero_lot+': '+e.message);result.fail++}
        progress.value = i+1
      }
      execResult.value = result; executing.value = false; showConfirm.value = false
      selected.value = []; actionType.value = ''; bulkDate.value = ''
      await load()
    }
    // ─────────────────────────────────────────────────────────────────

    onMounted(async function(){
      var u = await supabase.auth.getUser()
      if (u.data.user) {
        var p = await supabase.from('profiles').select('service').eq('id', u.data.user.id).single()
        if (p.data) { await loadPermissions(p.data.service); userService.value = p.data.service }
      }
      if(route.query.filters)activeFilters.value=route.query.filters.split(',')
      load()
      document.addEventListener('click', closeAll)
    })
    onUnmounted(function(){document.removeEventListener('click', closeAll)})
    watch(function(){return route.query},load,{deep:true})

    return{lots,total,activeFilters,showDates,filteredLots,filterOptions,
      toggleFilter,sortBy,sortIcon,goToLot,doExportExcel,doExportPDF,
      selected,actionType,showConfirm,executing,progress,execResult,bulkDate,
      actionLabel,canExecute,allVisibleChecked,someVisibleChecked,
      isSelected,toggleLot,toggleAll,getLotNum,executeAction,
      actionGroups,userService,
      columnFilters,activeDropdown,ddPos,openDropdown,getColumnValues,setColumnFilter,clearColumnFilters,removeColumnFilter,hasColumnFilters,
      visibleCols,showColPanel,colDefs,isColVisible,toggleCol,resetCols,
      inlineMenu,openInlineMenu,executeInline,closeAll,
      datePicker,dpInput,openDatePicker,savePlanning,getPlanClass,
      chargeCount,chargeLoading,loadCharge}
  }
}
</script>
<style scoped>
.ph{display:flex;align-items:baseline;justify-content:space-between;padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:2px;flex-wrap:wrap;gap:8px}
.pt{font-size:11px;font-weight:500;letter-spacing:1.5px}.pc{font-size:11px;color:#999;font-family:'SF Mono',monospace}
.ph-right{display:flex;align-items:center;gap:6px;flex-wrap:wrap}
.btn-exp{font-size:11px;padding:4px 10px;border:1px solid #ddd;border-radius:3px;background:#fff;cursor:pointer;color:#666;font-family:inherit}.btn-exp:hover{background:#f5f5f5}
.btn-toggle{font-size:11px;padding:4px 10px;border:1px solid #185FA5;border-radius:3px;background:#E6F1FB;cursor:pointer;color:#0C447C;font-family:inherit}.btn-toggle:hover{background:#d0e3f5}
.btn-cols{font-size:11px;padding:4px 10px;border:1px solid #ddd;border-radius:3px;background:#fff;cursor:pointer;color:#666;font-family:inherit;white-space:nowrap}.btn-cols:hover{background:#f5f5f5}.btn-cols-on{border-color:#185FA5;background:#E6F1FB;color:#0C447C}
.col-panel-wrap{position:relative}
.col-panel{position:absolute;top:calc(100% + 4px);right:0;background:#fff;border:1px solid #ddd;border-radius:4px;box-shadow:0 6px 20px rgba(0,0,0,.12);z-index:300;padding:10px;min-width:180px}
.col-panel-title{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.8px;color:#999;margin-bottom:8px;padding-bottom:6px;border-bottom:1px solid #f0f0f0}
.col-item{display:flex;align-items:center;gap:6px;font-size:12px;color:#333;padding:3px 0;cursor:pointer;white-space:nowrap}
.col-item input{cursor:pointer;accent-color:#185FA5}
.col-reset{margin-top:8px;width:100%;padding:5px;font-size:11px;border:1px solid #ddd;border-radius:3px;background:#fafafa;cursor:pointer;color:#666}.col-reset:hover{background:#f0f0f0}
.filters{display:flex;gap:4px;padding:8px 0;flex-wrap:wrap}
.fbtn{display:flex;align-items:center;gap:4px;padding:5px 10px;min-height:32px;font-size:11px;border:1px solid #e8e8e8;border-radius:3px;background:#fff;cursor:pointer;color:#666;font-family:inherit;transition:.15s}
.fbtn:hover{border-color:#ccc}.fbtn.active{border-color:#185FA5;background:#E6F1FB;color:#0C447C}
.fdot{width:6px;height:6px;border-radius:50%;flex-shrink:0}
.table-wrap{overflow-x:auto;overflow-y:auto;-webkit-overflow-scrolling:touch;max-height:calc(100vh - 150px)}
.tb{width:100%;border-collapse:collapse;font-size:11px;white-space:nowrap}.tb th{font-size:9px;text-transform:uppercase;color:#999;font-weight:500;padding:5px 4px;text-align:left;border-bottom:1px solid #e8e8e8;position:sticky;top:0;background:#fff;z-index:1}
.sortable{cursor:pointer;user-select:none}.sortable:hover{color:#185FA5}.sort-arrow{font-size:10px;color:#ccc}
.tb td{padding:6px 4px;border-bottom:1px solid #f5f5f5}.tb tr{cursor:pointer}.tb tr:hover td{background:#fafafa}
.bold{font-weight:500}.mono{font-family:'SF Mono',monospace;font-size:10px}.dim{color:#999;font-size:10px}
.td-prod{max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:11px}
.code{font-size:9px;color:#999;font-family:'SF Mono',monospace;margin-left:3px}
.sp{font-size:9px;padding:2px 5px;border-radius:2px;font-weight:500;white-space:nowrap}
.s-quarantaine{background:#FAEEDA;color:#854F0B}.s-accepte{background:#EAF3DE;color:#3B6D11}.s-sous_investigation{background:#FCEBEB;color:#A32D2D}.s-vide{background:#f5f5f5;color:#999}.s-enprod{background:#E6F1FB;color:#0C447C}.s-enprep{background:#F0EBFE;color:#5B3CC4}.s-refuse{background:#e8e8e8;color:#333}
.doc-pip{font-size:9px;padding:2px 4px;border-radius:2px;font-weight:500}
.dc-ok{background:#EAF3DE;color:#3B6D11}.dc-ret{background:#FCEBEB;color:#A32D2D}.dc-wait{background:#f5f5f5;color:#999}.dc-prog{background:#E6F1FB;color:#0C447C}.dc-na{background:transparent;color:#ccc}.dc-date{background:#fafafa;color:#666;font-family:'SF Mono',monospace}
.pip-done-t{background:#EAF3DE;color:#3B6D11}.pip-prog-t{background:#FAEEDA;color:#854F0B}
.dev-badge{font-size:9px;padding:2px 5px;border-radius:2px;font-weight:500}.dev-open{background:#FCEBEB;color:#A32D2D}.dev-closed{background:#EAF3DE;color:#3B6D11}
/* Cellule cliquable pour actions inline */
.td-action{cursor:pointer;position:relative}.td-action:hover span{filter:brightness(.9)}
/* Planning dates */
.td-plan{text-align:center;min-width:70px}
.plan-date{font-size:9px;font-family:'SF Mono',monospace;padding:2px 5px;border-radius:2px;background:#f0f4ff;color:#185FA5;font-weight:500;cursor:pointer}
.plan-revised{background:#fff3cd;color:#856404}
.plan-empty{font-size:14px;color:#ddd;cursor:pointer;line-height:1}.td-plan:hover .plan-empty{color:#185FA5}
.plan-warn{background:#fff3cd !important;color:#856404 !important}
.plan-urgent{background:#FAEEDA !important;color:#854F0B !important}
.plan-crit{background:#FCEBEB !important;color:#A32D2D !important}
.empty{text-align:center;padding:40px;color:#999}
/* column filter chips */
.cf-bar{display:flex;align-items:center;gap:6px;padding:5px 0;flex-wrap:wrap;font-size:11px;border-bottom:1px solid #e8e8e8}
.cf-label{color:#999;font-weight:500;white-space:nowrap}
.cf-chip{display:flex;align-items:center;gap:4px;background:#E6F1FB;color:#0C447C;padding:2px 8px;border-radius:10px;font-size:11px}
.cf-chip strong{font-weight:600}
.cf-rm{background:none;border:none;cursor:pointer;color:#185FA5;font-size:11px;padding:0 0 0 2px;line-height:1}
.cf-clear{font-size:11px;padding:2px 10px;border:1px solid #E24B4A;border-radius:10px;background:#fff;color:#E24B4A;cursor:pointer;white-space:nowrap}.cf-clear:hover{background:#FCEBEB}
/* column header inner wrapper — NE JAMAIS mettre display:flex sur <th> directement */
.th-i{display:flex;align-items:center;gap:2px;white-space:nowrap}
.th-txt{display:flex;align-items:center;gap:2px;flex:1}
.th-txt.sortable{cursor:pointer}.th-txt.sortable:hover{color:#185FA5}
.th-f{background:none;border:none;cursor:pointer;color:#ccc;font-size:11px;padding:0 2px;line-height:1;border-radius:2px;flex-shrink:0;transition:.1s}.th-f:hover{color:#185FA5;background:#f0f0f0}
.th-f-on{color:#185FA5 !important;background:#E6F1FB}
/* column dropdown */
.col-dd{position:fixed;background:#fff;border:1px solid #ddd;border-radius:4px;box-shadow:0 6px 20px rgba(0,0,0,.12);z-index:300;min-width:160px;max-width:260px;max-height:280px;overflow-y:auto;font-size:12px}
.col-dd-item{padding:7px 12px;cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;transition:.1s}
.col-dd-item:hover{background:#f5f5f5}.col-dd-all{color:#999;font-style:italic;border-bottom:1px solid #f0f0f0}.col-dd-on{background:#E6F1FB;color:#0C447C;font-weight:500}
/* Inline action menu */
.inline-menu{position:fixed;background:#fff;border:1px solid #ddd;border-radius:4px;box-shadow:0 6px 20px rgba(0,0,0,.15);z-index:400;min-width:180px;max-width:260px;overflow:hidden}
.inline-menu-title{font-size:9px;font-weight:600;text-transform:uppercase;letter-spacing:.8px;color:#999;padding:7px 12px 5px;border-bottom:1px solid #f0f0f0}
.inline-act{display:block;width:100%;padding:8px 12px;text-align:left;border:none;background:#fff;cursor:pointer;font-size:12px;font-family:inherit;border-bottom:1px solid #f8f8f8;transition:.1s}.inline-act:hover{background:#E6F1FB;color:#0C447C}
.inline-empty{padding:10px 12px;font-size:11px;color:#999;text-align:center}
/* Date picker popup */
.date-picker-pop{position:fixed;background:#fff;border:1px solid #ddd;border-radius:4px;box-shadow:0 6px 20px rgba(0,0,0,.15);z-index:400;padding:12px;min-width:200px}
.dp-title{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.8px;color:#999;margin-bottom:8px}
.dp-input{width:100%;padding:6px 8px;border:1px solid #ddd;border-radius:3px;font-size:13px;font-family:inherit;outline:none;box-sizing:border-box}.dp-input:focus{border-color:#185FA5}
.dp-charge{margin:7px 0 2px;padding:5px 8px;border-radius:3px;font-size:11px;line-height:1.4;background:#fafafa;border:1px solid #f0f0f0}
.charge-loading{color:#999}
.charge-ok{color:#1D9E75;font-weight:500}
.charge-low{color:#185FA5;font-weight:500}
.charge-med{color:#FFA94D;font-weight:600}
.charge-high{color:#E24B4A;font-weight:700}
.dp-actions{display:flex;gap:6px;margin-top:8px}
.dp-ok{flex:1;padding:6px;background:#185FA5;color:#fff;border:none;border-radius:3px;cursor:pointer;font-size:12px;font-weight:500}.dp-ok:hover{background:#0C447C}
.dp-cancel{padding:6px 10px;background:#f5f5f5;color:#666;border:none;border-radius:3px;cursor:pointer;font-size:12px}
/* bulk bar */
.bulk-bar{display:flex;align-items:center;gap:8px;padding:6px 0;flex-wrap:wrap;border-bottom:1px solid #e8e8e8}
.bulk-sel{padding:5px 8px;font-size:12px;border:1px solid #ddd;border-radius:3px;outline:none;font-family:inherit;min-width:220px}.bulk-sel:focus{border-color:#185FA5}
.bulk-btn{padding:5px 14px;font-size:12px;font-weight:500;background:#185FA5;color:#fff;border:none;border-radius:3px;cursor:pointer;white-space:nowrap}.bulk-btn:hover{background:#0C447C}.bulk-btn:disabled{opacity:.35;cursor:not-allowed}
.bulk-info{font-size:11px;color:#185FA5;font-family:'SF Mono',monospace}
.bulk-clear{font-size:11px;padding:3px 10px;border:1px solid #E24B4A;border-radius:3px;background:#fff;color:#E24B4A;cursor:pointer}.bulk-clear:hover{background:#FCEBEB}
.bulk-date-wrap{display:flex;align-items:center;gap:6px}
.bulk-date-lbl{font-size:12px;color:#666;white-space:nowrap}
.bulk-date-in{padding:5px 8px;border:1px solid #ddd;border-radius:3px;font-size:12px;font-family:inherit;outline:none}.bulk-date-in:focus{border-color:#185FA5}
/* checkboxes */
.th-chk,.td-chk{width:32px;text-align:center;padding:0 4px !important}.td-chk{cursor:pointer}.row-sel td{background:#E6F1FB !important}
/* modal masse */
.m-overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:200;padding:16px}
.m-box{background:#fff;padding:24px;width:min(100%,480px);border-radius:4px;max-height:85vh;overflow-y:auto}
.m-title{font-size:16px;font-weight:500;margin-bottom:16px}
.m-line{display:flex;justify-content:space-between;align-items:center;padding:6px 0;font-size:13px;border-bottom:1px solid #f5f5f5}.m-lbl{color:#999}
.m-chips{display:flex;flex-wrap:wrap;gap:4px;margin-top:10px}
.m-chip{font-size:11px;font-family:'SF Mono',monospace;padding:2px 8px;background:#f5f5f5;border-radius:2px;color:#666}.m-more{background:#E6F1FB;color:#185FA5}
.m-actions{display:flex;gap:8px;margin-top:16px}
.m-btn-ok{flex:1;padding:11px;background:#185FA5;color:#fff;border:none;font-size:13px;font-weight:500;cursor:pointer;border-radius:2px;min-height:44px}.m-btn-ok:hover{background:#0C447C}.m-btn-ok:disabled{opacity:.5}
.m-btn-cancel{flex:1;padding:11px;background:#f5f5f5;color:#666;border:none;font-size:13px;cursor:pointer;border-radius:2px;min-height:44px}
.m-result{border:1px solid #e8e8e8;padding:16px;margin-top:12px}
.m-rh{font-size:13px;font-weight:500;margin-bottom:10px}
.m-rg{display:grid;grid-template-columns:1fr 1fr;border:1px solid #e8e8e8}
.m-rc{padding:10px;text-align:center;border-right:1px solid #e8e8e8}.m-rc:last-child{border-right:none}
.m-rv{font-size:18px;font-weight:500;font-family:'SF Mono',monospace}.m-rl{font-size:10px;color:#999;text-transform:uppercase;margin-top:2px}
.m-errs{margin-top:10px}.m-err{font-size:11px;color:#E24B4A;padding:3px 0;border-bottom:1px solid #f5f5f5}
@media(max-width:768px){
  .ph{flex-direction:column;gap:6px}
  .ph-right{width:100%;justify-content:flex-start;gap:4px}
  .btn-exp,.btn-toggle,.btn-cols{padding:6px 10px;min-height:36px}
  .filters{overflow-x:auto;-webkit-overflow-scrolling:touch;flex-wrap:nowrap;padding-bottom:6px;padding-top:6px;gap:6px;scrollbar-width:none}.filters::-webkit-scrollbar{display:none}
  .fbtn{min-height:36px;padding:6px 12px;white-space:nowrap}
  .td-prod{max-width:110px}
  .tb td{padding:8px 4px}
  .table-wrap{max-height:calc(100vh - 220px)}
  .bulk-sel{min-width:0;width:100%}
  .bulk-bar{flex-direction:column;align-items:stretch}
  .bulk-btn{width:100%;padding:10px;min-height:44px}
  .col-panel{right:auto;left:0}
}
</style>
