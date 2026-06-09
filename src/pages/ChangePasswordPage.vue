<template>
  <div class="cp">
    <div class="cc">
      <div class="ch"><span class="cl">LDM GROUPE</span><span class="cs">Première connexion</span></div>
      <div class="ci">Pour des raisons de sécurité, définissez votre mot de passe personnel avant d'accéder à l'application.</div>
      <div v-if="error" class="ce">{{ error }}</div>
      <div class="f">
        <label>Nouveau mot de passe</label>
        <input v-model="pwd1" type="password" @keydown.enter="submit" placeholder="min. 8 caractères" />
      </div>
      <div class="f">
        <label>Confirmer le mot de passe</label>
        <input v-model="pwd2" type="password" @keydown.enter="submit" placeholder="ressaisir le mot de passe" />
      </div>
      <button @click="submit" :disabled="loading || !valid" class="cb">{{ loading ? 'Enregistrement…' : 'Définir mon mot de passe' }}</button>
      <button @click="logout" class="cx">Se déconnecter</button>
    </div>
  </div>
</template>
<script>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../supabase'
export default {
  setup() {
    var router = useRouter()
    var pwd1 = ref(''), pwd2 = ref(''), error = ref(''), loading = ref(false)
    var valid = computed(function() { return pwd1.value.length >= 8 && pwd1.value === pwd2.value })

    var submit = async function() {
      error.value = ''
      if (pwd1.value.length < 8) { error.value = 'Le mot de passe doit faire au moins 8 caractères.'; return }
      if (pwd1.value !== pwd2.value) { error.value = 'Les deux mots de passe ne correspondent pas.'; return }
      loading.value = true
      // 1) Changer le mot de passe de l'utilisateur connecté
      var up = await supabase.auth.updateUser({ password: pwd1.value })
      if (up.error) { error.value = up.error.message || 'Erreur lors de la mise à jour du mot de passe.'; loading.value = false; return }
      // 2) Baisser le marqueur "doit changer" sur son propre profil
      var u = await supabase.auth.getUser()
      var uid = u.data.user ? u.data.user.id : null
      if (uid) {
        var pr = await supabase.from('profiles').update({ must_change_password: false }).eq('id', uid)
        if (pr.error) { error.value = 'Mot de passe changé, mais le marqueur n\'a pas pu être mis à jour : ' + pr.error.message; loading.value = false; return }
      }
      loading.value = false
      router.push('/dashboard')
    }

    var logout = async function() { await supabase.auth.signOut(); router.push('/login') }

    return { pwd1, pwd2, error, loading, valid, submit, logout }
  }
}
</script>
<style scoped>
.cp{display:flex;align-items:center;justify-content:center;height:100vh;background:#fafafa}
.cc{width:360px;background:#fff;border:1px solid #e8e8e8;padding:32px}
.ch{text-align:center;margin-bottom:14px}
.cl{font-size:18px;font-weight:600;letter-spacing:1.5px;display:block}
.cs{font-size:11px;color:#999;text-transform:uppercase;letter-spacing:.5px}
.ci{font-size:12px;color:#666;line-height:1.5;margin-bottom:18px;text-align:center}
.ce{background:#FCEBEB;color:#A32D2D;font-size:12px;padding:8px 12px;margin-bottom:16px}
.f{margin-bottom:14px}
.f label{display:block;font-size:11px;color:#666;text-transform:uppercase;margin-bottom:4px}
.f input{width:100%;padding:8px 10px;border:1px solid #ddd;font-size:13px;outline:none;box-sizing:border-box}
.f input:focus{border-color:#185FA5}
.cb{width:100%;padding:10px;background:#0a0a0a;color:#fff;border:none;font-size:13px;font-weight:500;cursor:pointer}
.cb:hover:not(:disabled){background:#222}.cb:disabled{opacity:.5;cursor:not-allowed}
.cx{width:100%;padding:8px;margin-top:10px;background:none;border:none;color:#999;font-size:12px;cursor:pointer;text-decoration:underline}
</style>
