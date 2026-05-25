<template>
  <div class="flow-page">

    <!-- ── HEADER ── -->
    <div class="flow-header">
      <div class="fh-left">
        <div class="fh-title">SCHÉMA FLUX PRODUCTION</div>
        <div class="fh-sub">Vision processus — mise à jour en temps réel</div>
      </div>
      <div class="fh-right">
        <div class="fh-legend">
          <span class="fl" v-for="l in legend" :key="l.label">
            <span class="fl-dot" :style="{background:l.color}"></span>{{l.label}}
          </span>
        </div>
        <button class="fh-btn" :class="{spinning:loading}" @click="loadLive" title="Rafraîchir">↻</button>
      </div>
    </div>

    <!-- ── CORPS SVG ── -->
    <div class="flow-body" ref="flowBody">
      <svg
        class="flow-svg"
        :viewBox="'0 0 '+SVG_W+' '+SVG_H"
        preserveAspectRatio="xMidYMid meet"
        xmlns="http://www.w3.org/2000/svg"
      >
        <!-- ────────────────────────────────────────── FOND -->
        <defs>
          <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
            <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#1e1e3a" stroke-width="0.5"/>
          </pattern>
          <filter id="glow">
            <feGaussianBlur stdDeviation="3" result="blur"/>
            <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
          </filter>
          <marker id="arr" markerWidth="8" markerHeight="8" refX="7" refY="3" orient="auto">
            <path d="M0,0 L0,6 L8,3 z" fill="#4b5563"/>
          </marker>
          <marker id="arr-active" markerWidth="8" markerHeight="8" refX="7" refY="3" orient="auto">
            <path d="M0,0 L0,6 L8,3 z" fill="#10b981"/>
          </marker>
        </defs>
        <rect width="100%" height="100%" fill="url(#grid)"/>

        <!-- ────────────────────────────────────────── ZONES BACKGROUND -->
        <!-- Zone Formes Sèches -->
        <rect :x="TRACK_X" :y="ZONE_FS_Y" :width="TRACKS_W" :height="ZONE_FS_H"
          rx="12" fill="#7c3aed" opacity="0.06"/>
        <text :x="TRACK_X+12" :y="ZONE_FS_Y+22" fill="#7c3aed" font-size="11"
          font-weight="700" letter-spacing="2" opacity="0.8">FORMES SÈCHES</text>

        <!-- Zone Formes Semi-Solides -->
        <rect :x="TRACK_X" :y="ZONE_SS_Y" :width="TRACKS_W" :height="ZONE_SS_H"
          rx="12" fill="#2563eb" opacity="0.06"/>
        <text :x="TRACK_X+12" :y="ZONE_SS_Y+22" fill="#2563eb" font-size="11"
          font-weight="700" letter-spacing="2" opacity="0.8">FORMES SEMI-SOLIDES</text>

        <!-- Zone Conditionnement (right column) -->
        <rect :x="COND_X" :y="COND_Y" :width="COND_W" :height="COND_H"
          rx="12" fill="#059669" opacity="0.06"/>
        <text :x="COND_X+COND_W/2" :y="COND_Y+22" text-anchor="middle" fill="#059669"
          font-size="11" font-weight="700" letter-spacing="2" opacity="0.8">CONDITIONNEMENT</text>

        <!-- Zone Pesée (top left) -->
        <rect :x="PESEE_X" :y="PESEE_Y" :width="PESEE_W" :height="PESEE_H"
          rx="12" fill="#d97706" opacity="0.06"/>
        <text :x="PESEE_X+12" :y="PESEE_Y+22" fill="#d97706" font-size="11"
          font-weight="700" letter-spacing="2" opacity="0.8">PESÉE</text>

        <!-- Zone Injectable (bottom right) -->
        <rect :x="INJ_X" :y="INJ_Y" :width="INJ_W" :height="INJ_H"
          rx="12" fill="#db2777" opacity="0.06"/>
        <text :x="INJ_X+12" :y="INJ_Y+22" fill="#db2777" font-size="11"
          font-weight="700" letter-spacing="2" opacity="0.8">FORMES INJECTABLES</text>

        <!-- ────────────────────────────────────────── FLÈCHES -->
        <!-- Flux Formes Sèches Z100 -->
        <g v-for="arr in arrows" :key="arr.id">
          <path :d="arr.d" fill="none"
            :stroke="arr.active?'#10b981':'#374151'"
            stroke-width="2"
            :stroke-dasharray="arr.active?'none':'6,3'"
            :marker-end="arr.active?'url(#arr-active)':'url(#arr)'"
            opacity="0.9"/>
        </g>

        <!-- ────────────────────────────────────────── NODES -->
        <g v-for="node in allNodes" :key="node.id"
          class="flow-node"
          @click="selectNode(node)"
          :class="{'node-selected': selectedNode && selectedNode.id===node.id}"
        >
          <!-- Fond node -->
          <rect
            :x="node.x" :y="node.y" :width="node.w" :height="node.h"
            :rx="8"
            :fill="nodeColor(node)"
            :stroke="nodeStroke(node)"
            :stroke-width="selectedNode&&selectedNode.id===node.id?2.5:1.5"
            opacity="0.92"
          />
          <!-- Barre de statut en bas -->
          <rect v-if="nodeStatus(node).label!=='Libre'"
            :x="node.x+2" :y="node.y+node.h-5" :width="node.w-4" height="5"
            :fill="nodeStatus(node).color" rx="0" opacity="0.9"
            :style="{borderBottomLeftRadius:'6px',borderBottomRightRadius:'6px'}"/>
          <!-- Code salle -->
          <text :x="node.x+node.w/2" :y="node.y+20"
            text-anchor="middle" fill="rgba(255,255,255,.95)"
            font-size="16" font-weight="800" font-family="monospace">
            {{node.code}}
          </text>
          <!-- Nom salle (2 lignes si nécessaire) -->
          <text :x="node.x+node.w/2" :y="node.y+36"
            text-anchor="middle" fill="rgba(255,255,255,.75)" font-size="9.5">
            {{node.line1}}
          </text>
          <text v-if="node.line2" :x="node.x+node.w/2" :y="node.y+48"
            text-anchor="middle" fill="rgba(255,255,255,.75)" font-size="9.5">
            {{node.line2}}
          </text>
          <!-- Dot statut -->
          <circle v-if="nodeStatus(node).label!=='Libre'"
            :cx="node.x+node.w-10" :cy="node.y+10" r="6"
            :fill="nodeStatus(node).color" stroke="rgba(255,255,255,.5)" stroke-width="1"
            filter="url(#glow)"/>
          <!-- Count lots -->
          <text v-if="activeLotCount(node)>0"
            :x="node.x+10" :y="node.y+12"
            fill="rgba(255,255,255,.8)" font-size="9" font-weight="700">
            {{activeLotCount(node)}}L
          </text>
        </g>

        <!-- ────────────────────────────────────────── TITRE CENTRAL -->
        <rect :x="SVG_W/2-140" :y="SVG_H/2-28" width="280" height="56"
          rx="28" fill="#1a1a3e" stroke="#3b3b6e" stroke-width="1.5"/>
        <text :x="SVG_W/2" :y="SVG_H/2-4" text-anchor="middle"
          fill="#7c7cff" font-size="13" font-weight="800" letter-spacing="2">
          PRODUCTION
        </text>
        <text :x="SVG_W/2" :y="SVG_H/2+14" text-anchor="middle"
          fill="#4b4b8a" font-size="9" letter-spacing="3">
          LDM GROUPE
        </text>

        <!-- ────────────────────────────────────────── LABELS ÉTAPES -->
        <g v-for="step in stepLabels" :key="step.id">
          <line :x1="step.x" :y1="step.y1" :x2="step.x" :y2="step.y2"
            stroke="#2a2a4a" stroke-width="1" stroke-dasharray="3,3"/>
          <rect :x="step.x-step.tw/2" :y="step.y2+2" :width="step.tw" height="18"
            rx="3" fill="#12122a"/>
          <text :x="step.x" :y="step.y2+14" text-anchor="middle"
            fill="#4b5563" font-size="9" font-weight="600" letter-spacing="1">
            {{step.label}}
          </text>
        </g>

      </svg>
    </div>

    <!-- ── PANEL DÉTAIL NŒUD ── -->
    <transition name="panel-slide">
      <div class="detail-panel" v-if="selectedNode" @click.stop>
        <div class="dp-hd" :style="{borderLeftColor: zoneColor(selectedNode.zone)}">
          <div>
            <div class="dp-code">{{selectedNode.code}}</div>
            <div class="dp-nom">{{selectedNode.nom}}</div>
            <div class="dp-zone">{{zoneLabel(selectedNode.zone)}}</div>
          </div>
          <button class="dp-close" @click="selectedNode=null">✕</button>
        </div>
        <div class="dp-status" :style="{background:nodeStatus(selectedNode).color+'33'}">
          <span class="dp-st-icon" :style="{color:nodeStatus(selectedNode).color}">
            {{nodeStatus(selectedNode).icon}}
          </span>
          <span class="dp-st-label">{{nodeStatus(selectedNode).label}}</span>
        </div>
        <div class="dp-section">
          <div class="dp-sec-title">Lots en cours</div>
          <div v-if="!getNodeLots(selectedNode).length" class="dp-empty">Aucun lot actif</div>
          <div v-for="lot in getNodeLots(selectedNode)" :key="lot.id" class="dp-lot-row">
            <span class="dp-lot-num">{{lot.numero_lot}}</span>
            <span class="dp-lot-prod">{{lot.nom_produit||'—'}}</span>
            <span class="dp-lot-st" :class="'ls-'+lot.statut?.toLowerCase()">{{lot.statut}}</span>
          </div>
        </div>
        <div class="dp-actions">
          <button class="dp-btn" @click="goTo(selectedNode)">
            {{selectedNode.type==='cond'?'📦 Suivi Cond':'📋 Suivi Fab'}}
          </button>
          <button class="dp-btn dp-btn-plan" @click="goToPlan(selectedNode)">
            🗺 Voir sur plan
          </button>
        </div>
      </div>
    </transition>

  </div>
</template>

<script>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'

// ── LAYOUT CONSTANTS ──────────────────────────────────────────────
var SVG_W  = 1540
var SVG_H  = 920
var NW     = 148   // node width
var NH     = 62    // node height
var HGAP   = 30    // horizontal gap between nodes
var STEP   = NW + HGAP  // 178px per step

// Pesée column (far left)
var PESEE_X = 30
var PESEE_Y = 30
var PESEE_W = NW + 20
var PESEE_H = 420

// Production tracks start (after pesée)
var TRACK_X   = PESEE_X + PESEE_W + 20   // ~220
var TRACKS_W  = 820
var ZONE_FS_Y = 30
var ZONE_FS_H = 560
var ZONE_SS_Y = 610
var ZONE_SS_H = 130

// Conditionnement column (right)
var COND_X = TRACK_X + TRACKS_W + 30     // ~1070
var COND_Y = 30
var COND_W = 200
var COND_H = 740

// Injectable (bottom right)
var INJ_X = COND_X
var INJ_Y = 790
var INJ_W = COND_W
var INJ_H = 110

// Track Y positions (center of node)
var T1Y = 100    // Zone 100 - Track 1 (Granulation→Compression→Pelliculage)
var T2Y = 240    // Zone 100 - Track 2 (Mélange→Compression alt)
var T3Y = 380    // Zone 400 - Track 1
var T4Y = 490    // Zone 400 - Track 2 (Formulation / Remplissage)
var T5Y = 650    // Formes Semi-Solides
var COND_PRIM_Y = 120   // Cond primaire nodes
var COND_SEC_Y  = 440   // Cond secondaire nodes
var INJ_NODE_Y  = 820   // Injectable node

// ── NODE DEFINITIONS ─────────────────────────────────────────────
// x is computed from TRACK_X + column * STEP
var buildNode = function(id, code, nom, zone, type, col, trackY, overX) {
  var x = overX !== undefined ? overX : (TRACK_X + col * STEP + 10)
  var y = trackY - NH / 2
  var words = nom.split(' ')
  var mid = Math.ceil(words.length / 2)
  return {
    id, code, nom, zone, type,
    x, y, w: NW, h: NH,
    line1: words.slice(0, mid).join(' '),
    line2: words.slice(mid).join(' ') || null,
    col
  }
}

var NODES_DEF = [
  // ── PESÉE (column far left)
  buildNode('p464', '464', 'Salle Pesée -02', 'pesee', 'pesee', 0, T1Y, PESEE_X + 10),
  buildNode('p471', '471', 'Salle Pesée -03', 'pesee', 'pesee', 0, T3Y, PESEE_X + 10),

  // ── ZONE 100 — Track 1 : Granulation → Mélange 01 → Compression 01 → Pelliculage 01
  buildNode('n140', '140', 'Granulation Séchage 01', 'formes_seches', 'fab', 0, T1Y),
  buildNode('n138', '138', 'Mélange 01 Tamisage', 'formes_seches', 'fab', 1, T1Y),
  buildNode('n131', '131', 'Compression 01', 'formes_seches', 'fab', 2, T1Y),
  buildNode('n143', '143', 'Pelliculage 01', 'formes_seches', 'fab', 3, T1Y),

  // ── ZONE 100 — Track 2 : Mélange 02/03 → Compression 03/02 → Pelliculage 03
  buildNode('n529', '529', 'Mélange 03 Tamisage', 'formes_seches', 'fab', 0, T2Y),
  buildNode('n137', '137', 'Mélange 02 Tamisage', 'formes_seches', 'fab', 1, T2Y),
  buildNode('n134', '134', 'Compression 03', 'formes_seches', 'fab', 2, T2Y),
  buildNode('n136', '136', 'Pelliculage 03', 'formes_seches', 'fab', 3, T2Y),

  // ── ZONE 400 — Track 1 : Granulation 02 → Mélange 03 → Compression 04 → Pelliculage 02
  buildNode('n425', '425', 'Granulation Séchage 02', 'formes_seches', 'fab', 0, T3Y),
  buildNode('n448', '448', 'Mélange 03', 'formes_seches', 'fab', 1, T3Y),
  buildNode('n445', '445', 'Compression 04', 'formes_seches', 'fab', 2, T3Y),
  buildNode('n429', '429', 'Pelliculage 02', 'formes_seches', 'fab', 3, T3Y),

  // ── ZONE 400 — Track 2 : Formulation → Remplissage Gélules
  buildNode('n442', '442', 'Salle de Formulation', 'formes_seches', 'fab', 0, T4Y),
  buildNode('n436', '436', 'Remplissage Gélules 02', 'formes_seches', 'fab', 1, T4Y),

  // ── FORMES SEMI-SOLIDES
  buildNode('n200', '200', 'Mélange Homogénéisateur', 'formes_semi', 'fab', 0, T5Y),
  buildNode('n206', '206', 'Remplissage Tubes', 'formes_semi', 'fab', 1, T5Y),

  // ── CONDITIONNEMENT PRIMAIRE (right column, stacked)
  buildNode('c149', '149', 'Cond. Primaire 01', 'cond_secondaire', 'cond', 0, COND_PRIM_Y + 0,   COND_X + 26),
  buildNode('c148', '148', 'Cond. Primaire 02', 'cond_secondaire', 'cond', 0, COND_PRIM_Y + 80,  COND_X + 26),
  buildNode('c147', '147', 'Cond. Primaire 03', 'cond_secondaire', 'cond', 0, COND_PRIM_Y + 160, COND_X + 26),
  buildNode('c146', '146', 'Cond. Primaire 04', 'cond_secondaire', 'cond', 0, COND_PRIM_Y + 240, COND_X + 26),

  // ── CONDITIONNEMENT SECONDAIRE (right column, below cond prim)
  buildNode('c153', '153', 'Cond. Secondaire', 'cond_secondaire', 'cond', 0, COND_SEC_Y,       COND_X + 26),
  buildNode('c154', '154', 'Cond. Sec. Extension', 'cond_secondaire', 'cond', 0, COND_SEC_Y + 80, COND_X + 26),

  // ── INJECTABLES
  buildNode('i521', '521', 'Réception Injectables', 'injectable', 'cond', 0, INJ_NODE_Y, COND_X + 26),
]

// ── ARROWS DEFINITION (from, to) ─────────────────────────────────
var ARROWS_DEF = [
  // Pesée → Granulation
  { id: 'a1', from: 'p464', to: 'n140' },
  { id: 'a2', from: 'p471', to: 'n425' },
  // Zone 100 Track 1
  { id: 'a3', from: 'n140', to: 'n138' },
  { id: 'a4', from: 'n138', to: 'n131' },
  { id: 'a5', from: 'n131', to: 'n143' },
  // Zone 100 Track 2
  { id: 'a6', from: 'n529', to: 'n137' },
  { id: 'a7', from: 'n137', to: 'n134' },
  { id: 'a8', from: 'n134', to: 'n136' },
  // Zone 400 Track 1
  { id: 'a9',  from: 'n425', to: 'n448' },
  { id: 'a10', from: 'n448', to: 'n445' },
  { id: 'a11', from: 'n445', to: 'n429' },
  // Zone 400 Track 2
  { id: 'a12', from: 'n442', to: 'n436' },
  // Semi-solides
  { id: 'a13', from: 'n200', to: 'n206' },
  // Pelliculages → Cond Primaire
  { id: 'a14', from: 'n143', to: 'c149' },
  { id: 'a15', from: 'n136', to: 'c147' },
  { id: 'a16', from: 'n429', to: 'c146' },
  { id: 'a17', from: 'n436', to: 'c148' },
  { id: 'a18', from: 'n206', to: 'c149' },
  // Cond Prim → Cond Sec
  { id: 'a19', from: 'c149', to: 'c153' },
  { id: 'a20', from: 'c147', to: 'c153' },
  { id: 'a21', from: 'c146', to: 'c154' },
  { id: 'a22', from: 'c148', to: 'c154' },
]

// ── STEP LABELS ───────────────────────────────────────────────────
var STEP_LABELS = [
  { id: 'sl1', label: 'PESÉE',            x: PESEE_X + PESEE_W/2, y1: 30,  y2: 230, tw: 60 },
  { id: 'sl2', label: 'GRANULATION',      x: TRACK_X + 0*STEP + NW/2 + 10, y1: 30, y2: 560, tw: 90 },
  { id: 'sl3', label: 'MÉLANGE',          x: TRACK_X + 1*STEP + NW/2 + 10, y1: 30, y2: 560, tw: 72 },
  { id: 'sl4', label: 'COMPRESSION',      x: TRACK_X + 2*STEP + NW/2 + 10, y1: 30, y2: 560, tw: 90 },
  { id: 'sl5', label: 'PELLICULAGE',      x: TRACK_X + 3*STEP + NW/2 + 10, y1: 30, y2: 560, tw: 84 },
  { id: 'sl6', label: 'CONDITIONNEMENT',  x: COND_X + COND_W/2,  y1: 30, y2: 770, tw: 110 },
]

export default {
  setup() {
    var router = useRouter()

    var loading       = ref(false)
    var selectedNode  = ref(null)
    var suiviFab      = ref([])
    var sessions      = ref([])
    var deviations    = ref([])
    var arrets        = ref([])
    var rooms         = ref([])

    var legend = [
      { label: 'En cours', color: '#10b981' },
      { label: 'Arrêt',    color: '#ef4444' },
      { label: 'Déviation',color: '#f59e0b' },
      { label: 'Libre',    color: '#4b5563' },
    ]

    var zones = [
      { key: 'formes_seches',   label: 'Formes Sèches',        color: '#7c3aed' },
      { key: 'formes_semi',     label: 'Formes Semi-Solides',   color: '#2563eb' },
      { key: 'cond_secondaire', label: 'Conditionnement',       color: '#059669' },
      { key: 'pesee',           label: 'Zone Pesée',            color: '#d97706' },
      { key: 'injectable',      label: 'Formes Injectables',    color: '#db2777' },
    ]

    var zoneColor = function(z) {
      var found = zones.find(function(x) { return x.key === z })
      return found ? found.color : '#888'
    }
    var zoneLabel = function(z) {
      var found = zones.find(function(x) { return x.key === z })
      return found ? found.label : '—'
    }

    // ─── NODES enrichis avec la lookup room de Supabase ──────────
    var allNodes = computed(function() {
      return NODES_DEF.map(function(n) {
        var room = rooms.value.find(function(r) { return r.code === n.code })
        return Object.assign({}, n, {
          atelier_id:    room ? room.atelier_id    : null,
          equipement_id: room ? room.equipement_id : null,
        })
      })
    })

    // ─── ARROWS calculées à partir des node positions ────────────
    var arrows = computed(function() {
      return ARROWS_DEF.map(function(a) {
        var fromNode = allNodes.value.find(function(n) { return n.id === a.from })
        var toNode   = allNodes.value.find(function(n) { return n.id === a.to   })
        if (!fromNode || !toNode) return null
        var x1 = fromNode.x + fromNode.w
        var y1 = fromNode.y + fromNode.h / 2
        var x2 = toNode.x
        var y2 = toNode.y + toNode.h / 2
        // Si même x (flèche verticale)
        if (Math.abs(x1 - x2) < 20) {
          x1 = fromNode.x + fromNode.w / 2
          y1 = fromNode.y + fromNode.h
          x2 = toNode.x + toNode.w / 2
          y2 = toNode.y - 2
        }
        var active = nodeStatus(fromNode).label === 'En cours'
        var mx = (x1 + x2) / 2
        return Object.assign({}, a, {
          d: 'M'+x1+','+y1+' C'+mx+','+y1+' '+mx+','+y2+' '+x2+','+y2,
          active
        })
      }).filter(Boolean)
    })

    // ─── LIVE DATA HELPERS ───────────────────────────────────────
    var nodeStatus = function(node) {
      var sessIds = sessions.value
        .filter(function(s) { return s.equipement_id === node.equipement_id })
        .map(function(s) { return s.id })
      var hasArret = arrets.value.some(function(a) { return sessIds.includes(a.session_id) })
      var hasFabArret = suiviFab.value.some(function(sf) {
        return sf.atelier_id === node.atelier_id && sf.statut === 'Arrêt'
      })
      var lotIds = []
      suiviFab.value.filter(function(sf) { return sf.atelier_id === node.atelier_id })
        .forEach(function(sf) { lotIds.push(sf.lot_id) })
      sessions.value.filter(function(s) { return s.equipement_id === node.equipement_id })
        .forEach(function(s) { lotIds.push(s.lot_id) })
      var hasDev = deviations.value.some(function(d) { return lotIds.includes(d.lot_id) })
      var hasFabActive = suiviFab.value.some(function(sf) {
        return sf.atelier_id === node.atelier_id && sf.statut === 'En cours'
      })
      var hasSessActive = sessions.value.some(function(s) {
        return s.equipement_id === node.equipement_id && s.statut === 'En cours'
      })
      if (hasArret || hasFabArret) return { label: 'Arrêt',    icon: '⏸', color: '#ef4444' }
      if (hasDev)                   return { label: 'Déviation',icon: '⚠', color: '#f59e0b' }
      if (hasFabActive || hasSessActive) return { label: 'En cours', icon: '🔄', color: '#10b981' }
      return { label: 'Libre', icon: '✓', color: '#4b5563' }
    }

    var nodeColor = function(node) {
      var st = nodeStatus(node)
      if (st.label === 'Arrêt')     return '#3f1212'
      if (st.label === 'Déviation') return '#3f2e00'
      if (st.label === 'En cours')  return '#0d2e20'
      var z = zones.find(function(x) { return x.key === node.zone })
      return z ? z.color + '22' : '#1e1e3a'
    }

    var nodeStroke = function(node) {
      if (selectedNode.value && selectedNode.value.id === node.id) return '#fff'
      var st = nodeStatus(node)
      if (st.label === 'Arrêt')     return '#ef4444'
      if (st.label === 'Déviation') return '#f59e0b'
      if (st.label === 'En cours')  return '#10b981'
      return zoneColor(node.zone) + '88'
    }

    var activeLotCount = function(node) {
      var c = suiviFab.value.filter(function(sf) {
        return sf.atelier_id === node.atelier_id && sf.statut === 'En cours'
      }).length
      c += sessions.value.filter(function(s) {
        return s.equipement_id === node.equipement_id && s.statut === 'En cours'
      }).length
      return c
    }

    var getNodeLots = function(node) {
      var res = []
      suiviFab.value.filter(function(sf) { return sf.atelier_id === node.atelier_id })
        .forEach(function(sf) {
          res.push({
            id: 'f' + sf.id,
            numero_lot: sf.lots?.numero_lot || sf.lot_id,
            nom_produit: sf.lots?.products?.nom_produit || '',
            statut: sf.statut
          })
        })
      sessions.value.filter(function(s) { return s.equipement_id === node.equipement_id })
        .forEach(function(s) {
          res.push({
            id: 's' + s.id,
            numero_lot: s.lots?.numero_lot || s.lot_id,
            nom_produit: s.lots?.products?.nom_produit || '',
            statut: s.statut
          })
        })
      return res
    }

    // ─── LOAD ────────────────────────────────────────────────────
    var loadLive = async function() {
      loading.value = true
      var [r1, r2, r3, r4, r5] = await Promise.all([
        supabase.from('plan_rooms').select('*'),
        supabase.from('suivi_fabrication')
          .select('id,lot_id,atelier_id,statut,lots(numero_lot,products(nom_produit))')
          .is('deleted_at', null).in('statut', ['En cours', 'Arrêt']),
        supabase.from('production_sessions')
          .select('id,lot_id,equipement_id,statut,lots(numero_lot,products(nom_produit))')
          .in('statut', ['En cours', 'Arrêt']),
        supabase.from('deviations')
          .select('id,lot_id,statut').in('statut', ['ouverte', 'en_cours']),
        supabase.from('production_arrets')
          .select('id,session_id,is_running').eq('is_running', true),
      ])
      if (!r1.error) rooms.value      = r1.data
      if (!r2.error) suiviFab.value   = r2.data
      if (!r3.error) sessions.value   = r3.data
      if (!r4.error) deviations.value = r4.data
      if (!r5.error) arrets.value     = r5.data
      loading.value = false
    }

    // ─── ACTIONS ─────────────────────────────────────────────────
    var selectNode = function(node) { selectedNode.value = node }
    var goTo = function(node) {
      if (node.type === 'cond') router.push('/tracking/pdp-cond')
      else router.push('/tracking/pdp-fab')
    }
    var goToPlan = function(node) {
      router.push('/production/plan')
    }

    // ─── LIFECYCLE ───────────────────────────────────────────────
    var refreshInt = null
    onMounted(async function() {
      await loadLive()
      refreshInt = setInterval(loadLive, 60000)
    })
    onBeforeUnmount(function() { clearInterval(refreshInt) })

    return {
      SVG_W, SVG_H, NW, NH,
      TRACK_X, TRACKS_W, ZONE_FS_Y, ZONE_FS_H, ZONE_SS_Y, ZONE_SS_H,
      COND_X, COND_Y, COND_W, COND_H,
      PESEE_X, PESEE_Y, PESEE_W, PESEE_H,
      INJ_X, INJ_Y, INJ_W, INJ_H,
      loading, legend, zones,
      allNodes, arrows, selectedNode,
      stepLabels: STEP_LABELS,
      zoneColor, zoneLabel,
      nodeStatus, nodeColor, nodeStroke, activeLotCount,
      getNodeLots, selectNode, goTo, goToPlan, loadLive,
    }
  }
}
</script>

<style scoped>
/* ── Base ── */
.flow-page { display:flex; flex-direction:column; height:calc(100vh - 48px); background:#0a0a1e; overflow:hidden; margin:-16px -20px; font-family:'Inter',sans-serif; }

/* ── Header ── */
.flow-header { display:flex; align-items:center; justify-content:space-between; padding:10px 20px; background:#0f0f23; border-bottom:1px solid #1e1e3a; flex-shrink:0; }
.fh-title { font-size:13px; font-weight:800; letter-spacing:3px; color:#7c7cff; }
.fh-sub   { font-size:11px; color:#4b5563; margin-top:2px; }
.fh-right { display:flex; align-items:center; gap:14px; }
.fh-legend { display:flex; gap:12px; flex-wrap:wrap; }
.fl { display:flex; align-items:center; gap:4px; font-size:11px; color:#6b7280; }
.fl-dot { width:8px; height:8px; border-radius:50%; }
.fh-btn { width:32px; height:32px; border:1px solid #2a2a4a; border-radius:4px; background:transparent; color:#6b7280; cursor:pointer; font-size:16px; }
.fh-btn:hover { background:#1a1a3e; color:#fff; }
.fh-btn.spinning { animation:spin 1s linear infinite; }
@keyframes spin { to { transform:rotate(360deg) } }

/* ── Corps ── */
.flow-body { flex:1; display:flex; overflow:hidden; position:relative; }
.flow-svg  { width:100%; height:100%; display:block; }

/* ── Nodes ── */
.flow-node { cursor:pointer; transition:opacity .15s; }
.flow-node:hover rect { opacity:1 !important; stroke-width:2px; }
.node-selected rect { stroke-width:3px !important; }

/* ── Detail Panel ── */
.detail-panel { width:300px; flex-shrink:0; background:#0f0f23; border-left:1px solid #1e1e3a; display:flex; flex-direction:column; z-index:10; }
.panel-slide-enter-active,.panel-slide-leave-active { transition:transform .22s ease,opacity .22s; }
.panel-slide-enter-from,.panel-slide-leave-to { transform:translateX(100%); opacity:0; }

.dp-hd { padding:14px 16px; border-bottom:1px solid #1e1e3a; display:flex; align-items:flex-start; justify-content:space-between; border-left:4px solid #888; }
.dp-code { font-size:22px; font-weight:800; color:#fff; font-family:monospace; }
.dp-nom  { font-size:12px; color:#e2e8f0; margin-top:3px; line-height:1.4; }
.dp-zone { font-size:10px; color:#4b5563; margin-top:4px; text-transform:uppercase; letter-spacing:.5px; }
.dp-close { background:none; border:none; color:#4b5563; cursor:pointer; font-size:18px; }

.dp-status { display:flex; align-items:center; gap:8px; padding:10px 16px; }
.dp-st-icon { font-size:18px; }
.dp-st-label { font-size:13px; font-weight:600; color:#fff; }

.dp-section { padding:12px 16px; border-bottom:1px solid #1a1a38; }
.dp-sec-title { font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.7px; color:#4b5563; margin-bottom:8px; }
.dp-empty { font-size:12px; color:#374151; font-style:italic; }
.dp-lot-row { display:flex; align-items:center; gap:8px; padding:5px 8px; background:#1a1a38; border-radius:4px; margin-bottom:4px; }
.dp-lot-num  { font-family:monospace; font-size:12px; font-weight:700; color:#fff; }
.dp-lot-prod { flex:1; font-size:11px; color:#9ca3af; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.dp-lot-st   { font-size:10px; padding:2px 6px; border-radius:3px; font-weight:600; }
.ls-en.cours { background:#d1fae5; color:#065f46; }
.ls-arrêt,.ls-arret { background:#fee2e2; color:#991b1b; }

.dp-actions { padding:12px 16px; margin-top:auto; display:flex; flex-direction:column; gap:6px; }
.dp-btn { padding:9px 12px; border-radius:4px; border:none; background:#2563eb; color:#fff; font-size:12px; font-weight:600; cursor:pointer; text-align:center; }
.dp-btn:hover { background:#1d4ed8; }
.dp-btn.dp-btn-plan { background:#374151; }
.dp-btn.dp-btn-plan:hover { background:#4b5563; }
</style>
