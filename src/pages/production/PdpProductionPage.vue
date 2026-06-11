<template>
  <div class="pdp-prod" :data-theme="theme">

    <!-- ── HEADER ── -->
    <div class="ph">
      <div class="ph-l">
        <span class="pt">PDP PRODUCTION</span>
        <div class="vtabs">
          <button v-for="v in views" :key="v.key" class="vtab" :class="{active:activeView===v.key}" @click="activeView=v.key">
            <span class="vtab-ic">{{v.icon}}</span>{{v.label}}
          </button>
        </div>
      </div>
      <div class="ph-r">
        <!-- Filtre Fab / Condt -->
        <div class="fam-wrap" @click.stop>
          <button class="btn-ref" :class="{'btn-ref-on': hiddenFam.length>0}" @click="showFamPanel=!showFamPanel">
            ⊙ Famille{{hiddenFam.length>0?' ('+hiddenFam.length+')':''}}
          </button>
          <div class="fam-panel" v-if="showFamPanel">
            <div class="fam-title">Visibilité familles</div>
            <label class="fam-item" @click.stop>
              <input type="checkbox" :checked="!hiddenFam.includes('fab')" @change="toggleFam('fab')" @click.stop />
              <span class="fam-dot" style="background:#5B3CC4"></span>
              <span class="fam-lbl">Fabrication</span>
            </label>
            <label class="fam-item" @click.stop>
              <input type="checkbox" :checked="!hiddenFam.includes('cond')" @change="toggleFam('cond')" @click.stop />
              <span class="fam-dot" style="background:#185FA5"></span>
              <span class="fam-lbl">Conditionnement</span>
            </label>
          </div>
        </div>
        <button class="btn-ref" @click="loadAll" :class="{spin:loading}" title="Rafraîchir">↻</button>
        <button class="btn-ref" @click="openGsImport" title="Import Google Sheets">↑ GS</button>
        <button class="btn-ref" @click="openCalModal" title="Calendrier machines (fériés / arrêts / fermetures)">📅 Calendrier</button>
        <button class="btn-ref btn-ref-accent" @click="openBulkModal" title="Saisie PDP en masse (coller depuis Excel)">📋 Saisie en masse</button>
        <button class="btn-ref" @click="cycleTheme" :title="themeTitle">{{themeIcon}}</button>
      </div>
    </div>

    <div v-if="loading && !allSuivis.length && !allArrets.length" class="ldg">Chargement…</div>

    <!-- ════════════════════════════════
         VUE 1 — SUIVI EN COURS
    ════════════════════════════════ -->
    <div v-show="activeView==='suivi'">
      <div class="t-bar">
        <input v-model="suiviSearch" class="t-srch" placeholder="Lot, produit, lieu…" />
        <select v-model="suiviStatut" class="t-sel">
          <option value="">Tous statuts</option>
          <option>Planifié</option><option>En cours</option><option>Arrêt</option><option>Clôturé</option>
        </select>
        <button class="btn-add" @click="openSuiviModal(null,'fab')" v-if="!hiddenFam.includes('fab')">+ Nouveau FAB</button>
        <button class="btn-add btn-add-cond" @click="openSuiviModal(null,'cond')" v-if="!hiddenFam.includes('cond')">+ Nouveau COND</button>
      </div>
      <div class="dt-wrap">
        <table class="dt" v-if="filteredSuivis.length">
          <thead>
            <tr>
              <th>Famille</th>
              <th>Lieu</th>
              <th>N° Lot</th>
              <th>Produit</th>
              <th class="tc">Taille lot</th>
              <th>Date début</th>
              <th>Date fin est.</th>
              <th>Date fin réelle</th>
              <th>Statut</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in filteredSuivis" :key="s._id" :class="'row-'+s.statut.toLowerCase().replace(/\s/g,'-')">
              <td><span class="fam-badge" :class="'fb-'+s.famille">{{s.famille==='fab'?'FAB':'COND'}}</span></td>
              <td class="sm">{{s.lieu}}</td>
              <td class="mono">{{s.numero_lot}}</td>
              <td class="sm">{{s.description}}</td>
              <td class="num">{{s.taille_lot||'—'}}</td>
              <td class="mono sm">{{fmtDate(s.date_debut)}}</td>
              <td class="mono sm" :class="s.famille==='fab'?'dim':''">{{s.famille==='cond'&&s.date_fin_estimee?fmtDate(s.date_fin_estimee):'—'}}</td>
              <td class="mono sm">{{fmtDate(s.date_fin_reelle)}}</td>
              <td><span class="schip" :class="'sc-'+s.statut.toLowerCase().replace(/\s/g,'-')">{{s.statut}}</span></td>
              <td class="acts">
                <button class="ia" @click="openSuiviModal(s, s.famille)" title="Modifier">✏</button>
                <button class="ia" @click="openArretModal(s)" title="Déclarer arrêt" v-if="s.statut==='En cours'">⏸</button>
                <button class="ia ok" @click="clotureSuivi(s)" title="Clôturer" v-if="s.statut==='En cours'||s.statut==='Arrêt'">✓</button>
                <button class="ia del" @click="deleteSuivi(s)" title="Supprimer">✕</button>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-else-if="!loading" class="empty">Aucun suivi trouvé</div>
      </div>
    </div>

    <!-- ════════════════════════════════
         VUE 2 — ARRÊTS
    ════════════════════════════════ -->
    <div v-show="activeView==='arrets'">
      <div class="t-bar">
        <input v-model="arretSearch" class="t-srch" placeholder="Motif, lot…" />
        <select v-model="arretStatutFil" class="t-sel">
          <option value="">Tous</option>
          <option value="actif">En cours</option>
          <option value="cloture">Clôturés</option>
        </select>
        <div class="arr-stats">
          <span class="arr-stat">Total : <b>{{filteredArrets.length}}</b></span>
          <span class="arr-stat arr-run">En cours : <b>{{allArrets.filter(function(a){return !a.heure_fin&&!a.deleted_at}).length}}</b></span>
        </div>
      </div>
      <div class="dt-wrap">
        <table class="dt" v-if="filteredArrets.length">
          <thead>
            <tr>
              <th>Famille</th>
              <th>Lieu</th>
              <th>N° Lot</th>
              <th>Motif</th>
              <th>Début</th>
              <th>Fin</th>
              <th class="tc">Durée</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="a in filteredArrets" :key="a._id" :class="{'row-running':!a.heure_fin}">
              <td><span class="fam-badge" :class="'fb-'+a.famille">{{a.famille==='fab'?'FAB':'COND'}}</span></td>
              <td class="sm">{{a.lieu}}</td>
              <td class="mono">{{a.numero_lot}}</td>
              <td class="sm">{{a.motif}}</td>
              <td class="mono sm">{{fmtDate(a.heure_debut)}}</td>
              <td class="mono sm">{{a.heure_fin?fmtDate(a.heure_fin):'⏱ en cours'}}</td>
              <td class="num">{{arretDuree(a)}}</td>
              <td class="acts">
                <button class="ia ok" @click="closeArret(a)" v-if="!a.heure_fin" title="Clôturer arrêt">✓</button>
                <button class="ia del" @click="deleteArret(a)" title="Supprimer">✕</button>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-else-if="!loading" class="empty">Aucun arrêt trouvé</div>
      </div>
    </div>

    <!-- ════════════════════════════════
         VUE 3 — GÉRER PDP
    ════════════════════════════════ -->
    <div v-show="activeView==='pdp'">
      <div class="t-bar">
        <input v-model="pdpSearch" class="t-srch" placeholder="Lot, produit…" />
        <select v-model="pdpStatutFil" class="t-sel">
          <option value="">Tous statuts</option>
          <option>Planifié</option><option>En cours</option><option>Clôturé</option><option>Annulé</option>
        </select>
      </div>
      <!-- Condt : planification_conditionnement -->
      <div v-if="!hiddenFam.includes('cond')">
        <div class="pdp-section-row">
          <div class="pdp-section-title">Conditionnement — PDP Prévisionnel</div>
          <button class="btn-ref btn-ref-accent" @click="recomputeAllPdp" :disabled="pdpRecomputing" title="Aligner les dates estimées sur les fins réelles et décaler l'aval du retard cumulé">{{pdpRecomputing?'…':'📌 Recaler sur réel'}}</button>
        </div>
        <div class="pdp-err" v-if="pdpErr">{{pdpErr}}</div>
        <div class="dt-wrap">
          <table class="dt" v-if="filteredPdpCond.length">
            <thead>
              <tr>
                <th class="tc">Ordre</th>
                <th>Équipement</th>
                <th>N° Lot</th>
                <th>Produit</th>
                <th class="tc">Taille</th>
                <th>Début est.</th>
                <th>Fin est.</th>
                <th>Fin réelle</th>
                <th class="tc">Retard j</th>
                <th class="tc">TOTAL (j)</th>
                <th class="tc">Cumul (j)</th>
                <th>Libération est.</th>
                <th>Statut</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(p, idx) in filteredPdpCond" :key="p.id" :class="{'row-annule':p.statut_planification==='Annulé'}">
                <td class="num">{{p.ordre_plan||'—'}}</td>
                <td class="sm">{{p.nom_equipement||'—'}}</td>
                <td class="mono">{{p.numero_lot||'—'}}</td>
                <td class="sm">{{p.code_article||'—'}}</td>
                <td class="num mono">{{p.taille_lot?p.taille_lot.toLocaleString('fr-FR'):'—'}}</td>
                <td class="mono sm">{{fmtDate(p.date_debut_estimee)}}</td>
                <td class="mono sm">{{fmtDate(p.date_fin_estimee)}}</td>
                <td><input type="date" v-model="p.date_fin_reelle" @paste="onReelPaste($event, idx)" @change="savePdpReelle(p)" class="pdp-reel-inp" /></td>
                <td class="num" :class="{'bg-retard':p.retard_jours>0,'bg-avance':p.retard_jours<0}">{{p.retard_jours?(p.retard_jours>0?'+'+p.retard_jours:p.retard_jours):(p.date_fin_reelle?'0':'—')}}</td>
                <td class="num">{{p.total_prod_jours!=null?p.total_prod_jours:(p.duree_estimee_jours||'—')}}</td>
                <td class="num">{{p.total_cml!=null?p.total_cml:'—'}}</td>
                <td class="mono sm">{{fmtDate(p.date_liberation)}}</td>
                <td><span class="schip" :class="'sc-'+(p.statut_planification||'').toLowerCase().replace(/\s/g,'-')">{{p.statut_planification}}</span></td>
                <td class="acts">
                  <button class="ia del" @click="deletePdpCond(p)" title="Supprimer">✕</button>
                </td>
              </tr>
            </tbody>
          </table>
          <div v-else-if="!loading" class="empty">Aucun planning conditionnement</div>
        </div>
      </div>
      <!-- Fab : suivi_fabrication (Planifié uniquement) -->
      <div v-if="!hiddenFam.includes('fab')">
        <div class="pdp-section-title">Fabrication — Lots planifiés</div>
        <div class="dt-wrap">
          <table class="dt" v-if="filteredPdpFab.length">
            <thead>
              <tr>
                <th>Atelier</th>
                <th>N° Lot</th>
                <th>Produit</th>
                <th>Date début</th>
                <th>Statut</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="sf in filteredPdpFab" :key="sf.id">
                <td class="sm">{{sf.nom_atelier||'—'}}</td>
                <td class="mono">{{sf.lots&&sf.lots.numero_lot||'—'}}</td>
                <td class="sm">{{sf.lots&&sf.lots.products&&sf.lots.products.description||'—'}}</td>
                <td class="mono sm">{{fmtDate(sf.date_debut)}}</td>
                <td><span class="schip" :class="'sc-'+sf.statut.toLowerCase().replace(/\s/g,'-')">{{sf.statut}}</span></td>
                <td class="acts">
                  <button class="ia" @click="openSuiviModal({rawId:sf.id,famille:'fab',raw_fab:sf},'fab')" title="Modifier">✏</button>
                </td>
              </tr>
            </tbody>
          </table>
          <div v-else-if="!loading" class="empty">Aucun lot planifié en fabrication</div>
        </div>
      </div>
    </div>

    <!-- ══ MODAL SUIVI FAB ══ -->
    <div class="ov" v-if="suiviModal.show && suiviModal.famille==='fab'" @click.self="suiviModal.show=false">
      <div class="modal">
        <div class="modal-hd">{{suiviModal.id?'Modifier suivi FAB':'Nouveau suivi FAB'}}</div>
        <label class="lbl">N° Lot *</label>
        <div class="auto-wrap">
          <input v-model="suiviModal.lotSearch" class="inp" placeholder="Rechercher lot…" @input="searchLots" :disabled="!!suiviModal.id" />
          <div class="auto-list" v-if="lotSuggestions.length">
            <div v-for="l in lotSuggestions" :key="l.id" class="auto-item" @mousedown.prevent="selectLot(l)">
              <span class="auto-code">{{l.numero_lot}}</span> {{l.description}}
            </div>
          </div>
        </div>
        <label class="lbl">Atelier *</label>
        <select v-model="suiviModal.atelier_id" class="inp">
          <option value="">— Choisir —</option>
          <option v-for="at in ateliers" :key="at.id" :value="at.id">{{at.nom_atelier}}</option>
        </select>
        <label class="lbl">Date début</label>
        <input type="date" v-model="suiviModal.date_debut" class="inp" />
        <label class="lbl">Date fin réelle</label>
        <input type="date" v-model="suiviModal.date_fin" class="inp" />
        <label class="lbl">Statut</label>
        <select v-model="suiviModal.statut" class="inp">
          <option>Planifié</option><option>En cours</option><option>Arrêt</option><option>Clôturé</option>
        </select>
        <div class="modal-err" v-if="suiviModal.err">{{suiviModal.err}}</div>
        <div class="modal-acts">
          <button class="btn-save" @click="saveSuiviFab" :disabled="suiviModal.saving">{{suiviModal.saving?'…':'Enregistrer'}}</button>
          <button class="btn-cancel" @click="suiviModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL SUIVI CONDT ══ -->
    <div class="ov" v-if="suiviModal.show && suiviModal.famille==='cond'" @click.self="suiviModal.show=false">
      <div class="modal">
        <div class="modal-hd">{{suiviModal.id?'Modifier suivi COND':'Nouveau suivi COND'}}</div>
        <label class="lbl">N° Lot *</label>
        <div class="auto-wrap">
          <input v-model="suiviModal.lotSearch" class="inp" placeholder="Rechercher lot…" @input="searchLots" :disabled="!!suiviModal.id" />
          <div class="auto-list" v-if="lotSuggestions.length">
            <div v-for="l in lotSuggestions" :key="l.id" class="auto-item" @mousedown.prevent="selectLot(l)">
              <span class="auto-code">{{l.numero_lot}}</span> {{l.description}}
            </div>
          </div>
        </div>
        <label class="lbl">Équipement *</label>
        <select v-model="suiviModal.equipement_id" class="inp">
          <option value="">— Choisir —</option>
          <option v-for="eq in equipements" :key="eq.id" :value="eq.id">{{eq.nom_equipement}}</option>
        </select>
        <label class="lbl">Taille lot</label>
        <input type="number" v-model.number="suiviModal.taille_lot" class="inp" placeholder="Ex: 500000" />
        <label class="lbl">Date début</label>
        <input type="date" v-model="suiviModal.date_debut" class="inp" />
        <label class="lbl">Date fin estimée (PDP)</label>
        <input type="date" v-model="suiviModal.date_fin_estimee" class="inp" />
        <label class="lbl">Date fin réelle</label>
        <input type="date" v-model="suiviModal.date_fin" class="inp" />
        <label class="lbl">Statut</label>
        <select v-model="suiviModal.statut" class="inp">
          <option>Planifié</option><option>En cours</option><option>Arrêt</option><option>Clôturé</option>
        </select>
        <div class="modal-err" v-if="suiviModal.err">{{suiviModal.err}}</div>
        <div class="modal-acts">
          <button class="btn-save" @click="saveSuiviCond" :disabled="suiviModal.saving">{{suiviModal.saving?'…':'Enregistrer'}}</button>
          <button class="btn-cancel" @click="suiviModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL ARRÊT ══ -->
    <div class="ov" v-if="arretModal.show" @click.self="arretModal.show=false">
      <div class="modal">
        <div class="modal-hd">⏸ Déclarer arrêt — {{arretModal.lieu}}</div>
        <div class="modal-ctx">{{arretModal.numero_lot}}</div>
        <label class="lbl">Motif *</label>
        <textarea v-model="arretModal.motif" class="inp" rows="2" placeholder="Motif de l'arrêt…"></textarea>
        <label class="lbl">Date début</label>
        <input type="date" v-model="arretModal.heure_debut" class="inp" />
        <div class="modal-err" v-if="arretModal.err">{{arretModal.err}}</div>
        <div class="modal-acts">
          <button class="btn-save btn-warn" @click="saveArret" :disabled="arretModal.saving">{{arretModal.saving?'…':'Déclarer'}}</button>
          <button class="btn-cancel" @click="arretModal.show=false">Annuler</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL CALENDRIER MACHINES ══ -->
    <div class="ov" v-if="calModal.show" @click.self="calModal.show=false">
      <div class="modal modal-wide">
        <div class="modal-hd">📅 Calendrier machines — fériés / arrêts / fermetures</div>
        <div class="modal-ctx">Jours non ouvrés pris en compte dans le calcul des dates PDP (en plus des week-ends, gérés par machine).</div>
        <div class="cal-form">
          <div class="cal-f-row">
            <div class="cal-f-col cal-f-2">
              <label class="lbl">Machine</label>
              <select v-model="calForm.equipement_id" class="inp">
                <option value="">Toutes les machines</option>
                <option v-for="eq in equipements" :key="eq.id" :value="eq.id">{{eq.nom_equipement}}</option>
              </select>
            </div>
            <div class="cal-f-col">
              <label class="lbl">Type</label>
              <select v-model="calForm.type" class="inp">
                <option value="ferie">Jour férié</option>
                <option value="arret_annuel">Arrêt annuel</option>
                <option value="fermeture">Fermeture</option>
                <option value="maintenance">Maintenance</option>
              </select>
            </div>
          </div>
          <div class="cal-f-row">
            <div class="cal-f-col"><label class="lbl">Du *</label><input type="date" v-model="calForm.date_debut" class="inp" /></div>
            <div class="cal-f-col"><label class="lbl">Au</label><input type="date" v-model="calForm.date_fin" class="inp" /></div>
            <div class="cal-f-col cal-f-2"><label class="lbl">Libellé</label><input type="text" v-model="calForm.libelle" class="inp" placeholder="Ex : Aïd, congés août…" /></div>
          </div>
          <div class="modal-err" v-if="calModal.err">{{calModal.err}}</div>
          <button class="btn-save" @click="addCalEntry" :disabled="calModal.saving||!calForm.date_debut">{{calModal.saving?'…':'+ Ajouter au calendrier'}}</button>
        </div>
        <div class="dt-wrap cal-list">
          <table class="dt" v-if="calEntries.length">
            <thead><tr><th>Machine</th><th>Type</th><th>Du</th><th>Au</th><th>Libellé</th><th></th></tr></thead>
            <tbody>
              <tr v-for="c in calEntries" :key="c.id">
                <td class="sm">{{c.nom_equipement}}</td>
                <td><span class="schip" :class="'cal-t-'+c.type">{{CAL_TYPE_LABELS[c.type]||c.type}}</span></td>
                <td class="mono sm">{{fmtDate(c.date_debut)}}</td>
                <td class="mono sm">{{fmtDate(c.date_fin)}}</td>
                <td class="sm">{{c.libelle||'—'}}</td>
                <td class="acts"><button class="ia del" @click="deleteCalEntry(c)" title="Supprimer">✕</button></td>
              </tr>
            </tbody>
          </table>
          <div v-else class="empty">Aucune entrée — ajoute les fériés, arrêts annuels et fermetures.</div>
        </div>
        <div class="modal-acts"><button class="btn-cancel" @click="calModal.show=false">Fermer</button></div>
      </div>
    </div>

    <!-- ══ MODAL SAISIE PDP EN MASSE ══ -->
    <div class="ov" v-if="bulkModal.show" @click.self="bulkModal.show=false">
      <div class="modal modal-xwide">
        <div class="modal-hd">📋 Saisie PDP en masse</div>
        <div class="modal-ctx">Colle depuis Excel (colonne par colonne, ou un bloc entier) — la désignation remonte du code produit. N° lot facultatif (renseigné → lot créé façon « Planifier », visible dans Lots). En conditionnement, <b>🧮 Calculer</b> remplit dates de fin estimées + charge (TP/THP/TOTAL/cumul) selon le référentiel machine et le calendrier.</div>

        <div class="bulk-ctrl">
          <div class="bulk-fam">
            <button class="bulk-fam-btn" :class="{on:bulkModal.famille==='cond'}" @click="bulkSetFamille('cond')">Conditionnement</button>
            <button class="bulk-fam-btn" :class="{on:bulkModal.famille==='fab'}" @click="bulkSetFamille('fab')">Fabrication</button>
          </div>
          <select v-model="bulkModal.lieu_id" class="inp bulk-lieu">
            <option value="">— {{bulkModal.famille==='fab'?'Atelier / salle':'Équipement / machine'}} —</option>
            <option v-for="l in bulkLieuList" :key="l.id" :value="l.id">{{l.nom}}</option>
          </select>
          <template v-if="bulkModal.famille==='cond'">
            <label class="bulk-il">Début planning <input type="date" v-model="bulkModal.plan_start" class="inp bulk-mini" /></label>
            <label class="bulk-il">Nb shift défaut
              <select v-model="bulkModal.def_shift" class="inp bulk-mini"><option value="1">1</option><option value="2">2</option><option value="3">3</option></select>
            </label>
          </template>
        </div>

        <!-- Insertion campagne -->
        <div class="camp-panel" v-if="campPanel.show">
          <div class="camp-row">
            <div class="camp-f camp-code auto-wrap">
              <label class="bulk-il">Code produit</label>
              <input v-model="campPanel.code" @input="campSearchCode" class="inp bulk-mini" placeholder="PFABB10" />
              <div class="auto-list" v-if="campSuggest.length">
                <div v-for="s in campSuggest" :key="s.id" class="auto-item" @mousedown.prevent="campSelectProduct(s)">
                  <span class="auto-code">{{s.code_article}}</span> {{s.description}}
                </div>
              </div>
            </div>
            <div class="camp-f camp-desg-f"><label class="bulk-il">Désignation</label><div class="camp-desg-v">{{campPanel.designation||'—'}}</div></div>
            <div class="camp-f">
              <label class="bulk-il">Taille lot{{campPanel.tailleOpts.length?' (GS)':''}}</label>
              <select v-if="campPanel.tailleOpts.length" v-model="campPanel.taille" class="inp bulk-mini">
                <option value="">—</option>
                <option v-for="t in campPanel.tailleOpts" :key="t" :value="t">{{t.toLocaleString('fr-FR')}}</option>
              </select>
              <input v-else v-model="campPanel.taille" class="inp bulk-mini" placeholder="UN" />
            </div>
            <div class="camp-f"><label class="bulk-il">Nb lots</label><input v-model="campPanel.nb" class="inp bulk-mini bg-w40" /></div>
            <div class="camp-f"><label class="bulk-il">N° lot début (opt.)</label><input v-model="campPanel.lot_debut" class="inp bulk-mini" placeholder="ex 251050" /></div>
            <button class="btn-save" @click="campInsert">Insérer</button>
            <button class="btn-cancel" @click="campPanel.show=false">Annuler</button>
          </div>
          <div class="modal-err" v-if="campPanel.err">{{campPanel.err}}</div>
          <div class="camp-hint">Génère {{campPanel.nb||0}} ligne(s) du produit dans la grille{{campPanel.lot_debut?' — lots '+campPanel.lot_debut+'→'+((parseInt(campPanel.lot_debut)||0)+((parseInt(campPanel.nb)||1)-1))+' (créés façon « Planifier » à l\'enregistrement)':' — sans n° lot'}}.</div>
        </div>

        <div class="bulk-grid-wrap">
          <table class="bulk-grid">
            <thead>
              <tr>
                <th class="bg-idx">#</th>
                <th>Code produit</th>
                <th>Désignation</th>
                <th>N° Lot</th>
                <th>Taille</th>
                <template v-if="bulkModal.famille==='cond'">
                  <th title="Cadence boîtes/minute (référentiel cadences)">Cad b/min</th>
                  <th title="Nombre de shifts">Shift</th>
                  <th title="Total = début campagne · Partiel = même produit que le lot précédent">Vide ligne</th>
                  <th title="Temps de production utile (jours)">TP</th>
                  <th title="Temps arrêts planifiés (jours)">THP</th>
                  <th title="TP + THP (jours)">TOTAL</th>
                  <th title="Cumul charge machine (jours)">CML</th>
                </template>
                <th>Début{{bulkModal.famille==='cond'?' est.':''}}</th>
                <th>Fin{{bulkModal.famille==='cond'?' est.':''}}</th>
                <template v-if="bulkModal.famille==='cond'">
                  <th title="Date de fin réelle (saisie quotidienne planification)">Fin réelle</th>
                  <th title="Retard = jours ouvrés (fin réelle − fin estimée)">Retard j</th>
                  <th title="Accepté (réel) > date cible > fin +15j">Libération</th>
                  <th title="Date de libération cible (manuelle)">Cible</th>
                </template>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(r,i) in bulkRows" :key="i" :class="{'bg-unknown-row':r._status==='unknown'}">
                <td class="bg-idx">{{i+1}}</td>
                <td><input v-model="r.code" @paste="onBulkPaste($event,i,'code')" @blur="bulkResolveDesignations" class="bg-inp mono" placeholder="PFABB10" /></td>
                <td class="bg-desg" :class="{warn:r._status==='unknown'}">{{r.designation||'—'}}</td>
                <td><input v-model="r.numero_lot" @paste="onBulkPaste($event,i,'numero_lot')" class="bg-inp mono" placeholder="(option.)" /></td>
                <td><input v-model="r.taille" @paste="onBulkPaste($event,i,'taille')" class="bg-inp mono bg-num" placeholder="UN" /></td>
                <template v-if="bulkModal.famille==='cond'">
                  <td><input v-model="r.cadence" class="bg-inp mono bg-num" placeholder="auto" /></td>
                  <td><input v-model="r.nb_shift" class="bg-inp mono bg-num bg-w40" :placeholder="bulkModal.def_shift" /></td>
                  <td>
                    <select v-model="r.vide_ligne" @change="r.vide_ligne_auto=false" class="bg-inp bg-sel" :class="'vl-'+(r.vide_ligne||'').toLowerCase()">
                      <option value="">auto</option><option value="Total">Total</option><option value="Partiel">Partiel</option>
                    </select>
                  </td>
                  <td class="bg-calc">{{r.tp!=null?r.tp:'—'}}</td>
                  <td class="bg-calc">{{r.thp!=null?r.thp:'—'}}</td>
                  <td class="bg-calc bg-strong">{{r.total!=null?r.total:'—'}}</td>
                  <td class="bg-calc">{{r.cml!=null?r.cml:'—'}}</td>
                </template>
                <td><input v-model="r.date_debut" @paste="onBulkPaste($event,i,'date_debut')" class="bg-inp mono bg-date" placeholder="jj/mm/aaaa" /></td>
                <td><input v-model="r.date_fin" @paste="onBulkPaste($event,i,'date_fin')" class="bg-inp mono bg-date" placeholder="jj/mm/aaaa" /></td>
                <template v-if="bulkModal.famille==='cond'">
                  <td><input v-model="r.date_fin_reelle" @paste="onBulkColPaste($event,i,'date_fin_reelle')" class="bg-inp mono bg-reel bg-date" placeholder="jj/mm/aaaa" /></td>
                  <td class="bg-calc" :class="{'bg-retard':r.retard>0,'bg-avance':r.retard<0}">{{r.retard!=null?(r.retard>0?'+'+r.retard:r.retard):'—'}}</td>
                  <td class="bg-calc bg-date">{{r.liberation?fmtDate(r.liberation):'—'}}<span v-if="r.lib_src" class="lib-src">{{r.lib_src}}</span></td>
                  <td><input v-model="r.date_cible" @paste="onBulkColPaste($event,i,'date_cible')" class="bg-inp mono bg-date" placeholder="jj/mm/aaaa" /></td>
                </template>
                <td class="acts"><button class="ia del" @click="bulkRemoveRow(i)" title="Supprimer la ligne">✕</button></td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="bulk-foot">
          <button class="btn-ref" @click="bulkAddRow">+ Ligne</button>
          <button class="btn-ref" @click="openCampPanel">➕ Insérer campagne</button>
          <button class="btn-ref" @click="bulkResolveDesignations">↻ Désignations</button>
          <button v-if="bulkModal.famille==='cond'" class="btn-ref btn-ref-accent" @click="bulkCompute">🧮 Calculer</button>
          <button class="btn-ref" @click="bulkClear">Vider</button>
          <span v-if="bulkModal.computed" class="bulk-hint">Dates &amp; charge calculées — vérifie puis « Créer le PDP ».</span>
        </div>
        <div v-if="bulkModal.cont_info" class="bulk-cont">↪ {{bulkModal.cont_info}}</div>

        <div class="modal-err" v-if="bulkModal.err">{{bulkModal.err}}</div>
        <div class="bulk-result" v-if="bulkModal.result">
          ✓ {{bulkModal.result.lignes}} ligne(s) PDP · {{bulkModal.result.lots}} lot(s) créé(s) · {{bulkModal.result.skipped}} lot(s) déjà existant(s) · {{bulkModal.result.errors}} erreur(s)
        </div>

        <div class="modal-acts">
          <button class="btn-save" @click="bulkSave" :disabled="bulkModal.saving">{{bulkModal.saving?(bulkModal.progress||'…'):'Créer le PDP'}}</button>
          <button class="btn-cancel" @click="bulkModal.show=false">Fermer</button>
        </div>
      </div>
    </div>

    <!-- ══ MODAL IMPORT GS ══ -->
    <div class="ov" v-if="gsModal.show" @click.self="gsModal.show=false">
      <div class="modal modal-wide">
        <div class="modal-hd">↑ Import Google Sheets — PDP Production</div>
        <div class="modal-ctx">
          URL : <code class="gs-url">{{GS_URL}}</code>
        </div>
        <div class="gs-cols">Colonnes détectées : <b>Equipement · Numéro d'article · Description article · Lot interne · Prévisionnel [UN] · Date fin estimée · Date début · Date fin réelle</b></div>
        <button class="btn-gs-fetch" @click="fetchGsData" :disabled="gsModal.fetching">
          {{gsModal.fetching?'⟳ Chargement…':'↓ Charger les données'}}
        </button>
        <div class="gs-err" v-if="gsModal.err">{{gsModal.err}}</div>
        <!-- Prévisualisation -->
        <div v-if="gsModal.preview.length" class="gs-preview">
          <div class="gs-prev-title">{{gsModal.preview.length}} lignes — Prévisualisation :</div>
          <div class="dt-wrap gs-prev-wrap">
            <table class="dt">
              <thead>
                <tr>
                  <th>Famille</th>
                  <th>Équipement</th>
                  <th>Lot</th>
                  <th>Produit</th>
                  <th class="tc">Taille</th>
                  <th>Début</th>
                  <th>Fin est.</th>
                  <th>Fin réelle</th>
                  <th>État</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(r,i) in gsModal.preview" :key="i" :class="r._err?'row-err':''">
                  <td><span v-if="r._famille" class="fam-badge" :class="'fb-'+r._famille">{{r._famille==='fab'?'FAB':'COND'}}</span><span v-else class="gs-err-badge">?</span></td>
                  <td class="sm">{{r.Equipement}}</td>
                  <td class="mono">{{r._lot}}</td>
                  <td class="sm">{{r._description}}</td>
                  <td class="num">{{r._taille}}</td>
                  <td class="mono sm">{{r._date_debut}}</td>
                  <td class="mono sm">{{r._date_fin_est}}</td>
                  <td class="mono sm">{{r._date_fin}}</td>
                  <td class="sm">{{r._err||'✓'}}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="gs-warn" v-if="gsModal.preview.some(function(r){return r._err})">
            ⚠ Certaines lignes ont des équipements non reconnus et seront ignorées.
          </div>
        </div>
        <div class="modal-acts" v-if="gsModal.preview.length">
          <button class="btn-save" @click="confirmGsImport" :disabled="gsModal.saving">
            {{gsModal.saving?'…':'Importer '+gsModal.preview.filter(function(r){return !r._err}).length+' lignes'}}
          </button>
          <button class="btn-cancel" @click="gsModal.show=false">Annuler</button>
        </div>
        <div class="modal-acts" v-else>
          <button class="btn-cancel" @click="gsModal.show=false">Fermer</button>
        </div>
      </div>
    </div>

  </div>
</template>

<script>
import { ref, reactive, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { useTheme } from '../../composables/useTheme'
import { checkProductFluxEquipName, checkUpstreamForEquip, checkUpstreamForAtelier, stageLabels } from '../../services/flux'
import { loadPermissions, canPerform } from '../../services/permissions'

var GS_URL = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vQqKb5_i0U7YeQYMiNEDy4X2gq6W_78NA2EuC2gRqSVXOKuBcBuXR8ASrE9Eq3admceATv4_gdAUppc/pub?gid=1634438429&single=true&output=csv'

export default {
  setup() {
    var { theme } = useTheme()

    // ── Thème cycle ──
    var THEME_ORDER = ['night', 'day', 'workshop']
    var cycleTheme = function() {
      var idx = THEME_ORDER.indexOf(theme.value)
      theme.value = THEME_ORDER[(idx + 1) % THEME_ORDER.length]
    }
    var themeIcon = computed(function() {
      return theme.value === 'day' ? '☀️' : theme.value === 'workshop' ? '🏭' : '🌙'
    })
    var themeTitle = computed(function() {
      return theme.value === 'night' ? 'Nuit → Jour' : theme.value === 'day' ? 'Jour → Atelier' : 'Atelier → Nuit'
    })

    // ── État ──
    var loading       = ref(false)
    var activeView    = ref('suivi')
    var views = [
      { key: 'suivi',  icon: '▥', label: 'Suivi en cours' },
      { key: 'arrets', icon: '⚠', label: 'Arrêts' },
      { key: 'pdp',    icon: '☰', label: 'Gérer PDP' }
    ]

    // Filtre famille
    var hiddenFam    = ref(JSON.parse(localStorage.getItem('pdp_hidden_fam') || '[]'))
    var showFamPanel = ref(false)
    var toggleFam    = function(key) {
      var idx = hiddenFam.value.indexOf(key)
      if (idx >= 0) hiddenFam.value.splice(idx, 1)
      else hiddenFam.value.push(key)
      localStorage.setItem('pdp_hidden_fam', JSON.stringify(hiddenFam.value))
    }

    // Données brutes
    var suiviFab    = ref([])
    var suiviCond   = ref([])
    var arretsFab   = ref([])
    var arretsCond  = ref([])
    var pdpCond     = ref([])
    var ateliers    = ref([])
    var equipements = ref([])
    var planRooms   = ref([])
    var gsRefMap    = ref({})   // equipment_name.toLowerCase() → { id_supabase, type }
    var calcRef     = ref({})   // equipment_name.toLowerCase() → params calcul (temps_util, to_shift_min, vdlc/vdlp/chgt/reglage/micro)
    var cadenceList = ref([])   // table cadences (equipment_name × code_article × taille_lot)
    var calAll      = ref([])   // calendrier_machine (jours non ouvrés)
    var lotSuggestions = ref([])
    var lotTimeout  = null

    // ── Helpers ──
    var fmtDt = function(d) {
      if (!d) return '—'
      var dt = new Date(d)
      var p = function(v) { return String(v).padStart(2, '0') }
      return p(dt.getDate()) + '/' + p(dt.getMonth() + 1) + '/' + dt.getFullYear() + ' ' + p(dt.getHours()) + ':' + p(dt.getMinutes())
    }
    var fmtDate = function(d) {
      if (!d) return '—'
      var p = d.slice(0, 10).split('-')
      return p.length === 3 ? p[2] + '/' + p[1] + '/' + p[0] : d
    }
    var arretDuree = function(a) {
      if (!a.heure_debut) return '—'
      var end = a.heure_fin ? new Date(a.heure_fin) : new Date()
      var jours = Math.max(0, Math.round((end - new Date(a.heure_debut)) / 86400000))
      return jours <= 0 ? '< 1 j' : (jours + (jours > 1 ? ' jours' : ' jour'))
    }
    var getAtelierNom = function(id) {
      var at = ateliers.value.find(function(a) { return a.id === id })
      return at ? at.nom_atelier : '—'
    }
    var getEquipNom = function(id) {
      var eq = equipements.value.find(function(e) { return e.id === id })
      return eq ? eq.nom_equipement : '—'
    }

    // ── Données normalisées ──
    var allSuivis = computed(function() {
      var result = []
      if (!hiddenFam.value.includes('fab')) {
        suiviFab.value.forEach(function(sf) {
          result.push({
            _id: 'fab_' + sf.id, rawId: sf.id, famille: 'fab',
            lieu: getAtelierNom(sf.atelier_id),
            lot_id: sf.lot_id,
            numero_lot: sf.lots ? sf.lots.numero_lot : '—',
            description: sf.lots && sf.lots.products ? sf.lots.products.description : '—',
            taille_lot: null,
            date_debut: sf.date_debut,
            date_fin_estimee: null,
            date_fin_reelle: sf.date_fin,
            statut: sf.statut || 'En cours',
            raw_fab: sf
          })
        })
      }
      if (!hiddenFam.value.includes('cond')) {
        suiviCond.value.forEach(function(sc) {
          result.push({
            _id: 'cond_' + sc.id, rawId: sc.id, famille: 'cond',
            lieu: getEquipNom(sc.equipement_id),
            lot_id: sc.lot_id,
            numero_lot: sc.lots ? sc.lots.numero_lot : '—',
            description: sc.lots && sc.lots.products ? sc.lots.products.description : '—',
            taille_lot: sc.taille_lot,
            date_debut: sc.date_debut,
            date_fin_estimee: sc.date_fin_estimee,
            date_fin_reelle: sc.date_fin,
            statut: sc.statut || 'En cours',
            raw_cond: sc
          })
        })
      }
      return result
    })

    var allArrets = computed(function() {
      var result = []
      if (!hiddenFam.value.includes('fab')) {
        arretsFab.value.forEach(function(a) {
          result.push(Object.assign({}, a, {
            _id: 'fab_' + a.id, famille: 'fab',
            lieu: getAtelierNom(a.atelier_id),
            numero_lot: a.lots ? a.lots.numero_lot : '—'
          }))
        })
      }
      if (!hiddenFam.value.includes('cond')) {
        arretsCond.value.forEach(function(a) {
          result.push(Object.assign({}, a, {
            _id: 'cond_' + a.id, famille: 'cond',
            lieu: getEquipNom(a.equipement_id),
            numero_lot: a.lots ? a.lots.numero_lot : '—'
          }))
        })
      }
      return result.sort(function(a, b) { return new Date(b.heure_debut || 0) - new Date(a.heure_debut || 0) })
    })

    // ── Filtres ──
    var suiviSearch  = ref(''), suiviStatut   = ref('')
    var arretSearch  = ref(''), arretStatutFil = ref('')
    var pdpSearch    = ref(''), pdpStatutFil   = ref('')

    var filteredSuivis = computed(function() {
      var q = suiviSearch.value.toLowerCase()
      return allSuivis.value.filter(function(s) {
        if (suiviStatut.value && s.statut !== suiviStatut.value) return false
        if (!q) return true
        return (s.numero_lot||'').toLowerCase().includes(q) ||
               (s.description||'').toLowerCase().includes(q) ||
               (s.lieu||'').toLowerCase().includes(q)
      })
    })

    var filteredArrets = computed(function() {
      var q = arretSearch.value.toLowerCase()
      return allArrets.value.filter(function(a) {
        if (arretStatutFil.value === 'actif' && a.heure_fin) return false
        if (arretStatutFil.value === 'cloture' && !a.heure_fin) return false
        if (!q) return true
        return (a.motif||'').toLowerCase().includes(q) ||
               (a.numero_lot||'').toLowerCase().includes(q)
      })
    })

    var filteredPdpCond = computed(function() {
      var q = pdpSearch.value.toLowerCase()
      return pdpCond.value.filter(function(p) {
        if (pdpStatutFil.value && p.statut_planification !== pdpStatutFil.value) return false
        if (!q) return true
        return (p.numero_lot||'').toLowerCase().includes(q) ||
               (p.code_article||'').toLowerCase().includes(q)
      })
    })

    var filteredPdpFab = computed(function() {
      var q = pdpSearch.value.toLowerCase()
      return suiviFab.value.filter(function(sf) {
        if (sf.statut !== 'Planifié') return false
        if (!q) return true
        var lot = sf.lots ? sf.lots.numero_lot : ''
        var prod = sf.lots && sf.lots.products ? sf.lots.products.description : ''
        return (lot||'').toLowerCase().includes(q) || (prod||'').toLowerCase().includes(q)
      })
    })

    // ── LOAD ──
    var loadAll = async function() {
      loading.value = true
      var [rOm, rAt, rEq, rPR, rSF, rSC, rAF, rAC, rPC, rCad, rCal] = await Promise.all([
        supabase.from('operations_master').select('id,equipment_name,processus,temps_util,to_shift_min,vdlp_min,vdlc_min,chgt_format_min,reglage_min,micro_arrets_min'),
        supabase.from('ateliers').select('id,nom_atelier').eq('actif', true).order('nom_atelier'),
        supabase.from('equipements_conditionnement').select('id,nom_equipement,travaille_weekend,cadence_objectif_boite_min').eq('actif', true).order('ordre_affichage'),
        supabase.from('plan_rooms').select('id,code,nom,atelier_id,equipement_id'),
        supabase.from('suivi_fabrication')
          .select('id,lot_id,atelier_id,statut,date_debut,date_fin,lots(numero_lot,products(description))')
          .is('deleted_at', null).order('date_debut', {ascending: false}),
        supabase.from('suivi_conditionnement')
          .select('id,lot_id,equipement_id,statut,date_debut,date_fin,date_fin_estimee,taille_lot,lots(numero_lot,products(description))')
          .is('deleted_at', null).order('date_debut', {ascending: false}),
        supabase.from('atelier_arrets')
          .select('id,atelier_id,lot_id,motif,heure_debut,heure_fin,lots(numero_lot)')
          .is('deleted_at', null).order('heure_debut', {ascending: false}),
        supabase.from('arret_conditionnement')
          .select('id,suivi_id,equipement_id,lot_id,motif,heure_debut,heure_fin,lots(numero_lot)')
          .is('deleted_at', null).order('heure_debut', {ascending: false}),
        supabase.from('planification_conditionnement')
          .select('id,lot_id,product_id,equipement_id,ordre_plan,statut_planification,date_debut_estimee,date_fin_estimee,duree_estimee_jours,taille_lot,nb_shift,cadence_bh,nbre_vdlt,nbre_vdlp,retard_jours,tp_jours,thp_jours,total_prod_jours,total_cml,date_liberation,lots(numero_lot,products(code_article)),produit:products!planification_conditionnement_product_id_fkey(code_article,description),equipements_conditionnement(nom_equipement)')
          .neq('statut_planification', 'Annulé').order('ordre_plan'),
        supabase.from('cadences').select('numero_salle,code_article,equipment_name,taille_lot,cadence_objectif_b_min'),
        supabase.from('calendrier_machine').select('id,equipement_id,type,date_debut,date_fin'),
      ])
      if (rAt.data)  ateliers.value    = rAt.data
      if (rEq.data)  equipements.value = rEq.data
      if (rPR.data)  planRooms.value   = rPR.data
      // Construire la map Référentiel : equipment_name → { id_supabase, type } + params de calcul capacité
      var refMap = {}, calcMap = {}
      ;(rOm.data || []).forEach(function(om) {
        if (om.equipment_name) {
          var key = om.equipment_name.toLowerCase().trim()
          refMap[key] = { id_supabase: om.id, type: om.processus === 'Conditionnement' ? 'cond' : 'fab' }
          calcMap[key] = {
            temps_util: om.temps_util, to_shift_min: om.to_shift_min,
            vdlp_min: om.vdlp_min, vdlc_min: om.vdlc_min,
            chgt_format_min: om.chgt_format_min, reglage_min: om.reglage_min, micro_arrets_min: om.micro_arrets_min
          }
        }
      })
      gsRefMap.value = refMap
      calcRef.value  = calcMap
      if (rCad && rCad.data) cadenceList.value = rCad.data
      if (rCal && rCal.data) calAll.value      = rCal.data
      if (rSF.data)  suiviFab.value    = rSF.data
      if (rSC.data)  suiviCond.value   = rSC.data
      if (rAF.data)  arretsFab.value   = rAF.data
      if (rAC.data)  arretsCond.value  = rAC.data
      if (rPC.data) {
        pdpCond.value = rPC.data.map(function(p) {
          return Object.assign({}, p, {
            numero_lot:    p.lots ? p.lots.numero_lot : '—',
            code_article:  (p.produit && p.produit.code_article) || (p.lots && p.lots.products ? p.lots.products.code_article : '') || '—',
            description:   (p.produit && p.produit.description) || '',
            nom_equipement: p.equipements_conditionnement ? p.equipements_conditionnement.nom_equipement : '—',
            date_fin_reelle: ''
          })
        })
        // date_fin_reelle : requête séparée tolérante (colonne ajoutée par migration 030 — ne pas casser l'affichage si absente)
        var rReel = await supabase.from('planification_conditionnement').select('id,date_fin_reelle').neq('statut_planification', 'Annulé')
        if (!rReel.error && rReel.data) {
          var reelMap = {}; rReel.data.forEach(function(x) { reelMap[x.id] = x.date_fin_reelle })
          pdpCond.value.forEach(function(p) { if (reelMap[p.id]) p.date_fin_reelle = reelMap[p.id].slice(0, 10) })
        }
      }
      loading.value = false
    }

    // ── Recherche lots ──
    var searchLots = function() {
      clearTimeout(lotTimeout)
      var q = suiviModal.lotSearch
      if (!q || q.length < 2) { lotSuggestions.value = []; return }
      lotTimeout = setTimeout(async function() {
        var r = await supabase.from('lots')
          .select('id,numero_lot,products(description)')
          .ilike('numero_lot', '%' + q + '%').limit(8)
        lotSuggestions.value = (r.data || []).map(function(l) {
          return { id: l.id, numero_lot: l.numero_lot, description: l.products ? l.products.description : '' }
        })
      }, 200)
    }
    var selectLot = function(l) {
      suiviModal.lot_id = l.id
      suiviModal.lotSearch = l.numero_lot
      lotSuggestions.value = []
    }

    // ── Modals ──
    var suiviModal = reactive({
      show: false, famille: 'fab', id: null, saving: false, err: '',
      lot_id: null, lotSearch: '',
      atelier_id: '', equipement_id: '',
      taille_lot: null, statut: 'En cours',
      date_debut: '', date_fin: '', date_fin_estimee: ''
    })
    var arretModal = reactive({
      show: false, famille: 'fab', suivi_id: null, atelier_id: null, equipement_id: null,
      lot_id: null, lieu: '', numero_lot: '',
      motif: '', heure_debut: '', err: '', saving: false
    })
    var gsModal = reactive({
      show: false, fetching: false, saving: false, err: '', preview: []
    })
    // ── Calendrier machines (fériés / arrêts / fermetures) — PDP capacité ──
    var calModal = reactive({ show: false, saving: false, err: '' })
    var calEntries = ref([])
    var calForm = reactive({ equipement_id: '', type: 'ferie', date_debut: '', date_fin: '', libelle: '' })
    var CAL_TYPE_LABELS = { ferie: 'Jour férié', arret_annuel: 'Arrêt annuel', fermeture: 'Fermeture', maintenance: 'Maintenance' }

    // ── Saisie PDP en masse (coller colonne par colonne) ──
    // Ordre des colonnes collables (tab/Excel) — la désignation est dérivée du code.
    var BULK_FIELDS = ['code', 'numero_lot', 'taille', 'date_debut', 'date_fin']
    var bulkBlankRow = function() {
      return {
        code: '', designation: '', product_id: null, numero_lot: '', taille: '',
        cadence: '', nb_shift: '', vide_ligne: '', vide_ligne_auto: true, retard: null, date_cible: '',
        date_debut: '', date_fin: '', date_fin_reelle: '',
        tp: null, thp: null, total: null, cml: null, liberation: '', lib_src: '',
        _status: ''
      }
    }
    var bulkModal = reactive({ show: false, famille: 'cond', lieu_id: '', plan_start: '', def_shift: '3', saving: false, progress: '', err: '', computed: false, cont_info: '', result: null })
    var bulkRows  = ref([])
    var SHIFTS_REF = 3   // temps_util référentiel = base 3 shifts → Tu/shift = temps_util / 3
    var LIB_DELAI_JOURS = 15

    // Insertion d'une campagne (N lots du même produit) dans la grille
    var campPanel  = reactive({ show: false, code: '', designation: '', product_id: null, taille: '', nb: '10', lot_debut: '', tailleOpts: [], err: '' })
    var campSuggest = ref([])
    var campTimeout = null

    var openSuiviModal = function(s, famille) {
      var now2 = new Date().toISOString().slice(0, 10)
      suiviModal.famille = famille
      suiviModal.err = ''; suiviModal.saving = false
      lotSuggestions.value = []
      if (s && s.rawId) {
        suiviModal.id = s.rawId
        if (famille === 'fab' && s.raw_fab) {
          var sf = s.raw_fab
          suiviModal.lot_id = sf.lot_id
          suiviModal.lotSearch = sf.lots ? sf.lots.numero_lot : ''
          suiviModal.atelier_id = sf.atelier_id || ''
          suiviModal.statut = sf.statut || 'En cours'
          suiviModal.date_debut = sf.date_debut ? sf.date_debut.slice(0, 10) : ''
          suiviModal.date_fin = sf.date_fin ? sf.date_fin.slice(0, 10) : ''
          suiviModal.date_fin_estimee = ''
        } else if (famille === 'cond' && s.raw_cond) {
          var sc = s.raw_cond
          suiviModal.lot_id = sc.lot_id
          suiviModal.lotSearch = sc.lots ? sc.lots.numero_lot : ''
          suiviModal.equipement_id = sc.equipement_id || ''
          suiviModal.taille_lot = sc.taille_lot
          suiviModal.statut = sc.statut || 'En cours'
          suiviModal.date_debut = sc.date_debut ? sc.date_debut.slice(0, 10) : ''
          suiviModal.date_fin = sc.date_fin ? sc.date_fin.slice(0, 10) : ''
          suiviModal.date_fin_estimee = sc.date_fin_estimee || ''
        }
      } else {
        suiviModal.id = null
        suiviModal.lot_id = null; suiviModal.lotSearch = ''
        suiviModal.atelier_id = ''; suiviModal.equipement_id = ''
        suiviModal.taille_lot = null; suiviModal.statut = 'En cours'
        suiviModal.date_debut = now2; suiviModal.date_fin = ''; suiviModal.date_fin_estimee = ''
      }
      suiviModal.show = true
    }

    var saveSuiviFab = async function() {
      if (!canPerform('trs_demarrer')) { suiviModal.err = 'Permission « démarrer un suivi de production » requise'; return }
      if (!suiviModal.lot_id) { suiviModal.err = 'Lot requis'; return }
      if (!suiviModal.atelier_id) { suiviModal.err = 'Atelier requis'; return }
      suiviModal.saving = true; suiviModal.err = ''
      // ── BPF : hors pesée, un seul lot en cours par atelier ──
      if (!suiviModal.id && (suiviModal.statut === 'En cours' || suiviModal.statut === 'Arrêt')) {
        var atF = ateliers.value.find(function(a) { return a.id === suiviModal.atelier_id })
        var isPeseeAt = atF && /pes[ée]/i.test(atF.nom_atelier || '')
        if (!isPeseeAt && suiviFab.value.some(function(sf) { return sf.atelier_id === suiviModal.atelier_id && (sf.statut === 'En cours' || sf.statut === 'Arrêt') })) {
          suiviModal.err = 'BPF : un lot est déjà en cours sur cet atelier (un seul à la fois, hors pesée).'; suiviModal.saving = false; return
        }
      }
      // ── Séquence (règle N°23) : alerter si une étape amont de la route n'est pas saisie ──
      if (!suiviModal.id) {
        var lpFab = await supabase.from('lots').select('products(code_article)').eq('id', suiviModal.lot_id).maybeSingle()
        var upF = await checkUpstreamForAtelier(suiviModal.lot_id, lpFab.data && lpFab.data.products ? lpFab.data.products.code_article : null, suiviModal.atelier_id)
        if (upF.missing && upF.missing.length && !window.confirm('⚠ Traçabilité : étape(s) amont non saisie(s) pour ce lot : ' + stageLabels(upF.missing) + '.\n\nÀ saisir (date rétroactive). Continuer quand même ?')) { suiviModal.saving = false; return }
      }
      var payload = {
        lot_id: suiviModal.lot_id, atelier_id: suiviModal.atelier_id,
        statut: suiviModal.statut,
        date_debut: suiviModal.date_debut || null,
        date_fin: suiviModal.date_fin || null
      }
      var res = suiviModal.id
        ? await supabase.from('suivi_fabrication').update(payload).eq('id', suiviModal.id)
        : await supabase.from('suivi_fabrication').insert(payload)
      suiviModal.saving = false
      if (res.error) { suiviModal.err = res.error.message; return }
      suiviModal.show = false; await loadAll()
    }

    var saveSuiviCond = async function() {
      if (!canPerform('trs_demarrer')) { suiviModal.err = 'Permission « démarrer un suivi de production » requise'; return }
      if (!suiviModal.lot_id) { suiviModal.err = 'Lot requis'; return }
      if (!suiviModal.equipement_id) { suiviModal.err = 'Équipement requis'; return }
      suiviModal.saving = true; suiviModal.err = ''
      // ── BPF : un seul lot en cours par équipement de conditionnement ──
      if (!suiviModal.id && (suiviModal.statut === 'En cours' || suiviModal.statut === 'Arrêt')
          && suiviCond.value.some(function(sc) { return sc.equipement_id === suiviModal.equipement_id && (sc.statut === 'En cours' || sc.statut === 'Arrêt') })) {
        suiviModal.err = 'BPF : un lot est déjà en cours sur cet équipement (un seul à la fois).'; suiviModal.saving = false; return
      }
      // ── Règle flux produit : le produit du lot doit être autorisé sur cet équipement ──
      var eqFx = equipements.value.find(function(e) { return e.id === suiviModal.equipement_id })
      var lpFx = await supabase.from('lots').select('products(code_article)').eq('id', suiviModal.lot_id).maybeSingle()
      var codeFxC = lpFx.data && lpFx.data.products ? lpFx.data.products.code_article : null
      var fxC = await checkProductFluxEquipName(codeFxC, eqFx ? eqFx.nom_equipement : null)
      if (!fxC.allowed) { suiviModal.err = fxC.reason; suiviModal.saving = false; return }
      // ── Séquence (règle N°23) : alerter si une étape amont de la route n'est pas saisie ──
      if (!suiviModal.id) {
        var upC = await checkUpstreamForEquip(suiviModal.lot_id, codeFxC, suiviModal.equipement_id)
        if (upC.missing && upC.missing.length && !window.confirm('⚠ Traçabilité : étape(s) amont non saisie(s) pour ce lot : ' + stageLabels(upC.missing) + '.\n\nÀ saisir (date rétroactive). Continuer quand même ?')) { suiviModal.saving = false; return }
      }
      var payload = {
        lot_id: suiviModal.lot_id, equipement_id: suiviModal.equipement_id,
        taille_lot: suiviModal.taille_lot || null,
        statut: suiviModal.statut,
        date_debut: suiviModal.date_debut || null,
        date_fin: suiviModal.date_fin || null,
        date_fin_estimee: suiviModal.date_fin_estimee || null,
        updated_at: new Date().toISOString()
      }
      var res = suiviModal.id
        ? await supabase.from('suivi_conditionnement').update(payload).eq('id', suiviModal.id)
        : await supabase.from('suivi_conditionnement').insert(payload)
      suiviModal.saving = false
      if (res.error) { suiviModal.err = res.error.message; return }
      suiviModal.show = false; await loadAll()
    }

    var clotureSuivi = async function(s) {
      if (!canPerform('trs_cloturer')) { alert('Permission « clôturer un suivi » requise'); return }
      var now = new Date().toISOString()
      if (s.famille === 'fab') {
        await supabase.from('suivi_fabrication').update({ statut: 'Clôturé', date_fin: now }).eq('id', s.rawId)
      } else {
        await supabase.from('suivi_conditionnement').update({ statut: 'Clôturé', date_fin: now, updated_at: now }).eq('id', s.rawId)
      }
      await loadAll()
    }

    var deleteSuivi = async function(s) {
      if (!canPerform('trs_supprimer_suivi')) { alert('Permission « supprimer un suivi » requise'); return }
      if (!confirm('Supprimer ce suivi ?')) return
      var now = new Date().toISOString()
      if (s.famille === 'fab') {
        await supabase.from('suivi_fabrication').update({ deleted_at: now }).eq('id', s.rawId)
      } else {
        await supabase.from('suivi_conditionnement').update({ deleted_at: now }).eq('id', s.rawId)
      }
      await loadAll()
    }

    var openArretModal = function(s) {
      var now2 = new Date().toISOString().slice(0, 10)
      arretModal.famille = s.famille
      arretModal.suivi_id = s.rawId
      arretModal.lot_id = s.lot_id
      arretModal.lieu = s.lieu
      arretModal.numero_lot = s.numero_lot
      arretModal.motif = ''; arretModal.heure_debut = now2
      arretModal.err = ''; arretModal.saving = false
      if (s.famille === 'fab') arretModal.atelier_id = s.raw_fab ? s.raw_fab.atelier_id : null
      else arretModal.equipement_id = s.raw_cond ? s.raw_cond.equipement_id : null
      arretModal.show = true
    }

    var saveArret = async function() {
      if (!canPerform('trs_arret')) { arretModal.err = 'Permission « déclarer un arrêt » requise'; return }
      if (!arretModal.motif.trim()) { arretModal.err = 'Motif requis'; return }
      arretModal.saving = true; arretModal.err = ''
      var res
      if (arretModal.famille === 'fab') {
        res = await supabase.from('atelier_arrets').insert({
          atelier_id: arretModal.atelier_id, lot_id: arretModal.lot_id,
          motif: arretModal.motif, heure_debut: arretModal.heure_debut || new Date().toISOString().slice(0,10)
        })
        if (!res.error) {
          await supabase.from('suivi_fabrication').update({ statut: 'Arrêt' }).eq('id', arretModal.suivi_id)
        }
      } else {
        res = await supabase.from('arret_conditionnement').insert({
          suivi_id: arretModal.suivi_id, equipement_id: arretModal.equipement_id,
          lot_id: arretModal.lot_id, motif: arretModal.motif,
          heure_debut: arretModal.heure_debut || new Date().toISOString().slice(0,10)
        })
        if (!res.error) {
          await supabase.from('suivi_conditionnement').update({ statut: 'Arrêt', updated_at: new Date().toISOString() }).eq('id', arretModal.suivi_id)
        }
      }
      arretModal.saving = false
      if (res.error) { arretModal.err = res.error.message; return }
      arretModal.show = false; await loadAll()
    }

    var closeArret = async function(a) {
      var now = new Date().toISOString().slice(0,10)
      if (a.famille === 'fab') {
        await supabase.from('atelier_arrets').update({ heure_fin: now }).eq('id', a.id)
        var sf = suiviFab.value.find(function(s) { return s.lot_id === a.lot_id && s.atelier_id === a.atelier_id })
        if (sf) await supabase.from('suivi_fabrication').update({ statut: 'En cours' }).eq('id', sf.id)
      } else {
        await supabase.from('arret_conditionnement').update({ heure_fin: now }).eq('id', a.id)
        if (a.suivi_id) await supabase.from('suivi_conditionnement').update({ statut: 'En cours', updated_at: now }).eq('id', a.suivi_id)
      }
      await loadAll()
    }

    var deleteArret = async function(a) {
      if (!confirm('Supprimer cet arrêt ?')) return
      var now = new Date().toISOString()
      if (a.famille === 'fab') await supabase.from('atelier_arrets').update({ deleted_at: now }).eq('id', a.id)
      else await supabase.from('arret_conditionnement').update({ deleted_at: now }).eq('id', a.id)
      await loadAll()
    }

    var deletePdpCond = async function(p) {
      if (!canPerform('gerer_pdp')) { alert('Permission « gérer le PDP » requise'); return }
      if (!confirm('Supprimer cette entrée PDP ?')) return
      await supabase.from('planification_conditionnement').update({ statut_planification: 'Annulé' }).eq('id', p.id)
      await loadAll()
    }

    // ── Suivi réel quotidien : fin réelle + recalage ──
    var pdpRecomputing = ref(false)
    var pdpErr = ref('')
    // Saisie inline de la date de fin réelle (équipe planification)
    var savePdpReelle = async function(p) {
      if (!canPerform('gerer_pdp')) { alert('Permission « gérer le PDP » requise'); return }
      pdpErr.value = ''
      var dr = bulkParseDate(p.date_fin_reelle)
      // Retard de la ligne = jours OUVRÉS (fin réelle − fin estimée), calendrier de la machine
      var eq = equipements.value.find(function(e) { return e.id === p.equipement_id })
      var ret = (dr && p.date_fin_estimee) ? bulkWorkingDaysBetween(p.date_fin_estimee, dr, p.equipement_id, eq ? !!eq.travaille_weekend : false) : 0
      var r = await supabase.from('planification_conditionnement')
        .update({ date_fin_reelle: dr, retard_jours: ret, updated_at: new Date().toISOString() }).eq('id', p.id)
      if (r.error) { pdpErr.value = 'Enregistrement fin réelle impossible : ' + r.error.message + ' (migration 030 exécutée ?)'; return }
      p.retard_jours = ret  // affichage live du retard sur la ligne
      // ── Interconnexion Schéma (bidirectionnel) : propager la fin réelle à la session du même lot ──
      // (date uniquement ; on ne force pas le statut pour ne pas clôturer une session TRS active)
      if (p.lot_id && dr) {
        await supabase.from('suivi_conditionnement')
          .update({ date_fin: dr, updated_at: new Date().toISOString() })
          .eq('lot_id', p.lot_id).eq('equipement_id', p.equipement_id).is('deleted_at', null)
      }
    }
    // Recaler tout le PDP conditionnement sur les fins réelles + décaler l'aval du retard cumulé
    var recomputeAllPdp = async function() {
      if (!canPerform('gerer_pdp')) { alert('Permission « gérer le PDP » requise'); return }
      pdpErr.value = ''; pdpRecomputing.value = true
      // statut réel des lots (date de libération « réel » si Accepté)
      var lotNums = pdpCond.value.map(function(p) { return p.numero_lot }).filter(function(x) { return x && x !== '—' })
      var lotStat = {}
      if (lotNums.length) { var rl = await supabase.from('lots').select('numero_lot,statut_sap,date_liberation').in('numero_lot', lotNums); (rl.data || []).forEach(function(l) { lotStat[l.numero_lot] = l }) }
      // grouper par machine
      var byEq = {}
      pdpCond.value.forEach(function(p) { if (p.statut_planification === 'Annulé') return; (byEq[p.equipement_id] = byEq[p.equipement_id] || []).push(p) })
      var updates = []
      Object.keys(byEq).forEach(function(eqId) {
        var eq = equipements.value.find(function(e) { return e.id === Number(eqId) }); if (!eq) return
        var ref = calcRef.value[(eq.nom_equipement || '').toLowerCase().trim()]; if (!ref || ref.temps_util == null) return
        var rows = byEq[eqId].slice().sort(function(a, b) { return (a.ordre_plan || 0) - (b.ordre_plan || 0) })
        var firstStart = rows[0] && rows[0].date_debut_estimee ? rows[0].date_debut_estimee.slice(0, 10) : null
        var base = new Date(); if (firstStart) { var fp = firstStart.split('-'); base = new Date(+fp[0], +fp[1] - 1, +fp[2]) }
        var items = rows.map(function(p) {
          return {
            _id: p.id, code: p.code_article, product_id: p.product_id,
            taille: p.taille_lot, cadence: p.cadence_bh ? (p.cadence_bh / 60) : '',
            nb_shift: p.nb_shift, vide_ligne: p.nbre_vdlt === 1 ? 'Total' : (p.nbre_vdlp === 1 ? 'Partiel' : ''),
            vide_ligne_auto: !(p.nbre_vdlt === 1 || p.nbre_vdlp === 1),
            date_fin_reelle: p.date_fin_reelle || '', numero_lot: (p.numero_lot === '—' ? '' : p.numero_lot), date_cible: ''
          }
        })
        computeCapacityChain(items, {
          ref: ref, travWE: !!eq.travaille_weekend, equipId: Number(eqId), base: base,
          cmlBase: 0, lastProduct: null, lotStat: lotStat, defShift: 3,
          cadenceFn: function(code, taille) { return bulkCadence(eq.nom_equipement, code, taille) }
        })
        items.forEach(function(it) {
          updates.push({ id: it._id, payload: {
            date_debut_estimee: bulkParseDate(it.date_debut), date_fin_estimee: bulkParseDate(it.date_fin),
            tp_jours: it.tp, thp_jours: it.thp, total_prod_jours: it.total, total_cml: it.cml,
            duree_estimee_jours: it.total, retard_jours: (it.retard != null ? it.retard : 0),
            nbre_vdlt: it.vide_ligne === 'Total' ? 1 : 0, nbre_vdlp: it.vide_ligne === 'Partiel' ? 1 : 0,
            nb_shift: parseInt(it.nb_shift) || null, cadence_bh: it.cadence ? Math.round(parseFloat(it.cadence) * 60) : null,
            date_liberation: bulkParseDate(it.liberation), updated_at: new Date().toISOString()
          } })
        })
      })
      for (var i = 0; i < updates.length; i++) {
        var ru = await supabase.from('planification_conditionnement').update(updates[i].payload).eq('id', updates[i].id)
        if (ru.error) { pdpErr.value = 'Recalage : ' + ru.error.message; break }
      }
      pdpRecomputing.value = false
      await loadAll()
    }

    // ── Import GS ──
    var openGsImport = function() {
      gsModal.show = true; gsModal.err = ''; gsModal.preview = []; gsModal.fetching = false; gsModal.saving = false
    }

    // ── Parser CSV RFC-4180 (gère les champs entre guillemets contenant des virgules) ──
    var parseCSVLine = function(line) {
      var cells = [], cur = '', inQ = false
      for (var i = 0; i < line.length; i++) {
        var ch = line[i]
        if (ch === '"') {
          if (inQ && line[i + 1] === '"') { cur += '"'; i++ }
          else inQ = !inQ
        } else if (ch === ',' && !inQ) {
          cells.push(cur.trim()); cur = ''
        } else { cur += ch }
      }
      cells.push(cur.trim())
      return cells
    }

    // Lookup flexible de colonne (essaie plusieurs noms possibles)
    var gc = function(row, keys) {
      for (var k = 0; k < keys.length; k++) {
        var v = row[keys[k]]
        if (v !== undefined && v !== '') return v
      }
      return ''
    }

    var fetchGsData = async function() {
      gsModal.fetching = true; gsModal.err = ''; gsModal.preview = []
      try {
        var resp = await fetch(GS_URL)
        if (!resp.ok) throw new Error('HTTP ' + resp.status)
        var text = await resp.text()
        var rawLines = text.trim().split('\n')
        if (rawLines.length < 2) throw new Error('CSV vide ou invalide')
        var headers = parseCSVLine(rawLines[0]).map(function(h) { return h })
        // Lookup depuis GS Référentiel (source unique de vérité)
        var refMap = gsRefMap.value
        var rows = []
        for (var i = 1; i < rawLines.length; i++) {
          if (!rawLines[i].trim()) continue
          var cells = parseCSVLine(rawLines[i])
          var row = {}
          headers.forEach(function(h, j) { row[h] = (cells[j] || '').trim() })
          // Valeurs normalisées (insensibles au nom exact de colonne)
          row._lot          = gc(row, ['N_lot','Lot interne','Lot','numero_lot','N° lot'])
          row._description  = gc(row, ['description','Description article','Description'])
          row._taille       = gc(row, ['Taille_lot','Prévisionnel [UN]','Taille lot','Quantité','quantite'])
          row._date_debut   = gc(row, ['Date_début','Date début','date_debut','Date de début'])
          row._date_fin     = gc(row, ['Date_fin_réelle','Date fin réelle','date_fin_reelle','Date fin'])
          row._date_fin_est = gc(row, ['Date_fin_estimée','Date fin estimée','date_fin_estimee'])
          // Détection Fab / Cond via GS Référentiel (equipment_name = source de vérité)
          var equipRaw = gc(row, ['Equipement','Équipement','equipement']) || ''
          var equipKey = equipRaw.toLowerCase().trim()
          var ref = refMap[equipKey]
          if (ref) {
            row._famille    = ref.type   // 'fab' ou 'cond'
            row._id_supabase = ref.id_supabase
          } else {
            row._err = 'Équipement non trouvé dans GS Référentiel : ' + equipRaw
          }
          rows.push(row)
        }
        gsModal.preview = rows
      } catch(e) {
        gsModal.err = 'Erreur : ' + (e.message || 'Impossible de charger le CSV')
      }
      gsModal.fetching = false
    }

    var confirmGsImport = async function() {
      var toImport = gsModal.preview.filter(function(r) { return !r._err })
      if (!toImport.length) return
      gsModal.saving = true; gsModal.err = ''
      var lotCache = {}
      var getLotId = async function(nLot) {
        if (!nLot) return null
        var key = nLot.trim()
        if (lotCache[key] !== undefined) return lotCache[key]
        var r = await supabase.from('lots').select('id').ilike('numero_lot', key).maybeSingle()
        lotCache[key] = r.data ? r.data.id : null
        return lotCache[key]
      }
      var parseDate = function(s) {
        if (!s || !s.trim()) return null
        var p = s.trim().split('/')
        if (p.length === 3) {
          var iso = p[2] + '-' + p[1].padStart(2,'0') + '-' + p[0].padStart(2,'0')
          var d = new Date(iso)
          return isNaN(d.getTime()) ? null : iso
        }
        return s.trim() || null
      }
      var fabRows = [], condRows = []
      for (var i = 0; i < toImport.length; i++) {
        var r = toImport[i]
        var lotId = r._lot ? await getLotId(r._lot) : null
        var dDebut = parseDate(r._date_debut)
        var dFin   = parseDate(r._date_fin)
        var statut = dFin ? 'Clôturé' : dDebut ? 'En cours' : 'Planifié'
        if (r._famille === 'fab') {
          fabRows.push({
            lot_id: lotId,
            atelier_id: r._id_supabase,
            date_debut: dDebut ? new Date(dDebut).toISOString() : null,
            date_fin:   dFin   ? new Date(dFin).toISOString()   : null,
            statut: statut
          })
        } else {
          var dEst = parseDate(r._date_fin_est)
          condRows.push({
            lot_id: lotId,
            equipement_id: r._id_supabase,
            taille_lot: parseInt(r._taille) || null,
            date_debut: dDebut ? new Date(dDebut).toISOString() : null,
            date_fin:   dFin   ? new Date(dFin).toISOString()   : null,
            date_fin_estimee: dEst || null,
            statut: statut,
            created_at: new Date().toISOString()
          })
        }
      }
      // règle N°17 : toujours vérifier res.error (sinon échec silencieux — ex. statut='Planifié' refusé par le CHECK avant migration 029)
      if (fabRows.length) {
        var rGsF = await supabase.from('suivi_fabrication').insert(fabRows)
        if (rGsF.error) { gsModal.saving = false; gsModal.err = 'Import FAB : ' + rGsF.error.message; return }
      }
      if (condRows.length) {
        var rGsC = await supabase.from('suivi_conditionnement').insert(condRows)
        if (rGsC.error) { gsModal.saving = false; gsModal.err = 'Import COND : ' + rGsC.error.message; return }
      }
      gsModal.saving = false; gsModal.show = false
      await loadAll()
    }

    // ── Calendrier machines ──
    var loadCalEntries = async function() {
      var r = await supabase.from('calendrier_machine')
        .select('id, equipement_id, type, date_debut, date_fin, libelle')
        .order('date_debut', { ascending: false })
      var eqMap = {}; equipements.value.forEach(function(e){ eqMap[e.id] = e.nom_equipement })
      calEntries.value = (r.data || []).map(function(c){
        return Object.assign({}, c, { nom_equipement: c.equipement_id ? (eqMap[c.equipement_id] || ('#'+c.equipement_id)) : 'Toutes machines' })
      })
    }
    var openCalModal = async function() {
      calModal.show = true; calModal.err = ''
      calForm.date_debut = ''; calForm.date_fin = ''; calForm.libelle = ''
      await loadCalEntries()
    }
    var addCalEntry = async function() {
      if (!calForm.date_debut) { calModal.err = 'Date de début requise.'; return }
      calModal.saving = true; calModal.err = ''
      var r = await supabase.from('calendrier_machine').insert({
        equipement_id: calForm.equipement_id || null,
        type:          calForm.type,
        date_debut:    calForm.date_debut,
        date_fin:      calForm.date_fin || calForm.date_debut,
        libelle:       calForm.libelle || null
      })
      calModal.saving = false
      if (r.error) { calModal.err = r.error.message; return }
      calForm.date_debut = ''; calForm.date_fin = ''; calForm.libelle = ''
      await loadCalEntries()
    }
    var deleteCalEntry = async function(c) {
      await supabase.from('calendrier_machine').delete().eq('id', c.id)
      await loadCalEntries()
    }

    // ── Saisie PDP en masse ──
    var bulkLieuList = computed(function() {
      return bulkModal.famille === 'fab'
        ? ateliers.value.map(function(a) { return { id: a.id, nom: a.nom_atelier } })
        : equipements.value.map(function(e) { return { id: e.id, nom: e.nom_equipement } })
    })
    var bulkSetFamille = function(f) { bulkModal.famille = f; bulkModal.lieu_id = '' }
    var openBulkModal = function() {
      bulkModal.show = true; bulkModal.err = ''; bulkModal.result = null; bulkModal.progress = ''; bulkModal.saving = false; bulkModal.computed = false; bulkModal.cont_info = ''
      campPanel.show = false
      bulkModal.lieu_id = ''
      bulkModal.plan_start = new Date().toISOString().slice(0, 10)
      bulkRows.value = []
      for (var i = 0; i < 6; i++) bulkRows.value.push(bulkBlankRow())
    }
    var bulkAddRow    = function() { bulkRows.value.push(bulkBlankRow()) }
    var bulkRemoveRow = function(i) { bulkRows.value.splice(i, 1); if (!bulkRows.value.length) bulkRows.value.push(bulkBlankRow()) }
    var bulkClear     = function() { bulkRows.value = []; for (var i = 0; i < 6; i++) bulkRows.value.push(bulkBlankRow()); bulkModal.result = null; bulkModal.err = '' }

    // ── Insertion d'une campagne (N lots d'un même produit) ──
    var openCampPanel = function() { campPanel.show = true; campPanel.err = ''; if (campPanel.product_id) campLoadTailles() }
    var campSearchCode = function() {
      clearTimeout(campTimeout)
      campPanel.product_id = null; campPanel.designation = ''
      var q = campPanel.code
      if (!q || q.length < 2) { campSuggest.value = []; return }
      campTimeout = setTimeout(async function() {
        var r = await supabase.from('products').select('id,code_article,description')
          .or('code_article.ilike.%' + q + '%,description.ilike.%' + q + '%').limit(8)
        campSuggest.value = r.data || []
      }, 200)
    }
    var campLoadTailles = function() {
      var eq = equipements.value.find(function(e) { return e.id === bulkModal.lieu_id })
      var en = eq ? (eq.nom_equipement || '').toLowerCase().trim() : null
      var cd = (campPanel.code || '').toUpperCase().trim()
      var opts = cadenceList.value.filter(function(c) {
        if ((c.code_article || '').toUpperCase().trim() !== cd) return false
        if (en && (c.equipment_name || '').toLowerCase().trim() !== en) return false
        return true
      }).map(function(c) { return c.taille_lot }).filter(function(v, i, a) { return v != null && a.indexOf(v) === i }).sort(function(a, b) { return a - b })
      campPanel.tailleOpts = opts
      if (opts.length === 1) campPanel.taille = String(opts[0])
    }
    var campSelectProduct = function(p) {
      campPanel.code = p.code_article; campPanel.designation = p.description || ''; campPanel.product_id = p.id
      campSuggest.value = []; campPanel.taille = ''
      campLoadTailles()
    }
    var campInsert = function() {
      campPanel.err = ''
      if (!campPanel.product_id) { campPanel.err = 'Choisis un produit (la désignation doit apparaître).'; return }
      var n = parseInt(campPanel.nb) || 0
      if (n < 1) { campPanel.err = 'Nombre de lots invalide.'; return }
      var startLot = parseInt(campPanel.lot_debut)
      var hasLot = !isNaN(startLot)
      // purger les lignes vides existantes (les 6 lignes blanches d'ouverture) avant d'ajouter la campagne
      bulkRows.value = bulkRows.value.filter(function(r) { return (r.code || '').trim() })
      for (var i = 0; i < n; i++) {
        var row = bulkBlankRow()
        row.code = campPanel.code; row.designation = campPanel.designation; row.product_id = campPanel.product_id; row._status = 'ok'
        row.taille = campPanel.taille ? String(campPanel.taille) : ''
        if (hasLot) row.numero_lot = String(startLot + i)
        bulkRows.value.push(row)
      }
      campPanel.show = false; bulkModal.computed = false
      campPanel.code = ''; campPanel.designation = ''; campPanel.product_id = null; campPanel.taille = ''; campPanel.nb = '10'; campPanel.lot_debut = ''; campPanel.tailleOpts = []; campSuggest.value = []
    }

    // Date jj/mm/aaaa (ou aaaa-mm-jj) → 'aaaa-mm-jj' pour la BD
    var bulkParseDate = function(s) {
      if (!s) return null
      s = String(s).trim(); if (!s) return null
      if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10)
      var p = s.split(/[\/.\-]/)
      if (p.length === 3) {
        if (p[2].length === 4) return p[2] + '-' + p[1].padStart(2, '0') + '-' + p[0].padStart(2, '0')
        if (p[0].length === 4) return p[0] + '-' + p[1].padStart(2, '0') + '-' + p[2].padStart(2, '0')
      }
      return null
    }

    // ── Moteur de capacité (calcul des dates) ──
    var fmtIso = function(d) { var m = d.getMonth() + 1, j = d.getDate(); return d.getFullYear() + '-' + (m < 10 ? '0' : '') + m + '-' + (j < 10 ? '0' : '') + j }
    // jour ouvré pour une machine : ni WE (sauf travaille_weekend), ni dans calendrier_machine
    var bulkIsWorkingDay = function(d, equipId, travailleWE) {
      var day = d.getDay()
      if (!travailleWE && (day === 0 || day === 6)) return false
      var iso = fmtIso(d)
      var blocked = calAll.value.some(function(c) {
        if (c.equipement_id != null && c.equipement_id !== equipId) return false
        return iso >= (c.date_debut || '') && iso <= (c.date_fin || c.date_debut || '')
      })
      return !blocked
    }
    // n-ième jour ouvré (le 1er jour ouvré >= base = #1)
    var bulkNthWorkingDay = function(base, n, equipId, travailleWE) {
      var d = new Date(base.getFullYear(), base.getMonth(), base.getDate())
      var count = 0, guard = 0
      while (guard++ < 4000) {
        if (bulkIsWorkingDay(d, equipId, travailleWE)) { count++; if (count >= n) return d }
        d.setDate(d.getDate() + 1)
      }
      return d
    }
    var bulkAddCalDays = function(iso, days) {
      if (!iso) return ''
      var p = iso.split('-'); var d = new Date(+p[0], +p[1] - 1, +p[2]); d.setDate(d.getDate() + days); return fmtIso(d)
    }
    // Nombre de jours OUVRÉS (machine) entre deux dates ISO — signé (négatif si fin avant estimée)
    var bulkWorkingDaysBetween = function(isoFrom, isoTo, equipId, travailleWE) {
      if (!isoFrom || !isoTo) return 0
      var pf = isoFrom.split('-'), pt = isoTo.split('-')
      var a = new Date(+pf[0], +pf[1] - 1, +pf[2]), b = new Date(+pt[0], +pt[1] - 1, +pt[2])
      var sign = 1
      if (b < a) { var t = a; a = b; b = t; sign = -1 }
      var count = 0, guard = 0, d = new Date(a); d.setDate(d.getDate() + 1)
      while (d <= b && guard++ < 4000) { if (bulkIsWorkingDay(d, equipId, travailleWE)) count++; d.setDate(d.getDate() + 1) }
      return sign * count
    }
    // cadence (b/min) : table cadences (machine × article × taille) sinon cadence machine par défaut
    var bulkCadence = function(equipName, code, taille) {
      if (!equipName) return null
      var en = equipName.toLowerCase().trim(), cd = (code || '').toUpperCase().trim(), t = parseInt(taille) || 0
      var rows = cadenceList.value.filter(function(c) { return (c.equipment_name || '').toLowerCase().trim() === en && (c.code_article || '').toUpperCase().trim() === cd })
      if (rows.length) {
        if (t) {
          var exact = rows.find(function(c) { return c.taille_lot === t })
          if (exact) return exact.cadence_objectif_b_min
          rows = rows.slice().sort(function(a, b) { return Math.abs((a.taille_lot || 0) - t) - Math.abs((b.taille_lot || 0) - t) })
        }
        return rows[0].cadence_objectif_b_min
      }
      var eq = equipements.value.find(function(e) { return (e.nom_equipement || '').toLowerCase().trim() === en })
      return eq && eq.cadence_objectif_boite_min ? eq.cadence_objectif_boite_min : null
    }

    // Calcule TP / THP / TOTAL / CML + dates début/fin (calendrier machine) + date libération
    // Moteur partagé : calcule TP/THP/TOTAL/cumul + dates + retard (réel) + libération pour une suite de lots d'UNE machine.
    // items mutés ; ctx = { ref, travWE, equipId, base(Date), cmlBase, lastProduct, lotStat{}, defShift, cadenceFn(code,taille) }
    var computeCapacityChain = function(items, ctx) {
      var TuShift = ctx.ref.temps_util / SHIFTS_REF
      var toShift = ctx.ref.to_shift_min || 480
      var segBase = ctx.base, segOff = 0
      var cml = ctx.cmlBase || 0, prevProduct = ctx.lastProduct || null
      items.forEach(function(r) {
        var taille = parseInt(r.taille) || 0
        var cadBmin = parseFloat(r.cadence) || ctx.cadenceFn(r.code, taille)
        if (cadBmin) r.cadence = cadBmin
        var nb = parseInt(r.nb_shift) || ctx.defShift || 3
        r.nb_shift = nb
        if (r.vide_ligne_auto || !r.vide_ligne) { r.vide_ligne = (prevProduct && prevProduct === r.product_id) ? 'Partiel' : 'Total'; r.vide_ligne_auto = true }
        var cadBh = (cadBmin || 0) * 60
        var realIso = bulkParseDate(r.date_fin_reelle)
        if (!taille || !cadBh) {
          r.tp = r.thp = r.total = null; r.date_debut = ''; r.retard = null; r.liberation = ''; r.lib_src = ''
          r.date_fin = realIso || r.date_fin || ''
          if (realIso) { var rd0 = realIso.split('-'); segBase = new Date(+rd0[0], +rd0[1] - 1, +rd0[2]); segBase.setDate(segBase.getDate() + 1); segOff = 0 }
          r.cml = Math.round(cml * 100) / 100; prevProduct = r.product_id; return
        }
        var TP = (taille / cadBh) / (TuShift * nb)
        var THPmin = (r.vide_ligne === 'Total')
          ? ((ctx.ref.vdlc_min || 0) + (ctx.ref.chgt_format_min || 0) + (ctx.ref.reglage_min || 0))
          : ((ctx.ref.vdlp_min || 0) + (ctx.ref.micro_arrets_min || 0))
        var THP = THPmin / (toShift * nb)
        var TOTAL = TP + THP
        var startOff = segOff, endOff = segOff + TOTAL
        var dDeb = bulkNthWorkingDay(segBase, Math.floor(startOff) + 1, ctx.equipId, ctx.travWE)
        var dFinEst = bulkNthWorkingDay(segBase, Math.max(Math.ceil(endOff), Math.floor(startOff) + 1), ctx.equipId, ctx.travWE)
        r.tp = Math.round(TP * 100) / 100; r.thp = Math.round(THP * 100) / 100; r.total = Math.round(TOTAL * 100) / 100
        r.date_debut = fmtIso(dDeb)
        if (realIso) {
          // retard = jours ouvrés (réelle − estimée) ; aligner l'estimée sur la réelle ; repartir l'aval après la réelle
          r.retard = bulkWorkingDaysBetween(fmtIso(dFinEst), realIso, ctx.equipId, ctx.travWE)
          r.date_fin = realIso
          var rp = realIso.split('-'); segBase = new Date(+rp[0], +rp[1] - 1, +rp[2]); segBase.setDate(segBase.getDate() + 1); segOff = 0
        } else {
          r.retard = null; r.date_fin = fmtIso(dFinEst); segOff = endOff
        }
        cml += TOTAL; r.cml = Math.round(cml * 100) / 100
        var st = ctx.lotStat[(r.numero_lot || '').trim()]
        if (st && st.statut_sap === 'accepte' && st.date_liberation) { r.liberation = st.date_liberation.slice(0, 10); r.lib_src = 'réel' }
        else if (r.date_cible) { r.liberation = bulkParseDate(r.date_cible) || ''; r.lib_src = 'cible' }
        else { r.liberation = bulkAddCalDays(r.date_fin, LIB_DELAI_JOURS); r.lib_src = '+15j' }
        prevProduct = r.product_id
      })
    }

    var bulkCompute = async function() {
      bulkModal.err = ''
      if (bulkModal.famille !== 'cond') { bulkModal.err = 'Le calcul de capacité concerne le conditionnement.'; return }
      if (!bulkModal.lieu_id) { bulkModal.err = 'Choisis une machine.'; return }
      await bulkResolveDesignations()
      var eq = equipements.value.find(function(e) { return e.id === bulkModal.lieu_id })
      if (!eq) { bulkModal.err = 'Machine introuvable.'; return }
      var ref = calcRef.value[(eq.nom_equipement || '').toLowerCase().trim()]
      if (!ref || ref.temps_util == null) { bulkModal.err = 'Référentiel incomplet pour ' + (eq.nom_equipement || '?') + ' — re-synchronise le référentiel (Temps util, TO shift…).'; return }
      var TuShift = ref.temps_util / SHIFTS_REF
      var toShift = ref.to_shift_min || 480
      var travWE = !!eq.travaille_weekend
      var base = new Date()
      if (bulkModal.plan_start) { var ps = bulkParseDate(bulkModal.plan_start); if (ps) { var pp = ps.split('-'); base = new Date(+pp[0], +pp[1] - 1, +pp[2]) } }

      // Poursuivre à partir du dernier PDP déjà enregistré pour cette machine
      var cmlBase = 0
      bulkModal.cont_info = ''
      var rLast = await supabase.from('planification_conditionnement')
        .select('date_fin_estimee,total_cml,product_id').eq('equipement_id', bulkModal.lieu_id)
        .neq('statut_planification', 'Annulé').not('date_fin_estimee', 'is', null)
        .order('date_fin_estimee', { ascending: false }).order('total_cml', { ascending: false, nullsFirst: false }).limit(1).maybeSingle()
      var lastProduct = (rLast.data && rLast.data.product_id) ? rLast.data.product_id : null
      if (rLast.data && rLast.data.date_fin_estimee) {
        var lf = rLast.data.date_fin_estimee.slice(0, 10).split('-')
        var nextAfter = new Date(+lf[0], +lf[1] - 1, +lf[2]); nextAfter.setDate(nextAfter.getDate() + 1)
        if (nextAfter > base) { base = nextAfter }
        cmlBase = rLast.data.total_cml || 0
        bulkModal.cont_info = 'Poursuite après le dernier PDP machine (fin ' + fmtDate(rLast.data.date_fin_estimee) + (cmlBase ? ', cumul ' + cmlBase + ' j' : '') + ')'
      }

      var filled = bulkRows.value.filter(function(r) { return (r.code || '').trim() })
      var lotNums = filled.map(function(r) { return (r.numero_lot || '').trim() }).filter(Boolean)
      var lotStat = {}
      if (lotNums.length) {
        var rl = await supabase.from('lots').select('numero_lot,statut_sap,date_liberation').in('numero_lot', lotNums)
        ;(rl.data || []).forEach(function(l) { lotStat[l.numero_lot] = l })
      }

      computeCapacityChain(filled, {
        ref: ref, travWE: travWE, equipId: bulkModal.lieu_id, base: base,
        cmlBase: cmlBase, lastProduct: lastProduct, lotStat: lotStat,
        defShift: parseInt(bulkModal.def_shift) || 3,
        cadenceFn: function(code, taille) { return bulkCadence(eq.nom_equipement, code, taille) }
      })
      bulkModal.computed = true
    }

    // Résoudre les désignations + product_id depuis les codes saisis (batch)
    var bulkResolveDesignations = async function() {
      var codes = []
      bulkRows.value.forEach(function(r) { var c = (r.code || '').trim(); if (c && codes.indexOf(c) < 0) codes.push(c) })
      if (!codes.length) return
      var res = await supabase.from('products').select('id,code_article,description').in('code_article', codes)
      var map = {}
      ;(res.data || []).forEach(function(p) { map[(p.code_article || '').trim().toUpperCase()] = p })
      bulkRows.value.forEach(function(r) {
        var c = (r.code || '').trim()
        if (!c) { r.designation = ''; r.product_id = null; r._status = ''; return }
        var p = map[c.toUpperCase()]
        if (p) { r.designation = p.description || p.code_article; r.product_id = p.id; r._status = 'ok' }
        else   { r.designation = '⚠ code inconnu'; r.product_id = null; r._status = 'unknown' }
      })
    }

    // Collage Excel : remplit vers le bas (et à droite si plusieurs colonnes tab)
    var onBulkPaste = function(e, rowIdx, field) {
      var text = (e.clipboardData || window.clipboardData).getData('text')
      if (!text || !/[\n\t\r]/.test(text)) return   // valeur simple → collage natif
      e.preventDefault()
      var lines = text.replace(/\r/g, '').split('\n')
      while (lines.length && lines[lines.length - 1] === '') lines.pop()
      var startCol = BULK_FIELDS.indexOf(field); if (startCol < 0) startCol = 0
      for (var li = 0; li < lines.length; li++) {
        var ri = rowIdx + li
        while (bulkRows.value.length <= ri) bulkRows.value.push(bulkBlankRow())
        var cells = lines[li].split('\t')
        for (var ci = 0; ci < cells.length; ci++) {
          var f = BULK_FIELDS[startCol + ci]; if (!f) break
          var val = (cells[ci] || '').trim()
          if (f === 'taille') bulkRows.value[ri][f] = val.replace(/[^\d]/g, '')
          else bulkRows.value[ri][f] = val
        }
      }
      bulkResolveDesignations()
    }

    // Coller depuis Excel dans « Fin réelle » de Gérer PDP : <input type="date"> refuse le texte brut
    // (« 17/06/2026 ») → on intercepte, on parse (jj/mm/aaaa ou aaaa-mm-jj), on convertit en ISO,
    // et on répartit une colonne entière sur les lignes suivantes (chaque ligne est sauvegardée).
    var onReelPaste = function(e, idx) {
      var text = (e.clipboardData || window.clipboardData).getData('text')
      if (!text) return
      e.preventDefault()
      var lines = text.replace(/\r/g, '').split('\n')
      while (lines.length && lines[lines.length - 1] === '') lines.pop()
      var view = filteredPdpCond.value
      for (var li = 0; li < lines.length; li++) {
        var p = view[idx + li]; if (!p) break
        var iso = bulkParseDate((lines[li] || '').split('\t')[0].trim())
        if (!iso) continue
        p.date_fin_reelle = iso
        savePdpReelle(p)
      }
    }

    // Collage d'une colonne (depuis Excel) dans un champ texte de la grille en masse qui n'est pas
    // dans BULK_FIELDS (date_fin_reelle, date_cible) : on répartit verticalement le texte brut
    // (parsé plus tard par bulkCompute / bulkSave). Une seule valeur → collage natif.
    var onBulkColPaste = function(e, rowIdx, field) {
      var text = (e.clipboardData || window.clipboardData).getData('text')
      if (!text || !/[\n\r]/.test(text)) return
      e.preventDefault()
      var lines = text.replace(/\r/g, '').split('\n')
      while (lines.length && lines[lines.length - 1] === '') lines.pop()
      for (var li = 0; li < lines.length; li++) {
        var ri = rowIdx + li
        while (bulkRows.value.length <= ri) bulkRows.value.push(bulkBlankRow())
        bulkRows.value[ri][field] = (lines[li] || '').split('\t')[0].trim()
      }
      bulkResolveDesignations()
    }

    // Création lot « façon Planifier » (LotsPage) — réplique exacte de PlanifierPage
    var bulkCreateLot = async function(numLot, productId, codeArticle, uid) {
      if (!canPerform('creer_lot')) return { error: 'Permission « créer un lot » requise' }
      var existing = await supabase.from('lots').select('id').eq('numero_lot', numLot).maybeSingle()
      if (existing.data) return { lotId: existing.data.id, created: false }
      var lotRes = await supabase.from('lots').insert({
        numero_lot: numLot, product_id: productId, statut_sap: 'vide',
        synced_from_excel_at: new Date().toISOString()
      }).select('id').single()
      if (lotRes.error) return { error: lotRes.error.message }
      var lotId = lotRes.data.id
      await supabase.from('liberation_documents').insert([
        { lot_id: lotId, type_document: 'if',       is_applicable: true,  is_required: true,  service_emetteur: 'fabrication' },
        { lot_id: lotId, type_document: 'ic',       is_applicable: true,  is_required: true,  service_emetteur: 'conditionnement' },
        { lot_id: lotId, type_document: 'da_pc',    is_applicable: true,  is_required: true,  service_emetteur: 'lcq' },
        { lot_id: lotId, type_document: 'da_micro', is_applicable: false, is_required: false, service_emetteur: 'lcq' },
        { lot_id: lotId, type_document: 'ccl',      is_applicable: true,  is_required: true,  service_emetteur: 'aq' }
      ])
      await supabase.from('liberation_dossiers').insert({ lot_id: lotId, da_micro_applicable: false })
      await supabase.from('orders_of').insert({ lot_id: lotId, statut: 'planifie', etape_circuit: 'planification' })
      await supabase.from('orders_oc').insert({ lot_id: lotId, statut: 'planifie', etape_circuit: 'planification' })
      await supabase.from('lot_events').insert({
        lot_id: lotId, event_type: 'lot_planifie',
        description: 'Lot planifié (PDP en masse) — ' + codeArticle,
        triggered_by: uid, source: 'app', created_at: new Date().toISOString()
      })
      return { lotId: lotId, created: true }
    }

    var bulkSave = async function() {
      if (!bulkModal.lieu_id) { bulkModal.err = (bulkModal.famille === 'fab' ? 'Atelier' : 'Équipement') + ' requis'; return }
      var rows = bulkRows.value.filter(function(r) { return (r.code || '').trim() })
      if (!rows.length) { bulkModal.err = 'Aucune ligne à créer (renseigne au moins un code produit)'; return }
      bulkModal.saving = true; bulkModal.err = ''; bulkModal.result = null; bulkModal.progress = 'Résolution des produits…'
      await bulkResolveDesignations()
      var unknown = rows.filter(function(r) { return !r.product_id })
      if (unknown.length) { bulkModal.saving = false; bulkModal.progress = ''; bulkModal.err = unknown.length + ' code(s) produit inconnu(s) — corrige-les avant de créer'; return }

      // ── Règle flux produit : chaque code doit être autorisé sur la machine choisie (cond) ──
      if (bulkModal.famille === 'cond') {
        bulkModal.progress = 'Vérification du flux produit…'
        var eqB = equipements.value.find(function(e) { return e.id === bulkModal.lieu_id })
        var eqNomB = eqB ? eqB.nom_equipement : null
        var distinctCodes = []
        rows.forEach(function(r) { var c = (r.code || '').trim(); if (c && distinctCodes.indexOf(c) < 0) distinctCodes.push(c) })
        var fluxBad = []
        for (var fi = 0; fi < distinctCodes.length; fi++) {
          var fr = await checkProductFluxEquipName(distinctCodes[fi], eqNomB)
          if (!fr.allowed) fluxBad.push(distinctCodes[fi])
        }
        if (fluxBad.length) { bulkModal.saving = false; bulkModal.progress = ''; bulkModal.err = 'Flux produit : ' + fluxBad.join(', ') + ' non autorisé(s) sur ' + (eqNomB || 'cette machine') + ' — cocher le flux (Flux produits) avant.'; return }
      }

      var u = await supabase.auth.getUser()
      var uid = u.data && u.data.user ? u.data.user.id : null
      // Garde : créer des lots depuis le PDP nécessite la permission creer_lot
      var willCreateLots = rows.some(function (r) { return (r.numero_lot || '').trim() })
      if (willCreateLots && !canPerform('creer_lot')) { bulkModal.saving = false; bulkModal.progress = ''; bulkModal.err = 'Permission « créer un lot » requise pour créer des lots depuis le PDP.'; return }
      var stats = { lots: 0, lignes: 0, skipped: 0, errors: 0 }
      var ordreBase = 0
      if (bulkModal.famille === 'cond') {
        var om = await supabase.from('planification_conditionnement').select('ordre_plan').order('ordre_plan', { ascending: false }).limit(1).maybeSingle()
        ordreBase = (om.data && om.data.ordre_plan) ? om.data.ordre_plan : 0
      }
      var condRows = [], fabRows = []
      for (var i = 0; i < rows.length; i++) {
        var r = rows[i]
        bulkModal.progress = 'Ligne ' + (i + 1) + '/' + rows.length + '…'
        var lotId = null
        var nLot = (r.numero_lot || '').trim()
        if (nLot) {
          var lr = await bulkCreateLot(nLot, r.product_id, r.code, uid)
          if (lr.error) { stats.errors++; r._status = 'err'; continue }
          lotId = lr.lotId
          if (lr.created) stats.lots++; else stats.skipped++
        }
        var dDeb = bulkParseDate(r.date_debut)
        var dFin = bulkParseDate(r.date_fin)
        if (bulkModal.famille === 'cond') {
          var condRow = {
            lot_id: lotId, product_id: r.product_id, equipement_id: bulkModal.lieu_id,
            taille_lot: r.taille ? (parseInt(r.taille) || null) : null,
            cadence_bh: r.cadence ? Math.round(parseFloat(r.cadence) * 60) : null,
            nb_shift: parseInt(r.nb_shift) || null,
            nbre_vdlt: r.vide_ligne === 'Total' ? 1 : 0,
            nbre_vdlp: r.vide_ligne === 'Partiel' ? 1 : 0,
            retard_jours: (r.retard != null ? r.retard : 0),
            tp_jours: r.tp, thp_jours: r.thp, total_prod_jours: r.total, total_cml: r.cml,
            duree_estimee_jours: r.total,
            ordre_plan: (++ordreBase), statut_planification: 'Planifié',
            date_debut_estimee: dDeb || bulkParseDate(r.date_debut),
            date_fin_estimee:   dFin || bulkParseDate(r.date_fin),
            date_liberation:    bulkParseDate(r.liberation)
          }
          // date_fin_reelle : n'inclure que si renseignée (colonne migration 030 — évite l'échec pré-migration)
          var dReel = bulkParseDate(r.date_fin_reelle)
          if (dReel) condRow.date_fin_reelle = dReel
          condRow.created_at = new Date().toISOString()
          condRows.push(condRow)
        } else {
          fabRows.push({
            lot_id: lotId, product_id: r.product_id, atelier_id: bulkModal.lieu_id,
            date_debut: dDeb, date_fin: dFin, statut: 'Planifié'
          })
        }
        stats.lignes++
      }
      bulkModal.progress = 'Enregistrement…'
      if (condRows.length) {
        var rc = await supabase.from('planification_conditionnement').insert(condRows)
        if (rc.error) { bulkModal.saving = false; bulkModal.progress = ''; bulkModal.err = 'PDP cond : ' + rc.error.message; return }
      }
      if (fabRows.length) {
        var rf = await supabase.from('suivi_fabrication').insert(fabRows)
        if (rf.error) { bulkModal.saving = false; bulkModal.progress = ''; bulkModal.err = 'PDP fab : ' + rf.error.message + ' (migration 029 exécutée ?)'; return }
      }
      bulkModal.saving = false; bulkModal.progress = ''
      bulkModal.result = stats
      await loadAll()
    }

    onMounted(async function () { var u = await supabase.auth.getUser(); if (u.data.user) { var p = await supabase.from('profiles').select('service').eq('id', u.data.user.id).single(); if (p.data) await loadPermissions(p.data.service) } })
    onMounted(loadAll)

    return {
      theme, cycleTheme, themeIcon, themeTitle,
      loading, activeView, views,
      hiddenFam, showFamPanel, toggleFam,
      suiviFab, suiviCond, ateliers, equipements,
      allSuivis, allArrets,
      suiviSearch, suiviStatut, filteredSuivis,
      arretSearch, arretStatutFil, filteredArrets,
      pdpSearch, pdpStatutFil, filteredPdpCond, filteredPdpFab,
      lotSuggestions, searchLots, selectLot,
      suiviModal, openSuiviModal, saveSuiviFab, saveSuiviCond, clotureSuivi, deleteSuivi,
      arretModal, openArretModal, saveArret, closeArret, deleteArret,
      calModal, calEntries, calForm, openCalModal, addCalEntry, deleteCalEntry, CAL_TYPE_LABELS,
      bulkModal, bulkRows, bulkLieuList, bulkSetFamille, openBulkModal, bulkAddRow, bulkRemoveRow, bulkClear, onBulkPaste, onBulkColPaste, onReelPaste, bulkResolveDesignations, bulkCompute, bulkSave,
      campPanel, campSuggest, openCampPanel, campSearchCode, campSelectProduct, campInsert,
      deletePdpCond, savePdpReelle, recomputeAllPdp, pdpRecomputing, pdpErr,
      gsModal, GS_URL, openGsImport, fetchGsData, confirmGsImport,
      fmtDt, fmtDate, arretDuree
    }
  }
}
</script>

<style scoped>
.pdp-prod { min-height:100%; background:#0b0b1c; color:#e0e0f0; font-family:'Inter',sans-serif; font-size:13px; padding:0; }

/* ── HEADER ── */
.ph { display:flex; align-items:center; justify-content:space-between; gap:10px; padding:8px 16px; background:#0f0f23; border-bottom:2px solid #1a1a38; flex-wrap:wrap; }
.ph-l { display:flex; align-items:center; gap:12px; flex-wrap:wrap; }
.ph-r { display:flex; align-items:center; gap:6px; flex-wrap:wrap; }
.pt { font-size:11px; font-weight:700; letter-spacing:2px; text-transform:uppercase; color:#7c7cff; white-space:nowrap; }

/* vtabs */
.vtabs { display:flex; gap:3px; }
.vtab { display:flex; align-items:center; gap:5px; padding:5px 12px; font-size:11px; border:1px solid #252545; background:#12122a; color:#8888b0; border-radius:3px; cursor:pointer; transition:.15s; }
.vtab:hover { background:#1a1a35; color:#c0c0e8; }
.vtab.active { background:#1e3a6e; color:#93c5fd; border-color:#3b82f6; }
.vtab-ic { font-size:12px; }

/* btn-ref */
.btn-ref { padding:4px 10px; font-size:12px; border:1px solid #252545; background:#12122a; color:#8888b0; border-radius:3px; cursor:pointer; font-family:inherit; white-space:nowrap; }
.btn-ref:hover { border-color:#7c7cff; color:#c0c0e8; }
.btn-ref.spin { animation:spin .7s linear infinite; }
.btn-ref-on { border-color:#3b82f6; color:#93c5fd; background:#1e3a6e; }
@keyframes spin { to { transform:rotate(360deg) } }

/* Famille filter */
.fam-wrap { position:relative; }
.fam-panel { position:absolute; top:calc(100% + 4px); right:0; background:#12122a; border:1px solid #252545; border-radius:4px; box-shadow:0 6px 20px rgba(0,0,0,.4); z-index:300; padding:10px; min-width:160px; }
.fam-title { font-size:9px; font-weight:700; text-transform:uppercase; letter-spacing:.8px; color:#555; margin-bottom:8px; padding-bottom:6px; border-bottom:1px solid #1e1e3a; }
.fam-item { display:flex; align-items:center; gap:7px; font-size:12px; color:#b0b0cc; padding:5px 4px; border-radius:3px; cursor:pointer; user-select:none; white-space:nowrap; }
.fam-item:hover { background:#1a1a35; }
.fam-item input { cursor:pointer; accent-color:#3b82f6; flex-shrink:0; }
.fam-dot { width:8px; height:8px; border-radius:50%; flex-shrink:0; }
.fam-lbl { flex:1; }

/* Tableau */
.t-bar { display:flex; align-items:center; gap:8px; padding:8px 16px; flex-wrap:wrap; }
.t-srch { padding:5px 10px; font-size:12px; border:1px solid #252545; border-radius:3px; background:#12122a; color:#e0e0f0; font-family:inherit; outline:none; }
.t-srch:focus { border-color:#7c7cff; }
.t-sel { padding:5px 8px; font-size:12px; border:1px solid #252545; border-radius:3px; background:#12122a; color:#e0e0f0; font-family:inherit; outline:none; }
.btn-add { padding:5px 12px; font-size:11px; font-weight:600; border:none; border-radius:3px; background:#5B3CC4; color:#fff; cursor:pointer; }
.btn-add:hover { background:#4A2FA3; }
.btn-add-cond { background:#185FA5; }
.btn-add-cond:hover { background:#0C447C; }
.dt-wrap { overflow-x:auto; }
.dt { width:100%; border-collapse:collapse; font-size:12px; white-space:nowrap; }
.dt th { font-size:9px; text-transform:uppercase; color:#555; font-weight:600; padding:6px 10px; text-align:left; border-bottom:1px solid #1e1e3a; background:#0f0f23; position:sticky; top:0; }
.dt td { padding:7px 10px; border-bottom:1px solid #12122a; color:#b0b0cc; }
.dt tr:hover td { background:#0f0f1e; }
.mono { font-family:'SF Mono',monospace; font-size:11px; }
.sm { max-width:160px; overflow:hidden; text-overflow:ellipsis; }
.num { text-align:right; font-family:'SF Mono',monospace; }
.tc { text-align:center; }
.dim { color:#444; }
.acts { display:flex; gap:4px; }
.ia { padding:2px 8px; font-size:11px; border:1px solid #252545; border-radius:3px; background:transparent; color:#8888b0; cursor:pointer; }
.ia:hover { background:#1a1a35; color:#c0c0e8; }
.ia.ok { color:#10b981; border-color:#10b98144; }
.ia.ok:hover { background:#10b98122; }
.ia.del { color:#ef4444; border-color:#ef444444; }
.ia.del:hover { background:#ef444422; }
.empty { padding:30px; text-align:center; color:#444; font-size:12px; }
.ldg { padding:30px; text-align:center; color:#555; }

/* Badges */
.fam-badge { font-size:9px; font-weight:700; padding:2px 6px; border-radius:3px; }
.fb-fab { background:#5B3CC422; color:#a78bfa; border:1px solid #5B3CC444; }
.fb-cond { background:#185FA522; color:#60a5fa; border:1px solid #185FA544; }
.schip { font-size:10px; padding:2px 7px; border-radius:2px; font-weight:500; }
.sc-planifié,.sc-planifi { background:#1e3a6e33; color:#60a5fa; }
.sc-en-cours { background:#10b98133; color:#6ee7b7; }
.sc-arrêt,.sc-arr { background:#ef444433; color:#fca5a5; }
.sc-clôturé,.sc-cl { background:#1e293b; color:#475569; }
.row-running td { background:#ef444408; }
.row-annule td { opacity:.45; }

/* Arrêts stats */
.arr-stats { display:flex; gap:8px; margin-left:8px; }
.arr-stat { font-size:11px; color:#555; }
.arr-run { color:#ef444488; }

/* Gérer PDP section */
.pdp-section-title { font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:1px; color:#3b82f6; padding:12px 16px 4px; }

/* Modals */
.ov { position:fixed; inset:0; background:rgba(0,0,0,.65); display:flex; align-items:center; justify-content:center; z-index:500; }
.modal { background:#0f0f23; border:1px solid #252545; border-radius:8px; padding:24px; width:420px; max-width:96vw; max-height:92vh; overflow-y:auto; }
.modal-wide { width:720px; }
.modal-hd { font-size:14px; font-weight:600; color:#e0e0f0; margin-bottom:14px; }
.modal-ctx { font-size:11px; color:#555; background:#12122a; padding:6px 10px; border-radius:3px; margin-bottom:12px; }
.lbl { display:block; font-size:10px; color:#555; text-transform:uppercase; letter-spacing:.5px; margin:10px 0 4px; }
.inp { width:100%; padding:7px 10px; border:1px solid #252545; border-radius:3px; background:#12122a; color:#e0e0f0; font-size:12px; font-family:inherit; outline:none; box-sizing:border-box; }
.inp:focus { border-color:#7c7cff; }
.auto-wrap { position:relative; }
.auto-list { position:absolute; top:100%; left:0; right:0; background:#1a1a35; border:1px solid #252545; border-radius:4px; z-index:10; max-height:160px; overflow-y:auto; }
.auto-item { padding:7px 10px; font-size:12px; cursor:pointer; color:#b0b0cc; border-bottom:1px solid #1e1e3a; }
.auto-item:hover { background:#252545; }
.auto-code { font-family:'SF Mono',monospace; color:#60a5fa; margin-right:8px; }
.modal-err { font-size:11px; color:#ef4444; background:#ef444411; border-radius:3px; padding:6px 10px; margin-top:8px; }
.modal-acts { display:flex; gap:8px; margin-top:16px; }
.btn-save { padding:7px 16px; font-size:12px; font-weight:600; border:none; border-radius:3px; background:#3b82f6; color:#fff; cursor:pointer; }
.btn-save:hover:not(:disabled) { background:#2563eb; }
.btn-save:disabled { opacity:.4; cursor:not-allowed; }
.btn-save.btn-warn { background:#b45309; }
.btn-save.btn-warn:hover:not(:disabled) { background:#92400e; }
.btn-cancel { padding:7px 16px; font-size:12px; border:1px solid #252545; border-radius:3px; background:transparent; color:#8888b0; cursor:pointer; font-family:inherit; }
.btn-cancel:hover { color:#c0c0e8; border-color:#7c7cff; }

/* Saisie PDP en masse */
.modal-xwide { width:min(1480px, 96vw); }
.btn-ref-accent { border-color:#7c7cff; color:#c7c7ff; background:#1c1c3e; }
.btn-ref-accent:hover { background:#252550; color:#e0e0ff; }
.bulk-ctrl { display:flex; gap:12px; align-items:center; margin-bottom:12px; flex-wrap:wrap; }
.bulk-fam { display:inline-flex; border:1px solid #252545; border-radius:5px; overflow:hidden; }
.bulk-fam-btn { padding:6px 14px; font-size:12px; background:#12122a; color:#8888b0; border:none; cursor:pointer; font-family:inherit; }
.bulk-fam-btn.on { background:#3b82f6; color:#fff; font-weight:600; }
.bulk-lieu { max-width:300px; }
.bulk-il { display:inline-flex; align-items:center; gap:6px; font-size:11px; color:#8888b0; }
.bulk-mini { width:auto; padding:5px 8px; }
.bulk-grid-wrap { max-height:52vh; overflow:auto; border:1px solid #252545; border-radius:5px; }
.bulk-grid { width:100%; border-collapse:collapse; font-size:12px; }
.bulk-grid thead th { position:sticky; top:0; z-index:2; background:#12122a; color:#8888b0; font-weight:600; text-align:left; padding:7px 8px; font-size:10px; text-transform:uppercase; letter-spacing:.3px; border-bottom:1px solid #252545; white-space:nowrap; }
.bulk-grid td { padding:0; border-bottom:1px solid #1c1c38; vertical-align:middle; }
.bulk-grid .bg-idx { width:30px; text-align:center; color:#555; font-size:10px; padding:0 4px; }
.bg-inp { width:100%; padding:6px 8px; border:none; background:transparent; color:#e0e0f0; font-size:12px; font-family:inherit; outline:none; box-sizing:border-box; }
.bg-inp:focus { background:#1a1a35; box-shadow:inset 0 0 0 1px #7c7cff; }
.bg-num { text-align:right; }
.bg-w40 { width:46px; }
.bg-date { min-width:96px; }  /* dates jj/mm/aaaa affichées entièrement */
.bg-sel { padding:5px 4px; cursor:pointer; }
.bg-sel.vl-total { color:#fbbf24; }
.bg-sel.vl-partiel { color:#6ee7b7; }
.bg-calc { padding:6px 8px; text-align:right; font-family:'SF Mono',monospace; font-size:11px; color:#9999c0; white-space:nowrap; }
.bg-calc.bg-strong { color:#c7c7ff; font-weight:600; }
.lib-src { display:inline-block; margin-left:5px; font-size:9px; color:#666; font-family:inherit; }
.bg-desg { padding:6px 8px; color:#9999c0; font-size:11px; max-width:230px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.bg-desg.warn { color:#f59e0b; }
.bg-unknown-row { background:#f59e0b0d; }
.bulk-grid .acts { width:34px; text-align:center; }
.bulk-foot { display:flex; gap:8px; align-items:center; margin-top:10px; flex-wrap:wrap; }
.bulk-hint { font-size:11px; color:#6ee7b7; }
.bulk-cont { font-size:11px; color:#c7c7ff; background:#1c1c3e; border:1px solid #2a2a55; border-radius:4px; padding:6px 10px; margin-top:8px; }
.bulk-result { font-size:12px; color:#34d399; background:#10b98111; border:1px solid #10b98133; border-radius:4px; padding:8px 12px; margin-top:10px; }
/* Panneau campagne */
.camp-panel { background:#14142e; border:1px solid #2a2a55; border-radius:6px; padding:10px 12px; margin-bottom:12px; }
.camp-row { display:flex; gap:10px; align-items:flex-end; flex-wrap:wrap; }
.camp-f { display:flex; flex-direction:column; gap:3px; }
.camp-code { min-width:150px; }
.camp-desg-f { min-width:200px; flex:1; }
.camp-desg-v { font-size:12px; color:#9999c0; padding:6px 0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.camp-hint { font-size:11px; color:#8888b0; margin-top:6px; }
/* Fin réelle + retard */
.bg-reel { color:#6ee7b7 !important; }
.bg-reel:focus { box-shadow:inset 0 0 0 1px #34d399; }
.bg-retard { color:#fca5a5; }
.bg-avance { color:#6ee7b7; }
.pdp-section-row { display:flex; align-items:center; justify-content:space-between; gap:12px; flex-wrap:wrap; }
.pdp-err { font-size:11px; color:#ef4444; background:#ef444411; border-radius:3px; padding:6px 10px; margin:6px 0; }
.pdp-reel-inp { width:100%; min-width:120px; padding:4px 6px; border:1px solid #252545; border-radius:3px; background:#12122a; color:#6ee7b7; font-size:11px; font-family:'SF Mono',monospace; outline:none; box-sizing:border-box; }
.pdp-reel-inp:focus { border-color:#34d399; }

/* GS Import */
.gs-url { font-size:10px; color:#7c7cff; word-break:break-all; font-family:'SF Mono',monospace; }
.gs-cols { font-size:11px; color:#555; margin:8px 0 12px; }
.btn-gs-fetch { padding:7px 16px; font-size:12px; font-weight:600; border:1px solid #3b82f6; border-radius:3px; background:#1e3a6e; color:#93c5fd; cursor:pointer; margin-bottom:12px; }
.btn-gs-fetch:hover:not(:disabled) { background:#1e3a8e; }
.btn-gs-fetch:disabled { opacity:.4; cursor:not-allowed; }
.gs-err { font-size:11px; color:#ef4444; margin-bottom:8px; }
.gs-warn { font-size:11px; color:#f59e0b; margin-top:8px; }
.gs-preview { margin-top:10px; }
.gs-prev-title { font-size:11px; color:#555; margin-bottom:6px; }
.gs-prev-wrap { max-height:240px; overflow-y:auto; }
.gs-err-badge { font-size:10px; color:#ef4444; background:#ef444411; padding:2px 6px; border-radius:3px; }
.row-err td { color:#ef444488; }

/* Thème JOUR */
.pdp-prod[data-theme="day"] { background:#ffffff; color:#1a1a2e; font-family:'Inter',sans-serif; }
.pdp-prod[data-theme="day"] .ph { background:#ffffff; border-bottom:1px solid #e5e7eb; }
.pdp-prod[data-theme="day"] .pt { color:#7c3aed; }
.pdp-prod[data-theme="day"] .vtab { background:#f9fafb; color:#6b7280; border:none; }
.pdp-prod[data-theme="day"] .vtab:hover { background:#f3f4f6; color:#374151; }
.pdp-prod[data-theme="day"] .vtab.active { background:#7c3aed; color:#fff; border:none; }
.pdp-prod[data-theme="day"] .btn-ref { background:#f9fafb; color:#6b7280; border-color:#e5e7eb; }
.pdp-prod[data-theme="day"] .btn-ref:hover { border-color:#7c3aed; color:#7c3aed; }
.pdp-prod[data-theme="day"] .btn-ref-on { background:#f5f3ff; border-color:#7c3aed; color:#7c3aed; }
.pdp-prod[data-theme="day"] .fam-panel { background:#fff; border-color:#e5e7eb; box-shadow:0 6px 20px rgba(0,0,0,.1); }
.pdp-prod[data-theme="day"] .fam-title { color:#9ca3af; border-bottom-color:#f3f4f6; }
.pdp-prod[data-theme="day"] .fam-item { color:#374151; }
.pdp-prod[data-theme="day"] .fam-item:hover { background:#f9fafb; }
.pdp-prod[data-theme="day"] .t-srch,
.pdp-prod[data-theme="day"] .t-sel { background:#fff; border-color:#e5e7eb; color:#374151; }
.pdp-prod[data-theme="day"] .t-srch:focus { border-color:#7c3aed; }
/* Tableau — en-têtes violet (règle N°15) */
.pdp-prod[data-theme="day"] .dt th { background:#f5f3ff; color:#7c3aed; border-bottom:1px solid #ede9fe; font-size:10px; font-weight:700; }
.pdp-prod[data-theme="day"] .dt td { color:#374151; border-bottom-color:#f3f4f6; }
.pdp-prod[data-theme="day"] .dt tr:hover td { background:#faf5ff; }
/* Modal */
.pdp-prod[data-theme="day"] .modal { background:#fff; border-color:#e5e7eb; border-radius:10px; box-shadow:0 20px 50px rgba(0,0,0,.15); }
.pdp-prod[data-theme="day"] .modal-hd { color:#111827; font-weight:800; }
.pdp-prod[data-theme="day"] .modal-ctx { background:#f9fafb; color:#6b7280; }
.pdp-prod[data-theme="day"] .lbl { color:#6b7280; }
.pdp-prod[data-theme="day"] .inp { background:#fff; border-color:#e5e7eb; color:#111827; }
.pdp-prod[data-theme="day"] .inp:focus { border-color:#7c3aed; }
.pdp-prod[data-theme="day"] .auto-list { background:#fff; border-color:#e5e7eb; box-shadow:0 4px 12px rgba(0,0,0,.08); }
.pdp-prod[data-theme="day"] .auto-item { color:#374151; border-bottom-color:#f3f4f6; }
.pdp-prod[data-theme="day"] .auto-item:hover { background:#f5f3ff; }
.pdp-prod[data-theme="day"] .auto-code { color:#7c3aed; }
.pdp-prod[data-theme="day"] .pdp-section-title { color:#7c3aed; }
.pdp-prod[data-theme="day"] .btn-save { background:#7c3aed; }
.pdp-prod[data-theme="day"] .btn-save:hover:not(:disabled) { background:#6d28d9; }
.pdp-prod[data-theme="day"] .btn-cancel { border-color:#e5e7eb; color:#6b7280; }
.pdp-prod[data-theme="day"] .btn-cancel:hover { border-color:#7c3aed; color:#7c3aed; }
.pdp-prod[data-theme="day"] .gs-url { color:#7c3aed; }
.pdp-prod[data-theme="day"] .modal-err { background:#fef2f2; color:#ef4444; }
/* Saisie PDP en masse — thème jour */
.pdp-prod[data-theme="day"] .btn-ref-accent { background:#f5f3ff; border-color:#7c3aed; color:#7c3aed; }
.pdp-prod[data-theme="day"] .btn-ref-accent:hover { background:#ede9fe; }
.pdp-prod[data-theme="day"] .bulk-fam { border-color:#e5e7eb; }
.pdp-prod[data-theme="day"] .bulk-fam-btn { background:#f9fafb; color:#6b7280; }
.pdp-prod[data-theme="day"] .bulk-fam-btn.on { background:#7c3aed; color:#fff; }
.pdp-prod[data-theme="day"] .bulk-grid-wrap { border-color:#e5e7eb; }
.pdp-prod[data-theme="day"] .bulk-grid thead th { background:#f5f3ff; color:#7c3aed; border-bottom-color:#ede9fe; }
.pdp-prod[data-theme="day"] .bulk-grid td { border-bottom-color:#f3f4f6; }
.pdp-prod[data-theme="day"] .bg-inp { color:#111827; }
.pdp-prod[data-theme="day"] .bg-inp:focus { background:#faf9ff; box-shadow:inset 0 0 0 1px #7c3aed; }
.pdp-prod[data-theme="day"] .bg-desg { color:#6b7280; }
.pdp-prod[data-theme="day"] .bg-unknown-row { background:#fffbeb; }
.pdp-prod[data-theme="day"] .bulk-result { color:#065f46; background:#ecfdf5; border-color:#a7f3d0; }
.pdp-prod[data-theme="day"] .bulk-il { color:#6b7280; }
.pdp-prod[data-theme="day"] .bg-calc { color:#4b5563; }
.pdp-prod[data-theme="day"] .bg-calc.bg-strong { color:#7c3aed; }
.pdp-prod[data-theme="day"] .bg-sel.vl-total { color:#b45309; }
.pdp-prod[data-theme="day"] .bg-sel.vl-partiel { color:#047857; }
.pdp-prod[data-theme="day"] .lib-src { color:#9ca3af; }
.pdp-prod[data-theme="day"] .bulk-hint { color:#047857; }
.pdp-prod[data-theme="day"] .bulk-cont { color:#5b21b6; background:#f5f3ff; border-color:#ddd6fe; }
.pdp-prod[data-theme="day"] .camp-panel { background:#faf9ff; border-color:#ddd6fe; }
.pdp-prod[data-theme="day"] .camp-desg-v { color:#6b7280; }
.pdp-prod[data-theme="day"] .camp-hint { color:#6b7280; }
.pdp-prod[data-theme="day"] .pdp-err { background:#fef2f2; color:#dc2626; }
.pdp-prod[data-theme="day"] .pdp-reel-inp { background:#fff; color:#047857; border-color:#e5e7eb; }
.pdp-prod[data-theme="day"] .bg-reel { color:#047857 !important; }
.pdp-prod[data-theme="day"] .bg-retard { color:#dc2626; }
.pdp-prod[data-theme="day"] .bg-avance { color:#047857; }
/* Badges statut (règle N°15c) */
.pdp-prod[data-theme="day"] .sc-planifié,
.pdp-prod[data-theme="day"] .sc-planifi { background:#ede9fe; color:#7c3aed; }
.pdp-prod[data-theme="day"] .sc-en-cours { background:#d1fae5; color:#065f46; }
.pdp-prod[data-theme="day"] .sc-arrêt,
.pdp-prod[data-theme="day"] .sc-arr { background:#fee2e2; color:#dc2626; }
.pdp-prod[data-theme="day"] .sc-clôturé,
.pdp-prod[data-theme="day"] .sc-cl { background:#f3f4f6; color:#9ca3af; }

/* Polices / espacement tableau (alignement AdminFluxPage) */
.pdp-prod[data-theme="day"] .dt { font-size:13px; }
.pdp-prod[data-theme="day"] .dt th { font-size:11px; font-weight:700; padding:10px 12px; }
.pdp-prod[data-theme="day"] .dt td { padding:10px 12px; color:#374151; }
.pdp-prod[data-theme="day"] .dt-wrap { border:1px solid #e5e7eb; border-radius:8px; overflow-x:auto; overflow-y:auto; max-height:calc(100vh - 140px); }
/* Boutons add */
.pdp-prod[data-theme="day"] .btn-add { background:#7c3aed; border-radius:5px; font-size:12px; }
.pdp-prod[data-theme="day"] .btn-add:hover { background:#6d28d9; }
.pdp-prod[data-theme="day"] .btn-add-cond { background:#7c3aed; }
.pdp-prod[data-theme="day"] .btn-add-cond:hover { background:#6d28d9; }
/* Actions inline */
.pdp-prod[data-theme="day"] .ia { border-color:#e5e7eb; color:#6b7280; background:#fff; }
.pdp-prod[data-theme="day"] .ia:hover { background:#f9fafb; color:#374151; border-color:#d1d5db; }
.pdp-prod[data-theme="day"] .ia.ok { color:#059669; border-color:#bbf7d0; background:#f0fdf4; }
.pdp-prod[data-theme="day"] .ia.ok:hover { background:#dcfce7; }
.pdp-prod[data-theme="day"] .ia.del { color:#ef4444; border-color:#fecaca; background:#fff; }
.pdp-prod[data-theme="day"] .ia.del:hover { background:#fef2f2; }
/* Badges famille (règle N°15c) */
.pdp-prod[data-theme="day"] .fb-fab { background:#f5f3ff; color:#7c3aed; border-color:#ede9fe; }
.pdp-prod[data-theme="day"] .fb-cond { background:#dbeafe; color:#1e40af; border-color:#bfdbfe; }
/* Textes */
.pdp-prod[data-theme="day"] .dim { color:#9ca3af; }
.pdp-prod[data-theme="day"] .empty { color:#9ca3af; }
.pdp-prod[data-theme="day"] .ldg { color:#9ca3af; }
.pdp-prod[data-theme="day"] .arr-stat { color:#6b7280; }
.pdp-prod[data-theme="day"] .mono { color:#374151; }
/* Barre filtres */
.pdp-prod[data-theme="day"] .t-bar { background:#fff; border-bottom:1px solid #e5e7eb; }
.pdp-prod[data-theme="day"] .t-srch:focus { border-color:#7c3aed; }
/* Section title */
.pdp-prod[data-theme="day"] .pdp-section-title { background:transparent; }
/* Row running */
.pdp-prod[data-theme="day"] .row-running td { background:#fef9c3; }

/* Thème ATELIER */
.pdp-prod[data-theme="workshop"] { background:#161616; color:#f0f0f0; }
.pdp-prod[data-theme="workshop"] .ph { background:#1a1a1a; border-bottom-color:#2a2a2a; }
.pdp-prod[data-theme="workshop"] .pt { color:#ff9800; letter-spacing:3px; }
.pdp-prod[data-theme="workshop"] .vtab.active { background:#ff9800; color:#000; border-color:#ff9800; font-weight:700; }
.pdp-prod[data-theme="workshop"] .btn-ref { background:#1e1e1e; color:#aaa; border-color:#2a2a2a; }
/* Calendrier machines (modale) */
.cal-form { background: rgba(124,60,196,.05); border:1px solid rgba(124,60,196,.15); border-radius:8px; padding:12px; margin-bottom:14px; }
.cal-f-row { display:flex; gap:10px; margin-bottom:8px; flex-wrap:wrap; }
.cal-f-col { flex:1; min-width:120px; display:flex; flex-direction:column; gap:3px; }
.cal-f-2 { flex:2; }
.cal-list { max-height:42vh; overflow:auto; }
.cal-t-ferie        { background:#ede9fe; color:#7c3aed; }
.cal-t-arret_annuel { background:#fef3c7; color:#92400e; }
.cal-t-fermeture    { background:#f3f4f6; color:#374151; }
.cal-t-maintenance  { background:#e6f1fb; color:#2563eb; }
</style>
