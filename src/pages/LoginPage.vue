<template>
  <div class="lp">
    <div class="lc">
      <div class="lh"><span class="ll">LDM GROUPE</span><span class="ls">Suivi Libération PF</span></div>
      <div v-if="error" class="le">{{ error }}</div>
      <div class="f"><label>Email</label><input v-model="email" type="email" @keydown.enter="login" placeholder="votre.email@ldm.dz" /></div>
      <div class="f"><label>Mot de passe</label><input v-model="password" type="password" @keydown.enter="login" placeholder="••••••" /></div>
      <button @click="login" :disabled="loading" class="lb">{{ loading ? 'Connexion...' : 'Se connecter' }}</button>
    </div>
  </div>
</template>
<script>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../supabase'
export default {
  setup() {
    const router = useRouter(), email = ref(''), password = ref(''), error = ref(''), loading = ref(false)
    const login = async () => {
      if (!email.value || !password.value) return
      loading.value = true; error.value = ''
      const { error: err } = await supabase.auth.signInWithPassword({ email: email.value, password: password.value })
      if (err) { error.value = 'Identifiants incorrects'; loading.value = false; return }
      router.push('/dashboard')
    }
    return { email, password, error, loading, login }
  }
}
</script>
<style scoped>
.lp{display:flex;align-items:center;justify-content:center;height:100vh;background:#fafafa}
.lc{width:340px;background:#fff;border:1px solid #e8e8e8;padding:32px}
.lh{text-align:center;margin-bottom:24px}.ll{font-size:18px;font-weight:600;letter-spacing:1.5px;display:block}
.ls{font-size:11px;color:#999;text-transform:uppercase;letter-spacing:.5px}
.le{background:#FCEBEB;color:#A32D2D;font-size:12px;padding:8px 12px;margin-bottom:16px}
.f{margin-bottom:14px}.f label{display:block;font-size:11px;color:#666;text-transform:uppercase;margin-bottom:4px}
.f input{width:100%;padding:8px 10px;border:1px solid #ddd;font-size:13px;outline:none;box-sizing:border-box}.f input:focus{border-color:#185FA5}
.lb{width:100%;padding:10px;background:#0a0a0a;color:#fff;border:none;font-size:13px;font-weight:500;cursor:pointer}.lb:hover{background:#222}.lb:disabled{opacity:.5}
</style>
