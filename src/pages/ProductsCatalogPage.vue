<template>
  <div>
    <div class="ph">
      <div>
        <div class="pt">Catalogue Produits Finis</div>
        <div class="ps">{{ filtered.length }} produit(s){{ searchQ ? ' trouvé(s)' : '' }}</div>
      </div>
      <div class="ph-actions">
        <input v-model="searchQ" class="search-inp" placeholder="Rechercher code, description, DCI…" />
        <button class="btn bg" @click="openCreate">+ Nouveau produit</button>
      </div>
    </div>

    <div v-if="loading" class="em">Chargement…</div>
    <div v-else-if="!filtered.length" class="em">{{ searchQ ? 'Aucun résultat.' : 'Aucun produit. Cliquez sur + Nouveau produit pour commencer.' }}</div>
    <div v-else class="table-wrap">
      <table class="pt-table">
        <thead>
          <tr>
            <th>Code article</th>
            <th>Description</th>
            <th>Groupe</th>
            <th>DCI</th>
            <th>Code DCI</th>
            <th>Durée de vie</th>
            <th>Fabricant</th>
            <th>Statut</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="p in filtered" :key="p.id" :class="{'row-off': !p.actif}">
            <td class="mono">{{ p.code_article }}</td>
            <td class="td-desc">{{ p.description }}</td>
            <td>{{ p.groupe_article || '—' }}</td>
            <td>{{ p.dci || '—' }}</td>
            <td class="mono">{{ p.code_dci || '—' }}</td>
            <td>{{ p.duree_vie || '—' }}</td>
            <td>{{ p.fabricant || '—' }}</td>
            <td>
              <button class="tog" :class="p.actif ? 'ton' : 'toff'" @click="toggleActif(p)">
                {{ p.actif ? 'Actif' : 'Inactif' }}
              </button>
            </td>
            <td class="tar">
              <button class="btn-sm" @click="openEdit(p)">Modifier</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal -->
    <div class="overlay" v-if="showModal" @click.self="showModal=false">
      <div class="modal">
        <div class="mt">{{ isEdit ? 'Modifier le produit' : 'Nouveau produit' }}</div>

        <div class="fg">
          <div class="fi">
            <label>Code article <span class="req">*</span></label>
            <input v-model="form.code_article" class="inp" placeholder="Ex : 100123" :disabled="isEdit" />
          </div>
          <div class="fi">
            <label>Groupe d'article</label>
            <input v-model="form.groupe_article" class="inp" placeholder="Ex : ANTIBIOTIQUES" />
          </div>
        </div>

        <div class="fi">
          <label>Description <span class="req">*</span></label>
          <input v-model="form.description" class="inp" placeholder="Ex : AMOXICILLINE 500MG GELULE" />
        </div>

        <div class="fg">
          <div class="fi">
            <label>DCI</label>
            <input v-model="form.dci" class="inp" placeholder="Ex : Amoxicilline" />
          </div>
          <div class="fi">
            <label>Code DCI</label>
            <input v-model="form.code_dci" class="inp" placeholder="Ex : J01CA04" />
          </div>
        </div>

        <div class="fg">
          <div class="fi">
            <label>Durée de vie</label>
            <input v-model="form.duree_vie" class="inp" placeholder="Ex : 24 mois" />
          </div>
          <div class="fi">
            <label>Fabricant</label>
            <input v-model="form.fabricant" class="inp" placeholder="Ex : LDM Pharma" />
          </div>
        </div>

        <div class="merr" v-if="formErr">{{ formErr }}</div>
        <div class="ma">
          <button class="btn bg" @click="submitForm" :disabled="saving">{{ saving ? '…' : isEdit ? 'Enregistrer' : 'Créer le produit' }}</button>
          <button class="btn bc2" @click="showModal=false">Annuler</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'

export default {
  setup() {
    var products = ref([])
    var loading = ref(true)
    var searchQ = ref('')
    var showModal = ref(false)
    var isEdit = ref(false)
    var saving = ref(false)
    var formErr = ref('')
    var editId = ref(null)
    var form = ref({ code_article: '', description: '', groupe_article: '', dci: '', code_dci: '', duree_vie: '', fabricant: '' })

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
      var res = await supabase.from('products').select('id, code_article, description, groupe_article, dci, code_dci, duree_vie, fabricant, actif').order('code_article')
      products.value = (res.data || []).map(function(p) {
        return Object.assign({ actif: true }, p)
      })
      loading.value = false
    }

    var openCreate = function() {
      isEdit.value = false
      editId.value = null
      form.value = { code_article: '', description: '', groupe_article: '', dci: '', code_dci: '', duree_vie: '', fabricant: '' }
      formErr.value = ''
      showModal.value = true
    }

    var openEdit = function(p) {
      isEdit.value = true
      editId.value = p.id
      form.value = { code_article: p.code_article, description: p.description, groupe_article: p.groupe_article || '', dci: p.dci || '', code_dci: p.code_dci || '', duree_vie: p.duree_vie || '', fabricant: p.fabricant || '' }
      formErr.value = ''
      showModal.value = true
    }

    var submitForm = async function() {
      if (!form.value.code_article.trim() || !form.value.description.trim()) { formErr.value = 'Code article et description requis'; return }
      saving.value = true; formErr.value = ''
      var data = {
        code_article: form.value.code_article.trim().toUpperCase(),
        description: form.value.description.trim().toUpperCase(),
        groupe_article: form.value.groupe_article.trim() || null,
        dci: form.value.dci.trim() || null,
        code_dci: form.value.code_dci.trim() || null,
        duree_vie: form.value.duree_vie.trim() || null,
        fabricant: form.value.fabricant.trim() || null,
      }
      var res
      if (isEdit.value) {
        res = await supabase.from('products').update(data).eq('id', editId.value)
      } else {
        data.actif = true
        res = await supabase.from('products').insert(data)
      }
      if (res.error) { formErr.value = res.error.message; saving.value = false; return }
      showModal.value = false
      await loadProducts()
      saving.value = false
    }

    var toggleActif = async function(p) {
      var newVal = !p.actif
      await supabase.from('products').update({ actif: newVal }).eq('id', p.id)
      p.actif = newVal
    }

    onMounted(loadProducts)

    return { products, loading, searchQ, filtered, showModal, isEdit, saving, formErr, form, openCreate, openEdit, submitForm, toggleActif }
  }
}
</script>

<style scoped>
.ph { display:flex; align-items:flex-start; justify-content:space-between; gap:12px; margin-bottom:16px; flex-wrap:wrap }
.pt { font-size:11px; font-weight:500; letter-spacing:1.5px; text-transform:uppercase }
.ps { font-size:12px; color:#999; margin-top:3px }
.ph-actions { display:flex; align-items:center; gap:8px; flex-wrap:wrap }
.search-inp { font-size:12px; padding:6px 10px; border:1px solid #ddd; border-radius:2px; outline:none; width:220px; font-family:inherit }
.search-inp:focus { border-color:#185FA5 }

.btn { font-size:12px; padding:7px 16px; border:none; border-radius:2px; cursor:pointer; font-weight:500; font-family:inherit }
.bg { background:#1D9E75; color:#fff }
.bg:hover { background:#168a64 }
.bc2 { background:#f5f5f5; color:#666; border:1px solid #e8e8e8 }
.btn-sm { font-size:11px; padding:3px 10px; border:1px solid #ddd; border-radius:2px; background:#fff; cursor:pointer; font-family:inherit }
.btn-sm:hover { background:#f5f5f5 }

.em { text-align:center; padding:40px; color:#999; font-size:13px }

.table-wrap { overflow-x:auto; border:1px solid #e8e8e8; border-radius:2px }
.pt-table { width:100%; border-collapse:collapse; font-size:13px }
.pt-table th { text-align:left; font-size:10px; text-transform:uppercase; letter-spacing:.5px; color:#999; padding:8px 10px; border-bottom:2px solid #e8e8e8; font-weight:500; white-space:nowrap; background:#fafafa }
.pt-table td { padding:9px 10px; border-bottom:1px solid #f5f5f5; vertical-align:middle }
.pt-table tr:last-child td { border-bottom:none }
.pt-table tr:hover td { background:#fafbfd }
.row-off { opacity:.4 }
.mono { font-family:'SF Mono',monospace; font-size:11px }
.td-desc { max-width:220px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis }
.tar { text-align:right }

.tog { font-size:11px; padding:3px 12px; border:none; border-radius:10px; cursor:pointer; font-weight:500 }
.ton { background:#EAF3DE; color:#3B6D11 }
.toff { background:#f5f5f5; color:#999 }

/* Modal */
.overlay { position:fixed; inset:0; background:rgba(0,0,0,.35); display:flex; align-items:center; justify-content:center; z-index:100; padding:16px }
.modal { background:#fff; border-radius:4px; padding:24px; width:100%; max-width:520px; max-height:90vh; overflow-y:auto }
.mt { font-size:15px; font-weight:600; margin-bottom:18px }
.fg { display:grid; grid-template-columns:1fr 1fr; gap:12px }
.fi { display:flex; flex-direction:column; gap:5px; margin-bottom:12px }
.fi label { font-size:11px; font-weight:500; color:#666; text-transform:uppercase; letter-spacing:.5px }
.req { color:#E24B4A }
.inp { font-size:13px; padding:8px 10px; border:1px solid #ddd; border-radius:2px; outline:none; font-family:inherit }
.inp:focus { border-color:#185FA5 }
.inp:disabled { background:#f5f5f5; color:#999; cursor:not-allowed }
.merr { font-size:12px; color:#E24B4A; margin-bottom:10px }
.ma { display:flex; gap:8px; margin-top:4px }

@media (max-width: 640px) {
  .ph { flex-direction:column }
  .ph-actions { width:100% }
  .search-inp { width:100%; flex:1 }
  .fg { grid-template-columns:1fr }
  .pt-table th:nth-child(3), .pt-table td:nth-child(3),
  .pt-table th:nth-child(5), .pt-table td:nth-child(5),
  .pt-table th:nth-child(7), .pt-table td:nth-child(7) { display:none }
}
</style>
