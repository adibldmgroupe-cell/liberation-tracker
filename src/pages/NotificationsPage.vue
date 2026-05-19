<template>
  <div>
    <div class="ph"><span class="pt">NOTIFICATIONS</span>
      <button v-if="notifications.length" class="btn-mark" @click="markAll">Tout marquer comme lu</button>
    </div>
    <div v-if="!notifications.length" class="empty">Aucune notification</div>
    <div v-else class="nlist">
      <div v-for="n in notifications" :key="n.id" class="nitem" :class="{unread:!n.is_read}" @click="read(n)">
        <span class="ndot" v-if="!n.is_read"></span>
        <div class="ncontent">
          <div class="nmsg">{{n.message}}</div>
          <div class="nmeta">
            <span class="nsvc">→ {{n.service}}</span>
            <span class="nlot" v-if="n.lots">{{n.lots.numero_lot}}</span>
            <span class="ntime">{{fmtDt(n.created_at)}}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import { ref, onMounted } from 'vue'
import { supabase } from '../supabase'
import { getNotifications, markAsRead, markAllAsRead } from '../services/notifications'
export default {
  setup() {
    var notifications = ref([]), service = ref(''), isAdmin = ref(false)
    var fmtDt = function(d){return d?new Date(d).toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}):''}
    var read = async function(n){if(!n.is_read){await markAsRead(n.id);n.is_read=true}}
    var markAll = async function(){await markAllAsRead(service.value,isAdmin.value);notifications.value.forEach(function(n){n.is_read=true})}
    onMounted(async function(){
      var u=await supabase.auth.getUser()
      var p=await supabase.from('profiles').select('service').eq('id',u.data.user.id).single()
      service.value=p.data.service
      isAdmin.value=p.data.service==='admin'
      notifications.value=await getNotifications(p.data.service,isAdmin.value,100)
    })
    return{notifications,fmtDt,read,markAll}
  }
}
</script>
<style scoped>
.ph{display:flex;align-items:baseline;justify-content:space-between;padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:8px}.pt{font-size:11px;font-weight:500;letter-spacing:1.5px}
.btn-mark{font-size:11px;padding:4px 12px;border:1px solid #ddd;border-radius:3px;background:#fff;cursor:pointer;color:#666}.btn-mark:hover{background:#f5f5f5}
.nlist{max-width:600px}.nitem{display:flex;align-items:flex-start;gap:10px;padding:10px 0;border-bottom:1px solid #f5f5f5;cursor:pointer}.nitem:hover{background:#fafafa}.nitem.unread{background:#f8f9ff}
.ndot{width:8px;height:8px;border-radius:50%;background:#185FA5;flex-shrink:0;margin-top:6px}
.ncontent{flex:1}.nmsg{font-size:13px;line-height:1.4}.nmeta{display:flex;gap:12px;margin-top:4px;flex-wrap:wrap}
.nsvc{font-size:10px;padding:1px 6px;background:#f0f0f0;border-radius:2px;color:#666}
.nlot{font-family:'SF Mono',monospace;font-size:11px;color:#185FA5}.ntime{font-family:'SF Mono',monospace;font-size:11px;color:#999}
.empty{text-align:center;padding:40px;color:#999}
</style>
