<template>
  <div @click="closeAll">
    <div class="ph">
      <span class="pt">LOTS</span>
      <div class="ph-right">
        <span class="pc" v-if="lots.length">{{filteredLots.length}} lot{{filteredLots.length!==1?'s':''}}<span class="pc-sub" v-if="filteredLots.length<lots.length"> / {{lots.length}}</span></span>
        <div class="statut-panel-wrap" @click.stop>
          <button class="btn-cols" :class="{'btn-cols-on': hiddenStatuts.length > 0}" @click="showStatutPanel=!showStatutPanel">⊙ Statuts{{hiddenStatuts.length > 0 ? ' ('+hiddenStatuts.length+')' : ''}}</button>
          <div class="statut-panel" v-if="showStatutPanel">
            <div class="col-panel-title">Visibilité statuts</div>
            <label class="statut-item" v-for="f in filterOptions" :key="f.value" @click.stop>
              <input type="checkbox" :checked="!hiddenStatuts.includes(f.value)" @change="toggleStatutVisibility(f.value)" @click.stop />
              <span class="statut-dot" :style="{background:f.color}"></span>
              <span class="statut-lbl">{{f.label}}</span>
            </label>
          </div>
        </div>
        <button class="btn-toggle" @click.stop="showDates=!showDates">{{showDates?'Voir statuts':'Voir dates'}}</button>
        <div class="col-panel-wrap" @click.stop>
          <button class="btn-cols" :class="{'btn-cols-on':showColPanel}" @click="showColPanel=!showColPanel">⚙ Colonnes</button>
          <div class="col-panel" v-if="showColPanel">
            <div class="col-panel-title">Colonnes (ordre & visibilité)</div>
            <div v-for="(col,idx) in colDefs" :key="col.key" class="col-item"
              draggable="true"
              :class="{'col-item-dragging':colDragIdx===idx,'col-item-over':colDragOverIdx===idx}"
              @dragstart.stop="onColDragStart(idx,$event)"
              @dragover.prevent.stop="onColDragOver(idx)"
              @drop.prevent.stop="onColDrop(idx)"
              @dragend.stop="onColDragEnd">
              <span class="col-drag-handle" title="Glisser pour réordonner">⠿</span>
              <input type="checkbox" :checked="isColVisible(col.key)" @change="toggleCol(col.key)" @click.stop />
              <span class="col-item-label">{{col.label}}</span>
            </div>
            <button class="col-reset" @click="resetCols">Réinitialiser</button>
          </div>
        </div>
        <button class="btn-exp" @click="doExportExcel">📥 Excel</button>
        <button class="btn-exp" @click="doExportPDF">📄 PDF</button>
      </div>
    </div>

    <!-- Barre d'actions en masse -->
    <div class="bulk-bar">
      <div class="action-palette-wrap" @click.stop>
        <button class="action-trigger" :class="{'action-trigger-on': actionType}" @click="showActionPanel=!showActionPanel">
          <span class="action-trigger-label">{{actionType ? actionLabel : '— Choisir une action —'}}</span>
          <span class="action-trigger-arr">{{showActionPanel ? '▲' : '▼'}}</span>
        </button>
        <button v-if="actionType" class="action-clear" @click.stop="actionType=''" title="Effacer">✕</button>
        <div class="action-palette" v-if="showActionPanel">
          <div class="ap-search-wrap">
            <span class="ap-search-ico">🔍</span>
            <input class="ap-search" v-model="actionSearch" placeholder="Rechercher une action…" @click.stop />
            <button v-if="actionSearch" class="ap-search-clr" @click.stop="actionSearch=''">✕</button>
          </div>
          <div class="ap-body">
            <!-- Mode recherche : liste plate avec séparateurs de groupe -->
            <template v-if="actionSearch.trim()">
              <template v-for="grp in filteredActionGroups" :key="grp.label">
                <div class="ap-grp-hd">{{grp.label}}</div>
                <button v-for="opt in grp.filteredActions" :key="opt.value"
                  class="ap-item" :class="{'ap-item-active': actionType===opt.value}"
                  @click.stop="selectAction(opt.value)">
                  <span class="ap-item-arr">›</span>{{opt.label}}
                </button>
              </template>
              <div v-if="!filteredActionGroups.length" class="ap-empty">Aucun résultat</div>
            </template>
            <!-- Mode accordéon : groupes repliables -->
            <template v-else>
              <div v-for="grp in actionGroups" :key="grp.label" class="ap-acc-grp">
                <button class="ap-acc-hd" @click.stop="toggleActionGroup(grp.label)">
                  <span class="ap-acc-chevron">{{expandedActionGroups.includes(grp.label) ? '▾' : '▸'}}</span>
                  <span class="ap-acc-label">{{grp.label}}</span>
                  <span class="ap-acc-cnt">{{grp.actions.length}}</span>
                </button>
                <div v-if="expandedActionGroups.includes(grp.label)" class="ap-acc-items">
                  <button v-for="opt in grp.actions" :key="opt.value"
                    class="ap-item" :class="{'ap-item-active': actionType===opt.value}"
                    @click.stop="selectAction(opt.value)">
                    <span class="ap-item-arr">›</span>{{opt.label}}
                  </button>
                </div>
              </div>
            </template>
          </div>
        </div>
      </div>
      <!-- Date input pour les actions de planification -->
      <div v-if="actionType.startsWith('plan_')" class="bulk-date-wrap">
        <label class="bulk-date-lbl">Date :</label>
        <input type="date" v-model="bulkDate" class="bulk-date-in" />
      </div>
      <div v-if="actionType==='dev_declarer'" class="bulk-dev-wrap">
        <input type="text" v-model="bulkDevNumeroDn" placeholder="N° DN (optionnel)" class="bulk-dev-in" />
        <input type="text" v-model="bulkDevObs" placeholder="Observation (optionnel)" class="bulk-dev-in" />
        <button class="bulk-dev-tog" :class="bulkDevBloquante?'bulk-dev-bl-on':'bulk-dev-bl-off'" @click.stop="bulkDevBloquante=!bulkDevBloquante">
          {{bulkDevBloquante?'BLOQUANTE':'Non bloquante'}}
        </button>
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

    <div v-if="lotsLoading" class="lots-loading">⟳ Chargement des lots…</div>
    <div v-else-if="!filteredLots.length" class="empty">Aucun lot trouvé</div>
    <div v-else-if="!lotsLoading" class="table-wrap">
      <table class="tb">
        <thead><tr>
          <th class="th-chk"><input type="checkbox" :checked="allVisibleChecked" @change="toggleAll" /></th>
          <th><div class="th-i"><span class="th-txt sortable" @click="sortBy('numero_lot')">N° Lot <span class="sort-arrow">{{sortIcon('numero_lot')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['numero_lot']}" @click="openDropdown('numero_lot',$event)">⌄</button></div></th>
          <th><div class="th-i"><span class="th-txt sortable" @click="sortBy('prod_desc')">Produit <span class="sort-arrow">{{sortIcon('prod_desc')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['prod_desc']}" @click="openDropdown('prod_desc',$event)">⌄</button></div></th>
          <th><div class="th-i"><span class="th-txt sortable" @click="sortBy('statut_label')">Statut <span class="sort-arrow">{{sortIcon('statut_label')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['statut_label']}" @click="openDropdown('statut_label',$event)">⌄</button></div></th>
          <th><div class="th-i"><span class="th-txt sortable" @click="sortBy('phase')">Phase <span class="sort-arrow">{{sortIcon('phase')}}</span></span><button class="th-f" :class="{'th-f-on':columnFilters['phase']}" @click="openDropdown('phase',$event)">⌄</button></div></th>
          <!-- Dynamic columns driven by visibleCols order -->
          <template v-for="ck in visibleCols" :key="'h-'+ck">
            <th><div class="th-i">
              <span class="th-txt" :class="{'sortable':CC[ck].s}" @click="CC[ck].s?sortBy(CC[ck].s):null">{{CC[ck].l2&&showDates?CC[ck].l2:CC[ck].l}} <span v-if="CC[ck].s" class="sort-arrow">{{sortIcon(CC[ck].s)}}</span></span>
              <button class="th-f" :class="{'th-f-on':columnFilters[CC[ck].f]}" @click="openDropdown(CC[ck].f,$event)">⌄</button>
            </div></th>
          </template>
        </tr></thead>
        <tbody>
          <tr v-for="l in pagedLots" :key="l.id" :class="{'row-sel':isSelected(l.id),'row-bloquante':l.dev_has_bloquante}" @click="goToLot(l.id)">
            <td class="td-chk" @click.stop><input type="checkbox" :value="l.id" v-model="selected" /></td>
            <td class="mono bold">{{l.numero_lot}}</td>
            <td class="td-prod">{{l.prod_desc}}<span class="code">{{l.prod_code}}</span></td>
            <td><span class="sp" :class="l.statut_class">{{l.statut_label}}</span></td>
            <td><span class="sp-phase" :class="getPhaseClass(l.phase)">{{l.phase}}</span></td>
            <!-- Dynamic columns -->
            <template v-for="ck in visibleCols" :key="'c-'+ck+'-'+l.id">
              <!-- OF/OC -->
              <td v-if="CC[ck].r==='ofoc'" class="td-action" @click.stop="openInlineMenu($event,l,ck)"><span class="doc-pip" :class="showDates&&l[CC[ck].dp]?'dc-date':l[CC[ck].xp]?'pip-done-t':'pip-prog-t'">{{showDates&&l[CC[ck].dp]?l[CC[ck].dp]:l[CC[ck].lp]}}</span></td>
              <!-- Standard doc / AQL / RVP / MàJ / Clôture SAP -->
              <td v-else-if="CC[ck].r==='doc'" class="td-action" @click.stop="openInlineMenu($event,l,ck)"><span class="doc-pip" :class="showDates&&l[CC[ck].dp]?'dc-date':l[CC[ck].cp]">{{showDates&&l[CC[ck].dp]?l[CC[ck].dp]:l[CC[ck].lp]}}</span></td>
              <!-- Planning dates -->
              <td v-else-if="CC[ck].r==='plan'" class="td-plan td-action" @click.stop="openDatePicker($event,l,ck)">
                <span v-if="l[ck]" class="plan-date" :class="[getPlanClass(l,CC[ck].pt),CC[ck].rv?'plan-revised':'']">{{l[ck]}}</span>
                <span v-else class="plan-empty">＋</span>
              </td>
              <!-- Déviation -->
              <td v-else-if="CC[ck].r==='dev'" class="td-action" @click.stop="openDevPopup($event,l)">
                <span v-if="l.dev_open>0" class="dev-badge dev-open">{{l.dev_open}} DN</span>
                <span v-else-if="l.dev_count>0" class="dev-badge dev-closed">Clôturée</span>
                <span v-else class="dim">—</span>
              </td>
              <!-- Date -->
              <td v-else class="mono dim">{{showDates?(l.date_lib||l.date_fmt):l.date_fmt}}</td>
            </template>
          </tr>
        </tbody>
      </table>
      <div class="pag-bar" v-if="totalPages > 1">
        <button class="pag-btn" :disabled="tablePage===0" @click.stop="tablePage--">‹ Préc.</button>
        <span class="pag-info">Page {{tablePage+1}} / {{totalPages}} &nbsp;·&nbsp; {{filteredLots.length}} lot{{filteredLots.length!==1?'s':''}}</span>
        <button class="pag-btn" :disabled="tablePage>=totalPages-1" @click.stop="tablePage++">Suiv. ›</button>
      </div>
    </div>

    <!-- Dropdown filtre colonne (position:fixed) -->
    <div v-if="activeDropdown" class="col-dd" :style="{top:ddPos.top+'px',left:ddPos.left+'px'}" @click.stop>
      <div class="col-dd-item col-dd-all" @click="setColumnFilter(null)">— Tout —</div>
      <div v-for="v in getColumnValues(activeDropdown)" :key="v" class="col-dd-item" :class="{'col-dd-on':columnFilters[activeDropdown]===v}" @click="setColumnFilter(v)">{{v}}</div>
    </div>

    <!-- Menu inline actions (position:fixed) -->
    <div v-if="inlineMenu" class="inline-menu" :style="{top:inlineMenu.top+'px',left:inlineMenu.left+'px'}" @click.stop>
      <div class="inline-menu-title">{{inlineMenu.colLabel}}</div>
      <!-- Confirmation motif pour les actions de retour -->
      <template v-if="inlineMenu.pendingAction">
        <div class="inline-motif-title">{{inlineMenu.pendingAction.label}}</div>
        <textarea v-model="inlineMenu.motifText" class="inline-motif-input" placeholder="Motif du retour (optionnel)…" rows="3"></textarea>
        <div class="inline-motif-btns">
          <button class="inline-motif-confirm" @click="confirmInlineMotif">✓ Confirmer</button>
          <button class="inline-motif-cancel" @click="inlineMenu.pendingAction=null">✕ Annuler</button>
        </div>
      </template>
      <template v-else>
        <button v-for="(act,idx) in inlineMenu.actions" :key="idx" class="inline-act" @click="executeInline(act)">{{act.label}}</button>
        <div v-if="!inlineMenu.actions.length" class="inline-empty">Aucune action disponible</div>
        <!-- Audit trail -->
        <button class="inline-hist-toggle" @click.stop="toggleInlineHistory">
          {{inlineMenu.historyOpen ? '▲ Masquer l\'historique' : '▼ Voir l\'historique'}}
        </button>
        <div v-if="inlineMenu.historyOpen" class="inline-hist">
          <div v-if="inlineMenu.historyLoading" class="inline-hist-empty">⟳ Chargement…</div>
          <div v-else-if="!inlineMenu.historyData.length" class="inline-hist-empty">Aucun historique enregistré</div>
          <div v-for="(h,i) in inlineMenu.historyData" :key="i" class="inline-hist-row">
            <span class="inline-hist-label">{{h.label}}</span>
            <div class="inline-hist-sub">
              <span class="inline-hist-who">{{h.who}}</span>
              <span class="inline-hist-at">{{h.at}}</span>
            </div>
          </div>
        </div>
      </template>
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
      <!-- Historique des modifications -->
      <div class="dp-history">
        <div class="dp-hist-title">Historique</div>
        <div v-if="planHistLoading" class="dp-hist-loading">⟳ Chargement…</div>
        <div v-else-if="!planHistory.length" class="dp-hist-empty">Aucune modification enregistrée</div>
        <div v-for="h in planHistory" :key="h.at" class="dp-hist-row">
          <span class="dp-hist-val">{{h.date}}</span>
          <span class="dp-hist-meta">{{h.user}} — {{h.at}}</span>
        </div>
      </div>
      <div class="dp-actions">
        <button class="dp-ok" @click="savePlanning">✓ Valider</button>
        <button class="dp-cancel" @click="datePicker=null">✕</button>
      </div>
    </div>

    <!-- Popup déviation -->
    <div v-if="devPopup" class="dev-pop" :style="{top:devPopup.top+'px',left:devPopup.left+'px'}" @click.stop>
      <div class="dev-pop-header">
        <span class="dev-pop-title">Déviations — {{devPopup.lotNum}}</span>
        <button class="dev-pop-x" @click="devPopup=null">✕</button>
      </div>
      <!-- Résumé -->
      <div class="dev-pop-summary">
        <span class="dev-sum-bl">{{devPopup.devBloquanteOpen}} bloquante{{devPopup.devBloquanteOpen!==1?'s':''}}</span>
        <span class="dev-sum-nb">{{devPopup.devNonBloquanteOpen}} non bloquante{{devPopup.devNonBloquanteOpen!==1?'s':''}}</span>
        <span class="dev-sum-cl">{{devPopup.devClosed}} clôturée{{devPopup.devClosed!==1?'s':''}}</span>
      </div>
      <!-- Liste déviations existantes — accordéon -->
      <div v-if="devPopup.devList.length" class="dev-pop-list">
        <div v-for="(d,di) in devPopup.devList" :key="d.id" class="dev-pop-acc">
          <!-- Ligne cliquable -->
          <div class="dev-pop-acc-hd" @click.stop="devPopup.expandedId===d.id?devPopup.expandedId=null:devPopup.expandedId=d.id">
            <span class="dev-badge-sm" :class="d.bloquante?'dev-bl-on':'dev-bl-off'">{{d.bloquante?'BLQ':'NBL'}}</span>
            <span class="dev-pop-stat" :class="d.statut==='cloturee'?'dev-stat-cl':'dev-stat-op'">{{d.statut==='cloturee'?'Clôturée':'Ouverte'}}</span>
            <span class="dev-pop-acc-num">{{d.numero_dn||('Dév. '+(di+1))}}</span>
            <span class="dev-pop-acc-date">{{fmtDevDate(d.declared_at)}}</span>
            <span class="dev-pop-acc-chev">{{devPopup.expandedId===d.id?'▲':'▼'}}</span>
          </div>
          <!-- Détail dépliable -->
          <div v-if="devPopup.expandedId===d.id" class="dev-pop-acc-body">
            <div class="dev-pop-meta">
              <span class="dev-pop-svc">{{SVC_LABELS[d.declared_service]||d.declared_service||'—'}}</span>
              <span class="dev-pop-who">{{d.declarer_nom||'—'}}</span>
            </div>
            <div class="dev-pop-edit-row">
              <input v-model="d.editNumeroDn" placeholder="N° DN" class="dev-pop-in-sm" />
            </div>
            <div class="dev-pop-edit-row">
              <textarea v-model="d.editObs" rows="2" placeholder="Observation" class="dev-pop-ta-sm"></textarea>
            </div>
            <div class="dev-pop-acc-actions">
              <button class="dev-save-btn" @click="saveDevField(d)">💾 Sauvegarder</button>
              <button v-if="!d.bloquante&&(d.statut==='ouverte'||d.statut==='en_cours')&&(userService==='admin'||canPerform('declarer_nc'))" class="dev-bl-btn" @click="markBloquanteInPopup(d.id)">⚠ Marquer bloquante</button>
              <button v-if="(d.statut==='ouverte'||d.statut==='en_cours')&&(userService==='admin'||canPerform('cloturer_deviation'))" class="dev-close-btn" @click="closeDevInPopup(d.id)">Clôturer</button>
            </div>
          </div>
        </div>
      </div>
      <!-- Formulaire nouvelle déviation -->
      <template v-if="userService==='admin'||canPerform('declarer_nc')">
        <div class="dev-pop-sep">Nouvelle déviation</div>
        <input type="text" v-model="devPopup.numeroDn" placeholder="N° DN (optionnel)" class="dev-pop-in" />
        <textarea v-model="devPopup.obs" rows="2" placeholder="Observation (optionnel)" class="dev-pop-ta"></textarea>
        <button class="dev-pop-tog" :class="devPopup.bloquante?'dev-pop-bl-on':'dev-pop-bl-off'" @click.stop="devPopup.bloquante=!devPopup.bloquante">
          {{devPopup.bloquante?'BLOQUANTE':'Non bloquante'}}
        </button>
        <div class="dev-pop-actions">
          <button class="dp-ok" @click="confirmDevPopup">✓ Déclarer</button>
        </div>
      </template>
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
    var lots = ref([]), total = ref(0)
    var lotsLoading = ref(false)
    var tablePage = ref(0)
    var TABLE_PAGE_SIZE = 250
    var sortCol = ref(''), sortDir = ref('asc'), showDates = ref(false)
    var hiddenStatuts = ref(JSON.parse(localStorage.getItem('lots_hidden_statuts') || '["accepte","refuse"]'))
    var toggleStatutVisibility = function(value) {
      var idx = hiddenStatuts.value.indexOf(value)
      if (idx >= 0) hiddenStatuts.value.splice(idx, 1)
      else hiddenStatuts.value.push(value)
      localStorage.setItem('lots_hidden_statuts', JSON.stringify(hiddenStatuts.value))
    }
    var showStatutPanel = ref(false)
    var selected = ref([]), actionType = ref(''), showConfirm = ref(false)
    var showActionPanel = ref(false), actionSearch = ref(''), expandedActionGroups = ref([])
    var toggleActionGroup = function(label) {
      var idx = expandedActionGroups.value.indexOf(label)
      if (idx >= 0) expandedActionGroups.value.splice(idx, 1)
      else expandedActionGroups.value.push(label)
    }
    var executing = ref(false), progress = ref(0), execResult = ref(null)
    var userService = ref(''), bulkDate = ref('')
    var bulkDevBloquante = ref(false), bulkDevNumeroDn = ref(''), bulkDevObs = ref('')
    var devPopup = ref(null)
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
      {label:'CCL',actions:[{value:'ccl_transmettre',label:'CCL — Transmettre au DT'},{value:'ccl_liberer',label:'CCL — Libérer le lot (DT)'},{value:'ccl_retourner',label:"CCL — Retourner à l'AQ (DT)"},{value:'ccl_reemettre',label:'CCL — Retransmettre au DT (AQ)'}]},
      {label:'Documents — Émission',actions:[{value:'doc_if',label:'IF — Émettre'},{value:'doc_ic',label:'IC — Émettre'},{value:'doc_da_pc',label:'DA Physico — Émettre'},{value:'doc_da_micro',label:'DA Micro — Émettre'}]},
      {label:'Documents — Vérification AQ → DT',actions:[{value:'doc_if_verifier',label:'IF — Vérifier AQ → DT'},{value:'doc_ic_verifier',label:'IC — Vérifier AQ → DT'},{value:'doc_da_pc_verifier',label:'DA Physico — Vérifier AQ → DT'},{value:'doc_da_micro_verifier',label:'DA Micro — Vérifier AQ → DT'}]},
      {label:'Documents — Approbation DT',actions:[{value:'doc_if_approuver',label:'IF — Approuver DT'},{value:'doc_ic_approuver',label:'IC — Approuver DT'},{value:'doc_da_pc_approuver',label:'DA Physico — Approuver DT'},{value:'doc_da_micro_approuver',label:'DA Micro — Approuver DT'}]},
      {label:'Documents — Retour',actions:[{value:'doc_if_retour_emetteur',label:"IF — Retourner à l'émetteur"},{value:'doc_ic_retour_emetteur',label:"IC — Retourner à l'émetteur"},{value:'doc_da_pc_retour_emetteur',label:"DA Physico — Retourner à l'émetteur"},{value:'doc_da_micro_retour_emetteur',label:"DA Micro — Retourner à l'émetteur"},{value:'doc_if_retour_aq',label:"IF — DT retourne à l'AQ"},{value:'doc_ic_retour_aq',label:"IC — DT retourne à l'AQ"},{value:'doc_da_pc_retour_aq',label:"DA Physico — DT retourne à l'AQ"},{value:'doc_da_micro_retour_aq',label:"DA Micro — DT retourne à l'AQ"}]},
      {label:'AQL',actions:[{value:'aql_fab_demander',label:'AQL Fabrication — Demander'},{value:'aql_fab_relancer',label:'AQL Fabrication — Relancer'},{value:'aql_fab_conforme',label:'AQL Fabrication — Conforme'},{value:'aql_fab_non_conforme',label:'AQL Fabrication — Non conforme'},{value:'aql_cond_demander',label:'AQL Conditionnement — Demander'},{value:'aql_cond_relancer',label:'AQL Conditionnement — Relancer'},{value:'aql_cond_conforme',label:'AQL Conditionnement — Conforme'},{value:'aql_cond_non_conforme',label:'AQL Conditionnement — Non conforme'}]},
      {label:'RVP — Émission',actions:[{value:'rvp_fab_emettre',label:'RVP Fabrication — Émettre'},{value:'rvp_cond_emettre',label:'RVP Conditionnement — Émettre'},{value:'rvp_lcq_emettre',label:'RVP LCQ — Émettre'}]},
      {label:'RVP — Vérification AQ → DT',actions:[{value:'rvp_fab_verifier',label:'RVP Fabrication — Vérifier AQ → DT'},{value:'rvp_cond_verifier',label:'RVP Conditionnement — Vérifier AQ → DT'},{value:'rvp_lcq_verifier',label:'RVP LCQ — Vérifier AQ → DT'}]},
      {label:'RVP — Approbation DT',actions:[{value:'rvp_fab_approuver',label:'RVP Fabrication — Approuver DT'},{value:'rvp_cond_approuver',label:'RVP Conditionnement — Approuver DT'},{value:'rvp_lcq_approuver',label:'RVP LCQ — Approuver DT'}]},
      {label:'RVP — Retour',actions:[{value:'rvp_fab_retour_emetteur',label:"RVP Fabrication — Retourner à l'émetteur"},{value:'rvp_cond_retour_emetteur',label:"RVP Conditionnement — Retourner à l'émetteur"},{value:'rvp_lcq_retour_emetteur',label:"RVP LCQ — Retourner à l'émetteur"},{value:'rvp_fab_retour_aq',label:"RVP Fabrication — DT retourne à l'AQ"},{value:'rvp_cond_retour_aq',label:"RVP Conditionnement — DT retourne à l'AQ"},{value:'rvp_lcq_retour_aq',label:"RVP LCQ — DT retourne à l'AQ"}]},
      {label:'MàJ Documents',actions:[{value:'maj_if_declarer',label:'MàJ IF — Déclarer'},{value:'maj_if_emettre',label:'MàJ IF — Émettre'},{value:'maj_if_verifier',label:'MàJ IF — Vérifier AQ'},{value:'maj_if_approuver',label:'MàJ IF — Approuver DT'},{value:'maj_ic_declarer',label:'MàJ IC — Déclarer'},{value:'maj_ic_emettre',label:'MàJ IC — Émettre'},{value:'maj_ic_verifier',label:'MàJ IC — Vérifier AQ'},{value:'maj_ic_approuver',label:'MàJ IC — Approuver DT'},{value:'maj_nmcl_of_declarer',label:'MàJ Nmcl OF — Déclarer'},{value:'maj_nmcl_of_emettre',label:'MàJ Nmcl OF — Émettre'},{value:'maj_nmcl_of_verifier',label:'MàJ Nmcl OF — Vérifier AQ'},{value:'maj_nmcl_of_approuver',label:'MàJ Nmcl OF — Approuver DT'},{value:'maj_nmcl_oc_declarer',label:'MàJ Nmcl OC — Déclarer'},{value:'maj_nmcl_oc_emettre',label:'MàJ Nmcl OC — Émettre'},{value:'maj_nmcl_oc_verifier',label:'MàJ Nmcl OC — Vérifier AQ'},{value:'maj_nmcl_oc_approuver',label:'MàJ Nmcl OC — Approuver DT'}]},
      {label:'Clôture SAP',actions:[{value:'clot_of_emettre',label:'Clôt. SAP OF — Émettre'},{value:'clot_of_valider',label:'Clôt. SAP OF — Valider (Planif.)'},{value:'clot_of_cloture',label:'Clôt. SAP OF — Dem. clôture'},{value:'clot_of_confirmer',label:'Clôt. SAP OF — Confirmer clôture'},{value:'clot_oc_emettre',label:'Clôt. SAP OC — Émettre'},{value:'clot_oc_valider',label:'Clôt. SAP OC — Valider (Planif.)'},{value:'clot_oc_cloture',label:'Clôt. SAP OC — Dem. clôture'},{value:'clot_oc_confirmer',label:'Clôt. SAP OC — Confirmer clôture'}]},
      {label:'Déviation',actions:[{value:'dev_declarer',label:'Déviation — Déclarer'},{value:'dev_bloquer',label:'Déviation — Marquer bloquante'},{value:'dev_cloture',label:'Déviation — Clôturer'}]},
      {label:'Dates prévisionnelles',actions:[{value:'plan_lcq',label:'Libération LCQ'},{value:'plan_aq',label:'Libération AQ'},{value:'plan_dt1',label:'Libération DT1'},{value:'plan_dt2',label:'Libération DT2'}]},
      {label:'Accusés de réception',actions:[
        {value:'ar_circuit_of',label:'AR — Circuit OF (intermédiaire)'},
        {value:'ar_circuit_oc',label:'AR — Circuit OC (intermédiaire)'},
        {value:'ar_doc_if',label:'AR — Document IF'},
        {value:'ar_doc_ic',label:'AR — Document IC'},
        {value:'ar_doc_da_pc',label:'AR — Document DA PC'},
        {value:'ar_doc_da_micro',label:'AR — Document DA Micro'},
        {value:'ar_doc_ccl',label:'AR — Document CCL'},
        {value:'ar_doc_rvp_fab',label:'AR — RVP Fabrication'},
        {value:'ar_doc_rvp_cond',label:'AR — RVP Conditionnement'},
        {value:'ar_doc_rvp_lcq',label:'AR — RVP LCQ'},
        {value:'ar_aql_fab_demande',label:'AR — Demande AQL Fabrication'},
        {value:'ar_aql_cond_demande',label:'AR — Demande AQL Conditionnement'},
        {value:'ar_aql_fab_resultat',label:'AR — Résultat AQL Fabrication'},
        {value:'ar_aql_cond_resultat',label:'AR — Résultat AQL Conditionnement'},
      ]},
    ]
    var actionGroups = computed(function(){
      return actionGroupDefs.map(function(g){
        return {label:g.label,actions:g.actions.filter(function(a){return canAction(a.value)})}
      }).filter(function(g){return g.actions.length>0})
    })
    var filteredActionGroups = computed(function(){
      var q = actionSearch.value.trim().toLowerCase()
      return actionGroups.value.map(function(grp){
        var acts = q ? grp.actions.filter(function(opt){
          return opt.label.toLowerCase().indexOf(q)>=0 || grp.label.toLowerCase().indexOf(q)>=0
        }) : grp.actions
        return Object.assign({},grp,{filteredActions:acts})
      }).filter(function(grp){return grp.filteredActions.length>0})
    })
    var selectAction = function(value){
      actionType.value = value
      showActionPanel.value = false
      actionSearch.value = ''
    }

    // ── Colonnes show/hide ─────────────────────────────────────────────
    // ── Column config (pilote headers, cells, tri, filtre) ────────────
    // l=label, s=sortKey, f=filterKey, r=renderType, lp=labelProp, cp=classProp, dp=dateProp, xp=doneProp, pt=planType, rv=revised
    var CC = {
      of:{l:'OF',s:'of_label',f:'of_label',r:'ofoc',lp:'of_label',dp:'of_date',xp:'of_done'},
      oc:{l:'OC',s:'oc_label',f:'oc_label',r:'ofoc',lp:'oc_label',dp:'oc_date',xp:'oc_done'},
      aql_fab:{l:'AQL Fab',s:null,f:'aql_fab_label',r:'doc',lp:'aql_fab_label',cp:'aql_fab_class',dp:'aql_fab_date'},
      aql_cond:{l:'AQL Cond',s:null,f:'aql_cond_label',r:'doc',lp:'aql_cond_label',cp:'aql_cond_class',dp:'aql_cond_date'},
      'if':{l:'IF',s:'if_label',f:'if_label',r:'doc',lp:'if_label',cp:'if_class',dp:'if_date'},
      ic:{l:'IC',s:'ic_label',f:'ic_label',r:'doc',lp:'ic_label',cp:'ic_class',dp:'ic_date'},
      da_pc:{l:'DA PC',s:null,f:'dapc_label',r:'doc',lp:'dapc_label',cp:'dapc_class',dp:'dapc_date'},
      da_micro:{l:'DA Micro',s:null,f:'damicro_label',r:'doc',lp:'damicro_label',cp:'damicro_class',dp:'damicro_date'},
      ccl:{l:'CCL',s:null,f:'ccl_label',r:'doc',lp:'ccl_label',cp:'ccl_class',dp:'ccl_date'},
      dev:{l:'Dév.',s:null,f:'dev_label',r:'dev'},
      rvp_fab:{l:'RVP Fab',s:null,f:'rvp_fab_label',r:'doc',lp:'rvp_fab_label',cp:'rvp_fab_class',dp:'rvp_fab_date'},
      rvp_cond:{l:'RVP Cond',s:null,f:'rvp_cond_label',r:'doc',lp:'rvp_cond_label',cp:'rvp_cond_class',dp:'rvp_cond_date'},
      rvp_lcq:{l:'RVP LCQ',s:null,f:'rvp_lcq_label',r:'doc',lp:'rvp_lcq_label',cp:'rvp_lcq_class',dp:'rvp_lcq_date'},
      maj_if:{l:'MàJ IF',s:null,f:'maj_if_label',r:'doc',lp:'maj_if_label',cp:'maj_if_class',dp:'maj_if_date'},
      maj_ic:{l:'MàJ IC',s:null,f:'maj_ic_label',r:'doc',lp:'maj_ic_label',cp:'maj_ic_class',dp:'maj_ic_date'},
      maj_nmcl_of:{l:'MàJ N. OF',s:null,f:'maj_nmcl_of_label',r:'doc',lp:'maj_nmcl_of_label',cp:'maj_nmcl_of_class',dp:'maj_nmcl_of_date'},
      maj_nmcl_oc:{l:'MàJ N. OC',s:null,f:'maj_nmcl_oc_label',r:'doc',lp:'maj_nmcl_oc_label',cp:'maj_nmcl_oc_class',dp:'maj_nmcl_oc_date'},
      cloture_sap_of:{l:'Clôt. OF',s:null,f:'clot_of_label',r:'doc',lp:'clot_of_label',cp:'clot_of_class',dp:'clot_of_date'},
      cloture_sap_oc:{l:'Clôt. OC',s:null,f:'clot_oc_label',r:'doc',lp:'clot_oc_label',cp:'clot_oc_class',dp:'clot_oc_date'},
      plan_lcq:{l:'Lib. LCQ',s:'plan_lcq_raw',f:'plan_lcq',r:'plan',pt:'lcq'},
      plan_aq:{l:'Lib. AQ',s:'plan_aq_raw',f:'plan_aq',r:'plan',pt:'aq'},
      plan_dt1:{l:'Lib. DT1',s:'plan_dt1_raw',f:'plan_dt1',r:'plan',pt:'dt'},
      plan_dt2:{l:'Lib. DT2',s:'plan_dt2_raw',f:'plan_dt2',r:'plan',pt:'dt',rv:true},
      date:{l:'Date',l2:'Libération',s:'date_fmt',f:'date_fmt',r:'date'},
    }
    var ALL_COLS = ['of','oc','aql_fab','aql_cond','if','ic','da_pc','da_micro','ccl','dev','rvp_fab','rvp_cond','rvp_lcq','maj_if','maj_ic','maj_nmcl_of','maj_nmcl_oc','cloture_sap_of','cloture_sap_oc','plan_lcq','plan_aq','plan_dt1','plan_dt2','date']
    var COL_LABELS = {};ALL_COLS.forEach(function(k){COL_LABELS[k]=CC[k].l})
    // ── Colonnes : ordre (colOrder) + visibilité (hiddenCols) séparés ──
    var savedOrder = null, savedHidden = []
    try { savedOrder = JSON.parse(localStorage.getItem('lots_col_order')) } catch(e) {}
    // compat ancien format : lots_vis_cols ne contenait que les colonnes visibles
    if (!savedOrder) { try { savedOrder = JSON.parse(localStorage.getItem('lots_vis_cols')) } catch(e) {} }
    try { savedHidden = JSON.parse(localStorage.getItem('lots_hidden_cols')) || [] } catch(e) {}
    // Ajouter les nouvelles colonnes absentes de l'ordre sauvegardé
    if (savedOrder) { ALL_COLS.forEach(function(k){ if(savedOrder.indexOf(k)<0) savedOrder.push(k) }) }
    var colOrder = ref(savedOrder || ALL_COLS.slice())
    var hiddenCols = ref(savedHidden)
    // tableCols = ce qui est affiché dans le tableau (order - hidden)
    var tableCols = computed(function(){return colOrder.value.filter(function(k){return hiddenCols.value.indexOf(k)<0})})
    var showColPanel = ref(false)
    // colDefs = TOUTES les colonnes dans l'ordre (pour le panneau)
    var colDefs = computed(function(){return colOrder.value.map(function(k){return{key:k,label:CC[k].l}})})
    var isColVisible = function(col){ return hiddenCols.value.indexOf(col) < 0 }
    var toggleCol = function(col){
      var idx = hiddenCols.value.indexOf(col)
      if(idx>=0) hiddenCols.value.splice(idx,1); else hiddenCols.value.push(col)
      try { localStorage.setItem('lots_col_order',JSON.stringify(colOrder.value)); localStorage.setItem('lots_hidden_cols',JSON.stringify(hiddenCols.value)) } catch(e) {}
    }
    var resetCols = function(){ colOrder.value=ALL_COLS.slice(); hiddenCols.value=[]; try{localStorage.removeItem('lots_col_order');localStorage.removeItem('lots_hidden_cols');localStorage.removeItem('lots_vis_cols')}catch(e){} }
    var moveColUp = function(col){var i=colOrder.value.indexOf(col);if(i>0){var a=colOrder.value.slice();var t=a[i];a[i]=a[i-1];a[i-1]=t;colOrder.value=a;try{localStorage.setItem('lots_col_order',JSON.stringify(a))}catch(e){}}}
    var moveColDown = function(col){var i=colOrder.value.indexOf(col);if(i>=0&&i<colOrder.value.length-1){var a=colOrder.value.slice();var t=a[i];a[i]=a[i+1];a[i+1]=t;colOrder.value=a;try{localStorage.setItem('lots_col_order',JSON.stringify(a))}catch(e){}}}

    // ── Drag & drop colonnes ───────────────────────────────────────────
    var colDragIdx = ref(null)
    var colDragOverIdx = ref(null)
    var onColDragStart = function(idx, e) {
      colDragIdx.value = idx
      if (e.dataTransfer) { e.dataTransfer.effectAllowed = 'move'; e.dataTransfer.setData('text/plain', idx) }
    }
    var onColDragOver = function(idx) { colDragOverIdx.value = idx }
    var onColDrop = function(targetIdx) {
      var fromIdx = colDragIdx.value
      if (fromIdx === null || fromIdx === targetIdx) { colDragIdx.value = null; colDragOverIdx.value = null; return }
      var a = colOrder.value.slice()
      var moved = a.splice(fromIdx, 1)[0]
      a.splice(targetIdx, 0, moved)
      colOrder.value = a
      try { localStorage.setItem('lots_col_order', JSON.stringify(a)) } catch(e) {}
      colDragIdx.value = null
      colDragOverIdx.value = null
    }
    var onColDragEnd = function() { colDragIdx.value = null; colDragOverIdx.value = null }
    // ──────────────────────────────────────────────────────────────────

    var statusLabels = {vide:'Planifié',quarantaine:'Quarantaine',sous_investigation:'Investigation',accepte:'Accepté',refuse:'Refusé'}
    var filterOptions = [
      {label:'Planifié',value:'planifie',color:'#999'},
      {label:'En préparation',value:'en_preparation',color:'#5B3CC4'},
      {label:'En production',value:'en_production',color:'#7c3aed'},
      {label:'Quarantaine',value:'quarantaine',color:'#FFA94D'},
      {label:'Investigation',value:'sous_investigation',color:'#E24B4A'},
      {label:'Acceptés',value:'accepte',color:'#1D9E75'},
      {label:'Refusé',value:'refuse',color:'#666'},
    ]
    var etapeLabels = {planification:'Planif.',stock:'Stock',aq:'AQ',dt:'DT',aq_dap:'AQ DAP',production:'Prod.'}
    var docStatutLabels = {non_emis:'Non émis',emis:'Émis',verification_aq:'Vérif AQ',retour_emetteur:'Retourné',rectification:'Rectif.',approuve_aq:'Appr. AQ',approbation_dt:'Appr. DT',approuve_dt:'Approuvé'}
    var clotureSapLabels = {non_emis:'Dem. valid.',emis:'Dem. valid.',valide_planif:'Validé',cloture_demandee:'Dem. clôt.',cloture:'Clôturé'}
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

    // Correspondance type de doc → service émetteur court
    var DOC_SVC_SHORT = {'if':'Fab.','ic':'Cond.','da_pc':'LCQ','da_micro':'LCQ','ccl':'AQ','maj_if':'Fab.','maj_ic':'Cond.','maj_nmcl_of':'Planif.','maj_nmcl_oc':'Planif.'}
    var SVC_SHORT = {fabrication:'Fab.',conditionnement:'Cond.',lcq:'LCQ',planification:'Planif.',aq:'AQ',aq_dap:'AQ DAP',dt:'DT',stock:'Stock'}

    // Retourne le service qui détient actuellement le document
    var docLocation = function(statut, emitterShort) {
      if (statut==='non_emis'||statut==='rectification') return emitterShort||'—'
      if (statut==='emis'||statut==='verification_aq') return 'AQ'
      if (statut==='retour_emetteur') return '↩ '+(emitterShort||'—')
      if (statut==='approuve_aq'||statut==='approbation_dt') return 'DT'
      if (statut==='approuve_dt') return '✓ Lib.'
      return emitterShort||'—'
    }

    var getDocInfo = function(docs,type){
      var d=null;if(docs){for(var i=0;i<docs.length;i++){if(docs[i].type_document===type){d=docs[i];break}}}
      if(!d)return{label:'—',cls:'dc-na',date:null,pendingAr:null,docId:null}
      if(!d.is_applicable)return{label:'N/A',cls:'dc-na',date:null,pendingAr:null,docId:d.id}
      if(d.pending_ar_service)return{label:'⏳ '+(SVC_SHORT[d.pending_ar_service]||d.pending_ar_service),cls:'dc-prog',date:null,pendingAr:d.pending_ar_service,docId:d.id}
      var emitter=DOC_SVC_SHORT[type]||'—'
      var label=docLocation(d.statut,emitter)
      var cls='dc-wait';if(d.statut==='approuve_dt')cls='dc-ok';else if(d.statut==='retour_emetteur')cls='dc-ret';else if(d.statut!=='non_emis')cls='dc-prog'
      var date=d.approved_at||d.emitted_at;return{label:label,cls:cls,date:date?fmt(date):null,pendingAr:null,docId:d.id}
    }

    var getRvpInfo = function(docs,emetteur){
      var d=null;if(docs){for(var i=0;i<docs.length;i++){if(docs[i].type_document==='rvp'&&docs[i].service_emetteur===emetteur){d=docs[i];break}}}
      if(!d)return{label:'—',cls:'dc-na',date:null,pendingAr:null,docId:null}
      if(d.pending_ar_service)return{label:'⏳ '+(SVC_SHORT[d.pending_ar_service]||d.pending_ar_service),cls:'dc-prog',date:null,pendingAr:d.pending_ar_service,docId:d.id}
      var emitter=SVC_SHORT[emetteur]||emetteur
      var label=docLocation(d.statut,emitter)
      var cls='dc-wait';if(d.statut==='approuve_dt')cls='dc-ok';else if(d.statut==='retour_emetteur')cls='dc-ret';else if(d.statut!=='non_emis')cls='dc-prog'
      var date=d.approved_at||d.emitted_at;return{label:label,cls:cls,date:date?fmt(date):null,pendingAr:null,docId:d.id}
    }

    var getClotureSapInfo = function(docs,type){
      var d=null;if(docs){for(var i=0;i<docs.length;i++){if(docs[i].type_document===type){d=docs[i];break}}}
      var emitter=type==='cloture_sap_of'?'Fab.':'Cond.'
      if(!d)return{label:emitter,cls:'dc-wait',date:null}
      var label
      if(d.statut==='non_emis') label=emitter
      else if(d.statut==='emis') label='Planif.'
      else if(d.statut==='valide_planif') label=emitter
      else if(d.statut==='cloture_demandee') label='Planif.'
      else if(d.statut==='cloture') label='✓ Clôt.'
      else label=emitter
      var cls='dc-wait';if(d.statut==='cloture')cls='dc-ok';else if(d.statut==='cloture_demandee'||d.statut==='emis')cls='dc-prog';else if(d.statut==='valide_planif')cls='dc-prog'
      var date=d.updated_at;return{label:label,cls:cls,date:date?fmt(date):null}
    }

    var getAqlInfo = function(aqls,type){
      if(!aqls||!aqls.length)return{label:'—',cls:'dc-na',date:null,reqArPending:false,resArPending:false,aqlId:null}
      var latest=null;for(var i=0;i<aqls.length;i++){if(aqls[i].type===type){if(!latest||new Date(aqls[i].requested_at||0)>new Date(latest.requested_at||0))latest=aqls[i]}}
      if(!latest)return{label:'—',cls:'dc-na',date:null,reqArPending:false,resArPending:false,aqlId:null}
      if(latest.request_ar_pending)return{label:'⏳ AQ',cls:'dc-prog',date:null,reqArPending:true,resArPending:false,aqlId:latest.id}
      if(latest.result_ar_pending)return{label:'⏳ Résultat',cls:'dc-prog',date:null,reqArPending:false,resArPending:true,aqlId:latest.id}
      if(latest.resultat==='conforme')return{label:'✓ Conf.',cls:'dc-ok',date:latest.inspected_at?fmt(latest.inspected_at):null,reqArPending:false,resArPending:false,aqlId:latest.id}
      if(latest.resultat==='non_conforme')return{label:'✗ N.C.',cls:'dc-ret',date:latest.inspected_at?fmt(latest.inspected_at):null,reqArPending:false,resArPending:false,aqlId:latest.id}
      return{label:'AQ',cls:'dc-prog',date:latest.requested_at?fmt(latest.requested_at):null,reqArPending:false,resArPending:false,aqlId:latest.id}
    }

    var getOfOcInfo = function(order,statutSap){
      var inStock=statutSap==='quarantaine'||statutSap==='sous_investigation'||statutSap==='accepte'||statutSap==='refuse'
      if(inStock)return{label:'Terminé',done:true,date:null,pendingAr:null}
      if(!order)return{label:'—',done:false,date:null,pendingAr:null}
      if(order.statut==='termine')return{label:'Terminé',done:true,date:order.updated_at?fmt(order.updated_at):null,pendingAr:null}
      if(order.pending_ar_service)return{label:'⏳ '+(SVC_SHORT[order.pending_ar_service]||order.pending_ar_service),done:false,date:null,pendingAr:order.pending_ar_service}
      return{label:etapeLabels[order.etape_circuit]||order.etape_circuit||'—',done:false,date:order.updated_at?fmt(order.updated_at):null,pendingAr:null}
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
      lotsLoading.value = true
      try {
      // Requête lots + products uniquement (belongs-to, rapide). Les relations has-many
      // sont récupérées séparément → évite le timeout de la méga-jointure PostgREST.
      var query = supabase.from('lots').select('*, products(code_article,description)')

      var q = route.query.q
      if(q){
        var matchRes=await supabase.from('products').select('id').or('code_article.ilike.%'+q+'%,description.ilike.%'+q+'%')
        var prodIds=(matchRes.data||[]).map(function(p){return p.id})
        if(prodIds.length){query=query.or('numero_lot.ilike.%'+q+'%,product_id.in.('+prodIds.join(',')+')')}
        else{query=query.ilike('numero_lot','%'+q+'%')}
      }

      query=query.order('date_enregistrement',{ascending:false,nullsFirst:false}).range(0,99999)
      var result=await query
      if(result.error){console.error('Erreur chargement lots:',result.error);return}
      var rows=result.data||[]
      total.value=rows.length
      var lotIds=rows.map(function(l){return l.id})
      if(!lotIds.length){lots.value=[];return}

      // Relations récupérées par lots de 100 IDs (évite URL trop longue sur .in())
      var chunk=function(arr,size){var out=[];for(var ci=0;ci<arr.length;ci+=size){out.push(arr.slice(ci,ci+size))}return out}
      var idChunks=chunk(lotIds,100)
      var fetchRel=function(table,cols){
        return Promise.all(idChunks.map(function(ids){return supabase.from(table).select(cols).in('lot_id',ids)}))
          .then(function(res){var all=[];res.forEach(function(r){if(r.data)all=all.concat(r.data)});return all})
      }
      var rel=await Promise.all([
        fetchRel('orders_of','id,lot_id,statut,etape_circuit,updated_at,pending_ar_service'),
        fetchRel('orders_oc','id,lot_id,statut,etape_circuit,updated_at,pending_ar_service'),
        fetchRel('liberation_documents','id,lot_id,type_document,statut,is_applicable,service_emetteur,emitted_at,approved_at,updated_at,pending_ar_service'),
        fetchRel('deviations','id,lot_id,statut,bloquante,numero_dn,description,declared_at,declared_service,profiles!declared_by(prenom,nom)'),
        fetchRel('aql_inspections','id,lot_id,type,resultat,requested_at,inspected_at,request_ar_pending,result_ar_pending'),
        fetchRel('lot_planning','lot_id,date_lcq_cible,date_lcq_revisee,date_aq_cible,date_aq_revisee,date_dt_cible,date_dt_revisee'),
      ])
      var ofMap={},ocMap={},docsMap={},devsMap={},aqlsMap={},planMap={}
      rel[0].forEach(function(o){ofMap[o.lot_id]=o})
      rel[1].forEach(function(o){ocMap[o.lot_id]=o})
      rel[2].forEach(function(d){(docsMap[d.lot_id]=docsMap[d.lot_id]||[]).push(d)})
      rel[3].forEach(function(d){(devsMap[d.lot_id]=devsMap[d.lot_id]||[]).push(d)})
      rel[4].forEach(function(a){(aqlsMap[a.lot_id]=aqlsMap[a.lot_id]||[]).push(a)})
      rel[5].forEach(function(p){planMap[p.lot_id]=p})

      lots.value=rows.map(function(l){
        var docs=docsMap[l.id]||[]
        var devs=devsMap[l.id]||[]
        var aqls=aqlsMap[l.id]||[]
        var of=ofMap[l.id]||null
        var oc=ocMap[l.id]||null
        var planning=planMap[l.id]||null

        var statutInfo=getGranularStatus(of,oc,docs,l.statut_sap)
        var ofInfo=getOfOcInfo(of,l.statut_sap)
        var ocInfo=getOfOcInfo(oc,l.statut_sap)
        var ifInfo=getDocInfo(docs,'if')
        var icInfo=getDocInfo(docs,'ic')
        var dapcInfo=getDocInfo(docs,'da_pc')
        var damicroInfo=getDocInfo(docs,'da_micro')
        var cclInfo=getDocInfo(docs,'ccl')
        var aqlFab=getAqlInfo(aqls,'fabrication')
        var aqlCond=getAqlInfo(aqls,'conditionnement')
        var rvpFab=getRvpInfo(docs,'fabrication')
        var rvpCond=getRvpInfo(docs,'conditionnement')
        var rvpLcq=getRvpInfo(docs,'lcq')
        var majIfInfo=getDocInfo(docs,'maj_if')
        var majIcInfo=getDocInfo(docs,'maj_ic')
        var majNmclOfInfo=getDocInfo(docs,'maj_nmcl_of')
        var majNmclOcInfo=getDocInfo(docs,'maj_nmcl_oc')
        var clotOfInfo=getClotureSapInfo(docs,'cloture_sap_of')
        var clotOcInfo=getClotureSapInfo(docs,'cloture_sap_oc')
        var devOpen=0,devBloquanteOpen=0,devNonBloquanteOpen=0,devClosed=0
        for(var j=0;j<devs.length;j++){
          var dv=devs[j]
          if(dv.statut==='ouverte'||dv.statut==='en_cours'){devOpen++;if(dv.bloquante)devBloquanteOpen++;else devNonBloquanteOpen++}
          else if(dv.statut==='cloturee')devClosed++
        }
        var devHasBloquante=devBloquanteOpen>0

        var planLcqRaw = planning ? planning.date_lcq_cible  : null
        var planAqRaw  = planning ? planning.date_aq_cible   : null
        var planDt1Raw = planning ? planning.date_dt_cible   : null
        var planDt2Raw = planning ? planning.date_dt_revisee : null

        return{
          id:l.id,numero_lot:l.numero_lot,statut_sap:l.statut_sap,
          statut_label:statutInfo.label,statut_class:statutInfo.cls,statut_filter:statutInfo.filter,
          date_fmt:fmt(l.date_enregistrement),date_lib:l.date_liberation?fmt(l.date_liberation):null,
          prod_desc:l.products?l.products.description:'',prod_code:l.products?l.products.code_article:'',
          of_label:ofInfo.label,of_done:ofInfo.done,of_date:ofInfo.date,of_pending_ar:ofInfo.pendingAr,
          oc_label:ocInfo.label,oc_done:ocInfo.done,oc_date:ocInfo.date,oc_pending_ar:ocInfo.pendingAr,
          if_label:ifInfo.label,if_class:ifInfo.cls,if_date:ifInfo.date,if_pending_ar:ifInfo.pendingAr,if_doc_id:ifInfo.docId,
          ic_label:icInfo.label,ic_class:icInfo.cls,ic_date:icInfo.date,ic_pending_ar:icInfo.pendingAr,ic_doc_id:icInfo.docId,
          dapc_label:dapcInfo.label,dapc_class:dapcInfo.cls,dapc_date:dapcInfo.date,dapc_pending_ar:dapcInfo.pendingAr,dapc_doc_id:dapcInfo.docId,
          damicro_label:damicroInfo.label,damicro_class:damicroInfo.cls,damicro_date:damicroInfo.date,damicro_pending_ar:damicroInfo.pendingAr,damicro_doc_id:damicroInfo.docId,
          ccl_label:cclInfo.label,ccl_class:cclInfo.cls,ccl_date:cclInfo.date,ccl_pending_ar:cclInfo.pendingAr,ccl_doc_id:cclInfo.docId,
          aql_fab_label:aqlFab.label,aql_fab_class:aqlFab.cls,aql_fab_date:aqlFab.date,aql_fab_req_ar:aqlFab.reqArPending,aql_fab_res_ar:aqlFab.resArPending,aql_fab_id:aqlFab.aqlId,
          aql_cond_label:aqlCond.label,aql_cond_class:aqlCond.cls,aql_cond_date:aqlCond.date,aql_cond_req_ar:aqlCond.reqArPending,aql_cond_res_ar:aqlCond.resArPending,aql_cond_id:aqlCond.aqlId,
          rvp_fab_label:rvpFab.label,rvp_fab_class:rvpFab.cls,rvp_fab_date:rvpFab.date,rvp_fab_pending_ar:rvpFab.pendingAr,rvp_fab_doc_id:rvpFab.docId,
          rvp_cond_label:rvpCond.label,rvp_cond_class:rvpCond.cls,rvp_cond_date:rvpCond.date,rvp_cond_pending_ar:rvpCond.pendingAr,rvp_cond_doc_id:rvpCond.docId,
          rvp_lcq_label:rvpLcq.label,rvp_lcq_class:rvpLcq.cls,rvp_lcq_date:rvpLcq.date,rvp_lcq_pending_ar:rvpLcq.pendingAr,rvp_lcq_doc_id:rvpLcq.docId,
          maj_if_label:majIfInfo.label,maj_if_class:majIfInfo.cls,maj_if_date:majIfInfo.date,
          maj_ic_label:majIcInfo.label,maj_ic_class:majIcInfo.cls,maj_ic_date:majIcInfo.date,
          maj_nmcl_of_label:majNmclOfInfo.label,maj_nmcl_of_class:majNmclOfInfo.cls,maj_nmcl_of_date:majNmclOfInfo.date,
          maj_nmcl_oc_label:majNmclOcInfo.label,maj_nmcl_oc_class:majNmclOcInfo.cls,maj_nmcl_oc_date:majNmclOcInfo.date,
          clot_of_label:clotOfInfo.label,clot_of_class:clotOfInfo.cls,clot_of_date:clotOfInfo.date,
          clot_oc_label:clotOcInfo.label,clot_oc_class:clotOcInfo.cls,clot_oc_date:clotOcInfo.date,
          dev_count:devs.length,dev_open:devOpen,dev_bloquante_open:devBloquanteOpen,dev_non_bloquante_open:devNonBloquanteOpen,dev_closed:devClosed,dev_has_bloquante:devHasBloquante,dev_list:devs,
          plan_lcq:fmtPlan(planLcqRaw),plan_lcq_raw:planLcqRaw,
          plan_aq:fmtPlan(planAqRaw),plan_aq_raw:planAqRaw,
          plan_dt1:fmtPlan(planDt1Raw),plan_dt1_raw:planDt1Raw,
          plan_dt2:fmtPlan(planDt2Raw),plan_dt2_raw:planDt2Raw,
          of_id:of?of.id:null,oc_id:oc?oc.id:null,docs:docs,aqls_raw:aqls,
          of_etape:of?of.etape_circuit:null,oc_etape:oc?oc.etape_circuit:null,
          of_statut:of?of.statut:null,oc_statut:oc?oc.statut:null,
          phase:l.phase_production_en_cours||'Planifié',
        }
      })
      } catch(e) { console.error('Erreur chargement lots:', e) } finally { lotsLoading.value = false }
    }

    var getPhaseClass = function(phase) {
      if (!phase || phase === 'Planifié') return 'phase-planifie'
      if (phase === 'Libéré') return 'phase-libere'
      if (phase === 'Clôturé') return 'phase-cloture'
      if (phase === 'Fabriqué — En attente conditionnement') return 'phase-attente-cond'
      if (phase === 'Conditionné — En attente livraison PF') return 'phase-attente-pf'
      if (phase.startsWith('Conditionnement —')) return 'phase-cond'
      return 'phase-fab'
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
    var SVC_MAP = {'if':'fabrication',ic:'conditionnement',da_pc:'lcq',da_micro:'lcq',ccl:'aq',maj_if:'fabrication',maj_ic:'conditionnement',maj_nmcl_of:'planification',maj_nmcl_oc:'planification'}
    var COL_LABELS2 = {of:'OF',oc:'OC','if':'IF',ic:'IC',da_pc:'DA PC',da_micro:'DA Micro',ccl:'CCL',aql_fab:'AQL Fab',aql_cond:'AQL Cond',dev:'Déviation',rvp_fab:'RVP Fab',rvp_cond:'RVP Cond',rvp_lcq:'RVP LCQ',maj_if:'MàJ IF',maj_ic:'MàJ IC',maj_nmcl_of:'MàJ Nmcl OF',maj_nmcl_oc:'MàJ Nmcl OC',cloture_sap_of:'Clôt. SAP OF',cloture_sap_oc:'Clôt. SAP OC'}
    var CLOT_SVC = {cloture_sap_of:'fabrication',cloture_sap_oc:'conditionnement'}

    var buildInlineActions = function(lot, col) {
      var actions = []
      var isAdmin = userService.value === 'admin'

      if (col === 'of' || col === 'oc') {
        var etape = col === 'of' ? lot.of_etape : lot.oc_etape
        var orderId = col === 'of' ? lot.of_id : lot.oc_id
        var pendingArCircuit = col === 'of' ? lot.of_pending_ar : lot.oc_pending_ar
        var orderStatut = col === 'of' ? lot.of_statut : lot.oc_statut
        if (etape && orderId && orderStatut !== 'termine') {
          // AR en attente : montrer le bouton AR si c'est le bon service
          if (pendingArCircuit) {
            if (isAdmin || (pendingArCircuit === userService.value && canPerform('accuser_reception_circuit'))) {
              ;(function(oid, col2, arSvc) {
                actions.push({
                  label: '✅ Accuser réception — ' + (SVC_SHORT[arSvc]||arSvc),
                  fn: async function() {
                    var u = await supabase.auth.getUser(); var uid = u.data.user.id; var n = new Date().toISOString()
                    var tbl = col2==='of'?'orders_of':'orders_oc'
                    var res = await supabase.from(tbl).update({pending_ar_service:null,updated_at:n}).eq('id',oid)
                    if (res.error) { alert('Erreur AR : '+res.error.message); return }
                    await supabase.from('lot_events').insert({lot_id:lot.id,event_type:'ar_circuit',description:'Circuit '+col2.toUpperCase()+' — Accusé réception',triggered_by:uid,created_at:n})
                  }
                })
              })(orderId, col, pendingArCircuit)
            }
          } else {
            // Pas d'AR en attente → bouton Valider normal
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
                    var AR_NEXT = {planification:'stock', stock:'aq', aq:'dt', dt:'aq_dap'}
                    var arSvc = AR_NEXT[e] || null
                    await supabase.from('order_validations').insert({order_type:col2,order_id:oid,etape:e,action:'valide',validated_by:uid,validated_at:n})
                    await supabase.from(tbl).update({statut:next?'en_circuit':'termine',etape_circuit:next||e,pending_ar_service:arSvc,updated_at:n}).eq('id',oid)
                    await supabase.from('lots').update({statut_operationnel:col2.toUpperCase()+' — '+nextLabel,updated_at:n}).eq('id',lot.id)
                    var notifSvc = next==='stock'?'stock':next==='aq'?'aq':next==='dt'?'dt':next==='aq_dap'?'aq_dap':next==='production'?(col2==='of'?'fabrication':'conditionnement'):'planification'
                    await createNotification(notifSvc,lot.id,null,'Lot '+lot.numero_lot+' — Circuit '+col2.toUpperCase()+' : '+(ETAPE_LABELS_LONG[e]||e)+' validé','circuit_avance')
                  }
                })
              })(etape, orderId, col, nextEtape)
            }
          }
        }

      } else if (col==='ccl') {
        var cclDoc = null
        if (lot.docs) { for (var ic2=0;ic2<lot.docs.length;ic2++){if(lot.docs[ic2].type_document==='ccl'){cclDoc=lot.docs[ic2];break}} }
        if (cclDoc && cclDoc.is_applicable) {
          ;(function(d) {
            // AR en attente
            if (d.pending_ar_service) {
              if (isAdmin || (d.pending_ar_service === userService.value && canPerform('accuser_reception_document'))) {
                actions.push({label:'✅ Accuser réception — '+(SVC_SHORT[d.pending_ar_service]||d.pending_ar_service), fn: async function(){
                  var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                  await supabase.from('liberation_documents').update({pending_ar_service:null,updated_at:n}).eq('id',d.id)
                  await supabase.from('lot_events').insert({lot_id:lot.id,event_type:'ar_document',description:'CCL — Accusé réception',triggered_by:uid,created_at:n})
                }})
              }
              return
            }
            // AQ transmet
            if (d.statut==='non_emis' && (isAdmin||canPerform('emettre_ccl'))) {
              actions.push({label:'Transmettre CCL au DT', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,pending_ar_service:'dt',updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'emission',from_service:'aq',to_service:'dt',performed_by:uid,performed_at:n})
                await createNotification('dt',lot.id,d.id,'Lot '+lot.numero_lot+' — CCL transmis au DT','document_transmis')
              }})
            }
            // DT libère
            if (d.statut==='emis' && (isAdmin||canPerform('approuver_ccl'))) {
              actions.push({label:'Libérer le lot (CCL)', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:n,pending_ar_service:null,updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'approbation',from_service:'dt',performed_by:uid,performed_at:n})
                await supabase.from('lots').update({statut_sap:'accepte',date_liberation:n,updated_at:n}).eq('id',lot.id)
                await supabase.from('liberation_dossiers').update({statut:'libere',if_approved:true,ic_approved:true,da_pc_approved:true,deviations_closed:true,pieces_complementaires_ok:true,updated_at:n}).eq('lot_id',lot.id)
                await createNotification('aq',lot.id,d.id,'Lot '+lot.numero_lot+' — Lot libéré par le DT','lot_libere')
              }})
            }
            // DT retourne à l'AQ
            if (d.statut==='emis' && (isAdmin||canPerform('retourner_document'))) {
              actions.push({label:"Retourner CCL à l'AQ", needsMotif:true, fn: async function(motif){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'retour_emetteur',pending_ar_service:'aq',updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'retour',from_service:'dt',to_service:'aq',motif_retour:motif,performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,d.id,'Lot '+lot.numero_lot+' — CCL retourné par le DT','document_retourne')
              }})
            }
            // AQ retransmet après retour
            if (d.statut==='retour_emetteur' && (isAdmin||canPerform('emettre_ccl'))) {
              actions.push({label:'Retransmettre CCL au DT', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,pending_ar_service:'dt',updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'rectification',from_service:'aq',to_service:'dt',performed_by:uid,performed_at:n})
                await createNotification('dt',lot.id,d.id,'Lot '+lot.numero_lot+' — CCL retransmis au DT','document_transmis')
              }})
            }
          })(cclDoc)
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
              return
            }
            if (!d.is_applicable) return
            // AR en attente : montrer AR uniquement
            if (d.pending_ar_service) {
              if (isAdmin || (d.pending_ar_service === userService.value && canPerform('accuser_reception_document'))) {
                actions.push({label:'✅ Accuser réception — '+(SVC_SHORT[d.pending_ar_service]||d.pending_ar_service), fn: async function(){
                  var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                  var res=await supabase.from('liberation_documents').update({pending_ar_service:null,updated_at:n}).eq('id',d.id)
                  if(res.error){alert('Erreur AR : '+res.error.message);return}
                  await supabase.from('lot_events').insert({lot_id:lot.id,event_type:'ar_document',description:col3.toUpperCase()+' — Accusé réception',triggered_by:uid,created_at:n})
                }})
              }
              return // bloquer les autres actions tant que AR pas fait
            }
            if (d.statut==='non_emis' && (isAdmin||canPerform('emettre_'+col3))) {
              actions.push({label:'Émettre '+col3.toUpperCase().replace('_',' '), fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,pending_ar_service:'aq',updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'emission',from_service:SVC_MAP[col3]||'',to_service:'aq',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase()+' émis','document_transmis')
              }})
            }
            if ((d.statut==='emis'||d.statut==='verification_aq') && (isAdmin||canPerform('verifier_'+col3))) {
              actions.push({label:'Vérifier AQ → DT', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'approuve_aq',pending_ar_service:'dt',updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'approbation',from_service:'aq',to_service:'dt',performed_by:uid,performed_at:n})
                await createNotification('dt',lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase()+' vérifié AQ → DT','document_transmis')
              }})
            }
            if (d.statut==='approuve_aq' && (isAdmin||canPerform('approuver_'+col3))) {
              actions.push({label:'Approuver DT', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:n,pending_ar_service:null,updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'approbation',from_service:'dt',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase()+' approuvé DT','document_approuve')
                if(SVC_MAP[col3])await createNotification(SVC_MAP[col3],lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase()+' approuvé DT','document_approuve')
              }})
            }
            if (d.statut==='retour_emetteur' && (isAdmin||canPerform('emettre_'+col3))) {
              actions.push({label:'Rectifier / Réémettre', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,pending_ar_service:'aq',updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'rectification',from_service:SVC_MAP[col3]||'',to_service:'aq',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase().replace('_',' ')+' rectifié et réémis','document_transmis')
              }})
            }
            // AQ retourne à l'émetteur (document émis ou en vérification AQ)
            if ((d.statut==='emis'||d.statut==='verification_aq') && (isAdmin||canPerform('retourner_document'))) {
              var emSvc = SVC_MAP[col3] || null
              actions.push({label:'Retourner à l\'émetteur', needsMotif:true, fn: async function(motif){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'retour_emetteur',pending_ar_service:emSvc,updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'retour',from_service:'aq',to_service:emSvc,motif_retour:motif,performed_by:uid,performed_at:n})
                if(emSvc)await createNotification(emSvc,lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase()+' retourné pour rectification','document_retourne')
              }})
            }
            // DT retourne à l'AQ (document approuvé AQ, en attente DT)
            if (d.statut==='approuve_aq' && (isAdmin||canPerform('retourner_document'))) {
              actions.push({label:'Retourner à l\'AQ (DT)', needsMotif:true, fn: async function(motif){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'verification_aq',pending_ar_service:'aq',updated_at:n}).eq('id',d.id)
                await supabase.from('document_movements').insert({document_id:d.id,action:'retour',from_service:'dt',to_service:'aq',motif_retour:motif,performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,d.id,'Lot '+lot.numero_lot+' — '+col3.toUpperCase()+' retourné par DT','document_retourne')
              }})
            }
          })(doc, col)
        }

      } else if (col==='aql_fab'||col==='aql_cond') {
        var aqlType2 = col==='aql_fab'?'fabrication':'conditionnement'
        var aqlPerm = col==='aql_fab'?'demander_aql_fab':'demander_aql_cond'
        var aqlLabel = col==='aql_fab'?'Fabrication':'Conditionnement'
        var reqArFlag = col==='aql_fab'?lot.aql_fab_req_ar:lot.aql_cond_req_ar
        var resArFlag = col==='aql_fab'?lot.aql_fab_res_ar:lot.aql_cond_res_ar
        var aqlIdFlag = col==='aql_fab'?lot.aql_fab_id:lot.aql_cond_id
        // Trouver le dernier AQL de ce type
        var typeAqls = (lot.aqls_raw||[]).filter(function(a){return a.type===aqlType2})
        var latestAql2 = null
        for (var ka=0;ka<typeAqls.length;ka++){if(!latestAql2||new Date(typeAqls[ka].requested_at||0)>new Date(latestAql2.requested_at||0))latestAql2=typeAqls[ka]}
        ;(function(aType, aLabel, latest, reqAr, resAr, aqlId) {
          // AR demande AQL (AQ/LCQ accuse réception de la demande)
          if (reqAr && aqlId) {
            if (isAdmin || (['aq','lcq'].indexOf(userService.value)>=0 && canPerform('accuser_reception_aql_demande'))) {
              actions.push({label:'✅ Accuser réception demande AQL '+aLabel, fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                var res=await supabase.from('aql_inspections').update({request_ar_pending:false}).eq('id',aqlId)
                if(res.error){alert('Erreur AR : '+res.error.message);return}
                await supabase.from('lot_events').insert({lot_id:lot.id,event_type:'ar_aql_demande',description:'AQL '+aLabel+' — Accusé réception demande',triggered_by:uid,created_at:n})
              }})
            }
            return // bloquer autres actions tant que AR demande pas fait
          }
          // AR résultat AQL (Fab/Cond accuse réception du résultat)
          if (resAr && aqlId) {
            if (isAdmin || (['fabrication','conditionnement'].indexOf(userService.value)>=0 && canPerform('accuser_reception_aql_resultat'))) {
              actions.push({label:'✅ Accuser réception résultat AQL '+aLabel, fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                var res=await supabase.from('aql_inspections').update({result_ar_pending:false}).eq('id',aqlId)
                if(res.error){alert('Erreur AR : '+res.error.message);return}
                await supabase.from('lot_events').insert({lot_id:lot.id,event_type:'ar_aql_resultat',description:'AQL '+aLabel+' — Accusé réception résultat',triggered_by:uid,created_at:n})
              }})
            }
            return
          }
          if (!latest) {
            // Aucun AQL → Demander
            if (isAdmin||canPerform(aqlPerm)) {
              actions.push({label:'Demander AQL '+aLabel, fn: async function(){
                var u=await supabase.auth.getUser();var n=new Date().toISOString()
                await supabase.from('aql_inspections').insert({lot_id:lot.id,type:aType,resultat:'en_attente',requested_at:n,request_ar_pending:true})
                await createNotification('aq',lot.id,null,'Lot '+lot.numero_lot+' — AQL '+aLabel+' demandé','aql_demande')
              }})
            }
          } else if (latest.resultat===null||latest.resultat===undefined||latest.resultat==='en_attente') {
            // En attente → Conforme / Non conforme uniquement
            if (isAdmin||canPerform('realiser_aql')) {
              actions.push({label:'AQL Conforme', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('aql_inspections').update({resultat:'conforme',inspected_at:n,inspected_by:uid,request_ar_pending:false,result_ar_pending:true}).eq('id',latest.id)
                await createNotification('planification',lot.id,null,'Lot '+lot.numero_lot+' — AQL '+aLabel+' : conforme','aql_resultat')
              }})
              actions.push({label:'AQL Non conforme', fn: async function(){
                var avis=prompt('Remarque AQ (obligatoire) :')
                if(!avis||!avis.trim()){alert('Remarque obligatoire pour non conforme.');return}
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('aql_inspections').update({resultat:'non_conforme',avis_aq:avis.trim(),inspected_at:n,inspected_by:uid,request_ar_pending:false,result_ar_pending:true}).eq('id',latest.id)
                await createNotification('planification',lot.id,null,'Lot '+lot.numero_lot+' — AQL '+aLabel+' : non conforme','aql_resultat')
              }})
            }
          } else if (latest.resultat==='non_conforme') {
            // Non conforme → Relancer
            if (isAdmin||canPerform(aqlPerm)) {
              actions.push({label:'Relancer AQL '+aLabel, fn: async function(){
                var u=await supabase.auth.getUser();var n=new Date().toISOString()
                await supabase.from('aql_inspections').insert({lot_id:lot.id,type:aType,resultat:'en_attente',requested_at:n,request_ar_pending:true})
                await createNotification('aq',lot.id,null,'Lot '+lot.numero_lot+' — AQL '+aLabel+' relancé','aql_demande')
              }})
            }
          }
          // Conforme → aucune action
        })(aqlType2, aqlLabel, latestAql2, reqArFlag, resArFlag, aqlIdFlag)

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
            // AR en attente pour RVP
            if (rd.pending_ar_service) {
              if (isAdmin || (rd.pending_ar_service === userService.value && canPerform('accuser_reception_document'))) {
                actions.push({label:'✅ Accuser réception — '+(SVC_SHORT[rd.pending_ar_service]||rd.pending_ar_service), fn: async function(){
                  var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                  var res=await supabase.from('liberation_documents').update({pending_ar_service:null,updated_at:n}).eq('id',rd.id)
                  if(res.error){alert('Erreur AR : '+res.error.message);return}
                  await supabase.from('lot_events').insert({lot_id:lot.id,event_type:'ar_document',description:'RVP '+re+' — Accusé réception',triggered_by:uid,created_at:n})
                }})
              }
              return
            }
            if (rd.statut==='non_emis' && (isAdmin||canPerform('emettre_rvp'))) {
              actions.push({label:'Émettre RVP '+re, fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,pending_ar_service:'aq',updated_at:n}).eq('id',rd.id)
                await supabase.from('document_movements').insert({document_id:rd.id,action:'emission',from_service:re,to_service:'aq',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,rd.id,'Lot '+lot.numero_lot+' — RVP '+re+' émis','document_transmis')
              }})
            }
            if ((rd.statut==='emis'||rd.statut==='verification_aq') && (isAdmin||canPerform('verifier_rvp'))) {
              actions.push({label:'Vérifier AQ → DT', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'approuve_aq',pending_ar_service:'dt',updated_at:n}).eq('id',rd.id)
                await supabase.from('document_movements').insert({document_id:rd.id,action:'approbation',from_service:'aq',to_service:'dt',performed_by:uid,performed_at:n})
                await createNotification('dt',lot.id,rd.id,'Lot '+lot.numero_lot+' — RVP '+re+' vérifié AQ → DT','document_transmis')
              }})
            }
            if (rd.statut==='approuve_aq' && (isAdmin||canPerform('approuver_rvp'))) {
              actions.push({label:'Approuver DT', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:n,pending_ar_service:null,updated_at:n}).eq('id',rd.id)
                await supabase.from('document_movements').insert({document_id:rd.id,action:'approbation',from_service:'dt',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,rd.id,'Lot '+lot.numero_lot+' — RVP '+re+' approuvé DT','document_approuve')
                await createNotification(re,lot.id,rd.id,'Lot '+lot.numero_lot+' — RVP '+re+' approuvé DT','document_approuve')
              }})
            }
            if (rd.statut==='retour_emetteur' && (isAdmin||canPerform('emettre_rvp'))) {
              actions.push({label:'Rectifier / Réémettre RVP '+re, fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,pending_ar_service:'aq',updated_at:n}).eq('id',rd.id)
                await supabase.from('document_movements').insert({document_id:rd.id,action:'rectification',from_service:re,to_service:'aq',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,rd.id,'Lot '+lot.numero_lot+' — RVP '+re+' rectifié et réémis','document_transmis')
              }})
            }
            // AQ retourne à l'émetteur RVP
            if ((rd.statut==='emis'||rd.statut==='verification_aq') && (isAdmin||canPerform('retourner_document'))) {
              actions.push({label:'Retourner RVP à l\'émetteur', needsMotif:true, fn: async function(motif){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'retour_emetteur',pending_ar_service:re,updated_at:n}).eq('id',rd.id)
                await supabase.from('document_movements').insert({document_id:rd.id,action:'retour',from_service:'aq',to_service:re,motif_retour:motif,performed_by:uid,performed_at:n})
                await createNotification(re,lot.id,rd.id,'Lot '+lot.numero_lot+' — RVP '+re+' retourné pour rectification','document_retourne')
              }})
            }
            // DT retourne à l'AQ
            if (rd.statut==='approuve_aq' && (isAdmin||canPerform('retourner_document'))) {
              actions.push({label:'Retourner RVP à l\'AQ (DT)', needsMotif:true, fn: async function(motif){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'verification_aq',pending_ar_service:'aq',updated_at:n}).eq('id',rd.id)
                await supabase.from('document_movements').insert({document_id:rd.id,action:'retour',from_service:'dt',to_service:'aq',motif_retour:motif,performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,rd.id,'Lot '+lot.numero_lot+' — RVP '+re+' retourné par DT','document_retourne')
              }})
            }
          })(rvpDoc, rvpEmetteur)
        }

      } else if (col==='maj_if'||col==='maj_ic'||col==='maj_nmcl_of'||col==='maj_nmcl_oc') {
        // MàJ documents — même circuit que RVP (declare → emit → verify → approve)
        var majType = col // type_document in DB
        var majEmitPermMap = {maj_if:'emettre_maj_if',maj_ic:'emettre_maj_ic',maj_nmcl_of:'emettre_maj_nmcl_of',maj_nmcl_oc:'emettre_maj_nmcl_oc'}
        var majEmitPerm = majEmitPermMap[col]||'emettre_maj_doc'
        var majDoc = null
        if (lot.docs) { for(var mm=0;mm<lot.docs.length;mm++){if(lot.docs[mm].type_document===majType){majDoc=lot.docs[mm];break}} }
        if (!majDoc) {
          ;(function(mt,svc,ep) {
            if (isAdmin||canPerform(ep)) {
              actions.push({label:'Déclarer '+COL_LABELS2[mt], fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').insert({lot_id:lot.id,type_document:mt,statut:'non_emis',is_applicable:true,is_required:false,service_emetteur:svc,created_at:n,updated_at:n})
                await supabase.from('lot_events').insert({lot_id:lot.id,event_type:'maj_doc_declare',description:COL_LABELS2[mt]+' déclaré',triggered_by:uid,created_at:n})
                await createNotification(svc,lot.id,null,'Lot '+lot.numero_lot+' — '+COL_LABELS2[mt]+' à émettre','document_transmis')
              }})
            }
          })(majType, SVC_MAP[majType]||'planification', majEmitPerm)
        } else {
          ;(function(md, mt, svc, ep) {
            if (md.statut==='non_emis' && (isAdmin||canPerform(ep))) {
              actions.push({label:'Émettre '+COL_LABELS2[mt], fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,updated_at:n}).eq('id',md.id)
                await supabase.from('document_movements').insert({document_id:md.id,action:'emission',from_service:svc,to_service:'aq',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,md.id,'Lot '+lot.numero_lot+' — '+COL_LABELS2[mt]+' émis','document_transmis')
              }})
            }
            if ((md.statut==='emis'||md.statut==='verification_aq') && (isAdmin||canPerform('verifier_maj_doc'))) {
              actions.push({label:'Vérifier AQ → DT', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'approuve_aq',updated_at:n}).eq('id',md.id)
                await supabase.from('document_movements').insert({document_id:md.id,action:'approbation',from_service:'aq',to_service:'dt',performed_by:uid,performed_at:n})
                await createNotification('dt',lot.id,md.id,'Lot '+lot.numero_lot+' — '+COL_LABELS2[mt]+' vérifié AQ → DT','document_transmis')
              }})
            }
            if (md.statut==='approuve_aq' && (isAdmin||canPerform('approuver_maj_doc'))) {
              actions.push({label:'Approuver DT', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:n,updated_at:n}).eq('id',md.id)
                await supabase.from('document_movements').insert({document_id:md.id,action:'approbation',from_service:'dt',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,md.id,'Lot '+lot.numero_lot+' — '+COL_LABELS2[mt]+' approuvé DT','document_approuve')
                if(svc)await createNotification(svc,lot.id,md.id,'Lot '+lot.numero_lot+' — '+COL_LABELS2[mt]+' approuvé DT','document_approuve')
              }})
            }
            if (md.statut==='retour_emetteur' && (isAdmin||canPerform(ep))) {
              actions.push({label:'Rectifier / Réémettre', fn: async function(){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,updated_at:n}).eq('id',md.id)
                await supabase.from('document_movements').insert({document_id:md.id,action:'rectification',from_service:svc,to_service:'aq',performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,md.id,'Lot '+lot.numero_lot+' — '+COL_LABELS2[mt]+' rectifié et réémis','document_transmis')
              }})
            }
            // AQ retourne à l'émetteur
            if ((md.statut==='emis'||md.statut==='verification_aq') && (isAdmin||canPerform('retourner_document'))) {
              actions.push({label:'Retourner à l\'émetteur', needsMotif:true, fn: async function(motif){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'retour_emetteur',updated_at:n}).eq('id',md.id)
                await supabase.from('document_movements').insert({document_id:md.id,action:'retour',from_service:'aq',to_service:svc,motif_retour:motif,performed_by:uid,performed_at:n})
                if(svc)await createNotification(svc,lot.id,md.id,'Lot '+lot.numero_lot+' — '+COL_LABELS2[mt]+' retourné','document_retourne')
              }})
            }
            // DT retourne à l'AQ
            if (md.statut==='approuve_aq' && (isAdmin||canPerform('retourner_document'))) {
              actions.push({label:'Retourner à l\'AQ (DT)', needsMotif:true, fn: async function(motif){
                var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
                await supabase.from('liberation_documents').update({statut:'verification_aq',updated_at:n}).eq('id',md.id)
                await supabase.from('document_movements').insert({document_id:md.id,action:'retour',from_service:'dt',to_service:'aq',motif_retour:motif,performed_by:uid,performed_at:n})
                await createNotification('aq',lot.id,md.id,'Lot '+lot.numero_lot+' — '+COL_LABELS2[mt]+' retourné par DT','document_retourne')
              }})
            }
          })(majDoc, majType, SVC_MAP[majType]||'planification', majEmitPerm)
        }

      } else if (col==='cloture_sap_of'||col==='cloture_sap_oc') {
        // Clôture SAP — Émettre → Planif valide → Dem. clôture → Confirmer
        var clotType = col
        var clotSvc = CLOT_SVC[col]
        var clotDoc = null
        if (lot.docs) { for(var cc2=0;cc2<lot.docs.length;cc2++){if(lot.docs[cc2].type_document===clotType){clotDoc=lot.docs[cc2];break}} }
        var clotEmitPerm = col==='cloture_sap_of'?'emettre_cloture_sap_of':'emettre_cloture_sap_oc'
        var clotValidPerm = col==='cloture_sap_of'?'valider_cloture_sap_of':'valider_cloture_sap_oc'
        var clotDemPerm = col==='cloture_sap_of'?'demander_cloture_sap_of':'demander_cloture_sap_oc'
        var clotConfPerm = col==='cloture_sap_of'?'confirmer_cloture_sap_of':'confirmer_cloture_sap_oc'
        ;(function(cd, ct, cs, ep, vp, dp, cp) {
          if ((!cd || cd.statut==='non_emis') && (isAdmin||canPerform(ep))) {
            actions.push({label:'Émettre', fn: async function(){
              var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
              if (!cd) {
                var ins=await supabase.from('liberation_documents').insert({lot_id:lot.id,type_document:ct,statut:'emis',is_applicable:true,is_required:false,service_emetteur:cs,emitted_at:n,emitted_by:uid,created_at:n,updated_at:n}).select().single()
                if(ins.data)await supabase.from('document_movements').insert({document_id:ins.data.id,action:'emission',from_service:cs,to_service:'planification',performed_by:uid,performed_at:n})
              } else {
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:n,emitted_by:uid,updated_at:n}).eq('id',cd.id)
                await supabase.from('document_movements').insert({document_id:cd.id,action:'emission',from_service:cs,to_service:'planification',performed_by:uid,performed_at:n})
              }
              await createNotification('planification',lot.id,null,'Lot '+lot.numero_lot+' — '+COL_LABELS2[ct]+' émis, en attente validation','document_transmis')
            }})
          }
          if (cd && cd.statut==='emis' && (isAdmin||canPerform(vp))) {
            actions.push({label:'Valider (Planif.)', fn: async function(){
              var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
              await supabase.from('liberation_documents').update({statut:'valide_planif',updated_at:n}).eq('id',cd.id)
              await supabase.from('document_movements').insert({document_id:cd.id,action:'validation',from_service:'planification',to_service:cs,performed_by:uid,performed_at:n})
              await createNotification(cs,lot.id,cd.id,'Lot '+lot.numero_lot+' — '+COL_LABELS2[ct]+' validé, demande de clôture possible','document_transmis')
            }})
          }
          if (cd && cd.statut==='valide_planif' && (isAdmin||canPerform(dp))) {
            actions.push({label:'Demander clôture', fn: async function(){
              var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
              await supabase.from('liberation_documents').update({statut:'cloture_demandee',updated_at:n}).eq('id',cd.id)
              await supabase.from('document_movements').insert({document_id:cd.id,action:'cloture',from_service:cs,to_service:'planification',performed_by:uid,performed_at:n})
              await createNotification('planification',lot.id,cd.id,'Lot '+lot.numero_lot+' — '+COL_LABELS2[ct]+' clôture demandée','document_approuve')
            }})
          }
          if (cd && cd.statut==='cloture_demandee' && (isAdmin||canPerform(cp))) {
            actions.push({label:'Confirmer clôture', fn: async function(){
              var u=await supabase.auth.getUser();var uid=u.data.user.id;var n=new Date().toISOString()
              await supabase.from('liberation_documents').update({statut:'cloture',updated_at:n}).eq('id',cd.id)
              await supabase.from('document_movements').insert({document_id:cd.id,action:'cloture_confirmee',from_service:'planification',performed_by:uid,performed_at:n})
              await createNotification(cs,lot.id,cd.id,'Lot '+lot.numero_lot+' — '+COL_LABELS2[ct]+' clôturé','document_approuve')
            }})
          }
        })(clotDoc, clotType, clotSvc, clotEmitPerm, clotValidPerm, clotDemPerm, clotConfPerm)
      }
      return actions
    }

    var openInlineMenu = function(event, lot, col) {
      var actions = buildInlineActions(lot, col)
      var rect = event.currentTarget.getBoundingClientRect()
      var top = rect.bottom + 2, left = rect.left
      if (left + 240 > window.innerWidth) left = window.innerWidth - 250
      inlineMenu.value = { top: top, left: left, colLabel: COL_LABELS2[col]||col, actions: actions,
        lotRef: lot, colRef: col, historyOpen: false, historyData: [], historyLoading: false,
        pendingAction: null, motifText: '' }
    }

    var executeInline = async function(action) {
      if (action.needsMotif) {
        inlineMenu.value.pendingAction = action
        inlineMenu.value.motifText = ''
        return
      }
      inlineMenu.value = null
      await action.fn(null)
      if (!action.noReload) await load()
    }

    var confirmInlineMotif = async function() {
      if (!inlineMenu.value || !inlineMenu.value.pendingAction) return
      var action = inlineMenu.value.pendingAction
      var motif = (inlineMenu.value.motifText || '').trim() || null
      inlineMenu.value = null
      await action.fn(motif)
      if (!action.noReload) await load()
    }

    var fmtHistDate = function(iso) {
      if (!iso) return '—'
      var d = new Date(iso)
      return d.toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',year:'2-digit'})+' '+d.toLocaleTimeString('fr-FR',{hour:'2-digit',minute:'2-digit'})
    }

    var DOC_COLS = ['if','ic','da_pc','da_micro','rvp_fab','rvp_cond','rvp_lcq','maj_if','maj_ic','maj_nmcl_of','maj_nmcl_oc','cloture_sap_of','cloture_sap_oc']
    var RVP_SVC = {rvp_fab:'fabrication',rvp_cond:'conditionnement',rvp_lcq:'lcq'}
    var DOC_ACT_LABELS = {emission:'Émission',approbation:'Approbation',retour:'Retour',rectification:'Rectification',validation:'Validation',cloture:'Dem. clôture',cloture_confirmee:'Clôture confirmée'}

    var loadInlineHistory = async function() {
      if (!inlineMenu.value) return
      var lot = inlineMenu.value.lotRef, col = inlineMenu.value.colRef
      inlineMenu.value.historyLoading = true
      inlineMenu.value.historyData = []
      var rows = []

      // Helper : convertit un lot_event en ligne d'historique
      var mapEv = function(e) {
        return {label:e.description||e.event_type, who:e.profiles?e.profiles.prenom+' '+e.profiles.nom:'—', at:fmtHistDate(e.created_at), _ts:e.created_at}
      }

      if (col === 'of' || col === 'oc') {
        var orderId = col === 'of' ? lot.of_id : lot.oc_id
        if (orderId) {
          var r = await supabase.from('order_validations')
            .select('etape,validated_at,profiles(prenom,nom)')
            .eq('order_type', col).eq('order_id', orderId)
            .order('validated_at', {ascending:false}).limit(20)
          var el = {planification:'Mise en circuit',stock:'Valid. Stock',aq:'Valid. AQ',dt:'Autor. DT',aq_dap:'Remise AQ DAP',production:'Accusé récp.'}
          rows = (r.data||[]).map(function(v){
            return {label:el[v.etape]||v.etape, who:v.profiles?v.profiles.prenom+' '+v.profiles.nom:'—', at:fmtHistDate(v.validated_at), _ts:v.validated_at}
          })
        }
        // Accusés de réception circuit
        var arCirc = await supabase.from('lot_events')
          .select('description,created_at,profiles!triggered_by(prenom,nom)')
          .eq('lot_id', lot.id).eq('event_type', 'ar_circuit')
          .ilike('description', '%'+col.toUpperCase()+'%')
          .order('created_at', {ascending:false}).limit(10)
        rows = rows.concat((arCirc.data||[]).map(mapEv))

      } else if (col === 'aql_fab' || col === 'aql_cond') {
        var aqlType = col === 'aql_fab' ? 'fabrication' : 'conditionnement'
        // Demandes et résultats AQL
        var r2 = await supabase.from('aql_inspections')
          .select('resultat,requested_at,inspected_at,profiles!inspected_by(prenom,nom)')
          .eq('lot_id', lot.id).eq('type', aqlType)
          .order('requested_at', {ascending:false}).limit(10)
        rows = (r2.data||[]).map(function(a){
          var lbl = a.resultat==='conforme'?'AQL Conforme':a.resultat==='non_conforme'?'AQL Non conforme':'Demande AQL'
          var ts = a.inspected_at||a.requested_at
          return {label:lbl, who:a.profiles?a.profiles.prenom+' '+a.profiles.nom:'—', at:fmtHistDate(ts), _ts:ts}
        })
        // AR demande / résultat + événements lot_events AQL
        var arAql = await supabase.from('lot_events')
          .select('description,created_at,profiles!triggered_by(prenom,nom)')
          .eq('lot_id', lot.id)
          .in('event_type', ['ar_aql_demande','ar_aql_resultat','aql_demande','aql_resultat'])
          .ilike('description', '%'+aqlType+'%')
          .order('created_at', {ascending:false}).limit(15)
        rows = rows.concat((arAql.data||[]).map(mapEv))

      } else if (DOC_COLS.indexOf(col) >= 0) {
        var docObj = null
        if (col.startsWith('rvp_')) {
          docObj = (lot.docs||[]).find(function(d){return d.type_document==='rvp'&&d.service_emetteur===RVP_SVC[col]})
        } else {
          docObj = (lot.docs||[]).find(function(d){return d.type_document===col})
        }
        if (docObj) {
          // Mouvements documentaires (flux principal)
          var r3 = await supabase.from('document_movements')
            .select('action,from_service,to_service,motif_retour,performed_at,profiles(prenom,nom)')
            .eq('document_id', docObj.id)
            .order('performed_at', {ascending:false}).limit(20)
          rows = (r3.data||[]).map(function(m){
            var svc = m.to_service ? (m.from_service||'')+'→'+(m.to_service||'') : (m.from_service||'')
            var lbl = (DOC_ACT_LABELS[m.action]||m.action)+(svc?' ('+svc+')':'')
            if(m.motif_retour)lbl+=' — '+m.motif_retour
            return {label:lbl, who:m.profiles?m.profiles.prenom+' '+m.profiles.nom:'—', at:fmtHistDate(m.performed_at), _ts:m.performed_at}
          })
        }
        // AR document depuis lot_events
        var arDocKey = col.startsWith('rvp_') ? 'RVP '+(RVP_SVC[col]||'') : col.toUpperCase().replace(/_/g,' ')
        var arDoc = await supabase.from('lot_events')
          .select('description,created_at,profiles!triggered_by(prenom,nom)')
          .eq('lot_id', lot.id).eq('event_type', 'ar_document')
          .ilike('description', '%'+arDocKey+'%')
          .order('created_at', {ascending:false}).limit(10)
        rows = rows.concat((arDoc.data||[]).map(mapEv))
      }

      // Trier par date décroissante
      rows.sort(function(a,b){ return (a._ts||'') > (b._ts||'') ? -1 : 1 })
      inlineMenu.value.historyData = rows
      inlineMenu.value.historyLoading = false
    }

    var toggleInlineHistory = async function() {
      if (!inlineMenu.value) return
      inlineMenu.value.historyOpen = !inlineMenu.value.historyOpen
      if (inlineMenu.value.historyOpen && !inlineMenu.value.historyData.length && !inlineMenu.value.historyLoading) {
        await loadInlineHistory()
      }
    }

    var SVC_LABELS = {planification:'Planification',stock:'Stock',aq:'AQ',aq_dap:'AQ DAP',dt:'DT',fabrication:'Fabrication',conditionnement:'Conditionnement',lcq:'LCQ',admin:'Admin'}
    var fmtDevDate = function(iso) {
      if (!iso) return '—'
      var d = new Date(iso)
      return d.toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',year:'numeric'}) + ' ' + d.toLocaleTimeString('fr-FR',{hour:'2-digit',minute:'2-digit'})
    }

    var openDevPopup = function(event, lot) {
      var rect = event.currentTarget.getBoundingClientRect()
      var top = rect.bottom + 2, left = rect.left
      if (left + 340 > window.innerWidth) left = window.innerWidth - 350
      devPopup.value = {
        lotId: lot.id, lotNum: lot.numero_lot, top: top, left: left,
        bloquante: false, numeroDn: '', obs: '',
        devList: (lot.dev_list || []).map(function(d) {
          var p = d.profiles
          return {
            id: d.id, statut: d.statut, bloquante: d.bloquante,
            numero_dn: d.numero_dn || '', description: d.description || '',
            declared_at: d.declared_at, declared_service: d.declared_service,
            declarer_nom: p ? ((p.prenom||'') + ' ' + (p.nom||'')).trim() : '',
            editNumeroDn: d.numero_dn || '',
            editObs: d.description || ''
          }
        }),
        devBloquanteOpen: lot.dev_bloquante_open || 0,
        devNonBloquanteOpen: lot.dev_non_bloquante_open || 0,
        devClosed: lot.dev_closed || 0,
        expandedId: null
      }
    }

    var saveDevField = async function(dev) {
      var res = await supabase.from('deviations').update({
        numero_dn: dev.editNumeroDn || null,
        description: dev.editObs || ''
      }).eq('id', dev.id)
      if (res.error) { alert('Erreur sauvegarde : ' + res.error.message); return }
      // Mettre à jour l'objet local du popup
      dev.numero_dn = dev.editNumeroDn
      dev.description = dev.editObs
      // Mettre à jour le cache lots pour que le popup reste cohérent si rouvert
      if (devPopup.value) {
        var cachedLot = lots.value.find(function(l){ return l.id === devPopup.value.lotId })
        if (cachedLot && cachedLot.dev_list) {
          var cachedDev = cachedLot.dev_list.find(function(x){ return x.id === dev.id })
          if (cachedDev) { cachedDev.numero_dn = dev.editNumeroDn; cachedDev.description = dev.editObs }
        }
      }
    }

    var markBloquanteInPopup = async function(devId) {
      var res = await supabase.from('deviations').update({bloquante: true}).eq('id', devId)
      if (res.error) { alert('Erreur : ' + res.error.message); return }
      if (devPopup.value) {
        var d = devPopup.value.devList.find(function(x){ return x.id === devId })
        if (d) {
          d.bloquante = true
          devPopup.value.devNonBloquanteOpen = Math.max(0, devPopup.value.devNonBloquanteOpen - 1)
          devPopup.value.devBloquanteOpen = devPopup.value.devBloquanteOpen + 1
        }
        var cachedLot = lots.value.find(function(l){ return l.id === devPopup.value.lotId })
        if (cachedLot && cachedLot.dev_list) {
          var cachedDev = cachedLot.dev_list.find(function(x){ return x.id === devId })
          if (cachedDev) cachedDev.bloquante = true
        }
      }
    }

    var closeDevInPopup = async function(devId) {
      var u = await supabase.auth.getUser(); var uid = u.data.user.id; var n = new Date().toISOString()
      var res = await supabase.from('deviations').update({statut:'cloturee', closed_at:n, closed_by:uid}).eq('id', devId)
      if (res.error) { alert('Erreur clôture : ' + res.error.message); return }
      devPopup.value = null
      await load()
    }

    var confirmDevPopup = async function() {
      if (!devPopup.value) return
      var u = await supabase.auth.getUser(); var uid = u.data.user.id; var n = new Date().toISOString()
      var insRes = await supabase.from('deviations').insert({
        lot_id: devPopup.value.lotId, type: 'deviation', statut: 'ouverte',
        description: devPopup.value.obs || '',
        bloquante: devPopup.value.bloquante || false,
        numero_dn: devPopup.value.numeroDn || null,
        declared_service: userService.value || null,
        declared_by: uid, declared_at: n
      })
      if (insRes.error) { alert('Erreur déclaration : ' + insRes.error.message); return }
      await supabase.from('liberation_dossiers').update({deviations_closed:false,updated_at:n}).eq('lot_id',devPopup.value.lotId)
      await supabase.from('lot_events').insert({lot_id:devPopup.value.lotId,event_type:'deviation_declaree',description:'Déviation déclarée'+(devPopup.value.bloquante?' (BLOQUANTE)':''),triggered_by:uid,created_at:n})
      await createNotification('aq',devPopup.value.lotId,null,'Lot '+devPopup.value.lotNum+' — Déviation déclarée'+(devPopup.value.bloquante?' (BLOQUANTE)':''),'deviation_declaree')
      devPopup.value = null
      await load()
    }
    // ──────────────────────────────────────────────────────────────────

    // ── Date picker planification ──────────────────────────────────────
    var datePicker = ref(null)
    var PLAN_LABELS = {
      plan_lcq:'Lib. LCQ',
      plan_aq:'Lib. AQ',
      plan_dt1:'Lib. DT1',
      plan_dt2:'Lib. DT2'
    }
    var PLAN_DB_FIELD = {
      plan_lcq:'date_lcq_cible',
      plan_aq:'date_aq_cible',
      plan_dt1:'date_dt_cible',
      plan_dt2:'date_dt_revisee'
    }

    var openDatePicker = function(event, lot, col) {
      var rawVal = lot[col+'_raw'] || ''
      if (typeof rawVal === 'string' && rawVal.length > 10) rawVal = rawVal.split('T')[0]
      var rect = event.currentTarget.getBoundingClientRect()
      var top = rect.bottom + 2, left = rect.left
      if (left + 200 > window.innerWidth) left = window.innerWidth - 210
      datePicker.value = { lotId: lot.id, col: col, label: PLAN_LABELS[col]||col, top: top, left: left, value: rawVal }
      chargeCount.value = null
      planHistory.value = []
      if (rawVal) loadCharge()
      loadPlanHistory(lot.id, col)
    }

    var chargeCount = ref(null)
    var chargeLoading = ref(false)
    var planHistory = ref([])
    var planHistLoading = ref(false)

    var loadPlanHistory = async function(lotId, col) {
      planHistLoading.value = true
      var res = await supabase.from('lot_events')
        .select('description, created_at')
        .eq('lot_id', lotId)
        .eq('event_type', 'planning_updated')
        .ilike('description', col + '|%')
        .order('created_at', { ascending: false })
        .limit(8)
      planHistory.value = (res.data || []).map(function(e) {
        var parts = e.description.split('|')
        var d = new Date(e.created_at)
        return {
          date: parts[1] || '—',
          user: parts[2] || '—',
          at: d.toLocaleDateString('fr-FR', {day:'2-digit',month:'2-digit',year:'numeric'}) + ' ' + d.toLocaleTimeString('fr-FR', {hour:'2-digit',minute:'2-digit'})
        }
      })
      planHistLoading.value = false
    }

var loadCharge = async function() {
      if (!datePicker.value || !datePicker.value.value) { chargeCount.value = null; return }
      var dbField = PLAN_DB_FIELD[datePicker.value.col]
      if (!dbField) { chargeCount.value = null; return }
      chargeLoading.value = true
      var dateStr = datePicker.value.value // 'YYYY-MM-DD'
      // Comptage côté serveur sur le champ exact en cours d'édition
      // Indépendant des filtres/recherche actifs côté client, sans limite de lignes
      var res = await supabase.from('lot_planning')
        .select('lot_id', { count: 'exact', head: true })
        .neq('lot_id', datePicker.value.lotId)
        .eq(dbField, dateStr)
      chargeCount.value = res.count || 0
      chargeLoading.value = false
    }

    var savePlanning = async function() {
      if (!datePicker.value) return
      var u = await supabase.auth.getUser()
      var uid = u.data.user.id
      var userEmail = u.data.user.email || uid
      var col = datePicker.value.col
      var dbField = PLAN_DB_FIELD[col]
      if (!dbField) { datePicker.value = null; return }
      var newDate = datePicker.value.value || null
      var lotId = datePicker.value.lotId
      await supabase.from('lot_planning').upsert(
        { lot_id: lotId, [dbField]: newDate, updated_at: new Date().toISOString(), updated_by: uid },
        { onConflict: 'lot_id' }
      )
      await supabase.from('lot_events').insert({
        lot_id: lotId,
        event_type: 'planning_updated',
        description: col + '|' + (newDate || 'supprimé') + '|' + userEmail,
        triggered_by: uid,
        created_at: new Date().toISOString()
      })
      datePicker.value = null
      chargeCount.value = null
      planHistory.value = []
      await load()
    }
    // ──────────────────────────────────────────────────────────────────

    var closeAll = function() { activeDropdown.value = null; inlineMenu.value = null; showColPanel.value = false; showStatutPanel.value = false; showActionPanel.value = false; actionSearch.value = ''; if(datePicker.value) datePicker.value = null; if(devPopup.value) devPopup.value = null }

    var filteredLots = computed(function(){
      var result = lots.value
      if(hiddenStatuts.value.length>0){result=result.filter(function(l){return !hiddenStatuts.value.includes(l.statut_filter)})}
      var cf=columnFilters.value,cfk=Object.keys(cf)
      if(cfk.length>0){result=result.filter(function(l){return cfk.every(function(k){return l[k]===cf[k]})})}
      if(sortCol.value){
        var col=sortCol.value,dir=sortDir.value
        // Convertit dd/mm/yyyy → timestamp pour tri chronologique
        var parseFrDate=function(s){if(!s||s==='—')return 0;var p=s.split('/');return p.length===3?new Date(p[2],p[1]-1,p[0]).getTime():0}
        result=result.slice().sort(function(a,b){
          var va=a[col]||'',vb=b[col]||''
          // Tri numérique pour le numéro de lot
          if(col==='numero_lot'){var na=parseInt(va)||0,nb=parseInt(vb)||0;return dir==='asc'?na-nb:nb-na}
          // Tri chronologique pour les colonnes de dates (format dd/mm/yyyy)
          if(col==='date_fmt'||col==='date_lib'||col==='plan_dt1'||col==='plan_dt2'||col==='plan_aq'||col==='plan_lcq'){
            var da=parseFrDate(String(va)),db=parseFrDate(String(vb))
            if(da!==db)return dir==='asc'?da-db:db-da
            return 0
          }
          if(typeof va==='string')va=va.toLowerCase()
          if(typeof vb==='string')vb=vb.toLowerCase()
          if(va<vb)return dir==='asc'?-1:1;if(va>vb)return dir==='asc'?1:-1;return 0
        })
      }
      return result
    })

    // pagedLots découpe filteredLots (déjà trié + filtré sur TOUS les lots) → tri global garanti
    var totalPages = computed(function(){ return Math.max(1, Math.ceil(filteredLots.value.length / TABLE_PAGE_SIZE)) })
    var pagedLots = computed(function(){ var s = tablePage.value * TABLE_PAGE_SIZE; return filteredLots.value.slice(s, s + TABLE_PAGE_SIZE) })

    var sortBy = function(col){if(sortCol.value===col){sortDir.value=sortDir.value==='asc'?'desc':'asc'}else{sortCol.value=col;sortDir.value='asc'}}
    var sortIcon = function(col){if(sortCol.value!==col)return'↕';return sortDir.value==='asc'?'↑':'↓'}
    var goToLot = function(id){var query={};if(route.query.q)query.q=route.query.q;router.push({path:'/lots/'+id,query:query})}

    var exportCols=[
      {key:'numero_lot',label:'N° Lot',width:12},{key:'prod_desc',label:'Produit',width:28},{key:'prod_code',label:'Code',width:12},
      {key:'statut_label',label:'Statut',width:14},{key:'phase',label:'Phase',width:26},{key:'of_label',label:'OF',width:10},{key:'oc_label',label:'OC',width:10},
      {key:'aql_fab_label',label:'AQL Fab',width:10},{key:'aql_cond_label',label:'AQL Cond',width:10},
      {key:'if_label',label:'IF',width:10},{key:'ic_label',label:'IC',width:10},
      {key:'dapc_label',label:'DA PC',width:10},{key:'damicro_label',label:'DA Micro',width:10},
      {key:'rvp_fab_label',label:'RVP Fab',width:10},{key:'rvp_cond_label',label:'RVP Cond',width:10},{key:'rvp_lcq_label',label:'RVP LCQ',width:10},
      {key:'maj_if_label',label:'MàJ IF',width:10},{key:'maj_ic_label',label:'MàJ IC',width:10},{key:'maj_nmcl_of_label',label:'MàJ N.OF',width:10},{key:'maj_nmcl_oc_label',label:'MàJ N.OC',width:10},
      {key:'clot_of_label',label:'Clôt.OF',width:10},{key:'clot_oc_label',label:'Clôt.OC',width:10},
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
      ccl_transmettre:'CCL — Transmettre au DT',ccl_liberer:'CCL — Libérer le lot (DT)',ccl_retourner:"CCL — Retourner à l'AQ (DT)",ccl_reemettre:'CCL — Retransmettre au DT (AQ)',
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
      maj_if_declarer:'MàJ IF — Déclarer',maj_if_emettre:'MàJ IF — Émettre',maj_if_verifier:'MàJ IF — Vérifier',maj_if_approuver:'MàJ IF — Approuver',
      maj_ic_declarer:'MàJ IC — Déclarer',maj_ic_emettre:'MàJ IC — Émettre',maj_ic_verifier:'MàJ IC — Vérifier',maj_ic_approuver:'MàJ IC — Approuver',
      maj_nmcl_of_declarer:'MàJ N. OF — Déclarer',maj_nmcl_of_emettre:'MàJ N. OF — Émettre',maj_nmcl_of_verifier:'MàJ N. OF — Vérifier',maj_nmcl_of_approuver:'MàJ N. OF — Approuver',
      maj_nmcl_oc_declarer:'MàJ N. OC — Déclarer',maj_nmcl_oc_emettre:'MàJ N. OC — Émettre',maj_nmcl_oc_verifier:'MàJ N. OC — Vérifier',maj_nmcl_oc_approuver:'MàJ N. OC — Approuver',
      clot_of_declarer:'Clôt. OF — Déclarer',clot_of_emettre:'Clôt. OF — Dem. validation',clot_of_valider:'Clôt. OF — Valider (Planif.)',clot_of_cloture:'Clôt. OF — Dem. clôture',clot_of_confirmer:'Clôt. OF — Confirmer clôture',
      clot_oc_declarer:'Clôt. OC — Déclarer',clot_oc_emettre:'Clôt. OC — Dem. validation',clot_oc_valider:'Clôt. OC — Valider (Planif.)',clot_oc_cloture:'Clôt. OC — Dem. clôture',clot_oc_confirmer:'Clôt. OC — Confirmer clôture',
      dev_declarer:'Déviation — Déclarer',dev_bloquer:'Déviation — Marquer bloquante',dev_cloture:'Déviation — Clôturer',
      plan_lcq:'Lib. LCQ',plan_aq:'Lib. AQ',plan_dt1:'Lib. DT1',plan_dt2:'Lib. DT2',
      ar_circuit_of:'AR — Circuit OF',ar_circuit_oc:'AR — Circuit OC',
      ar_doc_if:'AR — IF',ar_doc_ic:'AR — IC',ar_doc_da_pc:'AR — DA PC',ar_doc_da_micro:'AR — DA Micro',ar_doc_ccl:'AR — CCL',
      ar_doc_rvp_fab:'AR — RVP Fab',ar_doc_rvp_cond:'AR — RVP Cond',ar_doc_rvp_lcq:'AR — RVP LCQ',
      ar_aql_fab_demande:'AR — Dem. AQL Fab',ar_aql_cond_demande:'AR — Dem. AQL Cond',
      ar_aql_fab_resultat:'AR — Rés. AQL Fab',ar_aql_cond_resultat:'AR — Rés. AQL Cond',
    }
    var actionLabel = computed(function(){return actionLabels[actionType.value]||''})
    var canExecute = computed(function(){
      if(!selected.value.length||!actionType.value)return false
      if(actionType.value.startsWith('plan_')&&!bulkDate.value)return false
      return true
    })

    var isSelected = function(id){return selected.value.indexOf(id)>=0}
    var toggleLot = function(id){var idx=selected.value.indexOf(id);if(idx>=0)selected.value.splice(idx,1);else selected.value.push(id)}
    var allVisibleChecked = computed(function(){return pagedLots.value.length>0&&pagedLots.value.every(function(l){return isSelected(l.id)})})
    var someVisibleChecked = computed(function(){return pagedLots.value.some(function(l){return isSelected(l.id)})})
    var toggleAll = function(){
      if(allVisibleChecked.value){pagedLots.value.forEach(function(l){var i=selected.value.indexOf(l.id);if(i>=0)selected.value.splice(i,1)})}
      else{pagedLots.value.forEach(function(l){if(!isSelected(l.id))selected.value.push(l.id)})}
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
      var bulkAqlAvis = ''

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
            var AR_NEXT_BULK={planification:'stock',stock:'aq',aq:'dt',dt:'aq_dap'}
            var bulkArSvc=AR_NEXT_BULK[etape]||null
            await supabase.from('order_validations').insert({order_type:orderType,order_id:orderId,etape:etape,action:'valide',validated_by:userId,validated_at:now})
            await supabase.from(tbl).update({statut:nextEtape?'en_circuit':'termine',etape_circuit:nextEtape||etape,pending_ar_service:bulkArSvc,updated_at:now}).eq('id',orderId)
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
            var bulkSvcMap={'if':'fabrication',ic:'conditionnement',da_pc:'lcq',da_micro:'lcq'}
            if(isApprouver){
              await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:now,pending_ar_service:null,updated_at:now}).eq('id',doc2.id)
              var fldMap={'if':'if_approved',ic:'ic_approved',da_pc:'da_pc_approved',da_micro:'da_micro_approved'}
              var fld=fldMap[docType];if(fld)await supabase.from('liberation_dossiers').update({[fld]:true,updated_at:now}).eq('lot_id',lotId)
              await supabase.from('document_movements').insert({document_id:doc2.id,action:'approbation',from_service:'dt',performed_by:userId,performed_at:now})
            } else if(isVerifier){
              await supabase.from('liberation_documents').update({statut:'approuve_aq',pending_ar_service:'dt',updated_at:now}).eq('id',doc2.id)
              await supabase.from('document_movements').insert({document_id:doc2.id,action:'approbation',from_service:'aq',to_service:'dt',performed_by:userId,performed_at:now})
            } else if(isRetourEmetteur){
              var retSvc=bulkSvcMap[docType]||''
              await supabase.from('liberation_documents').update({statut:'retour_emetteur',pending_ar_service:retSvc||null,updated_at:now}).eq('id',doc2.id)
              await supabase.from('document_movements').insert({document_id:doc2.id,action:'retour',from_service:'aq',to_service:retSvc,motif_retour:'Retour en masse',performed_by:userId,performed_at:now})
            } else if(isRetourAQ){
              await supabase.from('liberation_documents').update({statut:'verification_aq',pending_ar_service:'aq',updated_at:now}).eq('id',doc2.id)
              await supabase.from('document_movements').insert({document_id:doc2.id,action:'retour',from_service:'dt',to_service:'aq',motif_retour:'Retour DT en masse',performed_by:userId,performed_at:now})
            } else {
              if(docType==='da_micro'){
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,is_applicable:true,is_required:true,pending_ar_service:'aq',updated_at:now}).eq('id',doc2.id)
                await supabase.from('liberation_dossiers').update({da_micro_applicable:true,updated_at:now}).eq('lot_id',lotId)
              } else {
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,pending_ar_service:'aq',updated_at:now}).eq('id',doc2.id)
              }
              await supabase.from('document_movements').insert({document_id:doc2.id,action:'emission',from_service:bulkSvcMap[docType]||'',to_service:'aq',performed_by:userId,performed_at:now})
            }
            await supabase.from('lot_events').insert({lot_id:lotId,event_type:'document_masse',description:docType.toUpperCase()+' — '+docAction+' (masse)',triggered_by:userId,created_at:now})
            var typeLabel=docType.toUpperCase().replace('_',' ')
            if(!isApprouver&&!isVerifier&&!isRetourEmetteur&&!isRetourAQ){await createNotification('aq',lotId,doc2.id,'Lot '+lot.numero_lot+' — '+typeLabel+' émis','document_transmis')}
            else if(isVerifier){await createNotification('dt',lotId,doc2.id,'Lot '+lot.numero_lot+' — '+typeLabel+' vérifié AQ → DT','document_transmis')}
            else if(isRetourEmetteur){var s4={'if':'fabrication',ic:'conditionnement',da_pc:'lcq',da_micro:'lcq'};if(s4[docType])await createNotification(s4[docType],lotId,doc2.id,'Lot '+lot.numero_lot+' — '+typeLabel+' retourné','document_retourne')}
            else if(isRetourAQ){await createNotification('aq',lotId,doc2.id,'Lot '+lot.numero_lot+' — '+typeLabel+' retourné par DT','document_retourne')}
            else if(isApprouver){await createNotification('aq',lotId,doc2.id,'Lot '+lot.numero_lot+' — '+typeLabel+' approuvé DT','document_approuve')}
            result.ok++

          } else if (action.startsWith('ccl_')) {
            var cclOp=action.replace('ccl_','')
            var cclD=null;if(lot.docs){for(var cc4=0;cc4<lot.docs.length;cc4++){if(lot.docs[cc4].type_document==='ccl'){cclD=lot.docs[cc4];break}}}
            if(!cclD){result.errors.push(lot.numero_lot+': CCL non trouvé');result.fail++;continue}
            if(cclOp==='transmettre'){
              await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,pending_ar_service:'dt',updated_at:now}).eq('id',cclD.id)
              await supabase.from('document_movements').insert({document_id:cclD.id,action:'emission',from_service:'aq',to_service:'dt',performed_by:userId,performed_at:now})
              await createNotification('dt',lotId,cclD.id,'Lot '+lot.numero_lot+' — CCL transmis au DT','document_transmis')
            } else if(cclOp==='liberer'){
              await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:now,pending_ar_service:null,updated_at:now}).eq('id',cclD.id)
              await supabase.from('document_movements').insert({document_id:cclD.id,action:'approbation',from_service:'dt',performed_by:userId,performed_at:now})
              await supabase.from('lots').update({statut_sap:'accepte',date_liberation:now,updated_at:now}).eq('id',lotId)
              await supabase.from('liberation_dossiers').update({statut:'libere',if_approved:true,ic_approved:true,da_pc_approved:true,deviations_closed:true,pieces_complementaires_ok:true,updated_at:now}).eq('lot_id',lotId)
              await createNotification('aq',lotId,cclD.id,'Lot '+lot.numero_lot+' — Lot libéré par le DT','lot_libere')
            } else if(cclOp==='retourner'){
              await supabase.from('liberation_documents').update({statut:'retour_emetteur',pending_ar_service:'aq',updated_at:now}).eq('id',cclD.id)
              await supabase.from('document_movements').insert({document_id:cclD.id,action:'retour',from_service:'dt',to_service:'aq',motif_retour:'Retour en masse',performed_by:userId,performed_at:now})
              await createNotification('aq',lotId,cclD.id,'Lot '+lot.numero_lot+' — CCL retourné par le DT','document_retourne')
            } else if(cclOp==='reemettre'){
              await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,pending_ar_service:'dt',updated_at:now}).eq('id',cclD.id)
              await supabase.from('document_movements').insert({document_id:cclD.id,action:'rectification',from_service:'aq',to_service:'dt',performed_by:userId,performed_at:now})
              await createNotification('dt',lotId,cclD.id,'Lot '+lot.numero_lot+' — CCL retransmis au DT','document_transmis')
            } else {result.errors.push(lot.numero_lot+': action CCL inconnue');result.fail++;continue}
            await supabase.from('lot_events').insert({lot_id:lotId,event_type:'ccl_masse',description:'CCL — '+cclOp+' (masse)',triggered_by:userId,created_at:now})
            result.ok++

          } else if (action.startsWith('aql_')) {
            var aqlParts=action.split('_'),aqlSvc=aqlParts[1],aqlOp=aqlParts.slice(2).join('_')
            var aqlTypeVal=aqlSvc==='fab'?'fabrication':'conditionnement'
            var aqlSvcLabel=aqlSvc==='fab'?'Fabrication':'Conditionnement'
            if(aqlOp==='demander'||aqlOp==='relancer'){
              await supabase.from('aql_inspections').insert({lot_id:lotId,type:aqlTypeVal,resultat:'en_attente',requested_at:now,request_ar_pending:true})
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'aql_demande',description:'AQL '+aqlSvcLabel+' — '+(aqlOp==='relancer'?'relancé':'demandé')+' (masse)',triggered_by:userId,created_at:now})
              await createNotification('aq',lotId,null,'Lot '+lot.numero_lot+' — AQL '+aqlSvcLabel+(aqlOp==='relancer'?' relancé':' demandé'),'aql_demande')
              result.ok++
            } else if(aqlOp==='conforme'||aqlOp==='non_conforme'){
              var avisBulk=''
              if(aqlOp==='non_conforme'){
                if(!bulkAqlAvis){bulkAqlAvis=prompt('Remarque AQ pour tous les lots non conformes (obligatoire) :');if(!bulkAqlAvis||!bulkAqlAvis.trim()){alert('Remarque obligatoire pour non conforme.');return}}
                avisBulk=bulkAqlAvis.trim()
              }
              var aqlRes=await supabase.from('aql_inspections').select('id').eq('lot_id',lotId).eq('type',aqlTypeVal).or('resultat.is.null,resultat.eq.en_attente').order('requested_at',{ascending:false}).limit(1)
              var latestAql=aqlRes.data&&aqlRes.data[0]
              if(!latestAql){result.errors.push(lot.numero_lot+': pas d\'AQL '+aqlSvcLabel+' en attente');result.fail++;continue}
              await supabase.from('aql_inspections').update({resultat:aqlOp,avis_aq:avisBulk,inspected_at:now,inspected_by:userId,request_ar_pending:false,result_ar_pending:true}).eq('id',latestAql.id)
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
              await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,pending_ar_service:'aq',updated_at:now}).eq('id',rvpDoc2.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc2.id,action:'emission',from_service:rvpEmetteur2,to_service:'aq',performed_by:userId,performed_at:now})
              await createNotification('aq',lotId,rvpDoc2.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur2+' émis','document_transmis')
            } else if(rvpOp==='verifier'){
              await supabase.from('liberation_documents').update({statut:'approuve_aq',pending_ar_service:'dt',updated_at:now}).eq('id',rvpDoc2.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc2.id,action:'approbation',from_service:'aq',to_service:'dt',performed_by:userId,performed_at:now})
              await createNotification('dt',lotId,rvpDoc2.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur2+' vérifié','document_transmis')
            } else if(rvpOp==='approuver'){
              await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:now,pending_ar_service:null,updated_at:now}).eq('id',rvpDoc2.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc2.id,action:'approbation',from_service:'dt',performed_by:userId,performed_at:now})
              await createNotification('aq',lotId,rvpDoc2.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur2+' approuvé DT','document_approuve')
              await createNotification(rvpEmetteur2,lotId,rvpDoc2.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur2+' approuvé DT','document_approuve')
            } else if(rvpOp==='retour_emetteur'){
              await supabase.from('liberation_documents').update({statut:'retour_emetteur',pending_ar_service:rvpEmetteur2||null,updated_at:now}).eq('id',rvpDoc2.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc2.id,action:'retour',from_service:'aq',to_service:rvpEmetteur2,motif_retour:'Retour en masse',performed_by:userId,performed_at:now})
              await createNotification(rvpEmetteur2,lotId,rvpDoc2.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur2+' retourné','document_retourne')
            } else if(rvpOp==='retour_aq'){
              await supabase.from('liberation_documents').update({statut:'verification_aq',pending_ar_service:'aq',updated_at:now}).eq('id',rvpDoc2.id)
              await supabase.from('document_movements').insert({document_id:rvpDoc2.id,action:'retour',from_service:'dt',to_service:'aq',motif_retour:'Retour DT en masse',performed_by:userId,performed_at:now})
              await createNotification('aq',lotId,rvpDoc2.id,'Lot '+lot.numero_lot+' — RVP '+rvpEmetteur2+' retourné par DT','document_retourne')
            } else {result.errors.push(lot.numero_lot+': action RVP inconnue');result.fail++;continue}
            await supabase.from('lot_events').insert({lot_id:lotId,event_type:'rvp_masse',description:'RVP '+rvpEmetteur2+' — '+rvpOp.replace(/_/g,' ')+' (masse)',triggered_by:userId,created_at:now})
            result.ok++

          } else if (action.startsWith('dev_')) {
            var devOp=action.replace('dev_','')
            if(devOp==='declarer'){
              var isBl=bulkDevBloquante.value; var dn=bulkDevNumeroDn.value||null; var obs=bulkDevObs.value||''
              await supabase.from('deviations').insert({lot_id:lotId,type:'deviation',statut:'ouverte',description:obs,bloquante:isBl,numero_dn:dn,declared_service:userService.value||null,declared_by:userId,declared_at:now})
              await supabase.from('liberation_dossiers').update({deviations_closed:false,updated_at:now}).eq('lot_id',lotId)
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'deviation_declaree',description:'Déviation déclarée (masse)'+(isBl?' (BLOQUANTE)':''),triggered_by:userId,created_at:now})
              await createNotification('aq',lotId,null,'Lot '+lot.numero_lot+' — Déviation déclarée'+(isBl?' (BLOQUANTE)':''),'deviation_declaree')
              result.ok++
            } else if(devOp==='bloquer'){
              var openNblDevs=await supabase.from('deviations').select('id').eq('lot_id',lotId).in('statut',['ouverte','en_cours']).eq('bloquante',false)
              if(!openNblDevs.data||!openNblDevs.data.length){result.errors.push(lot.numero_lot+': aucune déviation non bloquante ouverte');result.fail++;continue}
              for(var kb=0;kb<openNblDevs.data.length;kb++){await supabase.from('deviations').update({bloquante:true,updated_at:now}).eq('id',openNblDevs.data[kb].id)}
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'deviation_bloquante',description:openNblDevs.data.length+' déviation(s) marquée(s) bloquante (masse)',triggered_by:userId,created_at:now})
              result.ok++
            } else if(devOp==='cloture'){
              var openDevs=await supabase.from('deviations').select('id').eq('lot_id',lotId).in('statut',['ouverte','en_cours'])
              if(!openDevs.data||!openDevs.data.length){result.errors.push(lot.numero_lot+': aucune déviation ouverte');result.fail++;continue}
              for(var kk=0;kk<openDevs.data.length;kk++){await supabase.from('deviations').update({statut:'cloturee',closed_at:now,closed_by:userId,updated_at:now}).eq('id',openDevs.data[kk].id)}
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'deviation_cloturee',description:openDevs.data.length+' déviation(s) clôturée(s) (masse)',triggered_by:userId,created_at:now})
              result.ok++
            } else {result.errors.push(lot.numero_lot+': action déviation inconnue');result.fail++}

          } else if (action.startsWith('maj_')) {
            // MàJ documents bulk: maj_if_declarer, maj_if_emettre, maj_if_verifier, maj_if_approuver, etc.
            var majParts=action.match(/^(maj_(?:if|ic|nmcl_of|nmcl_oc))_(\w+)$/)
            if(!majParts){result.errors.push(lot.numero_lot+': action MàJ inconnue');result.fail++;continue}
            var majDocType=majParts[1],majOp=majParts[2]
            var majSvcMap2={maj_if:'fabrication',maj_ic:'conditionnement',maj_nmcl_of:'planification',maj_nmcl_oc:'planification'}
            var majSvc2=majSvcMap2[majDocType]||'planification'
            if(majOp==='declarer'){
              await supabase.from('liberation_documents').insert({lot_id:lotId,type_document:majDocType,statut:'non_emis',is_applicable:true,is_required:false,service_emetteur:majSvc2,created_at:now,updated_at:now})
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'maj_doc_declare',description:majDocType.toUpperCase()+' déclaré (masse)',triggered_by:userId,created_at:now})
              result.ok++
            } else if(majOp==='emettre'){
              var majD=null;if(lot.docs){for(var mm2=0;mm2<lot.docs.length;mm2++){if(lot.docs[mm2].type_document===majDocType){majD=lot.docs[mm2];break}}}
              if(!majD){result.errors.push(lot.numero_lot+': '+majDocType+' non déclaré');result.fail++;continue}
              await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,updated_at:now}).eq('id',majD.id)
              await supabase.from('document_movements').insert({document_id:majD.id,action:'emission',from_service:majSvc2,to_service:'aq',performed_by:userId,performed_at:now})
              await createNotification('aq',lotId,majD.id,'Lot '+lot.numero_lot+' — '+majDocType.toUpperCase()+' émis','document_transmis')
              result.ok++
            } else if(majOp==='verifier'){
              var majD2=null;if(lot.docs){for(var mm3=0;mm3<lot.docs.length;mm3++){if(lot.docs[mm3].type_document===majDocType){majD2=lot.docs[mm3];break}}}
              if(!majD2){result.errors.push(lot.numero_lot+': '+majDocType+' non trouvé');result.fail++;continue}
              await supabase.from('liberation_documents').update({statut:'approuve_aq',updated_at:now}).eq('id',majD2.id)
              await supabase.from('document_movements').insert({document_id:majD2.id,action:'approbation',from_service:'aq',to_service:'dt',performed_by:userId,performed_at:now})
              await createNotification('dt',lotId,majD2.id,'Lot '+lot.numero_lot+' — '+majDocType.toUpperCase()+' vérifié AQ → DT','document_transmis')
              result.ok++
            } else if(majOp==='approuver'){
              var majD3=null;if(lot.docs){for(var mm4=0;mm4<lot.docs.length;mm4++){if(lot.docs[mm4].type_document===majDocType){majD3=lot.docs[mm4];break}}}
              if(!majD3){result.errors.push(lot.numero_lot+': '+majDocType+' non trouvé');result.fail++;continue}
              await supabase.from('liberation_documents').update({statut:'approuve_dt',approved_at:now,updated_at:now}).eq('id',majD3.id)
              await supabase.from('document_movements').insert({document_id:majD3.id,action:'approbation',from_service:'dt',performed_by:userId,performed_at:now})
              await createNotification('aq',lotId,majD3.id,'Lot '+lot.numero_lot+' — '+majDocType.toUpperCase()+' approuvé DT','document_approuve')
              result.ok++
            } else {result.errors.push(lot.numero_lot+': action MàJ inconnue');result.fail++}

          } else if (action.startsWith('clot_')) {
            // Clôture SAP bulk: clot_of_emettre, clot_of_valider, clot_of_cloture, clot_of_confirmer
            var clotParts=action.match(/^clot_(of|oc)_(\w+)$/)
            if(!clotParts){result.errors.push(lot.numero_lot+': action Clôture inconnue');result.fail++;continue}
            var clotDocType='cloture_sap_'+clotParts[1],clotOp=clotParts[2]
            var clotSvc2=clotParts[1]==='of'?'fabrication':'conditionnement'
            var clotD=null;if(lot.docs){for(var cc3=0;cc3<lot.docs.length;cc3++){if(lot.docs[cc3].type_document===clotDocType){clotD=lot.docs[cc3];break}}}
            if(clotOp==='emettre'){
              if(!clotD){
                // Créer + émettre en une seule étape
                var insRes=await supabase.from('liberation_documents').insert({lot_id:lotId,type_document:clotDocType,statut:'emis',is_applicable:true,is_required:false,service_emetteur:clotSvc2,emitted_at:now,emitted_by:userId,created_at:now,updated_at:now}).select().single()
                if(insRes.data){
                  await supabase.from('document_movements').insert({document_id:insRes.data.id,action:'emission',from_service:clotSvc2,to_service:'planification',performed_by:userId,performed_at:now})
                  await createNotification('planification',lotId,insRes.data.id,'Lot '+lot.numero_lot+' — '+clotDocType+' émis','document_transmis')
                }
              } else {
                await supabase.from('liberation_documents').update({statut:'emis',emitted_at:now,emitted_by:userId,updated_at:now}).eq('id',clotD.id)
                await supabase.from('document_movements').insert({document_id:clotD.id,action:'emission',from_service:clotSvc2,to_service:'planification',performed_by:userId,performed_at:now})
                await createNotification('planification',lotId,clotD.id,'Lot '+lot.numero_lot+' — '+clotDocType+' émis','document_transmis')
              }
              result.ok++
            } else {
              if(!clotD){result.errors.push(lot.numero_lot+': '+clotDocType+' non trouvé');result.fail++;continue}
              if(clotOp==='valider'){
                await supabase.from('liberation_documents').update({statut:'valide_planif',updated_at:now}).eq('id',clotD.id)
                await supabase.from('document_movements').insert({document_id:clotD.id,action:'validation',from_service:'planification',to_service:clotSvc2,performed_by:userId,performed_at:now})
                await createNotification(clotSvc2,lotId,clotD.id,'Lot '+lot.numero_lot+' — '+clotDocType+' validé Planif.','document_transmis')
                result.ok++
              } else if(clotOp==='cloture'){
                await supabase.from('liberation_documents').update({statut:'cloture_demandee',updated_at:now}).eq('id',clotD.id)
                await supabase.from('document_movements').insert({document_id:clotD.id,action:'cloture',from_service:clotSvc2,to_service:'planification',performed_by:userId,performed_at:now})
                await createNotification('planification',lotId,clotD.id,'Lot '+lot.numero_lot+' — '+clotDocType+' clôture demandée','document_approuve')
                result.ok++
              } else if(clotOp==='confirmer'){
                await supabase.from('liberation_documents').update({statut:'cloture',updated_at:now}).eq('id',clotD.id)
                await supabase.from('document_movements').insert({document_id:clotD.id,action:'cloture_confirmee',from_service:'planification',performed_by:userId,performed_at:now})
                await createNotification(clotSvc2,lotId,clotD.id,'Lot '+lot.numero_lot+' — '+clotDocType+' clôturé','document_approuve')
                result.ok++
              } else {result.errors.push(lot.numero_lot+': action Clôture inconnue');result.fail++}
            }

          } else if (action.startsWith('ar_')) {
            // Accusés de réception en masse
            if(action==='ar_circuit_of'||action==='ar_circuit_oc'){
              var arOType=action==='ar_circuit_of'?'of':'oc'
              var arOId=arOType==='of'?lot.of_id:lot.oc_id
              var arTbl=arOType==='of'?'orders_of':'orders_oc'
              if(!arOId){result.errors.push(lot.numero_lot+': pas d\'ordre '+arOType.toUpperCase());result.fail++;continue}
              var arORes=await supabase.from(arTbl).update({pending_ar_service:null,updated_at:now}).eq('id',arOId)
              if(arORes.error){result.errors.push(lot.numero_lot+': '+arORes.error.message);result.fail++;continue}
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'ar_circuit',description:'AR circuit '+arOType.toUpperCase()+' (masse)',triggered_by:userId,created_at:now})
              result.ok++
            } else if(action.startsWith('ar_doc_')){
              var arDocTypeMap={ar_doc_if:'if',ar_doc_ic:'ic',ar_doc_da_pc:'da_pc',ar_doc_da_micro:'da_micro',ar_doc_rvp_fab:'rvp',ar_doc_rvp_cond:'rvp',ar_doc_rvp_lcq:'rvp'}
              var arDocType=arDocTypeMap[action]||null
              if(!arDocType){result.errors.push(lot.numero_lot+': type doc AR inconnu');result.fail++;continue}
              var arDoc=null
              if(action==='ar_doc_rvp_fab'||action==='ar_doc_rvp_cond'||action==='ar_doc_rvp_lcq'){
                var arRvpSvcMap={ar_doc_rvp_fab:'fabrication',ar_doc_rvp_cond:'conditionnement',ar_doc_rvp_lcq:'lcq'}
                var arRvpSvc=arRvpSvcMap[action]
                if(lot.docs){for(var arj=0;arj<lot.docs.length;arj++){if(lot.docs[arj].type_document==='rvp'&&lot.docs[arj].service_emetteur===arRvpSvc){arDoc=lot.docs[arj];break}}}
              } else {
                if(lot.docs){for(var arj2=0;arj2<lot.docs.length;arj2++){if(lot.docs[arj2].type_document===arDocType){arDoc=lot.docs[arj2];break}}}
              }
              if(!arDoc){result.errors.push(lot.numero_lot+': document '+arDocType+' non trouvé');result.fail++;continue}
              var arDocRes=await supabase.from('liberation_documents').update({pending_ar_service:null,updated_at:now}).eq('id',arDoc.id)
              if(arDocRes.error){result.errors.push(lot.numero_lot+': '+arDocRes.error.message);result.fail++;continue}
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'ar_document',description:'AR '+arDocType.toUpperCase()+' (masse)',triggered_by:userId,created_at:now})
              result.ok++
            } else if(action==='ar_aql_fab_demande'||action==='ar_aql_cond_demande'){
              var arAqlType=action==='ar_aql_fab_demande'?'fabrication':'conditionnement'
              var arAqlR=await supabase.from('aql_inspections').select('id').eq('lot_id',lotId).eq('type',arAqlType).eq('request_ar_pending',true).order('requested_at',{ascending:false}).limit(1)
              var arAqlRow=arAqlR.data&&arAqlR.data[0]
              if(!arAqlRow){result.errors.push(lot.numero_lot+': pas de demande AQL en attente AR');result.fail++;continue}
              var arAqlRes=await supabase.from('aql_inspections').update({request_ar_pending:false,updated_at:now}).eq('id',arAqlRow.id)
              if(arAqlRes.error){result.errors.push(lot.numero_lot+': '+arAqlRes.error.message);result.fail++;continue}
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'ar_aql_demande',description:'AR demande AQL '+arAqlType+' (masse)',triggered_by:userId,created_at:now})
              result.ok++
            } else if(action==='ar_aql_fab_resultat'||action==='ar_aql_cond_resultat'){
              var arAqlResType=action==='ar_aql_fab_resultat'?'fabrication':'conditionnement'
              var arAqlR2=await supabase.from('aql_inspections').select('id').eq('lot_id',lotId).eq('type',arAqlResType).eq('result_ar_pending',true).order('requested_at',{ascending:false}).limit(1)
              var arAqlRow2=arAqlR2.data&&arAqlR2.data[0]
              if(!arAqlRow2){result.errors.push(lot.numero_lot+': pas de résultat AQL en attente AR');result.fail++;continue}
              var arAqlRes2=await supabase.from('aql_inspections').update({result_ar_pending:false,updated_at:now}).eq('id',arAqlRow2.id)
              if(arAqlRes2.error){result.errors.push(lot.numero_lot+': '+arAqlRes2.error.message);result.fail++;continue}
              await supabase.from('lot_events').insert({lot_id:lotId,event_type:'ar_aql_resultat',description:'AR résultat AQL '+arAqlResType+' (masse)',triggered_by:userId,created_at:now})
              result.ok++
            } else {result.errors.push(lot.numero_lot+': action AR inconnue');result.fail++}

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
      load()
      document.addEventListener('click', closeAll)
    })
    onUnmounted(function(){document.removeEventListener('click', closeAll)})
    watch(function(){return route.query},load,{deep:true})
    watch([hiddenStatuts, columnFilters, sortCol, sortDir], function(){ tablePage.value = 0 }, {deep:true})

    return{lots,total,lotsLoading,hiddenStatuts,toggleStatutVisibility,showStatutPanel,showDates,filteredLots,pagedLots,tablePage,totalPages,filterOptions,
      sortBy,sortIcon,goToLot,doExportExcel,doExportPDF,
      selected,actionType,showConfirm,executing,progress,execResult,bulkDate,
      actionLabel,canExecute,allVisibleChecked,someVisibleChecked,
      isSelected,toggleLot,toggleAll,getLotNum,executeAction,
      actionGroups,filteredActionGroups,selectAction,showActionPanel,actionSearch,expandedActionGroups,toggleActionGroup,userService,
      columnFilters,activeDropdown,ddPos,openDropdown,getColumnValues,setColumnFilter,clearColumnFilters,removeColumnFilter,hasColumnFilters,
      visibleCols:tableCols,showColPanel,colDefs,isColVisible,toggleCol,resetCols,moveColUp,moveColDown,CC,
      colDragIdx,colDragOverIdx,onColDragStart,onColDragOver,onColDrop,onColDragEnd,
      inlineMenu,openInlineMenu,executeInline,confirmInlineMotif,toggleInlineHistory,closeAll,
      devPopup,openDevPopup,confirmDevPopup,closeDevInPopup,saveDevField,markBloquanteInPopup,canPerform,SVC_LABELS,fmtDevDate,
      bulkDevBloquante,bulkDevNumeroDn,bulkDevObs,
      datePicker,dpInput,openDatePicker,savePlanning,getPlanClass,getPhaseClass,
      chargeCount,chargeLoading,loadCharge,
      planHistory,planHistLoading}
  }
}
</script>
<style scoped>
.ph{display:flex;align-items:baseline;justify-content:space-between;padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:2px;flex-wrap:wrap;gap:8px}
.pt{font-size:18px;font-weight:800;letter-spacing:.3px;color:#1a1a2e}.pc{font-size:11px;color:#999;font-family:'SF Mono',monospace}.pc-sub{font-size:10px;color:#bbb;margin-left:2px}
.ph-right{display:flex;align-items:center;gap:6px;flex-wrap:wrap}
.btn-exp{font-size:11px;padding:4px 10px;border:1px solid #ddd;border-radius:3px;background:#fff;cursor:pointer;color:#666;font-family:inherit}.btn-exp:hover{background:#f5f5f5}
.btn-toggle{font-size:11px;padding:4px 10px;border:1px solid #7c3aed;border-radius:3px;background:#ede9fe;cursor:pointer;color:#6d28d9;font-family:inherit}.btn-toggle:hover{background:#ddd6fe}
.statut-panel-wrap{position:relative}
.statut-panel{position:absolute;top:calc(100% + 4px);right:0;background:#fff;border:1px solid #ddd;border-radius:4px;box-shadow:0 6px 20px rgba(0,0,0,.12);z-index:300;padding:10px;min-width:160px}
.statut-item{display:flex;align-items:center;gap:7px;font-size:12px;color:#333;padding:5px 4px;border-radius:3px;cursor:pointer;user-select:none;white-space:nowrap}
.statut-item:hover{background:#f5f5f5}
.statut-item input{cursor:pointer;accent-color:#7c3aed;flex-shrink:0}
.statut-dot{width:8px;height:8px;border-radius:50%;flex-shrink:0}
.statut-lbl{flex:1}
.btn-cols{font-size:11px;padding:4px 10px;border:1px solid #ddd;border-radius:3px;background:#fff;cursor:pointer;color:#666;font-family:inherit;white-space:nowrap}.btn-cols:hover{background:#f5f5f5}.btn-cols-on{border-color:#7c3aed;background:#ede9fe;color:#6d28d9}
.col-panel-wrap{position:relative}
.col-panel{position:absolute;top:calc(100% + 4px);right:0;background:#fff;border:1px solid #ddd;border-radius:4px;box-shadow:0 6px 20px rgba(0,0,0,.12);z-index:300;padding:10px;min-width:180px}
.col-panel-title{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.8px;color:#999;margin-bottom:8px;padding-bottom:6px;border-bottom:1px solid #f0f0f0}
.col-item{display:flex;align-items:center;gap:6px;font-size:12px;color:#333;padding:3px 4px;border-radius:3px;white-space:nowrap;transition:background .1s}
.col-item input{cursor:pointer;accent-color:#7c3aed}
.col-item-label{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis}
.col-drag-handle{cursor:grab;color:#ccc;font-size:14px;line-height:1;user-select:none;padding:0 1px;flex-shrink:0}.col-drag-handle:active{cursor:grabbing}
.col-item-dragging{opacity:.35;background:#f5f5f5}
.col-item-over{background:#ede9fe;border-color:#7c3aed}
.col-reset{margin-top:8px;width:100%;padding:5px;font-size:11px;border:1px solid #ddd;border-radius:3px;background:#fafafa;cursor:pointer;color:#666}.col-reset:hover{background:#f0f0f0}
.lots-loading{text-align:center;padding:40px 0;color:#999;font-size:13px;letter-spacing:.3px}
.pag-bar{display:flex;align-items:center;gap:12px;padding:8px 12px;border-top:1px solid #e8e8e8;background:#fafafa;position:sticky;bottom:0}
.pag-btn{padding:3px 12px;border:1px solid #ddd;border-radius:3px;background:#fff;cursor:pointer;font-size:11px;font-family:inherit}.pag-btn:hover:not(:disabled){background:#f0f0f0}.pag-btn:disabled{opacity:.35;cursor:not-allowed}
.pag-info{font-size:11px;color:#777;flex:1;text-align:center}
.filters{display:flex;gap:4px;padding:8px 0;flex-wrap:wrap}
.fbtn{display:flex;align-items:center;gap:4px;padding:5px 10px;min-height:32px;font-size:11px;border:1px solid #e8e8e8;border-radius:3px;background:#fff;cursor:pointer;color:#666;font-family:inherit;transition:.15s}
.fbtn:hover{border-color:#ccc}.fbtn.active{border-color:#7c3aed;background:#ede9fe;color:#6d28d9}
.fdot{width:6px;height:6px;border-radius:50%;flex-shrink:0}
.table-wrap{overflow-x:auto;overflow-y:auto;-webkit-overflow-scrolling:touch;max-height:calc(100vh - 150px)}
.tb{width:100%;border-collapse:collapse;font-size:11px;white-space:nowrap}.tb th{font-size:9px;text-transform:uppercase;color:#7c3aed;font-weight:700;padding:5px 4px;text-align:left;border-bottom:1px solid #ede9fe;position:sticky;top:0;background:#f5f3ff;z-index:1}
.sortable{cursor:pointer;user-select:none}.sortable:hover{color:#7c3aed}.sort-arrow{font-size:10px;color:#ccc}
.tb td{padding:6px 4px;border-bottom:1px solid #f5f5f5}.tb tr{cursor:pointer}.tb tr:hover td{background:#fafafa}
.bold{font-weight:500}.mono{font-family:'SF Mono',monospace;font-size:10px}.dim{color:#999;font-size:10px}
.td-prod{max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:11px}
.code{font-size:9px;color:#999;font-family:'SF Mono',monospace;margin-left:3px}
.sp{font-size:9px;padding:2px 5px;border-radius:2px;font-weight:500;white-space:nowrap}
.s-quarantaine{background:#FAEEDA;color:#854F0B}.s-accepte{background:#EAF3DE;color:#3B6D11}.s-sous_investigation{background:#FCEBEB;color:#A32D2D}.s-vide{background:#f5f5f5;color:#999}.s-enprod{background:#ede9fe;color:#6d28d9}.s-enprep{background:#F0EBFE;color:#5B3CC4}.s-refuse{background:#e8e8e8;color:#333}
.sp-phase{font-size:9px;padding:2px 5px;border-radius:2px;font-weight:500;white-space:nowrap;max-width:160px;overflow:hidden;text-overflow:ellipsis;display:inline-block}
.phase-planifie{background:#f5f5f5;color:#999}.phase-fab{background:#EEE8FF;color:#5B3CC4}.phase-attente-cond{background:#FFF3CD;color:#856404}.phase-cond{background:#E0F7F4;color:#00695C}.phase-attente-pf{background:#FFF3CD;color:#856404}.phase-libere{background:#EAF3DE;color:#3B6D11}.phase-cloture{background:#e8e8e8;color:#333}
.doc-pip{font-size:9px;padding:2px 4px;border-radius:2px;font-weight:500}
.dc-ok{background:#EAF3DE;color:#3B6D11}.dc-ret{background:#FCEBEB;color:#A32D2D}.dc-wait{background:#f5f5f5;color:#999}.dc-prog{background:#ede9fe;color:#6d28d9}.dc-na{background:transparent;color:#ccc}.dc-date{background:#fafafa;color:#666;font-family:'SF Mono',monospace}
.pip-done-t{background:#EAF3DE;color:#3B6D11}.pip-prog-t{background:#FAEEDA;color:#854F0B}
.dev-badge{font-size:9px;padding:2px 5px;border-radius:2px;font-weight:500}.dev-open{background:#FCEBEB;color:#A32D2D}.dev-closed{background:#EAF3DE;color:#3B6D11}
/* Cellule cliquable pour actions inline */
.td-action{cursor:pointer;position:relative}.td-action:hover span{filter:brightness(.9)}
/* Planning dates */
.td-plan{text-align:center;min-width:70px}
.plan-date{font-size:9px;font-family:'SF Mono',monospace;padding:2px 5px;border-radius:2px;background:#f5f3ff;color:#7c3aed;font-weight:500;cursor:pointer}
.plan-revised{background:#fff3cd;color:#856404}
.plan-empty{font-size:14px;color:#ddd;cursor:pointer;line-height:1}.td-plan:hover .plan-empty{color:#7c3aed}
.plan-warn{background:#fff3cd !important;color:#856404 !important}
.plan-urgent{background:#FAEEDA !important;color:#854F0B !important}
.plan-crit{background:#FCEBEB !important;color:#A32D2D !important}
.empty{text-align:center;padding:40px;color:#999}
/* column filter chips */
.cf-bar{display:flex;align-items:center;gap:6px;padding:5px 0;flex-wrap:wrap;font-size:11px;border-bottom:1px solid #e8e8e8}
.cf-label{color:#999;font-weight:500;white-space:nowrap}
.cf-chip{display:flex;align-items:center;gap:4px;background:#ede9fe;color:#6d28d9;padding:2px 8px;border-radius:10px;font-size:11px}
.cf-chip strong{font-weight:600}
.cf-rm{background:none;border:none;cursor:pointer;color:#7c3aed;font-size:11px;padding:0 0 0 2px;line-height:1}
.cf-clear{font-size:11px;padding:2px 10px;border:1px solid #E24B4A;border-radius:10px;background:#fff;color:#E24B4A;cursor:pointer;white-space:nowrap}.cf-clear:hover{background:#FCEBEB}
/* column header inner wrapper — NE JAMAIS mettre display:flex sur <th> directement */
.th-i{display:flex;align-items:center;gap:2px;white-space:nowrap}
.th-txt{display:flex;align-items:center;gap:2px;flex:1}
.th-txt.sortable{cursor:pointer}.th-txt.sortable:hover{color:#7c3aed}
.th-f{background:none;border:none;cursor:pointer;color:#ccc;font-size:11px;padding:0 2px;line-height:1;border-radius:2px;flex-shrink:0;transition:.1s}.th-f:hover{color:#7c3aed;background:#f0f0f0}
.th-f-on{color:#7c3aed !important;background:#ede9fe}
/* column dropdown */
.col-dd{position:fixed;background:#fff;border:1px solid #ddd;border-radius:4px;box-shadow:0 6px 20px rgba(0,0,0,.12);z-index:300;min-width:160px;max-width:260px;max-height:280px;overflow-y:auto;font-size:12px}
.col-dd-item{padding:7px 12px;cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;transition:.1s}
.col-dd-item:hover{background:#f5f5f5}.col-dd-all{color:#999;font-style:italic;border-bottom:1px solid #f0f0f0}.col-dd-on{background:#ede9fe;color:#6d28d9;font-weight:500}
/* Inline action menu */
.inline-menu{position:fixed;background:#fff;border:1px solid #ddd;border-radius:4px;box-shadow:0 6px 20px rgba(0,0,0,.15);z-index:400;min-width:180px;max-width:260px;overflow:hidden}
.inline-menu-title{font-size:9px;font-weight:600;text-transform:uppercase;letter-spacing:.8px;color:#999;padding:7px 12px 5px;border-bottom:1px solid #f0f0f0}
.inline-act{display:block;width:100%;padding:8px 12px;text-align:left;border:none;background:#fff;cursor:pointer;font-size:12px;font-family:inherit;border-bottom:1px solid #f8f8f8;transition:.1s}.inline-act:hover{background:#ede9fe;color:#6d28d9}
.inline-empty{padding:10px 12px;font-size:11px;color:#999;text-align:center}
.inline-hist-toggle{display:block;width:100%;padding:6px 12px;text-align:left;border:none;border-top:1px solid #f0f0f0;background:#fafafa;cursor:pointer;font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.6px;color:#aaa;font-family:inherit;transition:.1s}.inline-hist-toggle:hover{color:#7c3aed;background:#f5f3ff}
.inline-hist{max-height:220px;overflow-y:auto;border-top:1px solid #f0f0f0}
.inline-hist-empty{padding:8px 12px;font-size:11px;color:#bbb;font-style:italic}
.inline-hist-row{padding:6px 12px;border-bottom:1px solid #f8f8f8}
.inline-hist-row:last-child{border-bottom:none}
.inline-hist-label{display:block;font-size:11px;font-weight:500;color:#333}
.inline-hist-sub{display:flex;justify-content:space-between;align-items:center;margin-top:1px}
.inline-hist-who{font-size:10px;color:#888}
.inline-hist-at{font-size:9px;font-family:'SF Mono',monospace;color:#bbb}
.inline-motif-title{font-size:11px;font-weight:600;color:#6d28d9;padding:8px 12px 6px;border-bottom:1px solid #f0f0f0}
.inline-motif-input{display:block;width:calc(100% - 24px);box-sizing:border-box;padding:6px 8px;font-size:11px;font-family:inherit;border:1px solid #ddd;border-radius:3px;resize:vertical;outline:none;margin:8px 12px 6px;background:#faf5ff;min-height:56px}
.inline-motif-input:focus{border-color:#7c3aed}
.inline-motif-btns{display:flex;gap:6px;padding:0 12px 10px}
.inline-motif-confirm{flex:1;padding:5px 0;font-size:11px;font-weight:600;font-family:inherit;background:#7c3aed;color:#fff;border:none;border-radius:3px;cursor:pointer;transition:.15s}.inline-motif-confirm:hover{background:#6d28d9}
.inline-motif-cancel{flex:1;padding:5px 0;font-size:11px;font-family:inherit;background:#f5f5f5;color:#666;border:1px solid #ddd;border-radius:3px;cursor:pointer;transition:.15s}.inline-motif-cancel:hover{background:#eee}
/* Date picker popup */
.date-picker-pop{position:fixed;background:#fff;border:1px solid #ddd;border-radius:4px;box-shadow:0 6px 20px rgba(0,0,0,.15);z-index:400;padding:12px;min-width:200px}
.dp-title{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.8px;color:#999;margin-bottom:8px}
.dp-input{width:100%;padding:6px 8px;border:1px solid #ddd;border-radius:3px;font-size:13px;font-family:inherit;outline:none;box-sizing:border-box}.dp-input:focus{border-color:#7c3aed}
.dp-charge{margin:7px 0 2px;padding:5px 8px;border-radius:3px;font-size:11px;line-height:1.4;background:#fafafa;border:1px solid #f0f0f0}
.charge-loading{color:#999}
.charge-ok{color:#1D9E75;font-weight:500}
.charge-low{color:#7c3aed;font-weight:500}
.charge-med{color:#FFA94D;font-weight:600}
.charge-high{color:#E24B4A;font-weight:700}
.dp-history{margin:8px 0 2px;border-top:1px solid #f0f0f0;padding-top:7px}
.dp-hist-title{font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:.8px;color:#bbb;margin-bottom:5px}
.dp-hist-loading{font-size:11px;color:#999}
.dp-hist-empty{font-size:11px;color:#ccc;font-style:italic}
.dp-hist-row{margin-bottom:4px;padding:4px 6px;background:#fafafa;border-radius:3px;border:1px solid #f0f0f0}
.dp-hist-val{display:block;font-size:12px;font-weight:600;color:#7c3aed;font-family:'SF Mono',monospace}
.dp-hist-meta{display:block;font-size:10px;color:#999;margin-top:1px}
.dp-actions{display:flex;gap:6px;margin-top:8px}
.dp-ok{flex:1;padding:6px;background:#7c3aed;color:#fff;border:none;border-radius:3px;cursor:pointer;font-size:12px;font-weight:500}.dp-ok:hover{background:#6d28d9}
.dp-cancel{padding:6px 10px;background:#f5f5f5;color:#666;border:none;border-radius:3px;cursor:pointer;font-size:12px}
/* Ligne lot bloquante */
.row-bloquante td{background:#FFF5F5!important}
.row-bloquante:hover td{background:#FDEAEA!important}
/* Popup déviation */
.dev-pop{position:fixed;background:#fff;border:1px solid #ddd;border-radius:4px;box-shadow:0 6px 20px rgba(0,0,0,.15);z-index:400;padding:12px;min-width:300px;max-width:360px;max-height:80vh;overflow-y:auto;display:flex;flex-direction:column;gap:8px}
.dev-pop-header{display:flex;align-items:center;justify-content:space-between}
.dev-pop-title{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.8px;color:#999}
.dev-pop-x{background:none;border:none;cursor:pointer;color:#bbb;font-size:14px;padding:0}
.dev-pop-summary{display:flex;gap:6px;flex-wrap:wrap}
.dev-sum-bl{font-size:11px;padding:2px 8px;border-radius:10px;background:#FCEBEB;color:#A32D2D;font-weight:600}
.dev-sum-nb{font-size:11px;padding:2px 8px;border-radius:10px;background:#f5f5f5;color:#666;font-weight:500}
.dev-sum-cl{font-size:11px;padding:2px 8px;border-radius:10px;background:#EAF3DE;color:#3B6D11;font-weight:500}
.dev-pop-list{display:flex;flex-direction:column;gap:3px;border-top:1px solid #f0f0f0;padding-top:6px}
.dev-pop-acc{border:1px solid #f0f0f0;border-radius:3px;overflow:hidden;background:#fff}
.dev-pop-acc-hd{display:flex;align-items:center;gap:5px;padding:5px 8px;cursor:pointer;background:#fafafa;user-select:none;transition:.1s}.dev-pop-acc-hd:hover{background:#f5f3ff}
.dev-pop-acc-num{font-size:11px;font-weight:600;font-family:'SF Mono',monospace;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#333}
.dev-pop-acc-date{font-size:9px;font-family:'SF Mono',monospace;color:#bbb;white-space:nowrap}
.dev-pop-acc-chev{font-size:9px;color:#bbb;margin-left:2px}
.dev-pop-acc-body{padding:6px 8px;border-top:1px solid #f0f0f0;background:#fff}
.dev-pop-acc-actions{display:flex;gap:5px;flex-wrap:wrap;margin-top:5px}
.dev-bl-btn{font-size:10px;padding:2px 8px;border:1px solid #E89C3A;border-radius:3px;background:#FEF5E7;color:#A0620D;cursor:pointer;font-family:inherit}.dev-bl-btn:hover{background:#FDEBD0;color:#7D4E0A}
.dev-badge-sm{font-size:9px;padding:1px 5px;border-radius:2px;font-weight:700}
.dev-bl-on{background:#FCEBEB;color:#A32D2D}.dev-bl-off{background:#f0f0f0;color:#999}
.dev-pop-dn{font-size:12px;font-weight:600;font-family:'SF Mono',monospace;flex:1}
.dev-pop-stat{font-size:10px;padding:1px 6px;border-radius:10px;font-weight:500}
.dev-stat-op{background:#FCEBEB;color:#A32D2D}.dev-stat-cl{background:#EAF3DE;color:#3B6D11}
.dev-close-btn{font-size:10px;padding:2px 8px;border:1px solid #ddd;border-radius:3px;background:#fff;cursor:pointer;color:#666;margin-left:auto}
.dev-close-btn:hover{background:#FCEBEB;color:#A32D2D;border-color:#f5c6c6}
.dev-pop-desc{font-size:11px;color:#999;margin-top:3px;word-break:break-word}
.dev-pop-meta{display:flex;align-items:center;gap:6px;flex-wrap:wrap;margin-top:4px;padding-top:4px;border-top:1px solid #f5f5f5}
.dev-pop-svc{background:#ede9fe;color:#6d28d9;padding:1px 6px;border-radius:10px;font-size:9px;font-weight:600;white-space:nowrap}
.dev-pop-who{font-size:10px;font-weight:500;color:#666}
.dev-pop-when{font-size:9px;font-family:'SF Mono',monospace;color:#999;margin-left:auto}
.dev-pop-edit-row{margin-top:4px}
.dev-pop-in-sm{width:100%;padding:4px 7px;border:1px solid #e0e0e0;border-radius:3px;font-size:12px;font-family:inherit;outline:none;box-sizing:border-box}.dev-pop-in-sm:focus{border-color:#7c3aed}
.dev-pop-ta-sm{width:100%;padding:4px 7px;border:1px solid #e0e0e0;border-radius:3px;font-size:12px;font-family:inherit;resize:vertical;outline:none;box-sizing:border-box}.dev-pop-ta-sm:focus{border-color:#7c3aed}
.dev-save-btn{font-size:10px;padding:3px 10px;border:1px solid #7c3aed;border-radius:3px;background:#ede9fe;color:#6d28d9;cursor:pointer;margin-top:5px;font-family:inherit}.dev-save-btn:hover{background:#ddd6fe}
.dev-pop-sep{font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:.8px;color:#bbb;border-top:1px solid #f0f0f0;padding-top:8px;margin-top:2px}
.dev-pop-in{width:100%;padding:6px 8px;border:1px solid #ddd;border-radius:3px;font-size:13px;font-family:inherit;outline:none;box-sizing:border-box}
.dev-pop-ta{width:100%;padding:6px 8px;border:1px solid #ddd;border-radius:3px;font-size:13px;font-family:inherit;resize:vertical;outline:none;box-sizing:border-box}
.dev-pop-tog{padding:5px 14px;border:none;border-radius:10px;cursor:pointer;font-size:11px;font-weight:600;align-self:flex-start}
.dev-pop-bl-on{background:#FCEBEB;color:#A32D2D}.dev-pop-bl-off{background:#f5f5f5;color:#999}
.dev-pop-actions{display:flex;gap:6px}
/* Bulk déviation */
.bulk-dev-wrap{display:flex;align-items:center;gap:6px;flex-wrap:wrap}
.bulk-dev-in{padding:6px 8px;border:1px solid #ddd;border-radius:3px;font-size:12px;font-family:inherit;min-width:130px}
.bulk-dev-tog{padding:5px 12px;border:none;border-radius:10px;cursor:pointer;font-size:11px;font-weight:600}
.bulk-dev-bl-on{background:#FCEBEB;color:#A32D2D}.bulk-dev-bl-off{background:#f5f5f5;color:#999}
/* bulk bar */
.bulk-bar{display:flex;align-items:center;gap:8px;padding:6px 0;flex-wrap:wrap;border-bottom:1px solid #e8e8e8}
/* ── Action palette (command-palette style) ── */
.action-palette-wrap{position:relative;display:flex;align-items:center;gap:4px}
.action-trigger{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:5px 10px;font-size:12px;border:1px solid #ddd;border-radius:3px;background:#fff;cursor:pointer;color:#666;font-family:inherit;min-width:200px;max-width:260px;transition:.15s}
.action-trigger:hover{border-color:#7c3aed;color:#333}
.action-trigger-on{border-color:#7c3aed;color:#6d28d9;background:#ede9fe}
.action-trigger-label{flex:1;text-align:left;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.action-trigger-arr{font-size:8px;color:#aaa;flex-shrink:0}
.action-clear{padding:3px 7px;font-size:11px;border:1px solid #ddd;border-radius:3px;background:#fff;cursor:pointer;color:#999;font-family:inherit;line-height:1}.action-clear:hover{color:#E24B4A;border-color:#E24B4A}
.action-palette{position:absolute;top:calc(100% + 5px);left:0;z-index:600;background:#fff;border:1px solid #e0e0e0;border-radius:8px;box-shadow:0 8px 32px rgba(0,0,0,.15);min-width:320px;max-width:420px;overflow:hidden}
.ap-search-wrap{display:flex;align-items:center;gap:6px;padding:8px 12px;border-bottom:1px solid #f0f0f0;background:#fafafa}
.ap-search-ico{font-size:12px;color:#bbb;flex-shrink:0}
.ap-search{flex:1;border:none;outline:none;font-size:12px;font-family:inherit;color:#333;background:transparent}
.ap-search::placeholder{color:#bbb}
.ap-search-clr{background:none;border:none;cursor:pointer;color:#ccc;font-size:11px;padding:2px 4px;border-radius:2px}.ap-search-clr:hover{color:#666;background:#eee}
.ap-body{max-height:340px;overflow-y:auto;padding:4px 0}
.ap-grp-hd{font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:1.2px;color:#bbb;padding:10px 14px 3px;user-select:none}
.ap-item{display:flex;align-items:center;gap:6px;width:100%;padding:6px 14px;font-size:12px;font-family:inherit;border:none;background:none;cursor:pointer;color:#333;text-align:left;transition:background .08s}
.ap-item:hover{background:#ede9fe;color:#6d28d9}
.ap-item-active{background:#ede9fe;color:#6d28d9;font-weight:600}
.ap-item-arr{color:#d0d0d0;font-size:14px;flex-shrink:0;line-height:1}
.ap-item:hover .ap-item-arr,.ap-item-active .ap-item-arr{color:#7c3aed}
.ap-empty{padding:20px 14px;font-size:12px;color:#bbb;text-align:center}
/* Accordéon */
.ap-acc-grp{border-bottom:1px solid #f5f5f5}
.ap-acc-grp:last-child{border-bottom:none}
.ap-acc-hd{display:flex;align-items:center;gap:8px;width:100%;padding:8px 14px;font-size:12px;font-family:inherit;font-weight:500;border:none;background:none;cursor:pointer;color:#444;text-align:left;transition:background .1s}
.ap-acc-hd:hover{background:#f5f3ff;color:#7c3aed}
.ap-acc-chevron{font-size:12px;color:#aaa;flex-shrink:0;width:12px}
.ap-acc-label{flex:1}
.ap-acc-cnt{font-size:10px;color:#6d28d9;background:#ede9fe;border-radius:8px;padding:1px 6px;font-weight:600}
.ap-acc-items{padding:0 0 4px 0;background:#faf5ff}
.bulk-btn{padding:5px 14px;font-size:12px;font-weight:500;background:#7c3aed;color:#fff;border:none;border-radius:3px;cursor:pointer;white-space:nowrap}.bulk-btn:hover{background:#6d28d9}.bulk-btn:disabled{opacity:.35;cursor:not-allowed}
.bulk-info{font-size:11px;color:#7c3aed;font-family:'SF Mono',monospace}
.bulk-clear{font-size:11px;padding:3px 10px;border:1px solid #E24B4A;border-radius:3px;background:#fff;color:#E24B4A;cursor:pointer}.bulk-clear:hover{background:#FCEBEB}
.bulk-date-wrap{display:flex;align-items:center;gap:6px}
.bulk-date-lbl{font-size:12px;color:#666;white-space:nowrap}
.bulk-date-in{padding:5px 8px;border:1px solid #ddd;border-radius:3px;font-size:12px;font-family:inherit;outline:none}.bulk-date-in:focus{border-color:#7c3aed}
/* checkboxes */
.th-chk,.td-chk{width:32px;text-align:center;padding:0 4px !important}.td-chk{cursor:pointer}.row-sel td{background:#ede9fe !important}
/* modal masse */
.m-overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:200;padding:16px}
.m-box{background:#fff;padding:24px;width:min(100%,480px);border-radius:4px;max-height:85vh;overflow-y:auto}
.m-title{font-size:16px;font-weight:500;margin-bottom:16px}
.m-line{display:flex;justify-content:space-between;align-items:center;padding:6px 0;font-size:13px;border-bottom:1px solid #f5f5f5}.m-lbl{color:#999}
.m-chips{display:flex;flex-wrap:wrap;gap:4px;margin-top:10px}
.m-chip{font-size:11px;font-family:'SF Mono',monospace;padding:2px 8px;background:#f5f5f5;border-radius:2px;color:#666}.m-more{background:#ede9fe;color:#7c3aed}
.m-actions{display:flex;gap:8px;margin-top:16px}
.m-btn-ok{flex:1;padding:11px;background:#7c3aed;color:#fff;border:none;font-size:13px;font-weight:500;cursor:pointer;border-radius:2px;min-height:44px}.m-btn-ok:hover{background:#6d28d9}.m-btn-ok:disabled{opacity:.5}
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
  .tb th{font-size:10px}
  .table-wrap{max-height:calc(100vh - 220px)}
  .action-trigger{min-width:0;width:100%;max-width:100%}
  .action-palette-wrap{width:100%}
  .action-palette{min-width:0;width:100%;max-width:100%}
  .bulk-bar{flex-direction:column;align-items:stretch}
  .bulk-btn{width:100%;padding:10px;min-height:44px}
  .col-panel{right:auto;left:0;max-height:70vh;overflow-y:auto}
  /* Popups fixed : forcer dans l'écran */
  .col-dd{max-width:calc(100vw - 16px) !important}
  .inline-menu{left:8px !important;right:8px !important;max-width:none !important;min-width:0}
  .date-picker-pop{left:8px !important;right:8px !important;min-width:0}
  .dev-pop{left:8px !important;right:8px !important;max-width:none !important;min-width:0}
  .m-overlay{padding:12px}
  .m-box{width:100%}
}
</style>
