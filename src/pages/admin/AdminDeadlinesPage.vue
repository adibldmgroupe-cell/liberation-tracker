<template>
  <div class="dl-page" v-if="loaded">
    <div class="dl-head">
      <div class="dl-title">⏱ Délais documentaires</div>
      <div class="dl-sub">Délai de traitement (en jours) par <b>service</b> et par <b>type</b>. Le compteur démarre à l'arrivée de l'item au niveau du service (accusé de réception ; réception du lot pour l'émission). À l'échéance, la tâche correspondante est signalée dans « Tâches ». Laisser vide = aucun délai.</div>
    </div>
    <div class="dl-grid-wrap">
      <table class="dl-grid">
        <thead>
          <tr>
            <th class="dl-corner">Service \ Type</th>
            <th v-for="t in TYPES" :key="t.key">{{t.label}}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in SERVICES" :key="s.key">
            <td class="dl-svc">{{s.label}}</td>
            <td v-for="t in TYPES" :key="t.key" class="dl-cell">
              <template v-if="s.types.includes(t.key)">
                <input type="number" min="0" class="dl-input" :value="vals[s.key+'|'+t.key]"
                       @change="onSave(s.key, t.key, $event)" placeholder="—" />
                <span class="dl-unit">j</span>
              </template>
              <span v-else class="dl-na">·</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <div class="dl-foot">
      <span class="dl-saved" v-if="savedMsg">{{savedMsg}}</span>
    </div>
  </div>
  <div v-else class="dl-loading">Chargement…</div>
</template>
<script>
import { ref, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { DEADLINE_TYPES, DEADLINE_SERVICES } from '../../services/deadlines'
export default {
  setup() {
    var TYPES = DEADLINE_TYPES
    var SERVICES = DEADLINE_SERVICES
    var vals = ref({})
    var loaded = ref(false)
    var savedMsg = ref('')

    var load = async function() {
      var r = await supabase.from('document_deadlines').select('service,type_key,delai_jours')
      var m = {}
      ;(r.data || []).forEach(function(d) { m[d.service + '|' + d.type_key] = d.delai_jours })
      vals.value = m
      loaded.value = true
    }

    var onSave = async function(service, typeKey, ev) {
      var raw = (ev.target.value || '').trim()
      var key = service + '|' + typeKey
      var u = await supabase.auth.getUser(); var uid = u.data.user ? u.data.user.id : null
      var now = new Date().toISOString()
      if (raw === '') {
        var dRes = await supabase.from('document_deadlines').delete().eq('service', service).eq('type_key', typeKey)
        if (dRes.error) { alert('Erreur : ' + dRes.error.message); return }
        delete vals.value[key]
      } else {
        var n = parseInt(raw, 10); if (isNaN(n) || n < 0) n = 0
        var res = await supabase.from('document_deadlines')
          .upsert({ service: service, type_key: typeKey, delai_jours: n, updated_at: now, updated_by: uid }, { onConflict: 'service,type_key' })
        if (res.error) { alert('Erreur : ' + res.error.message); return }
        vals.value[key] = n
        ev.target.value = n
      }
      savedMsg.value = '✓ Enregistré'
      setTimeout(function() { savedMsg.value = '' }, 1500)
    }

    onMounted(load)
    return { TYPES, SERVICES, vals, loaded, savedMsg, onSave }
  }
}
</script>
<style scoped>
.dl-page { max-width: 1100px; }
.dl-head { margin-bottom: 14px; }
.dl-title { font-size: 18px; font-weight: 800; color: var(--th-text); }
.dl-sub { font-size: 12px; color: var(--th-text2); margin-top: 5px; max-width: 820px; line-height: 1.45; }
.dl-grid-wrap { overflow-x: auto; border: 1px solid var(--th-border); border-radius: 6px; }
.dl-grid { border-collapse: collapse; width: 100%; font-size: 13px; }
.dl-grid th { background: var(--th-bg3); color: var(--th-accent); border: 1px solid var(--th-border); padding: 8px 10px; font-weight: 600; white-space: nowrap; position: sticky; top: 0; }
.dl-corner { text-align: left; }
.dl-svc { font-weight: 600; color: var(--th-text); padding: 6px 12px; border: 1px solid var(--th-border); background: var(--th-bg2); white-space: nowrap; }
.dl-cell { text-align: center; border: 1px solid var(--th-border); padding: 4px 6px; background: var(--th-bg); }
.dl-input { width: 48px; text-align: center; border: 1px solid var(--th-border); border-radius: 4px; padding: 4px; font-size: 13px; background: var(--th-bg); color: var(--th-text); font-family: inherit; outline: none; }
.dl-input:focus { border-color: var(--th-accent); }
.dl-unit { font-size: 10px; color: var(--th-text3); margin-left: 3px; }
.dl-na { color: var(--th-text3); }
.dl-foot { margin-top: 10px; min-height: 18px; }
.dl-saved { font-size: 12px; color: #1D9E75; font-weight: 600; }
.dl-loading { text-align: center; padding: 60px; color: var(--th-text2); }
</style>
