<template>
  <div>
    <div class="ph">
      <div>
        <div class="pt">Gestion des utilisateurs</div>
        <div class="ps">{{ profiles.length }} compte(s)</div>
      </div>
      <button class="btn bg" @click="openCreate">+ Nouveau compte</button>
    </div>

    <div v-if="loading" class="em">Chargement...</div>
    <table class="ut" v-else-if="profiles.length">
      <thead>
        <tr>
          <th>Utilisateur</th>
          <th>Service</th>
          <th>Rôle</th>
          <th>Statut</th>
          <th>Créé le</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="p in profiles" :key="p.id" :class="{'row-off': !p.is_active}">
          <td>
            <div class="ua">
              <div class="av">{{ initials(p) }}</div>
              <div>
                <div class="un">{{ p.prenom }} {{ p.nom }}</div>
                <div class="ue">{{ p.email }}</div>
              </div>
            </div>
          </td>
          <td><span class="sb">{{ serviceLabels[p.service] || p.service }}</span></td>
          <td><span class="rb" :class="'rb-'+p.role">{{ roleLabels[p.role] || p.role }}</span></td>
          <td>
            <button class="tog" :class="p.is_active ? 'ton' : 'toff'" @click="toggleActive(p)">
              {{ p.is_active ? 'Actif' : 'Inactif' }}
            </button>
          </td>
          <td class="dim mono">{{ fmtDate(p.created_at) }}</td>
          <td class="tar">
            <button class="btn-sm" @click="openEdit(p)">Modifier</button>
            <button class="btn-sm bd" @click="confirmDelete(p)" :disabled="p.id === currentUserId">Supprimer</button>
          </td>
        </tr>
      </tbody>
    </table>
    <div v-else class="em">Aucun utilisateur</div>

    <!-- Modal créer / modifier -->
    <div class="overlay" v-if="showModal" @click.self="showModal=false">
      <div class="modal">
        <div class="mt">{{ isEdit ? 'Modifier le compte' : 'Nouveau compte' }}</div>
        <div class="fg">
          <div class="fi"><label>Prénom</label><input v-model="form.prenom" class="inp" /></div>
          <div class="fi"><label>Nom</label><input v-model="form.nom" class="inp" /></div>
        </div>
        <template v-if="!isEdit">
          <div class="fi"><label>Email</label><input v-model="form.email" type="email" class="inp" /></div>
          <div class="fi"><label>Mot de passe temporaire</label><input v-model="form.password" type="text" class="inp" placeholder="min. 6 caractères" /></div>
        </template>
        <div class="fg">
          <div class="fi">
            <label>Service</label>
            <select v-model="form.service" class="inp">
              <option v-for="(label, key) in serviceLabels" :key="key" :value="key">{{ label }}</option>
            </select>
          </div>
          <div class="fi">
            <label>Rôle</label>
            <select v-model="form.role" class="inp">
              <option v-for="(label, key) in roleLabels" :key="key" :value="key">{{ label }}</option>
            </select>
          </div>
        </div>
        <div class="merr" v-if="formErr">{{ formErr }}</div>
        <div class="ma">
          <button class="btn bg" @click="submitForm" :disabled="saving">{{ saving ? '...' : isEdit ? 'Enregistrer' : 'Créer le compte' }}</button>
          <button class="btn bc2" @click="showModal=false">Annuler</button>
          <button v-if="isEdit" class="btn" style="margin-left:auto" @click="sendReset">Réinitialiser MDP</button>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import { ref, onMounted } from 'vue'
import { supabase } from '../supabase'
import { adminCreateUser, adminDeleteUser } from '../services/adminAuth'
export default {
  setup() {
    var profiles = ref([]), loading = ref(true), currentUserId = ref(null)
    var showModal = ref(false), isEdit = ref(false), saving = ref(false), formErr = ref('')
    var editId = ref(null), editEmail = ref('')
    var form = ref({ prenom: '', nom: '', email: '', password: '', service: 'aq', role: 'operateur' })

    var serviceLabels = { planification: 'Planification', stock: 'Stock', aq: 'Assurance Qualité', aq_dap: 'AQ DAP', dt: 'Direction Technique', fabrication: 'Fabrication', conditionnement: 'Conditionnement', lcq: 'Laboratoire CQ', admin: 'Administration' }
    var roleLabels = { operateur: 'Opérateur', responsable: 'Responsable', admin: 'Administrateur' }

    var initials = function(p) { return ((p.prenom || '').charAt(0) + (p.nom || '').charAt(0)).toUpperCase() }
    var fmtDate = function(d) { return d ? new Date(d).toLocaleDateString('fr-FR') : '—' }

    var loadProfiles = async function() {
      loading.value = true
      var res = await supabase.from('profiles').select('*').order('nom')
      profiles.value = res.data || []
      loading.value = false
    }

    var toggleActive = async function(p) {
      var newVal = !p.is_active
      await supabase.from('profiles').update({ is_active: newVal }).eq('id', p.id)
      p.is_active = newVal
    }

    var openCreate = function() {
      isEdit.value = false
      form.value = { prenom: '', nom: '', email: '', password: '', service: 'aq', role: 'operateur' }
      formErr.value = ''
      showModal.value = true
    }

    var openEdit = function(p) {
      isEdit.value = true
      editId.value = p.id
      editEmail.value = p.email
      form.value = { prenom: p.prenom, nom: p.nom, email: p.email, password: '', service: p.service, role: p.role }
      formErr.value = ''
      showModal.value = true
    }

    var submitForm = async function() {
      if (!form.value.prenom || !form.value.nom) { formErr.value = 'Prénom et nom requis'; return }
      saving.value = true; formErr.value = ''
      try {
        if (isEdit.value) {
          var { error } = await supabase.from('profiles').update({
            prenom: form.value.prenom,
            nom: form.value.nom,
            service: form.value.service,
            role: form.value.role
          }).eq('id', editId.value)
          if (error) throw error
        } else {
          if (!form.value.email || !form.value.password) { formErr.value = 'Email et mot de passe requis'; saving.value = false; return }
          await adminCreateUser({
            email: form.value.email,
            password: form.value.password,
            nom: form.value.nom,
            prenom: form.value.prenom,
            service: form.value.service,
            role: form.value.role
          })
        }
        showModal.value = false
        // Petit délai pour laisser le trigger PostgreSQL créer le profil
        await new Promise(function(r){ setTimeout(r, 800) })
        await loadProfiles()
      } catch(e) {
        formErr.value = e.message || 'Une erreur est survenue'
      }
      saving.value = false
    }

    var confirmDelete = async function(p) {
      if (!confirm('Supprimer le compte de ' + p.prenom + ' ' + p.nom + ' ?\nCette action est irréversible.')) return
      try {
        await adminDeleteUser(p.id)
        await loadProfiles()
      } catch(e) {
        alert('Erreur : ' + (e.message || 'Impossible de supprimer le compte'))
      }
    }

    var sendReset = async function() {
      var { error } = await supabase.auth.resetPasswordForEmail(editEmail.value)
      if (error) { alert('Erreur : ' + error.message); return }
      alert('Email de réinitialisation envoyé à ' + editEmail.value)
    }

    onMounted(async function() {
      var u = await supabase.auth.getUser()
      currentUserId.value = u.data.user ? u.data.user.id : null
      await loadProfiles()
    })

    return {
      profiles, loading, currentUserId, showModal, isEdit, saving, formErr, form,
      serviceLabels, roleLabels, initials, fmtDate,
      toggleActive, openCreate, openEdit, submitForm, confirmDelete, sendReset
    }
  }
}
</script>
<style scoped>
.ph{display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:16px}
.pt{font-size:18px;font-weight:500}.ps{font-size:12px;color:#999;margin-top:4px}
.btn{font-size:12px;padding:7px 16px;border:none;border-radius:2px;cursor:pointer;font-weight:500;background:#185FA5;color:#fff}.btn:hover{opacity:.9}
.bg{background:#1D9E75}.bc2{background:#f5f5f5;color:#666;border:1px solid #e8e8e8}
.btn-sm{font-size:11px;padding:3px 10px;border:1px solid #ddd;border-radius:2px;background:#fff;cursor:pointer;margin-left:4px}.btn-sm:hover{background:#f5f5f5}
.bd{border-color:#E24B4A;color:#E24B4A}.bd:hover{background:#FCEBEB}.bd:disabled{opacity:.3;cursor:not-allowed}
.ut{width:100%;border-collapse:collapse;font-size:13px}
.ut th{text-align:left;font-size:10px;text-transform:uppercase;letter-spacing:.5px;color:#999;padding:8px;border-bottom:2px solid #e8e8e8;font-weight:500}
.ut td{padding:10px 8px;border-bottom:1px solid #f5f5f5;vertical-align:middle}
.row-off{opacity:.4}
.ua{display:flex;align-items:center;gap:10px}
.av{width:32px;height:32px;border-radius:50%;background:#185FA5;color:#fff;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:600;flex-shrink:0}
.un{font-size:13px;font-weight:500}.ue{font-size:11px;color:#999;margin-top:1px}
.sb{font-size:11px;background:#E6F1FB;color:#0C447C;padding:2px 8px;border-radius:2px;font-weight:500;white-space:nowrap}
.rb{font-size:11px;padding:2px 8px;border-radius:2px;font-weight:500}
.rb-admin{background:#FFF3CD;color:#664D03}.rb-responsable{background:#EAF3DE;color:#3B6D11}.rb-operateur{background:#f5f5f5;color:#666}
.tog{font-size:11px;padding:3px 12px;border:none;border-radius:10px;cursor:pointer;font-weight:500}
.ton{background:#EAF3DE;color:#3B6D11}.toff{background:#f5f5f5;color:#999}
.dim{color:#999}.mono{font-family:'SF Mono',monospace;font-size:12px}.tar{text-align:right}
.em{text-align:center;padding:40px;color:#999;font-size:13px}
.overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:100}
.modal{background:#fff;padding:24px;width:480px;border-radius:4px;max-height:90vh;overflow-y:auto}
.mt{font-size:16px;font-weight:500;margin-bottom:16px}
.fg{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.fi{margin-bottom:12px}.fi label{display:block;font-size:11px;color:#666;text-transform:uppercase;margin-bottom:4px}
.inp{width:100%;padding:7px 10px;border:1px solid #ddd;font-size:13px;outline:none;box-sizing:border-box;font-family:inherit;border-radius:2px}.inp:focus{border-color:#185FA5}
.merr{background:#FCEBEB;color:#A32D2D;font-size:12px;padding:8px;margin-bottom:12px;border-radius:2px}
.ma{display:flex;gap:8px;margin-top:16px;align-items:center;flex-wrap:wrap}
@media(max-width:768px){.fg{grid-template-columns:1fr}.ut td{padding:8px 4px;font-size:12px}.modal{width:90%}}
</style>
