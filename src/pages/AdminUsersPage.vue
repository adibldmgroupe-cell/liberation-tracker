<template>
  <div class="users-page">

    <!-- ── En-tête ── -->
    <div class="fa-header">
      <div>
        <div class="fa-title"><NavIcon name="user" :size="18" /> Utilisateurs</div>
        <div class="fa-sub">{{ profiles.length }} compte(s) enregistré(s)</div>
      </div>
      <div class="fa-actions">
        <button class="tb-btn-add" @click="openCreate">+ Nouveau compte</button>
      </div>
    </div>

    <div v-if="loading" class="em">Chargement...</div>
    <div v-else-if="profiles.length" class="ut-wrap">
    <table class="ut">
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
    </div><!-- /ut-wrap -->
    <div v-else class="em">Aucun utilisateur</div>

    <!-- Modal créer / modifier -->
    <div class="overlay" v-if="showModal" @click.self="showModal=false">
      <div class="modal">
        <div class="modal-hd">{{ isEdit ? 'Modifier le compte' : 'Nouveau compte' }}</div>
        <div class="modal-body-inner">
          <div class="fg">
            <div class="fi"><label class="lbl">Prénom</label><input v-model="form.prenom" class="inp" /></div>
            <div class="fi"><label class="lbl">Nom</label><input v-model="form.nom" class="inp" /></div>
          </div>
          <template v-if="!isEdit">
            <div class="fi"><label class="lbl">Email</label><input v-model="form.email" type="email" class="inp" /></div>
            <div class="fi"><label class="lbl">Mot de passe temporaire</label><input v-model="form.password" type="text" class="inp" placeholder="min. 6 caractères" /></div>
          </template>
          <div class="fg">
            <div class="fi">
              <label class="lbl">Service</label>
              <select v-model="form.service" class="inp">
                <option v-for="svc in servicesList" :key="svc.id" :value="svc.id">{{ svc.label }}</option>
              </select>
            </div>
            <div class="fi">
              <label class="lbl">Rôle</label>
              <select v-model="form.role" class="inp">
                <option v-for="(label, key) in roleLabels" :key="key" :value="key">{{ label }}</option>
              </select>
            </div>
          </div>
          <div class="merr" v-if="formErr">{{ formErr }}</div>
        </div>
        <div class="modal-acts">
          <button class="tb-btn-add" @click="submitForm" :disabled="saving">{{ saving ? '...' : isEdit ? 'Enregistrer' : 'Créer le compte' }}</button>
          <button class="btn-cancel" @click="showModal=false">Annuler</button>
          <button v-if="isEdit" class="btn-reset" @click="sendReset">Réinitialiser MDP</button>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { canPerform } from '../services/permissions'
import { adminCreateUser, adminDeleteUser } from '../services/adminAuth'
import NavIcon from '../components/NavIcon.vue'
export default {
  components: { NavIcon },
  setup() {
    var profiles = ref([]), loading = ref(true), currentUserId = ref(null)
    var showModal = ref(false), isEdit = ref(false), saving = ref(false), formErr = ref('')
    var editId = ref(null), editEmail = ref('')
    var form = ref({ prenom: '', nom: '', email: '', password: '', service: 'aq', role: 'operateur' })

    // Services chargés depuis la DB (table services)
    var servicesList = ref([{ id: 'aq', label: 'Assurance Qualité' }]) // valeur par défaut
    var serviceLabels = computed(function() {
      var map = {}
      servicesList.value.forEach(function(s) { map[s.id] = s.label })
      return map
    })
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
      if (!canPerform('gerer_comptes')) { alert('Permission « gérer les comptes » requise'); return }
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
      if (!canPerform('gerer_comptes')) { alert('Permission « gérer les comptes » requise'); return }
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
      if (!canPerform('gerer_comptes')) { alert('Permission « gérer les comptes » requise'); return }
      if (!confirm('Supprimer le compte de ' + p.prenom + ' ' + p.nom + ' ?\nCette action est irréversible.')) return
      try {
        await adminDeleteUser(p.id)
        await loadProfiles()
      } catch(e) {
        alert('Erreur : ' + (e.message || 'Impossible de supprimer le compte'))
      }
    }

    var sendReset = async function() {
      if (!canPerform('gerer_comptes')) { alert('Permission « gérer les comptes » requise'); return }
      var { error } = await supabase.auth.resetPasswordForEmail(editEmail.value)
      if (error) { alert('Erreur : ' + error.message); return }
      alert('Email de réinitialisation envoyé à ' + editEmail.value)
    }

    var loadServices = async function() {
      var res = await supabase.from('services').select('id, label, sort_order').order('sort_order')
      if (res.data && res.data.length) servicesList.value = res.data
    }

    onMounted(async function() {
      var u = await supabase.auth.getUser()
      currentUserId.value = u.data.user ? u.data.user.id : null
      await Promise.all([loadProfiles(), loadServices()])
    })

    return {
      profiles, loading, currentUserId, showModal, isEdit, saving, formErr, form,
      servicesList, serviceLabels, roleLabels, initials, fmtDate,
      toggleActive, openCreate, openEdit, submitForm, confirmDelete, sendReset
    }
  }
}
</script>
<style scoped>
.users-page{font-family:'Inter',sans-serif;font-size:13px;}
.fa-actions{display:flex;align-items:center;gap:8px;flex-shrink:0;}

/* Table */
.ut-wrap{overflow-x:auto;overflow-y:auto;max-height:calc(100vh - 220px);border:1px solid #e5e7eb;border-radius:8px;}
.ut{width:100%;border-collapse:collapse;font-size:13px}
.ut th{text-align:left;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.3px;color:#2563eb;padding:10px 12px;border-bottom:1px solid #dbeafe;background:#eff6ff;position:sticky;top:0;z-index:2}
.ut td{padding:10px 12px;border-bottom:1px solid #f3f4f6;vertical-align:middle}
.row-off{opacity:.4}

/* User cell */
.ua{display:flex;align-items:center;gap:10px}
.av{width:32px;height:32px;border-radius:50%;background:#2563eb;color:#fff;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;flex-shrink:0}
.un{font-size:13px;font-weight:500;color:#111827}
.ue{font-size:11px;color:#9ca3af;margin-top:1px}

/* Badges */
.sb{font-size:11px;background:#dbeafe;color:#2563eb;padding:2px 8px;border-radius:4px;font-weight:500;white-space:nowrap}
.rb{font-size:11px;padding:2px 8px;border-radius:4px;font-weight:500}
.rb-admin{background:#fef3c7;color:#92400e}
.rb-responsable{background:#d1fae5;color:#065f46}
.rb-operateur{background:#f3f4f6;color:#6b7280}

/* Toggle actif */
.tog{font-size:11px;padding:3px 12px;border:none;border-radius:10px;cursor:pointer;font-weight:500}
.ton{background:#d1fae5;color:#065f46}
.toff{background:#f3f4f6;color:#9ca3af}

/* Action buttons */
.btn-sm{font-size:11px;padding:3px 10px;border:1px solid #e5e7eb;border-radius:4px;background:#fff;cursor:pointer;margin-left:4px;color:#374151}
.btn-sm:hover{background:#f9fafb}
.bd{border-color:#fecaca;color:#ef4444}
.bd:hover{background:#fef2f2}
.bd:disabled{opacity:.3;cursor:not-allowed}

.dim{color:#9ca3af}.mono{font-family:'SF Mono',monospace;font-size:12px}.tar{text-align:right}
.em{text-align:center;padding:40px;color:#9ca3af;font-size:13px}

/* Modal */
.overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:100}
.modal{background:#fff;width:480px;max-width:96vw;border-radius:10px;box-shadow:0 20px 50px rgba(0,0,0,.2);max-height:90vh;overflow-y:auto;display:flex;flex-direction:column;}
.modal-hd{font-size:14px;font-weight:800;padding:16px 20px 12px;border-bottom:1px solid #f3f4f6;flex-shrink:0}
.modal-body-inner{padding:16px 20px;display:flex;flex-direction:column;gap:4px;}
.modal-acts{display:flex;gap:8px;padding:12px 20px;border-top:1px solid #f3f4f6;align-items:center;flex-wrap:wrap;flex-shrink:0}
.fg{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.fi{margin-bottom:4px}
.lbl{display:block;font-size:10px;font-weight:700;color:#6b7280;text-transform:uppercase;letter-spacing:1px;margin-bottom:4px;margin-top:8px}
.inp{width:100%;padding:8px 10px;border:1px solid #e5e7eb;font-size:12px;outline:none;box-sizing:border-box;font-family:'Inter',sans-serif;border-radius:5px}
.inp:focus{border-color:#2563eb}
.merr{background:#fef2f2;color:#dc2626;font-size:11px;padding:7px 10px;border-radius:4px;margin-top:4px}
.btn-cancel{padding:9px 16px;background:#f5f5f5;color:#6b7280;border:1px solid #e5e7eb;font-size:12px;cursor:pointer;border-radius:5px;font-family:'Inter',sans-serif}
.btn-cancel:hover{background:#eee}
.btn-reset{margin-left:auto;padding:9px 14px;background:none;border:1px solid #e5e7eb;color:#6b7280;font-size:12px;cursor:pointer;border-radius:5px;font-family:'Inter',sans-serif}
.btn-reset:hover{background:#f9fafb;color:#374151}
@media(max-width:768px){
  .fg{grid-template-columns:1fr}
  .modal{width:min(92vw,480px)}
  .ut{font-size:12px}
  .ut td{padding:9px 4px}
  /* masquer Service, Créé le sur mobile — garder Utilisateur, Rôle, Statut, Actions */
  .ut th:nth-child(2),.ut td:nth-child(2),
  .ut th:nth-child(5),.ut td:nth-child(5){display:none}
  .ph{flex-direction:column;align-items:flex-start;gap:8px}
  .btn.bg{width:100%;padding:10px 16px;min-height:44px}
  .ma{flex-wrap:wrap}
  .ma .btn{min-height:44px;flex:1}
}
@media(max-width:480px){
  .ut th:nth-child(3),.ut td:nth-child(3){display:none}
  .btn-sm{min-height:36px;padding:5px 8px}
  .ua{gap:6px}
  .av{width:28px;height:28px;font-size:10px}
}
</style>
