<template>
  <div class="prod-plan" :class="{'fullscreen': isFullscreen}">

    <!-- ── TOOLBAR ── -->
    <div class="toolbar" v-show="!isFullscreen || showToolbar">
      <div class="tb-left">
        <span class="tb-title">PILOTAGE PRODUCTION</span>
        <div class="tb-modes">
          <button class="mode-btn" :class="{active: mode==='plan'}"    @click="mode='plan'">🗺 Plan</button>
          <button class="mode-btn" :class="{active: mode==='flux'}"    @click="mode='flux'">🔄 Flux produit</button>
          <button class="mode-btn" :class="{active: mode==='trs'}"     @click="mode='trs'">📊 TRS</button>
        </div>
        <!-- Sélecteur produit en mode flux -->
        <div class="flux-selector" v-if="mode==='flux'">
          <select class="tb-sel" v-model="selectedLotId" @change="buildFlux">
            <option :value="null">— Choisir un lot actif —</option>
            <option v-for="s in activeSessions" :key="s.id" :value="s.lot_id">
              Lot {{s.numero_lot}} · {{s.nom_produit||'—'}}
            </option>
          </select>
          <button class="btn-sm-tb" v-if="selectedLotId" @click="selectedLotId=null;fluxArrows=[]">✕</button>
        </div>
      </div>
      <div class="tb-right">
        <div class="tb-legend">
          <span class="leg" v-for="l in legend" :key="l.label">
            <span class="leg-dot" :style="{background:l.color}"></span>{{l.label}}
          </span>
        </div>
        <div class="tb-pages" v-if="totalPages>1">
          <button class="pag-btn" @click="prevPage" :disabled="currentPage<=1">◀</button>
          <span class="pag-info">{{currentPage}} / {{totalPages}}</span>
          <button class="pag-btn" @click="nextPage" :disabled="currentPage>=totalPages">▶</button>
        </div>
        <button class="tb-icon-btn" @click="loadAll" :class="{spinning:loading}" title="Rafraîchir">↻</button>
        <button class="tb-icon-btn" @click="toggleFullscreen" :title="isFullscreen?'Quitter plein écran':'Plein écran'">{{isFullscreen?'⊠':'⊞'}}</button>
        <button class="tb-icon-btn admin-btn" v-if="isAdmin" @click="editMode=!editMode" :class="{active:editMode}" title="Mode édition hotspots">✎</button>
      </div>
    </div>

    <!-- ── CORPS PRINCIPAL ── -->
    <div class="plan-body" ref="planBody" @mousemove="isFullscreen&&(showToolbar=true);clearTimeout(tbTimer);tbTimer=setTimeout(()=>showToolbar=false,3000)">

      <!-- CANVAS CONTAINER (zoom/pan) -->
      <div class="canvas-wrap"
        ref="canvasWrap"
        @wheel.prevent="onWheel"
        @mousedown="onPanStart"
        @mousemove="onPanMove"
        @mouseup="onPanEnd"
        @mouseleave="onPanEnd"
        :style="{cursor: isPanning?'grabbing': editMode?'crosshair':'grab'}"
      >
        <div class="canvas-inner" :style="transformStyle">
          <!-- Plan PNG (généré par CI via pdftoppm) -->
          <img
            :src="'/plans/P004_page-'+currentPage+'.png'"
            class="plan-img"
            @load="onImgLoad"
            @error="onImgError"
            :alt="'Plan production page '+currentPage"
            draggable="false"
          />

          <!-- SVG overlay : hotspots + flux arrows -->
          <svg class="hotspot-svg" :style="{width: canvasW+'px', height: canvasH+'px'}" xmlns="http://www.w3.org/2000/svg">

            <!-- Flux arrows (mode flux) -->
            <defs>
              <marker id="arrow-head" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
                <path d="M0,0 L0,6 L8,3 z" fill="#f59e0b"/>
              </marker>
              <marker id="arrow-head-done" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
                <path d="M0,0 L0,6 L8,3 z" fill="#10b981"/>
              </marker>
            </defs>

            <g v-for="arr in fluxArrows" :key="arr.id">
              <path
                :d="arr.path"
                :stroke="arr.done?'#10b981':'#f59e0b'"
                stroke-width="3"
                fill="none"
                :stroke-dasharray="arr.done?'none':'10,5'"
                :marker-end="arr.done?'url(#arrow-head-done)':'url(#arrow-head)'"
                class="flux-path"
                :class="{animated: !arr.done}"
              />
              <rect :x="arr.labelX-45" :y="arr.labelY-12" width="90" height="22" rx="4"
                :fill="arr.done?'#10b981':'#f59e0b'" opacity="0.9"/>
              <text :x="arr.labelX" :y="arr.labelY+4" text-anchor="middle"
                font-size="11" fill="white" font-weight="600">{{arr.label}}</text>
            </g>

            <!-- Hotspot rooms -->
            <g v-for="room in visibleRooms" :key="room.id"
              class="hotspot-g"
              :class="{'hs-edit': editMode}"
              @click="!isPanning && !editMode && selectRoom(room)"
              @click.stop="editMode && startDrag(room, $event)"
            >
              <!-- Rectangle de la salle -->
              <rect
                :x="room.x" :y="room.y" :width="room.w" :height="room.h"
                :fill="roomFill(room)" :stroke="roomStroke(room)"
                stroke-width="2" rx="3" opacity="0.55"
                class="hs-rect"
              />
              <!-- Badge statut -->
              <circle v-if="getRoomStatus(room).dot" :cx="room.x+room.w-8" :cy="room.y+8" r="7"
                :fill="getRoomStatus(room).dot" stroke="white" stroke-width="1.5"/>
              <!-- Indicateur TRS (mode TRS) -->
              <rect v-if="mode==='trs' && getRoomTRS(room)!=null"
                :x="room.x" :y="room.y+room.h-6" :width="(room.w * getRoomTRS(room)/100)" height="6"
                :fill="trsColor(getRoomTRS(room))" rx="0" opacity="0.9"/>
              <!-- Nom salle (visible si assez grand) -->
              <text v-if="room.h>30"
                :x="room.x + room.w/2" :y="room.y + room.h/2 - (room.h>50?8:0)"
                text-anchor="middle" dominant-baseline="middle"
                :font-size="Math.max(9, Math.min(13, room.w/8))"
                fill="white" font-weight="600"
                style="pointer-events:none;text-shadow:0 1px 3px rgba(0,0,0,.8)"
              >{{room.code}}</text>
              <text v-if="room.h>50"
                :x="room.x + room.w/2" :y="room.y + room.h/2 + 10"
                text-anchor="middle" dominant-baseline="middle"
                :font-size="Math.max(7, Math.min(10, room.w/10))"
                fill="rgba(255,255,255,.9)"
                style="pointer-events:none;text-shadow:0 1px 2px rgba(0,0,0,.7)"
              >{{getActiveCount(room)>0 ? getActiveCount(room)+' lot'+(getActiveCount(room)>1?'s':'') : ''}}</text>
              <!-- Handle édition -->
              <circle v-if="editMode" :cx="room.x+room.w/2" :cy="room.y+room.h/2" r="8"
                fill="#3b82f6" opacity="0.8" style="cursor:move"/>
            </g>

            <!-- Nouveau hotspot (clic en mode edit) -->
            <rect v-if="editMode && newRoom"
              :x="newRoom.x" :y="newRoom.y" :width="newRoom.w" :height="newRoom.h"
              fill="#3b82f6" opacity="0.4" stroke="#3b82f6" stroke-width="2" rx="3"
              stroke-dasharray="6,3"/>
          </svg>
        </div>
      </div>

      <!-- PANEL LATÉRAL SALLE -->
      <transition name="panel-slide">
        <div class="side-panel" v-if="selectedRoom" @click.stop>
          <div class="sp-hd" :style="{borderLeftColor: zoneColor(selectedRoom.zone)}">
            <div>
              <div class="sp-code">{{selectedRoom.code}}</div>
              <div class="sp-nom">{{selectedRoom.nom}}</div>
              <div class="sp-zone">{{zoneLabel(selectedRoom.zone)}}</div>
            </div>
            <button class="sp-close" @click="selectedRoom=null">✕</button>
          </div>

          <!-- Statut live -->
          <div class="sp-status-bar" :style="{background: roomFill(selectedRoom)+'cc'}">
            <span class="sp-st-icon">{{getRoomStatus(selectedRoom).icon}}</span>
            <span class="sp-st-label">{{getRoomStatus(selectedRoom).label}}</span>
            <span v-if="getRoomTRS(selectedRoom)!=null" class="sp-trs" :style="{color:trsColor(getRoomTRS(selectedRoom))}">
              TRS {{getRoomTRS(selectedRoom)}}%
            </span>
          </div>

          <!-- Lots actifs -->
          <div class="sp-section">
            <div class="sp-sec-title">Lots en cours</div>
            <div v-if="!getRoomLots(selectedRoom).length" class="sp-empty">Aucun lot actif</div>
            <div v-for="s in getRoomLots(selectedRoom)" :key="s.id" class="sp-lot-row">
              <div class="sp-lot-left">
                <div class="sp-lot-num">{{s.numero_lot}}</div>
                <div class="sp-lot-prod">{{s.nom_produit||'—'}}</div>
              </div>
              <div class="sp-lot-right">
                <span class="sp-lot-stat" :class="'ls-'+s.statut_session?.toLowerCase().replace(/\s/g,'-')">{{s.statut_session}}</span>
                <div class="sp-lot-dur">{{s.elapsed}}</div>
              </div>
            </div>
          </div>

          <!-- Déviations ouvertes -->
          <div class="sp-section" v-if="getRoomDevs(selectedRoom).length">
            <div class="sp-sec-title sp-sec-warn">⚠ Déviations</div>
            <div v-for="d in getRoomDevs(selectedRoom)" :key="d.id" class="sp-dev-row">
              <span class="sp-dev-bl" v-if="d.bloquante">BLOQUANTE</span>
              <span class="sp-dev-desc">{{d.description||'Déviation en cours'}}</span>
              <span class="sp-dev-date">{{fmtDate(d.declared_at)}}</span>
            </div>
          </div>

          <!-- Arrêts actifs -->
          <div class="sp-section" v-if="getRoomArrets(selectedRoom).length">
            <div class="sp-sec-title sp-sec-stop">⏸ Arrêts actifs</div>
            <div v-for="a in getRoomArrets(selectedRoom)" :key="a.id" class="sp-arr-row">
              <span class="sp-arr-timer">{{a.elapsed}}</span>
              <span class="sp-arr-nom">{{a.arret_nom||a.motif||'Arrêt'}}</span>
              <span class="sp-arr-type" :style="{color:a.couleur||'#888'}">{{a.famille_nom||''}}</span>
            </div>
          </div>

          <!-- Actions -->
          <div class="sp-actions">
            <button class="sp-btn" @click="goToFab(selectedRoom)" v-if="selectedRoom.type==='fab'">📋 Suivi Fab</button>
            <button class="sp-btn" @click="goToCond(selectedRoom)" v-if="selectedRoom.type==='cond'">📦 Suivi Cond</button>
            <button class="sp-btn" @click="goToTRS(selectedRoom)" v-if="selectedRoom.type==='cond'">⚡ TRS Live</button>
            <button class="sp-btn sp-btn-sec" @click="goToLot(selectedRoom)" v-if="getRoomLots(selectedRoom).length">🔍 Voir lot</button>
          </div>
        </div>
      </transition>

      <!-- MODAL NOUVEAU HOTSPOT (mode admin) -->
      <div class="modal-overlay" v-if="newRoomModal.open" @click.self="newRoomModal.open=false">
        <div class="modal-new-room">
          <div class="modal-hd">Nouvelle salle — définir la zone</div>
          <div class="modal-body">
            <div class="form-row"><label>Code *</label><input class="form-inp" v-model="newRoomModal.code" placeholder="ex: 428"/></div>
            <div class="form-row"><label>Nom *</label><input class="form-inp" v-model="newRoomModal.nom" placeholder="ex: Granulation et séchage 02"/></div>
            <div class="form-row">
              <label>Zone</label>
              <select class="form-inp" v-model="newRoomModal.zone">
                <option v-for="z in zones" :key="z.key" :value="z.key">{{z.label}}</option>
              </select>
            </div>
            <div class="form-row">
              <label>Type</label>
              <select class="form-inp" v-model="newRoomModal.type">
                <option value="fab">Fabrication</option>
                <option value="cond">Conditionnement</option>
                <option value="pesee">Pesée</option>
                <option value="support">Support</option>
              </select>
            </div>
            <div class="form-row"><label>Atelier ID (fab)</label><input class="form-inp" v-model.number="newRoomModal.atelier_id" placeholder="laisser vide si cond"/></div>
            <div class="form-row"><label>Équipement ID (cond)</label><input class="form-inp" v-model.number="newRoomModal.equipement_id" placeholder="laisser vide si fab"/></div>
          </div>
          <div class="modal-ft">
            <button class="btn-cancel" @click="newRoomModal.open=false">Annuler</button>
            <button class="btn-save" @click="saveNewRoom">Créer la salle</button>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'

export default {
  setup() {
    var router = useRouter()

    // ─── STATE ────────────────────────────────────────────────
    var mode = ref('plan')
    var loading = ref(false)
    var isFullscreen = ref(false)
    var showToolbar = ref(true)
    var tbTimer = ref(null)
    var editMode = ref(false)
    var isAdmin = ref(false)

    // Plan image
    var canvasWrap = ref(null)
    var planBody = ref(null)
    var canvasW = ref(2400)
    var canvasH = ref(1700)
    var currentPage = ref(1)
    var totalPages = ref(2)   // P004 a 2 pages (ajuster si besoin)

    // Pan / zoom
    var scale = ref(1)
    var offsetX = ref(0)
    var offsetY = ref(0)
    var isPanning = ref(false)
    var panStart = ref({x:0,y:0,ox:0,oy:0})

    // Rooms
    var rooms = ref([])
    var selectedRoom = ref(null)

    // Data live
    var suiviFab = ref([])
    var sessions = ref([])
    var deviations = ref([])
    var arrets = ref([])
    var activeSessions = ref([])

    // Flux
    var selectedLotId = ref(null)
    var fluxArrows = ref([])

    // New room (edit mode)
    var newRoom = ref(null)
    var newRoomModal = ref({open:false, code:'', nom:'', zone:'formes_seches', type:'fab', atelier_id:null, equipement_id:null})
    var drawStart = ref(null)

    // ─── ZONES ────────────────────────────────────────────────
    var zones = [
      {key:'formes_seches',   label:'Formes Sèches',        color:'#7c3aed'},
      {key:'formes_semi',     label:'Formes Semi-Solides',   color:'#2563eb'},
      {key:'cond_secondaire', label:'Conditionnement',       color:'#059669'},
      {key:'pesee',           label:'Zone Pesée',            color:'#d97706'},
      {key:'technique',       label:'Zone Technique',        color:'#9ca3af'},
      {key:'magasin',         label:'Magasin MP',            color:'#64748b'},
    ]

    var legend = [
      {label:'Actif',    color:'#10b981'},
      {label:'Arrêt',    color:'#ef4444'},
      {label:'Déviation',color:'#f59e0b'},
      {label:'Libre',    color:'#6b7280'},
    ]

    var zoneColor = function(zone) {
      var z = zones.find(function(x){return x.key===zone})
      return z?z.color:'#888'
    }
    var zoneLabel = function(zone) {
      var z = zones.find(function(x){return x.key===zone})
      return z?z.label:'—'
    }

    // ─── IMAGE PLAN ───────────────────────────────────────────
    var onImgLoad = function(e) {
      canvasW.value = e.target.naturalWidth
      canvasH.value = e.target.naturalHeight
    }
    var onImgError = function() {
      // Si la page n'existe pas, revenir à 1
      if (currentPage.value > 1) { currentPage.value = 1; totalPages.value = 1 }
    }

    var prevPage = function() {
      if (currentPage.value > 1) currentPage.value--
    }
    var nextPage = function() {
      if (currentPage.value < totalPages.value) currentPage.value++
    }

    // ─── LOAD DATA ────────────────────────────────────────────
    var loadAll = async function() {
      loading.value = true
      var [r1,r2,r3,r4,r5,r6] = await Promise.all([
        supabase.from('plan_rooms').select('*').order('code'),
        supabase.from('suivi_fabrication')
          .select('id,lot_id,atelier_id,statut,date_debut,lots(numero_lot,products(nom_produit))')
          .is('deleted_at',null).in('statut',['En cours','Arrêt']),
        supabase.from('production_sessions')
          .select('id,lot_id,equipement_id,statut,date,heure_debut,trs,colis_produits,objectif_boites,lots(numero_lot,products(nom_produit))')
          .in('statut',['En cours','Arrêt']),
        supabase.from('deviations')
          .select('id,lot_id,description,bloquante,statut,declared_at,declared_service')
          .in('statut',['ouverte','en_cours']),
        supabase.from('production_arrets')
          .select('id,session_id,arret_nom,famille_nom,couleur,motif,heure_debut,is_running')
          .eq('is_running',true),
        supabase.from('production_sessions')
          .select('id,lot_id,equipement_id,lots(numero_lot,products(nom_produit))')
          .in('statut',['En cours','Arrêt'])
      ])
      if (!r1.error) rooms.value = r1.data
      if (!r2.error) suiviFab.value = r2.data
      if (!r3.error) sessions.value = r3.data
      if (!r4.error) deviations.value = r4.data
      if (!r5.error) arrets.value = r5.data
      if (!r6.error) {
        activeSessions.value = r6.data.map(function(s){
          return {
            id:s.id, lot_id:s.lot_id, equipement_id:s.equipement_id,
            numero_lot: s.lots?.numero_lot||'',
            nom_produit: s.lots?.products?.nom_produit||''
          }
        })
      }
      loading.value = false
    }

    var loadProfile = async function() {
      var { data: { user } } = await supabase.auth.getUser()
      if (user) {
        var r = await supabase.from('profiles').select('service').eq('id',user.id).single()
        isAdmin.value = r.data?.service === 'admin'
      }
    }

    // ─── COMPUTED ─────────────────────────────────────────────
    var visibleRooms = computed(function() { return rooms.value })

    var transformStyle = computed(function() {
      return {
        transform: 'translate('+offsetX.value+'px,'+offsetY.value+'px) scale('+scale.value+')',
        transformOrigin: '0 0',
        width: canvasW.value+'px',
        height: canvasH.value+'px',
      }
    })

    // ─── ROOM HELPERS ─────────────────────────────────────────
    var getRoomStatus = function(room) {
      // Check arrêts (production_arrets actifs)
      var sessIds = sessions.value.filter(function(s){ return s.equipement_id===room.equipement_id }).map(function(s){return s.id})
      var hasArret = arrets.value.some(function(a){ return sessIds.includes(a.session_id) })
      // Check déviations via lots de la salle
      var lotIds = getAllLotIds(room)
      var hasDev = deviations.value.some(function(d){ return lotIds.includes(d.lot_id) })
      // Check fab arrêts
      var hasFabArret = suiviFab.value.some(function(sf){ return sf.atelier_id===room.atelier_id && sf.statut==='Arrêt' })

      if (hasArret || hasFabArret) return {label:'Arrêt', icon:'⏸', dot:'#ef4444'}
      if (hasDev) return {label:'Déviation', icon:'⚠', dot:'#f59e0b'}
      if (hasActiveFab(room) || hasActiveSess(room)) return {label:'En cours', icon:'🔄', dot:'#10b981'}
      return {label:'Libre', icon:'✓', dot:null}
    }

    var hasActiveFab = function(room) {
      return suiviFab.value.some(function(sf){ return sf.atelier_id===room.atelier_id && sf.statut==='En cours' })
    }
    var hasActiveSess = function(room) {
      return sessions.value.some(function(s){ return s.equipement_id===room.equipement_id && s.statut==='En cours' })
    }

    var getAllLotIds = function(room) {
      var ids = []
      suiviFab.value.filter(function(sf){ return sf.atelier_id===room.atelier_id }).forEach(function(sf){ ids.push(sf.lot_id) })
      sessions.value.filter(function(s){ return s.equipement_id===room.equipement_id }).forEach(function(s){ ids.push(s.lot_id) })
      return ids
    }

    var getActiveCount = function(room) {
      var c = suiviFab.value.filter(function(sf){ return sf.atelier_id===room.atelier_id && sf.statut==='En cours' }).length
      c += sessions.value.filter(function(s){ return s.equipement_id===room.equipement_id && s.statut==='En cours' }).length
      return c
    }

    var getRoomTRS = function(room) {
      if (room.type!=='cond') return null
      var sess = sessions.value.find(function(s){ return s.equipement_id===room.equipement_id })
      return sess && sess.trs!=null ? sess.trs : null
    }

    var getRoomLots = function(room) {
      var res = []
      var now = Date.now()
      suiviFab.value.filter(function(sf){ return sf.atelier_id===room.atelier_id }).forEach(function(sf) {
        var elapsed = sf.date_debut ? formatElapsed(now - new Date(sf.date_debut)) : '—'
        res.push({id:'f'+sf.id, numero_lot:sf.lots?.numero_lot||sf.lot_id, nom_produit:sf.lots?.products?.nom_produit||'', statut_session:sf.statut, elapsed, lot_id:sf.lot_id})
      })
      sessions.value.filter(function(s){ return s.equipement_id===room.equipement_id }).forEach(function(s) {
        res.push({id:'s'+s.id, numero_lot:s.lots?.numero_lot||s.lot_id, nom_produit:s.lots?.products?.nom_produit||'', statut_session:s.statut, elapsed:'—', lot_id:s.lot_id})
      })
      return res
    }

    var getRoomDevs = function(room) {
      var lotIds = getAllLotIds(room)
      return deviations.value.filter(function(d){ return lotIds.includes(d.lot_id) })
    }

    var getRoomArrets = function(room) {
      var now = Date.now()
      var sessIds = sessions.value.filter(function(s){ return s.equipement_id===room.equipement_id }).map(function(s){return s.id})
      return arrets.value.filter(function(a){ return sessIds.includes(a.session_id) }).map(function(a) {
        var elapsed = a.heure_debut ? formatElapsed(now - new Date(a.heure_debut)) : '—'
        return Object.assign({}, a, {elapsed})
      })
    }

    var roomFill = function(room) {
      var st = getRoomStatus(room)
      if (st.label==='Arrêt') return '#ef4444'
      if (st.label==='Déviation') return '#f59e0b'
      if (st.label==='En cours') return '#10b981'
      return zoneColor(room.zone)
    }
    var roomStroke = function(room) {
      if (selectedRoom.value && selectedRoom.value.id===room.id) return '#fff'
      return 'rgba(255,255,255,.5)'
    }
    var trsColor = function(v) {
      if (v==null) return '#888'
      return v>=85?'#10b981':v>=60?'#f59e0b':'#ef4444'
    }

    // ─── FLUX PRODUIT ─────────────────────────────────────────
    var buildFlux = async function() {
      fluxArrows.value = []
      if (!selectedLotId.value) return

      // Charger les étapes fab + cond pour ce lot
      var [r1,r2] = await Promise.all([
        supabase.from('suivi_fabrication')
          .select('id,atelier_id,statut,ateliers(nom_atelier,processus_id,processus(nom_process,ordre))')
          .eq('lot_id',selectedLotId.value).is('deleted_at',null).order('id'),
        supabase.from('production_sessions')
          .select('id,equipement_id,statut')
          .eq('lot_id',selectedLotId.value).order('id')
      ])

      var steps = []
      if (r1.data) r1.data.forEach(function(sf) {
        var room = rooms.value.find(function(r){ return r.atelier_id===sf.atelier_id })
        if (room) steps.push({room, statut:sf.statut, ordre: sf.ateliers?.processus?.ordre||99})
      })
      if (r2.data) r2.data.forEach(function(s) {
        var room = rooms.value.find(function(r){ return r.equipement_id===s.equipement_id })
        if (room) steps.push({room, statut:s.statut, ordre:200})
      })
      steps.sort(function(a,b){ return a.ordre-b.ordre })

      // Générer les flèches entre étapes consécutives
      var arrows = []
      for (var i=0; i<steps.length-1; i++) {
        var from = steps[i].room, to = steps[i+1].room
        var x1 = from.x + from.w/2, y1 = from.y + from.h/2
        var x2 = to.x + to.w/2,   y2 = to.y + to.h/2
        var mx = (x1+x2)/2, my = (y1+y2)/2
        var done = steps[i].statut==='Clôturé'
        arrows.push({
          id:'arr-'+i,
          path: 'M '+x1+' '+y1+' Q '+mx+' '+(my-40)+' '+x2+' '+y2,
          labelX: mx, labelY: my-50,
          label: done?'✓ Terminé':'→ Phase '+(i+2),
          done
        })
      }
      fluxArrows.value = arrows
    }

    // ─── ZOOM / PAN ───────────────────────────────────────────
    var onWheel = function(e) {
      var delta = e.deltaY > 0 ? 0.9 : 1.1
      var newScale = Math.max(0.3, Math.min(5, scale.value * delta))
      var rect = canvasWrap.value.getBoundingClientRect()
      var mx = e.clientX - rect.left, my = e.clientY - rect.top
      offsetX.value = mx - (mx - offsetX.value) * (newScale/scale.value)
      offsetY.value = my - (my - offsetY.value) * (newScale/scale.value)
      scale.value = newScale
    }
    var onPanStart = function(e) {
      if (editMode.value) { startNewRoomDraw(e); return }
      isPanning.value = true
      panStart.value = {x:e.clientX, y:e.clientY, ox:offsetX.value, oy:offsetY.value}
    }
    var onPanMove = function(e) {
      if (editMode.value && drawStart.value) { updateNewRoomDraw(e); return }
      if (!isPanning.value) return
      offsetX.value = panStart.value.ox + (e.clientX - panStart.value.x)
      offsetY.value = panStart.value.oy + (e.clientY - panStart.value.y)
    }
    var onPanEnd = function() {
      isPanning.value = false
      if (editMode.value && drawStart.value) { finishNewRoomDraw() }
    }

    // ─── EDIT MODE — DESSIN HOTSPOT ───────────────────────────
    var svgCoords = function(e) {
      var rect = canvasWrap.value.getBoundingClientRect()
      return {
        x: Math.round((e.clientX - rect.left - offsetX.value) / scale.value),
        y: Math.round((e.clientY - rect.top  - offsetY.value) / scale.value)
      }
    }
    var startNewRoomDraw = function(e) {
      var c = svgCoords(e)
      drawStart.value = c
      newRoom.value = {x:c.x, y:c.y, w:1, h:1}
    }
    var updateNewRoomDraw = function(e) {
      if (!drawStart.value || !newRoom.value) return
      var c = svgCoords(e)
      newRoom.value = {
        x: Math.min(drawStart.value.x, c.x), y: Math.min(drawStart.value.y, c.y),
        w: Math.abs(c.x - drawStart.value.x), h: Math.abs(c.y - drawStart.value.y)
      }
    }
    var finishNewRoomDraw = function() {
      if (!newRoom.value || newRoom.value.w < 10 || newRoom.value.h < 10) { newRoom.value=null; drawStart.value=null; return }
      newRoomModal.value = {open:true, code:'', nom:'', zone:'formes_seches', type:'fab', atelier_id:null, equipement_id:null}
      drawStart.value = null
    }
    var saveNewRoom = async function() {
      if (!newRoomModal.value.code || !newRoomModal.value.nom) return
      var payload = {
        code: newRoomModal.value.code,
        nom: newRoomModal.value.nom,
        zone: newRoomModal.value.zone,
        type: newRoomModal.value.type,
        atelier_id: newRoomModal.value.atelier_id||null,
        equipement_id: newRoomModal.value.equipement_id||null,
        x: newRoom.value.x, y: newRoom.value.y,
        w: newRoom.value.w, h: newRoom.value.h
      }
      var res = await supabase.from('plan_rooms').insert(payload)
      if (!res.error) { newRoomModal.value.open=false; newRoom.value=null; await loadAll() }
    }

    // Drag room to reposition
    var startDrag = function(room, e) {
      e.preventDefault()
      var startX = e.clientX, startY = e.clientY
      var origX = room.x, origY = room.y
      var onMove = function(me) {
        var dx = (me.clientX-startX)/scale.value
        var dy = (me.clientY-startY)/scale.value
        room.x = Math.round(origX+dx)
        room.y = Math.round(origY+dy)
      }
      var onUp = async function() {
        document.removeEventListener('mousemove',onMove)
        document.removeEventListener('mouseup',onUp)
        await supabase.from('plan_rooms').update({x:room.x,y:room.y}).eq('id',room.id)
      }
      document.addEventListener('mousemove',onMove)
      document.addEventListener('mouseup',onUp)
    }

    // ─── NAVIGATION ───────────────────────────────────────────
    var selectRoom = function(room) { selectedRoom.value = room }
    var goToFab = function(room) { router.push('/tracking/pdp-fab') }
    var goToCond = function(room) { router.push('/tracking/pdp-cond') }
    var goToTRS = function(room) { router.push('/tracking/trs') }
    var goToLot = function(room) {
      var lots = getRoomLots(room)
      if (lots.length===1) router.push('/lots/'+lots[0].lot_id)
      else router.push('/lots')
    }

    // ─── FULLSCREEN ───────────────────────────────────────────
    var toggleFullscreen = function() {
      isFullscreen.value = !isFullscreen.value
      showToolbar.value = true
    }

    // ─── UTILS ────────────────────────────────────────────────
    var formatElapsed = function(ms) {
      var h = Math.floor(ms/3600000), m = Math.floor((ms%3600000)/60000)
      return h>0?(h+'h'+String(m).padStart(2,'0')):(m+'min')
    }
    var fmtDate = function(dt) {
      if (!dt) return ''
      return new Date(dt).toLocaleDateString('fr-FR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'})
    }

    // ─── AUTO-REFRESH ─────────────────────────────────────────
    var refreshInt = null
    onMounted(async function() {
      await loadProfile()
      await loadAll()
      refreshInt = setInterval(loadAll, 60000)
    })
    onBeforeUnmount(function() { clearInterval(refreshInt) })

    return {
      mode, loading, isFullscreen, showToolbar, tbTimer, editMode, isAdmin,
      canvasWrap, planBody, canvasW, canvasH,
      currentPage, totalPages, scale, offsetX, offsetY, isPanning, panStart,
      onImgLoad, onImgError,
      rooms, selectedRoom, suiviFab, sessions, deviations, arrets, activeSessions,
      selectedLotId, fluxArrows, newRoom, newRoomModal, drawStart,
      zones, legend,
      visibleRooms, transformStyle,
      zoneColor, zoneLabel, getRoomStatus, getActiveCount, getRoomTRS,
      getRoomLots, getRoomDevs, getRoomArrets, roomFill, roomStroke, trsColor,
      buildFlux, onWheel, onPanStart, onPanMove, onPanEnd,
      startDrag, selectRoom, saveNewRoom,
      goToFab, goToCond, goToTRS, goToLot, toggleFullscreen,
      formatElapsed, fmtDate, prevPage, nextPage, loadAll,
    }
  }
}
</script>

<style scoped>
/* ── Base ── */
.prod-plan { display:flex; flex-direction:column; height:calc(100vh - 48px); overflow:hidden; background:#1a1a2e; font-family:'Inter',sans-serif; margin:-16px -20px; }
.prod-plan.fullscreen { position:fixed; inset:0; z-index:9999; margin:0; height:100vh; }

/* ── Toolbar ── */
.toolbar { display:flex; align-items:center; justify-content:space-between; padding:8px 16px; background:#0f0f23; border-bottom:1px solid #2a2a4a; flex-shrink:0; gap:12px; flex-wrap:wrap; }
.tb-title { font-size:11px; font-weight:700; letter-spacing:2px; color:#7c7cff; text-transform:uppercase; white-space:nowrap; }
.tb-left,.tb-right { display:flex; align-items:center; gap:10px; flex-wrap:wrap; }
.tb-modes { display:flex; gap:3px; }
.mode-btn { padding:5px 12px; border-radius:4px; border:1px solid #3a3a5c; background:transparent; color:#9ca3af; font-size:12px; cursor:pointer; transition:.15s; }
.mode-btn:hover { background:#2a2a4a; color:#fff; }
.mode-btn.active { background:#3b82f6; border-color:#3b82f6; color:#fff; }
.flux-selector { display:flex; align-items:center; gap:6px; }
.tb-sel { padding:5px 10px; border:1px solid #3a3a5c; border-radius:4px; background:#1a1a2e; color:#e2e8f0; font-size:12px; }
.btn-sm-tb { background:none; border:none; color:#9ca3af; cursor:pointer; font-size:14px; }
.tb-legend { display:flex; gap:10px; flex-wrap:wrap; }
.leg { display:flex; align-items:center; gap:4px; font-size:11px; color:#9ca3af; }
.leg-dot { width:9px; height:9px; border-radius:50%; }
.tb-pages { display:flex; align-items:center; gap:6px; }
.pag-btn { padding:4px 8px; border:1px solid #3a3a5c; border-radius:3px; background:transparent; color:#9ca3af; cursor:pointer; font-size:12px; }
.pag-btn:disabled { opacity:.3; cursor:not-allowed; }
.pag-info { font-size:11px; color:#9ca3af; white-space:nowrap; }
.tb-icon-btn { width:32px; height:32px; border:1px solid #3a3a5c; border-radius:4px; background:transparent; color:#9ca3af; cursor:pointer; font-size:15px; display:flex; align-items:center; justify-content:center; transition:.15s; }
.tb-icon-btn:hover { background:#2a2a4a; color:#fff; }
.tb-icon-btn.spinning { animation:spin 1s linear infinite; }
.tb-icon-btn.active { background:#f59e0b; border-color:#f59e0b; color:#000; }
.admin-btn { }
@keyframes spin { to{transform:rotate(360deg)} }

/* ── Plan body ── */
.plan-body { flex:1; display:flex; overflow:hidden; position:relative; }

/* ── Canvas wrap ── */
.canvas-wrap { flex:1; overflow:hidden; position:relative; }
.canvas-inner { position:absolute; top:0; left:0; }
.plan-img { display:block; max-width:none; user-select:none; -webkit-user-drag:none; }

/* ── SVG overlay ── */
.hotspot-svg { position:absolute; top:0; left:0; pointer-events:none; }
.hotspot-g { pointer-events:all; cursor:pointer; }
.hotspot-g:hover .hs-rect { opacity:0.75 !important; }
.hs-edit { cursor:move; }
.hs-rect { transition:opacity .2s; }

/* ── Flux arrows ── */
.flux-path { transition:stroke .3s; }
.flux-path.animated { stroke-dasharray:10,5; animation:dash 1s linear infinite; }
@keyframes dash { to{stroke-dashoffset:-30} }

/* ── Side panel ── */
.side-panel { width:320px; flex-shrink:0; background:#0f0f23; border-left:1px solid #2a2a4a; overflow-y:auto; display:flex; flex-direction:column; z-index:10; }
.panel-slide-enter-active,.panel-slide-leave-active { transition:transform .25s ease,opacity .25s; }
.panel-slide-enter-from,.panel-slide-leave-to { transform:translateX(100%); opacity:0; }

.sp-hd { padding:14px 16px; border-bottom:1px solid #2a2a4a; display:flex; align-items:flex-start; justify-content:space-between; border-left:4px solid #888; }
.sp-code { font-size:20px; font-weight:700; color:#fff; }
.sp-nom  { font-size:13px; color:#e2e8f0; margin-top:2px; line-height:1.3; }
.sp-zone { font-size:11px; color:#6b7280; margin-top:4px; text-transform:uppercase; letter-spacing:.5px; }
.sp-close { background:none; border:none; color:#6b7280; cursor:pointer; font-size:18px; padding:0 0 0 8px; }

.sp-status-bar { display:flex; align-items:center; gap:8px; padding:10px 16px; font-size:13px; color:#fff; }
.sp-st-icon { font-size:16px; }
.sp-st-label { flex:1; font-weight:600; }
.sp-trs { font-size:13px; font-weight:700; }

.sp-section { padding:12px 16px; border-bottom:1px solid #1e1e38; }
.sp-sec-title { font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.7px; color:#6b7280; margin-bottom:8px; }
.sp-sec-warn { color:#f59e0b; }
.sp-sec-stop { color:#ef4444; }
.sp-empty { font-size:12px; color:#4b5563; font-style:italic; }

.sp-lot-row { display:flex; align-items:center; justify-content:space-between; padding:7px 10px; background:#1e1e38; border-radius:4px; margin-bottom:4px; }
.sp-lot-left { min-width:0; }
.sp-lot-num { font-size:13px; font-weight:600; color:#fff; font-family:monospace; }
.sp-lot-prod { font-size:11px; color:#9ca3af; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.sp-lot-right { display:flex; flex-direction:column; align-items:flex-end; gap:2px; }
.sp-lot-stat { font-size:10px; padding:2px 7px; border-radius:3px; font-weight:600; }
.ls-en-cours { background:#d1fae5; color:#065f46; }
.ls-arrêt, .ls-arret { background:#fee2e2; color:#991b1b; }
.sp-lot-dur { font-size:10px; color:#6b7280; font-variant-numeric:tabular-nums; }

.sp-dev-row { padding:6px 10px; background:#2d1f0e; border-radius:4px; border-left:3px solid #f59e0b; margin-bottom:4px; }
.sp-dev-bl { display:inline-block; font-size:9px; font-weight:700; background:#ef4444; color:#fff; padding:1px 5px; border-radius:2px; margin-right:6px; }
.sp-dev-desc { font-size:12px; color:#e2e8f0; }
.sp-dev-date { display:block; font-size:10px; color:#6b7280; margin-top:2px; }

.sp-arr-row { display:flex; align-items:center; gap:8px; padding:6px 10px; background:#1f0e0e; border-radius:4px; border-left:3px solid #ef4444; margin-bottom:4px; }
.sp-arr-timer { font-size:12px; font-weight:700; color:#ef4444; font-variant-numeric:tabular-nums; white-space:nowrap; }
.sp-arr-nom { flex:1; font-size:12px; color:#e2e8f0; }
.sp-arr-type { font-size:10px; font-weight:600; }

.sp-actions { padding:12px 16px; margin-top:auto; display:flex; flex-wrap:wrap; gap:6px; }
.sp-btn { flex:1; min-width:120px; padding:8px 10px; border-radius:4px; border:none; background:#2563eb; color:#fff; font-size:12px; font-weight:600; cursor:pointer; transition:.15s; }
.sp-btn:hover { background:#1d4ed8; }
.sp-btn.sp-btn-sec { background:#374151; }
.sp-btn.sp-btn-sec:hover { background:#4b5563; }

/* ── Modal nouveau hotspot ── */
.modal-overlay { position:fixed; inset:0; background:rgba(0,0,0,.7); z-index:1000; display:flex; align-items:center; justify-content:center; }
.modal-new-room { background:#1a1a2e; border:1px solid #3a3a5c; border-radius:8px; width:420px; max-width:95vw; }
.modal-hd { padding:16px 20px; border-bottom:1px solid #2a2a4a; font-weight:600; color:#fff; font-size:14px; }
.modal-body { padding:20px; display:flex; flex-direction:column; gap:12px; }
.modal-ft { padding:14px 20px; border-top:1px solid #2a2a4a; display:flex; justify-content:flex-end; gap:8px; }
.form-row { display:flex; flex-direction:column; gap:4px; }
.form-row label { font-size:11px; color:#9ca3af; text-transform:uppercase; letter-spacing:.5px; }
.form-inp { padding:7px 10px; border:1px solid #3a3a5c; border-radius:4px; background:#0f0f23; color:#e2e8f0; font-size:13px; }
.btn-cancel { padding:7px 16px; border:1px solid #3a3a5c; border-radius:4px; background:transparent; color:#9ca3af; font-size:13px; cursor:pointer; }
.btn-save { padding:7px 20px; border:none; border-radius:4px; background:#2563eb; color:#fff; font-size:13px; cursor:pointer; font-weight:600; }
</style>
