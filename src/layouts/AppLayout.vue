<template>
  <div class="app-layout" :class="{'mobile-open':mobileMenuOpen}">
    <div class="mobile-overlay" v-if="mobileMenuOpen" @click="mobileMenuOpen=false"></div>
    <aside class="sidebar" :class="{'sidebar-open':mobileMenuOpen}">
      <div class="sidebar-logo"><span class="logo-text">LDM</span><span class="logo-sub">Libération PF</span></div>
      <nav class="sidebar-nav">
        <router-link to="/dashboard" class="nav-item" active-class="active" @click="mobileMenuOpen=false"><span class="nav-icon">◻</span>Dashboard</router-link>
<router-link to="/lots" class="nav-item" active-class="active" @click="mobileMenuOpen=false"><span class="nav-icon">▥</span>Lots</router-link>
        <router-link to="/planifier" class="nav-item" active-class="active" @click="mobileMenuOpen=false"><span class="nav-icon">+</span>Planifier</router-link>
<router-link to="/import" class="nav-item" active-class="active" @click="mobileMenuOpen=false"><span class="nav-icon">↑</span>Import Excel</router-link>
        <router-link to="/notifications" class="nav-item" active-class="active" @click="mobileMenuOpen=false">
          <span class="nav-icon">🔔</span>Notifications
          <span class="notif-badge" v-if="unreadCount>0">{{unreadCount}}</span>
        </router-link>
        <router-link to="/tasks" class="nav-item" active-class="active" @click="mobileMenuOpen=false">
          <span class="nav-icon">📋</span>Tâches
          <span class="notif-badge tasks-badge" v-if="pendingTasksCount>0">{{pendingTasksCount}}</span>
        </router-link>
        <template v-if="isAdmin">
          <div class="nav-sep">Administration</div>
          <router-link to="/admin/users" class="nav-item" active-class="active" @click="mobileMenuOpen=false"><span class="nav-icon">👥</span>Utilisateurs</router-link>
          <router-link to="/admin/permissions" class="nav-item" active-class="active" @click="mobileMenuOpen=false"><span class="nav-icon">🔑</span>Permissions</router-link>
          <router-link to="/admin/products" class="nav-item" active-class="active" @click="mobileMenuOpen=false"><span class="nav-icon">📦</span>Catalogue produits</router-link>
        </template>
      </nav>
      <div class="sidebar-user" v-if="profile">
        <div class="user-avatar">{{initials}}</div>
        <div class="user-info"><div class="user-name">{{profile.prenom}} {{profile.nom}}</div><div class="user-service">{{serviceLabels[profile.service]}}</div></div>
        <button class="logout-btn" @click="logout" title="Déconnexion">✕</button>
      </div>
    </aside>
    <main class="main-content">
      <header class="top-bar">
        <button class="hamburger" @click="mobileMenuOpen=!mobileMenuOpen">☰</button>
        <div class="search-container">
          <span class="search-icon">⌕</span>
          <input ref="searchInput" v-model="searchQuery" @input="onSearch" @keydown.enter="submitSearch" @focus="showSug=true" @blur="hideSug" type="text" class="search-input" placeholder="Rechercher..." />
          <div class="suggestions" v-if="showSug && suggestions.length">
            <div v-for="(s,i) in suggestions" :key="i" class="sug-item" @mousedown.prevent="selectSug(s)">
              <span class="sug-type" :class="'t-'+s.type">{{s.type==='lot'?'LOT':'PRD'}}</span>
              <span class="sug-label">{{s.label}}</span><span class="sug-sub">{{s.sub}}</span>
            </div>
          </div>
        </div>
        <span class="notif-bell" @click="$router.push('/notifications')">🔔<span class="bell-badge" v-if="unreadCount>0">{{unreadCount}}</span></span>
        <span class="clock">{{clock}}</span>
      </header>
      <div class="page-content"><router-view /></div>
    </main>
    <!-- Toast notifications -->
    <div class="toast-container">
      <div v-for="t in toasts" :key="t.id" class="toast" @click="goToLot(t)">
        <div class="toast-msg">{{t.message}}</div>
        <div class="toast-lot" v-if="t.lots">{{t.lots.numero_lot}}</div>
      </div>
    </div>
  </div>
</template>
<script>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { loadPermissions } from '../services/permissions'
import { getUnreadCount, getNewNotifications, check48hDeviations } from '../services/notifications'
import { checkPlanningAlerts } from '../services/planningAlerts'
import { playSoundForEvent } from '../services/sounds'
export default {
  setup() {
    var router = useRouter()
    var profile = ref(null), searchQuery = ref(''), suggestions = ref([]), showSug = ref(false)
    var clock = ref(''), unreadCount = ref(0), pendingTasksCount = ref(0), searchInput = ref(null), mobileMenuOpen = ref(false)
    var toasts = ref([]), lastCheck = ref(new Date().toISOString()), toastId = ref(0)
    var debounce = null, clockInt = null, notifInt = null, planningInt = null, devAlertInt = null, tasksInt = null
    var serviceLabels = {planification:'Planification',stock:'Stock',aq:'Assurance Qualité',aq_dap:'AQ DAP',dt:'Direction Technique',fabrication:'Fabrication',conditionnement:'Conditionnement',lcq:'Laboratoire CQ',admin:'Administration'}
    var initials = computed(function(){return profile.value?(profile.value.prenom[0]+profile.value.nom[0]).toUpperCase():''})
    var isAdmin = computed(function(){return profile.value && profile.value.service === 'admin'})

    var updateClock = function(){var n=new Date(),p=function(v){return String(v).padStart(2,'0')};clock.value=p(n.getHours())+':'+p(n.getMinutes())+':'+p(n.getSeconds())}

    var showToast = function(notif) {
      toastId.value++
      var t = { id: toastId.value, message: notif.message, lots: notif.lots, lot_id: notif.lot_id }
      toasts.value.push(t)
      try { playSoundForEvent(notif.event_type) } catch(e) {}
      setTimeout(function() { toasts.value = toasts.value.filter(function(x){return x.id !== t.id}) }, 4000)
    }

    var loadPendingTasksCount = async function(svc) {
      if (!svc) return
      var total = 0
      // Récupérer les IDs des lots acceptés pour les exclure
      var accRes = await supabase.from('lots').select('id').eq('statut_sap','accepte')
      var accIds = (accRes.data||[]).map(function(l){return l.id})
      var excl = function(q){ return accIds.length ? q.not('lot_id','in','('+accIds.join(',')+')') : q }
      // Circuits
      var circEtapeMap = {planification:'planification',stock:'stock',aq:'aq',dt:'dt',aq_dap:'aq_dap'}
      var circEtape = circEtapeMap[svc]
      if (circEtape) {
        var r1 = await excl(supabase.from('orders_of').select('id',{count:'exact',head:true}).eq('statut','en_circuit').eq('etape_circuit',circEtape))
        total += r1.count||0
        var r2 = await excl(supabase.from('orders_oc').select('id',{count:'exact',head:true}).eq('statut','en_circuit').eq('etape_circuit',circEtape))
        total += r2.count||0
      } else if (svc==='fabrication') {
        var r3 = await excl(supabase.from('orders_of').select('id',{count:'exact',head:true}).eq('statut','en_circuit').eq('etape_circuit','production'))
        total += r3.count||0
      } else if (svc==='conditionnement') {
        var r4 = await excl(supabase.from('orders_oc').select('id',{count:'exact',head:true}).eq('statut','en_circuit').eq('etape_circuit','production'))
        total += r4.count||0
      }
      // Documents
      if (svc==='aq') {
        var r5 = await excl(supabase.from('liberation_documents').select('id',{count:'exact',head:true}).in('statut',['emis','verification_aq']).eq('is_applicable',true))
        total += r5.count||0
      } else if (svc==='dt') {
        var r6 = await excl(supabase.from('liberation_documents').select('id',{count:'exact',head:true}).eq('statut','approuve_aq').eq('is_applicable',true))
        total += r6.count||0
      } else {
        var r7 = await excl(supabase.from('liberation_documents').select('id',{count:'exact',head:true}).eq('statut','retour_emetteur').eq('service_emetteur',svc).eq('is_applicable',true))
        total += r7.count||0
      }
      // AR
      var r8 = await excl(supabase.from('liberation_documents').select('id',{count:'exact',head:true}).eq('pending_ar_service',svc))
      total += r8.count||0
      var r9 = await excl(supabase.from('orders_of').select('id',{count:'exact',head:true}).eq('pending_ar_service',svc))
      total += r9.count||0
      var r10 = await excl(supabase.from('orders_oc').select('id',{count:'exact',head:true}).eq('pending_ar_service',svc))
      total += r10.count||0
      pendingTasksCount.value = total
    }

    var checkNewNotifs = async function() {
      if (!profile.value) return
      var newOnes = await getNewNotifications(profile.value.service, isAdmin.value, lastCheck.value)
      lastCheck.value = new Date().toISOString()
      if (newOnes.length > 0) {
        unreadCount.value = await getUnreadCount(profile.value.service, isAdmin.value)
        newOnes.forEach(function(n) { showToast(n) })
      }
    }

    var goToLot = function(t) {
      if (t.lot_id) router.push('/lots/' + t.lot_id)
      toasts.value = toasts.value.filter(function(x){return x.id !== t.id})
    }

    var onSearch = function(){
      clearTimeout(debounce)
      if(searchQuery.value.length<2){suggestions.value=[];return}
      debounce=setTimeout(async function(){
        var q=searchQuery.value, results=[]
        var lr=await supabase.from('lots').select('id,numero_lot,statut_sap').ilike('numero_lot','%'+q+'%').limit(4)
        if(lr.data)lr.data.forEach(function(l){results.push({type:'lot',id:l.id,label:l.numero_lot,sub:l.statut_sap})})
        var pr=await supabase.from('products').select('id,code_article,description').or('code_article.ilike.%'+q+'%,description.ilike.%'+q+'%').limit(4)
        if(pr.data)pr.data.forEach(function(p){results.push({type:'product',id:p.id,label:p.code_article,sub:p.description})})
        suggestions.value=results.slice(0,8); showSug.value=true
      },250)
    }
    var submitSearch = function(){showSug.value=false;router.push({path:'/lots',query:{q:searchQuery.value}})}
    var selectSug = function(s){showSug.value=false;searchQuery.value=s.label;router.push({path:'/lots',query:{q:s.label}})}
    var hideSug = function(){setTimeout(function(){showSug.value=false},200)}
    var logout = async function(){await supabase.auth.signOut();router.push('/login')}

    onMounted(async function(){
      updateClock();clockInt=setInterval(updateClock,1000)
      var userRes=await supabase.auth.getUser()
      if(userRes.data.user){
        var pRes=await supabase.from('profiles').select('*').eq('id',userRes.data.user.id).single()
        profile.value=pRes.data
        if(pRes.data){
          await loadPermissions(pRes.data.service)
          unreadCount.value = await getUnreadCount(pRes.data.service, pRes.data.service === 'admin')
          await loadPendingTasksCount(pRes.data.service)
          notifInt=setInterval(checkNewNotifs,15000)
          tasksInt=setInterval(function(){ loadPendingTasksCount(profile.value&&profile.value.service) }, 60000)
          checkPlanningAlerts()
          planningInt=setInterval(checkPlanningAlerts, 6*60*60*1000)
          check48hDeviations()
          devAlertInt=setInterval(check48hDeviations, 30*60*1000)
        }
      }
    })
    onUnmounted(function(){clearInterval(clockInt);clearInterval(notifInt);clearInterval(planningInt);clearInterval(devAlertInt);clearInterval(tasksInt)})

    return {profile,initials,isAdmin,searchQuery,suggestions,showSug,clock,unreadCount,pendingTasksCount,searchInput,
      mobileMenuOpen,toasts,serviceLabels,onSearch,submitSearch,selectSug,hideSug,logout,goToLot}
  }
}
</script>
<style scoped>
.app-layout{display:flex;height:100vh;background:#fff;font-family:-apple-system,BlinkMacSystemFont,'Inter',sans-serif}
.sidebar{width:200px;background:#0a0a0a;color:#fff;display:flex;flex-direction:column;flex-shrink:0;z-index:50}
.sidebar-logo{padding:16px 18px;border-bottom:1px solid #222}.logo-text{font-size:16px;font-weight:600;letter-spacing:1px}.logo-sub{font-size:10px;color:#666;display:block;margin-top:2px;text-transform:uppercase;letter-spacing:.5px}
.sidebar-nav{flex:1;padding:12px 8px;overflow-y:auto}
.nav-item{display:flex;align-items:center;gap:10px;padding:9px 12px;color:#888;text-decoration:none;font-size:13px;border-radius:4px;margin-bottom:2px;transition:.15s;position:relative}.nav-item:hover{color:#ccc;background:#161616}.nav-item.active{color:#fff;background:#1a1a1a}
.nav-sep{font-size:9px;font-weight:600;text-transform:uppercase;letter-spacing:1px;color:#444;padding:12px 12px 4px;}
.nav-icon{font-size:14px;width:18px;text-align:center}
.notif-badge{position:absolute;right:8px;background:#E24B4A;color:#fff;font-size:10px;font-weight:600;padding:1px 6px;border-radius:8px;min-width:16px;text-align:center}
.tasks-badge{background:#E89C3A}
.sidebar-user{padding:14px 16px;border-top:1px solid #222;display:flex;align-items:center;gap:10px}
.user-avatar{width:30px;height:30px;border-radius:50%;background:#185FA5;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:500;flex-shrink:0}.user-name{font-size:12px;font-weight:500}.user-service{font-size:10px;color:#666}.user-info{flex:1;min-width:0}
.logout-btn{background:none;border:none;color:#666;cursor:pointer;font-size:12px;padding:4px}
.main-content{flex:1;display:flex;flex-direction:column;overflow:hidden;min-width:0}
.top-bar{display:flex;align-items:center;gap:10px;padding:10px 16px;border-bottom:1px solid #e8e8e8;flex-shrink:0}
.hamburger{display:none;background:none;border:none;font-size:20px;cursor:pointer;padding:4px 8px}
.search-container{position:relative;flex:1;max-width:400px}.search-icon{position:absolute;left:10px;top:50%;transform:translateY(-50%);font-size:15px;color:#999}
.search-input{width:100%;padding:7px 14px 7px 32px;font-size:13px;border:1px solid #ddd;border-radius:4px;background:#fafafa;outline:none;font-family:inherit;box-sizing:border-box}.search-input:focus{border-color:#185FA5;background:#fff}
.suggestions{position:absolute;top:100%;left:0;right:0;background:#fff;border:1px solid #ddd;border-radius:4px;margin-top:4px;box-shadow:0 6px 16px rgba(0,0,0,.08);z-index:100;max-height:320px;overflow-y:auto}
.sug-item{display:flex;align-items:center;gap:8px;padding:8px 12px;cursor:pointer;font-size:13px}.sug-item:hover{background:#f5f5f5}
.sug-type{font-size:9px;font-weight:600;padding:2px 6px;border-radius:2px;letter-spacing:.5px}.t-lot{background:#E6F1FB;color:#0C447C}.t-product{background:#EAF3DE;color:#3B6D11}
.sug-label{font-weight:500}.sug-sub{color:#999;font-size:11px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.notif-bell{font-size:18px;cursor:pointer;position:relative;padding:4px}.bell-badge{position:absolute;top:-2px;right:-4px;background:#E24B4A;color:#fff;font-size:9px;font-weight:600;padding:1px 4px;border-radius:6px}
.clock{margin-left:auto;font-family:'SF Mono','Fira Code',monospace;font-size:12px;color:#999;white-space:nowrap}
.page-content{flex:1;overflow-y:auto;overflow-x:hidden;padding:16px 20px;min-width:0}

/* Toast */
.toast-container{position:fixed;bottom:20px;right:20px;z-index:200;display:flex;flex-direction:column-reverse;gap:8px;max-width:360px}
.toast{background:#0a0a0a;color:#fff;padding:12px 16px;border-radius:6px;box-shadow:0 8px 24px rgba(0,0,0,.2);cursor:pointer;animation:slideIn .3s ease}
.toast-msg{font-size:13px;line-height:1.4}.toast-lot{font-family:'SF Mono',monospace;font-size:11px;color:#999;margin-top:4px}
@keyframes slideIn{from{transform:translateX(100%);opacity:0}to{transform:translateX(0);opacity:1}}

/* Mobile overlay */
.mobile-overlay{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.4);z-index:40}

/* Mobile */
@media(max-width:768px){
  .sidebar{position:fixed;left:-240px;top:0;bottom:0;width:240px;transition:left .25s ease;z-index:50}
  .sidebar-open{left:0}
  .mobile-overlay{display:block}
  .hamburger{display:block}
  .clock{display:none}
  .page-content{padding:12px}
  .toast-container{left:12px;right:12px;max-width:none}
}
</style>
