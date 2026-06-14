<template>
  <div class="trs-live" :data-theme="theme">
    <!-- ══ HEADER ══ -->
    <div class="ph">
      <div class="ph-left">
        <span class="pt">TRS LIVE</span>
        <span class="pt-clock">{{clock}}</span>
      </div>
      <div class="ph-right">
        <div class="site-tabs">
          <button v-for="s in ['Tous','PHARMA','OTC']" :key="s" class="site-tab" :class="{active:filterSite===s}" @click="filterSite=s">{{s}}</button>
        </div>
        <button class="btn-refresh" @click="loadAll" :class="{spinning:loading}" title="Rafraîchir"><NavIcon name="refresh" :size="14" /></button>
        <button class="btn-refresh" @click="cycleTheme" :title="themeTitle"><NavIcon :name="themeIcon" :size="15" /></button>
        <button class="btn-live-open" @click="openLiveView" title="Mode Live — affichage production plein écran"><NavIcon name="monitor" :size="14" /> Mode Live</button>
      </div>
    </div>

    <!-- ══ VUE MODE LIVE GÉANTE (plein écran production) ══ -->
    <div class="live-tv" v-if="liveView" :data-theme="theme">
      <div class="ltv-head">
        <div class="ltv-title"><NavIcon name="zap" :size="18" /> PRODUCTION&nbsp;LIVE</div>
        <div class="ltv-clock">{{clock}}</div>
        <button class="ltv-exit" @click="closeLiveView" title="Quitter (Échap)"><NavIcon name="x" :size="16" /></button>
      </div>
      <div class="ltv-body">
        <!-- Cartes machines -->
        <div class="ltv-cards" :style="liveGrid">
          <div v-for="p in liveCards" :key="p.equip.id"
               class="ltv-card"
               :class="{ 'ltv-stop': p.session.statut==='Arrêt'||p.session.statut==='Pause', 'ltv-win': p.rendPct>=100 }">
            <div class="ltv-card-hd">
              <span class="ltv-mach">{{p.equip.nom_equipement}}</span>
              <span class="ltv-eq" v-if="p.equipeNom" :style="{background:p.equipeCouleur+'22',color:p.equipeCouleur,borderColor:p.equipeCouleur+'66'}">{{p.equipeNom}}</span>
            </div>
            <div class="ltv-lot">{{p.lotNum}}<span v-if="p.lotProd && p.lotProd!=='—'" class="ltv-prod"> · {{p.lotProd}}</span></div>
            <div class="ltv-rend" :class="rendClass(p.rendPct)">{{p.rendPct}}<span class="ltv-pct">%</span></div>
            <div class="ltv-rend-lbl">RENDEMENT</div>
            <div class="ltv-nums">
              <div class="ltv-num"><b>{{sessBoites(p.session).toLocaleString('fr-FR')}}</b><span>réel</span></div>
              <div class="ltv-num" v-if="theoCounters[p.equip.id]"><b class="ltv-theo">{{theoCounters[p.equip.id].boites.toLocaleString('fr-FR')}}</b><span>théo</span></div>
              <div class="ltv-num"><b>{{(p.session.objectif_boites||0).toLocaleString('fr-FR')}}</b><span>objectif</span></div>
            </div>
            <div class="ltv-foot">
              <span class="ltv-status">{{p.session.statut}}</span>
              <span class="ltv-rec" v-if="lineRecords[p.equip.id]"><NavIcon name="award" :size="12" /> {{lineRecords[p.equip.id].boites.toLocaleString('fr-FR')}}</span>
            </div>
            <div class="ltv-arr" v-if="p.activeArret"><NavIcon name="ban" :size="13" /> {{p.activeArret.arret_code}} — {{p.activeArret.arret_nom||p.activeArret.famille_nom}}</div>
            <div class="ltv-win-badge" v-if="p.rendPct>=100">🎉 OBJECTIF DÉPASSÉ</div>
          </div>
          <div v-if="!liveCards.length" class="ltv-empty">Aucune machine en production</div>
        </div>
        <!-- Classement équipes + records -->
        <div class="ltv-side">
          <div class="ltv-rank">
            <div class="ltv-rank-hd"><NavIcon name="award" :size="14" /> ÉQUIPES — MOIS</div>
            <div v-for="(t,i) in teamRankMonth.slice(0,5)" :key="'m'+t.equipe_id" class="ltv-rank-row" :class="{first:i===0}">
              <span class="ltv-medal">{{['🥇','🥈','🥉'][i]||(i+1)}}</span>
              <span class="ltv-team" :style="{color:t.couleur}">{{t.nom}}</span>
              <span class="ltv-team-rend" :class="rendClass(t.rendement)">{{t.rendement}}%</span>
            </div>
            <div v-if="!teamRankMonth.length" class="ltv-rank-empty">— pas encore de données —</div>
          </div>
          <div class="ltv-rank">
            <div class="ltv-rank-hd">👑 ÉQUIPES — ANNÉE</div>
            <div v-for="(t,i) in teamRankYear.slice(0,5)" :key="'y'+t.equipe_id" class="ltv-rank-row" :class="{first:i===0}">
              <span class="ltv-medal">{{['🥇','🥈','🥉'][i]||(i+1)}}</span>
              <span class="ltv-team" :style="{color:t.couleur}">{{t.nom}}</span>
              <span class="ltv-team-rend" :class="rendClass(t.rendement)">{{t.rendement}}%</span>
            </div>
            <div v-if="!teamRankYear.length" class="ltv-rank-empty">— pas encore de données —</div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="loading && !panels.length" class="loading-msg">Chargement…</div>

    <!-- ══ TABLE ══ -->
    <div class="trs-scroller" v-else>
      <div class="trs-table">

        <!-- En-tête colonnes -->
        <div class="trs-thead">
          <div class="th">Machine</div>
          <div class="th">Shift / Équipe</div>
          <div class="th">Lot</div>
          <div class="th">Statut</div>
          <div class="th th-c"><NavIcon name="clock" :size="13" /> Durée</div>
          <div class="th th-c">Boîtes / Obj.</div>
          <div class="th th-c">b/min</div>
          <div class="th th-c">D%</div>
          <div class="th th-c">P%</div>
          <div class="th th-c">Q%</div>
          <div class="th th-c th-trs-h">TRS%</div>
          <div class="th">Actions</div>
        </div>

        <!-- Lignes -->
        <div v-for="p in filteredPanels" :key="p.equip.id" class="trs-row-group">

          <!-- Ligne principale -->
          <div class="trs-row" :style="{'border-left-color': panelColor(p)}">

            <!-- Machine -->
            <div class="td">
              <div class="mach-name">{{p.equip.nom_equipement}}</div>
              <div class="mach-site">{{p.equip.site}}</div>
            </div>

            <!-- Shift / Équipe -->
            <div class="td td-chips">
              <span v-if="p.shiftNom" class="chip" :style="{background:p.shiftCouleur+'22',color:p.shiftCouleur}">{{p.shiftNom}}</span>
              <span v-if="p.equipeNom" class="chip" :style="{background:p.equipeCouleur+'22',color:p.equipeCouleur}">{{p.equipeNom}}</span>
              <span v-if="!p.shiftNom && !p.equipeNom" class="dim">—</span>
            </div>

            <!-- Lot -->
            <div class="td td-lot">
              <template v-if="p.session">
                <div class="lot-n">{{p.lotNum}}</div>
                <div class="lot-p">{{p.lotProd}}</div>
              </template>
              <span class="dim" v-else>—</span>
            </div>

            <!-- Statut + arrêt actif -->
            <div class="td td-stat">
              <div class="stat-pill" :style="{color:panelColor(p),borderColor:panelColor(p)+'44',background:panelColor(p)+'15'}">
                <span class="stat-dot" :style="{background:panelColor(p)}"></span>
                {{p.session ? p.session.statut : 'Disponible'}}
              </div>
              <div class="arret-mini" v-if="p.activeArret">
                <span class="ac" :style="{color:p.activeArret.couleur||'#ef4444'}">{{p.activeArret.arret_code||'?'}}</span>
                <span class="an">{{p.activeArret.arret_nom||p.activeArret.famille_nom||'—'}}</span>
              </div>
            </div>

            <!-- Durée -->
            <div class="td td-c">
              <div class="tmr mono" :style="{color:panelColor(p)}" v-if="p.session">
                {{p.session.statut === 'En cours' ? (timers[p.equip.id]||'00:00:00') : (p.activeArret ? (arretTimers[p.activeArret.id]||'00:00:00') : '—')}}
              </div>
              <span class="dim" v-else>—</span>
            </div>

            <!-- Boîtes / Objectif -->
            <div class="td td-c td-prod">
              <template v-if="p.session">
                <div class="prod-nums">
                  <span class="pv mono">{{sessBoites(p.session).toLocaleString('fr-FR')}}</span>
                  <span class="dim">/</span>
                  <span class="po mono dim">{{p.session.objectif_boites||'—'}}</span>
                </div>
                <div class="theo-row mono" v-if="theoCounters[p.equip.id]" title="Compteur théorique automatique (cadence × temps net hors arrêts)">
                  <span class="theo-lbl">théo</span> {{theoCounters[p.equip.id].boites.toLocaleString('fr-FR')}}
                </div>
                <template v-if="p.session.objectif_boites">
                  <div class="rend-bar">
                    <div class="rend-fill" :style="{width:Math.min(p.rendPct,100)+'%',background:p.rendPct>=100?'#10b981':p.rendPct>=80?'#f59e0b':'#ef4444'}"></div>
                  </div>
                  <div class="rend-pct mono" :class="p.rendPct>=100?'clr-g':p.rendPct>=80?'clr-o':'clr-r'">{{p.rendPct}}%</div>
                </template>
              </template>
              <span class="dim" v-else>—</span>
            </div>

            <!-- b/min -->
            <div class="td td-c">
              <template v-if="p.session">
                <div class="cad-r mono clr-b">{{p.session.cadence_reelle_boite_min!=null?p.session.cadence_reelle_boite_min:'—'}}</div>
                <div class="cad-o mono dim">/{{p.session.cadence_objectif_snapshot||'—'}}</div>
              </template>
              <span class="dim" v-else>—</span>
            </div>

            <!-- D% -->
            <div class="td td-c">
              <span class="oee-n mono" :class="oeeClass(p.session.disponibilite)" v-if="p.session">{{p.session.disponibilite!=null?p.session.disponibilite+'%':'—'}}</span>
              <span class="dim" v-else>—</span>
            </div>

            <!-- P% -->
            <div class="td td-c">
              <span class="oee-n mono" :class="oeeClass(p.session.performance)" v-if="p.session">{{p.session.performance!=null?p.session.performance+'%':'—'}}</span>
              <span class="dim" v-else>—</span>
            </div>

            <!-- Q% -->
            <div class="td td-c">
              <span class="oee-n mono" :class="oeeClass(p.session.qualite)" v-if="p.session">{{p.session.qualite!=null?p.session.qualite+'%':'—'}}</span>
              <span class="dim" v-else>—</span>
            </div>

            <!-- TRS% -->
            <div class="td td-c td-trs-c">
              <span class="trs-n mono" :class="oeeClass(p.session.trs)" v-if="p.session">{{p.session.trs!=null?p.session.trs+'%':'—'}}</span>
              <span class="dim" v-else>—</span>
            </div>

            <!-- Actions -->
            <div class="td td-act">
              <template v-if="!p.session">
                <button class="ab ab-start" @click="openStartModal(p.equip)"><NavIcon name="play" :size="13" /> Démarrer</button>
              </template>
              <template v-else-if="p.session.statut === 'En cours'">
                <button class="ab ab-stp" @click="openArretModal(p)" title="Déclarer arrêt"><NavIcon name="pause" :size="13" /></button>
                <button class="ab ab-cnt" @click="openComptageModal(p)" title="Comptage">+</button>
                <button class="ab ab-dev" @click="openDevModal(p)" title="Déclarer déviation"><NavIcon name="alert-triangle" :size="13" /></button>
                <button class="ab ab-cls" @click="openCloseModal(p)" title="Clôturer"><NavIcon name="check" :size="13" /></button>
              </template>
              <template v-else-if="p.session.statut === 'Arrêt' || p.session.statut === 'Pause'">
                <button class="ab ab-rsm" @click="clotureArret(p)"><NavIcon name="play" :size="13" /> Reprendre</button>
                <button class="ab ab-req" @click="openRequalifModal(p)" v-if="p.activeArret"><NavIcon name="pencil" :size="13" /></button>
              </template>
            </div>
          </div>

          <!-- Sous-ligne arrêts du shift -->
          <div class="arrets-sub" v-if="p.session && p.arrets && p.arrets.length">
            <span class="arrets-sub-lbl">Arrêts shift :</span>
            <span v-for="a in p.arrets" :key="a.id" class="arret-tag" :class="{'ar-run':a.is_running}" :style="{borderColor:(a.couleur||'#ef4444')+'44',color:a.couleur||'#ef4444'}">
              <span class="at-code">{{a.arret_code||'—'}}</span>
              <span class="at-nom">{{a.arret_nom||a.famille_nom||'—'}}</span>
              <span class="at-dur">{{a.is_running?'⏱ en cours':(a.duree_minutes?a.duree_minutes+'min':'—')}}</span>
            </span>
          </div>

        </div><!-- /row-group -->
      </div><!-- /trs-table -->
    </div><!-- /trs-scroller -->


    <!-- ══ MODAL DÉMARRER SESSION ══ -->
    <div class="overlay" v-if="startModal.show" @click.self="startModal.show=false">
      <div class="modal">
        <div class="modal-hd"><NavIcon name="play" :size="16" /> Démarrer une session — {{startModal.equip?.nom_equipement}}</div>

        <label class="lbl">N° Lot *</label>
        <div class="auto-wrap">
          <input v-model="startModal.lotSearch" class="inp" placeholder="Rechercher numéro de lot…" @input="searchLots" />
          <div class="auto-list" v-if="startModal.lotSuggestions.length">
            <div v-for="l in startModal.lotSuggestions" :key="l.id" class="auto-item" @mousedown.prevent="selectLot(l)">
              <span class="auto-code">{{l.numero_lot}}</span>
              <span class="auto-desc">{{l.code_article}} — {{l.description}}</span>
            </div>
          </div>
        </div>
        <div class="selected-lot" v-if="startModal.lot">
          <NavIcon name="check" :size="13" /> Lot <strong>{{startModal.lot.numero_lot}}</strong> — {{startModal.lot.description}}
        </div>

        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Shift</label>
            <select v-model="startModal.shift_id" class="inp">
              <option :value="null">— Aucun —</option>
              <option v-for="s in shifts" :key="s.id" :value="s.id">{{s.nom}} ({{s.heure_debut.slice(0,5)}}→{{s.heure_fin.slice(0,5)}})</option>
            </select>
          </div>
          <div class="form-field">
            <label class="lbl">Équipe</label>
            <select v-model="startModal.equipe_id" class="inp">
              <option :value="null">— Aucune —</option>
              <option v-for="e in equipes" :key="e.id" :value="e.id">{{e.nom}}</option>
            </select>
          </div>
        </div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Date</label>
            <input type="date" v-model="startModal.date" class="inp" />
          </div>
          <div class="form-field">
            <label class="lbl">Heure début</label>
            <input type="time" v-model="startModal.heure_debut" class="inp" step="60" />
          </div>
        </div>

        <div class="cadence-preview" v-if="startModal.equip">
          <!-- Type de transition détecté -->
          <div class="cp-row" v-if="startModal.lot">
            <span class="cp-lbl">Type transition</span>
            <span class="cp-val" :class="startModal.isPremierCampagne ? 'cp-warn' : startModal.hasVdlp ? '' : 'obj'">
              {{startModal.isPremierCampagne ? '🆕 Nouvelle campagne (VDLC + format + réglage)' : startModal.hasVdlp ? '🔄 Lot suivant — même campagne (VDLP)' : '▶ Premier lancement (aucun arrêt de changement)'}}
            </span>
          </div>
          <div class="cp-row">
            <span class="cp-lbl">Cadence objectif (GS)</span>
            <span class="cp-val obj">{{startModal.cadenceObj || '—'}} b/min</span>
          </div>
          <div class="cp-row">
            <span class="cp-lbl">TO référence (GS)</span>
            <span class="cp-val">{{startModal.equip.to_shift_ref || '—'}} min</span>
          </div>
          <div class="cp-row">
            <span class="cp-lbl">Pause</span>
            <span class="cp-val">{{startModal.equip.pause_ref || 0}} min</span>
          </div>
          <div class="cp-row" v-if="startModal.hasVdlp">
            <span class="cp-lbl">VDLP</span>
            <span class="cp-val">{{startModal.equip.vdlp_ref || 0}} min</span>
          </div>
          <div class="cp-row" v-if="startModal.isPremierCampagne">
            <span class="cp-lbl">VDLC</span>
            <span class="cp-val">{{startModal.equip.vdlc_ref || 0}} min</span>
          </div>
          <div class="cp-row" v-if="startModal.isPremierCampagne">
            <span class="cp-lbl">Chgt format</span>
            <span class="cp-val">{{startModal.equip.chgt_format_ref || 0}} min</span>
          </div>
          <div class="cp-row" v-if="startModal.isPremierCampagne">
            <span class="cp-lbl">Réglage lancement</span>
            <span class="cp-val">{{startModal.equip.reglage_ref || 0}} min</span>
          </div>
          <div class="cp-row">
            <span class="cp-lbl">Micro-arrêts (proportionnel)</span>
            <span class="cp-val">{{modalMicro}} min</span>
          </div>
          <div class="cp-row">
            <span class="cp-lbl">Temps net production</span>
            <span class="cp-val obj">{{gsNetRef(startModal.equip, modalOpts)}} min</span>
          </div>
          <div class="cp-row" v-if="startModal.cadenceObj">
            <span class="cp-lbl">Objectif / shift</span>
            <span class="cp-val obj">{{computeObjShift(startModal)}} boîtes</span>
          </div>
        </div>

        <div class="err" v-if="startModal.error">{{startModal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save btn-go" @click="doStart" :disabled="startModal.saving || !startModal.lot">
            <template v-if="startModal.saving">Démarrage…</template><template v-else><NavIcon name="play" :size="14" /> Démarrer</template>
          </button>
          <button class="btn-cancel" @click="startModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL DÉCLARER ARRÊT ══ -->
    <div class="overlay" v-if="arretModal.show" @click.self="arretModal.show=false">
      <div class="modal">
        <div class="modal-hd"><NavIcon name="pause" :size="16" /> Déclarer un arrêt — {{arretModal.panel?.equip.nom_equipement}}</div>

        <div class="cascade-selects">
          <div class="cs-step">
            <label class="lbl">Famille *</label>
            <select v-model="arretModal.famille_id" class="inp" @change="onFamilleChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="f in arretFamilles" :key="f.id" :value="f.id">{{f.nom}}</option>
            </select>
          </div>
          <div class="cs-arrow">→</div>
          <div class="cs-step">
            <label class="lbl">Sous-famille *</label>
            <select v-model="arretModal.sf_id" class="inp" :disabled="!arretModal.famille_id" @change="onSFChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="sf in arretModal.sousFamilles" :key="sf.id" :value="sf.id">{{sf.nom}}</option>
            </select>
          </div>
          <div class="cs-arrow">→</div>
          <div class="cs-step">
            <label class="lbl">Code arrêt *</label>
            <select v-model="arretModal.type_id" class="inp" :disabled="!arretModal.sf_id" @change="onTypeChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="t in arretModal.types" :key="t.id" :value="t.id">{{t.code}} — {{t.nom}}</option>
            </select>
          </div>
        </div>

        <div class="type-preview" v-if="arretModal.selectedType">
          <span class="arret-code-chip" :style="{background:(arretModal.selectedType.couleur||arretModal.familleCouleur)+'22', color:arretModal.selectedType.couleur||arretModal.familleCouleur, borderColor:(arretModal.selectedType.couleur||arretModal.familleCouleur)+'55'}">
            {{arretModal.selectedType.code}}
          </span>
          <span class="type-prev-nom">{{arretModal.selectedType.nom}}</span>
          <span class="tag tag-plan" v-if="arretModal.selectedType.est_planifie">Planifié</span>
          <span class="tag tag-pause" v-if="arretModal.selectedType.est_pause">Pause</span>
          <span class="tag tag-dur" v-if="arretModal.selectedType.duree_std_min">~{{arretModal.selectedType.duree_std_min}} min</span>
        </div>

        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Heure début arrêt</label>
            <input type="time" v-model="arretModal.heure_debut" class="inp" step="60" />
          </div>
        </div>
        <label class="lbl">Commentaire</label>
        <input v-model="arretModal.commentaire" class="inp" placeholder="Optionnel…" />

        <div class="err" v-if="arretModal.error">{{arretModal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save btn-stop" @click="doArret" :disabled="arretModal.saving || !arretModal.type_id">
            <template v-if="arretModal.saving">Enregistrement…</template><template v-else><NavIcon name="pause" :size="14" /> Démarrer chrono arrêt</template>
          </button>
          <button class="btn-cancel" @click="arretModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL REQUALIFIER ARRÊT ══ -->
    <div class="overlay" v-if="requalModal.show" @click.self="requalModal.show=false">
      <div class="modal modal-sm">
        <div class="modal-hd"><NavIcon name="pencil" :size="16" /> Requalifier l'arrêt en cours</div>
        <div class="modal-ctx">{{requalModal.panel?.equip.nom_equipement}} — arrêt actif</div>

        <div class="cascade-selects" style="flex-direction:column;gap:8px">
          <div>
            <label class="lbl">Famille</label>
            <select v-model="requalModal.famille_id" class="inp" @change="onRequalFamilleChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="f in arretFamilles" :key="f.id" :value="f.id">{{f.nom}}</option>
            </select>
          </div>
          <div>
            <label class="lbl">Sous-famille</label>
            <select v-model="requalModal.sf_id" class="inp" :disabled="!requalModal.famille_id" @change="onRequalSFChange">
              <option :value="null">— Sélectionner —</option>
              <option v-for="sf in requalModal.sousFamilles" :key="sf.id" :value="sf.id">{{sf.nom}}</option>
            </select>
          </div>
          <div>
            <label class="lbl">Code arrêt</label>
            <select v-model="requalModal.type_id" class="inp" :disabled="!requalModal.sf_id">
              <option :value="null">— Sélectionner —</option>
              <option v-for="t in requalModal.types" :key="t.id" :value="t.id">{{t.code}} — {{t.nom}}</option>
            </select>
          </div>
        </div>
        <div class="modal-acts">
          <button class="btn-save" @click="doRequalif" :disabled="requalModal.saving || !requalModal.type_id">{{requalModal.saving?'…':'Requalifier'}}</button>
          <button class="btn-cancel" @click="requalModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL COMPTAGE ══ -->
    <div class="overlay" v-if="comptageModal.show" @click.self="comptageModal.show=false">
      <div class="modal modal-sm">
        <div class="modal-hd">+ Saisie comptage — {{comptageModal.panel?.equip.nom_equipement}}</div>
        <div class="modal-ctx" v-if="comptageModal.panel?.session">
          Session en cours · Boîtes actuelles :
          <strong>{{sessBoites(comptageModal.panel.session).toLocaleString('fr-FR')}}</strong>
        </div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Heure relevé</label>
            <input type="time" v-model="comptageModal.heure" class="inp" step="60" />
          </div>
          <div class="form-field">
            <label class="lbl">Boîtes cumulées *</label>
            <input type="number" v-model.number="comptageModal.boites" class="inp" placeholder="ex: 1250" min="0" />
          </div>
        </div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Boîtes rebuts cumulées</label>
            <input type="number" v-model.number="comptageModal.rebuts" class="inp" placeholder="0" min="0" />
          </div>
        </div>

        <div class="cadence-calc" v-if="comptageModal.panel?.session && comptageModal.boites">
          <div class="cc-row">
            <span class="cc-lbl">Cadence calculée</span>
            <span class="cc-val">{{computeCadence(comptageModal)}} boîtes/min</span>
          </div>
          <div class="cc-row">
            <span class="cc-lbl">vs objectif</span>
            <span class="cc-val" :class="computeCadenceVsObj(comptageModal) >= 100 ? 'ok' : 'bad'">
              {{computeCadenceVsObj(comptageModal)}}%
            </span>
          </div>
        </div>

        <div class="modal-acts">
          <button class="btn-save" @click="doComptage" :disabled="comptageModal.saving || !comptageModal.boites">
            {{comptageModal.saving ? '…' : 'Enregistrer'}}
          </button>
          <button class="btn-cancel" @click="comptageModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL CLÔTURER SESSION ══ -->
    <div class="overlay" v-if="closeModal.show" @click.self="closeModal.show=false">
      <div class="modal">
        <div class="modal-hd"><NavIcon name="check" :size="16" /> Clôturer la session — {{closeModal.panel?.equip.nom_equipement}}</div>
        <div class="modal-ctx" v-if="closeModal.panel?.session">
          Lot {{closeModal.panel.lotNum}} · Démarré à {{closeModal.panel.session.heure_debut}}
        </div>

        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Heure fin *</label>
            <input type="time" v-model="closeModal.heure_fin" class="inp" step="60" />
          </div>
          <div class="form-field">
            <label class="lbl">Boîtes produites final *</label>
            <input type="number" v-model.number="closeModal.boites_produits" class="inp" min="0" />
          </div>
        </div>
        <div class="form-row">
          <div class="form-field">
            <label class="lbl">Boîtes rebuts</label>
            <input type="number" v-model.number="closeModal.boites_rebuts" class="inp" min="0" />
          </div>
        </div>
        <label class="lbl">Observation</label>
        <input v-model="closeModal.observation" class="inp" placeholder="Optionnel…" />

        <div class="oee-preview" v-if="closeModal.panel && closeModal.heure_fin && closeModal.boites_produits">
          <div class="op-title">OEE estimé à la clôture</div>
          <div class="op-grid">
            <div class="op-item" v-for="item in computeOEEPreview(closeModal)" :key="item.label">
              <div class="op-val" :class="oeeClass(item.val)">{{item.val != null ? item.val+'%' : '—'}}</div>
              <div class="op-lbl">{{item.label}}</div>
            </div>
          </div>
        </div>

        <div class="err" v-if="closeModal.error">{{closeModal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save btn-close-sess" @click="doClose" :disabled="closeModal.saving || !closeModal.heure_fin">
            <template v-if="closeModal.saving">Clôture…</template><template v-else><NavIcon name="check" :size="14" /> Clôturer et calculer OEE</template>
          </button>
          <button class="btn-cancel" @click="closeModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL DÉCLARER DÉVIATION ══ -->
    <div class="overlay" v-if="devModal.show" @click.self="devModal.show=false">
      <div class="modal">
        <div class="modal-hd"><NavIcon name="alert-triangle" :size="16" /> Déclarer déviation — {{devModal.panel?.equip.nom_equipement}}</div>
        <div class="modal-ctx" v-if="devModal.panel?.session">
          Lot {{devModal.panel.lotNum}} · Session en cours
        </div>
        <div class="dev-form">
          <div class="dev-form-row">
            <label class="dev-lbl">N° DN</label>
            <input type="text" v-model="devModal.numeroDn" placeholder="Ex: DN-2026-001" class="dev-input-sm" />
          </div>
          <div class="dev-form-row">
            <label class="dev-lbl">Observation</label>
            <textarea v-model="devModal.description" rows="2" placeholder="Observation (facultatif)..." class="dev-input"></textarea>
          </div>
          <div class="dev-form-row dev-bloquante-row">
            <label class="dev-lbl">Bloquante</label>
            <button class="dev-tog" :class="devModal.bloquante?'dev-tog-on':'dev-tog-off'" @click="devModal.bloquante=!devModal.bloquante">
              {{devModal.bloquante ? 'Oui — Bloquante' : 'Non — Non bloquante'}}
            </button>
          </div>
        </div>
        <div class="err" v-if="devModal.error">{{devModal.error}}</div>
        <div class="modal-acts">
          <button class="btn-save btn-warn" @click="doSaveDev" :disabled="devModal.saving">
            {{devModal.saving ? '…' : 'Confirmer'}}
          </button>
          <button class="btn-cancel" @click="devModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

  </div>
</template>

<script>
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../../supabase'
import { useTheme } from '../../composables/useTheme'
import { declareDeviation } from '../../services/actions'
import { checkProductFluxEquipName } from '../../services/flux'
import { loadPermissions, canPerform } from '../../services/permissions'
import NavIcon from '../../components/NavIcon.vue'

export default {
  components: { NavIcon },
  setup() {
    var { theme } = useTheme()
    var panels        = ref([])
    var shifts        = ref([])
    var equipes       = ref([])
    var arretFamilles = ref([])
    var loading       = ref(false)
    var gsCadences    = ref([])
    var clock         = ref('')
    var filterSite    = ref('Tous')
    var timers        = ref({})
    var arretTimers   = ref({})
    var theoCounters  = ref({})   // compteur théorique temps réel (parité avec le Schéma) : { boites, colis, currentCadence }
    var clockInt      = null
    var refreshInt    = null
    var autoStopInt   = null
    var autoClosing   = {}
    var lotSearchTimeout = null

    // ── Modals ──
    var startModal    = reactive({ show:false, equip:null, lotSearch:'', lotSuggestions:[], lot:null, shift_id:null, equipe_id:null, date:'', heure_debut:'', cadenceObj:null, colisage:null, colisageSrc:'', isPremierCampagne:false, hasVdlp:false, error:'', saving:false })
    var arretModal    = reactive({ show:false, panel:null, famille_id:null, sf_id:null, type_id:null, sousFamilles:[], types:[], selectedType:null, familleCouleur:'#EF4444', heure_debut:'', commentaire:'', error:'', saving:false })
    var requalModal   = reactive({ show:false, panel:null, famille_id:null, sf_id:null, type_id:null, sousFamilles:[], types:[], saving:false })
    var comptageModal = reactive({ show:false, panel:null, heure:'', boites:null, rebuts:0, saving:false })
    var closeModal    = reactive({ show:false, panel:null, heure_fin:'', boites_produits:null, boites_rebuts:0, observation:'', error:'', saving:false })
    var devModal      = reactive({ show:false, panel:null, description:'', numeroDn:'', bloquante:false, error:'', saving:false })

    var filteredPanels = computed(function() {
      if (filterSite.value === 'Tous') return panels.value
      return panels.value.filter(function(p){ return p.equip.site === filterSite.value })
    })

    // ── Helpers ──
    var nowTime = function() {
      var n = new Date()
      return String(n.getHours()).padStart(2,'0') + ':' + String(n.getMinutes()).padStart(2,'0')
    }

    var toDateTime = function(dateStr, timeStr) {
      if (!dateStr || !timeStr) return null
      return new Date(dateStr + 'T' + timeStr)
    }

    var formatElapsed = function(ms) {
      if (ms < 0) ms = 0
      var s = Math.floor(ms / 1000)
      var h = Math.floor(s / 3600)
      var m = Math.floor((s % 3600) / 60)
      var sec = s % 60
      return String(h).padStart(2,'0') + ':' + String(m).padStart(2,'0') + ':' + String(sec).padStart(2,'0')
    }

    var panelClass = function(p) {
      if (!p.session) return 'panel-dispo'
      if (p.session.statut === 'En cours') return 'panel-encours'
      if (p.session.statut === 'Arrêt') return 'panel-arret'
      if (p.session.statut === 'Pause') return 'panel-pause'
      return ''
    }

    var panelColor = function(p) {
      if (!p.session) return '#374151'
      if (p.session.statut === 'En cours') return '#10b981'
      if (p.session.statut === 'Arrêt') return '#ef4444'
      if (p.session.statut === 'Pause') return '#f59e0b'
      return '#374151'
    }

    var oeeClass = function(v) {
      if (v == null) return ''
      if (v >= 85) return 'oee-green'
      if (v >= 60) return 'oee-orange'
      return 'oee-red'
    }

    // ── Helpers GS référence ──────────────────────────────────────
    // opts = { isPremierCampagne, hasVdlp }
    // Règles :
    //   pause      → toujours
    //   vdlp       → seulement si même campagne, lot suivant (hasVdlp)
    //   vdlc+format+reglage → seulement si premier lot nouvelle campagne (isPremierCampagne)
    //   micro      → proportionnel : (TO - pause - transitions) × micro_GS / 480
    var gsTotalPlanRef = function(eq, opts) {
      if (!eq) return 0
      var isPremier = opts && opts.isPremierCampagne
      var hasVdlp   = opts && opts.hasVdlp
      var pause = eq.pause_ref || 0
      var vdlp  = hasVdlp  ? (eq.vdlp_ref         || 0) : 0
      var vdlc  = isPremier ? (eq.vdlc_ref          || 0) : 0
      var chgt  = isPremier ? (eq.chgt_format_ref   || 0) : 0
      var regl  = isPremier ? (eq.reglage_ref        || 0) : 0
      var toBase = Math.max(0, (eq.to_shift_ref || 480) - pause - vdlp - vdlc - chgt - regl)
      var micro  = Math.round(toBase * ((eq.micro_arrets_ref || 0) / 480))
      return pause + vdlp + vdlc + chgt + regl + micro
    }
    var gsNetRef = function(eq, opts) {
      if (!eq) return 480
      return Math.max(1, (eq.to_shift_ref || 480) - gsTotalPlanRef(eq, opts))
    }

    var computeObjShift = function(m) {
      var cadObj = m.cadenceObj
      if (!cadObj || !m.equip) return '—'
      var opts = { isPremierCampagne: m.isPremierCampagne, hasVdlp: m.hasVdlp }
      return Math.round(cadObj * gsNetRef(m.equip, opts))
    }

    // Computed pour les opts du modal démarrage (template propre)
    var modalOpts = computed(function() {
      return { isPremierCampagne: startModal.isPremierCampagne, hasVdlp: startModal.hasVdlp }
    })
    var modalMicro = computed(function() {
      var eq = startModal.equip
      if (!eq) return 0
      var total = gsTotalPlanRef(eq, modalOpts.value)
      var fixed = (eq.pause_ref || 0)
        + (startModal.hasVdlp          ? (eq.vdlp_ref        || 0) : 0)
        + (startModal.isPremierCampagne ? (eq.vdlc_ref        || 0) + (eq.chgt_format_ref || 0) + (eq.reglage_ref || 0) : 0)
      return total - fixed
    })

    var computeCadence = function(m) {
      var s = m.panel && m.panel.session
      if (!s || !m.boites || !s.heure_debut || !s.date) return '—'
      var start = toDateTime(s.date, s.heure_debut)
      if (!start) return '—'
      var now = new Date()
      var minElapsed = (now - start) / 60000
      if (minElapsed <= 0) return '—'
      return (m.boites / minElapsed).toFixed(1)
    }

    var computeCadenceVsObj = function(m) {
      var cadR = parseFloat(computeCadence(m))
      var cadO = m.panel && m.panel.session && m.panel.session.cadence_objectif_snapshot
      if (!cadR || !cadO) return '—'
      return Math.round((cadR / cadO) * 100)
    }

    var computeOEEPreview = function(m) {
      var s = m.panel && m.panel.session
      if (!s) return []
      var eq = m.panel.equip

      // TO net de référence : snapshot ou recalcul GS (fallback)
      var toNetRef = s.temps_ouverture_min || gsNetRef(eq)

      // Seuls les arrêts imprévus (non planifiés, non pause) réduisent la disponibilité
      var arretImpro = (m.panel.arrets||[]).reduce(function(acc, a) {
        return (!a.est_planifie && !a.est_pause) ? acc + (a.duree_minutes||0) : acc
      }, 0)

      var tf         = Math.max(0, toNetRef - arretImpro)
      var total      = m.boites_produits || 0
      var boitesGood = total - (m.boites_rebuts || 0)
      var cadObj     = s.cadence_objectif_snapshot  // cadence GS onglet 2

      var D   = toNetRef > 0 ? Math.round((tf / toNetRef) * 100) : null
      var P   = (tf > 0 && cadObj > 0) ? Math.min(150, Math.round((total / (cadObj * tf)) * 100)) : null
      var Q   = total > 0 ? Math.round((boitesGood / total) * 100) : null
      var TRS = (D != null && P != null && Q != null) ? Math.round((D/100) * (P/100) * (Q/100) * 100) : null

      return [
        { label:'Disponibilité', val: D },
        { label:'Performance',   val: P },
        { label:'Qualité',       val: Q },
        { label:'TRS',           val: TRS }
      ]
    }

    // ── Chargement ──
    var loadAll = async function() {
      loading.value = true
      var [rEq, rPlanRooms, rCadences, rSh, rEq2, rFam] = await Promise.all([
        supabase.from('equipements_conditionnement').select('id, nom_equipement, site, actif, ordre_affichage, cadence_nominale_boite_min').eq('actif', true).order('ordre_affichage'),
        supabase.from('plan_rooms').select('code, equipement_id, to_shift_min, pause_min, vdlp_min, vdlc_min, chgt_format_min, reglage_min, micro_arrets_min, maint_min'),
        supabase.from('cadences').select('numero_salle, code_article, cadence_objectif_b_min'),
        supabase.from('shifts').select('*').eq('actif', true).order('heure_debut'),
        supabase.from('equipes').select('*').eq('actif', true).order('nom'),
        supabase.from('arret_familles').select('*').eq('actif', true).order('ordre')
      ])
      if (rSh.data)  shifts.value        = rSh.data
      if (rEq2.data) equipes.value       = rEq2.data
      if (rFam.data) arretFamilles.value = rFam.data

      // Cadences depuis Supabase (table cadences)
      gsCadences.value = (rCadences.data || []).map(function(c) {
        return { numero_atelier: c.numero_salle, code_article: c.code_article, cadence_objectif_b_min: c.cadence_objectif_b_min }
      })

      // Construire map : equipement_id → plan_room (TRS params) via code = 'c' + N°_atelier
      var equipToPlanRoom = {}
      ;(rPlanRooms.data || []).forEach(function(pr) {
        if (pr.equipement_id && pr.code && pr.code.charAt(0) === 'c') {
          equipToPlanRoom[pr.equipement_id] = pr
        }
      })

      // Fusionner Supabase équipements + paramètres plan_rooms
      var equipList = (rEq.data || []).map(function(eq) {
        var pr = equipToPlanRoom[eq.id] || null
        var numAtelier = pr ? parseInt(pr.code.slice(1)) : null
        return Object.assign({}, eq, {
          numero_atelier:     numAtelier,
          to_shift_ref:       (pr && pr.to_shift_min)      || 480,
          pause_ref:          (pr && pr.pause_min)         || 0,
          vdlp_ref:           (pr && pr.vdlp_min)          || 0,
          vdlc_ref:           (pr && pr.vdlc_min)          || 0,
          chgt_format_ref:    (pr && pr.chgt_format_min)   || 0,
          reglage_ref:        (pr && pr.reglage_min)       || 0,
          micro_arrets_ref:   (pr && pr.micro_arrets_min)  || 0,
          maint_curative_ref: (pr && pr.maint_min)         || 0,
        })
      })
      var newPanels = []

      for (var i = 0; i < equipList.length; i++) {
        var eq = equipList[i]
        var rSess = await supabase.from('production_sessions')
          .select('*')
          .eq('equipement_id', eq.id)
          .neq('statut', 'Clôturé')
          .is('deleted_at', null)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle()

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

        var arrets = []
        var activeArret = null
        var cadences = []
        var lastComptage = null
        if (session) {
          var rArr = await supabase.from('production_arrets')
            .select('*')
            .eq('session_id', session.id)
            .order('created_at', { ascending: false })
          if (rArr.data) {
            arrets = rArr.data
            activeArret = arrets.find(function(a){ return a.is_running }) || null
          }
          var rCad = await supabase.from('session_cadences').select('*').eq('session_id', session.id).order('started_at')
          cadences = rCad.data || []
          var rCpt = await supabase.from('production_comptages').select('id, created_at').eq('session_id', session.id).order('created_at', { ascending: false }).limit(1).maybeSingle()
          lastComptage = rCpt.data || null
        }

        var shiftNom = '', shiftCouleur = '#3B82F6', equipeNom = '', equipeCouleur = '#8B5CF6'
        if (session && session.shift_id) {
          var sh = shifts.value.find(function(s){ return s.id === session.shift_id })
          if (sh) { shiftNom = sh.nom; shiftCouleur = sh.couleur }
        }
        if (session && session.equipe_id) {
          var eq2 = equipes.value.find(function(e){ return e.id === session.equipe_id })
          if (eq2) { equipeNom = eq2.nom; equipeCouleur = eq2.couleur }
        }

        var rendPct = 0
        if (session && session.objectif_boites && sessBoites(session)) {
          rendPct = Math.round((sessBoites(session) / session.objectif_boites) * 100)
        }

        newPanels.push({
          equip: eq, session: session, activeArret: activeArret,
          arrets: arrets, cadences: cadences, lastComptage: lastComptage,
          lotNum: lotNum, lotProd: lotProd,
          shiftNom: shiftNom, shiftCouleur: shiftCouleur,
          equipeNom: equipeNom, equipeCouleur: equipeCouleur,
          rendPct: rendPct
        })
      }
      panels.value = newPanels
      loading.value = false
    }

    // ── Ticker ──
    var tick = function() {
      var n = new Date()
      var p2 = function(v){ return String(v).padStart(2,'0') }
      clock.value = p2(n.getHours())+':'+p2(n.getMinutes())+':'+p2(n.getSeconds())

      var newT = {}, newAT = {}, newTheo = {}
      for (var i = 0; i < panels.value.length; i++) {
        var p = panels.value[i]
        var start = null
        if (p.session && p.session.statut === 'En cours') {
          start = toDateTime(p.session.date, p.session.heure_debut)
          if (start) newT[p.equip.id] = formatElapsed(n - start)
        }
        if (p.activeArret && p.activeArret.is_running) {
          var aStart = toDateTime(p.session ? p.session.date : new Date().toISOString().slice(0,10), p.activeArret.heure_debut)
          if (aStart) newAT[p.activeArret.id] = formatElapsed(n - aStart)
        }
        // ── Compteur théorique (cadence × temps net hors arrêts) — parité avec le Schéma (trsTick) ──
        if (p.session && p.session.statut === 'En cours') {
          var cads = p.cadences || []
          var isFallbackCad = false
          if (cads.length === 0) {
            var fallCad = p.session.cadence_objectif_snapshot || (p.equip && p.equip.cadence_objectif_boite_min)
            if (fallCad && start) { cads = [{ cadence_bpm: fallCad, started_at: start.toISOString() }]; isFallbackCad = true }
          }
          if (cads.length > 0) {
            var colisageT = p.session.colisage_confirme || null
            var arretsT   = p.arrets || []
            var boitesTheo = 0
            for (var ci = 0; ci < cads.length; ci++) {
              var cad = cads[ci]
              var segStart = new Date(cad.started_at)
              var segEnd = (ci < cads.length - 1) ? new Date(cads[ci + 1].started_at) : n
              if (segStart >= segEnd) continue
              var netMs = segEnd.getTime() - segStart.getTime()
              for (var ai = 0; ai < arretsT.length; ai++) {
                var arr = arretsT[ai]
                var aS  = toDateTime(p.session.date, arr.heure_debut)
                if (!aS) continue
                var aE  = arr.is_running ? n : (arr.duree_minutes ? new Date(aS.getTime() + arr.duree_minutes * 60000) : null)
                if (!aE) continue
                var ovS = Math.max(segStart.getTime(), aS.getTime())
                var ovE = Math.min(segEnd.getTime(), aE.getTime())
                if (ovE > ovS) netMs -= (ovE - ovS)
              }
              boitesTheo += cad.cadence_bpm * Math.max(0, netMs / 60000)
            }
            var needsComptage = false, minsSinceCpt = null
            if (!p.activeArret) {
              var refTime = (p.lastComptage && p.lastComptage.created_at) ? new Date(p.lastComptage.created_at) : start
              if (refTime) { minsSinceCpt = Math.floor((n - refTime) / 60000); needsComptage = minsSinceCpt >= 30 }
            }
            newTheo[p.equip.id] = {
              boites: Math.floor(boitesTheo),
              colis: (colisageT && colisageT > 0) ? Math.round(boitesTheo / colisageT * 100) / 100 : null,
              currentCadence: cads[cads.length - 1].cadence_bpm,
              needsComptage: needsComptage, minsSinceCpt: minsSinceCpt, isFallback: isFallbackCad
            }
          }
        }
      }
      timers.value       = newT
      arretTimers.value  = newAT
      theoCounters.value = newTheo
    }

    // ── Démarrer session ──
    var detectShift = function() {
      var now = nowTime()
      var nowMin = parseInt(now.slice(0,2)) * 60 + parseInt(now.slice(3,5))
      return shifts.value.find(function(s) {
        var start = s.heure_debut.slice(0, 5)
        var end   = s.heure_fin.slice(0, 5)
        var sMin  = parseInt(start.slice(0,2)) * 60 + parseInt(start.slice(3,5))
        var eMin  = parseInt(end.slice(0,2))   * 60 + parseInt(end.slice(3,5))
        if (sMin < eMin) return nowMin >= sMin && nowMin < eMin
        return nowMin >= sMin || nowMin < eMin
      }) || null
    }

    var openStartModal = function(equip) {
      startModal.equip          = equip
      startModal.lotSearch      = ''
      startModal.lotSuggestions = []
      startModal.lot            = null
      startModal.equipe_id      = null
      startModal.date           = new Date().toISOString().slice(0,10)
      startModal.heure_debut    = nowTime()
      startModal.cadenceObj     = null
      startModal.colisage       = null
      startModal.colisageSrc    = ''
      startModal.isPremierCampagne = false
      startModal.hasVdlp           = false
      startModal.error          = ''
      startModal.saving         = false
      var autoShift = detectShift()
      startModal.shift_id = autoShift ? autoShift.id : null
      startModal.show = true
    }

    var searchLots = function() {
      clearTimeout(lotSearchTimeout)
      var q = startModal.lotSearch
      if (!q || q.length < 2) { startModal.lotSuggestions = []; return }
      lotSearchTimeout = setTimeout(async function() {
        var r = await supabase.from('lots')
          .select('id, numero_lot, product_id, products(code_article, description)')
          .ilike('numero_lot', '%' + q + '%')
          .limit(8)
        startModal.lotSuggestions = (r.data || []).map(function(l) {
          return {
            id: l.id, numero_lot: l.numero_lot,
            code_article: l.products ? l.products.code_article : '',
            description:  l.products ? l.products.description  : '',
            product_id:   l.product_id
          }
        })
      }, 200)
    }

    var selectLot = async function(l) {
      startModal.lot            = l
      startModal.lotSearch      = l.numero_lot
      startModal.lotSuggestions = []
      startModal.cadenceObj     = null
      startModal.colisage       = null
      startModal.colisageSrc    = ''
      startModal.isPremierCampagne = false
      startModal.hasVdlp           = false
      if (startModal.equip) {
        var numAtelier = startModal.equip.numero_atelier
        if (numAtelier && l.code_article) {
          var match = gsCadences.value.find(function(c) {
            return c.numero_atelier === numAtelier && c.code_article === l.code_article
          })
          startModal.cadenceObj = match ? match.cadence_objectif_b_min : null
        }
        // Détection type campagne : comparer avec la dernière session de cet équipement
        if (l.code_article) {
          var lastSR = await supabase.from('production_sessions')
            .select('lot_id').eq('equipement_id', startModal.equip.id)
            .order('created_at', { ascending: false }).limit(1).maybeSingle()
          if (!lastSR.error && lastSR.data && lastSR.data.lot_id) {
            var lastLotR = await supabase.from('lots')
              .select('products(code_article)').eq('id', lastSR.data.lot_id).maybeSingle()
            var lastCode = lastLotR.data && lastLotR.data.products ? lastLotR.data.products.code_article : null
            if (lastCode) {
              if (lastCode === l.code_article) startModal.hasVdlp = true
              else                              startModal.isPremierCampagne = true
            }
          }
        }
      }
      // Colisage depuis products.quantite_par_colis (table catalogue_produits supprimée : inexistante en base → 404)
      var colisage = null; var colisageSrc = ''
      if (l.product_id) {
        var prodR = await supabase.from('products').select('quantite_par_colis').eq('id', l.product_id).maybeSingle()
        if (prodR.data && prodR.data.quantite_par_colis) { colisage = prodR.data.quantite_par_colis; colisageSrc = 'sap' }
      }
      startModal.colisage    = colisage
      startModal.colisageSrc = colisageSrc
    }

    var doStart = async function() {
      if (!canPerform('trs_demarrer')) { startModal.error = 'Permission « démarrer une session » requise.'; return }
      if (!startModal.lot) { startModal.error = 'Sélectionner un lot.'; return }
      startModal.saving = true
      var eq = startModal.equip
      // ── Règle flux produit : le produit doit être autorisé sur cet équipement ──
      var lpFx = await supabase.from('lots').select('products(code_article)').eq('id', startModal.lot.id).maybeSingle()
      var fxL = await checkProductFluxEquipName(lpFx.data && lpFx.data.products ? lpFx.data.products.code_article : null, eq.nom_equipement)
      if (!fxL.allowed) { startModal.error = fxL.reason; startModal.saving = false; return }
      var cadObj   = startModal.cadenceObj
      var planOpts = { isPremierCampagne: startModal.isPremierCampagne, hasVdlp: startModal.hasVdlp }
      var netRef   = gsNetRef(eq, planOpts)
      var objBoites = cadObj ? Math.round(cadObj * netRef) : null

      var r = await supabase.from('production_sessions').insert({
        lot_id:         startModal.lot.id,
        equipement_id:  eq.id,
        shift_id:       startModal.shift_id  || null,
        equipe_id:      startModal.equipe_id || null,
        date:           startModal.date,
        heure_debut:    startModal.heure_debut + ':00',
        statut:         'En cours',
        cadence_nominale_snapshot: eq.cadence_nominale_boite_min  || null,
        cadence_objectif_snapshot: cadObj                         || null,
        objectif_boites:           objBoites,
        temps_ouverture_min:       netRef,                         // snapshot GS au démarrage
        colis_produits: 0, colis_rebuts: 0, boites_produites: 0, boites_rebuts: 0,
        colisage_confirme:         startModal.colisage            || null
      })
      if (r.error) { startModal.error = r.error.message; startModal.saving = false; return }
      startModal.show = false; startModal.saving = false
      await loadAll()
    }

    // ── Déclarer arrêt ──
    var openArretModal = function(p) {
      arretModal.panel        = p
      arretModal.famille_id   = null
      arretModal.sf_id        = null
      arretModal.type_id      = null
      arretModal.sousFamilles = []
      arretModal.types        = []
      arretModal.selectedType = null
      arretModal.heure_debut  = nowTime()
      arretModal.commentaire  = ''
      arretModal.error        = ''
      arretModal.saving       = false
      arretModal.show         = true
    }

    var onFamilleChange = async function() {
      arretModal.sf_id        = null
      arretModal.type_id      = null
      arretModal.sousFamilles = []
      arretModal.types        = []
      arretModal.selectedType = null
      if (!arretModal.famille_id) return
      var f = arretFamilles.value.find(function(x){ return x.id === arretModal.famille_id })
      arretModal.familleCouleur = f ? f.couleur : '#EF4444'
      var r = await supabase.from('arret_sous_familles').select('*').eq('famille_id', arretModal.famille_id).eq('actif', true).order('ordre')
      arretModal.sousFamilles = r.data || []
    }

    var onSFChange = async function() {
      arretModal.type_id      = null
      arretModal.types        = []
      arretModal.selectedType = null
      if (!arretModal.sf_id) return
      var r = await supabase.from('arret_types').select('*').eq('sous_famille_id', arretModal.sf_id).eq('actif', true).order('code')
      arretModal.types = r.data || []
    }

    var onTypeChange = function() {
      arretModal.selectedType = arretModal.types.find(function(t){ return t.id === arretModal.type_id }) || null
    }

    var doArret = async function() {
      if (!canPerform('trs_arret')) { arretModal.error = 'Permission « déclarer un arrêt » requise.'; return }
      if (!arretModal.type_id) { arretModal.error = 'Sélectionner un code arrêt.'; return }
      arretModal.saving = true
      var t  = arretModal.selectedType
      var f  = arretFamilles.value.find(function(x){ return x.id === arretModal.famille_id })
      var sf = arretModal.sousFamilles.find(function(x){ return x.id === arretModal.sf_id })

      var r = await supabase.from('production_arrets').insert({
        session_id:       arretModal.panel.session.id,
        arret_type_id:    t.id,
        famille_nom:      f ? f.nom : '',
        sous_famille_nom: sf ? sf.nom : '',
        arret_code:       t.code,
        arret_nom:        t.nom,
        couleur:          t.couleur || (f ? f.couleur : '#EF4444'),
        est_planifie:     t.est_planifie,
        est_pause:        t.est_pause,
        heure_debut:      arretModal.heure_debut + ':00',
        is_running:       true,
        commentaire:      arretModal.commentaire || null
      }).select().maybeSingle()
      if (r.error) { arretModal.error = r.error.message; arretModal.saving = false; return }

      var newStatut = t.est_pause ? 'Pause' : 'Arrêt'
      await supabase.from('production_sessions').update({ statut: newStatut, updated_at: new Date().toISOString() }).eq('id', arretModal.panel.session.id)

      // MAJ locale instantanée sur le panel VIVANT (règle N°8)
      var lp = liveP(arretModal.panel.equip.id)
      if (lp && lp.session) lp.session.statut = newStatut
      if (lp && r.data) { lp.activeArret = r.data; lp.arrets = (lp.arrets || []).concat([r.data]) }
      arretModal.show = false; arretModal.saving = false
    }

    // ── Clôturer arrêt (reprendre) ──
    var clotureArret = async function(p) {
      if (!p.activeArret) return
      var now   = nowTime()
      var start = toDateTime(p.session.date, p.activeArret.heure_debut)
      var dur   = start ? Math.round((new Date() - start) / 60000) : null
      var arretId = p.activeArret.id
      await supabase.from('production_arrets').update({
        heure_fin: now + ':00', duree_minutes: dur, is_running: false, updated_at: new Date().toISOString()
      }).eq('id', arretId)
      await supabase.from('production_sessions').update({ statut: 'En cours', updated_at: new Date().toISOString() }).eq('id', p.session.id)
      // MAJ locale instantanée sur le panel VIVANT (règle N°8)
      var lp = liveP(p.equip.id) || p
      if (lp.session) lp.session.statut = 'En cours'
      var fa = (lp.arrets || []).find(function(x){ return x.id === arretId })
      if (fa) { fa.heure_fin = now + ':00'; fa.duree_minutes = dur; fa.is_running = false }
      lp.activeArret = null
    }

    // ── Requalifier arrêt ──
    var openRequalifModal = function(p) {
      requalModal.panel        = p
      requalModal.famille_id   = null
      requalModal.sf_id        = null
      requalModal.type_id      = null
      requalModal.sousFamilles = []
      requalModal.types        = []
      requalModal.saving       = false
      requalModal.show         = true
    }

    var onRequalFamilleChange = async function() {
      requalModal.sf_id = null; requalModal.type_id = null; requalModal.types = []
      if (!requalModal.famille_id) return
      var r = await supabase.from('arret_sous_familles').select('*').eq('famille_id', requalModal.famille_id).eq('actif', true).order('ordre')
      requalModal.sousFamilles = r.data || []
    }

    var onRequalSFChange = async function() {
      requalModal.type_id = null
      if (!requalModal.sf_id) return
      var r = await supabase.from('arret_types').select('*').eq('sous_famille_id', requalModal.sf_id).eq('actif', true).order('code')
      requalModal.types = r.data || []
    }

    var doRequalif = async function() {
      if (!requalModal.type_id || !requalModal.panel.activeArret) return
      requalModal.saving = true
      var t  = requalModal.types.find(function(x){ return x.id === requalModal.type_id })
      var f  = arretFamilles.value.find(function(x){ return x.id === requalModal.famille_id })
      var sf = requalModal.sousFamilles.find(function(x){ return x.id === requalModal.sf_id })
      await supabase.from('production_arrets').update({
        arret_type_id: t.id, famille_nom: f ? f.nom : '', sous_famille_nom: sf ? sf.nom : '',
        arret_code: t.code, arret_nom: t.nom, couleur: t.couleur || (f ? f.couleur : '#EF4444'),
        est_planifie: t.est_planifie, est_pause: t.est_pause, updated_at: new Date().toISOString()
      }).eq('id', requalModal.panel.activeArret.id)
      // MAJ locale instantanée sur le panel VIVANT (règle N°8)
      var lpr = liveP(requalModal.panel.equip.id)
      var aa = lpr && lpr.activeArret
      if (aa) { aa.arret_code = t.code; aa.arret_nom = t.nom; aa.famille_nom = f ? f.nom : ''; aa.sous_famille_nom = sf ? sf.nom : ''; aa.couleur = t.couleur || (f ? f.couleur : '#EF4444'); aa.est_planifie = t.est_planifie; aa.est_pause = t.est_pause }
      requalModal.show = false; requalModal.saving = false
    }

    // ── Comptage ──
    // Boîtes/rebuts d'une session — boîtes EXACTES (fallback colis × colisage pour sessions < migration 025)
    var sessBoites = function(s){ if(!s) return 0; return (s.boites_produites != null) ? s.boites_produites : ((s.colis_produits||0) * (s.colisage_confirme||1)) }
    var sessBoitesRebuts = function(s){ if(!s) return 0; return (s.boites_rebuts != null) ? s.boites_rebuts : ((s.colis_rebuts||0) * (s.colisage_confirme||1)) }
    var sessColis = function(s){ if(!s) return 0; var c = s.colisage_confirme||0; return c>0 ? Math.round(sessBoites(s)/c*100)/100 : (s.colis_produits||0) }
    // Panel VIVANT de panels.value (par equip.id) — pour muter l'objet réellement rendu, jamais une référence orpheline post-loadAll
    var liveP = function(eid){ for (var i=0;i<panels.value.length;i++){ if (panels.value[i].equip.id === eid) return panels.value[i] } return null }
    var openComptageModal = function(p) {
      comptageModal.panel   = p
      comptageModal.heure   = nowTime()
      comptageModal.boites  = p.session ? sessBoites(p.session) : null
      comptageModal.rebuts  = p.session ? sessBoitesRebuts(p.session) : 0
      comptageModal.saving  = false
      comptageModal.show    = true
    }

    var doComptage = async function() {
      if (!canPerform('trs_comptage')) { alert('Permission « saisir un comptage » requise.'); return }
      if (!comptageModal.boites) return
      comptageModal.saving = true
      var s        = comptageModal.panel.session
      var colisage = s.colisage_confirme || 1
      var boites   = comptageModal.boites                                  // BOÎTES exactes saisies
      var rebutsBte = comptageModal.rebuts || 0
      var colisCumul = Math.round(boites / colisage)                       // colis rétrocompat
      var rebutsColis = Math.round(rebutsBte / colisage)
      var start    = toDateTime(s.date, s.heure_debut)
      var minEl    = start ? (new Date() - start) / 60000 : null
      var cadInst  = (minEl && minEl > 0) ? parseFloat((boites / minEl).toFixed(2)) : null

      await supabase.from('production_comptages').insert({
        session_id: s.id, heure: comptageModal.heure + ':00',
        colis_cumules: colisCumul,
        rebuts_cumules: rebutsColis,
        boites_cumules: boites,
        boites_rebuts_cumules: rebutsBte,
        cadence_instantanee: cadInst
      })
      await supabase.from('production_sessions').update({
        boites_produites: boites,
        boites_rebuts: rebutsBte,
        colis_produits: colisCumul,
        colis_rebuts: rebutsColis,
        cadence_reelle_boite_min: cadInst,
        updated_at: new Date().toISOString()
      }).eq('id', s.id)
      // MAJ locale instantanée sur le panel VIVANT (règle N°8) — pas de loadAll (sa reconstruction orphelinerait les refs)
      var lp = liveP(comptageModal.panel.equip.id)
      if (lp && lp.session) {
        lp.session.boites_produites = boites; lp.session.boites_rebuts = rebutsBte
        lp.session.colis_produits = colisCumul; lp.session.colis_rebuts = rebutsColis
        lp.session.cadence_reelle_boite_min = cadInst
        if (lp.session.objectif_boites) lp.rendPct = Math.round((boites / lp.session.objectif_boites) * 100)
      }
      comptageModal.show = false; comptageModal.saving = false
    }

    // ── Clôturer session ──
    var openCloseModal = function(p) {
      closeModal.panel           = p
      closeModal.heure_fin       = nowTime()
      closeModal.boites_produits = p.session ? sessBoites(p.session) : null
      closeModal.boites_rebuts   = p.session ? sessBoitesRebuts(p.session) : 0
      closeModal.observation     = ''
      closeModal.error           = ''
      closeModal.saving          = false
      closeModal.show            = true
    }

    // Calcule l'objet d'update de clôture (OEE complet) — partagé par doClose (manuel) ET doAutoClose (fin de shift).
    var buildSessionCloseUpdate = function(s, eq, arrs, heureFinHHMM, boitesTotal, boitesRebuts) {
      var start    = toDateTime(s.date, s.heure_debut)
      var end      = toDateTime(s.date, heureFinHHMM)
      var totalMin = (start && end) ? Math.round((end - start) / 60000) : 0
      var arretImpro = arrs.reduce(function(a,x){ return (!x.est_planifie && !x.est_pause) ? a+(x.duree_minutes||0) : a }, 0)
      var arretPlan  = arrs.reduce(function(a,x){ return (x.est_planifie  && !x.est_pause) ? a+(x.duree_minutes||0) : a }, 0)
      var pauses     = arrs.reduce(function(a,x){ return x.est_pause ? a+(x.duree_minutes||0) : a }, 0)
      var toNetRef = s.temps_ouverture_min || gsNetRef(eq)
      var tf = Math.max(0, toNetRef - arretImpro)
      var total     = boitesTotal || 0
      var good      = total - (boitesRebuts || 0)
      var cadObj    = s.cadence_objectif_snapshot
      var cadReelle = (totalMin > 0 && total > 0) ? parseFloat((total / totalMin).toFixed(2)) : null
      var rendPct   = (s.objectif_boites && total) ? Math.round((total / s.objectif_boites) * 100) : null
      var D = toNetRef > 0 ? Math.round((tf / toNetRef) * 100) : null
      var P = (tf > 0 && cadObj > 0) ? Math.min(150, Math.round((total / (cadObj * tf)) * 100)) : null
      var Q = total > 0 ? Math.round((good / total) * 100) : null
      var TRS = (D != null && P != null && Q != null) ? Math.round((D/100) * (P/100) * (Q/100) * 100) : null
      var colisage = s.colisage_confirme || 1
      return {
        heure_fin: heureFinHHMM + ':00', statut: 'Clôturé',
        boites_produites: total, boites_rebuts: (boitesRebuts || 0),
        colis_produits: Math.floor(total / colisage), colis_rebuts: Math.floor((boitesRebuts || 0) / colisage),
        cadence_reelle_boite_min: cadReelle, rendement_pct: rendPct,
        temps_ouverture_min: toNetRef, temps_fonctionnement_min: tf,
        temps_arret_planifie_min: arretPlan, temps_arret_impro_min: arretImpro, temps_pause_min: pauses,
        disponibilite: D, performance: P, qualite: Q, trs: TRS,
        updated_at: new Date().toISOString()
      }
    }

    var doClose = async function() {
      if (!canPerform('trs_cloturer')) { closeModal.error = 'Permission « clôturer une session » requise.'; return }
      if (!closeModal.heure_fin) { closeModal.error = 'Heure de fin requise.'; return }
      closeModal.saving = true
      var s    = closeModal.panel.session
      var eq   = closeModal.panel.equip
      var arrs = closeModal.panel.arrets || []

      var end = toDateTime(s.date, closeModal.heure_fin)
      // Clôturer l'arrêt actif éventuel (comportement préservé : non recompté dans le TRS de clôture manuelle)
      if (closeModal.panel.activeArret) {
        var nowH   = nowTime()
        var aStart = toDateTime(s.date, closeModal.panel.activeArret.heure_debut)
        var aDur   = aStart ? Math.round((end - aStart) / 60000) : null
        await supabase.from('production_arrets').update({
          heure_fin: nowH+':00', duree_minutes: aDur, is_running: false, updated_at: new Date().toISOString()
        }).eq('id', closeModal.panel.activeArret.id)
      }

      var upd = buildSessionCloseUpdate(s, eq, arrs, closeModal.heure_fin, closeModal.boites_produits, closeModal.boites_rebuts)
      upd.observation = closeModal.observation || null
      var r = await supabase.from('production_sessions').update(upd).eq('id', s.id)

      if (r.error) { closeModal.error = r.error.message; closeModal.saving = false; return }
      // MAJ locale instantanée sur le panel VIVANT (règle N°8) — la machine repasse « Disponible »
      var pc = liveP(closeModal.panel.equip.id)
      if (pc) { pc.session = null; pc.activeArret = null; pc.arrets = [] }
      closeModal.show = false; closeModal.saving = false
      loadAll()
    }

    // ── Déclarer déviation ──
    var openDevModal = function(p) {
      devModal.panel       = p
      devModal.description = ''
      devModal.numeroDn    = ''
      devModal.bloquante   = false
      devModal.error       = ''
      devModal.saving      = false
      devModal.show        = true
    }

    var doSaveDev = async function() {
      var s = devModal.panel && devModal.panel.session
      if (!s || !s.lot_id) { devModal.error = 'Aucun lot associé à cette session.'; return }
      devModal.saving = true; devModal.error = ''
      var userData = await supabase.auth.getUser()
      var userId = userData.data.user?.id || null
      var userMeta = userData.data.user?.user_metadata || {}
      var userService = userMeta.service || null
      try {
        await declareDeviation(s.lot_id, devModal.description, devModal.bloquante, devModal.numeroDn || null, userId, userService)
      } catch(e) {
        devModal.error = e.message || 'Erreur'; devModal.saving = false; return
      }
      devModal.show = false; devModal.saving = false
    }

    // ── Clôture automatique 10 min après fin de shift ────────────────
    var timeToMin = function(hhmm) {
      var parts = (hhmm || '').slice(0, 5).split(':')
      return parseInt(parts[0] || 0) * 60 + parseInt(parts[1] || 0)
    }

    var doAutoClose = async function(p, sh) {
      var sessId = p.session.id
      if (autoClosing[sessId]) return
      autoClosing[sessId] = true
      var heureFin = sh.heure_fin.slice(0, 5)
      var arrs = (p.arrets || []).slice()
      if (p.activeArret) {
        var aStart  = toDateTime(p.session.date, p.activeArret.heure_debut)
        var finDate = toDateTime(p.session.date, heureFin)
        var aDur    = aStart ? Math.max(0, Math.round((finDate - aStart) / 60000)) : null
        await supabase.from('production_arrets').update({
          heure_fin: heureFin + ':00', duree_minutes: aDur, is_running: false,
          updated_at: new Date().toISOString()
        }).eq('id', p.activeArret.id)
        // recompter l'arrêt fraîchement clôturé dans le calcul OEE (machine à l'arrêt jusqu'à la fin de shift)
        arrs = arrs.map(function(a){ return a.id === p.activeArret.id ? Object.assign({}, a, { duree_minutes: aDur, is_running: false }) : a })
      }
      // Clôture PROPRE avec OEE calculé (comme une clôture manuelle) — boîtes = dernier comptage stocké
      var upd = buildSessionCloseUpdate(p.session, p.equip, arrs, heureFin, sessBoites(p.session), sessBoitesRebuts(p.session))
      upd.observation = 'Clôture automatique (fin de shift +10 min)'
      await supabase.from('production_sessions').update(upd).eq('id', sessId)
      delete autoClosing[sessId]
      // NB : pas de loadAll() ici — autoStopCheck recharge une seule fois après la boucle
      // (sinon panels.value muterait en pleine itération et certaines sessions seraient sautées).
    }

    // Datetime réelle de fin de shift d'une session (gère le franchissement de minuit : shift de nuit)
    var sessionShiftEnd = function(session, sh) {
      if (!session || !session.date || !sh || !sh.heure_fin) return null
      var end = new Date(session.date + 'T' + sh.heure_fin.slice(0, 5))
      var start = toDateTime(session.date, session.heure_debut)
      // fin <= début → le shift se termine le lendemain (nuit)
      if (start && end <= start) end.setDate(end.getDate() + 1)
      return end
    }

    // Clôture automatique de TOUTE session dont la fin de shift +10 min est DÉPASSÉE
    // (rattrape aussi les sessions oubliées des jours précédents dès l'ouverture de la page).
    var autoStopCheck = async function() {
      var now = new Date()
      var snapshot = panels.value.slice()   // figer la liste (doAutoClose ne recharge plus en boucle)
      var closedAny = false
      for (var pi = 0; pi < snapshot.length; pi++) {
        var p = snapshot[pi]
        if (!p.session || p.session.statut === 'Clôturé' || p.session.statut === 'Annulé') continue
        if (autoClosing[p.session.id]) continue
        if (!p.session.shift_id) continue
        var sh = shifts.value.find(function(s) { return s.id === p.session.shift_id })
        if (!sh) continue
        var end = sessionShiftEnd(p.session, sh)
        if (!end) continue
        var trigger = new Date(end.getTime() + 10 * 60000)   // fin de shift + 10 min
        if (now >= trigger) {
          await doAutoClose(p, sh)
          closedAny = true
        }
      }
      if (closedAny) await loadAll()
    }

    // ══ VUE « MODE LIVE » GÉANTE (affichage production plein écran) ══
    var liveView      = ref(false)
    var teamRankMonth = ref([])   // [{equipe_id, nom, couleur, rendement, n}]
    var teamRankYear  = ref([])
    var lineRecords   = ref({})   // equipement_id → { boites, date }
    var liveStatsInt  = null
    var liveCards     = computed(function(){ return filteredPanels.value.filter(function(p){ return !!p.session }) })
    var winSize       = ref({ w: 1280, h: 720 })
    var onResizeLive  = function(){ winSize.value = { w: window.innerWidth, h: window.innerHeight } }
    // Grille calculée pour que TOUTES les cartes tiennent sans scroll (plein écran)
    var liveGrid = computed(function(){
      var n = liveCards.value.length || 1
      var w = winSize.value.w, h = winSize.value.h
      var wide = w > 820
      var availW = wide ? (w - Math.min(w * 0.22, 420) - 48) : (w - 20)
      var availH = (h - 76) - (wide ? 0 : Math.min(h * 0.18, 150))
      var best = { cols: 1, rows: n, score: -1 }
      for (var c = 1; c <= n; c++) {
        var r = Math.ceil(n / c)
        var cw = (availW - (c - 1) * 14) / c
        var ch = (availH - (r - 1) * 14) / r
        if (cw <= 0 || ch <= 0) continue
        var score = Math.min(cw, ch * 1.4)   // vise un ratio carte ~1.4, maximise la dimension limitante
        if (score > best.score) best = { cols: c, rows: r, score: score }
      }
      return { gridTemplateColumns: 'repeat(' + best.cols + ',minmax(0,1fr))', gridTemplateRows: 'repeat(' + best.rows + ',minmax(0,1fr))' }
    })

    var rendClass = function(r) {
      if (r == null) return 'rc-dim'
      if (r >= 100) return 'rc-win'
      if (r >= 80)  return 'rc-ok'
      return 'rc-low'
    }

    var loadLiveStats = async function() {
      var d = new Date()
      var year         = d.getFullYear()
      var jan1         = year + '-01-01'
      var firstOfMonth = year + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-01'
      var r = await supabase.from('production_sessions')
        .select('equipe_id, equipement_id, rendement_pct, boites_produites, colis_produits, colisage_confirme, date')
        .eq('statut', 'Clôturé')
        .gte('date', jan1)
        .limit(20000)
      if (r.error) return
      var rows = r.data || []
      var bof = function(s){ return (s.boites_produites != null) ? s.boites_produites : ((s.colis_produits || 0) * (s.colisage_confirme || 1)) }
      // Records par ligne = MAX boîtes sur un shift
      var rec = {}
      rows.forEach(function(s){
        if (!s.equipement_id) return
        var b = bof(s)
        if (!rec[s.equipement_id] || b > rec[s.equipement_id].boites) rec[s.equipement_id] = { boites: b, date: s.date }
      })
      lineRecords.value = rec
      // Classement équipes = rendement moyen (réel/objectif)
      var rank = function(filterFn) {
        var agg = {}
        rows.forEach(function(s){
          if (!s.equipe_id || s.rendement_pct == null || !filterFn(s)) return
          if (!agg[s.equipe_id]) agg[s.equipe_id] = { sum: 0, n: 0 }
          agg[s.equipe_id].sum += s.rendement_pct; agg[s.equipe_id].n++
        })
        return Object.keys(agg).map(function(eid){
          var e = equipes.value.find(function(x){ return String(x.id) === String(eid) })
          return { equipe_id: eid, nom: e ? e.nom : '?', couleur: e ? e.couleur : '#8B5CF6', rendement: Math.round(agg[eid].sum / agg[eid].n), n: agg[eid].n }
        }).sort(function(a, b){ return b.rendement - a.rendement })
      }
      teamRankYear.value  = rank(function(){ return true })
      teamRankMonth.value = rank(function(s){ return s.date >= firstOfMonth })
    }

    var openLiveView = async function() {
      liveView.value = true
      onResizeLive()
      window.addEventListener('resize', onResizeLive)
      await loadLiveStats()
      if (!liveStatsInt) liveStatsInt = setInterval(loadLiveStats, 120000)
    }
    var closeLiveView = function() { liveView.value = false; window.removeEventListener('resize', onResizeLive) }
    var onKeyLive = function(e) { if (e.key === 'Escape' && liveView.value) closeLiveView() }

    onMounted(async function() {
      var ud = await supabase.auth.getUser()
      if (ud.data.user) { var pp = await supabase.from('profiles').select('service').eq('id', ud.data.user.id).single(); if (pp.data) await loadPermissions(pp.data.service) }
      await loadAll()
      await autoStopCheck()   // rattrape immédiatement les sessions en retard (ex. oubliées depuis hier)
      clockInt      = setInterval(tick, 1000)
      refreshInt    = setInterval(loadAll, 60000)
      autoStopInt   = setInterval(autoStopCheck, 60000)
      window.addEventListener('keydown', onKeyLive)
      tick()
    })

    onUnmounted(function() {
      clearInterval(clockInt)
      clearInterval(refreshInt)
      clearInterval(autoStopInt)
      clearInterval(liveStatsInt)
      window.removeEventListener('keydown', onKeyLive)
    })

    var THEME_ORDER = ['night', 'day', 'workshop']
    var cycleTheme = function() {
      var idx = THEME_ORDER.indexOf(theme.value)
      theme.value = THEME_ORDER[(idx + 1) % THEME_ORDER.length]
    }
    var themeIcon = computed(function() {
      return theme.value === 'day' ? 'sun' : theme.value === 'workshop' ? 'factory' : 'moon'
    })
    var themeTitle = computed(function() {
      return theme.value === 'night' ? 'Nuit → cliquer pour Jour' : theme.value === 'day' ? 'Jour → cliquer pour Atelier' : 'Atelier → cliquer pour Nuit'
    })

    return {
      theme, cycleTheme, themeIcon, themeTitle,
      panels, shifts, equipes, arretFamilles, loading, clock, filterSite,
      timers, arretTimers, theoCounters, filteredPanels,
      liveView, openLiveView, closeLiveView, liveCards, liveGrid, teamRankMonth, teamRankYear, lineRecords, rendClass,
      startModal, arretModal, requalModal, comptageModal, closeModal, devModal,
      panelClass, panelColor, oeeClass, sessBoites, sessColis,
      gsTotalPlanRef, gsNetRef, modalOpts, modalMicro,
      computeObjShift, computeCadence, computeCadenceVsObj, computeOEEPreview,
      loadAll,
      detectShift, openStartModal, searchLots, selectLot, doStart,
      openArretModal, onFamilleChange, onSFChange, onTypeChange, doArret,
      clotureArret, openRequalifModal, onRequalFamilleChange, onRequalSFChange, doRequalif,
      openComptageModal, doComptage,
      openCloseModal, doClose,
      openDevModal, doSaveDev
    }
  }
}
</script>

<style scoped>
/* ═══════════════════════════════════════════════
   BASE — dark navy matching schéma production
═══════════════════════════════════════════════ */
.trs-live {
  min-height: 100%;
  background: #0c0c1e;
  color: #e2e8f0;
  font-family: 'Inter', system-ui, -apple-system, sans-serif;
}

/* ══ HEADER ══ */
.ph {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 16px;
  background: #07070f;
  border-bottom: 1px solid rgba(255,255,255,.06);
  flex-wrap: wrap;
  gap: 8px;
  position: sticky;
  top: 0;
  z-index: 20;
}
.ph-left  { display: flex; align-items: baseline; gap: 12px; }
.ph-right { display: flex; align-items: center; gap: 8px; }

.pt       { font-size: 10px; font-weight: 700; letter-spacing: 2px; color: #475569; text-transform: uppercase; }
.pt-clock { font-family: 'SF Mono', monospace; font-size: 15px; color: #3b82f6; font-weight: 700; letter-spacing: 1px; }

.site-tabs { display: flex; gap: 3px; }
.site-tab  {
  padding: 3px 10px; font-size: 11px; font-weight: 500;
  border: 1px solid rgba(255,255,255,.1); background: transparent;
  color: #64748b; border-radius: 2px; cursor: pointer;
}
.site-tab.active { background: #3b82f6; color: #fff; border-color: #3b82f6; }

.btn-refresh {
  padding: 3px 10px; font-size: 16px;
  border: 1px solid rgba(255,255,255,.1); background: transparent;
  color: #64748b; border-radius: 2px; cursor: pointer;
}
.btn-refresh:hover { color: #e2e8f0; }
@keyframes spin { from { transform: rotate(0) } to { transform: rotate(360deg) } }
.btn-refresh.spinning { animation: spin .7s linear infinite; }

.loading-msg { padding: 48px; text-align: center; color: #475569; font-size: 13px; }

/* ══ TABLE ══ */
.trs-scroller { overflow-x: auto; }
.trs-table    { min-width: 1260px; }

/* Colonnes partagées header + rows */
.trs-thead,
.trs-row {
  display: grid;
  grid-template-columns: 152px 122px 158px 148px 100px 168px 78px 58px 58px 58px 70px minmax(128px, 1fr);
}

.trs-thead {
  background: #060610;
  border-bottom: 1px solid rgba(255,255,255,.08);
  position: sticky;
  top: 41px;
  z-index: 10;
}

.th {
  padding: 8px 10px;
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 1.2px;
  text-transform: uppercase;
  color: #334155;
}
.th-c     { text-align: center; }
.th-trs-h { text-align: center; color: #1e40af; }

/* ══ LIGNES ══ */
.trs-row-group { border-bottom: 1px solid rgba(255,255,255,.04); }

.trs-row {
  background: #0f0f23;
  border-left: 3px solid #1a1a35;
  align-items: center;
  transition: background .12s;
}
.trs-row:hover { background: #13132e; }

.td {
  padding: 8px 10px;
  font-size: 12px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  min-height: 54px;
  overflow: hidden;
}
.td-c    { align-items: center; }
.td-chips { flex-direction: row; flex-wrap: wrap; gap: 3px; align-items: center; }

/* Machine */
.mach-name { font-size: 13px; font-weight: 600; color: #e2e8f0; line-height: 1.2; }
.mach-site { font-size: 9px; color: #334155; text-transform: uppercase; letter-spacing: .5px; margin-top: 2px; }

/* Shift / Équipe */
.chip {
  font-size: 9px; font-weight: 600; padding: 2px 7px;
  border-radius: 8px; white-space: nowrap; line-height: 1.5;
}

/* Lot */
.lot-n { font-family: 'SF Mono', monospace; font-size: 12px; font-weight: 600; color: #e2e8f0; }
.lot-p { font-size: 10px; color: #475569; margin-top: 2px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

/* Statut */
.td-stat   { gap: 4px; }
.stat-pill {
  display: inline-flex; align-items: center; gap: 5px;
  font-size: 10px; font-weight: 600; padding: 2px 8px;
  border-radius: 8px; border: 1px solid; white-space: nowrap;
}
.stat-dot  { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
.arret-mini { display: flex; align-items: center; gap: 4px; }
.ac  { font-family: 'SF Mono', monospace; font-size: 9px; font-weight: 700; }
.an  { font-size: 10px; color: #64748b; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 130px; }

/* Timer */
.tmr { font-family: 'SF Mono', monospace; font-size: 14px; font-weight: 700; letter-spacing: 1px; }

/* Boîtes / Obj */
.td-prod { gap: 2px; }
.prod-nums { display: flex; align-items: baseline; gap: 4px; justify-content: center; }
.pv   { font-size: 16px; font-weight: 700; color: #e2e8f0; }
.po   { font-size: 12px; }
.rend-bar  { width: 90%; height: 4px; background: rgba(255,255,255,.07); border-radius: 2px; overflow: hidden; }
.rend-fill { height: 100%; border-radius: 2px; transition: width .5s; }
.rend-pct  { font-size: 10px; font-weight: 700; }
.theo-row  { font-size: 11px; color: #60a5fa; font-weight: 600; margin-top: 2px; }
.theo-lbl  { font-size: 8px; text-transform: uppercase; letter-spacing: .4px; color: #64748b; font-weight: 700; margin-right: 2px; }

/* b/min */
.cad-r { font-size: 14px; font-weight: 600; }
.cad-o { font-size: 11px; margin-top: 1px; }

/* OEE */
.oee-n { font-size: 13px; font-weight: 700; }
.trs-n { font-size: 17px; font-weight: 800; }
.td-trs-c { }

/* Utilitaires couleur */
.dim    { color: #1e293b; }
.mono   { font-family: 'SF Mono', 'Fira Code', monospace; }
.clr-g  { color: #10b981; }
.clr-o  { color: #f59e0b; }
.clr-r  { color: #ef4444; }
.clr-b  { color: #3b82f6; }
.oee-green  { color: #10b981; }
.oee-orange { color: #f59e0b; }
.oee-red    { color: #ef4444; }

/* ══ ACTIONS ══ */
.td-act {
  flex-direction: row; flex-wrap: wrap; gap: 3px;
  align-items: center; padding: 6px 8px;
}
.ab {
  border: 1px solid transparent; border-radius: 3px; cursor: pointer;
  font-size: 11px; font-weight: 600; padding: 4px 8px; white-space: nowrap;
  transition: background .1s;
}
.ab-start { background: rgba(16,185,129,.12); color: #10b981; border-color: rgba(16,185,129,.25); }
.ab-start:hover { background: rgba(16,185,129,.22); }
.ab-stp   { background: rgba(239,68,68,.12); color: #ef4444; border-color: rgba(239,68,68,.25); }
.ab-stp:hover { background: rgba(239,68,68,.22); }
.ab-cnt   { background: rgba(59,130,246,.12); color: #3b82f6; border-color: rgba(59,130,246,.25); }
.ab-cnt:hover { background: rgba(59,130,246,.22); }
.ab-cls   { background: rgba(148,163,184,.08); color: #94a3b8; border-color: rgba(148,163,184,.2); }
.ab-cls:hover { background: rgba(148,163,184,.15); }
.ab-dev   { background: rgba(245,158,11,.1); color: #f59e0b; border-color: rgba(245,158,11,.25); }
.ab-dev:hover { background: rgba(245,158,11,.2); }
.ab-rsm   { background: rgba(16,185,129,.12); color: #10b981; border-color: rgba(16,185,129,.25); }
.ab-rsm:hover { background: rgba(16,185,129,.22); }
.ab-req   { background: rgba(245,158,11,.12); color: #f59e0b; border-color: rgba(245,158,11,.25); }
.ab-req:hover { background: rgba(245,158,11,.22); }

/* ══ SOUS-LIGNE ARRÊTS ══ */
.arrets-sub {
  background: #08081a;
  border-left: 3px solid rgba(255,255,255,.04);
  padding: 4px 16px 5px 20px;
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  align-items: center;
}
.arrets-sub-lbl {
  font-size: 8px; color: #334155; text-transform: uppercase;
  letter-spacing: .8px; margin-right: 2px; white-space: nowrap;
}
.arret-tag {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 10px; padding: 2px 7px; border-radius: 3px;
  border: 1px solid; white-space: nowrap; background: rgba(255,255,255,.02);
}
.arret-tag.ar-run { background: rgba(255,255,255,.05); font-weight: 600; }
.at-code { font-family: 'SF Mono', monospace; font-size: 9px; font-weight: 700; }
.at-nom  { color: #64748b; font-size: 9px; }
.at-dur  { color: #334155; font-family: 'SF Mono', monospace; font-size: 9px; }


/* ════════════════════════════════════════
   MODALS — fond blanc, lisibles en prod.
════════════════════════════════════════ */
.overlay {
  position: fixed; top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,.75);
  display: flex; align-items: center; justify-content: center; z-index: 200;
}
.modal {
  background: #fff; padding: 24px;
  width: 520px; max-width: 96vw; border-radius: 8px;
  max-height: 92vh; overflow-y: auto;
  color: #0a0a0a;
}
.modal-sm   { width: 380px; }
.modal-hd   { font-size: 14px; font-weight: 600; margin-bottom: 16px; color: #0a0a0a; }
.modal-ctx  {
  font-size: 11px; color: #666; background: #f5f5f5;
  padding: 6px 10px; border-radius: 3px; margin-bottom: 12px;
}
.lbl {
  display: block; font-size: 11px; color: #666;
  text-transform: uppercase; letter-spacing: .3px;
  margin-bottom: 4px; margin-top: 10px;
}
.inp {
  width: 100%; padding: 8px 10px; border: 1px solid #ddd;
  font-size: 13px; outline: none; box-sizing: border-box;
  font-family: inherit; border-radius: 2px; color: #0a0a0a;
  background: #fff;
}
.inp:focus { border-color: #185FA5; }
.inp:disabled { opacity: .4; cursor: not-allowed; }

.form-row   { display: flex; gap: 12px; }
.form-field { flex: 1; }

.auto-wrap  { position: relative; }
.auto-list  {
  position: absolute; top: 100%; left: 0; right: 0;
  background: #fff; border: 1px solid #ddd; border-radius: 3px;
  box-shadow: 0 4px 12px rgba(0,0,0,.1); z-index: 10;
  max-height: 200px; overflow-y: auto;
}
.auto-item  { display: flex; align-items: center; gap: 8px; padding: 7px 10px; cursor: pointer; font-size: 12px; }
.auto-item:hover { background: #f5f5f5; }
.auto-code  { font-family: 'SF Mono', monospace; font-size: 12px; font-weight: 600; color: #185FA5; min-width: 60px; }
.auto-desc  { color: #666; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.selected-lot { font-size: 12px; color: #1D9E75; padding: 5px 8px; background: #f0fdf4; border-radius: 3px; margin-top: 4px; }

.cadence-preview {
  margin-top: 12px; padding: 10px 14px;
  background: #f8f8f8; border-radius: 4px; border: 1px solid #e8e8e8;
}
.cp-row  { display: flex; justify-content: space-between; padding: 2px 0; font-size: 12px; }
.cp-lbl  { color: #666; }
.cp-val  { font-family: 'SF Mono', monospace; font-weight: 500; color: #0a0a0a; }
.cp-val.obj  { color: #185FA5; font-weight: 600; }
.cp-val.cp-warn { color: #d97706; font-weight: 700; }

.cascade-selects { display: flex; align-items: flex-end; gap: 6px; }
.cs-step { flex: 1; }
.cs-arrow { color: #ccc; font-size: 16px; padding-bottom: 10px; flex-shrink: 0; }

.type-preview {
  display: flex; align-items: center; gap: 8px; margin-top: 8px;
  padding: 8px 12px; background: #fafafa; border-radius: 4px; flex-wrap: wrap;
}
.arret-code-chip {
  font-family: 'SF Mono', monospace; font-size: 10px; font-weight: 600;
  padding: 2px 7px; border-radius: 3px; border: 1px solid;
}
.type-prev-nom { font-size: 12px; font-weight: 500; flex: 1; color: #333; }
.tag { font-size: 10px; padding: 1px 7px; border-radius: 8px; font-weight: 500; white-space: nowrap; }
.tag-plan  { background: #EFF6FF; color: #1D4ED8; }
.tag-pause { background: #F0FDF4; color: #15803D; }
.tag-dur   { background: #FFF7ED; color: #C2410C; font-family: 'SF Mono', monospace; }

.cadence-calc { margin-top: 10px; padding: 10px; background: #f0f7ff; border-radius: 3px; }
.cc-row { display: flex; justify-content: space-between; font-size: 12px; padding: 2px 0; }
.cc-lbl { color: #666; }
.cc-val { font-family: 'SF Mono', monospace; font-weight: 600; color: #0a0a0a; }
.cc-val.ok  { color: #1D9E75; }
.cc-val.bad { color: #EF4444; }

.oee-preview {
  margin-top: 12px; padding: 12px 14px;
  background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 4px;
}
.op-title { font-size: 10px; text-transform: uppercase; letter-spacing: .5px; color: #166534; margin-bottom: 8px; font-weight: 600; }
.op-grid  { display: grid; grid-template-columns: repeat(4,1fr); gap: 8px; text-align: center; }
.op-val   { font-size: 18px; font-weight: 700; font-family: 'SF Mono', monospace; }
.op-lbl   { font-size: 9px; color: #555; text-transform: uppercase; margin-top: 2px; }

/* OEE classes dans modals */
.op-val.oee-green  { color: #1D9E75; }
.op-val.oee-orange { color: #F97316; }
.op-val.oee-red    { color: #EF4444; }

.err {
  color: #E24B4A; font-size: 12px; margin-top: 8px;
  padding: 6px 10px; background: #FEF2F2; border-radius: 3px;
}
.modal-acts { display: flex; gap: 8px; margin-top: 14px; }
.btn-save {
  flex: 1; padding: 10px; background: #185FA5; color: #fff;
  border: none; font-size: 13px; font-weight: 500; cursor: pointer; border-radius: 2px;
}
.btn-save:hover:not(:disabled) { background: #0C447C; }
.btn-save:disabled { opacity: .5; cursor: not-allowed; }
.btn-go   { background: #1D9E75; }
.btn-go:hover:not(:disabled) { background: #158a65; }
.btn-stop { background: #EF4444; }
.btn-stop:hover:not(:disabled) { background: #c53030; }
.btn-close-sess { background: #0a0a0a; }
.btn-close-sess:hover:not(:disabled) { background: #333; }
.btn-warn  { background: #b45309; }
.btn-warn:hover:not(:disabled) { background: #92400e; }
.btn-cancel {
  flex: 1; padding: 10px; background: #f5f5f5; color: #666;
  border: none; font-size: 13px; cursor: pointer; border-radius: 2px;
}
.btn-cancel:hover { background: #eee; }

/* ══ DEV FORM (identique LotDetailPage inline) ══ */
.dev-form{display:flex;flex-direction:column;gap:8px;margin:10px 0}
.dev-form-row{display:flex;align-items:flex-start;gap:10px}
.dev-lbl{font-size:11px;font-weight:600;color:#999;min-width:80px;padding-top:6px;text-transform:uppercase;letter-spacing:.5px}
.dev-input{flex:1;border:1px solid #ddd;padding:6px 8px;font-size:13px;resize:vertical;font-family:inherit;border-radius:2px;background:#fff;color:#0a0a0a}
.dev-input-sm{flex:1;border:1px solid #ddd;padding:6px 8px;font-size:13px;font-family:inherit;border-radius:2px;background:#fff;color:#0a0a0a}
.dev-bloquante-row{align-items:center}
.dev-tog{padding:5px 14px;border:none;border-radius:10px;cursor:pointer;font-size:11px;font-weight:600;font-family:inherit}
.dev-tog-on{background:#FCEBEB;color:#A32D2D}.dev-tog-off{background:#f5f5f5;color:#999}

/* ══ RESPONSIVE ══ */
@media (max-width: 768px) {
  .trs-scroller { -webkit-overflow-scrolling: touch; }
  .cascade-selects { flex-direction: column; gap: 8px; }
  .cs-arrow { display: none; }
  .form-row { flex-direction: column; }
  .btn-save, .btn-cancel, .btn-go, .btn-stop, .btn-close-sess { min-height: 44px; font-size: 14px; }
  .modal-acts { flex-wrap: wrap; }
}

/* ══════════════════════════════════════════
   THÈME JOUR ☀️
══════════════════════════════════════════ */
.trs-live[data-theme="day"] { background: #ffffff; color: #1a1a2e; }
.trs-live[data-theme="day"] .ph { background: #ffffff; border-bottom: 1px solid #d8dce8; }
.trs-live[data-theme="day"] .pt { color: #8896a8; }
.trs-live[data-theme="day"] .pt-clock { color: #185FA5; }
.trs-live[data-theme="day"] .site-tab { border-color: #e5e7eb; color: #6b7280; }
.trs-live[data-theme="day"] .site-tab.active { background: #2563eb; border-color: #2563eb; color: #fff; }
.trs-live[data-theme="day"] .btn-refresh { border-color: #c8ccd8; color: #888; }
.trs-live[data-theme="day"] .btn-refresh:hover { color: #333; }
.trs-live[data-theme="day"] .loading-msg { color: #aaa; }
.trs-live[data-theme="day"] .trs-thead { background: #eff6ff; border-bottom: 1px solid #dbeafe; }
.trs-live[data-theme="day"] .th { color: #2563eb; }
.trs-live[data-theme="day"] .th-trs-h { color: #2563eb; }
.trs-live[data-theme="day"] .trs-row-group { border-bottom-color: #e8eaf3; }
.trs-live[data-theme="day"] .trs-row { background: #ffffff; border-left-color: #e4e7f0; }
.trs-live[data-theme="day"] .trs-row:hover { background: #f0f2f8; }
.trs-live[data-theme="day"] .td { color: #333; }
.trs-live[data-theme="day"] .mach-name { color: #1a1a2e; }
.trs-live[data-theme="day"] .mach-site { color: #aaa; }
.trs-live[data-theme="day"] .lot-n { color: #1a1a2e; }
.trs-live[data-theme="day"] .lot-p { color: #888; }
.trs-live[data-theme="day"] .dim { color: #ccc; }
.trs-live[data-theme="day"] .oee-n { color: #555; }
.trs-live[data-theme="day"] .tmr { color: #555; }
.trs-live[data-theme="day"] .rend-bar { background: #e8eaf3; }
/* Modal */
.trs-live[data-theme="day"] .modal { background: #fff; border: none; box-shadow: 0 8px 32px rgba(0,0,0,.2); }
.trs-live[data-theme="day"] .modal-hd { color: #1a1a2e; }
.trs-live[data-theme="day"] .modal-ctx { background: #f5f6f9; color: #666; }
.trs-live[data-theme="day"] .lbl { color: #999; }
.trs-live[data-theme="day"] .inp { background: #fff; border-color: #c8ccd8; color: #1a1a2e; }
.trs-live[data-theme="day"] .inp:focus { border-color: #185FA5; }
.trs-live[data-theme="day"] .auto-list { background: #fff; border-color: #c8ccd8; box-shadow: 0 4px 16px rgba(0,0,0,.1); }
.trs-live[data-theme="day"] .auto-item:hover { background: #f5f5f8; }
.trs-live[data-theme="day"] .auto-code { color: #185FA5; }
.trs-live[data-theme="day"] .auto-desc { color: #888; }
.trs-live[data-theme="day"] .selected-lot { background: #f0fdf4; color: #1D9E75; }
.trs-live[data-theme="day"] .btn-cancel { background: #f5f5f5; color: #666; }
.trs-live[data-theme="day"] .btn-cancel:hover { background: #eee; }
.trs-live[data-theme="day"] .cadence-preview { background: #f8f9fb; border-color: #e8eaf0; }
.trs-live[data-theme="day"] .cp-lbl { color: #888; }
.trs-live[data-theme="day"] .cp-val { color: #1a1a2e; }
.trs-live[data-theme="day"] .cadence-calc { background: #f0f7ff; }
.trs-live[data-theme="day"] .cc-lbl { color: #888; }
.trs-live[data-theme="day"] .cc-val { color: #1a1a2e; }
.trs-live[data-theme="day"] .oee-preview { background: #f0fdf4; border-color: #bbf7d0; }
.trs-live[data-theme="day"] .err { background: #FEF2F2; color: #c53030; }
.trs-live[data-theme="day"] .type-preview { background: #fafafa; }
.trs-live[data-theme="day"] .type-prev-nom { color: #333; }
/* Éléments manquants en day */
.trs-live[data-theme="day"] .pv { color: #111827; }
.trs-live[data-theme="day"] .theo-row { color: #2563eb; }
.trs-live[data-theme="day"] .arrets-sub { background: #faf9ff; border-left-color: #dbeafe; }
.trs-live[data-theme="day"] .arrets-sub-lbl { color: #2563eb; }
.trs-live[data-theme="day"] .arret-tag { background: #eff6ff; }
.trs-live[data-theme="day"] .at-nom { color: #6b7280; }
.trs-live[data-theme="day"] .at-dur { color: #9ca3af; }

/* ══════════════════════════════════════════
   THÈME ATELIER 🏭
══════════════════════════════════════════ */
.trs-live[data-theme="workshop"] { background: #161616; color: #f0f0f0; }
.trs-live[data-theme="workshop"] .ph { background: #0e0e0e; border-bottom: 1px solid #2a2a2a; }
.trs-live[data-theme="workshop"] .pt { color: #666; letter-spacing: 2px; }
.trs-live[data-theme="workshop"] .pt-clock { color: #00c853; }
.trs-live[data-theme="workshop"] .site-tab { border-color: #2a2a2a; color: #777; }
.trs-live[data-theme="workshop"] .site-tab.active { background: #00c853; border-color: #00c853; color: #000; font-weight: 700; }
.trs-live[data-theme="workshop"] .btn-refresh { border-color: #2a2a2a; color: #777; }
.trs-live[data-theme="workshop"] .btn-refresh:hover { color: #fff; }
.trs-live[data-theme="workshop"] .loading-msg { color: #444; }
.trs-live[data-theme="workshop"] .trs-thead { background: #0e0e0e; border-bottom: 1px solid #2a2a2a; }
.trs-live[data-theme="workshop"] .th { color: #555; }
.trs-live[data-theme="workshop"] .th-trs-h { color: #00c853; font-weight: 900; }
.trs-live[data-theme="workshop"] .trs-row-group { border-bottom-color: #1e1e1e; }
.trs-live[data-theme="workshop"] .trs-row { background: #1a1a1a; border-left-color: #2a2a2a; }
.trs-live[data-theme="workshop"] .trs-row:hover { background: #1e1e1e; }
.trs-live[data-theme="workshop"] .td { color: #e0e0e0; }
.trs-live[data-theme="workshop"] .mach-name { color: #fff; font-weight: 700; }
.trs-live[data-theme="workshop"] .mach-site { color: #555; }
.trs-live[data-theme="workshop"] .lot-n { color: #fff; font-weight: 700; }
.trs-live[data-theme="workshop"] .lot-p { color: #777; }
.trs-live[data-theme="workshop"] .dim { color: #444; }
.trs-live[data-theme="workshop"] .rend-bar { background: #2a2a2a; }
/* Modal */
.trs-live[data-theme="workshop"] .modal { background: #1c1c1c; color: #f0f0f0; }
.trs-live[data-theme="workshop"] .modal-hd { color: #fff; }
.trs-live[data-theme="workshop"] .modal-ctx { background: #111; color: #888; }
.trs-live[data-theme="workshop"] .lbl { color: #666; }
.trs-live[data-theme="workshop"] .inp { background: #111; border-color: #2a2a2a; color: #f0f0f0; }
.trs-live[data-theme="workshop"] .inp:focus { border-color: #ff9800; }
.trs-live[data-theme="workshop"] .auto-list { background: #1c1c1c; border-color: #2a2a2a; }
.trs-live[data-theme="workshop"] .auto-item:hover { background: #222; }
.trs-live[data-theme="workshop"] .auto-code { color: #ff9800; }
.trs-live[data-theme="workshop"] .auto-desc { color: #777; }
.trs-live[data-theme="workshop"] .selected-lot { background: #001a08; color: #00c853; }
.trs-live[data-theme="workshop"] .btn-cancel { background: #1e1e1e; color: #888; border-color: #2a2a2a; }
.trs-live[data-theme="workshop"] .btn-cancel:hover { background: #252525; }
.trs-live[data-theme="workshop"] .cadence-preview { background: #1a1a1a; border-color: #2a2a2a; }
.trs-live[data-theme="workshop"] .cp-lbl { color: #666; }
.trs-live[data-theme="workshop"] .cp-val { color: #f0f0f0; }
.trs-live[data-theme="workshop"] .cadence-calc { background: #1a1200; }
.trs-live[data-theme="workshop"] .cc-lbl { color: #666; }
.trs-live[data-theme="workshop"] .cc-val { color: #f0f0f0; }
.trs-live[data-theme="workshop"] .oee-preview { background: #001a08; border-color: #00c85344; }
.trs-live[data-theme="workshop"] .op-title { color: #00c853; }
.trs-live[data-theme="workshop"] .err { background: #2a0000; color: #ff6b6b; }
.trs-live[data-theme="workshop"] .type-prev-nom { color: #e0e0e0; }

/* ═══════════ VUE MODE LIVE GÉANTE (affichage production plein écran) ═══════════ */
.btn-live-open { background: linear-gradient(90deg,#3b82f6,#8b5cf6); color:#fff; border:none; border-radius:10px;
  font-weight:800; padding:8px 16px; cursor:pointer; font-size:14px; white-space:nowrap; box-shadow:0 2px 12px rgba(59,130,246,.45); }
.btn-live-open:hover { filter: brightness(1.12); }

.live-tv { position: fixed; inset: 0; z-index: 9000;
  background: radial-gradient(circle at 30% -10%, #16213e 0%, #0a0f1d 55%, #05070d 100%);
  color:#e8eef9; display:flex; flex-direction:column; overflow:hidden; }
.ltv-head { display:flex; align-items:center; justify-content:space-between;
  padding: clamp(8px,1.4vh,22px) clamp(16px,3vw,48px); border-bottom:2px solid rgba(255,255,255,.08); background:rgba(255,255,255,.02); }
.ltv-title { font-size: clamp(20px,3.4vw,58px); font-weight:900; letter-spacing:1px;
  background:linear-gradient(90deg,#60a5fa,#a78bfa,#f472b6); -webkit-background-clip:text; background-clip:text; -webkit-text-fill-color:transparent; }
.ltv-clock { font-size: clamp(20px,3vw,54px); font-weight:800; font-variant-numeric:tabular-nums; color:#cbd5e1; letter-spacing:1px; }
.ltv-exit { background:rgba(239,68,68,.15); color:#f87171; border:1px solid rgba(239,68,68,.4); border-radius:12px;
  width:clamp(40px,4vw,60px); height:clamp(40px,4vw,60px); font-size:clamp(18px,2vw,28px); cursor:pointer; line-height:1; }
.ltv-exit:hover { background:rgba(239,68,68,.32); }
.ltv-body { flex:1; min-height:0; display:grid; grid-template-columns:1fr clamp(220px,20vw,380px);
  gap:clamp(8px,1.2vw,22px); padding:clamp(8px,1.2vw,22px); overflow:hidden; }
.ltv-cards { display:grid; gap:clamp(8px,1vw,18px); height:100%; min-height:0; overflow:hidden; }
.ltv-card { position:relative; container-type:size; background:linear-gradient(160deg,rgba(255,255,255,.07),rgba(255,255,255,.02));
  border:2px solid rgba(255,255,255,.10); border-radius:clamp(12px,2cqmin,24px); padding:clamp(8px,4cqmin,24px);
  display:flex; flex-direction:column; justify-content:center; gap:clamp(2px,1.2cqmin,10px); box-shadow:0 6px 30px rgba(0,0,0,.4); overflow:hidden; min-height:0; }
.ltv-card-hd { display:flex; flex-direction:column; align-items:flex-start; gap:clamp(2px,1cqmin,6px); }
.ltv-mach { font-size:clamp(13px,10cqmin,30px); font-weight:800; color:#fff; line-height:1.08; }
.ltv-eq { font-size:clamp(9px,5cqmin,15px); font-weight:700; padding:2px 9px; border-radius:999px; border:1px solid; white-space:nowrap; align-self:flex-start; }
.ltv-lot { font-size:clamp(9px,5.5cqmin,18px); color:#94a3b8; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:100%; }
.ltv-prod { color:#64748b; }
.ltv-rend { font-size:clamp(30px,34cqmin,150px); font-weight:900; line-height:.95; text-align:center; }
.ltv-pct { font-size:.45em; font-weight:800; opacity:.8; }
.ltv-rend-lbl { text-align:center; font-size:clamp(8px,4.5cqmin,15px); letter-spacing:3px; color:#64748b; font-weight:700; margin-top:-2px; }
.rc-win { color:#34d399; text-shadow:0 0 30px rgba(52,211,153,.5); }
.rc-ok  { color:#fbbf24; }
.rc-low { color:#f87171; }
.rc-dim { color:#64748b; }
.ltv-nums { display:flex; justify-content:space-between; gap:4px; margin-top:clamp(3px,1.5cqmin,12px);
  border-top:1px solid rgba(255,255,255,.08); padding-top:clamp(4px,2cqmin,14px); }
.ltv-num { display:flex; flex-direction:column; align-items:center; flex:1; min-width:0; }
.ltv-num b { font-size:clamp(12px,8.5cqmin,28px); font-weight:800; color:#e8eef9; font-variant-numeric:tabular-nums; white-space:nowrap; }
.ltv-num .ltv-theo { color:#60a5fa; }
.ltv-num span { font-size:clamp(7px,3.6cqmin,12px); letter-spacing:.5px; color:#64748b; text-transform:uppercase; white-space:nowrap; }
.ltv-foot { display:flex; align-items:center; justify-content:space-between; gap:8px; margin-top:clamp(2px,1cqmin,8px); }
.ltv-status { font-size:clamp(10px,5cqmin,18px); font-weight:700; color:#94a3b8; }
.ltv-rec { font-size:clamp(10px,5cqmin,18px); font-weight:800; color:#fbbf24; white-space:nowrap; }
.ltv-arr { margin-top:clamp(3px,1.5cqmin,8px); background:rgba(239,68,68,.18); color:#fca5a5; font-weight:700;
  font-size:clamp(9px,5cqmin,18px); padding:clamp(3px,1.5cqmin,8px) clamp(6px,3cqmin,14px); border-radius:10px; text-align:center; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.ltv-win-badge { position:absolute; top:clamp(10px,3cqmin,20px); right:-36px; transform:rotate(35deg);
  background:#16a34a; color:#fff; font-size:clamp(8px,3.4cqmin,13px); font-weight:800; padding:4px 42px; box-shadow:0 2px 10px rgba(0,0,0,.4); letter-spacing:.5px; }
.ltv-empty { grid-column:1/-1; text-align:center; color:#475569; font-size:clamp(18px,2vw,32px); padding:10vh 0; }
.ltv-card.ltv-stop { border-color:#ef4444; animation:ltv-blink 1.1s ease-in-out infinite; }
@keyframes ltv-blink {
  0%,100% { box-shadow:0 8px 40px rgba(0,0,0,.4),0 0 0 rgba(239,68,68,0); border-color:rgba(239,68,68,.45); }
  50%     { box-shadow:0 8px 40px rgba(0,0,0,.4),0 0 55px rgba(239,68,68,.75); border-color:#ef4444; }
}
.ltv-card.ltv-win { border-color:#34d399; animation:ltv-glow 1.8s ease-in-out infinite; }
@keyframes ltv-glow {
  0%,100% { box-shadow:0 8px 40px rgba(0,0,0,.4),0 0 0 rgba(52,211,153,0); }
  50%     { box-shadow:0 8px 40px rgba(0,0,0,.4),0 0 55px rgba(52,211,153,.6); }
}
.ltv-side { display:flex; flex-direction:column; gap:clamp(8px,1.2vw,20px); overflow:hidden; min-height:0; }
.ltv-rank { background:rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.08); border-radius:16px; padding:clamp(8px,1vw,18px); overflow:hidden; min-height:0; flex:1; display:flex; flex-direction:column; }
.ltv-rank-hd { font-size:clamp(13px,1.1vw,20px); font-weight:800; letter-spacing:1px; color:#cbd5e1; margin-bottom:clamp(6px,.8vh,14px); }
.ltv-rank-row { display:flex; align-items:center; gap:10px; padding:clamp(5px,.7vh,11px) 4px; border-bottom:1px solid rgba(255,255,255,.05); }
.ltv-rank-row.first { background:linear-gradient(90deg,rgba(251,191,36,.16),transparent); border-radius:10px; }
.ltv-medal { font-size:clamp(15px,1.3vw,24px); width:1.6em; text-align:center; }
.ltv-team { flex:1; font-size:clamp(13px,1.1vw,22px); font-weight:700; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.ltv-team-rend { font-size:clamp(14px,1.2vw,24px); font-weight:800; font-variant-numeric:tabular-nums; }
.ltv-rank-empty { color:#475569; font-size:clamp(11px,.9vw,15px); padding:8px 4px; }
@media (max-width: 820px) {
  .ltv-body { grid-template-columns:1fr; grid-template-rows:1fr auto; overflow:hidden; }
  .ltv-side { flex-direction:row; max-height:20vh; }
  .ltv-rank { flex:1; }
}
@media (max-width: 480px) {
  .ltv-head { padding:8px 12px; }
}
</style>
