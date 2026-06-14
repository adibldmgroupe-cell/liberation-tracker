<template>
  <div class="products-catalog">

    <!-- ── En-tête ── -->
    <div class="fa-header">
      <div>
        <div class="fa-title"><NavIcon name="package" :size="18" /> Catalogue Produits Finis</div>
        <div class="fa-sub">{{ products.length }} produit(s) au total · {{ filtered.length }} affiché(s)</div>
      </div>
      <div class="fa-actions">
        <button class="fa-btn-gs-reload" :disabled="!gsUrl || gsImporting" @click="importFromGs">
          <span v-if="gsImporting">⟳ Import… {{ gsProgress }}%</span>
          <span v-else><NavIcon name="refresh" :size="13" /> Actualiser le catalogue</span>
        </button>
        <button class="fa-btn-gs-reload" @click="showGsConfig=!showGsConfig"><template v-if="showGsConfig"><NavIcon name="chevron-up" :size="12" /> Config</template><template v-else><NavIcon name="settings" :size="13" /> Config GS</template></button>
      </div>
    </div>

    <!-- Config Google Sheets -->
    <div v-if="showGsConfig" class="gs-bar">
      <span class="gs-icon"><NavIcon name="link" :size="14" /></span>
      <span class="gs-label">Google Sheets PF</span>
      <span v-if="gsUrl" class="gs-url-hint">{{ gsUrl.slice(0, 60) }}…</span>
      <input v-model="gsUrl" class="gs-url-inp" type="url" placeholder="URL CSV Google Sheets" @change="saveGsUrl" />
    </div>

    <div v-if="gsImporting" class="gs-prog-bar">
      <div class="gs-prog-fill" :style="{width: gsProgress+'%'}"></div>
    </div>

    <div v-if="gsStats" class="gs-result">
      <span class="gs-stat c">+{{ gsStats.created }} créés</span>
      <span class="gs-stat u">{{ gsStats.updated }} mis à jour</span>
      <span v-if="gsStats.errors.length" class="gs-stat e">{{ gsStats.errors.length }} erreur(s)</span>
      <span class="gs-stat-close" @click="gsStats=null"><NavIcon name="x" :size="13" /></span>
    </div>

    <!-- ── Toolbar ── -->
    <div class="tb-toolbar">
      <div class="tb-search-wrap">
        <span class="ts-icon"><NavIcon name="search" :size="14" /></span>
        <input v-model="searchQ" class="tb-search" placeholder="Rechercher code, description, DCI…" />
      </div>
      <div class="tb-filters">
        <button class="tb-btn-add" @click="openCreate">+ Nouveau produit</button>
      </div>
    </div>

    <div v-if="loading" class="em">Chargement…</div>
    <div v-else-if="!filtered.length" class="em">{{ searchQ ? 'Aucun résultat.' : 'Aucun produit. Importez depuis Google Sheets ou ajoutez manuellement.' }}</div>
    <div v-else class="table-wrap">
      <table class="pt-table">
        <thead>
          <tr>
            <th>Code article</th>
            <th>Description</th>
            <th>Groupe</th>
            <th>DCI</th>
            <th>Code DCI</th>
            <th>Colisage</th>
            <th>Durée de vie</th>
            <th>Fabricant</th>
            <th>Statut</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="p in filtered" :key="p.id" :class="{'row-off': p.actif===false}">
            <td class="mono">{{ p.code_article }}</td>
            <td class="td-desc">{{ p.description }}</td>
            <td>{{ p.groupe_article || '—' }}</td>
            <td>{{ p.dci || '—' }}</td>
            <td class="mono">{{ p.code_dci || '—' }}</td>
            <td class="mono">{{ p.quantite_par_colis || '—' }}</td>
            <td>{{ p.duree_vie ? p.duree_vie + ' mois' : '—' }}</td>
            <td>{{ p.fabricant || '—' }}</td>
            <td>
              <button class="tog" :class="p.actif!==false ? 'ton' : 'toff'" @click="toggleActif(p)">
                {{ p.actif!==false ? 'Actif' : 'Inactif' }}
              </button>
            </td>
            <td class="tar">
              <button class="btn-sm" @click="openEdit(p)">Modifier</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal ajout / modification -->
    <div class="overlay" v-if="showModal" @click.self="showModal=false">
      <div class="modal">
        <div class="mt">{{ isEdit ? 'Modifier le produit' : 'Nouveau produit' }}</div>
        <div class="modal-body-inner">
          <div class="fg">
            <div class="fi">
              <label>Code article <span class="req">*</span></label>
              <input v-model="form.code_article" class="inp" placeholder="Ex : PFABB02" :disabled="isEdit" />
            </div>
            <div class="fi">
              <label>Groupe d'article</label>
              <input v-model="form.groupe_article" class="inp" placeholder="Ex : MD.PF-Médicament" />
            </div>
          </div>
          <div class="fi">
            <label>Description <span class="req">*</span></label>
            <input v-model="form.description" class="inp" placeholder="Ex : LIPANTHYL® 160mg COM PELLI B/30" />
          </div>
          <div class="fg">
            <div class="fi">
              <label>DCI</label>
              <input v-model="form.dci" class="inp" placeholder="Ex : Fenofibrate" />
            </div>
            <div class="fi">
              <label>Code DCI</label>
              <input v-model="form.code_dci" class="inp" placeholder="Ex : 06M214" />
            </div>
          </div>
          <div class="fg">
            <div class="fi">
              <label>Durée de vie (mois)</label>
              <input v-model="form.duree_vie" class="inp" placeholder="Ex : 24" type="number" />
            </div>
            <div class="fi">
              <label>Fabricant</label>
              <input v-model="form.fabricant" class="inp" placeholder="Ex : PRODUCTION ABBOTT" />
            </div>
          </div>
          <div class="fg">
            <div class="fi">
              <label>Colisage (boîtes/colis)</label>
              <input v-model="form.quantite_par_colis" class="inp" placeholder="Ex : 30" type="number" min="1" />
            </div>
          </div>
          <div class="merr" v-if="formErr">{{ formErr }}</div>
        </div>
        <div class="ma">
          <button class="tb-btn-add" @click="submitForm" :disabled="saving">{{ saving ? '…' : isEdit ? 'Enregistrer' : 'Créer le produit' }}</button>
          <button class="bc2" @click="showModal=false">Annuler</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { canPerform } from '../services/permissions'
import NavIcon from '../components/NavIcon.vue'

var GS_KEY = 'liberation_gs_url_products'
var DEFAULT_GS_URL = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vQqKb5_i0U7YeQYMiNEDy4X2gq6W_78NA2EuC2gRqSVXOKuBcBuXR8ASrE9Eq3admceATv4_gdAUppc/pub?gid=0&single=true&output=csv'

// Parseur CSV simple gérant les guillemets
function parseCsv(text) {
  var lines = text.split(/\r?\n/).filter(function(l) { return l.trim() })
  if (!lines.length) return []
  var headers = splitCsvLine(lines[0])
  var rows = []
  for (var i = 1; i < lines.length; i++) {
    var vals = splitCsvLine(lines[i])
    if (!vals.some(function(v) { return v.trim() })) continue
    var row = {}
    headers.forEach(function(h, idx) { row[h.trim()] = (vals[idx] || '').trim() })
    rows.push(row)
  }
  return rows
}

function splitCsvLine(line) {
  var result = [], cur = '', inQ = false
  for (var i = 0; i < line.length; i++) {
    var c = line[i]
    if (c === '"') { inQ = !inQ }
    else if (c === ',' && !inQ) { result.push(cur); cur = '' }
    else { cur += c }
  }
  result.push(cur)
  return result
}

export default {
  components: { NavIcon },
  setup() {
    var products = ref([])
    var loading = ref(true)
    var searchQ = ref('')

    // Google Sheets import
    var gsUrl = ref('')
    var showGsConfig = ref(false)
    var gsImporting = ref(false)
    var gsProgress = ref(0)
    var gsStats = ref(null)

    // Modal
    var showModal = ref(false)
    var isEdit = ref(false)
    var saving = ref(false)
    var formErr = ref('')
    var editId = ref(null)
    var form = ref({ code_article: '', description: '', groupe_article: '', dci: '', code_dci: '', duree_vie: '', fabricant: '', quantite_par_colis: '' })

    var filtered = computed(function() {
      var q = searchQ.value.trim().toLowerCase()
      if (!q) return products.value
      return products.value.filter(function(p) {
        return (p.code_article || '').toLowerCase().includes(q)
          || (p.description || '').toLowerCase().includes(q)
          || (p.dci || '').toLowerCase().includes(q)
          || (p.groupe_article || '').toLowerCase().includes(q)
          || (p.fabricant || '').toLowerCase().includes(q)
      })
    })

    var loadProducts = async function() {
      loading.value = true
      var res = await supabase.from('products')
        .select('id, code_article, description, groupe_article, dci, code_dci, duree_vie, fabricant, actif, quantite_par_colis')
        .order('code_article')
      products.value = res.data || []
      loading.value = false
    }

    var saveGsUrl = async function() {
      if (!canPerform('gerer_produits')) { alert('Permission « gérer le catalogue produits » requise'); return }
      localStorage.setItem(GS_KEY, gsUrl.value || '')
      await supabase.from('app_settings').upsert({ key: 'gs_url_products', value: gsUrl.value || '' }, { onConflict: 'key' })
    }

    var importFromGs = async function() {
      if (!canPerform('gerer_produits')) { alert('Permission « gérer le catalogue produits » requise'); return }
      if (!gsUrl.value) return
      gsImporting.value = true
      gsProgress.value = 10
      gsStats.value = null
      var created = 0, updated = 0
      var errors = []

      try {
        // Fetch CSV
        var res = await fetch(gsUrl.value)
        if (!res.ok) throw new Error('Impossible de récupérer le fichier (HTTP ' + res.status + ')')
        var text = await res.text()
        gsProgress.value = 30

        var rows = parseCsv(text)
        if (!rows.length) throw new Error('Fichier vide ou format incorrect')
        gsProgress.value = 50

        // Mapper les colonnes CSV → champs DB
        var mapped = rows.map(function(r) {
          return {
            code_article: (r['code_article'] || '').trim().toUpperCase(),
            description: (r['description'] || r['Description'] || '').trim().toUpperCase(),
            groupe_article: (r["Groupe d'article"] || r['Groupe d\'article'] || r['groupe_article'] || '').trim() || null,
            dci: (r['DCI'] || r['dci'] || '').trim() || null,
            code_dci: (r['Code DCI'] || r['code_dci'] || '').trim() || null,
            duree_vie: (r['Durée de vie'] || r['Duree de vie'] || r['duree_vie'] || '').trim() || null,
            fabricant: (r['Fabricant'] || r['fabricant'] || '').trim() || null,
            quantite_par_colis: parseInt((r['quantite_par_colis'] || '').trim()) || null,
            actif: true
          }
        }).filter(function(r) { return r.code_article })

        gsProgress.value = 60

        // Récupérer les codes existants
        var codes = mapped.map(function(r) { return r.code_article })
        var existRes = await supabase.from('products').select('id, code_article').in('code_article', codes)
        var existMap = {}
        ;(existRes.data || []).forEach(function(p) { existMap[p.code_article] = p.id })

        gsProgress.value = 70

        // Séparer créations et mises à jour
        var toInsert = [], toUpdate = []
        mapped.forEach(function(r) {
          if (existMap[r.code_article]) {
            toUpdate.push({ id: existMap[r.code_article], data: r })
          } else {
            toInsert.push(r)
          }
        })

        // Insertions en batch
        if (toInsert.length) {
          var ins = await supabase.from('products').insert(toInsert)
          if (ins.error) errors.push('Insert : ' + ins.error.message)
          else created = toInsert.length
        }

        gsProgress.value = 85

        // Mises à jour en batch (upsert sur code_article)
        if (toUpdate.length) {
          var upRows = toUpdate.map(function(u) { return Object.assign({ id: u.id }, u.data) })
          var upd = await supabase.from('products').upsert(upRows, { onConflict: 'id' })
          if (upd.error) errors.push('Update : ' + upd.error.message)
          else updated = toUpdate.length
        }

        gsProgress.value = 100
        gsStats.value = { created: created, updated: updated, errors: errors }
        await loadProducts()

      } catch(e) {
        gsStats.value = { created: 0, updated: 0, errors: [e.message] }
      }

      gsImporting.value = false
    }

    // CRUD produits
    var openCreate = function() {
      isEdit.value = false; editId.value = null
      form.value = { code_article: '', description: '', groupe_article: '', dci: '', code_dci: '', duree_vie: '', fabricant: '', quantite_par_colis: '' }
      formErr.value = ''; showModal.value = true
    }

    var openEdit = function(p) {
      isEdit.value = true; editId.value = p.id
      form.value = { code_article: p.code_article, description: p.description, groupe_article: p.groupe_article || '', dci: p.dci || '', code_dci: p.code_dci || '', duree_vie: p.duree_vie || '', fabricant: p.fabricant || '', quantite_par_colis: p.quantite_par_colis || '' }
      formErr.value = ''; showModal.value = true
    }

    var submitForm = async function() {
      if (!canPerform('gerer_produits')) { alert('Permission « gérer le catalogue produits » requise'); return }
      if (!form.value.code_article.trim() || !form.value.description.trim()) { formErr.value = 'Code article et description requis'; return }
      saving.value = true; formErr.value = ''
      var data = {
        code_article: form.value.code_article.trim().toUpperCase(),
        description: form.value.description.trim().toUpperCase(),
        groupe_article: form.value.groupe_article.trim() || null,
        dci: form.value.dci.trim() || null,
        code_dci: form.value.code_dci.trim() || null,
        duree_vie: form.value.duree_vie ? String(form.value.duree_vie).trim() : null,
        fabricant: form.value.fabricant.trim() || null,
        quantite_par_colis: form.value.quantite_par_colis !== '' ? parseInt(form.value.quantite_par_colis) || null : null,
      }
      var res = isEdit.value
        ? await supabase.from('products').update(data).eq('id', editId.value)
        : await supabase.from('products').insert(Object.assign({ actif: true }, data))
      if (res.error) { formErr.value = res.error.message; saving.value = false; return }
      showModal.value = false
      await loadProducts()
      saving.value = false
    }

    var toggleActif = async function(p) {
      if (!canPerform('gerer_produits')) { alert('Permission « gérer le catalogue produits » requise'); return }
      var newVal = p.actif === false ? true : false
      await supabase.from('products').update({ actif: newVal }).eq('id', p.id)
      p.actif = newVal
    }

    onMounted(async function() {
      // Charger URL depuis localStorage puis DB
      gsUrl.value = localStorage.getItem(GS_KEY) || DEFAULT_GS_URL
      var settingRes = await supabase.from('app_settings').select('value').eq('key', 'gs_url_products').maybeSingle()
      if (settingRes.data && settingRes.data.value) {
        gsUrl.value = settingRes.data.value
        localStorage.setItem(GS_KEY, settingRes.data.value)
      } else if (gsUrl.value === DEFAULT_GS_URL) {
        // Sauvegarder l'URL par défaut en DB
        await supabase.from('app_settings').upsert({ key: 'gs_url_products', value: DEFAULT_GS_URL }, { onConflict: 'key' })
      }
      await loadProducts()
    })

    return {
      products, loading, searchQ, filtered,
      gsUrl, showGsConfig, gsImporting, gsProgress, gsStats, saveGsUrl, importFromGs,
      showModal, isEdit, saving, formErr, form,
      openCreate, openEdit, submitForm, toggleActif
    }
  }
}
</script>

<style scoped>
.products-catalog { font-family: 'Inter', sans-serif; }
.fa-actions { display:flex; align-items:center; gap:8px; flex-wrap:wrap; flex-shrink:0; }

/* Google Sheets bar */
.gs-bar { display:flex; align-items:center; gap:10px; padding:8px 14px; background:#f7fbff; border:1px solid #d0e4f8; border-radius:6px; margin-bottom:12px; flex-wrap:wrap }
.gs-bar-left { display:flex; align-items:center; gap:8px; min-width:0; flex:1 }
.gs-icon { font-size:15px; flex-shrink:0 }
.gs-label { font-size:12px; font-weight:600; color:#6b7280; white-space:nowrap }
.gs-url-hint { font-size:11px; color:#9ca3af; font-family:'SF Mono',monospace; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; min-width:0; flex:1 }
.gs-url-inp { font-size:12px; font-family:'SF Mono',monospace; border:1px solid #d1d5db; border-radius:5px; padding:6px 10px; outline:none; box-sizing:border-box; min-width:300px; flex:1 }
.gs-url-inp:focus { border-color:#2563eb }
.gs-prog-bar { height:3px; background:#ddeefa; border-radius:2px; overflow:hidden; margin-bottom:8px }
.gs-prog-fill { height:100%; background:#185FA5; transition:width .3s }
.gs-result { display:flex; align-items:center; gap:12px; padding:8px 14px; background:#f0f8f0; border:1px solid #c8e8c8; border-radius:3px; margin-bottom:10px; font-size:12px }
.gs-stat { font-weight:600 }
.gs-stat.c { color:#1D9E75 }
.gs-stat.u { color:#185FA5 }
.gs-stat.e { color:#E24B4A }
.gs-stat-close { margin-left:auto; cursor:pointer; color:#999; font-size:14px }

.bc2 { padding:7px 16px; background:#f5f5f5; color:#666; border:1px solid #e5e7eb; border-radius:5px; font-size:12px; cursor:pointer; font-family:'Inter',sans-serif; }
.bc2:hover { background:#eee }
.btn-sm { font-size:11px; padding:3px 10px; border:1px solid #e5e7eb; border-radius:4px; background:#fff; cursor:pointer; font-family:'Inter',sans-serif; }
.btn-sm:hover { background:#f5f5f5 }

.em { text-align:center; padding:40px; color:#9ca3af; font-size:13px }
.table-wrap { overflow-x:auto; overflow-y:auto; max-height:calc(100vh - 260px); border:1px solid #e5e7eb; border-radius:8px; margin-top:0 }
.pt-table { width:100%; border-collapse:collapse; font-size:12px }
.pt-table th { text-align:left; font-size:11px; font-weight:700; letter-spacing:.3px; text-transform:uppercase; color:#2563eb; padding:10px 12px; border-bottom:1px solid #dbeafe; white-space:nowrap; background:#eff6ff; position:sticky; top:0; z-index:2 }
.pt-table td { padding:9px 10px; border-bottom:1px solid #f5f5f5; vertical-align:middle }
.pt-table tr:last-child td { border-bottom:none }
.pt-table tr:hover td { background:#fafbfd }
.row-off { opacity:.4 }
.mono { font-family:'SF Mono',monospace; font-size:11px }
.td-desc { max-width:240px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis }
.tar { text-align:right }

.tog { font-size:11px; padding:3px 12px; border:none; border-radius:10px; cursor:pointer; font-weight:500 }
.ton { background:#EAF3DE; color:#3B6D11 }
.toff { background:#f5f5f5; color:#999 }

/* Modal */
.overlay { position:fixed; inset:0; background:rgba(0,0,0,.4); display:flex; align-items:center; justify-content:center; z-index:100; padding:16px }
.modal { background:#fff; border-radius:10px; box-shadow:0 20px 50px rgba(0,0,0,.2); width:100%; max-width:520px; max-height:90vh; overflow-y:auto; display:flex; flex-direction:column; }
.mt { font-size:14px; font-weight:800; padding:16px 20px 12px; border-bottom:1px solid #f3f4f6; }
.fg { display:grid; grid-template-columns:1fr 1fr; gap:12px }
.fi { display:flex; flex-direction:column; gap:4px; }
.fi label { font-size:10px; font-weight:700; color:#6b7280; text-transform:uppercase; letter-spacing:1px }
.modal-body-inner { padding:16px 20px; display:flex; flex-direction:column; gap:4px; }
.req { color:#E24B4A }
.inp { font-size:12px; padding:8px 10px; border:1px solid #e5e7eb; border-radius:5px; outline:none; font-family:'Inter',sans-serif; width:100%; box-sizing:border-box; }
.inp:focus { border-color:#2563eb }
.inp:disabled { background:#f5f5f5; color:#9ca3af; cursor:not-allowed }
.merr { font-size:11px; color:#ef4444; background:#fef2f2; padding:6px 10px; border-radius:4px; }
.ma { display:flex; gap:8px; padding:12px 20px; border-top:1px solid #f3f4f6; }

@media (max-width:640px) {
  .gs-bar { flex-direction:column; align-items:stretch }
  .gs-url-hint { display:none }
  .fg { grid-template-columns:1fr }
  .pt-table th:nth-child(3), .pt-table td:nth-child(3),
  .pt-table th:nth-child(5), .pt-table td:nth-child(5),
  .pt-table th:nth-child(6), .pt-table td:nth-child(6),
  .pt-table th:nth-child(8), .pt-table td:nth-child(8) { display:none }
}
</style>
