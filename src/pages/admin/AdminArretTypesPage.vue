<template>
  <div>
    <div class="ph"><span class="pt">TYPES D'ARRÊTS</span><span class="pt-sub">Arbre famille → sous-famille → code arrêt</span></div>

    <div class="tree-layout">

      <!-- ── COL 1 : Familles ── -->
      <div class="tree-col">
        <div class="col-hd">
          <span class="col-title">Familles</span>
          <button class="btn-add" @click="openModal('famille')">+ Ajouter</button>
        </div>
        <div v-if="loadingF" class="loading">Chargement…</div>
        <div
          v-for="f in familles" :key="f.id"
          class="tree-item" :class="{active: selF && selF.id===f.id, inactive: !f.actif}"
          @click="selectF(f)"
        >
          <span class="cdot" :style="{background:f.couleur}"></span>
          <span class="item-nom">{{f.nom}}</span>
          <span class="item-badge">{{f.sf_count||0}}</span>
          <div class="item-acts" @click.stop>
            <button class="ia" @click="openModal('famille', f)" title="Modifier">✏️</button>
            <button class="ia del" @click="confirmDel('famille', f)" title="Supprimer">🗑</button>
          </div>
        </div>
        <div v-if="!loadingF && familles.length===0" class="empty-col">Aucune famille</div>
      </div>

      <!-- ── COL 2 : Sous-familles ── -->
      <div class="tree-col">
        <div class="col-hd">
          <span class="col-title" v-if="selF">
            <span class="cdot" :style="{background:selF.couleur}"></span>{{selF.nom}}
          </span>
          <span class="col-title muted" v-else>Sous-familles</span>
          <button class="btn-add" @click="openModal('sf')" :disabled="!selF">+ Ajouter</button>
        </div>
        <div v-if="!selF" class="empty-col">← Choisir une famille</div>
        <div v-else-if="loadingSF" class="loading">Chargement…</div>
        <div
          v-for="sf in sousFamilles" :key="sf.id"
          class="tree-item" :class="{active: selSF && selSF.id===sf.id, inactive: !sf.actif}"
          @click="selectSF(sf)"
        >
          <span class="item-nom">{{sf.nom}}</span>
          <span class="item-badge">{{sf.type_count||0}}</span>
          <div class="item-acts" @click.stop>
            <button class="ia" @click="openModal('sf', sf)" title="Modifier">✏️</button>
            <button class="ia del" @click="confirmDel('sf', sf)" title="Supprimer">🗑</button>
          </div>
        </div>
        <div v-if="selF && !loadingSF && sousFamilles.length===0" class="empty-col">Aucune sous-famille</div>
      </div>

      <!-- ── COL 3 : Codes arrêts ── -->
      <div class="tree-col wide">
        <div class="col-hd">
          <span class="col-title" v-if="selSF">{{selSF.nom}}</span>
          <span class="col-title muted" v-else>Codes arrêts</span>
          <button class="btn-add" @click="openModal('type')" :disabled="!selSF">+ Ajouter</button>
        </div>
        <div v-if="!selSF" class="empty-col">← Choisir une sous-famille</div>
        <div v-else-if="loadingT" class="loading">Chargement…</div>
        <div v-for="t in arretTypes" :key="t.id" class="type-row" :class="{inactive: !t.actif}">
          <div class="type-code" :style="{background:(t.couleur||selF.couleur)+'22', color:t.couleur||selF.couleur, borderColor:(t.couleur||selF.couleur)+'44'}">
            {{t.code}}
          </div>
          <div class="type-body">
            <div class="type-nom">{{t.nom}}</div>
            <div class="type-tags">
              <span v-if="t.est_planifie"  class="tag tag-plan">Planifié</span>
              <span v-if="t.est_pause"     class="tag tag-pause">Pause</span>
              <span v-if="!t.impacte_trs"  class="tag tag-ok">Hors TRS</span>
              <span v-if="t.duree_std_min" class="tag tag-dur">{{t.duree_std_min}} min</span>
              <span v-if="!t.actif"        class="tag tag-off">Inactif</span>
            </div>
          </div>
          <div class="item-acts">
            <button class="ia" @click="openModal('type', t)" title="Modifier">✏️</button>
            <button class="ia del" @click="confirmDel('type', t)" title="Supprimer">🗑</button>
          </div>
        </div>
        <div v-if="selSF && !loadingT && arretTypes.length===0" class="empty-col">Aucun code arrêt</div>
      </div>
    </div>

    <!-- ══ MODAL ══ -->
    <div class="overlay" v-if="modal.show" @click.self="modal.show=false">
      <div class="modal">
        <div class="modal-hd">{{modal.title}}</div>

        <!-- FAMILLE -->
        <template v-if="modal.kind==='famille'">
          <label class="lbl">Nom *</label>
          <input v-model="modal.data.nom" class="inp" placeholder="ex: Panne" />
          <label class="lbl">Couleur</label>
          <div class="color-row">
            <input type="color" v-model="modal.data.couleur" class="color-pick" />
            <span class="color-val">{{modal.data.couleur}}</span>
            <div class="color-presets">
              <span v-for="c in colorPresets" :key="c" class="cp" :style="{background:c}" @click="modal.data.couleur=c" :class="{selected:modal.data.couleur===c}"></span>
            </div>
          </div>
          <label class="lbl">Ordre d'affichage</label>
          <input v-model.number="modal.data.ordre" type="number" class="inp inp-sm" />
          <label class="lbl chk"><input type="checkbox" v-model="modal.data.actif" /> Actif</label>
        </template>

        <!-- SOUS-FAMILLE -->
        <template v-if="modal.kind==='sf'">
          <div class="modal-ctx">Famille : <strong>{{selF.nom}}</strong></div>
          <label class="lbl">Nom *</label>
          <input v-model="modal.data.nom" class="inp" placeholder="ex: Mécanique" />
          <label class="lbl">Ordre d'affichage</label>
          <input v-model.number="modal.data.ordre" type="number" class="inp inp-sm" />
          <label class="lbl chk"><input type="checkbox" v-model="modal.data.actif" /> Actif</label>
        </template>

        <!-- TYPE D'ARRÊT -->
        <template v-if="modal.kind==='type'">
          <div class="modal-ctx">{{selF.nom}} → {{selSF.nom}}</div>
          <div class="form-row">
            <div class="form-field">
              <label class="lbl">Code * <span class="hint">(ex: PAN-MEC-01)</span></label>
              <input v-model="modal.data.code" class="inp mono" placeholder="XXX-YYY-00" :disabled="!!modal.editing" />
            </div>
            <div class="form-field">
              <label class="lbl">Durée standard (min)</label>
              <input v-model.number="modal.data.duree_std_min" type="number" class="inp inp-sm" placeholder="30" />
            </div>
          </div>
          <label class="lbl">Nom *</label>
          <input v-model="modal.data.nom" class="inp" placeholder="ex: Grippage mécanique" />
          <label class="lbl">Couleur (laisser vide = hérite famille)</label>
          <div class="color-row">
            <input type="color" v-model="modal.data.couleur" class="color-pick" />
            <span class="color-val">{{modal.data.couleur||'—'}}</span>
            <button class="btn-clear" @click="modal.data.couleur=''" v-if="modal.data.couleur">✕ Effacer</button>
          </div>
          <div class="flags-row">
            <label class="flag-item">
              <input type="checkbox" v-model="modal.data.est_planifie" />
              <span class="flag-label">
                <strong>Planifié</strong>
                <small>Ne pénalise pas la Disponibilité</small>
              </span>
            </label>
            <label class="flag-item">
              <input type="checkbox" v-model="modal.data.est_pause" />
              <span class="flag-label">
                <strong>Pause</strong>
                <small>Déduit du Temps d'Ouverture</small>
              </span>
            </label>
            <label class="flag-item">
              <input type="checkbox" v-model="modal.data.impacte_trs" />
              <span class="flag-label">
                <strong>Impacte TRS</strong>
                <small>Comptabilisé dans le calcul</small>
              </span>
            </label>
            <label class="flag-item">
              <input type="checkbox" v-model="modal.data.actif" />
              <span class="flag-label">
                <strong>Actif</strong>
                <small>Visible dans les sélecteurs</small>
              </span>
            </label>
          </div>
        </template>

        <div class="err" v-if="modal.error">{{modal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save" @click="saveModal" :disabled="modal.saving">
            {{modal.saving ? 'Enregistrement…' : (modal.editing ? 'Modifier' : 'Ajouter')}}
          </button>
          <button class="btn-cancel" @click="modal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ CONFIRM DELETE ══ -->
    <div class="overlay" v-if="delConfirm.show" @click.self="delConfirm.show=false">
      <div class="modal modal-sm">
        <div class="modal-hd">Confirmer la suppression</div>
        <p class="del-msg">Supprimer <strong>«{{delConfirm.nom}}»</strong> ?<br/>
          <span v-if="delConfirm.kind==='famille'">Toutes les sous-familles et codes arrêts associés seront supprimés.</span>
          <span v-if="delConfirm.kind==='sf'">Tous les codes arrêts associés seront supprimés.</span>
        </p>
        <div class="modal-acts">
          <button class="btn-del" @click="doDelete" :disabled="delConfirm.saving">
            {{delConfirm.saving ? 'Suppression…' : 'Supprimer'}}
          </button>
          <button class="btn-cancel" @click="delConfirm.show=false">Annuler</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, reactive, onMounted } from 'vue'
import { supabase } from '../../supabase'
export default {
  setup() {
    var familles    = ref([])
    var sousFamilles = ref([])
    var arretTypes  = ref([])
    var selF        = ref(null)
    var selSF       = ref(null)
    var loadingF    = ref(false)
    var loadingSF   = ref(false)
    var loadingT    = ref(false)

    var colorPresets = ['#EF4444','#F97316','#EAB308','#10B981','#06B6D4','#3B82F6','#6366F1','#8B5CF6','#EC4899','#6B7280']

    var modal = reactive({
      show: false, kind: '', title: '', editing: null,
      data: {}, error: '', saving: false
    })
    var delConfirm = reactive({ show: false, kind: '', id: null, nom: '', saving: false })

    var loadFamilles = async function() {
      loadingF.value = true
      var r = await supabase.from('arret_familles').select('*, arret_sous_familles(count)').order('ordre').order('nom')
      if (r.data) {
        familles.value = r.data.map(function(f) {
          return Object.assign({}, f, { sf_count: f.arret_sous_familles ? f.arret_sous_familles[0].count : 0 })
        })
      }
      loadingF.value = false
    }

    var loadSousFamilles = async function(familleId) {
      loadingSF.value = true
      sousFamilles.value = []
      arretTypes.value = []
      selSF.value = null
      var r = await supabase.from('arret_sous_familles')
        .select('*, arret_types(count)')
        .eq('famille_id', familleId)
        .order('ordre').order('nom')
      if (r.data) {
        sousFamilles.value = r.data.map(function(sf) {
          return Object.assign({}, sf, { type_count: sf.arret_types ? sf.arret_types[0].count : 0 })
        })
      }
      loadingSF.value = false
    }

    var loadTypes = async function(sfId) {
      loadingT.value = true
      arretTypes.value = []
      var r = await supabase.from('arret_types')
        .select('*')
        .eq('sous_famille_id', sfId)
        .order('code')
      if (r.data) arretTypes.value = r.data
      loadingT.value = false
    }

    var selectF = function(f) {
      selF.value = f
      loadSousFamilles(f.id)
    }

    var selectSF = function(sf) {
      selSF.value = sf
      loadTypes(sf.id)
    }

    var openModal = function(kind, item) {
      modal.kind    = kind
      modal.editing = item || null
      modal.error   = ''
      modal.saving  = false
      if (kind === 'famille') {
        modal.title = item ? 'Modifier la famille' : 'Nouvelle famille'
        modal.data = item
          ? { nom: item.nom, couleur: item.couleur, ordre: item.ordre, actif: item.actif }
          : { nom: '', couleur: '#EF4444', ordre: 0, actif: true }
      } else if (kind === 'sf') {
        if (!selF.value) return
        modal.title = item ? 'Modifier la sous-famille' : 'Nouvelle sous-famille'
        modal.data = item
          ? { nom: item.nom, ordre: item.ordre, actif: item.actif }
          : { nom: '', ordre: 0, actif: true }
      } else if (kind === 'type') {
        if (!selSF.value) return
        modal.title = item ? 'Modifier le code arrêt' : 'Nouveau code arrêt'
        modal.data = item
          ? { code: item.code, nom: item.nom, couleur: item.couleur||'', duree_std_min: item.duree_std_min, est_planifie: item.est_planifie, est_pause: item.est_pause, impacte_trs: item.impacte_trs, actif: item.actif }
          : { code: '', nom: '', couleur: '', duree_std_min: null, est_planifie: false, est_pause: false, impacte_trs: true, actif: true }
      }
      modal.show = true
    }

    var saveModal = async function() {
      modal.error = ''
      if (!modal.data.nom || !modal.data.nom.trim()) { modal.error = 'Le nom est requis.'; return }
      if (modal.kind === 'type' && (!modal.data.code || !modal.data.code.trim())) { modal.error = 'Le code est requis.'; return }
      modal.saving = true

      var payload, res
      if (modal.kind === 'famille') {
        payload = { nom: modal.data.nom.trim(), couleur: modal.data.couleur||'#EF4444', ordre: modal.data.ordre||0, actif: modal.data.actif, updated_at: new Date().toISOString() }
        if (modal.editing) res = await supabase.from('arret_familles').update(payload).eq('id', modal.editing.id)
        else res = await supabase.from('arret_familles').insert(payload)
        if (!res.error) { await loadFamilles(); if (selF.value) selF.value = familles.value.find(function(f){return f.id===selF.value.id}) || null }

      } else if (modal.kind === 'sf') {
        payload = { famille_id: selF.value.id, nom: modal.data.nom.trim(), ordre: modal.data.ordre||0, actif: modal.data.actif, updated_at: new Date().toISOString() }
        if (modal.editing) res = await supabase.from('arret_sous_familles').update(payload).eq('id', modal.editing.id)
        else res = await supabase.from('arret_sous_familles').insert(payload)
        if (!res.error) await loadSousFamilles(selF.value.id)

      } else if (modal.kind === 'type') {
        payload = {
          sous_famille_id: selSF.value.id, code: modal.data.code.trim().toUpperCase(),
          nom: modal.data.nom.trim(), couleur: modal.data.couleur||null,
          duree_std_min: modal.data.duree_std_min||null,
          est_planifie: !!modal.data.est_planifie, est_pause: !!modal.data.est_pause,
          impacte_trs: !!modal.data.impacte_trs, actif: !!modal.data.actif,
          updated_at: new Date().toISOString()
        }
        if (modal.editing) res = await supabase.from('arret_types').update(payload).eq('id', modal.editing.id)
        else res = await supabase.from('arret_types').insert(payload)
        if (!res.error) await loadTypes(selSF.value.id)
      }

      if (res && res.error) { modal.error = res.error.message; modal.saving = false; return }
      modal.saving = false
      modal.show   = false
    }

    var confirmDel = function(kind, item) {
      delConfirm.kind  = kind
      delConfirm.id    = item.id
      delConfirm.nom   = item.nom || item.code
      delConfirm.saving = false
      delConfirm.show  = true
    }

    var doDelete = async function() {
      delConfirm.saving = true
      var table = delConfirm.kind === 'famille' ? 'arret_familles' : delConfirm.kind === 'sf' ? 'arret_sous_familles' : 'arret_types'
      var r = await supabase.from(table).delete().eq('id', delConfirm.id)
      if (r.error) { alert(r.error.message); delConfirm.saving = false; return }
      delConfirm.show = false
      if (delConfirm.kind === 'famille') { if (selF.value && selF.value.id===delConfirm.id) { selF.value=null; sousFamilles.value=[]; arretTypes.value=[] }; await loadFamilles() }
      else if (delConfirm.kind === 'sf') { if (selSF.value && selSF.value.id===delConfirm.id) { selSF.value=null; arretTypes.value=[] }; await loadSousFamilles(selF.value.id) }
      else { await loadTypes(selSF.value.id) }
    }

    onMounted(loadFamilles)

    return {
      familles, sousFamilles, arretTypes, selF, selSF,
      loadingF, loadingSF, loadingT, colorPresets,
      modal, delConfirm,
      selectF, selectSF, openModal, saveModal, confirmDel, doDelete
    }
  }
}
</script>

<style scoped>
.ph{padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:16px;display:flex;align-items:baseline;gap:12px}
.pt{font-size:11px;font-weight:500;letter-spacing:1.5px}
.pt-sub{font-size:11px;color:#999}

.tree-layout{display:grid;grid-template-columns:200px 220px 1fr;gap:0;border:1px solid #e0e0e0;border-radius:4px;overflow:hidden;min-height:500px;max-height:calc(100vh - 160px)}
.tree-col{border-right:1px solid #e0e0e0;display:flex;flex-direction:column;min-height:0;overflow-y:auto}
.tree-col.wide{border-right:none}
.col-hd{display:flex;align-items:center;justify-content:space-between;padding:10px 12px;background:#f8f8f8;border-bottom:1px solid #e0e0e0;flex-shrink:0;position:sticky;top:0;z-index:2}
.col-title{font-size:11px;font-weight:600;letter-spacing:.5px;display:flex;align-items:center;gap:6px}
.col-title.muted{color:#aaa}
.btn-add{font-size:11px;padding:3px 8px;background:#0a0a0a;color:#fff;border:none;border-radius:2px;cursor:pointer;white-space:nowrap}
.btn-add:disabled{opacity:.3;cursor:not-allowed}
.btn-add:hover:not(:disabled){background:#333}
.tree-item{display:flex;align-items:center;gap:8px;padding:9px 12px;cursor:pointer;font-size:13px;border-bottom:1px solid #f0f0f0;position:relative}
.tree-item:hover{background:#fafafa}
.tree-item.active{background:#EBF5FF;border-left:3px solid #185FA5}
.tree-item.inactive{opacity:.5}
.cdot{width:10px;height:10px;border-radius:50%;flex-shrink:0}
.item-nom{flex:1;font-size:12px;font-weight:500;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.item-badge{font-size:10px;background:#e8e8e8;color:#666;padding:1px 6px;border-radius:8px;font-family:'SF Mono',monospace;flex-shrink:0}
.item-acts{display:none;gap:2px;flex-shrink:0}
.tree-item:hover .item-acts{display:flex}
.ia{background:none;border:none;cursor:pointer;font-size:12px;padding:2px 4px;border-radius:2px;opacity:.7}
.ia:hover{background:#e8e8e8;opacity:1}
.ia.del:hover{background:#fde8e8}
.empty-col{padding:20px 12px;font-size:12px;color:#bbb;text-align:center;flex:1;display:flex;align-items:center;justify-content:center}
.loading{padding:16px 12px;font-size:12px;color:#999;text-align:center}

/* Type rows */
.type-row{display:flex;align-items:flex-start;gap:12px;padding:10px 14px;border-bottom:1px solid #f0f0f0}
.type-row:hover{background:#fafafa}
.type-row.inactive{opacity:.45}
.type-code{font-family:'SF Mono','Fira Code',monospace;font-size:11px;font-weight:600;padding:3px 8px;border-radius:3px;border:1px solid;white-space:nowrap;flex-shrink:0;margin-top:2px}
.type-body{flex:1;min-width:0}
.type-nom{font-size:12px;font-weight:500;margin-bottom:4px}
.type-tags{display:flex;flex-wrap:wrap;gap:4px}
.tag{font-size:10px;padding:1px 6px;border-radius:8px;font-weight:500}
.tag-plan{background:#EFF6FF;color:#1D4ED8}
.tag-pause{background:#F0FDF4;color:#15803D}
.tag-ok{background:#F5F3FF;color:#7C3AED}
.tag-dur{background:#FFF7ED;color:#C2410C;font-family:'SF Mono',monospace}
.tag-off{background:#F5F5F5;color:#999}
.type-row:hover .item-acts{display:flex}
.type-row .item-acts{display:none;flex-direction:column;gap:2px;flex-shrink:0}

/* Modal */
.overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:100}
.modal{background:#fff;padding:24px;width:480px;max-width:96vw;border-radius:6px;max-height:90vh;overflow-y:auto}
.modal-sm{width:360px}
.modal-hd{font-size:14px;font-weight:600;margin-bottom:16px}
.modal-ctx{font-size:11px;color:#666;background:#f5f5f5;padding:6px 10px;border-radius:3px;margin-bottom:12px}
.lbl{display:block;font-size:11px;color:#666;text-transform:uppercase;letter-spacing:.3px;margin-bottom:4px;margin-top:12px}
.lbl.chk{display:flex;align-items:center;gap:6px;cursor:pointer;margin-top:12px}
.inp{width:100%;padding:8px 10px;border:1px solid #ddd;font-size:13px;outline:none;box-sizing:border-box;font-family:inherit;border-radius:2px}
.inp:focus{border-color:#185FA5}
.inp-sm{width:100px}
.mono{font-family:'SF Mono',monospace;text-transform:uppercase}
.hint{font-weight:400;text-transform:none;font-size:10px;color:#aaa;letter-spacing:0}
.form-row{display:flex;gap:16px}
.form-field{flex:1}
.color-row{display:flex;align-items:center;gap:10px;margin-bottom:4px}
.color-pick{width:44px;height:32px;padding:1px;border:1px solid #ddd;border-radius:2px;cursor:pointer}
.color-val{font-family:'SF Mono',monospace;font-size:11px;color:#666}
.color-presets{display:flex;gap:4px;flex-wrap:wrap}
.cp{width:20px;height:20px;border-radius:50%;cursor:pointer;border:2px solid transparent;transition:.1s}
.cp:hover{transform:scale(1.2)}
.cp.selected{border-color:#0a0a0a}
.btn-clear{font-size:11px;padding:3px 8px;border:1px solid #ddd;background:#fff;border-radius:2px;cursor:pointer;color:#666}
.flags-row{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:12px}
.flag-item{display:flex;align-items:flex-start;gap:8px;padding:8px 10px;border:1px solid #e8e8e8;border-radius:4px;cursor:pointer;background:#fafafa}
.flag-item:hover{background:#f0f0f0}
.flag-label{display:flex;flex-direction:column}
.flag-label strong{font-size:12px}
.flag-label small{font-size:10px;color:#888;margin-top:1px}
.err{color:#E24B4A;font-size:12px;margin-top:10px;padding:6px 10px;background:#FEF2F2;border-radius:3px}
.modal-acts{display:flex;gap:8px;margin-top:16px}
.btn-save{flex:1;padding:10px;background:#185FA5;color:#fff;border:none;font-size:13px;font-weight:500;cursor:pointer;border-radius:2px}
.btn-save:hover:not(:disabled){background:#0C447C}
.btn-save:disabled{opacity:.5}
.btn-cancel{flex:1;padding:10px;background:#f5f5f5;color:#666;border:none;font-size:13px;cursor:pointer;border-radius:2px}
.btn-cancel:hover{background:#eee}
.btn-del{flex:1;padding:10px;background:#E24B4A;color:#fff;border:none;font-size:13px;font-weight:500;cursor:pointer;border-radius:2px}
.btn-del:hover:not(:disabled){background:#c53030}
.del-msg{font-size:13px;color:#444;line-height:1.5;margin-bottom:4px}

@media(max-width:768px){
  .tree-layout{grid-template-columns:1fr;border:none;gap:12px}
  .tree-col{border:1px solid #e0e0e0;border-radius:4px;border-right:1px solid #e0e0e0}
}
</style>
