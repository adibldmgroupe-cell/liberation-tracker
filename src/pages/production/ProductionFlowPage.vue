<template>
  <div class="flow-page" :data-theme="theme">

    <!-- ── HEADER ── -->
    <div class="flow-header">
      <div class="fh-left">
        <div class="fh-title">SCHÉMA FLUX PRODUCTION</div>
        <div class="fh-sub">Centre de commandement — temps réel</div>
      </div>

      <!-- ── PRODUCT SEARCH ── -->
      <div class="fh-center">
        <div class="prod-search-wrap" v-click-outside="closeSuggestions">
          <div class="psi-wrap">
            <span class="psi-icon">🔍</span>
            <input
              class="prod-input"
              placeholder="Chercher un produit pour visualiser son flux…"
              v-model="productSearch"
              @input="onProductSearch"
              @focus="onProductSearch"
              autocomplete="off"
            />
            <button v-if="productSearch" class="psi-clear" @click="clearProductSearch">✕</button>
          </div>
          <div class="prod-dropdown" v-if="productSuggestions.length && showSuggestions">
            <div class="pd-item" v-for="p in productSuggestions" :key="p.product_code+'-'+p.route"
              @click="pickProduct(p)">
              <span class="pd-code">{{p.product_code}}</span>
              <span class="pd-name">{{p.product_name}}</span>
              <span class="pd-type" :class="'pdt-'+p.type_flux">{{p.type_flux}}</span>
            </div>
          </div>
        </div>
        <div v-if="selectedProduct" class="prod-chip">
          <span class="pc-type" :class="'pct-'+selectedProduct.type_flux">{{selectedProduct.type_flux}}</span>
          <span class="pc-name">{{selectedProduct.product_name}}</span>
          <button v-if="selectedProduct.has_route_2" class="pc-route" @click="toggleRoute"
            :title="'Basculer Route '+(activeRoute===1?2:1)">R{{activeRoute}}</button>
          <button class="pc-x" @click="clearProduct">✕</button>
        </div>
      </div>

      <div class="fh-right">
        <div class="fh-legend" v-if="!trsMode">
          <span class="fl" v-for="l in legend" :key="l.label">
            <span class="fl-dot" :style="{background:l.color}"></span>{{l.label}}
          </span>
        </div>
        <div class="fh-legend" v-else>
          <span class="fl"><span class="fl-dot" style="background:#10b981"></span>≥85% Excellent</span>
          <span class="fl"><span class="fl-dot" style="background:#f59e0b"></span>≥60% Moyen</span>
          <span class="fl"><span class="fl-dot" style="background:#ef4444"></span>&lt;60% Faible</span>
        </div>
        <button class="fh-btn" :class="{spinning:loading}" @click="loadLive" title="Rafraîchir">↻</button>
        <button class="fh-btn" :class="{'fh-btn-trs-on': trsMode}" @click="toggleTrsMode" title="Mode TRS OEE">📊</button>
        <router-link to="/admin/flux" class="fh-btn fh-btn-admin" title="⚙ Paramétrer flux produits">⚙</router-link>
        <div class="theme-sw">
          <button class="tsw-btn" :class="{active:theme==='night'}" @click="theme='night'" title="Nuit">🌙</button>
          <button class="tsw-btn" :class="{active:theme==='day'}" @click="theme='day'" title="Jour">☀️</button>
          <button class="tsw-btn" :class="{active:theme==='workshop'}" @click="theme='workshop'" title="Atelier">🏭</button>
        </div>
      </div>
    </div>

    <!-- ── TRS BANDEAU ── -->
    <div class="trs-band" v-if="trsMode">
      <div class="trs-band-label">📊 MODE TRS — OEE TEMPS RÉEL</div>
      <div class="trs-kpi-group">
        <div class="trs-kpi">
          <div class="trs-kpi-val">{{trsSummary.active}}<span class="trs-kpi-tot">/{{trsSummary.total}}</span></div>
          <div class="trs-kpi-lbl">Machines actives</div>
        </div>
        <div class="trs-kpi trs-kpi-main">
          <div class="trs-kpi-val" :style="{color: trsColor(trsSummary.avgTrs)}">
            {{trsSummary.avgTrs != null ? trsSummary.avgTrs+'%' : '—'}}
          </div>
          <div class="trs-kpi-lbl">TRS moyen site</div>
        </div>
        <div class="trs-kpi">
          <div class="trs-kpi-val" :style="{color: trsSummary.arretsCount>0?'#ef4444':'#10b981'}">
            {{trsSummary.arretsCount}}
          </div>
          <div class="trs-kpi-lbl">Arrêts actifs</div>
        </div>
        <div class="trs-kpi">
          <div class="trs-kpi-val" :style="{color: trsColor(trsSummary.bestTrs)}">
            {{trsSummary.bestTrs != null ? trsSummary.bestTrs+'%' : '—'}}
          </div>
          <div class="trs-kpi-lbl">Meilleure machine</div>
        </div>
        <div class="trs-kpi">
          <div class="trs-kpi-val" :style="{color: trsColor(trsSummary.worstTrs)}">
            {{trsSummary.worstTrs != null ? trsSummary.worstTrs+'%' : '—'}}
          </div>
          <div class="trs-kpi-lbl">Machine la plus faible</div>
        </div>
      </div>
      <button class="trs-band-refresh" :class="{spinning:trsLoading}" @click="loadTrsData" title="Actualiser TRS">↻</button>
      <button class="trs-band-histo" @click="openTrsHisto" title="Historique sessions">📅</button>
    </div>

    <!-- ── CORPS SVG ── -->
    <div class="flow-body" ref="flowBody">
      <svg
        class="flow-svg"
        :viewBox="'0 0 '+SVG_W+' '+SVG_H"
        preserveAspectRatio="xMidYMid meet"
        xmlns="http://www.w3.org/2000/svg"
      >
        <defs>
          <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
            <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#1e1e3a" stroke-width="0.5"/>
          </pattern>
          <filter id="glow">
            <feGaussianBlur stdDeviation="3" result="blur"/>
            <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
          </filter>
          <filter id="glow-strong">
            <feGaussianBlur stdDeviation="5" result="blur"/>
            <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
          </filter>
          <marker id="arr" markerWidth="8" markerHeight="8" refX="7" refY="3" orient="auto">
            <path d="M0,0 L0,6 L8,3 z" fill="#4b5563"/>
          </marker>
          <marker id="arr-active" markerWidth="8" markerHeight="8" refX="7" refY="3" orient="auto">
            <path d="M0,0 L0,6 L8,3 z" fill="#10b981"/>
          </marker>
          <marker id="arr-flux" markerWidth="8" markerHeight="8" refX="7" refY="3" orient="auto">
            <path d="M0,0 L0,6 L8,3 z" fill="#fbbf24"/>
          </marker>
        </defs>
        <rect width="100%" height="100%" fill="url(#grid)"/>

        <!-- ── ZONES BACKGROUND ── -->
        <rect :x="TRACK_X" :y="ZONE_FS_Y" :width="TRACKS_W" :height="ZONE_FS_H"
          rx="12" fill="#7c3aed" opacity="0.06"/>
        <text :x="TRACK_X+12" :y="ZONE_FS_Y+22" fill="#7c3aed" font-size="11"
          font-weight="700" letter-spacing="2" opacity="0.8">FORMES SÈCHES</text>

        <rect :x="TRACK_X" :y="ZONE_SS_Y" :width="TRACKS_W" :height="ZONE_SS_H"
          rx="12" fill="#2563eb" opacity="0.06"/>
        <text :x="TRACK_X+12" :y="ZONE_SS_Y+22" fill="#2563eb" font-size="11"
          font-weight="700" letter-spacing="2" opacity="0.8">FORMES SEMI-SOLIDES</text>

        <!-- Zone OTC -->
        <rect :x="TRACK_X" :y="ZONE_OTC_Y" :width="5*STEP+NW" :height="ZONE_OTC_H"
          rx="12" fill="#0891b2" opacity="0.06"/>
        <text :x="TRACK_X+12" :y="ZONE_OTC_Y+22" fill="#0891b2" font-size="11"
          font-weight="700" letter-spacing="2" opacity="0.8">OTC</text>

        <rect :x="COND_X" :y="COND_Y" :width="COND_W" :height="COND_H"
          rx="12" fill="#059669" opacity="0.06"/>
        <text :x="COND_X+COND_W/2" :y="COND_Y+20" text-anchor="middle" fill="#059669"
          font-size="10" font-weight="700" letter-spacing="2" opacity="0.8">CONDITIONNEMENT</text>
        <text :x="COND_X+COND_W/2" :y="COND_Y+34" text-anchor="middle" fill="#059669"
          font-size="8" opacity="0.6">PRIMAIRE — 7 LIGNES</text>

        <rect :x="PESEE_X" :y="PESEE_Y" :width="PESEE_W" :height="PESEE_H"
          rx="12" fill="#d97706" opacity="0.06"/>
        <text :x="PESEE_X+12" :y="PESEE_Y+22" fill="#d97706" font-size="11"
          font-weight="700" letter-spacing="2" opacity="0.8">PESÉE</text>

        <!-- Zone SAS Livraison PF (à droite du COND) -->
        <rect :x="COND_X+COND_W+10" :y="COND_Y" :width="NW+40" height="360"
          rx="8" fill="#7c2d12" opacity="0.04" stroke="#7c2d12" stroke-opacity="0.15" stroke-width="1"/>
        <text :x="COND_X+COND_W+10+(NW+40)/2" :y="COND_Y+18" text-anchor="middle" fill="#7c2d12"
          font-size="9" font-weight="700" letter-spacing="1" opacity="0.7">LIVRAISON PF</text>

        <!-- ── FLÈCHES ── -->
        <g v-for="arr in arrows" :key="arr.id">
          <path :d="arr.d" fill="none"
            :stroke="arr.fluxHighlight?'#fbbf24':arr.active?'#10b981':'#374151'"
            :stroke-width="arr.fluxHighlight?3:2"
            :stroke-dasharray="arr.fluxHighlight?'none':arr.active?'none':'6,3'"
            :marker-end="arr.fluxHighlight?'url(#arr-flux)':arr.active?'url(#arr-active)':'url(#arr)'"
            :opacity="arr.fluxHighlight?1:selectedProduct?0.15:0.9"
            :filter="arr.fluxHighlight?'url(#glow)':''"/>
        </g>

        <!-- ── NODES ── -->
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
            :stroke-width="nodeStrokeWidth(node)"
            :opacity="nodeDim(node)"
            :filter="nodeIsFlux(node)?'url(#glow-strong)':''"
          />
          <!-- Barre statut (PDP uniquement) -->
          <rect v-if="nodeStatus(node).label!=='Libre' && !trsMode"
            :x="node.x+2" :y="node.y+node.h-5" :width="node.w-4" height="5"
            :fill="nodeStatus(node).color" rx="0"
            :opacity="nodeDim(node)*0.9"/>
          <!-- Code salle -->
          <text :x="node.x+node.w/2" :y="node.y+20"
            text-anchor="middle" fill="rgba(255,255,255,.95)"
            font-size="16" font-weight="800" font-family="monospace"
            :opacity="nodeDim(node)">
            {{node.code}}
          </text>
          <!-- Nom ligne 1 -->
          <text :x="node.x+node.w/2" :y="node.y+36"
            text-anchor="middle" fill="rgba(255,255,255,.75)" font-size="9.5"
            :opacity="nodeDim(node)">
            {{node.line1}}
          </text>
          <!-- Nom ligne 2 -->
          <text v-if="node.line2" :x="node.x+node.w/2" :y="node.y+48"
            text-anchor="middle" fill="rgba(255,255,255,.75)" font-size="9.5"
            :opacity="nodeDim(node)">
            {{node.line2}}
          </text>
          <!-- Dot statut PDP (masqué en mode TRS) -->
          <circle v-if="nodeStatus(node).label!=='Libre' && !trsMode"
            :cx="node.x+node.w-10" :cy="node.y+10" r="6"
            :fill="nodeStatus(node).color" stroke="rgba(255,255,255,.5)" stroke-width="1"
            filter="url(#glow)" :opacity="nodeDim(node)"/>
          <!-- Count lots PDP (masqué en mode TRS) -->
          <text v-if="activeLotCount(node)>0 && !trsMode"
            :x="node.x+10" :y="node.y+12"
            fill="rgba(255,255,255,.8)" font-size="9" font-weight="700"
            :opacity="nodeDim(node)">
            {{activeLotCount(node)}}L
          </text>
          <!-- Flux badge PDP (masqué en mode TRS) -->
          <rect v-if="nodeIsFlux(node) && !trsMode"
            :x="node.x" :y="node.y" :width="node.w" :height="node.h"
            rx="8" fill="none" stroke="#fbbf24" stroke-width="2.5"/>
          <!-- Dot TRS (mode TRS uniquement) -->
          <circle v-if="trsMode && node.type==='cond'"
            :cx="node.x+node.w-10" :cy="node.y+10" r="6"
            :fill="nodeTrs(node) && nodeTrs(node).statut==='En cours' ? '#10b981' : nodeTrs(node) && (nodeTrs(node).statut==='Arrêt'||nodeTrs(node).statut==='Pause') ? '#f59e0b' : '#374151'"
            stroke="rgba(255,255,255,.4)" stroke-width="1"
            filter="url(#glow)" :opacity="nodeDim(node)"/>

          <!-- ── TRS OVERLAY (mode TRS uniquement) ── -->
          <template v-if="trsMode">
            <!-- Fond bandeau bas -->
            <rect :x="node.x" :y="node.y+node.h-26" :width="node.w" height="26"
              rx="0" fill="rgba(0,0,0,0.82)" :opacity="nodeDim(node)"/>
            <!-- Séparateurs verticaux -->
            <line :x1="node.x+node.w*0.25" :y1="node.y+node.h-26" :x2="node.x+node.w*0.25" :y2="node.y+node.h"
              stroke="#2a2a4a" stroke-width="0.5" :opacity="nodeDim(node)"/>
            <line :x1="node.x+node.w*0.5"  :y1="node.y+node.h-26" :x2="node.x+node.w*0.5"  :y2="node.y+node.h"
              stroke="#2a2a4a" stroke-width="0.5" :opacity="nodeDim(node)"/>
            <line :x1="node.x+node.w*0.75" :y1="node.y+node.h-26" :x2="node.x+node.w*0.75" :y2="node.y+node.h"
              stroke="#2a2a4a" stroke-width="0.5" :opacity="nodeDim(node)"/>
            <!-- Labels D P Q TRS -->
            <text :x="node.x+node.w*0.125" :y="node.y+node.h-15" text-anchor="middle"
              fill="#6b7280" font-size="6" letter-spacing="0.5" :opacity="nodeDim(node)">D</text>
            <text :x="node.x+node.w*0.375" :y="node.y+node.h-15" text-anchor="middle"
              fill="#6b7280" font-size="6" letter-spacing="0.5" :opacity="nodeDim(node)">P</text>
            <text :x="node.x+node.w*0.625" :y="node.y+node.h-15" text-anchor="middle"
              fill="#6b7280" font-size="6" letter-spacing="0.5" :opacity="nodeDim(node)">Q</text>
            <text :x="node.x+node.w*0.875" :y="node.y+node.h-15" text-anchor="middle"
              fill="#9ca3af" font-size="6" font-weight="700" letter-spacing="0.5" :opacity="nodeDim(node)">TRS</text>
            <!-- Valeurs D -->
            <text :x="node.x+node.w*0.125" :y="node.y+node.h-4" text-anchor="middle"
              font-size="8" font-weight="700"
              :fill="nodeTrs(node) ? trsColor(nodeTrs(node).d) : '#374151'" :opacity="nodeDim(node)">
              {{nodeTrs(node) && nodeTrs(node).d != null ? nodeTrs(node).d+'%' : '—'}}
            </text>
            <!-- Valeurs P -->
            <text :x="node.x+node.w*0.375" :y="node.y+node.h-4" text-anchor="middle"
              font-size="8" font-weight="700"
              :fill="nodeTrs(node) ? trsColor(nodeTrs(node).p) : '#374151'" :opacity="nodeDim(node)">
              {{nodeTrs(node) && nodeTrs(node).p != null ? nodeTrs(node).p+'%' : '—'}}
            </text>
            <!-- Valeurs Q -->
            <text :x="node.x+node.w*0.625" :y="node.y+node.h-4" text-anchor="middle"
              font-size="8" font-weight="700"
              :fill="nodeTrs(node) ? trsColor(nodeTrs(node).q) : '#374151'" :opacity="nodeDim(node)">
              {{nodeTrs(node) && nodeTrs(node).q != null ? nodeTrs(node).q+'%' : '—'}}
            </text>
            <!-- Valeur TRS (plus grande) -->
            <text :x="node.x+node.w*0.875" :y="node.y+node.h-3" text-anchor="middle"
              font-size="9.5" font-weight="900"
              :fill="nodeTrs(node) && nodeTrs(node).trs != null ? trsColor(nodeTrs(node).trs) : '#374151'"
              :opacity="nodeDim(node)">
              {{nodeTrs(node) && nodeTrs(node).trs != null ? nodeTrs(node).trs+'%' : '—'}}
            </text>
          </template>
        </g>

        <!-- ── TITRE COIN SUP GAUCHE ── -->
        <rect x="16" y="16" width="200" height="44"
          rx="8" fill="#1a1a3e" stroke="#3b3b6e" stroke-width="1.5"/>
        <text x="116" y="36" text-anchor="middle"
          fill="#7c7cff" font-size="12" font-weight="800" letter-spacing="2">
          PRODUCTION
        </text>
        <text x="116" y="52" text-anchor="middle"
          fill="#4b4b8a" font-size="9" letter-spacing="3">
          LDM GROUPE
        </text>

        <!-- ── STEP LABELS ── -->
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

    <!-- ── TRS DETAIL PANEL ── -->
    <transition name="panel-slide">
      <div class="trs-detail-panel" v-if="trsMode && selectedNode && selectedNode.type === 'cond'" @click.stop>
        <div class="tdp-hd" :style="{borderLeftColor: selectedTrsPanel ? trsPanelColor(selectedTrsPanel) : '#4b5563'}">
          <div class="tdp-hd-info">
            <div class="tdp-equip">{{selectedNode.code}}</div>
            <div class="tdp-nom">{{selectedNode.nom}}</div>
          </div>
          <div class="tdp-right">
            <div class="tdp-status" :style="{background: (selectedTrsPanel ? trsPanelColor(selectedTrsPanel) : '#4b5563')+'22', color: selectedTrsPanel ? trsPanelColor(selectedTrsPanel) : '#4b5563'}">
              {{selectedTrsPanel && selectedTrsPanel.session ? selectedTrsPanel.session.statut : 'Disponible'}}
            </div>
            <div class="tdp-clock">{{trsClock}}</div>
            <button class="tdp-close" @click="selectedNode=null; selectedTrsPanel=null">✕</button>
          </div>
        </div>

        <!-- No panel / no session -->
        <div v-if="!selectedTrsPanel" class="tdp-empty">
          <div v-if="!selectedNode.equipement_id" class="tdp-empty-msg">
            Salle non liée à un équipement.<br>
            <span style="font-size:11px;color:#4b5563">Configurer dans Admin → Flux → Paramétrer les salles.</span>
          </div>
          <div v-else class="tdp-empty-msg">
            Équipement non trouvé dans le référentiel.<br>
            <span style="font-size:11px;color:#4b5563">Vérifier que l'équipement est actif dans le référentiel.</span>
          </div>
        </div>

        <template v-else>
          <!-- Shift & équipe -->
          <div class="tdp-chips" v-if="selectedTrsPanel.shiftNom || selectedTrsPanel.equipeNom">
            <span v-if="selectedTrsPanel.shiftNom" class="tdp-chip" :style="{background:selectedTrsPanel.shiftCouleur+'22',color:selectedTrsPanel.shiftCouleur,borderColor:selectedTrsPanel.shiftCouleur+'44'}">{{selectedTrsPanel.shiftNom}}</span>
            <span v-if="selectedTrsPanel.equipeNom" class="tdp-chip" :style="{background:selectedTrsPanel.equipeCouleur+'22',color:selectedTrsPanel.equipeCouleur}">{{selectedTrsPanel.equipeNom}}</span>
          </div>

          <!-- Lot -->
          <div class="tdp-lot" v-if="selectedTrsPanel.session">
            <div class="tdp-lot-num">Lot {{selectedTrsPanel.lotNum}}</div>
            <div class="tdp-lot-prod">{{selectedTrsPanel.lotProd}}</div>
          </div>
          <div class="tdp-no-session" v-else>Aucune session active</div>

          <!-- Timer -->
          <div class="tdp-timer" v-if="selectedTrsPanel.session">
            <div class="tdp-timer-lbl">
              {{selectedTrsPanel.session.statut === 'En cours' ? 'TEMPS PRODUCTION' : selectedTrsPanel.session.statut === 'Arrêt' ? 'ARRÊT EN COURS' : 'PAUSE'}}
            </div>
            <div class="tdp-timer-val" :style="{color: trsPanelColor(selectedTrsPanel)}">
              {{selectedTrsPanel.session.statut === 'En cours' ? trsTimers[selectedTrsPanel.equip.id] || '00:00:00' : (selectedTrsPanel.activeArret ? trsArretTimers[selectedTrsPanel.activeArret.id] || '00:00:00' : '—')}}
            </div>
            <div class="tdp-arret-info" v-if="selectedTrsPanel.activeArret">
              <span class="tdp-arret-chip" :style="{background:(selectedTrsPanel.activeArret.couleur||'#EF4444')+'22',color:selectedTrsPanel.activeArret.couleur||'#EF4444'}">
                {{selectedTrsPanel.activeArret.arret_code || '—'}}
              </span>
              <span class="tdp-arret-nom">{{selectedTrsPanel.activeArret.arret_nom || selectedTrsPanel.activeArret.famille_nom}}</span>
            </div>
          </div>

          <!-- Métriques -->
          <div class="tdp-metrics" v-if="selectedTrsPanel.session">
            <div class="tdp-metric">
              <div class="tdp-metric-val">{{selectedTrsPanel.session.colisage_confirme && selectedTrsPanel.session.colis_produits ? (selectedTrsPanel.session.colis_produits * selectedTrsPanel.session.colisage_confirme).toLocaleString('fr-FR') : (selectedTrsPanel.session.colis_produits || 0)}}</div>
              <div class="tdp-metric-lbl">{{selectedTrsPanel.session.colisage_confirme ? 'Boîtes prod.' : 'Colis prod.'}}</div>
            </div>
            <div class="tdp-metric">
              <div class="tdp-metric-val">{{selectedTrsPanel.session.objectif_boites || '—'}}</div>
              <div class="tdp-metric-lbl">Objectif</div>
            </div>
            <div class="tdp-metric">
              <div class="tdp-metric-val">{{selectedTrsPanel.session.cadence_reelle_boite_min != null ? selectedTrsPanel.session.cadence_reelle_boite_min : '—'}}</div>
              <div class="tdp-metric-lbl">b/min réel</div>
            </div>
            <div class="tdp-metric">
              <div class="tdp-metric-val">{{selectedTrsPanel.session.cadence_objectif_snapshot || selectedTrsPanel.equip.cadence_objectif_boite_min || '—'}}</div>
              <div class="tdp-metric-lbl">b/min obj.</div>
            </div>
          </div>

          <!-- Barre rendement -->
          <div class="tdp-rend" v-if="selectedTrsPanel.session && selectedTrsPanel.session.objectif_boites">
            <div class="tdp-rend-bar">
              <div class="tdp-rend-fill" :style="{width: Math.min(selectedTrsPanel.rendPct,100)+'%', background: selectedTrsPanel.rendPct>=100?'#1D9E75':selectedTrsPanel.rendPct>=80?'#F97316':'#EF4444'}"></div>
            </div>
            <div class="tdp-rend-pct" :style="{color: selectedTrsPanel.rendPct>=100?'#1D9E75':selectedTrsPanel.rendPct>=80?'#F97316':'#EF4444'}">{{selectedTrsPanel.rendPct}}%</div>
          </div>

          <!-- ── Comptage théorique vs réel ── -->
          <div class="tdp-comptage-bloc" v-if="selectedTrsPanel.session && trsTheoCounters[selectedTrsPanel.equip.id]">
            <div class="tdp-cad-line">
              <span class="tdp-cad-ic">⚙</span>
              <span class="tdp-cad-val">{{trsTheoCounters[selectedTrsPanel.equip.id]?.currentCadence || '—'}} b/min</span>
              <span v-if="trsTheoCounters[selectedTrsPanel.equip.id]?.isFallback" class="tdp-cad-fb"> (obj.)</span>
              <span v-if="selectedTrsPanel.session.colisage_confirme" class="tdp-cad-col"> · {{selectedTrsPanel.session.colisage_confirme}} btes/colis</span>
              <button class="tdp-cad-edit" @click="trsOpenCadence(selectedTrsPanel)" v-if="selectedTrsPanel.session.statut==='En cours'">✎</button>
            </div>
            <div class="tdp-cpt-table">
              <div class="tdp-cpt-row tdp-cpt-hd">
                <div class="tdp-cpt-cell"></div>
                <div class="tdp-cpt-cell tdp-cpt-th">THÉO</div>
                <div class="tdp-cpt-cell tdp-cpt-th">RÉEL</div>
              </div>
              <div class="tdp-cpt-row">
                <div class="tdp-cpt-cell tdp-cpt-lbl">Boîtes</div>
                <div class="tdp-cpt-cell tdp-cpt-theo">{{trsTheoCounters[selectedTrsPanel.equip.id]?.boites != null ? trsTheoCounters[selectedTrsPanel.equip.id].boites.toLocaleString('fr-FR') : '—'}}</div>
                <div class="tdp-cpt-cell tdp-cpt-reel">{{selectedTrsPanel.session.colis_produits && selectedTrsPanel.session.colisage_confirme ? (selectedTrsPanel.session.colis_produits * selectedTrsPanel.session.colisage_confirme).toLocaleString('fr-FR') : '—'}}</div>
              </div>
              <div class="tdp-cpt-row">
                <div class="tdp-cpt-cell tdp-cpt-lbl">Colis</div>
                <div class="tdp-cpt-cell tdp-cpt-theo">{{trsTheoCounters[selectedTrsPanel.equip.id]?.colis != null ? trsTheoCounters[selectedTrsPanel.equip.id].colis.toLocaleString('fr-FR') : '—'}}</div>
                <div class="tdp-cpt-cell tdp-cpt-reel">{{selectedTrsPanel.session.colis_produits || 0}}</div>
              </div>
            </div>
            <div class="tdp-reminder" v-if="trsTheoCounters[selectedTrsPanel.equip.id]?.needsComptage">
              ⚠ COMPTAGE EN ATTENTE — {{trsTheoCounters[selectedTrsPanel.equip.id]?.minsSinceCpt}} min
            </div>
          </div>

          <!-- OEE live -->
          <div class="tdp-oee" v-if="selectedTrsPanel.session">
            <div class="tdp-oee-item">
              <div class="tdp-oee-val" :class="trsOeeClass(nodeTrs(selectedNode)?.d)">{{nodeTrs(selectedNode)?.d != null ? nodeTrs(selectedNode).d+'%' : '—'}}</div>
              <div class="tdp-oee-lbl">Dispo</div>
            </div>
            <div class="tdp-oee-item">
              <div class="tdp-oee-val" :class="trsOeeClass(nodeTrs(selectedNode)?.p)">{{nodeTrs(selectedNode)?.p != null ? nodeTrs(selectedNode).p+'%' : '—'}}</div>
              <div class="tdp-oee-lbl">Perf.</div>
            </div>
            <div class="tdp-oee-item">
              <div class="tdp-oee-val" :class="trsOeeClass(nodeTrs(selectedNode)?.q)">{{nodeTrs(selectedNode)?.q != null ? nodeTrs(selectedNode).q+'%' : '—'}}</div>
              <div class="tdp-oee-lbl">Qual.</div>
            </div>
            <div class="tdp-oee-item">
              <div class="tdp-oee-val" :class="trsOeeClass(nodeTrs(selectedNode)?.trs)" style="font-size:20px;">{{nodeTrs(selectedNode)?.trs != null ? nodeTrs(selectedNode).trs+'%' : '—'}}</div>
              <div class="tdp-oee-lbl">TRS</div>
            </div>
          </div>

          <!-- Actions -->
          <div class="tdp-actions">
            <template v-if="!selectedTrsPanel.session">
              <button class="tdp-btn tdp-btn-start" @click="trsOpenStart(selectedTrsPanel.equip)">▶ Démarrer session</button>
            </template>
            <template v-else-if="selectedTrsPanel.session.statut === 'En cours'">
              <button class="tdp-btn tdp-btn-stop"  @click="trsOpenArret(selectedTrsPanel)">⏸ Arrêt</button>
              <button class="tdp-btn tdp-btn-count" @click="trsOpenComptage(selectedTrsPanel)">+ Comptage</button>
              <button class="tdp-btn tdp-btn-close" @click="trsOpenClose(selectedTrsPanel)">✓ Clôturer</button>
            </template>
            <template v-else-if="selectedTrsPanel.session.statut === 'Arrêt' || selectedTrsPanel.session.statut === 'Pause'">
              <button class="tdp-btn tdp-btn-resume"  @click="trsClotureArret(selectedTrsPanel)">▶ Reprendre</button>
              <button class="tdp-btn tdp-btn-requal"  @click="trsOpenRequalif(selectedTrsPanel)" v-if="selectedTrsPanel.activeArret">✎ Requalifier</button>
            </template>
          </div>

          <!-- Arrêts history -->
          <div class="tdp-arrets" v-if="selectedTrsPanel.session && selectedTrsPanel.arrets && selectedTrsPanel.arrets.length">
            <div class="tdp-arrets-title">Arrêts du shift</div>
            <div v-for="a in selectedTrsPanel.arrets" :key="a.id" class="tdp-arret-row" :class="{running: a.is_running}">
              <span class="tdp-arret-dot" :style="{background: a.couleur || (a.est_pause ? '#10B981' : '#EF4444')}"></span>
              <span class="tdp-arret-code">{{a.arret_code || '—'}}</span>
              <span class="tdp-arret-name">{{a.arret_nom || a.famille_nom || '—'}}</span>
              <span class="tdp-arret-dur">{{a.is_running ? '⏱ en cours' : (a.duree_minutes ? a.duree_minutes+'min' : '—')}}</span>
            </div>
          </div>
        </template>
      </div>
    </transition>

    <!-- ── PANEL DÉTAIL NŒUD ── -->
    <transition name="panel-slide">
      <div class="detail-panel" v-if="selectedNode && !(trsMode && selectedNode.type === 'cond')" @click.stop>
        <div class="dp-hd" :style="{borderLeftColor: zoneColor(selectedNode.zone)}">
          <div>
            <div class="dp-code">{{selectedNode.code}}</div>
            <div class="dp-nom">{{selectedNode.nom}}</div>
            <div class="dp-zone">{{zoneLabel(selectedNode.zone)}}</div>
          </div>
          <button class="dp-close" @click="selectedNode=null">✕</button>
        </div>

        <!-- Statut -->
        <div class="dp-status" :style="{background:nodeStatus(selectedNode).color+'22'}">
          <span class="dp-st-icon" :style="{color:nodeStatus(selectedNode).color}">
            {{nodeStatus(selectedNode).icon}}
          </span>
          <span class="dp-st-label">{{nodeStatus(selectedNode).label}}</span>
        </div>

        <!-- Lots en cours -->
        <div class="dp-section">
          <div class="dp-sec-title">Lots en cours</div>
          <div v-if="!getNodeLots(selectedNode).length" class="dp-empty">Aucun lot actif</div>
          <div v-for="lot in getNodeLots(selectedNode)" :key="lot.id" class="dp-lot-row"
            @click="modalLotPreselect=lot" style="cursor:pointer">
            <span class="dp-lot-num">{{lot.numero_lot}}</span>
            <span class="dp-lot-prod">{{lot.nom_produit||'—'}}</span>
            <span class="dp-lot-st" :class="'ls-'+lot.statut?.toLowerCase()">{{lot.statut}}</span>
          </div>
        </div>

        <!-- Actions opérationnelles -->
        <div class="dp-section">
          <div class="dp-sec-title">Actions</div>
          <div class="dp-actions-grid">
            <button class="dp-act-btn dp-act-start" @click="openStartModal">
              ▶ Démarrer
            </button>
            <button class="dp-act-btn dp-act-stop"
              :disabled="!getNodeLots(selectedNode).length"
              @click="openStopModal">
              ⏸ Arrêt
            </button>
            <button class="dp-act-btn dp-act-close"
              :disabled="!getNodeLots(selectedNode).length"
              @click="openCloseModal">
              ✓ Clôturer
            </button>
            <button class="dp-act-btn dp-act-dev"
              :disabled="!getNodeLots(selectedNode).length"
              @click="openDevModal">
              ⚠ Déviation
            </button>
          </div>
        </div>

        <!-- Flux produit si node dans flux sélectionné -->
        <div class="dp-section" v-if="selectedProduct && nodeIsFlux(selectedNode)">
          <div class="dp-sec-title" style="color:#fbbf24">Dans le flux</div>
          <div class="dp-flux-info">
            <span class="pct-badge" :class="'pct-'+selectedProduct.type_flux">
              {{selectedProduct.type_flux}}
            </span>
            {{selectedProduct.product_code}}
            <span class="dp-route-tag">Route {{activeRoute}}</span>
          </div>
        </div>
      </div>
    </transition>

    <!-- ── MODAL OVERLAY ── -->
    <div class="modal-overlay" v-if="modal.open" @click.self="closeModal">
      <div class="modal-box">
        <!-- MODAL : DÉMARRER SESSION -->
        <template v-if="modal.type==='start'">
          <div class="modal-hd">▶ Démarrer — <span class="mh-code">{{selectedNode?.code}}</span></div>
          <div class="modal-body">
            <div class="mf-row">
              <label>Lots <span class="mf-badge" v-if="modal.lots&&modal.lots.length">{{modal.lots.length}}</span></label>
              <div class="lot-search-wrap">
                <input class="mf-input" placeholder="Rechercher et ajouter un lot…" v-model="modal.lotSearch"
                  @input="searchModalLots"/>
                <div class="lot-dropdown" v-if="modal.lotDropdown.length">
                  <div v-for="l in modal.lotDropdown" :key="l.id" class="ld-item"
                    @click="selectModalLot(l)">
                    <b>{{l.numero_lot}}</b> — {{l.products?.description||'—'}}
                    <span v-if="modal.lots&&modal.lots.find(function(x){return x.id===l.id})" class="ld-check">✓</span>
                  </div>
                </div>
              </div>
              <div class="lot-multi-list" v-if="modal.lots&&modal.lots.length">
                <div v-for="l in modal.lots" :key="l.id" class="lot-chip-multi">
                  <span class="lcm-num">{{l.numero_lot}}</span>
                  <span class="lcm-desc">{{l.products?.description||'—'}}</span>
                  <button class="lcm-rm" @click="removeLot(l)" title="Retirer">×</button>
                </div>
              </div>
              <div class="mf-hint" v-else>Aucun lot sélectionné — rechercher ci-dessus</div>
            </div>
            <div class="mf-row">
              <label>Date/heure début</label>
              <input class="mf-input" type="datetime-local" v-model="modal.dateDebut"/>
            </div>
            <div class="mf-err" v-if="modal.err">{{modal.err}}</div>
          </div>
          <div class="modal-ft">
            <button class="mb-cancel" @click="closeModal">Annuler</button>
            <button class="mb-ok" @click="saveStart" :disabled="modal.saving||!(modal.lots&&modal.lots.length)">
              <template v-if="modal.saving">…</template>
              <template v-else-if="modal.lots&&modal.lots.length>1">▶ Démarrer ({{modal.lots.length}} lots)</template>
              <template v-else>▶ Démarrer</template>
            </button>
          </div>
        </template>

        <!-- MODAL : DÉCLARER ARRÊT -->
        <template v-if="modal.type==='stop'">
          <div class="modal-hd">⏸ Déclarer arrêt — <span class="mh-code">{{selectedNode?.code}}</span></div>
          <div class="modal-body">
            <div class="mf-row">
              <label>Lot concerné</label>
              <select class="mf-input" v-model="modal.fabId">
                <option value="">— Choisir —</option>
                <option v-for="lot in getNodeLots(selectedNode)" :key="lot.id"
                  :value="lot.fabId">{{lot.numero_lot}} — {{lot.nom_produit}}</option>
              </select>
            </div>
            <div class="mf-row">
              <label>Motif d'arrêt</label>
              <input class="mf-input" placeholder="Décrivez le motif…" v-model="modal.motif"/>
            </div>
            <div class="mf-row">
              <label>Heure début arrêt</label>
              <input class="mf-input" type="datetime-local" v-model="modal.dateDebut"/>
            </div>
            <div class="mf-err" v-if="modal.err">{{modal.err}}</div>
          </div>
          <div class="modal-ft">
            <button class="mb-cancel" @click="closeModal">Annuler</button>
            <button class="mb-ok mb-warn" @click="saveStop" :disabled="modal.saving">
              {{modal.saving?'…':'⏸ Confirmer arrêt'}}
            </button>
          </div>
        </template>

        <!-- MODAL : CLÔTURER -->
        <template v-if="modal.type==='close'">
          <div class="modal-hd">✓ Clôturer session — <span class="mh-code">{{selectedNode?.code}}</span></div>
          <div class="modal-body">
            <div class="mf-row">
              <label>Session à clôturer</label>
              <select class="mf-input" v-model="modal.fabId">
                <option value="">— Choisir —</option>
                <option v-for="lot in getNodeLots(selectedNode)" :key="lot.id"
                  :value="lot.fabId">{{lot.numero_lot}} — {{lot.nom_produit}}</option>
              </select>
            </div>
            <div class="mf-row">
              <label>Date/heure fin</label>
              <input class="mf-input" type="datetime-local" v-model="modal.dateFin"/>
            </div>
            <div class="mf-note">Cette action clôture définitivement la session.</div>
            <div class="mf-err" v-if="modal.err">{{modal.err}}</div>
          </div>
          <div class="modal-ft">
            <button class="mb-cancel" @click="closeModal">Annuler</button>
            <button class="mb-ok mb-green" @click="saveClose" :disabled="modal.saving">
              {{modal.saving?'…':'✓ Clôturer'}}
            </button>
          </div>
        </template>

        <!-- MODAL : DÉVIATION -->
        <template v-if="modal.type==='deviation'">
          <div class="modal-hd">⚠ Déclarer déviation — <span class="mh-code">{{selectedNode?.code}}</span></div>
          <div class="modal-body">
            <div class="mf-row">
              <label>Lot concerné</label>
              <select class="mf-input" v-model="modal.lotId">
                <option value="">— Choisir —</option>
                <option v-for="lot in getNodeLots(selectedNode)" :key="lot.id"
                  :value="lot.lotRawId">{{lot.numero_lot}} — {{lot.nom_produit}}</option>
              </select>
            </div>
            <div class="mf-row">
              <label>Description</label>
              <textarea class="mf-input mf-ta" rows="3" v-model="modal.description"
                placeholder="Décrivez la déviation observée…"/>
            </div>
            <div class="mf-err" v-if="modal.err">{{modal.err}}</div>
          </div>
          <div class="modal-ft">
            <button class="mb-cancel" @click="closeModal">Annuler</button>
            <button class="mb-ok mb-warn" @click="saveDev" :disabled="modal.saving">
              {{modal.saving?'…':'⚠ Déclarer'}}
            </button>
          </div>
        </template>
      </div>
    </div>

    <!-- ══ TRS MODAL : DÉMARRER SESSION ══ -->
    <div class="trs-overlay" v-if="trsStartModal.show" @click.self="trsStartModal.show=false">
      <div class="trs-modal">
        <div class="trs-modal-hd">▶ Démarrer — {{trsStartModal.equip?.nom_equipement}}</div>
        <label class="trs-lbl">N° Lot *</label>
        <div class="trs-auto-wrap">
          <input v-model="trsStartModal.lotSearch" class="trs-inp" placeholder="Rechercher numéro de lot…" @input="trsSearchLots" />
          <div class="trs-auto-list" v-if="trsStartModal.lotSuggestions.length">
            <div v-for="l in trsStartModal.lotSuggestions" :key="l.id" class="trs-auto-item" @mousedown.prevent="trsSelectLot(l)">
              <span class="trs-auto-code">{{l.numero_lot}}</span>
              <span class="trs-auto-desc">{{l.code_article}} — {{l.description}}</span>
            </div>
          </div>
        </div>
        <div class="trs-sel-lot" v-if="trsStartModal.lot">✓ Lot <strong>{{trsStartModal.lot.numero_lot}}</strong> — {{trsStartModal.lot.description}}</div>
        <div class="trs-form-row">
          <div class="trs-form-field">
            <label class="trs-lbl">Shift</label>
            <select v-model="trsStartModal.shift_id" class="trs-inp">
              <option :value="null">— Aucun —</option>
              <option v-for="s in trsShifts" :key="s.id" :value="s.id">{{s.nom}} ({{s.heure_debut.slice(0,5)}}→{{s.heure_fin.slice(0,5)}})</option>
            </select>
          </div>
          <div class="trs-form-field">
            <label class="trs-lbl">Équipe</label>
            <select v-model="trsStartModal.equipe_id" class="trs-inp">
              <option :value="null">— Aucune —</option>
              <option v-for="e in trsEquipes" :key="e.id" :value="e.id">{{e.nom}}</option>
            </select>
          </div>
        </div>
        <div class="trs-form-row">
          <div class="trs-form-field">
            <label class="trs-lbl">Date</label>
            <input type="date" v-model="trsStartModal.date" class="trs-inp" />
          </div>
          <div class="trs-form-field">
            <label class="trs-lbl">Heure début</label>
            <input type="time" v-model="trsStartModal.heure_debut" class="trs-inp" step="60" />
          </div>
        </div>
        <div class="trs-cad-preview" v-if="trsStartModal.equip">
          <div class="trs-cp-row"><span class="trs-cp-lbl">Cadence obj. (GS)</span><span class="trs-cp-val trs-cp-obj">{{trsStartModal.cadenceObj || '—'}} b/min</span></div>
          <div class="trs-cp-row" v-if="trsStartModal.cadenceObj"><span class="trs-cp-lbl">Objectif / shift</span><span class="trs-cp-val trs-cp-obj">{{trsComputeObjShift(trsStartModal)}} boîtes</span></div>
        </div>
        <!-- Cadence réelle opérateur + colisage -->
        <div class="trs-form-row trs-cad-real-row" v-if="trsStartModal.lot">
          <div class="trs-form-field">
            <label class="trs-lbl">Cadence réelle machine <span class="trs-lbl-unit">b/min</span></label>
            <input type="number" v-model.number="trsStartModal.cadenceReel" class="trs-inp" placeholder="ex: 60" min="1" step="0.5" />
          </div>
          <div class="trs-form-field">
            <label class="trs-lbl">Colisage <span class="trs-lbl-unit">btes/colis</span>
              <span v-if="trsStartModal.colisageSrc" class="trs-lbl-src">{{trsStartModal.colisageSrc==='catalogue'?'📦 catalogue':'📋 SAP'}}</span>
            </label>
            <input type="number" v-model.number="trsStartModal.colisage" class="trs-inp" placeholder="ex: 30" min="1" />
          </div>
        </div>
        <div class="trs-err" v-if="trsStartModal.error">{{trsStartModal.error}}</div>
        <div class="trs-modal-acts">
          <button class="trs-btn-save trs-btn-go" @click="trsDoStart" :disabled="trsStartModal.saving || !trsStartModal.lot">{{trsStartModal.saving ? 'Démarrage…' : '▶ Démarrer'}}</button>
          <button class="trs-btn-cancel" @click="trsStartModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ TRS MODAL : DÉCLARER ARRÊT ══ -->
    <div class="trs-overlay" v-if="trsArretModal.show" @click.self="trsArretModal.show=false">
      <div class="trs-modal">
        <div class="trs-modal-hd">⏸ Déclarer un arrêt — {{trsArretModal.panel?.equip.nom_equipement}}</div>
        <div class="trs-cascade">
          <div class="trs-cs-step">
            <label class="trs-lbl">Famille *</label>
            <select v-model="trsArretModal.famille_id" class="trs-inp" @change="trsOnFamilleChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="f in trsArretFamilles" :key="f.id" :value="f.id">{{f.nom}}</option>
            </select>
          </div>
          <div class="trs-cs-arrow">→</div>
          <div class="trs-cs-step">
            <label class="trs-lbl">Sous-famille *</label>
            <select v-model="trsArretModal.sf_id" class="trs-inp" :disabled="!trsArretModal.famille_id" @change="trsOnSFChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="sf in trsArretModal.sousFamilles" :key="sf.id" :value="sf.id">{{sf.nom}}</option>
            </select>
          </div>
          <div class="trs-cs-arrow">→</div>
          <div class="trs-cs-step">
            <label class="trs-lbl">Code arrêt *</label>
            <select v-model="trsArretModal.type_id" class="trs-inp" :disabled="!trsArretModal.sf_id" @change="trsOnTypeChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="t in trsArretModal.types" :key="t.id" :value="t.id">{{t.code}} — {{t.nom}}</option>
            </select>
          </div>
        </div>
        <div class="trs-type-preview" v-if="trsArretModal.selectedType">
          <span class="trs-code-chip" :style="{background:(trsArretModal.selectedType.couleur||trsArretModal.familleCouleur)+'22',color:trsArretModal.selectedType.couleur||trsArretModal.familleCouleur}">{{trsArretModal.selectedType.code}}</span>
          <span class="trs-prev-nom">{{trsArretModal.selectedType.nom}}</span>
          <span class="trs-tag trs-tag-plan" v-if="trsArretModal.selectedType.est_planifie">Planifié</span>
          <span class="trs-tag trs-tag-pause" v-if="trsArretModal.selectedType.est_pause">Pause</span>
        </div>
        <div class="trs-form-row">
          <div class="trs-form-field">
            <label class="trs-lbl">Heure début arrêt</label>
            <input type="time" v-model="trsArretModal.heure_debut" class="trs-inp" step="60" />
          </div>
        </div>
        <label class="trs-lbl">Commentaire</label>
        <input v-model="trsArretModal.commentaire" class="trs-inp" placeholder="Optionnel…" />
        <div class="trs-err" v-if="trsArretModal.error">{{trsArretModal.error}}</div>
        <div class="trs-modal-acts">
          <button class="trs-btn-save trs-btn-stop" @click="trsDoArret" :disabled="trsArretModal.saving || !trsArretModal.type_id">{{trsArretModal.saving ? 'Enregistrement…' : '⏸ Démarrer chrono arrêt'}}</button>
          <button class="trs-btn-cancel" @click="trsArretModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ TRS MODAL : REQUALIFIER ARRÊT ══ -->
    <div class="trs-overlay" v-if="trsRequalModal.show" @click.self="trsRequalModal.show=false">
      <div class="trs-modal trs-modal-sm">
        <div class="trs-modal-hd">✎ Requalifier l'arrêt en cours — {{trsRequalModal.panel?.equip.nom_equipement}}</div>
        <div style="display:flex;flex-direction:column;gap:8px;">
          <div><label class="trs-lbl">Famille</label>
            <select v-model="trsRequalModal.famille_id" class="trs-inp" @change="trsOnRequalFamilleChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="f in trsArretFamilles" :key="f.id" :value="f.id">{{f.nom}}</option>
            </select></div>
          <div><label class="trs-lbl">Sous-famille</label>
            <select v-model="trsRequalModal.sf_id" class="trs-inp" :disabled="!trsRequalModal.famille_id" @change="trsOnRequalSFChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="sf in trsRequalModal.sousFamilles" :key="sf.id" :value="sf.id">{{sf.nom}}</option>
            </select></div>
          <div><label class="trs-lbl">Code arrêt</label>
            <select v-model="trsRequalModal.type_id" class="trs-inp" :disabled="!trsRequalModal.sf_id">
              <option :value="null">— Sélectionner —</option>
              <option v-for="t in trsRequalModal.types" :key="t.id" :value="t.id">{{t.code}} — {{t.nom}}</option>
            </select></div>
        </div>
        <div class="trs-modal-acts">
          <button class="trs-btn-save" @click="trsDoRequalif" :disabled="trsRequalModal.saving || !trsRequalModal.type_id">{{trsRequalModal.saving ? '…' : 'Requalifier'}}</button>
          <button class="trs-btn-cancel" @click="trsRequalModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ TRS MODAL : MODIFIER CADENCE ══ -->
    <div class="trs-overlay" v-if="trsCadenceModal.show" @click.self="trsCadenceModal.show=false">
      <div class="trs-modal trs-modal-sm">
        <div class="trs-modal-hd">⚙ Modifier cadence — {{trsCadenceModal.panel?.equip.nom_equipement}}</div>
        <div class="trs-modal-ctx">Nouvelle valeur lue sur la machine</div>
        <div class="trs-form-row">
          <div class="trs-form-field" style="flex:1">
            <label class="trs-lbl">Cadence réelle * <span class="trs-lbl-unit">b/min</span></label>
            <input type="number" v-model.number="trsCadenceModal.cadence" class="trs-inp" placeholder="ex: 60" min="1" step="0.5" autofocus />
          </div>
        </div>
        <div class="trs-modal-acts">
          <button class="trs-btn-save" @click="trsDoChangeCadence" :disabled="trsCadenceModal.saving || !trsCadenceModal.cadence">{{trsCadenceModal.saving ? '…' : 'Enregistrer'}}</button>
          <button class="trs-btn-cancel" @click="trsCadenceModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ TRS MODAL : HISTORIQUE ══ -->
    <div class="trs-overlay trs-histo-overlay" v-if="trsHistoModal.show" @click.self="trsHistoModal.show=false">
      <div class="trs-modal trs-modal-lg">
        <div class="trs-modal-hd">📅 Historique des sessions TRS</div>

        <!-- Filtres -->
        <div class="trs-histo-filters">
          <div class="trs-form-field">
            <label class="trs-lbl">Date</label>
            <input type="date" v-model="trsHistoModal.date" class="trs-inp" @change="loadTrsHistoData" />
          </div>
          <div class="trs-form-field">
            <label class="trs-lbl">Machine</label>
            <select v-model="trsHistoModal.equip_id" class="trs-inp" @change="loadTrsHistoData">
              <option :value="null">Toutes</option>
              <option v-for="e in trsEquipes_list" :key="e.id" :value="e.id">{{e.nom_equipement}}</option>
            </select>
          </div>
          <button class="trs-btn-save" style="align-self:flex-end" @click="loadTrsHistoData" :disabled="trsHistoModal.loading">
            {{trsHistoModal.loading ? '…' : '🔍 Chercher'}}
          </button>
        </div>

        <!-- Tableau -->
        <div v-if="trsHistoModal.loading" style="text-align:center;padding:24px;color:#6b7280">Chargement…</div>
        <div v-else-if="!trsHistoModal.sessions.length" style="text-align:center;padding:24px;color:#6b7280">Aucune session trouvée.</div>
        <div v-else class="trs-histo-wrap">
          <table class="trs-histo-table">
            <thead>
              <tr>
                <th>Machine</th>
                <th>Lot</th>
                <th>Shift</th>
                <th>Début</th>
                <th>Fin</th>
                <th>Boîtes</th>
                <th>D%</th>
                <th>P%</th>
                <th>Q%</th>
                <th class="trs-h-trs">TRS%</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in trsHistoModal.sessions" :key="s.id">
                <td>{{s._equipNom || '—'}}</td>
                <td class="mono">{{s._lotNum || '—'}}</td>
                <td>{{s._shiftNom || '—'}}</td>
                <td class="mono">{{s.heure_debut ? s.heure_debut.slice(0,5) : '—'}}</td>
                <td class="mono">{{s.heure_fin ? s.heure_fin.slice(0,5) : '—'}}</td>
                <td class="mono">{{s.colis_produits && s._colisage ? (s.colis_produits * s._colisage).toLocaleString('fr-FR') : (s.colis_produits || '—')}}</td>
                <td :style="{color: s.disponibilite!=null ? trsColor(s.disponibilite) : '#4b5563'}">{{s.disponibilite != null ? s.disponibilite+'%' : '—'}}</td>
                <td :style="{color: s.performance!=null ? trsColor(s.performance) : '#4b5563'}">{{s.performance != null ? s.performance+'%' : '—'}}</td>
                <td :style="{color: s.qualite!=null ? trsColor(s.qualite) : '#4b5563'}">{{s.qualite != null ? s.qualite+'%' : '—'}}</td>
                <td class="trs-h-trs" :style="{color: s.trs!=null ? trsColor(s.trs) : '#4b5563', fontWeight:'800'}">{{s.trs != null ? s.trs+'%' : s.statut==='En cours' ? '⏱' : '—'}}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="trs-modal-acts" style="margin-top:12px">
          <button class="trs-btn-cancel" @click="trsHistoModal.show=false">Fermer</button>
        </div>
      </div>
    </div>

    <!-- ══ TRS MODAL : COMPTAGE ══ -->
    <div class="trs-overlay" v-if="trsComptageModal.show" @click.self="trsComptageModal.show=false">
      <div class="trs-modal trs-modal-sm">
        <div class="trs-modal-hd">+ Saisie comptage — {{trsComptageModal.panel?.equip.nom_equipement}}</div>
        <div class="trs-modal-ctx" v-if="trsComptageModal.panel?.session">Session en cours · Boîtes déclarées : <strong>{{trsComptageModal.panel.session.colis_produits && trsComptageModal.panel.session.colisage_confirme ? trsComptageModal.panel.session.colis_produits * trsComptageModal.panel.session.colisage_confirme : (trsComptageModal.panel.session.colis_produits || 0)}}</strong></div>
        <div class="trs-form-row">
          <div class="trs-form-field"><label class="trs-lbl">Heure relevé</label><input type="time" v-model="trsComptageModal.heure" class="trs-inp" step="60" /></div>
          <div class="trs-form-field"><label class="trs-lbl">Boîtes cumulées * <span class="trs-lbl-unit">btes</span></label><input type="number" v-model.number="trsComptageModal.boites" class="trs-inp" placeholder="ex: 37500" min="0" /></div>
        </div>
        <div class="trs-form-row">
          <div class="trs-form-field"><label class="trs-lbl">Rebuts cumulés</label><input type="number" v-model.number="trsComptageModal.rebuts" class="trs-inp" placeholder="0" min="0" /></div>
        </div>
        <div class="trs-cad-calc" v-if="trsComptageModal.panel?.session && trsComptageModal.boites">
          <div class="trs-cc-row"><span class="trs-cp-lbl">Cadence calculée</span><span class="trs-cp-val">{{trsComputeCadence(trsComptageModal)}} b/min</span></div>
          <div class="trs-cc-row"><span class="trs-cp-lbl">vs objectif</span><span class="trs-cp-val" :class="trsComputeCadenceVsObj(trsComptageModal) >= 100 ? 'trs-ok' : 'trs-bad'">{{trsComputeCadenceVsObj(trsComptageModal)}}%</span></div>
        </div>
        <div class="trs-modal-acts">
          <button class="trs-btn-save" @click="trsDoComptage" :disabled="trsComptageModal.saving || !trsComptageModal.boites">{{trsComptageModal.saving ? '…' : 'Enregistrer'}}</button>
          <button class="trs-btn-cancel" @click="trsComptageModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ TRS MODAL : CLÔTURER SESSION ══ -->
    <div class="trs-overlay" v-if="trsCloseModal.show" @click.self="trsCloseModal.show=false">
      <div class="trs-modal">
        <div class="trs-modal-hd">✓ Clôturer la session — {{trsCloseModal.panel?.equip.nom_equipement}}</div>
        <div class="trs-modal-ctx" v-if="trsCloseModal.panel?.session">Lot {{trsCloseModal.panel.lotNum}} · Démarré à {{trsCloseModal.panel.session.heure_debut}}</div>
        <div class="trs-form-row">
          <div class="trs-form-field"><label class="trs-lbl">Heure fin *</label><input type="time" v-model="trsCloseModal.heure_fin" class="trs-inp" step="60" /></div>
          <div class="trs-form-field"><label class="trs-lbl">Boîtes produites * <span class="trs-lbl-unit">btes</span></label><input type="number" v-model.number="trsCloseModal.colis_produits" class="trs-inp" min="0" /></div>
        </div>
        <div class="trs-form-row">
          <div class="trs-form-field"><label class="trs-lbl">Boîtes rebuts <span class="trs-lbl-unit">btes</span></label><input type="number" v-model.number="trsCloseModal.colis_rebuts" class="trs-inp" min="0" /></div>
        </div>
        <label class="trs-lbl">Observation</label>
        <input v-model="trsCloseModal.observation" class="trs-inp" placeholder="Optionnel…" />
        <div class="trs-oee-preview" v-if="trsCloseModal.panel && trsCloseModal.heure_fin && trsCloseModal.colis_produits">
          <div class="trs-op-title">OEE estimé à la clôture</div>
          <div class="trs-op-grid">
            <div class="trs-op-item" v-for="item in trsComputeOEEPreview(trsCloseModal)" :key="item.label">
              <div class="trs-op-val" :class="trsOeeClass(item.val)">{{item.val != null ? item.val+'%' : '—'}}</div>
              <div class="trs-op-lbl">{{item.label}}</div>
            </div>
          </div>
        </div>
        <div class="trs-err" v-if="trsCloseModal.error">{{trsCloseModal.error}}</div>
        <div class="trs-modal-acts">
          <button class="trs-btn-save trs-btn-cloture" @click="trsDoClose" :disabled="trsCloseModal.saving || !trsCloseModal.heure_fin">{{trsCloseModal.saving ? 'Clôture…' : '✓ Clôturer et calculer OEE'}}</button>
          <button class="trs-btn-cancel" @click="trsCloseModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

  </div>
</template>

<script>
import { ref, reactive, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import { useTheme } from '../../composables/useTheme'
import { getAll as gsGetAll } from '../../services/googleSheets'
import { declareDeviation } from '../../services/actions'

// ── LAYOUT CONSTANTS ──────────────────────────────────────────────
var SVG_W  = 1580
var SVG_H  = 980
var NW     = 148
var NH     = 62
var HGAP   = 30
var STEP   = NW + HGAP  // 178

// Pesée
var PESEE_X = 30
var PESEE_Y = 30
var PESEE_W = NW + 20
var PESEE_H = 460

// Production tracks
var TRACK_X   = PESEE_X + PESEE_W + 20   // ~220
var TRACKS_W  = 820
var ZONE_FS_Y = 30
var ZONE_FS_H = 580
var ZONE_SS_Y = 630
var ZONE_SS_H = 160

// OTC zone (sous semi-solides)
var ZONE_OTC_Y = 848
var ZONE_OTC_H = 110
var T_OTC_Y    = 900

// Conditionnement primaire column — décalé à droite pour laisser place au stock SF
var COND_X = TRACK_X + TRACKS_W + 110    // ~1150
var COND_Y = 30
var COND_W = 210
var COND_H = 640

// Track Y positions
var T1Y = 100    // Gran01→Mél01→Comp01→Pellic01
var T2Y = 220    // Mél02→Comp03→Pellic03
var T2bY = 330   // Comp02 seul
var T3Y = 430    // Gran02→Mél03→Comp04→Pellic02
var T4Y = 545    // Formulation→Gélules
var T5Y = 700    // Semi-solides
var COND_PRIM_Y = 100   // première ligne cond prim

// ── NODE BUILDER ─────────────────────────────────────────────────
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
  // ── PESÉE
  buildNode('p464', '464', 'Pesée 1',  'pesee', 'pesee', 0, T1Y,  PESEE_X+10),
  buildNode('p471', '471', 'Pesée 2',  'pesee', 'pesee', 0, T3Y,  PESEE_X+10),

  // ── ZONE 100 — Track 1 : Gran01→Mél01→Comp01→Pellic01
  buildNode('n140', '140', 'Gran. Séchage 01',  'formes_seches', 'fab', 0, T1Y),
  buildNode('n138', '138', 'Mélange 01',         'formes_seches', 'fab', 1, T1Y),
  buildNode('n131', '131', 'Compression 01',     'formes_seches', 'fab', 2, T1Y),
  buildNode('n143', '143', 'Pelliculage 01',     'formes_seches', 'fab', 3, T1Y),

  // ── ZONE 100 — Track 2 : Mél02→Comp03→Pellic03
  buildNode('n137', '137', 'Mélange 02',         'formes_seches', 'fab', 1, T2Y),
  buildNode('n134', '134', 'Compression 03',     'formes_seches', 'fab', 2, T2Y),
  buildNode('n136', '136', 'Pelliculage 03',     'formes_seches', 'fab', 3, T2Y),

  // ── ZONE 100 — Track 2b : Compression 02 (compression directe)
  buildNode('n128', '128', 'Compression 02',     'formes_seches', 'fab', 2, T2bY),

  // ── ZONE 400 — Track 3 : Gran02→Mél03→Comp04→Pellic02
  buildNode('n425', '425', 'Gran. Séchage 02',  'formes_seches', 'fab', 0, T3Y),
  buildNode('n448', '448', 'Mélange 03',         'formes_seches', 'fab', 1, T3Y),
  buildNode('n445', '445', 'Compression 04',     'formes_seches', 'fab', 2, T3Y),
  buildNode('n429', '429', 'Pelliculage 02',     'formes_seches', 'fab', 3, T3Y),

  // ── ZONE 400 — Track 4 : Formulation→Gélules
  buildNode('n442', '442', 'Formulation',        'formes_seches', 'fab', 0, T4Y),
  buildNode('n436', '436', 'Remplissage Gélules','formes_seches', 'fab', 1, T4Y),

  // ── FORMES SEMI-SOLIDES / OTC
  buildNode('n200', '200', 'Mélange Homogén.',   'formes_semi', 'fab', 0, T5Y),
  buildNode('n206', '206', 'Remplissage Tubes',  'formes_semi', 'fab', 1, T5Y),

  // ── CONDITIONNEMENT PRIMAIRE — 7 lignes
  buildNode('c149', '149', 'MB421',          'cond_primaire', 'cond', 0, COND_PRIM_Y + 0*70,  COND_X+31),
  buildNode('c148', '148', 'IMA TR100L',     'cond_primaire', 'cond', 0, COND_PRIM_Y + 1*70,  COND_X+31),
  buildNode('c147', '147', 'INTEGRA 300',    'cond_primaire', 'cond', 0, COND_PRIM_Y + 2*70,  COND_X+31),
  buildNode('c146', '146', 'IMA PG SUPER 1', 'cond_primaire', 'cond', 0, COND_PRIM_Y + 3*70,  COND_X+31),
  buildNode('c220', '220', 'MARCH. R,P',     'cond_primaire', 'cond', 0, COND_PRIM_Y + 4*70,  COND_X+31),
  buildNode('c222', '222', 'INTEGRA 520',    'cond_primaire', 'cond', 0, COND_PRIM_Y + 5*70,  COND_X+31),
  buildNode('c223', '223', 'IMA PG SUPER 2', 'cond_primaire', 'cond', 0, COND_PRIM_Y + 6*70,  COND_X+31),

  // ── STOCK INTERMÉDIAIRE SF (tampon entre FAB et COND)
  buildNode('n416', '416', 'Stock Inter. SF',    'stockage_sf', 'fab', 0, 400, 940),

  // ── SAS LIVRAISON PF (après COND primaire)
  buildNode('n155', '155', 'SAS Livraison PF',   'stockage_pf', 'fab', 0, 310, COND_X + COND_W + 30),

  // ── OTC — 5 lignes de mélange / remplissage
  buildNode('n101', '101', 'Ligne OTC 01', 'otc', 'fab', 0, T_OTC_Y),
  buildNode('n102', '102', 'Ligne OTC 02', 'otc', 'fab', 1, T_OTC_Y),
  buildNode('n103', '103', 'Ligne OTC 03', 'otc', 'fab', 2, T_OTC_Y),
  buildNode('n104', '104', 'Ligne OTC 04', 'otc', 'fab', 3, T_OTC_Y),
  buildNode('n105', '105', 'Ligne OTC 05', 'otc', 'fab', 4, T_OTC_Y),
]

// ── ARROWS ───────────────────────────────────────────────────────
var ARROWS_DEF = [
  // Pesée → Gran/direct
  { id: 'a1',  from: 'p464', to: 'n140' },
  { id: 'a2',  from: 'p471', to: 'n425' },
  // Track 1
  { id: 'a3',  from: 'n140', to: 'n138' },
  { id: 'a4',  from: 'n138', to: 'n131' },
  { id: 'a5',  from: 'n131', to: 'n143' },
  // Track 2
  { id: 'a6',  from: 'n137', to: 'n134' },
  { id: 'a7',  from: 'n134', to: 'n136' },
  // Comp02 (direct compression)
  { id: 'a8',  from: 'n138', to: 'n128' },
  // Track 3
  { id: 'a9',  from: 'n425', to: 'n448' },
  { id: 'a10', from: 'n448', to: 'n445' },
  { id: 'a11', from: 'n445', to: 'n429' },
  // Track 4
  { id: 'a12', from: 'n442', to: 'n436' },
  // Semi-solides
  { id: 'a13', from: 'n200', to: 'n206' },
  // Fab → Cond Prim (generic connections)
  { id: 'a14', from: 'n143', to: 'c149' },
  { id: 'a15', from: 'n136', to: 'c147' },
  { id: 'a16', from: 'n429', to: 'c146' },
  { id: 'a17', from: 'n436', to: 'c148' },
  { id: 'a18', from: 'n206', to: 'c220' },
  { id: 'a19', from: 'n131', to: 'c222' },
  { id: 'a20', from: 'n445', to: 'c223' },
  { id: 'a21', from: 'n128', to: 'c147' },
  // Cond Prim → SAS Livraison PF
  { id: 'a22', from: 'c149', to: 'n155' },
  { id: 'a23', from: 'c223', to: 'n155' },
]

// ── STEP LABELS ───────────────────────────────────────────────────
var STEP_LABELS = [
  { id: 'sl1', label: 'PESÉE',          x: PESEE_X + PESEE_W/2,              y1: 30,  y2: 500, tw: 60 },
  { id: 'sl2', label: 'GRANULATION',    x: TRACK_X + 0*STEP + NW/2 + 10,    y1: 30,  y2: 590, tw: 90 },
  { id: 'sl3', label: 'MÉLANGE',        x: TRACK_X + 1*STEP + NW/2 + 10,    y1: 30,  y2: 590, tw: 72 },
  { id: 'sl4', label: 'COMPRESSION',    x: TRACK_X + 2*STEP + NW/2 + 10,    y1: 30,  y2: 590, tw: 90 },
  { id: 'sl5', label: 'PELLICULAGE',    x: TRACK_X + 3*STEP + NW/2 + 10,    y1: 30,  y2: 590, tw: 84 },
  { id: 'sl6', label: 'COND. PRIM.',    x: COND_X + COND_W/2,               y1: 30,  y2: 648, tw: 90 },
]

export default {
  directives: {
    'click-outside': {
      mounted(el, binding) {
        el._clickOutside = function(e) { if (!el.contains(e.target)) binding.value(e) }
        document.addEventListener('click', el._clickOutside)
      },
      unmounted(el) { document.removeEventListener('click', el._clickOutside) }
    }
  },

  setup() {
    var router = useRouter()
    var { theme } = useTheme()

    var loading       = ref(false)
    var selectedNode  = ref(null)
    var suiviFab      = ref([])
    var sessions      = ref([])
    var deviations    = ref([])
    var arrets        = ref([])
    var rooms         = ref([])

    // ── TRS MODE ──────────────────────────────────────────────────
    var trsMode          = ref(false)
    var trsLoading       = ref(false)
    var trsSessionsFull  = ref([])   // production_sessions du jour avec champs OEE
    var trsArretsFull    = ref([])   // production_arrets (tous) pour calcul live

    var trsColor = function(val) {
      if (val == null) return '#4b5563'
      if (val >= 85) return '#10b981'
      if (val >= 60) return '#f59e0b'
      return '#ef4444'
    }

    var calcLiveTrs = function(sess, sessArrets) {
      if (!sess.heure_debut || !sess.date) return { d: null, p: null, q: null, trs: null, statut: sess.statut }
      var start = new Date(sess.date + 'T' + sess.heure_debut)
      var now   = new Date()
      var totalMin = (now - start) / 60000
      if (totalMin <= 0) return { d: null, p: null, q: null, trs: null, statut: sess.statut }
      var arretImpro = (sessArrets || []).reduce(function(acc, a) {
        return acc + (!a.est_planifie && !a.est_pause ? (a.duree_minutes || 0) : 0)
      }, 0)
      var pauses = (sessArrets || []).reduce(function(acc, a) {
        return acc + (a.est_pause ? (a.duree_minutes || 0) : 0)
      }, 0)
      var to = totalMin - pauses
      var tf = Math.max(0, to - arretImpro)
      var colisTotal = sess.colis_produits || 0
      var colisBon   = Math.max(0, colisTotal - (sess.colis_rebuts || 0))
      var cadNom     = sess.cadence_nominale_snapshot || 0
      var d   = to > 0 ? Math.min(100, Math.round((tf / to) * 100)) : null
      var p   = tf > 0 && cadNom > 0 ? Math.min(100, Math.round((colisTotal / (cadNom * tf)) * 100)) : null
      var q   = colisTotal > 0 ? Math.min(100, Math.round((colisBon / colisTotal) * 100)) : null
      var trs = (d != null && p != null && q != null) ? Math.round((d * p * q) / 10000) : null
      return { d, p, q, trs, statut: sess.statut }
    }

    var trsDataByEquipId = computed(function() {
      var map = {}
      trsSessionsFull.value.forEach(function(sess) {
        if (!sess.equipement_id) return
        var sessArrets = trsArretsFull.value.filter(function(a) { return a.session_id === sess.id })
        var result
        if (sess.statut === 'Clôturé' && sess.trs != null) {
          result = { d: sess.disponibilite, p: sess.performance, q: sess.qualite, trs: sess.trs, statut: sess.statut }
        } else {
          result = calcLiveTrs(sess, sessArrets)
        }
        if (result) map[sess.equipement_id] = result
      })
      return map
    })

    var nodeTrs = function(node) {
      if (!trsMode.value) return null
      if (node.type === 'cond' && node.equipement_id) {
        return trsDataByEquipId.value[node.equipement_id] || null
      }
      return null
    }

    var trsSummary = computed(function() {
      var entries = Object.values(trsDataByEquipId.value)
      var withTrs = entries.filter(function(t) { return t.trs != null })
      var sumTrs  = withTrs.reduce(function(a, t) { return a + t.trs }, 0)
      var arretsCount = entries.filter(function(t) { return t.statut === 'Arrêt' }).length
      var trsVals = withTrs.map(function(t) { return t.trs })
      return {
        active:   entries.length,
        total:    allNodes.value.filter(function(n) { return n.type === 'cond' }).length,
        avgTrs:   withTrs.length > 0 ? Math.round(sumTrs / withTrs.length) : null,
        bestTrs:  trsVals.length ? Math.max.apply(null, trsVals) : null,
        worstTrs: trsVals.length ? Math.min.apply(null, trsVals) : null,
        arretsCount
      }
    })

    var loadTrsData = async function() {
      trsLoading.value = true
      var today = new Date().toISOString().slice(0, 10)
      var [rS, rA] = await Promise.all([
        supabase.from('production_sessions')
          .select('id,equipement_id,statut,date,heure_debut,heure_fin,disponibilite,performance,qualite,trs,colis_produits,colis_rebuts,objectif_boites,cadence_nominale_snapshot')
          .eq('date', today)
          .neq('statut', 'Annulé'),
        supabase.from('production_arrets')
          .select('id,session_id,duree_minutes,est_planifie,est_pause,is_running')
      ])
      if (!rS.error) trsSessionsFull.value = rS.data || []
      if (!rA.error) trsArretsFull.value   = rA.data || []
      trsLoading.value = false
    }

    var toggleTrsMode = async function() {
      trsMode.value = !trsMode.value
      if (trsMode.value) {
        await loadTrsFull()
        trsClockInt   = setInterval(trsTick, 1000)
        trsRefreshInt = setInterval(loadTrsFull, 60000)
        trsTick()
      } else {
        clearInterval(trsClockInt)
        clearInterval(trsRefreshInt)
        trsClockInt = null; trsRefreshInt = null
        selectedTrsPanel.value = null
      }
    }

    // ── TRS LIVE STATE ─────────────────────────────────────────────
    var trsPanels        = ref([])
    var trsShifts        = ref([])
    var trsEquipes       = ref([])
    var trsArretFamilles = ref([])
    var trsCadences      = ref([])   // GS onglet 2 — cadences par (N°_atelier × code_article)
    var trsClock         = ref('')
    var trsTimers        = ref({})
    var trsArretTimers   = ref({})
    var selectedTrsPanel = ref(null)
    var trsClockInt      = null
    var trsRefreshInt    = null
    var trsLotTimeout    = null

    var trsStartModal    = reactive({ show:false, equip:null, lotSearch:'', lotSuggestions:[], lot:null, shift_id:null, equipe_id:null, date:'', heure_debut:'', cadenceObj:null, cadenceReel:null, colisage:null, colisageSrc:'', error:'', saving:false })
    var trsArretModal    = reactive({ show:false, panel:null, famille_id:null, sf_id:null, type_id:null, sousFamilles:[], types:[], selectedType:null, familleCouleur:'#EF4444', heure_debut:'', commentaire:'', error:'', saving:false })
    var trsRequalModal   = reactive({ show:false, panel:null, famille_id:null, sf_id:null, type_id:null, sousFamilles:[], types:[], saving:false })
    var trsComptageModal = reactive({ show:false, panel:null, heure:'', boites:null, rebuts:0, saving:false })
    var trsCloseModal    = reactive({ show:false, panel:null, heure_fin:'', colis_produits:null, colis_rebuts:0, observation:'', error:'', saving:false })
    var trsCadenceModal  = reactive({ show:false, panel:null, cadence:null, saving:false })
    var trsHistoModal    = reactive({ show:false, loading:false, date:'', equip_id:null, sessions:[] })
    var trsEquipes_list  = ref([])
    var trsTheoCounters  = ref({})

    // ── Helpers GS temps (miroir de TrsLivePage) ───────────────────
    var trsTotalPlanRef = function(eq) {
      if (!eq) return 0
      return (eq.pause_ref||0)+(eq.vdlp_ref||0)+(eq.vdlc_ref||0)+
             (eq.chgt_format_ref||0)+(eq.reglage_ref||0)+(eq.micro_arrets_ref||0)+(eq.maint_curative_ref||0)
    }
    var trsNetRef = function(eq) {
      if (!eq) return 480
      return Math.max(1, (eq.to_shift_ref||480) - trsTotalPlanRef(eq))
    }

    var trsNowTime = function() {
      var n = new Date()
      return String(n.getHours()).padStart(2,'0') + ':' + String(n.getMinutes()).padStart(2,'0')
    }

    var trsToDateTime = function(dateStr, timeStr) {
      if (!dateStr || !timeStr) return null
      return new Date(dateStr + 'T' + timeStr)
    }

    var trsFormatElapsed = function(ms) {
      if (ms < 0) ms = 0
      var s = Math.floor(ms / 1000)
      var h = Math.floor(s / 3600)
      var m = Math.floor((s % 3600) / 60)
      var sec = s % 60
      return String(h).padStart(2,'0') + ':' + String(m).padStart(2,'0') + ':' + String(sec).padStart(2,'0')
    }

    var trsPanelColor = function(p) {
      if (!p.session) return '#9CA3AF'
      if (p.session.statut === 'En cours') return '#1D9E75'
      if (p.session.statut === 'Arrêt') return '#EF4444'
      if (p.session.statut === 'Pause') return '#F97316'
      return '#9CA3AF'
    }

    var trsOeeClass = function(v) {
      if (v == null) return ''
      if (v >= 85) return 'oee-green'
      if (v >= 60) return 'oee-orange'
      return 'oee-red'
    }

    var trsComputeObjShift = function(m) {
      var cadObj = m.cadenceObj
      if (!cadObj || !m.equip) return '—'
      return Math.round(cadObj * trsNetRef(m.equip))
    }

    var trsComputeCadence = function(m) {
      var s = m.panel && m.panel.session
      if (!s || !m.boites || !s.heure_debut || !s.date) return '—'
      var start = trsToDateTime(s.date, s.heure_debut)
      if (!start) return '—'
      var minElapsed = (new Date() - start) / 60000
      if (minElapsed <= 0) return '—'
      return (m.boites / minElapsed).toFixed(1)
    }

    var trsComputeCadenceVsObj = function(m) {
      var cadR = parseFloat(trsComputeCadence(m))
      var cadO = m.panel && m.panel.session && m.panel.session.cadence_objectif_snapshot
      if (!cadR || !cadO) return '—'
      return Math.round((cadR / cadO) * 100)
    }

    var trsComputeOEEPreview = function(m) {
      var s = m.panel && m.panel.session
      if (!s) return []
      var eq = m.panel.equip
      var arretImpro = (m.panel.arrets||[]).reduce(function(acc,a){ return !a.est_planifie && !a.est_pause ? acc+(a.duree_minutes||0) : acc }, 0)
      // TO net de référence : snapshot ou fallback GS
      var toNetRef   = s.temps_ouverture_min || trsNetRef(eq)
      var tf         = Math.max(0, toNetRef - arretImpro)
      var total      = m.colis_produits||0
      var colisGood  = total - (m.colis_rebuts||0)
      var cadObj     = s.cadence_objectif_snapshot
      var D   = toNetRef>0 ? Math.round((tf/toNetRef)*100) : null
      var P   = (tf>0 && cadObj>0) ? Math.min(150, Math.round((total/(cadObj*tf))*100)) : null
      var Q   = total>0 ? Math.round((colisGood/total)*100) : null
      var TRS = (D!=null && P!=null && Q!=null) ? Math.round((D/100)*(P/100)*(Q/100)*100) : null
      return [{ label:'Disponibilité', val:D }, { label:'Performance', val:P }, { label:'Qualité', val:Q }, { label:'TRS', val:TRS }]
    }

    var trsTick = function() {
      var n = new Date()
      var p2 = function(v){ return String(v).padStart(2,'0') }
      trsClock.value = p2(n.getHours())+':'+p2(n.getMinutes())+':'+p2(n.getSeconds())
      var newT = {}, newAT = {}, newTheo = {}
      for (var i = 0; i < trsPanels.value.length; i++) {
        var p = trsPanels.value[i]
        if (p.session && p.session.statut === 'En cours') {
          var start = trsToDateTime(p.session.date, p.session.heure_debut)
          if (start) newT[p.equip.id] = trsFormatElapsed(n - start)
          // ── Compteur théorique (cadence × temps_net segmenté) ──
          var cads = p.cadences || []
          var isFallbackCad = false
          if (cads.length === 0) {
            var fallCad = p.session.cadence_objectif_snapshot || (p.equip && p.equip.cadence_objectif_boite_min)
            var fallStart = trsToDateTime(p.session.date, p.session.heure_debut)
            if (fallCad && fallStart) {
              cads = [{ cadence_bpm: fallCad, started_at: fallStart.toISOString() }]
              isFallbackCad = true
            }
          }
          if (cads.length > 0) {
            var colisage  = p.session.colisage_confirme || null
            var arrets    = p.arrets || []
            var boitesTheo = 0
            for (var ci = 0; ci < cads.length; ci++) {
              var cad      = cads[ci]
              var segStart = new Date(cad.started_at)
              var segEnd   = (ci < cads.length - 1) ? new Date(cads[ci + 1].started_at) : n
              if (segStart >= segEnd) continue
              var netMs = segEnd.getTime() - segStart.getTime()
              // Soustraire les chevauchements d'arrêts dans ce segment
              for (var ai = 0; ai < arrets.length; ai++) {
                var arr     = arrets[ai]
                var aS      = trsToDateTime(p.session.date, arr.heure_debut)
                if (!aS) continue
                var aE      = arr.is_running ? n : (arr.duree_minutes ? new Date(aS.getTime() + arr.duree_minutes * 60000) : null)
                if (!aE) continue
                var overlapS = Math.max(segStart.getTime(), aS.getTime())
                var overlapE = Math.min(segEnd.getTime(), aE.getTime())
                if (overlapE > overlapS) netMs -= (overlapE - overlapS)
              }
              boitesTheo += cad.cadence_bpm * Math.max(0, netMs / 60000)
            }
            var colisTheo = (colisage && colisage > 0) ? Math.floor(boitesTheo / colisage) : null
            // ── Rappel 30 min (pause si arrêt actif) ──
            var needsComptage = false; var minsSinceCpt = null
            if (!p.activeArret) {
              var refTime = null
              if (p.lastComptage && p.lastComptage.created_at) { refTime = new Date(p.lastComptage.created_at) }
              else if (start) { refTime = start }
              if (refTime) { minsSinceCpt = Math.floor((n - refTime) / 60000); needsComptage = minsSinceCpt >= 30 }
            }
            newTheo[p.equip.id] = {
              boites: Math.floor(boitesTheo),
              colis: colisTheo,
              currentCadence: cads[cads.length - 1].cadence_bpm,
              needsComptage: needsComptage,
              minsSinceCpt: minsSinceCpt,
              isFallback: isFallbackCad
            }
          }
        }
        if (p.activeArret && p.activeArret.is_running) {
          var aStart = trsToDateTime(p.session ? p.session.date : new Date().toISOString().slice(0,10), p.activeArret.heure_debut)
          if (aStart) newAT[p.activeArret.id] = trsFormatElapsed(n - aStart)
        }
      }
      trsTimers.value = newT; trsArretTimers.value = newAT; trsTheoCounters.value = newTheo
    }

    var loadTrsFull = async function() {
      trsLoading.value = true
      var [rEq, rSh, rEq2, rFam, gsData, rRooms] = await Promise.all([
        supabase.from('equipements_conditionnement').select('*').eq('actif', true).order('ordre_affichage'),
        supabase.from('shifts').select('*').eq('actif', true).order('heure_debut'),
        supabase.from('equipes').select('*').eq('actif', true).order('nom'),
        supabase.from('arret_familles').select('*').eq('actif', true).order('ordre'),
        gsGetAll(),
        supabase.from('plan_rooms').select('code,equipement_id')
      ])
      if (rSh.data)  trsShifts.value       = rSh.data
      if (rEq2.data) trsEquipes.value       = rEq2.data
      if (rFam.data) trsArretFamilles.value = rFam.data
      trsCadences.value = gsData.cadences || []
      // Construire map equipement_id → N°_atelier via plan_rooms.code (ex: 'c149' → 149)
      var equipToNum = {}
      ;(rRooms.data || []).forEach(function(r) {
        if (r.equipement_id && r.code) {
          var num = parseInt(r.code.replace(/^[a-z]+/i, ''), 10)
          if (!isNaN(num)) equipToNum[r.equipement_id] = num
        }
      })
      // Enrichir chaque équipement avec les données GS onglet 1
      var equipList = (rEq.data || []).map(function(eq) {
        var numAtelier = equipToNum[eq.id] || null
        var gsRoom = numAtelier ? gsData.planRooms.find(function(r) { return r.id === numAtelier }) : null
        return Object.assign({}, eq, {
          numero_atelier:     numAtelier,
          to_shift_ref:       (gsRoom && gsRoom.to_shift_min)             || 480,
          pause_ref:          (gsRoom && gsRoom.pause_min)                || 0,
          vdlp_ref:           (gsRoom && gsRoom.vdlp_min)                 || 0,
          vdlc_ref:           (gsRoom && gsRoom.vdlc_min)                 || 0,
          chgt_format_ref:    (gsRoom && gsRoom.chgt_format_min)          || 0,
          reglage_ref:        (gsRoom && gsRoom.reglage_lancement_min)    || 0,
          micro_arrets_ref:   (gsRoom && gsRoom.micro_arrets_shift_min)   || 0,
          maint_curative_ref: (gsRoom && gsRoom.maint_curative_shift_min) || 0,
        })
      })
      var newPanels = []
      for (var i = 0; i < equipList.length; i++) {
        var eq = equipList[i]
        var rSess = await supabase.from('production_sessions')
          .select('*').eq('equipement_id', eq.id).neq('statut', 'Clôturé')
          .is('deleted_at', null).order('created_at', { ascending: false }).limit(1).maybeSingle()
        var session = rSess.data || null
        var lotNum = '—', lotProd = '—'
        if (session) {
          var rLot = await supabase.from('lots').select('numero_lot, product_id').eq('id', session.lot_id).maybeSingle()
          if (rLot.data) {
            lotNum = rLot.data.numero_lot
            var rProd = await supabase.from('products').select('code_article, description').eq('id', rLot.data.product_id).maybeSingle()
            if (rProd.data) lotProd = rProd.data.code_article + ' — ' + rProd.data.description
          }
        }
        var panelArrets = [], activeArret = null
        var cadences = [], lastComptage = null
        if (session) {
          var rArr = await supabase.from('production_arrets').select('*').eq('session_id', session.id).order('created_at', { ascending: false })
          if (rArr.data) { panelArrets = rArr.data; activeArret = panelArrets.find(function(a){ return a.is_running }) || null }
          var rCad = await supabase.from('session_cadences').select('*').eq('session_id', session.id).order('started_at')
          if (!rCad.error) cadences = rCad.data || []
          var rLastCpt = await supabase.from('production_comptages').select('id,heure,colis_cumules,created_at').eq('session_id', session.id).order('created_at', { ascending: false }).limit(1).maybeSingle()
          if (!rLastCpt.error) lastComptage = rLastCpt.data || null
        }
        var shiftNom = '', shiftCouleur = '#3B82F6', equipeNom = '', equipeCouleur = '#8B5CF6'
        if (session && session.shift_id) {
          var sh = trsShifts.value.find(function(s){ return s.id === session.shift_id })
          if (sh) { shiftNom = sh.nom; shiftCouleur = sh.couleur }
        }
        if (session && session.equipe_id) {
          var eq2 = trsEquipes.value.find(function(e){ return e.id === session.equipe_id })
          if (eq2) { equipeNom = eq2.nom; equipeCouleur = eq2.couleur }
        }
        var rendPct = 0
        if (session && session.objectif_boites && session.colis_produits) {
          var boitesProdR = session.colisage_confirme ? session.colis_produits * session.colisage_confirme : session.colis_produits
          rendPct = Math.round((boitesProdR / session.objectif_boites) * 100)
        }
        newPanels.push({ equip: eq, session, activeArret, arrets: panelArrets, cadences, lastComptage, lotNum, lotProd, shiftNom, shiftCouleur, equipeNom, equipeCouleur, rendPct })
      }
      trsPanels.value = newPanels
      // Sync TRS overlay data
      var today = new Date().toISOString().slice(0, 10)
      var [rS, rA] = await Promise.all([
        supabase.from('production_sessions').select('id,equipement_id,statut,date,heure_debut,heure_fin,disponibilite,performance,qualite,trs,colis_produits,colis_rebuts,objectif_boites,cadence_nominale_snapshot').eq('date', today).neq('statut', 'Annulé'),
        supabase.from('production_arrets').select('id,session_id,duree_minutes,est_planifie,est_pause,is_running')
      ])
      if (!rS.error) trsSessionsFull.value = rS.data || []
      if (!rA.error) trsArretsFull.value   = rA.data || []
      // Sync selectedTrsPanel pointer after reload
      if (selectedTrsPanel.value) {
        var updated = newPanels.find(function(p){ return p.equip.id === selectedTrsPanel.value.equip.id })
        selectedTrsPanel.value = updated || null
      }
      trsLoading.value = false
    }

    // ── TRS Actions ───────────────────────────────────────────────
    var trsOpenStart = function(equip) {
      trsStartModal.equip = equip; trsStartModal.lotSearch = ''; trsStartModal.lotSuggestions = []
      trsStartModal.lot = null; trsStartModal.shift_id = null; trsStartModal.equipe_id = null
      trsStartModal.date = new Date().toISOString().slice(0,10); trsStartModal.heure_debut = trsNowTime()
      trsStartModal.cadenceObj = null; trsStartModal.cadenceReel = null; trsStartModal.colisage = null; trsStartModal.colisageSrc = ''
      trsStartModal.error = ''; trsStartModal.saving = false; trsStartModal.show = true
    }

    var trsSearchLots = async function() {
      var q = trsStartModal.lotSearch
      if (!q || q.length < 2) { trsStartModal.lotSuggestions = []; return }
      var r = await supabase
        .from('lots')
        .select('id, numero_lot, product_id, products(code_article, description)')
        .ilike('numero_lot', '%' + q + '%')
        .limit(8)
      if (r.error) { trsStartModal.lotSuggestions = []; return }
      trsStartModal.lotSuggestions = (r.data || []).map(function(l) {
        return {
          id: l.id,
          numero_lot: l.numero_lot,
          code_article: l.products ? l.products.code_article : '',
          description:  l.products ? l.products.description  : '',
          product_id:   l.product_id
        }
      })
    }

    var trsSelectLot = async function(l) {
      trsStartModal.lot = l; trsStartModal.lotSearch = l.numero_lot; trsStartModal.lotSuggestions = []
      trsStartModal.cadenceObj = null
      if (trsStartModal.equip) {
        // Lookup cadence depuis GS onglet 2 : (N°_atelier × code_article)
        var numAtelier = trsStartModal.equip.numero_atelier
        if (numAtelier && l.code_article) {
          var match = trsCadences.value.find(function(c) {
            return c.numero_atelier === numAtelier && c.code_article === l.code_article
          })
          trsStartModal.cadenceObj = match ? match.cadence_objectif_b_min : null
        }
        if (!trsStartModal.cadenceReel && trsStartModal.cadenceObj) trsStartModal.cadenceReel = trsStartModal.cadenceObj
      }
      // Colisage : catalogue_produits en priorité, fallback products
      var colisage = null; var colisageSrc = ''
      if (l.code_article) {
        var catR = await supabase.from('catalogue_produits').select('quantite_par_colis').eq('code_article', l.code_article).maybeSingle()
        if (catR.data && catR.data.quantite_par_colis) { colisage = catR.data.quantite_par_colis; colisageSrc = 'catalogue' }
      }
      if (!colisage && l.product_id) {
        var prodR = await supabase.from('products').select('quantite_par_colis').eq('id', l.product_id).maybeSingle()
        if (prodR.data && prodR.data.quantite_par_colis) { colisage = prodR.data.quantite_par_colis; colisageSrc = 'sap' }
      }
      trsStartModal.colisage = colisage; trsStartModal.colisageSrc = colisageSrc
    }

    var trsDoStart = async function() {
      if (!trsStartModal.lot) { trsStartModal.error = 'Sélectionner un lot.'; return }
      trsStartModal.saving = true
      var eq = trsStartModal.equip
      var cadObj    = trsStartModal.cadenceObj           // GS onglet 2 uniquement
      var netRef    = trsNetRef(eq)                      // TO_GS - arrêts planifiés GS
      var objBoites = cadObj ? Math.round(cadObj * netRef) : null
      var r = await supabase.from('production_sessions').insert({
        lot_id: trsStartModal.lot.id, equipement_id: eq.id,
        shift_id: trsStartModal.shift_id||null, equipe_id: trsStartModal.equipe_id||null,
        date: trsStartModal.date, heure_debut: trsStartModal.heure_debut+':00', statut: 'En cours',
        cadence_nominale_snapshot: eq.cadence_nominale_boite_min||null, cadence_objectif_snapshot: cadObj||null,
        objectif_boites: objBoites, temps_ouverture_min: netRef,   // snapshot GS au démarrage
        colis_produits: 0, colis_rebuts: 0,
        colisage_confirme: trsStartModal.colisage || null
      }).select('id').single()
      if (r.error) { trsStartModal.error = r.error.message; trsStartModal.saving = false; return }
      // Insérer la cadence initiale dans session_cadences
      if (trsStartModal.cadenceReel && r.data) {
        var isoStart = new Date(trsStartModal.date + 'T' + trsStartModal.heure_debut).toISOString()
        await supabase.from('session_cadences').insert({
          session_id: r.data.id,
          cadence_bpm: trsStartModal.cadenceReel,
          colisage: trsStartModal.colisage || null,
          started_at: isoStart
        })
      }
      trsStartModal.show = false; trsStartModal.saving = false
      await loadTrsFull()
    }

    var trsOpenArret = function(p) {
      trsArretModal.panel = p; trsArretModal.famille_id = null; trsArretModal.sf_id = null; trsArretModal.type_id = null
      trsArretModal.sousFamilles = []; trsArretModal.types = []; trsArretModal.selectedType = null
      trsArretModal.heure_debut = trsNowTime(); trsArretModal.commentaire = ''; trsArretModal.error = ''; trsArretModal.saving = false; trsArretModal.show = true
    }

    var trsOnFamilleChange = async function() {
      trsArretModal.sf_id = null; trsArretModal.type_id = null; trsArretModal.sousFamilles = []; trsArretModal.types = []; trsArretModal.selectedType = null
      if (!trsArretModal.famille_id) return
      var f = trsArretFamilles.value.find(function(x){ return x.id === trsArretModal.famille_id })
      trsArretModal.familleCouleur = f ? f.couleur : '#EF4444'
      var r = await supabase.from('arret_sous_familles').select('*').eq('famille_id', trsArretModal.famille_id).eq('actif', true).order('ordre')
      trsArretModal.sousFamilles = r.data || []
    }

    var trsOnSFChange = async function() {
      trsArretModal.type_id = null; trsArretModal.types = []; trsArretModal.selectedType = null
      if (!trsArretModal.sf_id) return
      var r = await supabase.from('arret_types').select('*').eq('sous_famille_id', trsArretModal.sf_id).eq('actif', true).order('code')
      trsArretModal.types = r.data || []
    }

    var trsOnTypeChange = function() {
      trsArretModal.selectedType = trsArretModal.types.find(function(t){ return t.id === trsArretModal.type_id }) || null
    }

    var trsDoArret = async function() {
      if (!trsArretModal.type_id) { trsArretModal.error = 'Sélectionner un code arrêt.'; return }
      trsArretModal.saving = true
      var t = trsArretModal.selectedType
      var f = trsArretFamilles.value.find(function(x){ return x.id === trsArretModal.famille_id })
      var sf = trsArretModal.sousFamilles.find(function(x){ return x.id === trsArretModal.sf_id })
      var r = await supabase.from('production_arrets').insert({
        session_id: trsArretModal.panel.session.id, arret_type_id: t.id,
        famille_nom: f?f.nom:'', sous_famille_nom: sf?sf.nom:'', arret_code: t.code, arret_nom: t.nom,
        couleur: t.couleur||(f?f.couleur:'#EF4444'), est_planifie: t.est_planifie, est_pause: t.est_pause,
        heure_debut: trsArretModal.heure_debut+':00', is_running: true, commentaire: trsArretModal.commentaire||null
      })
      if (r.error) { trsArretModal.error = r.error.message; trsArretModal.saving = false; return }
      await supabase.from('production_sessions').update({ statut: t.est_pause?'Pause':'Arrêt', updated_at: new Date().toISOString() }).eq('id', trsArretModal.panel.session.id)
      trsArretModal.show = false; trsArretModal.saving = false
      await loadTrsFull()
    }

    var trsClotureArret = async function(p) {
      if (!p.activeArret) return
      var now = trsNowTime()
      var start = trsToDateTime(p.session.date, p.activeArret.heure_debut)
      var dur = start ? Math.round((new Date() - start) / 60000) : null
      await supabase.from('production_arrets').update({ heure_fin: now+':00', duree_minutes: dur, is_running: false, updated_at: new Date().toISOString() }).eq('id', p.activeArret.id)
      await supabase.from('production_sessions').update({ statut: 'En cours', updated_at: new Date().toISOString() }).eq('id', p.session.id)
      await loadTrsFull()
    }

    var trsOpenRequalif = function(p) {
      trsRequalModal.panel = p; trsRequalModal.famille_id = null; trsRequalModal.sf_id = null; trsRequalModal.type_id = null
      trsRequalModal.sousFamilles = []; trsRequalModal.types = []; trsRequalModal.saving = false; trsRequalModal.show = true
    }

    var trsOnRequalFamilleChange = async function() {
      trsRequalModal.sf_id = null; trsRequalModal.type_id = null; trsRequalModal.types = []
      if (!trsRequalModal.famille_id) return
      var r = await supabase.from('arret_sous_familles').select('*').eq('famille_id', trsRequalModal.famille_id).eq('actif', true).order('ordre')
      trsRequalModal.sousFamilles = r.data || []
    }

    var trsOnRequalSFChange = async function() {
      trsRequalModal.type_id = null
      if (!trsRequalModal.sf_id) return
      var r = await supabase.from('arret_types').select('*').eq('sous_famille_id', trsRequalModal.sf_id).eq('actif', true).order('code')
      trsRequalModal.types = r.data || []
    }

    var trsDoRequalif = async function() {
      if (!trsRequalModal.type_id || !trsRequalModal.panel.activeArret) return
      trsRequalModal.saving = true
      var t = trsRequalModal.types.find(function(x){ return x.id === trsRequalModal.type_id })
      var f = trsArretFamilles.value.find(function(x){ return x.id === trsRequalModal.famille_id })
      var sf = trsRequalModal.sousFamilles.find(function(x){ return x.id === trsRequalModal.sf_id })
      await supabase.from('production_arrets').update({
        arret_type_id: t.id, famille_nom: f?f.nom:'', sous_famille_nom: sf?sf.nom:'',
        arret_code: t.code, arret_nom: t.nom, couleur: t.couleur||(f?f.couleur:'#EF4444'),
        est_planifie: t.est_planifie, est_pause: t.est_pause, updated_at: new Date().toISOString()
      }).eq('id', trsRequalModal.panel.activeArret.id)
      trsRequalModal.show = false; trsRequalModal.saving = false
      await loadTrsFull()
    }

    var trsOpenCadence = function(p) {
      var cads = p.cadences || []
      trsCadenceModal.panel   = p
      trsCadenceModal.cadence = cads.length ? cads[cads.length - 1].cadence_bpm : null
      trsCadenceModal.saving  = false
      trsCadenceModal.show    = true
    }

    var trsDoChangeCadence = async function() {
      if (!trsCadenceModal.cadence) return
      trsCadenceModal.saving = true
      var s = trsCadenceModal.panel.session
      var r = await supabase.from('session_cadences').insert({
        session_id: s.id,
        cadence_bpm: trsCadenceModal.cadence,
        colisage: s.colisage_confirme || null,
        started_at: new Date().toISOString()
      })
      if (r.error) { trsCadenceModal.saving = false; return }
      trsCadenceModal.show = false; trsCadenceModal.saving = false
      await loadTrsFull()
    }

    var openTrsHisto = async function() {
      trsHistoModal.date     = new Date().toISOString().slice(0,10)
      trsHistoModal.equip_id = null
      trsHistoModal.sessions = []
      trsHistoModal.show     = true
      // Charger la liste des machines si pas encore fait
      if (!trsEquipes_list.value.length) {
        var rEqH = await supabase.from('equipements_conditionnement').select('id,nom_equipement').eq('actif', true).order('ordre_affichage')
        if (!rEqH.error) trsEquipes_list.value = rEqH.data || []
      }
      await loadTrsHistoData()
    }

    var loadTrsHistoData = async function() {
      trsHistoModal.loading = true
      var q = supabase.from('production_sessions')
        .select('id,equipement_id,lot_id,shift_id,statut,date,heure_debut,heure_fin,colis_produits,colis_rebuts,colisage_confirme,disponibilite,performance,qualite,trs,objectif_boites')
        .eq('date', trsHistoModal.date)
        .order('heure_debut', { ascending: true })
      if (trsHistoModal.equip_id) q = q.eq('equipement_id', trsHistoModal.equip_id)
      var r = await q
      var sessions = r.data || []
      // Enrichir avec nom machine, lot, shift
      var equipIds = [...new Set(sessions.map(function(s){ return s.equipement_id }).filter(Boolean))]
      var lotIds   = [...new Set(sessions.map(function(s){ return s.lot_id }).filter(Boolean))]
      var shiftIds = [...new Set(sessions.map(function(s){ return s.shift_id }).filter(Boolean))]
      var equipMap = {}, lotMap = {}, shiftMap = {}
      if (equipIds.length) {
        var rEq = await supabase.from('equipements_conditionnement').select('id,nom_equipement').in('id', equipIds)
        ;(rEq.data||[]).forEach(function(e){ equipMap[e.id] = e.nom_equipement })
      }
      if (lotIds.length) {
        var rLt = await supabase.from('lots').select('id,numero_lot').in('id', lotIds)
        ;(rLt.data||[]).forEach(function(l){ lotMap[l.id] = l.numero_lot })
      }
      if (shiftIds.length) {
        var rSh2 = await supabase.from('shifts').select('id,nom').in('id', shiftIds)
        ;(rSh2.data||[]).forEach(function(s){ shiftMap[s.id] = s.nom })
      }
      sessions.forEach(function(s) {
        s._equipNom  = equipMap[s.equipement_id] || '—'
        s._lotNum    = lotMap[s.lot_id]   || '—'
        s._shiftNom  = shiftMap[s.shift_id] || '—'
        s._colisage  = s.colisage_confirme || null
      })
      trsHistoModal.sessions = sessions
      trsHistoModal.loading  = false
    }

    var trsOpenComptage = function(p) {
      trsComptageModal.panel  = p; trsComptageModal.heure  = trsNowTime()
      var colisageCpt = p.session ? p.session.colisage_confirme : null
      trsComptageModal.boites = p.session ? (colisageCpt && p.session.colis_produits ? p.session.colis_produits * colisageCpt : p.session.colis_produits) : null
      trsComptageModal.rebuts = p.session ? (colisageCpt && p.session.colis_rebuts ? p.session.colis_rebuts * colisageCpt : (p.session.colis_rebuts || 0)) : 0
      trsComptageModal.saving = false; trsComptageModal.show = true
    }

    var trsDoComptage = async function() {
      if (!trsComptageModal.boites) return
      trsComptageModal.saving = true
      var s = trsComptageModal.panel.session
      var colisageCpt2 = s.colisage_confirme || null
      var boitesCpt = trsComptageModal.boites
      var colisCpt  = (colisageCpt2 && colisageCpt2 > 0) ? Math.floor(boitesCpt / colisageCpt2) : boitesCpt
      var rebutsBte = trsComptageModal.rebuts || 0
      var rebuts    = (colisageCpt2 && colisageCpt2 > 0) ? Math.floor(rebutsBte / colisageCpt2) : rebutsBte
      var start = trsToDateTime(s.date, s.heure_debut)
      var minEl = start ? (new Date() - start) / 60000 : null
      var cadInst = (minEl && minEl > 0) ? parseFloat((boitesCpt / minEl).toFixed(2)) : null
      await supabase.from('production_comptages').insert({ session_id: s.id, heure: trsComptageModal.heure+':00', colis_cumules: colisCpt, rebuts_cumules: rebuts, cadence_instantanee: cadInst })
      await supabase.from('production_sessions').update({ colis_produits: colisCpt, colis_rebuts: rebuts, cadence_reelle_boite_min: cadInst, updated_at: new Date().toISOString() }).eq('id', s.id)
      trsComptageModal.show = false; trsComptageModal.saving = false
      await loadTrsFull()
    }

    var trsOpenClose = function(p) {
      trsCloseModal.panel = p; trsCloseModal.heure_fin = trsNowTime()
      var colisageClose = p.session ? p.session.colisage_confirme : null
      trsCloseModal.colis_produits = p.session ? (colisageClose && p.session.colis_produits ? p.session.colis_produits * colisageClose : p.session.colis_produits) : null
      trsCloseModal.colis_rebuts   = p.session ? (colisageClose && p.session.colis_rebuts ? p.session.colis_rebuts * colisageClose : (p.session.colis_rebuts || 0)) : 0
      trsCloseModal.observation = ''; trsCloseModal.error = ''; trsCloseModal.saving = false; trsCloseModal.show = true
    }

    var trsDoClose = async function() {
      if (!trsCloseModal.heure_fin) { trsCloseModal.error = 'Heure de fin requise.'; return }
      trsCloseModal.saving = true
      var s = trsCloseModal.panel.session; var eq = trsCloseModal.panel.equip; var arrs = trsCloseModal.panel.arrets || []
      var start = trsToDateTime(s.date, s.heure_debut); var end = trsToDateTime(s.date, trsCloseModal.heure_fin)
      var totalMin   = (start && end) ? Math.round((end - start) / 60000) : 0
      var arretImpro = arrs.reduce(function(a,x){ return !x.est_planifie && !x.est_pause ? a+(x.duree_minutes||0) : a }, 0)
      var arretPlan  = arrs.reduce(function(a,x){ return x.est_planifie && !x.est_pause ? a+(x.duree_minutes||0) : a }, 0)
      var pauses     = arrs.reduce(function(a,x){ return x.est_pause ? a+(x.duree_minutes||0) : a }, 0)
      // TO net de référence : snapshot au démarrage ou fallback GS
      var toNetRef  = s.temps_ouverture_min || trsNetRef(eq)
      var tf        = Math.max(0, toNetRef - arretImpro)
      // colis_produits ici contient des BOITES (l'opérateur saisit des boites)
      var boitesClose = trsCloseModal.colis_produits||0
      var rebuts_bte  = trsCloseModal.colis_rebuts||0
      var colisageClose2 = s.colisage_confirme || null
      var colisClose  = (colisageClose2 && colisageClose2 > 0) ? Math.floor(boitesClose / colisageClose2) : boitesClose
      var colisRbtClose = (colisageClose2 && colisageClose2 > 0) ? Math.floor(rebuts_bte / colisageClose2) : rebuts_bte
      var total = boitesClose; var good = total - rebuts_bte
      var cadObj    = s.cadence_objectif_snapshot                     // GS onglet 2
      var cadReelle = (totalMin>0 && total>0) ? parseFloat((total/totalMin).toFixed(2)) : null
      var D   = toNetRef>0 ? Math.round((tf/toNetRef)*100) : null
      // Performance = boitesTotal / (cadObj_GS × tf) — cap 150 %
      var P   = (tf>0 && cadObj>0) ? Math.min(150, Math.round((total/(cadObj*tf))*100)) : null
      var Q   = total>0 ? Math.round((good/total)*100) : null
      var TRS = (D!=null && P!=null && Q!=null) ? Math.round((D/100)*(P/100)*(Q/100)*100) : null
      var rendPct = (s.objectif_boites && total) ? Math.round((total/s.objectif_boites)*100) : null
      if (trsCloseModal.panel.activeArret) {
        var now = trsNowTime()
        var aStart = trsToDateTime(s.date, trsCloseModal.panel.activeArret.heure_debut)
        var aDur = aStart ? Math.round((end - aStart) / 60000) : null
        await supabase.from('production_arrets').update({ heure_fin: now+':00', duree_minutes: aDur, is_running: false, updated_at: new Date().toISOString() }).eq('id', trsCloseModal.panel.activeArret.id)
      }
      var r = await supabase.from('production_sessions').update({
        heure_fin: trsCloseModal.heure_fin+':00', statut: 'Clôturé',
        colis_produits: colisClose, colis_rebuts: colisRbtClose,
        cadence_reelle_boite_min: cadReelle, rendement_pct: rendPct,
        temps_ouverture_min: toNetRef, temps_fonctionnement_min: tf,
        temps_arret_planifie_min: arretPlan, temps_arret_impro_min: arretImpro, temps_pause_min: pauses,
        disponibilite: D, performance: P, qualite: Q, trs: TRS,
        observation: trsCloseModal.observation||null, updated_at: new Date().toISOString()
      }).eq('id', s.id)
      if (r.error) { trsCloseModal.error = r.error.message; trsCloseModal.saving = false; return }
      trsCloseModal.show = false; trsCloseModal.saving = false; selectedTrsPanel.value = null
      await loadTrsFull()
    }

    // ── PRODUCT FLUX STATE ────────────────────────────────────────
    var productSearch     = ref('')
    var showSuggestions   = ref(false)
    var allProductsFlux   = ref([])   // from v_product_flux_summary
    var selectedProduct   = ref(null)
    var activeRoute       = ref(1)
    var productFluxData   = ref([])   // product_flux rows for selected product
    var opMaster          = ref([])   // operations_master rows

    // ── MODAL STATE ───────────────────────────────────────────────
    var modal = ref({
      open: false, type: '', saving: false, err: '',
      lotSearch: '', lotDropdown: [], selectedLot: null,
      dateDebut: '', dateFin: '', quantite: null,
      motif: '', fabId: '', lotId: '', description: '',
      nodeType: 'fab'
    })
    var modalLotPreselect = ref(null)

    var legend = [
      { label: 'En cours', color: '#10b981' },
      { label: 'Arrêt',    color: '#ef4444' },
      { label: 'Déviation',color: '#f59e0b' },
      { label: 'Libre',    color: '#4b5563' },
    ]

    var zones = [
      { key: 'formes_seches',   label: 'Formes Sèches',        color: '#7c3aed' },
      { key: 'formes_semi',     label: 'Formes Semi-Solides',   color: '#2563eb' },
      { key: 'cond_primaire',   label: 'Cond. Primaire',        color: '#059669' },
      { key: 'cond_secondaire', label: 'Cond. Secondaire',      color: '#047857' },
      { key: 'pesee',           label: 'Zone Pesée',            color: '#d97706' },
      { key: 'otc',             label: 'OTC',                   color: '#0891b2' },
      { key: 'stockage_sf',     label: 'Stock Inter. SF',       color: '#b45309' },
      { key: 'stockage_pf',     label: 'SAS Livraison PF',      color: '#7c2d12' },
    ]

    var zoneColor = function(z) {
      var found = zones.find(function(x) { return x.key === z })
      return found ? found.color : '#888'
    }
    var zoneLabel = function(z) {
      var found = zones.find(function(x) { return x.key === z })
      return found ? found.label : '—'
    }

    // ─── NODES enrichis ─────────────────────────────────────────
    // plan_rooms.code = n.id ('p464','n140'...) — pas n.code ('464','140')
    var allNodes = computed(function() {
      return NODES_DEF.map(function(n) {
        var room = rooms.value.find(function(r) { return r.code === n.id })
        return Object.assign({}, n, {
          atelier_id:    room ? room.atelier_id    : null,
          equipement_id: room ? room.equipement_id : null,
        })
      })
    })

    // ─── FLUX HIGHLIGHTING ───────────────────────────────────────
    // Set of node IDs that are in the selected product's flux
    var fluxNodeIds = computed(function() {
      if (!selectedProduct.value || !productFluxData.value.length) return null
      var flux = productFluxData.value.filter(function(pf) {
        return pf.route === activeRoute.value
      })
      if (!flux.length) return null
      var roomCodes = new Set()
      flux.forEach(function(pf) {
        if (pf.room_code) {
          // Specific room assigned
          roomCodes.add(pf.room_code)
        } else {
          // Flexible: all rooms with this op_number
          opMaster.value.filter(function(om) {
            return om.op_number === pf.op_number
          }).forEach(function(om) {
            roomCodes.add(om.room_code)
          })
        }
      })
      var nodeIds = new Set()
      allNodes.value.forEach(function(n) {
        if (roomCodes.has(n.code)) nodeIds.add(n.id)
      })
      return nodeIds
    })

    var nodeIsFlux = function(node) {
      return fluxNodeIds.value !== null && fluxNodeIds.value.has(node.id)
    }

    var nodeDim = function(node) {
      if (fluxNodeIds.value === null) return 1
      return fluxNodeIds.value.has(node.id) ? 1 : 0.18
    }

    // ─── ARROWS ─────────────────────────────────────────────────
    var arrows = computed(function() {
      return ARROWS_DEF.map(function(a) {
        var fromNode = allNodes.value.find(function(n) { return n.id === a.from })
        var toNode   = allNodes.value.find(function(n) { return n.id === a.to   })
        if (!fromNode || !toNode) return null
        var x1 = fromNode.x + fromNode.w
        var y1 = fromNode.y + fromNode.h / 2
        var x2 = toNode.x
        var y2 = toNode.y + toNode.h / 2
        if (Math.abs(x1 - x2) < 20) {
          x1 = fromNode.x + fromNode.w / 2
          y1 = fromNode.y + fromNode.h
          x2 = toNode.x + toNode.w / 2
          y2 = toNode.y - 2
        }
        var active = nodeStatus(fromNode).label === 'En cours'
        var fluxHighlight = fluxNodeIds.value !== null &&
          fluxNodeIds.value.has(a.from) && fluxNodeIds.value.has(a.to)
        var mx = (x1 + x2) / 2
        return Object.assign({}, a, {
          d: 'M'+x1+','+y1+' C'+mx+','+y1+' '+mx+','+y2+' '+x2+','+y2,
          active, fluxHighlight
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
      if (trsMode.value) {
        var t = nodeTrs(node)
        if (!t || t.trs == null) return '#12122a'
        if (t.trs >= 85) return '#062216'
        if (t.trs >= 60) return '#231500'
        return '#1f0808'
      }
      var st = nodeStatus(node)
      if (st.label === 'Arrêt')     return '#3f1212'
      if (st.label === 'Déviation') return '#3f2e00'
      if (st.label === 'En cours')  return '#0d2e20'
      if (nodeIsFlux(node)) return '#2a2000'
      var z = zones.find(function(x) { return x.key === node.zone })
      return z ? z.color + '22' : '#1e1e3a'
    }

    var nodeStroke = function(node) {
      if (selectedNode.value && selectedNode.value.id === node.id) return '#fff'
      if (trsMode.value) {
        var t = nodeTrs(node)
        if (t && t.trs != null) return trsColor(t.trs)
        return '#2a2a4a'
      }
      if (nodeIsFlux(node)) return '#fbbf24'
      var st = nodeStatus(node)
      if (st.label === 'Arrêt')     return '#ef4444'
      if (st.label === 'Déviation') return '#f59e0b'
      if (st.label === 'En cours')  return '#10b981'
      return zoneColor(node.zone) + '88'
    }

    var nodeStrokeWidth = function(node) {
      if (selectedNode.value && selectedNode.value.id === node.id) return 2.5
      if (trsMode.value) {
        var t = nodeTrs(node)
        return (t && t.trs != null) ? 2 : 1
      }
      if (nodeIsFlux(node)) return 2
      return 1.5
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
      if (!node) return []
      var res = []
      suiviFab.value.filter(function(sf) { return sf.atelier_id === node.atelier_id })
        .forEach(function(sf) {
          res.push({
            id: 'f' + sf.id, fabId: sf.id, lotRawId: sf.lot_id,
            numero_lot: sf.lots?.numero_lot || sf.lot_id,
            nom_produit: sf.lots?.products?.description || '',
            statut: sf.statut, isFab: true
          })
        })
      sessions.value.filter(function(s) { return s.equipement_id === node.equipement_id })
        .forEach(function(s) {
          res.push({
            id: 's' + s.id, fabId: s.id, lotRawId: s.lot_id,
            numero_lot: s.lots?.numero_lot || s.lot_id,
            nom_produit: s.lots?.products?.nom_produit || '',
            statut: s.statut, isFab: false
          })
        })
      return res
    }

    // ─── PRODUCT SEARCH ─────────────────────────────────────────
    var productSuggestions = computed(function() {
      if (!productSearch.value || productSearch.value.length < 2) return []
      var q = productSearch.value.toLowerCase()
      return allProductsFlux.value.filter(function(p) {
        return p.product_code.toLowerCase().includes(q) ||
               p.product_name.toLowerCase().includes(q)
      }).slice(0, 12)
    })

    var onProductSearch = function() {
      showSuggestions.value = true
    }

    var closeSuggestions = function() {
      showSuggestions.value = false
    }

    var pickProduct = async function(p) {
      selectedProduct.value = p
      activeRoute.value = 1
      showSuggestions.value = false
      productSearch.value = ''
      // Load product flux details
      var res = await supabase.from('product_flux')
        .select('*')
        .eq('product_code', p.product_code)
      if (!res.error) productFluxData.value = res.data
    }

    var clearProduct = function() {
      selectedProduct.value = null
      productFluxData.value = []
      productSearch.value = ''
    }

    var clearProductSearch = function() {
      productSearch.value = ''
      showSuggestions.value = false
    }

    var toggleRoute = function() {
      activeRoute.value = activeRoute.value === 1 ? 2 : 1
    }

    // ─── MODALS ─────────────────────────────────────────────────
    var closeModal = function() {
      modal.value.open = false
      modal.value.err = ''
    }

    var resetModal = function(type) {
      var now2 = new Date().toISOString().slice(0, 16)
      modal.value = {
        open: true, type: type, saving: false, err: '',
        lotSearch: '', lotDropdown: [], selectedLot: null, lots: [],
        dateDebut: now2, dateFin: now2,
        quantite: null, motif: '', fabId: '', lotId: '',
        description: '', nodeType: selectedNode.value?.type || 'fab'
      }
    }

    var openStartModal = function() {
      resetModal('start')
      // Pre-select lot if one was clicked in the list
      if (modalLotPreselect.value) {
        var l = modalLotPreselect.value
        modal.value.selectedLot = l
        modal.value.lots = [l]
        modal.value.lotSearch = ''
      }
    }
    var openStopModal = function() {
      resetModal('stop')
    }
    var openCloseModal = function() {
      resetModal('close')
    }
    var openDevModal = function() {
      resetModal('deviation')
    }

    var searchModalLots = async function() {
      var q = modal.value.lotSearch
      if (!q || q.length < 2) { modal.value.lotDropdown = []; return }
      var res = await supabase.from('lots')
        .select('id,numero_lot,products(description)')
        .ilike('numero_lot', '%'+q+'%')
        .limit(10)
      if (!res.error) modal.value.lotDropdown = res.data
    }

    var selectModalLot = function(l) {
      // Ajoute à la liste multi-lots si pas déjà présent
      if (!modal.value.lots) modal.value.lots = []
      if (!modal.value.lots.find(function(x) { return x.id === l.id })) {
        modal.value.lots.push(l)
      }
      modal.value.selectedLot = l
      modal.value.lotSearch = ''
      modal.value.lotDropdown = []
    }

    var removeLot = function(l) {
      modal.value.lots = modal.value.lots.filter(function(x) { return x.id !== l.id })
      if (modal.value.selectedLot && modal.value.selectedLot.id === l.id) {
        modal.value.selectedLot = modal.value.lots.length ? modal.value.lots[modal.value.lots.length - 1] : null
      }
    }

    // Mapping op_code → nom du processus dans la table `processus`
    var OP_CODE_TO_PROC = {
      'PESEE':'Pesée','PESÉE':'Pesée',
      'GRANULATION SEC':'Granulation','GRANULATION':'Granulation',
      'MELANGE':'Mélange','MÉLANGE':'Mélange',
      'COMPRESSION':'Compression',
      'PELLICULAGE':'Pelliculage',
      'MISE EN GELULE':'Encapsulation','MISE EN GÉLULE':'Encapsulation',
      'FAB/CREME ET POMMADE':'Fabrication Crème/Pommade'
    }

    var saveStart = async function() {
      var lotsToStart = (modal.value.lots && modal.value.lots.length)
        ? modal.value.lots
        : (modal.value.selectedLot ? [modal.value.selectedLot] : [])
      if (!lotsToStart.length) { modal.value.err = 'Sélectionner au moins un lot.'; return }
      if (!selectedNode.value) return
      modal.value.saving = true; modal.value.err = ''
      var node = selectedNode.value
      var res

      if (node.type === 'cond') {
        // ── CONDITIONNEMENT ─────────────────────────────────────
        var eqId = node.equipement_id
        if (!eqId) {
          // Auto-résolution depuis equipements_conditionnement par nom
          var eqR = await supabase.from('equipements_conditionnement').select('id').ilike('nom_equipement','%'+node.label+'%').limit(1).maybeSingle()
          if (!eqR.data) { modal.value.err = 'Équipement introuvable pour nœud '+node.code+'. Vérifier le nom dans Équipements.'; modal.value.saving=false; return }
          eqId = eqR.data.id
          await supabase.from('plan_rooms').upsert({code:node.id, equipement_id:eqId, atelier_id:null},{onConflict:'code'})
        }
        for (var ci = 0; ci < lotsToStart.length; ci++) {
          res = await supabase.from('production_sessions').insert({
            lot_id: lotsToStart[ci].id,
            equipement_id: eqId,
            date: modal.value.dateDebut.slice(0, 10),
            heure_debut: modal.value.dateDebut.slice(11) + ':00',
            statut: 'En cours',
            colis_produits: 0, colis_rebuts: 0
          })
          if (res.error) { modal.value.err = 'Lot '+lotsToStart[ci].numero_lot+' : '+res.error.message; modal.value.saving=false; return }
        }
      } else {
        // ── FABRICATION ──────────────────────────────────────────
        var atId = node.atelier_id
        if (!atId) {
          // Auto-résolution : cherche dans operations_master (chargé depuis Google Sheets)
          var omRow    = opMaster.value.find(function(om) { return om.room_code === node.id })
          var roomName = omRow ? omRow.room_name : node.label
          var opCode   = omRow ? omRow.op_code   : ''
          var procName = OP_CODE_TO_PROC[opCode] || null
          var procId = null
          if (procName) {
            var pR = await supabase.from('processus').select('id').ilike('nom_process',procName).limit(1).maybeSingle()
            procId = pR.data ? pR.data.id : null
          }
          // Cherche l'atelier existant par nom de salle
          var atR = await supabase.from('ateliers').select('id').eq('nom_atelier',roomName).limit(1).maybeSingle()
          if (atR.data) {
            atId = atR.data.id
          } else {
            // Crée l'atelier automatiquement
            var insAt = await supabase.from('ateliers').insert({nom_atelier:roomName, processus_id:procId, actif:true}).select('id').single()
            if (insAt.error) { modal.value.err = 'Erreur création atelier : '+insAt.error.message; modal.value.saving=false; return }
            atId = insAt.data.id
          }
          // Mémorise dans plan_rooms pour les prochaines fois
          await supabase.from('plan_rooms').upsert({code:node.id, atelier_id:atId, equipement_id:null},{onConflict:'code'})
        }
        var atRes = await supabase.from('ateliers').select('processus_id').eq('id',atId).single()
        var processusId = atRes.data?.processus_id || null
        for (var fi = 0; fi < lotsToStart.length; fi++) {
          res = await supabase.from('suivi_fabrication').insert({
            lot_id: lotsToStart[fi].id,
            atelier_id: atId,
            processus_id: processusId,
            date_debut: modal.value.dateDebut || null,
            statut: 'En cours'
          })
          if (res.error) { modal.value.err = 'Lot '+lotsToStart[fi].numero_lot+' : '+res.error.message; modal.value.saving=false; return }
        }
      }
      modal.value.saving = false
      modal.value.open = false
      modalLotPreselect.value = null
      await loadLive()
    }

    var saveStop = async function() {
      if (!modal.value.fabId) { modal.value.err = 'Sélectionner une session.'; return }
      if (!modal.value.motif.trim()) { modal.value.err = 'Motif requis.'; return }
      modal.value.saving = true; modal.value.err = ''
      var node = selectedNode.value
      var res
      if (node.type === 'cond') {
        // Cond: insert production_arret (utiliser TRS modal pour les arrêts détaillés)
        res = await supabase.from('production_arrets').insert({
          session_id: modal.value.fabId,
          commentaire: modal.value.motif || null,
          heure_debut: new Date().toTimeString().slice(0,5) + ':00',
          is_running: true
        })
        if (!res.error) {
          await supabase.from('production_sessions').update({ statut: 'Arrêt', updated_at: new Date().toISOString() }).eq('id', modal.value.fabId)
        }
      } else {
        // Fab: insert atelier_arret
        res = await supabase.from('atelier_arrets').insert({
          atelier_id: node.atelier_id,
          motif: modal.value.motif,
          heure_debut: modal.value.dateDebut || new Date().toISOString()
        })
        if (!res.error) {
          await supabase.from('suivi_fabrication').update({ statut: 'Arrêt' }).eq('id', modal.value.fabId)
        }
      }
      modal.value.saving = false
      if (res.error) { modal.value.err = res.error.message; return }
      modal.value.open = false
      await loadLive()
    }

    var saveClose = async function() {
      if (!modal.value.fabId) { modal.value.err = 'Sélectionner une session.'; return }
      modal.value.saving = true; modal.value.err = ''
      var node = selectedNode.value
      var res
      if (node.type === 'cond') {
        res = await supabase.from('production_sessions').update({
          statut: 'Clôturé',
          heure_fin: modal.value.dateFin ? modal.value.dateFin.slice(11) + ':00' : new Date().toISOString().slice(11, 19)
        }).eq('id', modal.value.fabId)
      } else {
        res = await supabase.from('suivi_fabrication').update({
          statut: 'Clôturé',
          date_fin: modal.value.dateFin || new Date().toISOString()
        }).eq('id', modal.value.fabId)
      }
      modal.value.saving = false
      if (res.error) { modal.value.err = res.error.message; return }
      modal.value.open = false
      await loadLive()
    }

    var saveDev = async function() {
      if (!modal.value.lotId) { modal.value.err = 'Sélectionner un lot.'; return }
      if (!modal.value.description.trim()) { modal.value.err = 'Description requise.'; return }
      modal.value.saving = true; modal.value.err = ''
      var userData = await supabase.auth.getUser()
      var userId = userData.data.user?.id || null
      var userMeta = userData.data.user?.user_metadata || {}
      var userService = userMeta.service || null
      try {
        await declareDeviation(modal.value.lotId, modal.value.description, false, null, userId, userService)
      } catch(e) {
        modal.value.err = e.message || 'Erreur'; modal.value.saving = false; return
      }
      modal.value.saving = false
      modal.value.open = false
      await loadLive()
    }

    // ─── LOAD ────────────────────────────────────────────────────
    var loadLive = async function() {
      loading.value = true
      var [gsData, rRoomsFK, r2, r3, r4, r5, r6] = await Promise.all([
        gsGetAll(),
        // FK uniquement : atelier_id + equipement_id (non présents dans le CSV)
        supabase.from('plan_rooms').select('code,atelier_id,equipement_id'),
        supabase.from('suivi_fabrication')
          .select('id,lot_id,atelier_id,statut,lots(numero_lot,products(description))')
          .is('deleted_at', null).in('statut', ['En cours', 'Arrêt']),
        supabase.from('production_sessions')
          .select('id,lot_id,equipement_id,statut,lots(numero_lot,products(description))')
          .in('statut', ['En cours', 'Arrêt']),
        supabase.from('deviations')
          .select('id,lot_id,statut').in('statut', ['ouverte', 'en_cours']),
        supabase.from('production_arrets')
          .select('id,session_id,is_running').eq('is_running', true),
        // Product flux summary (for search)
        supabase.from('v_product_flux_summary').select('*').order('product_name'),
      ])
      // plan_rooms depuis Google Sheets (noms, codes) + FKs depuis Supabase (atelier_id, equipement_id)
      var fkMap = {}
      ;(rRoomsFK.data || []).forEach(function(r) {
        fkMap[r.code] = { atelier_id: r.atelier_id || null, equipement_id: r.equipement_id || null }
      })
      rooms.value = gsData.planRooms.map(function(r) {
        var fk = fkMap[r.code] || {}
        return Object.assign({}, r, { atelier_id: fk.atelier_id || null, equipement_id: fk.equipement_id || null })
      })
      opMaster.value = gsData.operationsMaster
      trsCadences.value = gsData.cadences || []
      if (!r2.error) suiviFab.value   = r2.data
      if (!r3.error) sessions.value   = r3.data
      if (!r4.error) deviations.value = r4.data
      if (!r5.error) arrets.value     = r5.data
      if (!r6.error) {
        // Deduplicate: keep unique (product_code, route), mark has_route_2
        var seen = new Map()
        ;(r6.data||[]).forEach(function(p) {
          var key = p.product_code
          if (!seen.has(key)) seen.set(key, { routes: [] })
          seen.get(key).routes.push(p.route)
          seen.get(key).product = p
        })
        var list = []
        seen.forEach(function(v) {
          var p = Object.assign({}, v.product, { has_route_2: v.routes.includes(2) })
          list.push(p)
        })
        allProductsFlux.value = list
      }
      loading.value = false
    }

    // ─── ACTIONS ─────────────────────────────────────────────────
    var selectNode = async function(node) {
      selectedNode.value = node
      modalLotPreselect.value = null
      if (trsMode.value && node.type === 'cond') {
        // 1. Chercher dans trsPanels déjà chargés
        var panel = trsPanels.value.find(function(p){ return p.equip.id === node.equipement_id }) || null
        // 2. Si pas trouvé mais equipement_id existe → fetch direct (équipement inactif ou non encore chargé)
        if (!panel && node.equipement_id) {
          var rEqDirect = await supabase.from('equipements_conditionnement').select('*').eq('id', node.equipement_id).maybeSingle()
          if (rEqDirect.data) {
            panel = { equip: rEqDirect.data, session: null, activeArret: null, arrets: [], cadences: [], lastComptage: null, lotNum: null, lotProd: null, shiftNom: '', shiftCouleur: '#3B82F6', equipeNom: '', equipeCouleur: '#8B5CF6', rendPct: 0 }
            trsPanels.value = trsPanels.value.concat([panel])
          }
        }
        selectedTrsPanel.value = panel
      } else {
        selectedTrsPanel.value = null
      }
    }

    // ─── LIFECYCLE ───────────────────────────────────────────────
    var refreshInt = null
    onMounted(async function() {
      await loadLive()
      refreshInt = setInterval(loadLive, 60000)
    })
    onBeforeUnmount(function() {
      clearInterval(refreshInt)
      clearInterval(trsClockInt)
      clearInterval(trsRefreshInt)
    })

    return {
      theme,
      SVG_W, SVG_H, NW, NH,
      TRACK_X, TRACKS_W, ZONE_FS_Y, ZONE_FS_H, ZONE_SS_Y, ZONE_SS_H,
      ZONE_OTC_Y, ZONE_OTC_H, STEP,
      COND_X, COND_Y, COND_W, COND_H,
      PESEE_X, PESEE_Y, PESEE_W, PESEE_H,
      loading, legend, zones,
      allNodes, arrows, selectedNode,
      stepLabels: STEP_LABELS,
      zoneColor, zoneLabel,
      nodeStatus, nodeColor, nodeStroke, nodeStrokeWidth, nodeDim, nodeIsFlux,
      activeLotCount, getNodeLots, selectNode,
      // Product flux
      productSearch, showSuggestions, productSuggestions, selectedProduct, activeRoute,
      onProductSearch, closeSuggestions, pickProduct, clearProduct, clearProductSearch, toggleRoute,
      // Modals
      modal, modalLotPreselect,
      closeModal, openStartModal, openStopModal, openCloseModal, openDevModal,
      searchModalLots, selectModalLot, removeLot, saveStart, saveStop, saveClose, saveDev,
      loadLive,
      // TRS overlay
      trsMode, trsLoading, trsColor, nodeTrs, trsSummary, loadTrsData, toggleTrsMode,
      // TRS LIVE
      trsPanels, trsShifts, trsEquipes, trsArretFamilles,
      trsClock, trsTimers, trsArretTimers, selectedTrsPanel,
      trsStartModal, trsArretModal, trsRequalModal, trsComptageModal, trsCloseModal,
      trsPanelColor, trsOeeClass, trsComputeObjShift, trsComputeCadence, trsComputeCadenceVsObj, trsComputeOEEPreview,
      loadTrsFull,
      trsOpenStart, trsSearchLots, trsSelectLot, trsDoStart,
      trsOpenArret, trsOnFamilleChange, trsOnSFChange, trsOnTypeChange, trsDoArret,
      trsClotureArret, trsOpenRequalif, trsOnRequalFamilleChange, trsOnRequalSFChange, trsDoRequalif,
      trsTheoCounters, trsCadenceModal, trsOpenCadence, trsDoChangeCadence,
      trsHistoModal, trsEquipes_list, openTrsHisto, loadTrsHistoData,
      trsOpenComptage, trsDoComptage,
      trsOpenClose, trsDoClose,
    }
  }
}
</script>

<style scoped>
/* ── Base ── */
.flow-page { display:flex; flex-direction:column; height:calc(100vh - 48px); background:#0a0a1e; overflow:hidden; margin:-16px -20px; font-family:'Inter',sans-serif; }

/* ── Header ── */
.flow-header { display:flex; align-items:center; justify-content:space-between; gap:12px; padding:8px 16px; background:#0f0f23; border-bottom:1px solid #1e1e3a; flex-shrink:0; }
.fh-title { font-size:12px; font-weight:800; letter-spacing:3px; color:#7c7cff; white-space:nowrap; }
.fh-sub   { font-size:10px; color:#4b5563; margin-top:2px; white-space:nowrap; }
.fh-center { flex:1; min-width:0; }
.fh-right { display:flex; align-items:center; gap:10px; flex-shrink:0; }
.fh-legend { display:flex; gap:10px; flex-wrap:wrap; }
.fl { display:flex; align-items:center; gap:4px; font-size:10px; color:#6b7280; }
.fl-dot { width:7px; height:7px; border-radius:50%; }
.fh-btn { width:30px; height:30px; border:1px solid #2a2a4a; border-radius:4px; background:transparent; color:#6b7280; cursor:pointer; font-size:15px; display:flex; align-items:center; justify-content:center; text-decoration:none; }
.fh-btn:hover { color:#fff; border-color:#4b5563; }
.fh-btn.spinning { animation: spin 1s linear infinite; }
.fh-btn-trs-on { background:#0f4c3a !important; border-color:#10b981 !important; color:#6ee7b7 !important; font-size:13px; }

/* ── TRS Bandeau ── */
.trs-band { display:flex; align-items:center; gap:20px; padding:6px 16px; background:#050f0a; border-bottom:1px solid #064e35; flex-shrink:0; }
.trs-band-label { font-size:10px; font-weight:800; letter-spacing:2px; color:#10b981; white-space:nowrap; }
.trs-kpi-group  { display:flex; align-items:center; gap:20px; flex:1; }
.trs-kpi        { display:flex; flex-direction:column; align-items:center; gap:1px; min-width:64px; }
.trs-kpi-val    { font-size:18px; font-weight:900; color:#e2e8f0; line-height:1; font-variant-numeric:tabular-nums; }
.trs-kpi-tot    { font-size:12px; color:#4b5563; font-weight:500; }
.trs-kpi-lbl    { font-size:9px; color:#4b5563; letter-spacing:0.5px; white-space:nowrap; }
.trs-kpi-main .trs-kpi-val { font-size:26px; }
.trs-band-refresh { width:28px; height:28px; border:1px solid #064e35; border-radius:4px; background:transparent; color:#10b981; cursor:pointer; font-size:14px; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
.trs-band-refresh:hover { background:#0d2e20; }
.trs-band-refresh.spinning { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

/* ── Product Search ── */
.prod-search-wrap { position:relative; display:flex; flex-direction:column; gap:6px; }
.psi-wrap { display:flex; align-items:center; gap:6px; background:#12122a; border:1px solid #2a2a4a; border-radius:6px; padding:4px 10px; }
.psi-icon { font-size:12px; color:#4b5563; }
.prod-input { flex:1; background:transparent; border:none; outline:none; color:#e2e8f0; font-size:12px; min-width:200px; }
.prod-input::placeholder { color:#374151; }
.psi-clear { background:none; border:none; color:#4b5563; cursor:pointer; font-size:12px; padding:0 2px; }
.psi-clear:hover { color:#9ca3af; }
.prod-dropdown { position:absolute; top:100%; left:0; right:0; background:#1a1a3e; border:1px solid #2a2a4a; border-radius:6px; z-index:100; max-height:260px; overflow-y:auto; box-shadow:0 8px 24px rgba(0,0,0,.6); margin-top:2px; }
.pd-item { display:flex; align-items:center; gap:8px; padding:7px 12px; cursor:pointer; font-size:11px; border-bottom:1px solid #1e1e3a; }
.pd-item:hover { background:#22224a; }
.pd-item:last-child { border-bottom:none; }
.pd-code { color:#7c7cff; font-weight:700; font-size:10px; min-width:80px; font-family:monospace; }
.pd-name { color:#d1d5db; flex:1; }
.pd-type { font-size:9px; font-weight:700; padding:2px 6px; border-radius:3px; background:#2a2a4a; color:#9ca3af; }
.pdt-COM_PELLI { background:#7c3aed22; color:#a78bfa; }
.pdt-COM_SEC   { background:#059669 22; color:#6ee7b7; }
.pdt-GLE       { background:#d9770622; color:#fcd34d; }
.pdt-CREME_POMMADE { background:#2563eb22; color:#93c5fd; }
.pdt-OTC       { background:#37415122; color:#9ca3af; }

.prod-chip { display:flex; align-items:center; gap:6px; background:#1a1a3e; border:1px solid #fbbf2444; border-radius:20px; padding:4px 10px; font-size:11px; }
.pc-name { color:#fbbf24; font-weight:600; max-width:260px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.pc-type { font-size:9px; font-weight:700; padding:2px 5px; border-radius:3px; }
.pct-COM_PELLI { background:#7c3aed33; color:#a78bfa; }
.pct-COM_SEC   { background:#05966933; color:#6ee7b7; }
.pct-GLE       { background:#d9770633; color:#fcd34d; }
.pct-CREME_POMMADE { background:#2563eb33; color:#93c5fd; }
.pct-OTC       { background:#37415133; color:#9ca3af; }
.pc-route { background:#fbbf2422; border:1px solid #fbbf2444; border-radius:4px; color:#fbbf24; cursor:pointer; font-size:10px; padding:1px 6px; font-weight:700; }
.pc-x { background:none; border:none; color:#4b5563; cursor:pointer; font-size:12px; }

/* ── SVG ── */
.flow-body { flex:1; overflow:hidden; position:relative; }
.flow-svg  { width:100%; height:100%; }
.flow-node { cursor:pointer; transition:opacity .2s; }
.flow-node:hover rect { filter:brightness(1.15); }

/* ── Detail Panel ── */
.detail-panel { position:absolute; right:0; top:0; bottom:0; width:280px; background:#0d0d26; border-left:1px solid #1e1e3a; display:flex; flex-direction:column; overflow-y:auto; z-index:50; }
.dp-hd { padding:14px 14px 10px; border-left:3px solid #7c7cff; margin:0; display:flex; justify-content:space-between; align-items:flex-start; }
.dp-code { font-size:22px; font-weight:900; color:#fff; font-family:monospace; line-height:1; }
.dp-nom  { font-size:11px; color:#9ca3af; margin-top:3px; }
.dp-zone { font-size:10px; color:#4b5563; margin-top:2px; }
.dp-close { background:none; border:none; color:#4b5563; cursor:pointer; font-size:14px; }
.dp-close:hover { color:#fff; }
.dp-status { display:flex; align-items:center; gap:8px; padding:8px 14px; margin:6px 12px; border-radius:6px; font-size:12px; }
.dp-st-icon { font-size:16px; }
.dp-st-label { color:#d1d5db; font-weight:600; }
.dp-section { padding:10px 14px; border-top:1px solid #1e1e3a; }
.dp-sec-title { font-size:9px; letter-spacing:2px; text-transform:uppercase; color:#4b5563; margin-bottom:8px; font-weight:700; }
.dp-empty { font-size:11px; color:#374151; font-style:italic; }
.dp-lot-row { display:flex; align-items:center; gap:6px; padding:5px 0; border-bottom:1px solid #1a1a3e; font-size:11px; }
.dp-lot-row:last-child { border-bottom:none; }
.dp-lot-num  { color:#7c7cff; font-weight:700; font-family:monospace; }
.dp-lot-prod { flex:1; color:#9ca3af; font-size:10px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.dp-lot-st   { font-size:9px; font-weight:700; padding:1px 5px; border-radius:3px; }
.ls-en.cours { background:#059669 22; color:#10b981; }
.ls-arrêt    { background:#ef444422; color:#ef4444; }
.ls-clôturé  { background:#37415122; color:#6b7280; }

.dp-actions-grid { display:grid; grid-template-columns:1fr 1fr; gap:6px; }
.dp-act-btn { padding:7px 6px; border:1px solid #2a2a4a; border-radius:5px; background:#12122a; color:#9ca3af; font-size:10px; font-weight:700; cursor:pointer; transition:all .15s; text-align:center; }
.dp-act-btn:hover:not(:disabled) { border-color:#6b7280; color:#fff; background:#1e1e3a; }
.dp-act-btn:disabled { opacity:0.3; cursor:not-allowed; }
.dp-act-start { border-color:#05966944; color:#10b981; }
.dp-act-start:hover:not(:disabled) { background:#05966911; border-color:#10b981; }
.dp-act-stop  { border-color:#ef444444; color:#ef4444; }
.dp-act-stop:hover:not(:disabled)  { background:#ef444411; border-color:#ef4444; }
.dp-act-close { border-color:#7c3aed44; color:#a78bfa; }
.dp-act-close:hover:not(:disabled) { background:#7c3aed11; border-color:#a78bfa; }
.dp-act-dev   { border-color:#f59e0b44; color:#f59e0b; }
.dp-act-dev:hover:not(:disabled)   { background:#f59e0b11; border-color:#f59e0b; }

.dp-flux-info { display:flex; align-items:center; gap:6px; font-size:11px; color:#fbbf24; }
.pct-badge { font-size:9px; padding:2px 5px; border-radius:3px; font-weight:700; }
.dp-route-tag { background:#fbbf2422; color:#fbbf24; border-radius:3px; padding:1px 5px; font-size:9px; }

/* ── Panel transition ── */
.panel-slide-enter-active, .panel-slide-leave-active { transition: transform .25s ease; }
.panel-slide-enter-from, .panel-slide-leave-to { transform: translateX(100%); }

/* ── Lot lot lot ── */
.ls-en\.cours { background:#05966922; color:#10b981; }

/* ── MODALS ── */
.modal-overlay { position:fixed; inset:0; background:rgba(0,0,0,.7); z-index:200; display:flex; align-items:center; justify-content:center; }
.modal-box { background:#0f0f26; border:1px solid #2a2a4a; border-radius:10px; width:420px; max-width:95vw; display:flex; flex-direction:column; box-shadow:0 24px 60px rgba(0,0,0,.8); }
.modal-hd { padding:16px 20px 12px; font-size:13px; font-weight:800; color:#e2e8f0; border-bottom:1px solid #1e1e3a; letter-spacing:.5px; }
.mh-code { color:#7c7cff; font-family:monospace; }
.modal-body { padding:16px 20px; display:flex; flex-direction:column; gap:12px; }
.mf-row { display:flex; flex-direction:column; gap:4px; }
.mf-row label { font-size:10px; color:#6b7280; letter-spacing:1px; text-transform:uppercase; font-weight:700; }
.mf-input { background:#12122a; border:1px solid #2a2a4a; border-radius:5px; color:#e2e8f0; font-size:12px; padding:8px 10px; outline:none; transition:border .15s; width:100%; box-sizing:border-box; }
.mf-input:focus { border-color:#7c7cff; }
.mf-ta { resize:vertical; min-height:70px; }
.mf-note { font-size:11px; color:#f59e0b; background:#f59e0b11; border-radius:4px; padding:7px 10px; }
.mf-err { font-size:11px; color:#ef4444; background:#ef444411; border-radius:4px; padding:6px 10px; }
.modal-ft { display:flex; justify-content:flex-end; gap:8px; padding:12px 20px; border-top:1px solid #1e1e3a; }
.mb-cancel { background:transparent; border:1px solid #2a2a4a; border-radius:5px; color:#6b7280; padding:7px 16px; font-size:12px; cursor:pointer; }
.mb-cancel:hover { color:#d1d5db; border-color:#4b5563; }
.mb-ok { background:#7c3aed; border:none; border-radius:5px; color:#fff; padding:7px 16px; font-size:12px; cursor:pointer; font-weight:700; }
.mb-ok:hover:not(:disabled) { background:#6d28d9; }
.mb-ok:disabled { opacity:.4; cursor:not-allowed; }
.mb-warn  { background:#b45309; }
.mb-warn:hover:not(:disabled)  { background:#92400e; }
.mb-green { background:#047857; }
.mb-green:hover:not(:disabled) { background:#065f46; }

.lot-search-wrap { position:relative; }
.lot-dropdown { position:absolute; top:100%; left:0; right:0; background:#1a1a3e; border:1px solid #2a2a4a; border-radius:6px; z-index:10; max-height:160px; overflow-y:auto; margin-top:2px; }
.ld-item { padding:7px 12px; font-size:11px; color:#d1d5db; cursor:pointer; border-bottom:1px solid #1e1e3a; }
.ld-item:hover { background:#22224a; }
.ld-item:last-child { border-bottom:none; }
.lot-chip { font-size:11px; color:#10b981; background:#05966911; border-radius:4px; padding:5px 10px; margin-top:4px; }
.mf-badge { display:inline-flex; align-items:center; justify-content:center; background:#7c3aed; color:#fff; font-size:10px; font-weight:800; border-radius:10px; min-width:18px; height:18px; padding:0 5px; margin-left:6px; }
.mf-hint { font-size:10px; color:#4b5563; margin-top:4px; font-style:italic; }
.ld-check { color:#10b981; font-weight:800; margin-left:6px; }
.lot-multi-list { display:flex; flex-direction:column; gap:3px; margin-top:6px; max-height:160px; overflow-y:auto; }
.lot-chip-multi { display:flex; align-items:center; gap:6px; background:#12124a; border:1px solid #2a2a5a; border-radius:5px; padding:5px 8px; }
.lcm-num { font-size:11px; font-weight:700; color:#a78bfa; white-space:nowrap; }
.lcm-desc { font-size:10px; color:#6b7280; flex:1; min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.lcm-rm { background:none; border:none; color:#4b5563; cursor:pointer; font-size:15px; line-height:1; padding:0 2px; flex-shrink:0; }
.lcm-rm:hover { color:#ef4444; }

/* ── TRS Start modal extras ── */
.trs-cad-real-row { margin-top:10px; padding-top:10px; border-top:1px solid #0d2e20; }
.trs-lbl-unit { font-size:9px; color:#4b5563; margin-left:4px; font-weight:400; }
.tdp-cad-fb { font-size:9px; color:#6b7280; font-style:italic; margin-left:2px; }
/* Bandeau TRS — bouton historique */
.trs-band-histo { background:rgba(255,255,255,.08); border:1px solid rgba(255,255,255,.15); color:#d1d5db; border-radius:4px; padding:6px 10px; cursor:pointer; font-size:14px; margin-left:6px; }
.trs-band-histo:hover { background:rgba(255,255,255,.16); }
/* Modal historique */
.trs-modal-lg { max-width:860px; width:95vw; }
.trs-histo-filters { display:flex; gap:12px; margin-bottom:14px; align-items:flex-end; flex-wrap:wrap; }
.trs-histo-wrap { overflow-x:auto; max-height:55vh; overflow-y:auto; border:1px solid #1f2937; border-radius:4px; }
.trs-histo-table { width:100%; border-collapse:collapse; font-size:12px; }
.trs-histo-table th { text-align:left; padding:8px 10px; background:#111827; color:#9ca3af; font-size:10px; text-transform:uppercase; letter-spacing:.5px; font-weight:600; white-space:nowrap; position:sticky; top:0; z-index:1; }
.trs-histo-table td { padding:8px 10px; border-bottom:1px solid #1f2937; color:#e5e7eb; white-space:nowrap; }
.trs-histo-table tr:last-child td { border-bottom:none; }
.trs-histo-table tr:hover td { background:rgba(255,255,255,.04); }
.trs-h-trs { font-weight:800; text-align:right; }
.trs-lbl-src  { font-size:9px; color:#10b981; margin-left:6px; }

/* ── Comptage théo/réel dans le panel TRS ── */
.tdp-comptage-bloc { border-top:1px solid #0d2e20; padding:10px 14px; }
.tdp-cad-line { display:flex; align-items:center; gap:5px; margin-bottom:8px; }
.tdp-cad-ic   { color:#10b981; font-size:13px; flex-shrink:0; }
.tdp-cad-val  { font-size:12px; font-weight:700; color:#d1fae5; }
.tdp-cad-col  { font-size:10px; color:#4b5563; }
.tdp-cad-edit { margin-left:auto; flex-shrink:0; background:none; border:1px solid #1e3a2e; color:#4b5563; border-radius:3px; cursor:pointer; font-size:11px; padding:1px 7px; }
.tdp-cad-edit:hover { color:#10b981; border-color:#10b981; }
.tdp-cpt-table { width:100%; }
.tdp-cpt-row  { display:grid; grid-template-columns:1fr 1fr 1fr; gap:2px; }
.tdp-cpt-hd .tdp-cpt-cell { font-size:9px; font-weight:800; letter-spacing:1px; color:#4b5563; padding:0 0 4px; }
.tdp-cpt-cell { font-size:12px; padding:3px 0; }
.tdp-cpt-lbl  { color:#6b7280; font-size:11px; }
.tdp-cpt-th   { text-align:center; color:#4b5563; }
.tdp-cpt-theo { color:#a78bfa; font-weight:700; font-family:monospace; font-size:14px; text-align:center; }
.tdp-cpt-reel { color:#10b981; font-weight:700; font-family:monospace; font-size:14px; text-align:center; }
.tdp-reminder { margin-top:8px; background:#3f1f0033; border:1px solid #f59e0b55; border-radius:5px; padding:6px 10px; font-size:10px; font-weight:800; color:#f59e0b; letter-spacing:.5px; animation:tdp-pulse 1.5s ease-in-out infinite; }
@keyframes tdp-pulse { 0%,100%{opacity:1} 50%{opacity:.55} }

/* ── TRS Detail Panel ── */
.trs-detail-panel { position:absolute; right:0; top:0; bottom:0; width:300px; background:#060f0a; border-left:1px solid #064e35; display:flex; flex-direction:column; overflow-y:auto; z-index:50; }
.tdp-hd { display:flex; justify-content:space-between; align-items:flex-start; padding:12px 14px 10px; border-left:3px solid #10b981; }
.tdp-hd-info .tdp-equip { font-size:20px; font-weight:900; color:#fff; font-family:monospace; line-height:1; }
.tdp-hd-info .tdp-nom   { font-size:10px; color:#4b5563; margin-top:3px; }
.tdp-right { display:flex; flex-direction:column; align-items:flex-end; gap:4px; }
.tdp-status { font-size:10px; font-weight:700; padding:3px 8px; border-radius:10px; letter-spacing:.5px; }
.tdp-clock  { font-size:11px; color:#10b981; font-family:monospace; font-weight:700; }
.tdp-close  { background:none; border:none; color:#4b5563; cursor:pointer; font-size:14px; }
.tdp-close:hover { color:#fff; }
.tdp-empty { padding:20px 14px; }
.tdp-empty-msg { font-size:11px; color:#374151; font-style:italic; }
.tdp-chips  { display:flex; flex-wrap:wrap; gap:5px; padding:8px 14px 0; }
.tdp-chip   { font-size:10px; font-weight:600; padding:2px 8px; border-radius:10px; border:1px solid transparent; }
.tdp-lot    { padding:8px 14px 0; }
.tdp-lot-num  { font-size:13px; font-weight:700; color:#6ee7b7; font-family:monospace; }
.tdp-lot-prod { font-size:10px; color:#4b5563; margin-top:2px; }
.tdp-no-session { padding:8px 14px; font-size:11px; color:#374151; font-style:italic; }
.tdp-timer  { padding:10px 14px; text-align:center; }
.tdp-timer-lbl { font-size:9px; letter-spacing:2px; color:#4b5563; font-weight:700; }
.tdp-timer-val { font-size:28px; font-weight:900; font-family:monospace; line-height:1.1; }
.tdp-arret-info { display:flex; align-items:center; gap:6px; justify-content:center; margin-top:4px; }
.tdp-arret-chip { font-size:10px; font-weight:700; padding:2px 7px; border-radius:4px; }
.tdp-arret-nom  { font-size:10px; color:#9ca3af; }
.tdp-metrics { display:grid; grid-template-columns:1fr 1fr 1fr 1fr; gap:4px; padding:8px 14px; }
.tdp-metric { text-align:center; background:#0a1a0f; border-radius:5px; padding:6px 4px; }
.tdp-metric-val { font-size:15px; font-weight:900; color:#e2e8f0; line-height:1; }
.tdp-metric-lbl { font-size:8px; color:#4b5563; margin-top:2px; }
.tdp-rend { display:flex; align-items:center; gap:8px; padding:4px 14px 6px; }
.tdp-rend-bar { flex:1; height:5px; background:#12122a; border-radius:3px; overflow:hidden; }
.tdp-rend-fill { height:100%; border-radius:3px; transition:width .3s; }
.tdp-rend-pct { font-size:11px; font-weight:700; min-width:36px; text-align:right; }
.tdp-oee { display:grid; grid-template-columns:1fr 1fr 1fr 1fr; gap:4px; padding:6px 14px 8px; border-top:1px solid #0a2a1a; border-bottom:1px solid #0a2a1a; }
.tdp-oee-item { text-align:center; background:#0a1a0f; border-radius:5px; padding:6px 2px; }
.tdp-oee-val  { font-size:14px; font-weight:900; line-height:1; }
.tdp-oee-lbl  { font-size:8px; color:#4b5563; margin-top:2px; font-weight:700; }
.oee-green { color:#10b981 !important; }
.oee-orange { color:#f59e0b !important; }
.oee-red    { color:#ef4444 !important; }
.tdp-actions { display:flex; flex-wrap:wrap; gap:5px; padding:8px 14px; }
.tdp-btn { flex:1; min-width:80px; padding:7px 6px; border-radius:5px; border:1px solid #1a3a28; background:#0a1a0f; color:#6ee7b7; font-size:10px; font-weight:700; cursor:pointer; transition:all .15s; }
.tdp-btn:hover:not(:disabled) { background:#0f2a1a; border-color:#10b981; color:#fff; }
.tdp-btn:disabled { opacity:.3; cursor:not-allowed; }
.tdp-btn-start  { border-color:#05966944; color:#10b981; }
.tdp-btn-start:hover:not(:disabled) { background:#05966922; }
.tdp-btn-stop   { border-color:#ef444444; color:#ef4444; }
.tdp-btn-stop:hover:not(:disabled)  { background:#ef444411; }
.tdp-btn-count  { border-color:#3b82f644; color:#60a5fa; }
.tdp-btn-close  { border-color:#7c3aed44; color:#a78bfa; }
.tdp-btn-resume { border-color:#10b98144; color:#10b981; }
.tdp-btn-requal { border-color:#f59e0b44; color:#f59e0b; }
.tdp-arrets { padding:6px 14px 10px; }
.tdp-arrets-title { font-size:9px; letter-spacing:2px; color:#4b5563; font-weight:700; margin-bottom:6px; }
.tdp-arret-row { display:flex; align-items:center; gap:5px; padding:4px 0; border-bottom:1px solid #0a2a1a; font-size:10px; }
.tdp-arret-row.running { background:#0f2a1a; border-radius:4px; padding:4px 4px; }
.tdp-arret-dot  { width:6px; height:6px; border-radius:50%; flex-shrink:0; }
.tdp-arret-code { color:#e2e8f0; font-weight:700; font-family:monospace; min-width:40px; }
.tdp-arret-name { flex:1; color:#6b7280; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.tdp-arret-dur  { color:#4b5563; white-space:nowrap; }

/* ── TRS Modals ── */
.trs-overlay { position:fixed; inset:0; background:rgba(0,0,0,.78); z-index:300; display:flex; align-items:center; justify-content:center; }
.trs-modal { background:#060f0a; border:1px solid #064e35; border-radius:10px; width:480px; max-width:96vw; max-height:90vh; overflow-y:auto; display:flex; flex-direction:column; gap:10px; padding:20px; box-shadow:0 24px 60px rgba(0,0,0,.9); }
.trs-modal-sm { width:380px; }
.trs-modal-hd { font-size:13px; font-weight:800; color:#e2e8f0; border-bottom:1px solid #0a2a1a; padding-bottom:10px; margin-bottom:2px; letter-spacing:.5px; }
.trs-modal-ctx { font-size:11px; color:#4b5563; }
.trs-lbl  { font-size:10px; color:#4b5563; letter-spacing:1px; text-transform:uppercase; font-weight:700; display:block; margin-bottom:3px; }
.trs-inp  { width:100%; background:#0a1a0f; border:1px solid #0d3a22; border-radius:5px; color:#e2e8f0; font-size:12px; padding:7px 10px; outline:none; box-sizing:border-box; }
.trs-inp:focus { border-color:#10b981; }
.trs-auto-wrap { position:relative; }
.trs-auto-list { position:absolute; top:100%; left:0; right:0; background:#0d2a1a; border:1px solid #0d3a22; border-radius:5px; z-index:10; max-height:160px; overflow-y:auto; margin-top:2px; }
.trs-auto-item { display:flex; align-items:center; gap:8px; padding:7px 10px; cursor:pointer; font-size:11px; border-bottom:1px solid #0a2a1a; }
.trs-auto-item:hover { background:#0f3a22; }
.trs-auto-code { color:#6ee7b7; font-weight:700; font-family:monospace; min-width:80px; }
.trs-auto-desc { color:#9ca3af; }
.trs-sel-lot { font-size:11px; color:#6ee7b7; background:#05966911; border-radius:4px; padding:5px 10px; }
.trs-form-row { display:flex; gap:10px; }
.trs-form-field { flex:1; display:flex; flex-direction:column; gap:3px; }
.trs-cad-preview, .trs-cad-calc { background:#0a1a0f; border-radius:5px; padding:8px 10px; display:flex; flex-direction:column; gap:4px; }
.trs-cp-row, .trs-cc-row { display:flex; justify-content:space-between; align-items:center; font-size:11px; }
.trs-cp-lbl { color:#4b5563; }
.trs-cp-val { color:#e2e8f0; font-weight:700; }
.trs-cp-obj { color:#6ee7b7; }
.trs-ok { color:#10b981; font-weight:700; }
.trs-bad { color:#ef4444; font-weight:700; }
.trs-cascade { display:flex; align-items:flex-end; gap:6px; }
.trs-cs-step { flex:1; }
.trs-cs-arrow { color:#4b5563; padding-bottom:8px; font-size:14px; }
.trs-type-preview { display:flex; align-items:center; gap:8px; padding:6px 10px; background:#0a1a0f; border-radius:5px; flex-wrap:wrap; }
.trs-code-chip { font-size:11px; font-weight:700; padding:2px 8px; border-radius:4px; }
.trs-prev-nom { font-size:11px; color:#e2e8f0; flex:1; }
.trs-tag { font-size:9px; font-weight:700; padding:1px 5px; border-radius:3px; }
.trs-tag-plan  { background:#3b82f622; color:#60a5fa; }
.trs-tag-pause { background:#10b98122; color:#6ee7b7; }
.trs-err { font-size:11px; color:#ef4444; background:#ef444411; border-radius:4px; padding:6px 10px; }
.trs-oee-preview { background:#0a1a0f; border-radius:6px; padding:10px; }
.trs-op-title { font-size:9px; letter-spacing:2px; color:#10b981; font-weight:700; margin-bottom:8px; }
.trs-op-grid  { display:grid; grid-template-columns:1fr 1fr 1fr 1fr; gap:6px; }
.trs-op-item  { text-align:center; }
.trs-op-val   { font-size:18px; font-weight:900; }
.trs-op-lbl   { font-size:9px; color:#4b5563; margin-top:2px; }
.trs-modal-acts { display:flex; justify-content:flex-end; gap:8px; padding-top:4px; }
.trs-btn-save   { background:#047857; border:none; border-radius:5px; color:#fff; padding:8px 16px; font-size:12px; cursor:pointer; font-weight:700; }
.trs-btn-save:hover:not(:disabled)   { background:#065f46; }
.trs-btn-save:disabled { opacity:.4; cursor:not-allowed; }
.trs-btn-go     { background:#047857; }
.trs-btn-stop   { background:#991b1b; }
.trs-btn-stop:hover:not(:disabled) { background:#7f1d1d; }
.trs-btn-cloture { background:#5b21b6; }
.trs-btn-cloture:hover:not(:disabled) { background:#4c1d95; }
.trs-btn-cancel { background:transparent; border:1px solid #0d3a22; border-radius:5px; color:#4b5563; padding:8px 16px; font-size:12px; cursor:pointer; }
.trs-btn-cancel:hover { color:#d1d5db; border-color:#4b5563; }

/* ══ RESPONSIVE MOBILE ══ */
@media(max-width:768px){
  /* Header : empiler le centre (recherche produit) */
  .flow-header { flex-wrap:wrap; gap:8px; }
  .fh-left { order:1; }
  .fh-center { order:3; width:100%; }
  .fh-right { order:2; }
  .fh-legend { display:none; }
  .fh-title { font-size:10px; letter-spacing:2px; }
  .fh-sub { display:none; }
  .prod-input { min-width:0; }

  /* TRS band scrollable horizontalement */
  .trs-band { overflow-x:auto; -webkit-overflow-scrolling:touch; gap:12px; }
  .trs-kpi-group { flex-shrink:0; }

  /* SVG : rendu scrollable au lieu d'être rétréci */
  .flow-body { overflow:auto; -webkit-overflow-scrolling:touch; }
  .flow-svg  { width:auto; height:auto; min-width:900px; min-height:560px; display:block; }

  /* Panneaux latéraux → drawer du bas */
  .detail-panel, .trs-detail-panel {
    position:fixed; bottom:0; left:0; right:0;
    top:auto; width:auto; height:55vh;
    border-left:none; border-top:1px solid #1e1e3a;
    z-index:80;
  }
  .trs-detail-panel { border-top-color:#064e35; }

  /* Métriques TRS dans le panel : 2 col au lieu de 4 */
  .tdp-metrics { grid-template-columns:1fr 1fr; }
  .tdp-oee     { grid-template-columns:1fr 1fr; }
  .trs-op-grid { grid-template-columns:1fr 1fr; }

  /* Form rows dans les modals TRS → empilés */
  .trs-form-row { flex-direction:column; }
  .trs-cascade  { flex-direction:column; gap:8px; }
  .trs-cs-arrow { transform:rotate(90deg); padding-bottom:0; align-self:center; }

  /* Boutons actions TRS */
  .trs-btn-save, .trs-btn-cancel, .mb-ok, .mb-cancel { min-height:44px; }
  .trs-modal-acts { flex-wrap:wrap; }
  .trs-btn-save, .trs-btn-cancel { flex:1; }

  /* Boutons dp-actions 2 col */
  .dp-actions-grid { grid-template-columns:1fr 1fr; }
  .tdp-btn { min-height:40px; }
}

@media(max-width:480px){
  .flow-svg { min-width:700px; min-height:440px; }
  .detail-panel, .trs-detail-panel { height:60vh; }
}

/* ══════════════════════════════════════════
   THÈME JOUR ☀️
══════════════════════════════════════════ */
.flow-page[data-theme="day"] { background: #f0f2f5; }
.flow-page[data-theme="day"] .flow-header { background: #ffffff; border-bottom-color: #d8dce8; }
.flow-page[data-theme="day"] .fh-title { color: #4a4aaa; }
.flow-page[data-theme="day"] .fh-sub   { color: #aaa; }
.flow-page[data-theme="day"] .fh-btn { border-color: #c8ccd8; color: #888; }
.flow-page[data-theme="day"] .fh-btn:hover { color: #333; border-color: #888; }
.flow-page[data-theme="day"] .fl { color: #888; }
.flow-page[data-theme="day"] .psi-wrap { background: #fff; border-color: #c8ccd8; }
.flow-page[data-theme="day"] .prod-input { color: #1a1a2e; }
.flow-page[data-theme="day"] .prod-input::placeholder { color: #bbb; }
.flow-page[data-theme="day"] .psi-icon { color: #aaa; }
.flow-page[data-theme="day"] .prod-dropdown { background: #fff; border-color: #c8ccd8; box-shadow: 0 8px 24px rgba(0,0,0,.1); }
.flow-page[data-theme="day"] .pd-item { border-bottom-color: #f0f0f0; }
.flow-page[data-theme="day"] .pd-item:hover { background: #f5f6f9; }
.flow-page[data-theme="day"] .pd-name { color: #333; }
.flow-page[data-theme="day"] .detail-panel { background: #fff; border-left-color: #d8dce8; }
.flow-page[data-theme="day"] .dp-nom  { color: #777; }
.flow-page[data-theme="day"] .dp-zone { color: #bbb; }
.flow-page[data-theme="day"] .dp-close { color: #bbb; }
.flow-page[data-theme="day"] .dp-close:hover { color: #333; }
.flow-page[data-theme="day"] .dp-section { border-top-color: #eee; }
.flow-page[data-theme="day"] .dp-sec-title { color: #aaa; }
.flow-page[data-theme="day"] .dp-lot-num { color: #1a1a2e; }
.flow-page[data-theme="day"] .dp-lot-prod { color: #888; }
.flow-page[data-theme="day"] .dp-empty { color: #ccc; }
/* TRS detail panel */
.flow-page[data-theme="day"] .trs-detail-panel { background: #fff; border-left-color: #d8dce8; }
/* SVG body */
.flow-page[data-theme="day"] .flow-body { background: #eef0f5; }
/* Modal */
.flow-page[data-theme="day"] .modal-overlay { background: rgba(0,0,0,.4); }
.flow-page[data-theme="day"] .modal-box { background: #fff; box-shadow: 0 16px 48px rgba(0,0,0,.2); }
.flow-page[data-theme="day"] .modal-hd { color: #1a1a2e; border-bottom-color: #eee; }
.flow-page[data-theme="day"] .mh-code { color: #185FA5; }
.flow-page[data-theme="day"] .modal-body { color: #444; }
.flow-page[data-theme="day"] .mf-row label { color: #888; }
.flow-page[data-theme="day"] .mf-input { background: #fff; border-color: #c8ccd8; color: #1a1a2e; }
.flow-page[data-theme="day"] .lot-dropdown { background: #fff; border-color: #c8ccd8; box-shadow: 0 4px 12px rgba(0,0,0,.1); }
.flow-page[data-theme="day"] .ld-item:hover { background: #f5f5f8; color: #1a1a2e; }
.flow-page[data-theme="day"] .modal-ft { border-top-color: #eee; }

/* ══════════════════════════════════════════
   THÈME ATELIER 🏭
══════════════════════════════════════════ */
.flow-page[data-theme="workshop"] { background: #161616; }
.flow-page[data-theme="workshop"] .flow-header { background: #0e0e0e; border-bottom-color: #2a2a2a; }
.flow-page[data-theme="workshop"] .fh-title { color: #8080ff; letter-spacing: 4px; }
.flow-page[data-theme="workshop"] .fh-sub   { color: #555; }
.flow-page[data-theme="workshop"] .fh-btn { border-color: #2a2a2a; color: #666; }
.flow-page[data-theme="workshop"] .fh-btn:hover { color: #fff; border-color: #555; }
.flow-page[data-theme="workshop"] .fl { color: #666; }
.flow-page[data-theme="workshop"] .psi-wrap { background: #1e1e1e; border-color: #2a2a2a; }
.flow-page[data-theme="workshop"] .prod-input { color: #f0f0f0; }
.flow-page[data-theme="workshop"] .prod-input::placeholder { color: #444; }
.flow-page[data-theme="workshop"] .psi-icon { color: #555; }
.flow-page[data-theme="workshop"] .prod-dropdown { background: #1c1c1c; border-color: #2a2a2a; box-shadow: 0 8px 24px rgba(0,0,0,.6); }
.flow-page[data-theme="workshop"] .pd-item { border-bottom-color: #1e1e1e; }
.flow-page[data-theme="workshop"] .pd-item:hover { background: #222; }
.flow-page[data-theme="workshop"] .pd-name { color: #e0e0e0; }
.flow-page[data-theme="workshop"] .detail-panel { background: #1a1a1a; border-left-color: #2a2a2a; }
.flow-page[data-theme="workshop"] .dp-nom  { color: #888; }
.flow-page[data-theme="workshop"] .dp-zone { color: #555; }
.flow-page[data-theme="workshop"] .dp-close { color: #555; }
.flow-page[data-theme="workshop"] .dp-close:hover { color: #fff; }
.flow-page[data-theme="workshop"] .dp-section { border-top-color: #2a2a2a; }
.flow-page[data-theme="workshop"] .dp-sec-title { color: #666; }
.flow-page[data-theme="workshop"] .dp-lot-num { color: #fff; font-weight:700; }
.flow-page[data-theme="workshop"] .dp-lot-prod { color: #777; }
.flow-page[data-theme="workshop"] .dp-empty { color: #444; }
.flow-page[data-theme="workshop"] .trs-detail-panel { background: #1a1a1a; border-left-color: #2a2a2a; }
.flow-page[data-theme="workshop"] .flow-body { background: #111; }
/* TRS bandeau */
.flow-page[data-theme="workshop"] .trs-band { background: #001a08; border-bottom-color: #00c85333; }
.flow-page[data-theme="workshop"] .trs-band-label { color: #00c853; }
/* Modal */
.flow-page[data-theme="workshop"] .modal-overlay { background: rgba(0,0,0,.7); }
.flow-page[data-theme="workshop"] .modal-box { background: #1c1c1c; border: 1px solid #2a2a2a; box-shadow: 0 24px 60px rgba(0,0,0,.8); }
.flow-page[data-theme="workshop"] .modal-hd { color: #fff; border-bottom-color: #2a2a2a; }
.flow-page[data-theme="workshop"] .mh-code { color: #ff9800; }
.flow-page[data-theme="workshop"] .modal-body { color: #e0e0e0; }
.flow-page[data-theme="workshop"] .mf-row label { color: #666; }
.flow-page[data-theme="workshop"] .mf-input { background: #111; border-color: #2a2a2a; color: #f0f0f0; }
.flow-page[data-theme="workshop"] .lot-dropdown { background: #1c1c1c; border-color: #2a2a2a; }
.flow-page[data-theme="workshop"] .ld-item:hover { background: #222; color: #fff; }
.flow-page[data-theme="workshop"] .modal-ft { border-top-color: #2a2a2a; }
</style>
