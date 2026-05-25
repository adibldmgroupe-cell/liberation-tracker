<template>
  <div>
    <div class="ph">
      <span class="pt">ÉQUIPEMENTS CONDITIONNEMENT</span>
      <button class="btn-add-top" @click="openModal(null)">+ Ajouter équipement</button>
    </div>

    <!-- Filtres site -->
    <div class="site-tabs">
      <button v-for="s in ['Tous','PHARMA','OTC']" :key="s" class="site-tab" :class="{active:filterSite===s}" @click="filterSite=s">{{s}}</button>
    </div>

    <div v-if="loading" class="loading">Chargement…</div>

    <div v-else>
      <table class="eq-table">
        <thead>
          <tr>
            <th>Équipement</th>
            <th>Site</th>
            <th class="num-col" title="Cadence nominale machine (boîtes/min)">Nominale<br/><small>boîte/min</small></th>
            <th class="num-col" title="Objectif par défaut (boîtes/min)">Objectif<br/><small>boîte/min</small></th>
            <th class="num-col" title="TRS cible en %">TRS cible<br/><small>%</small></th>
            <th class="num-col" title="Temps d'ouverture par shift en minutes">TO/shift<br/><small>min</small></th>
            <th class="num-col" title="Pauses planifiées déduites du TO">Pauses<br/><small>min</small></th>
            <th class="num-col" title="Objectif boîtes par shift = Obj × (TO−Pauses)">Obj/shift<br/><small>boîtes</small></th>
            <th>Weekend</th>
            <th>Statut</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="e in filteredEquipements" :key="e.id" :class="{inactive:!e.actif}">
            <td>
              <div class="eq-nom">{{e.nom_equipement}}</div>
              <div class="eq-zone" v-if="e.description_zone">{{e.description_zone}}</div>
            </td>
            <td><span class="site-badge" :class="e.site==='PHARMA'?'pharma':'otc'">{{e.site}}</span></td>
            <td class="num">{{e.cadence_nominale_boite_min != null ? e.cadence_nominale_boite_min : '—'}}</td>
            <td class="num obj">{{e.cadence_objectif_boite_min != null ? e.cadence_objectif_boite_min : '—'}}</td>
            <td class="num">
              <span class="trs-val" :class="trsClass(e.taux_rendement_cible)">{{e.taux_rendement_cible != null ? e.taux_rendement_cible+'%' : '—'}}</span>
            </td>
            <td class="num">{{e.temps_ouverture_shift_min}}</td>
            <td class="num">{{e.temps_pause_planifie_min}}</td>
            <td class="num obj">
              <span v-if="e.cadence_objectif_boite_min && e.temps_ouverture_shift_min">
                {{Math.round(e.cadence_objectif_boite_min * (e.temps_ouverture_shift_min - (e.temps_pause_planifie_min||0)))}}
              </span>
              <span v-else>—</span>
            </td>
            <td class="ctr">{{e.travaille_weekend ? '✓' : '—'}}</td>
            <td><span class="stat-badge" :class="e.actif?'actif':'inactif'">{{e.actif?'Actif':'Inactif'}}</span></td>
            <td class="acts">
              <button class="ia" @click="openModal(e)" title="Modifier">✏️</button>
              <button class="ia" @click="openObjectifs(e)" title="Objectifs par produit/shift">🎯</button>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-if="filteredEquipements.length===0" class="empty">Aucun équipement</div>
    </div>

    <!-- ══ MODAL ÉQUIPEMENT ══ -->
    <div class="overlay" v-if="modal.show" @click.self="modal.show=false">
      <div class="modal">
        <div class="modal-hd">{{modal.editing ? 'Modifier équipement' : 'Nouvel équipement'}}</div>

        <div class="form-grid">
          <div class="fg-full">
            <label class="lbl">Nom équipement *</label>
            <input v-model="modal.d.nom_equipement" class="inp" placeholder="ex: MARCHESINI R,T" />
          </div>
          <div>
            <label class="lbl">Site</label>
            <select v-model="modal.d.site" class="inp">
              <option>PHARMA</option>
              <option>OTC</option>
            </select>
          </div>
          <div>
            <label class="lbl">Ordre affichage</label>
            <input v-model.number="modal.d.ordre_affichage" type="number" class="inp" />
          </div>
          <div class="fg-full">
            <label class="lbl">Zone / Description</label>
            <input v-model="modal.d.description_zone" class="inp" placeholder="ex: Zone A – Salle 12" />
          </div>
        </div>

        <div class="section-title">Cadence & rendement</div>
        <div class="form-grid">
          <div>
            <label class="lbl">Cadence nominale <small>(boîtes/min)</small></label>
            <input v-model.number="modal.d.cadence_nominale_boite_min" type="number" step="0.5" class="inp" placeholder="ex: 120" />
            <div class="field-hint">Vitesse max théorique machine</div>
          </div>
          <div>
            <label class="lbl">Cadence objectif <small>(boîtes/min)</small></label>
            <input v-model.number="modal.d.cadence_objectif_boite_min" type="number" step="0.5" class="inp" placeholder="ex: 100" />
            <div class="field-hint">Cible par défaut (tous produits)</div>
          </div>
          <div>
            <label class="lbl">TRS cible <small>(%)</small></label>
            <input v-model.number="modal.d.taux_rendement_cible" type="number" step="0.5" min="0" max="100" class="inp" placeholder="85" />
          </div>
          <div>
            <label class="lbl">Temps ouverture/shift <small>(min)</small></label>
            <input v-model.number="modal.d.temps_ouverture_shift_min" type="number" class="inp" placeholder="480" />
            <div class="field-hint">Durée du shift (ex: 8h = 480)</div>
          </div>
          <div>
            <label class="lbl">Pauses planifiées <small>(min)</small></label>
            <input v-model.number="modal.d.temps_pause_planifie_min" type="number" class="inp" placeholder="30" />
            <div class="field-hint">Déduites du TO (déjeuner, café…)</div>
          </div>
          <div class="obj-preview" v-if="modal.d.cadence_objectif_boite_min && modal.d.temps_ouverture_shift_min">
            <div class="op-label">Objectif calculé / shift</div>
            <div class="op-val">{{Math.round(modal.d.cadence_objectif_boite_min * (modal.d.temps_ouverture_shift_min - (modal.d.temps_pause_planifie_min||0)))}} boîtes</div>
            <div class="op-sub">= {{modal.d.cadence_objectif_boite_min}} × {{modal.d.temps_ouverture_shift_min - (modal.d.temps_pause_planifie_min||0)}} min</div>
          </div>
        </div>

        <div class="check-row">
          <label class="chk-item"><input type="checkbox" v-model="modal.d.travaille_weekend" /> Travaille le weekend</label>
          <label class="chk-item"><input type="checkbox" v-model="modal.d.actif" /> Actif</label>
        </div>

        <div class="err" v-if="modal.error">{{modal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save" @click="saveModal" :disabled="modal.saving">{{modal.saving?'Enregistrement…':'Enregistrer'}}</button>
          <button class="btn-cancel" @click="modal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL OBJECTIFS PAR PRODUIT/SHIFT ══ -->
    <div class="overlay" v-if="objModal.show" @click.self="objModal.show=false">
      <div class="modal modal-lg">
        <div class="modal-hd">Objectifs — {{objModal.equip?.nom_equipement}}</div>
        <div class="obj-info">Objectif par défaut : <strong>{{objModal.equip?.cadence_objectif_boite_min}} boîtes/min</strong></div>

        <table class="obj-table" v-if="objModal.rows.length">
          <thead><tr><th>Produit</th><th>Shift</th><th>Cadence obj (boîtes/min)</th><th>Colisage réf</th><th>Commentaire</th><th></th></tr></thead>
          <tbody>
            <tr v-for="o in objModal.rows" :key="o.id">
              <td>{{o.products ? o.products.code_article : '— Tous —'}}</td>
              <td>{{o.shifts ? o.shifts.nom : '— Tous —'}}</td>
              <td class="num">{{o.cadence_objectif_boite_min}}</td>
              <td class="num">{{o.colisage_ref||'—'}}</td>
              <td class="small-txt">{{o.commentaire||'—'}}</td>
              <td><button class="ia del" @click="deleteObj(o.id)">🗑</button></td>
            </tr>
          </tbody>
        </table>
        <div class="empty-small" v-else>Aucun objectif spécifique — objectif par défaut appliqué</div>

        <div class="section-title" style="margin-top:16px">Ajouter un objectif spécifique</div>
        <div class="form-grid">
          <div>
            <label class="lbl">Produit <small>(vide = tous)</small></label>
            <input v-model="objModal.newRow.product_search" class="inp" placeholder="Rechercher code produit…" @input="searchProducts" />
            <div class="prod-suggestions" v-if="objModal.prodSuggestions.length">
              <div v-for="p in objModal.prodSuggestions" :key="p.id" class="ps-item" @click="selectProd(p)">
                <span class="ps-code">{{p.code_article}}</span><span class="ps-desc">{{p.description}}</span>
              </div>
            </div>
          </div>
          <div>
            <label class="lbl">Shift <small>(vide = tous)</small></label>
            <select v-model="objModal.newRow.shift_id" class="inp">
              <option :value="null">— Tous shifts —</option>
              <option v-for="s in shifts" :key="s.id" :value="s.id">{{s.nom}}</option>
            </select>
          </div>
          <div>
            <label class="lbl">Cadence objectif *</label>
            <input v-model.number="objModal.newRow.cadence_objectif_boite_min" type="number" step="0.5" class="inp" placeholder="ex: 95" />
          </div>
          <div>
            <label class="lbl">Colisage réf</label>
            <input v-model.number="objModal.newRow.colisage_ref" type="number" class="inp" />
          </div>
          <div class="fg-full">
            <label class="lbl">Commentaire</label>
            <input v-model="objModal.newRow.commentaire" class="inp" />
          </div>
        </div>
        <button class="btn-save" @click="addObj" :disabled="objModal.saving" style="margin-top:12px">
          {{objModal.saving?'Ajout…':'+ Ajouter objectif'}}
        </button>

        <div class="modal-acts" style="margin-top:16px">
          <button class="btn-cancel" style="flex:none;padding:8px 20px" @click="objModal.show=false">Fermer</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, reactive, onMounted } from 'vue'
import { supabase } from '../../supabase'
export default {
  setup() {
    var equipements  = ref([])
    var shifts       = ref([])
    var loading      = ref(false)
    var filterSite   = ref('Tous')
    var prodSearchTimeout = null

    var modal = reactive({ show:false, editing:null, d:{}, error:'', saving:false })
    var objModal = reactive({
      show:false, equip:null, rows:[], saving:false,
      prodSuggestions:[],
      newRow:{ product_id:null, product_search:'', shift_id:null, cadence_objectif_boite_min:null, colisage_ref:null, commentaire:'' }
    })

    var filteredEquipements = computed(function() {
      if (filterSite.value === 'Tous') return equipements.value
      return equipements.value.filter(function(e){ return e.site === filterSite.value })
    })

    var trsClass = function(v) {
      if (!v) return ''
      if (v >= 85) return 'trs-green'
      if (v >= 60) return 'trs-orange'
      return 'trs-red'
    }

    var loadEquipements = async function() {
      loading.value = true
      var r = await supabase.from('equipements_conditionnement').select('*').order('ordre_affichage')
      if (r.data) equipements.value = r.data
      loading.value = false
    }

    var loadShifts = async function() {
      var r = await supabase.from('shifts').select('id,nom').eq('actif',true).order('heure_debut')
      if (r.data) shifts.value = r.data
    }

    var openModal = function(e) {
      modal.editing = e
      modal.error   = ''
      modal.saving  = false
      modal.d = e ? {
        nom_equipement: e.nom_equipement, site: e.site, description_zone: e.description_zone||'',
        ordre_affichage: e.ordre_affichage,
        cadence_nominale_boite_min: e.cadence_nominale_boite_min,
        cadence_objectif_boite_min: e.cadence_objectif_boite_min,
        taux_rendement_cible: e.taux_rendement_cible,
        temps_ouverture_shift_min: e.temps_ouverture_shift_min,
        temps_pause_planifie_min: e.temps_pause_planifie_min,
        travaille_weekend: e.travaille_weekend, actif: e.actif
      } : {
        nom_equipement:'', site:'PHARMA', description_zone:'', ordre_affichage:9999,
        cadence_nominale_boite_min:null, cadence_objectif_boite_min:null,
        taux_rendement_cible:85, temps_ouverture_shift_min:480, temps_pause_planifie_min:30,
        travaille_weekend:false, actif:true
      }
      modal.show = true
    }

    var saveModal = async function() {
      if (!modal.d.nom_equipement || !modal.d.nom_equipement.trim()) { modal.error='Le nom est requis.'; return }
      modal.saving = true
      var payload = Object.assign({}, modal.d, { nom_equipement: modal.d.nom_equipement.trim(), updated_at: new Date().toISOString() })
      var r = modal.editing
        ? await supabase.from('equipements_conditionnement').update(payload).eq('id', modal.editing.id)
        : await supabase.from('equipements_conditionnement').insert(payload)
      if (r.error) { modal.error = r.error.message; modal.saving = false; return }
      modal.show = false; modal.saving = false
      await loadEquipements()
    }

    var openObjectifs = async function(e) {
      objModal.equip = e
      objModal.rows  = []
      objModal.newRow = { product_id:null, product_search:'', shift_id:null, cadence_objectif_boite_min:null, colisage_ref:null, commentaire:'' }
      objModal.prodSuggestions = []
      var r = await supabase.from('objectifs_production')
        .select('*, products(code_article,description), shifts(nom)')
        .eq('equipement_id', e.id)
        .order('created_at')
      if (r.data) objModal.rows = r.data
      objModal.show = true
    }

    var searchProducts = function() {
      clearTimeout(prodSearchTimeout)
      var q = objModal.newRow.product_search
      if (!q || q.length < 2) { objModal.prodSuggestions = []; return }
      prodSearchTimeout = setTimeout(async function() {
        var r = await supabase.from('products').select('id,code_article,description')
          .or('code_article.ilike.%'+q+'%,description.ilike.%'+q+'%').limit(6)
        objModal.prodSuggestions = r.data || []
      }, 200)
    }

    var selectProd = function(p) {
      objModal.newRow.product_id = p.id
      objModal.newRow.product_search = p.code_article
      objModal.prodSuggestions = []
    }

    var addObj = async function() {
      if (!objModal.newRow.cadence_objectif_boite_min) return
      objModal.saving = true
      var r = await supabase.from('objectifs_production').insert({
        equipement_id: objModal.equip.id,
        product_id: objModal.newRow.product_id || null,
        shift_id: objModal.newRow.shift_id || null,
        cadence_objectif_boite_min: objModal.newRow.cadence_objectif_boite_min,
        colisage_ref: objModal.newRow.colisage_ref || null,
        commentaire: objModal.newRow.commentaire || null,
        actif: true
      })
      if (!r.error) await openObjectifs(objModal.equip)
      objModal.saving = false
    }

    var deleteObj = async function(id) {
      await supabase.from('objectifs_production').delete().eq('id', id)
      await openObjectifs(objModal.equip)
    }

    onMounted(async function() { await loadEquipements(); await loadShifts() })

    return {
      equipements, shifts, loading, filterSite, filteredEquipements,
      modal, objModal, trsClass,
      openModal, saveModal, openObjectifs, searchProducts, selectProd, addObj, deleteObj
    }
  }
}
</script>

<style scoped>
.ph{padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:16px;display:flex;align-items:center;justify-content:space-between}
.pt{font-size:11px;font-weight:500;letter-spacing:1.5px}
.btn-add-top{font-size:12px;padding:6px 14px;background:#0a0a0a;color:#fff;border:none;border-radius:2px;cursor:pointer}
.btn-add-top:hover{background:#333}
.site-tabs{display:flex;gap:4px;margin-bottom:14px}
.site-tab{padding:5px 14px;font-size:12px;border:1px solid #ddd;background:#fff;border-radius:2px;cursor:pointer}
.site-tab.active{background:#0a0a0a;color:#fff;border-color:#0a0a0a}
.loading{padding:20px;text-align:center;color:#999;font-size:13px}
.eq-table{width:100%;border-collapse:collapse;font-size:12px}
.eq-table th{background:#f5f5f5;padding:8px 10px;text-align:left;font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.4px;border-bottom:2px solid #e0e0e0;white-space:nowrap}
.eq-table th.num-col{text-align:center}
.eq-table td{padding:9px 10px;border-bottom:1px solid #f0f0f0;vertical-align:middle}
.eq-table tr.inactive td{opacity:.45}
.eq-nom{font-weight:500;font-size:13px}
.eq-zone{font-size:10px;color:#999;margin-top:2px}
.num{text-align:center;font-family:'SF Mono',monospace;font-size:12px}
.num.obj{font-weight:600;color:#185FA5}
.ctr{text-align:center;font-size:13px}
.site-badge{font-size:10px;font-weight:600;padding:2px 7px;border-radius:8px;letter-spacing:.5px}
.pharma{background:#EBF5FF;color:#0C447C}
.otc{background:#F0FDF4;color:#15803D}
.stat-badge{font-size:10px;padding:2px 7px;border-radius:8px}
.actif{background:#F0FDF4;color:#15803D}
.inactif{background:#F5F5F5;color:#999}
.trs-val{font-family:'SF Mono',monospace;font-size:12px;font-weight:600;padding:1px 6px;border-radius:3px}
.trs-green{background:#F0FDF4;color:#15803D}
.trs-orange{background:#FFF7ED;color:#C2410C}
.trs-red{background:#FEF2F2;color:#DC2626}
.acts{text-align:right;white-space:nowrap}
.ia{background:none;border:none;cursor:pointer;font-size:13px;padding:3px 6px;border-radius:2px;opacity:.7}
.ia:hover{background:#e8e8e8;opacity:1}
.ia.del:hover{background:#fde8e8}
.empty{padding:24px;text-align:center;color:#999;font-size:13px}
.empty-small{font-size:12px;color:#aaa;padding:10px 0}

/* Modal */
.overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:100}
.modal{background:#fff;padding:24px;width:520px;max-width:96vw;border-radius:6px;max-height:90vh;overflow-y:auto}
.modal-lg{width:720px}
.modal-hd{font-size:14px;font-weight:600;margin-bottom:16px}
.section-title{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:1px;color:#666;padding:10px 0 6px;border-bottom:1px solid #f0f0f0;margin-bottom:8px}
.form-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.fg-full{grid-column:span 2}
.lbl{display:block;font-size:11px;color:#666;text-transform:uppercase;letter-spacing:.3px;margin-bottom:4px;margin-top:8px}
.inp{width:100%;padding:8px 10px;border:1px solid #ddd;font-size:13px;outline:none;box-sizing:border-box;font-family:inherit;border-radius:2px}
.inp:focus{border-color:#185FA5}
.field-hint{font-size:10px;color:#aaa;margin-top:3px}
.obj-preview{background:#f0f7ff;border:1px solid #bee3f8;border-radius:4px;padding:10px 14px;display:flex;flex-direction:column;justify-content:center}
.op-label{font-size:10px;text-transform:uppercase;letter-spacing:.5px;color:#555;margin-bottom:2px}
.op-val{font-size:20px;font-weight:600;font-family:'SF Mono',monospace;color:#185FA5}
.op-sub{font-size:10px;color:#888;margin-top:2px;font-family:'SF Mono',monospace}
.check-row{display:flex;gap:20px;margin-top:12px}
.chk-item{display:flex;align-items:center;gap:6px;font-size:13px;cursor:pointer}
.err{color:#E24B4A;font-size:12px;margin-top:10px;padding:6px 10px;background:#FEF2F2;border-radius:3px}
.modal-acts{display:flex;gap:8px;margin-top:16px}
.btn-save{padding:10px 20px;background:#185FA5;color:#fff;border:none;font-size:13px;font-weight:500;cursor:pointer;border-radius:2px}
.btn-save:hover:not(:disabled){background:#0C447C}
.btn-save:disabled{opacity:.5}
.btn-cancel{padding:10px 20px;background:#f5f5f5;color:#666;border:none;font-size:13px;cursor:pointer;border-radius:2px}
.btn-cancel:hover{background:#eee}

/* Objectifs */
.obj-info{font-size:12px;color:#555;margin-bottom:12px;padding:8px 12px;background:#f8f8f8;border-radius:3px}
.obj-table{width:100%;border-collapse:collapse;font-size:12px;margin-bottom:8px}
.obj-table th{background:#f5f5f5;padding:6px 10px;font-size:10px;text-transform:uppercase;letter-spacing:.4px;text-align:left;border-bottom:1px solid #e0e0e0}
.obj-table td{padding:7px 10px;border-bottom:1px solid #f0f0f0}
.small-txt{font-size:11px;color:#888}
.prod-suggestions{border:1px solid #ddd;border-radius:3px;margin-top:2px;max-height:160px;overflow-y:auto;background:#fff;position:relative;z-index:10}
.ps-item{display:flex;gap:8px;padding:7px 10px;cursor:pointer;font-size:12px}
.ps-item:hover{background:#f5f5f5}
.ps-code{font-family:'SF Mono',monospace;font-weight:500;color:#185FA5;min-width:80px}
.ps-desc{color:#666;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
</style>
