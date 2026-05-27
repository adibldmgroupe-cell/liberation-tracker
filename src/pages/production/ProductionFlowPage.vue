<template>
  <div class="flow-page">

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
          font-weight="700" letter-spacing="2" opacity="0.8">FORMES SEMI-SOLIDES / OTC</text>

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

        <rect :x="INJ_X" :y="INJ_Y" :width="INJ_W" :height="INJ_H"
          rx="12" fill="#db2777" opacity="0.06"/>
        <text :x="INJ_X+12" :y="INJ_Y+22" fill="#db2777" font-size="11"
          font-weight="700" letter-spacing="2" opacity="0.8">FORMES INJECTABLES</text>

        <!-- Cond Secondaire label -->
        <rect :x="COND_SEC_X" :y="COND_SEC_ZONE_Y" :width="COND_W" :height="COND_SEC_ZONE_H"
          rx="8" fill="#059669" opacity="0.04" stroke="#059669" stroke-opacity="0.15" stroke-width="1"/>
        <text :x="COND_SEC_X+COND_W/2" :y="COND_SEC_ZONE_Y+18" text-anchor="middle" fill="#059669"
          font-size="9" font-weight="700" letter-spacing="2" opacity="0.7">COND. SECONDAIRE</text>

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
          <!-- Barre statut -->
          <rect v-if="nodeStatus(node).label!=='Libre'"
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
          <!-- Dot statut -->
          <circle v-if="nodeStatus(node).label!=='Libre'"
            :cx="node.x+node.w-10" :cy="node.y+10" r="6"
            :fill="nodeStatus(node).color" stroke="rgba(255,255,255,.5)" stroke-width="1"
            filter="url(#glow)" :opacity="nodeDim(node)"/>
          <!-- Count lots -->
          <text v-if="activeLotCount(node)>0"
            :x="node.x+10" :y="node.y+12"
            fill="rgba(255,255,255,.8)" font-size="9" font-weight="700"
            :opacity="nodeDim(node)">
            {{activeLotCount(node)}}L
          </text>
          <!-- Flux badge -->
          <rect v-if="nodeIsFlux(node)"
            :x="node.x" :y="node.y" :width="node.w" :height="node.h"
            rx="8" fill="none" stroke="#fbbf24" stroke-width="2.5"/>

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
              <label>Numéro de lot</label>
              <div class="lot-search-wrap">
                <input class="mf-input" placeholder="Chercher lot..." v-model="modal.lotSearch"
                  @input="searchModalLots"/>
                <div class="lot-dropdown" v-if="modal.lotDropdown.length">
                  <div v-for="l in modal.lotDropdown" :key="l.id" class="ld-item"
                    @click="selectModalLot(l)">
                    <b>{{l.numero_lot}}</b> — {{l.products?.nom_produit||l.description||'—'}}
                  </div>
                </div>
              </div>
              <div v-if="modal.selectedLot" class="lot-chip">
                ✓ {{modal.selectedLot.numero_lot}} — {{modal.selectedLot.products?.nom_produit||'—'}}
              </div>
            </div>
            <div class="mf-row">
              <label>Date/heure début</label>
              <input class="mf-input" type="datetime-local" v-model="modal.dateDebut"/>
            </div>
            <div class="mf-row" v-if="modal.nodeType==='fab'">
              <label>Quantité</label>
              <input class="mf-input" type="number" v-model="modal.quantite" placeholder="Nb unités"/>
            </div>
            <div class="mf-err" v-if="modal.err">{{modal.err}}</div>
          </div>
          <div class="modal-ft">
            <button class="mb-cancel" @click="closeModal">Annuler</button>
            <button class="mb-ok" @click="saveStart" :disabled="modal.saving">
              {{modal.saving?'…':'▶ Démarrer'}}
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

  </div>
</template>

<script>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'

// ── LAYOUT CONSTANTS ──────────────────────────────────────────────
var SVG_W  = 1540
var SVG_H  = 960
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

// Conditionnement primaire column
var COND_X = TRACK_X + TRACKS_W + 30     // ~1070
var COND_Y = 30
var COND_W = 210
var COND_H = 640

// Conditionnement secondaire (below cond prim)
var COND_SEC_X        = COND_X
var COND_SEC_ZONE_Y   = 690
var COND_SEC_ZONE_H   = 160

// Injectable
var INJ_X = COND_X
var INJ_Y = 870
var INJ_W = COND_W
var INJ_H = 70

// Track Y positions
var T1Y = 100    // Gran01→Mél01→Comp01→Pellic01
var T2Y = 220    // Mél02→Comp03→Pellic03
var T2bY = 330   // Comp02 seul
var T3Y = 430    // Gran02→Mél03→Comp04→Pellic02
var T4Y = 545    // Formulation→Gélules
var T5Y = 700    // Semi-solides
var COND_PRIM_Y = 100   // première ligne cond prim
var COND_SEC_Y  = 720   // cond secondaire
var INJ_NODE_Y  = 895

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

  // ── CONDITIONNEMENT SECONDAIRE
  buildNode('c153', '153', 'Cond. Sec.',          'cond_secondaire', 'cond', 0, COND_SEC_Y,       COND_X+31),
  buildNode('c154', '154', 'Cond. Sec. Ext.',     'cond_secondaire', 'cond', 0, COND_SEC_Y + 80,  COND_X+31),

  // ── INJECTABLES
  buildNode('i521', '521', 'Réception Injectables','injectable', 'cond', 0, INJ_NODE_Y, COND_X+31),
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
  // Cond Prim → Cond Sec
  { id: 'a22', from: 'c149', to: 'c153' },
  { id: 'a23', from: 'c148', to: 'c153' },
  { id: 'a24', from: 'c147', to: 'c154' },
  { id: 'a25', from: 'c146', to: 'c154' },
  { id: 'a26', from: 'c220', to: 'c153' },
  { id: 'a27', from: 'c222', to: 'c154' },
  { id: 'a28', from: 'c223', to: 'c153' },
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
      if (trsMode.value) await loadTrsData()
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

    // ─── NODES enrichis ─────────────────────────────────────────
    var allNodes = computed(function() {
      return NODES_DEF.map(function(n) {
        var room = rooms.value.find(function(r) { return r.code === n.code })
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
            nom_produit: sf.lots?.products?.nom_produit || '',
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
        lotSearch: '', lotDropdown: [], selectedLot: null,
        dateDebut: now2, dateFin: now2,
        quantite: null, motif: '', fabId: '', lotId: '',
        description: '', nodeType: selectedNode.value?.type || 'fab'
      }
    }

    var openStartModal = function() {
      resetModal('start')
      // Pre-select lot if one was clicked in the list
      if (modalLotPreselect.value) {
        modal.value.selectedLot = modalLotPreselect.value
        modal.value.lotSearch = modalLotPreselect.value.numero_lot
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
        .select('id,numero_lot,description,products(nom_produit)')
        .ilike('numero_lot', '%'+q+'%')
        .limit(10)
      if (!res.error) modal.value.lotDropdown = res.data
    }

    var selectModalLot = function(l) {
      modal.value.selectedLot = l
      modal.value.lotSearch = l.numero_lot
      modal.value.lotDropdown = []
    }

    var saveStart = async function() {
      if (!modal.value.selectedLot) { modal.value.err = 'Sélectionner un lot.'; return }
      if (!selectedNode.value) return
      modal.value.saving = true; modal.value.err = ''
      var node = selectedNode.value
      var res
      if (node.type === 'cond' && node.equipement_id) {
        // Production session (cond)
        res = await supabase.from('production_sessions').insert({
          lot_id: modal.value.selectedLot.id,
          equipement_id: node.equipement_id,
          date: modal.value.dateDebut.slice(0, 10),
          heure_debut: modal.value.dateDebut.slice(11) + ':00',
          statut: 'En cours',
          colis_produits: 0, colis_rebuts: 0
        })
      } else if (node.atelier_id) {
        // Suivi fabrication (fab)
        // Get processus_id from ateliers
        var atRes = await supabase.from('ateliers').select('processus_id').eq('id', node.atelier_id).single()
        var processusId = atRes.data?.processus_id || null
        res = await supabase.from('suivi_fabrication').insert({
          lot_id: modal.value.selectedLot.id,
          atelier_id: node.atelier_id,
          processus_id: processusId,
          date_debut: modal.value.dateDebut || null,
          statut: 'En cours'
        })
      } else {
        modal.value.err = 'Atelier/équipement non configuré pour ce nœud.'
        modal.value.saving = false; return
      }
      modal.value.saving = false
      if (res.error) { modal.value.err = res.error.message; return }
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
        // Cond: insert production_arret
        res = await supabase.from('production_arrets').insert({
          session_id: modal.value.fabId,
          motif: modal.value.motif,
          is_running: true
        })
        if (!res.error) {
          await supabase.from('production_sessions').update({ statut: 'Arrêt' }).eq('id', modal.value.fabId)
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
      var res = await supabase.from('deviations').insert({
        lot_id: modal.value.lotId,
        description: modal.value.description,
        statut: 'ouverte',
        date_detection: new Date().toISOString()
      })
      modal.value.saving = false
      if (res.error) { modal.value.err = res.error.message; return }
      modal.value.open = false
      await loadLive()
    }

    // ─── LOAD ────────────────────────────────────────────────────
    var loadLive = async function() {
      loading.value = true
      var [r1, r2, r3, r4, r5, r6, r7] = await Promise.all([
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
        // Product flux summary (for search)
        supabase.from('v_product_flux_summary').select('*').order('product_name'),
        // Operations master (for flux mapping)
        supabase.from('operations_master').select('*'),
      ])
      if (!r1.error) rooms.value      = r1.data
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
      if (!r7.error) opMaster.value = r7.data
      loading.value = false
    }

    // ─── ACTIONS ─────────────────────────────────────────────────
    var selectNode = function(node) {
      selectedNode.value = node
      modalLotPreselect.value = null
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
      COND_SEC_X, COND_SEC_ZONE_Y, COND_SEC_ZONE_H,
      PESEE_X, PESEE_Y, PESEE_W, PESEE_H,
      INJ_X, INJ_Y, INJ_W, INJ_H,
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
      searchModalLots, selectModalLot, saveStart, saveStop, saveClose, saveDev,
      loadLive,
      // TRS
      trsMode, trsLoading, trsColor, nodeTrs, trsSummary, loadTrsData, toggleTrsMode,
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
</style>
