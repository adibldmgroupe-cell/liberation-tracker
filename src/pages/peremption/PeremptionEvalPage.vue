<template>
  <div v-if="product" class="pe">
    <div class="bc"><span @click="goBack">← Retour à la matrice</span></div>

    <!-- En-tête produit -->
    <div class="lh">
      <div class="lh-info">
        <div class="lh-type"><span class="lt-short">{{ product.code_article }}</span> <span class="lt-full">(Risque de péremption)</span></div>
        <div class="lh-lot"><span class="ll-prod">{{ product.description }}</span></div>
        <div class="lh-part">Partenaire : <strong>{{ product.fabricant || '—' }}</strong></div>
      </div>
      <div class="lh-right">
        <span v-if="preview.niveau" class="niv" :class="NIVEAU_CLASS[preview.niveau]">{{ NIVEAU_LABELS[preview.niveau] }}</span>
        <span v-else class="niv niv-na">À évaluer</span>
        <div class="gl" v-if="preview.score_global != null">Global {{ preview.score_global }}</div>
      </div>
    </div>

    <div v-if="submitting" class="detail-reloading">⟳ Enregistrement…</div>

    <!-- Mode d'approvisionnement -->
    <div class="section">
      <div class="sh"><span>Mode d'approvisionnement</span></div>
      <div class="appro-row">
        <button v-for="m in MODE_APPRO" :key="m.key" class="appro-btn" :class="{on: modeAppro===m.key}" @click="modeAppro = m.key">{{ m.label }}</button>
      </div>
    </div>

    <!-- Axes de scoring -->
    <div class="section" v-for="ax in AXES" :key="ax.key">
      <div class="sh">
        <span>Axe {{ ax.label }}</span>
        <span class="ax-score" v-if="axisVal(ax.key) != null">moyenne {{ axisVal(ax.key) }} · {{ axWeight(ax) }}%</span>
        <span class="ax-score muted" v-else>{{ axWeight(ax) }}%</span>
      </div>
      <div class="crit" v-for="c in critFor(ax.key)" :key="c.key">
        <div class="crit-head">
          <span class="crit-label">{{ c.label }}</span>
          <span class="crit-logique" :title="c.logique">ⓘ {{ c.logique }}</span>
        </div>
        <div class="crit-hint" v-if="hintFor(c.key)">{{ hintFor(c.key) }}</div>
        <div class="scores">
          <button v-for="v in vals(c)" :key="v"
            class="sc" :class="['sc-'+v, {on: scores[c.key]===v}]"
            @click="setScore(c.key, v)">
            <span class="sc-n">{{ v }}</span>
            <span class="sc-t">{{ labelFor(c, v) }}</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Synthèse -->
    <div class="section">
      <div class="sh"><span>Synthèse</span><span class="dc">{{ filledCount }}/9</span></div>
      <div class="synth">
        <div class="synth-axes">
          <div class="sa"><span class="sa-l">Produit</span><span class="sa-v">{{ disp(preview.score_produit) }}</span></div>
          <div class="sa"><span class="sa-l">Partenaire</span><span class="sa-v">{{ disp(preview.score_partenaire) }}</span></div>
          <div class="sa"><span class="sa-l">Marché</span><span class="sa-v">{{ disp(preview.score_marche) }}</span></div>
        </div>
        <div class="synth-global">
          <div class="sg-l">Score global pondéré</div>
          <div class="sg-v">{{ disp(preview.score_global) }}</div>
          <span v-if="preview.niveau" class="niv niv-big" :class="NIVEAU_CLASS[preview.niveau]">{{ NIVEAU_LABELS[preview.niveau] }}</span>
        </div>
      </div>
      <textarea v-model="note" class="note" rows="2" placeholder="Note / justification (optionnel)…"></textarea>
      <div class="save-row">
        <button class="btn-save" :disabled="submitting || !canEval || !isReady" @click="save">
          {{ submitting ? 'Enregistrement…' : (canEval ? 'Enregistrer l\'évaluation' : 'Permission requise') }}
        </button>
        <span v-if="!isReady && canEval" class="save-hint">Renseigne les 9 sous-critères ({{ 9 - filledCount }} restant{{ 9 - filledCount > 1 ? 's' : '' }})</span>
        <span v-if="saveOk" class="save-ok">✓ Évaluation enregistrée</span>
      </div>
    </div>

    <!-- Historique -->
    <div class="section" v-if="history.length">
      <div class="sh"><span>Historique des évaluations</span></div>
      <div class="circ-hist">
        <div class="circ-hist-row" v-for="h in history" :key="h.id">
          <span class="niv niv-sm" :class="NIVEAU_CLASS[h.niveau]">{{ NIVEAU_LABELS[h.niveau] || '—' }}</span>
          <span class="hh-global">Global {{ h.score_global != null ? h.score_global : '—' }}</span>
          <span class="hh-detail">P {{ disp(h.score_produit) }} · Pa {{ disp(h.score_partenaire) }} · M {{ disp(h.score_marche) }}</span>
          <span class="hh-who">{{ h.who }}</span>
          <span class="hh-at">{{ fmtDt(h.evaluated_at) }}</span>
        </div>
      </div>
    </div>
  </div>
  <div v-else class="loading">{{ notFound ? 'Produit introuvable.' : 'Chargement…' }}</div>
</template>

<script>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import { loadPermissions, canPerform } from '../../services/permissions'
import { AXES, CRITERIA, MODE_APPRO, DEFAULT_CONFIG, NIVEAU_LABELS, NIVEAU_CLASS,
  criteriaForAxe, allowedValues, axisScore, computeScores, isComplete } from '../../services/peremptionRisk'

export default {
  setup() {
    var route = useRoute(), router = useRouter()
    var product = ref(null), notFound = ref(false)
    var config = ref(Object.assign({}, DEFAULT_CONFIG))
    var scores = reactive({})
    var modeAppro = ref('')
    var note = ref('')
    var history = ref([])
    var userId = ref(null), userService = ref('')
    var canEval = ref(false)
    var submitting = ref(false)
    var saveOk = ref(false)

    CRITERIA.forEach(function (c) { scores[c.key] = null })

    var preview = computed(function () { return computeScores(scores, config.value) })
    var filledCount = computed(function () {
      return CRITERIA.filter(function (c) { var v = scores[c.key]; return v === 1 || v === 3 || v === 5 }).length
    })
    var isReady = computed(function () { return isComplete(scores) })

    var critFor = function (axeKey) { return criteriaForAxe(axeKey) }
    var vals = function (c) { return allowedValues(c) }
    var axisVal = function (axeKey) { var v = axisScore(scores, axeKey); return v == null ? null : Math.round(v * 100) / 100 }
    var axWeight = function (ax) { return Number(config.value[ax.poidsKey]) || 0 }
    var disp = function (v) { return v == null ? '—' : v }
    var labelFor = function (c, v) { return v === 1 ? c.s1 : (v === 3 ? c.s3 : c.s5) }
    var setScore = function (key, v) { scores[key] = v; saveOk.value = false }
    var fmtDt = function (d) { return d ? new Date(d).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' }) : '' }

    // indices de référence depuis le catalogue (aide à la décision, scoring reste manuel)
    var hintFor = function (key) {
      var p = product.value; if (!p) return ''
      if (key === 'sc_shelf_life' && p.duree_vie) return 'Catalogue — durée de vie : ' + p.duree_vie + ' mois'
      if (key === 'sc_prix') {
        var px = p.prix_vente || p.ppa || p.shp
        if (px) return 'Catalogue — prix unitaire : ' + px + ' DA'
      }
      return ''
    }

    var goBack = function () { router.push('/peremption') }

    var save = async function () {
      if (submitting.value || !canEval.value || !isReady.value) return
      submitting.value = true; saveOk.value = false
      try {
        var sc = computeScores(scores, config.value)
        var payload = {
          product_id: product.value.id,
          mode_appro: modeAppro.value || null,
          sc_shelf_life: scores.sc_shelf_life, sc_prix: scores.sc_prix, sc_historique: scores.sc_historique,
          sc_forecast: scores.sc_forecast, sc_solvabilite: scores.sc_solvabilite, sc_engagements: scores.sc_engagements,
          sc_croissance: scores.sc_croissance, sc_concurrence: scores.sc_concurrence, sc_maturite: scores.sc_maturite,
          score_produit: sc.score_produit, score_partenaire: sc.score_partenaire, score_marche: sc.score_marche,
          score_global: sc.score_global, niveau: sc.niveau,
          note: note.value || null,
          evaluated_by: userId.value, evaluated_at: new Date().toISOString()
        }
        var res = await supabase.from('peremption_evaluations').insert(payload)
        if (res.error) { alert('Erreur : ' + res.error.message); return }
        saveOk.value = true
        await loadHistory()
      } finally { submitting.value = false }
    }

    var loadHistory = async function () {
      try {
        // ⚠️ Pas d'embedding profiles(...) : evaluated_by n'a pas de FK → requête séparée (règle N°2)
        var res = await supabase.from('peremption_evaluations')
          .select('*').eq('product_id', route.params.productId).order('evaluated_at', { ascending: false })
        var rows = res.data || []
        var uids = []
        rows.forEach(function (r) { if (r.evaluated_by && uids.indexOf(r.evaluated_by) < 0) uids.push(r.evaluated_by) })
        var pmap = {}
        if (uids.length) {
          var pr = await supabase.from('profiles').select('id,prenom,nom').in('id', uids)
            ; (pr.data || []).forEach(function (p) { pmap[p.id] = (p.prenom || '') + ' ' + (p.nom || '') })
        }
        history.value = rows.map(function (h) { return Object.assign({}, h, { who: pmap[h.evaluated_by] || '' }) })
      } catch (e) { history.value = [] }
    }

    var load = async function () {
      notFound.value = false
      var pRes = await supabase.from('products').select('id, code_article, description, fabricant, duree_vie, prix_vente, ppa, shp').eq('id', route.params.productId).single()
      if (!pRes.data) { notFound.value = true; product.value = null; return }
      product.value = pRes.data
      try {
        var cfgRes = await supabase.from('peremption_config').select('*').eq('id', 1).maybeSingle()
        if (cfgRes.data) config.value = cfgRes.data
      } catch (e) { /* table absente : on garde DEFAULT_CONFIG */ }
      await loadHistory()
      // préremplir avec la dernière évaluation
      var last = history.value[0]
      CRITERIA.forEach(function (c) { scores[c.key] = last && (last[c.key] === 1 || last[c.key] === 3 || last[c.key] === 5) ? last[c.key] : null })
      modeAppro.value = last && last.mode_appro ? last.mode_appro : ''
      note.value = ''
    }

    onMounted(async function () {
      var u = await supabase.auth.getUser()
      if (u.data.user) {
        userId.value = u.data.user.id
        var p = await supabase.from('profiles').select('service').eq('id', u.data.user.id).single()
        if (p.data) { userService.value = p.data.service; await loadPermissions(p.data.service) }
      }
      canEval.value = canPerform('evaluer_risque_peremption')
      await load()
    })
    watch(function () { return route.params.productId }, function (nv, ov) { if (nv && nv !== ov) location.reload() })

    return {
      product, notFound, scores, modeAppro, note, history, submitting, saveOk, canEval, isReady, filledCount,
      preview, AXES, MODE_APPRO, NIVEAU_LABELS, NIVEAU_CLASS,
      critFor, vals, axisVal, axWeight, disp, labelFor, setScore, hintFor, fmtDt, goBack, save
    }
  }
}
</script>

<style scoped>
.pe { font-family: 'Inter', sans-serif; }
.bc { font-size: 12px; color: #7c3aed; cursor: pointer; margin-bottom: 8px; }
.lh { display: flex; align-items: flex-start; justify-content: space-between; padding-bottom: 10px; border-bottom: 1px solid var(--th-border, #e5e7eb); flex-wrap: wrap; gap: 10px; }
.lh-info { display: flex; flex-direction: column; gap: 3px; min-width: 0; }
.lh-type { font-size: 17px; line-height: 1.25; } .lt-short { font-weight: 700; font-family: 'SF Mono', monospace; } .lt-full { font-size: 13px; color: var(--th-text2, #999); font-weight: 400; }
.lh-lot { font-size: 13px; } .ll-prod { color: var(--th-text2, #999); }
.lh-part { font-size: 12px; color: var(--th-text2, #6b7280); } .lh-part strong { color: var(--th-text, #333); }
.lh-right { flex-shrink: 0; text-align: right; }
.gl { font-size: 11px; color: var(--th-text2, #6b7280); margin-top: 4px; font-family: 'SF Mono', monospace; }
.loading { text-align: center; padding: 60px; color: #999; }
.detail-reloading { font-size: 11px; color: #999; padding: 4px 0 6px; animation: spin-txt 1s linear infinite; }
@keyframes spin-txt { 0% { opacity: 1 } 50% { opacity: .4 } 100% { opacity: 1 } }

.section { margin-top: 16px; }
.sh { display: flex; justify-content: space-between; align-items: center; font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px; color: var(--th-text2, #999); padding-bottom: 6px; border-bottom: 1px solid var(--th-border, #e8e8e8); }
.dc { font-family: 'SF Mono', monospace; color: #BA7517; }
.ax-score { font-family: 'SF Mono', monospace; color: #7c3aed; text-transform: none; letter-spacing: 0; }
.ax-score.muted { color: var(--th-text3, #bbb); }

.appro-row { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 10px; }
.appro-btn { font-size: 12px; padding: 7px 14px; border-radius: 6px; border: 1px solid var(--th-border, #e5e7eb); background: var(--th-bg2, #fff); color: var(--th-text2, #555); cursor: pointer; }
.appro-btn:hover { border-color: #c4b5fd; }
.appro-btn.on { background: #f5f3ff; border-color: #7c3aed; color: #7c3aed; font-weight: 600; }

.crit { padding: 10px 0; border-bottom: 1px solid var(--th-border, #f0f0f0); }
.crit:last-child { border-bottom: none; }
.crit-head { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
.crit-label { font-size: 13px; font-weight: 600; color: var(--th-text, #222); }
.crit-logique { font-size: 11px; color: var(--th-text3, #9ca3af); }
.crit-hint { font-size: 11px; color: #7c3aed; margin-top: 2px; }
.scores { display: flex; gap: 8px; margin-top: 8px; flex-wrap: wrap; }
.sc { flex: 1; min-width: 140px; display: flex; align-items: center; gap: 8px; padding: 8px 12px; border-radius: 7px; border: 1px solid var(--th-border, #e5e7eb); background: var(--th-bg2, #fff); cursor: pointer; text-align: left; }
.sc:hover { border-color: #c4b5fd; }
.sc-n { font-size: 14px; font-weight: 800; font-family: 'SF Mono', monospace; width: 18px; flex-shrink: 0; color: var(--th-text2, #6b7280); }
.sc-t { font-size: 11px; color: var(--th-text2, #555); line-height: 1.2; }
.sc-1.on { background: #d1fae5; border-color: #1D9E75; } .sc-1.on .sc-n, .sc-1.on .sc-t { color: #065f46; }
.sc-3.on { background: #fef3c7; border-color: #d99e2b; } .sc-3.on .sc-n, .sc-3.on .sc-t { color: #92400e; }
.sc-5.on { background: #FCEBEB; border-color: #E24B4A; } .sc-5.on .sc-n, .sc-5.on .sc-t { color: #b91c1c; }

.synth { display: flex; gap: 16px; align-items: stretch; margin-top: 12px; flex-wrap: wrap; }
.synth-axes { display: flex; gap: 8px; flex: 1; min-width: 220px; }
.sa { flex: 1; border: 1px solid var(--th-border, #e8e8e8); border-radius: 8px; padding: 10px; text-align: center; background: var(--th-bg2, #fff); }
.sa-l { display: block; font-size: 10px; text-transform: uppercase; letter-spacing: .5px; color: var(--th-text2, #6b7280); }
.sa-v { display: block; font-size: 20px; font-weight: 800; font-family: 'SF Mono', monospace; color: var(--th-text, #1a1a2e); margin-top: 2px; }
.synth-global { border: 1px solid #ede9fe; background: #f5f3ff; border-radius: 8px; padding: 10px 16px; text-align: center; display: flex; flex-direction: column; align-items: center; justify-content: center; min-width: 150px; }
.sg-l { font-size: 10px; text-transform: uppercase; letter-spacing: .5px; color: #7c3aed; }
.sg-v { font-size: 28px; font-weight: 800; font-family: 'SF Mono', monospace; color: #7c3aed; line-height: 1.1; }

.note { width: 100%; box-sizing: border-box; margin-top: 12px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 6px; padding: 8px 10px; font-size: 13px; font-family: inherit; resize: vertical; background: var(--th-input-bg, #fff); color: inherit; }
.save-row { display: flex; align-items: center; gap: 12px; margin-top: 10px; flex-wrap: wrap; }
.btn-save { font-size: 13px; font-weight: 700; padding: 9px 20px; border-radius: 6px; border: none; background: #7c3aed; color: #fff; cursor: pointer; }
.btn-save:hover { opacity: .9; } .btn-save:disabled { opacity: .45; cursor: not-allowed; }
.save-hint { font-size: 12px; color: var(--th-text2, #9ca3af); }
.save-ok { font-size: 12px; color: #1D9E75; font-weight: 600; }

.niv { display: inline-block; font-size: 12px; font-weight: 700; padding: 3px 12px; border-radius: 10px; white-space: nowrap; }
.niv-sm { font-size: 11px; padding: 2px 9px; }
.niv-big { font-size: 13px; padding: 4px 14px; margin-top: 6px; }
.niv-faible { background: #d1fae5; color: #065f46; }
.niv-moyen { background: #fef3c7; color: #92400e; }
.niv-eleve { background: #FCEBEB; color: #b91c1c; }
.niv-na { background: #f3f4f6; color: #9ca3af; }

.circ-hist { margin-top: 10px; border: 1px solid var(--th-border, #e8e8e8); border-radius: 6px; padding: 6px 12px; }
.circ-hist-row { display: flex; align-items: center; gap: 12px; font-size: 12px; padding: 6px 0; border-bottom: 1px solid var(--th-border, #f5f5f5); flex-wrap: wrap; }
.circ-hist-row:last-child { border-bottom: none; }
.hh-global { font-family: 'SF Mono', monospace; font-weight: 700; color: var(--th-text, #333); }
.hh-detail { font-size: 11px; color: var(--th-text2, #6b7280); font-family: 'SF Mono', monospace; }
.hh-who { color: var(--th-text2, #999); margin-left: auto; }
.hh-at { font-family: 'SF Mono', monospace; font-size: 10px; color: var(--th-text3, #bbb); }

/* Overrides sombre (RÈGLE N°15c) */
html[data-theme="night"] .synth-global, html[data-theme="workshop"] .synth-global { background: var(--th-bg3); border-color: var(--th-border); }
html[data-theme="night"] .appro-btn.on, html[data-theme="workshop"] .appro-btn.on { background: var(--th-bg3); }
html[data-theme="night"] .crit-hint, html[data-theme="workshop"] .crit-hint { color: var(--th-accent); }
html[data-theme="night"] .sc-1.on, html[data-theme="workshop"] .sc-1.on { background: rgba(52,211,153,.14); } html[data-theme="night"] .sc-1.on .sc-n, html[data-theme="night"] .sc-1.on .sc-t, html[data-theme="workshop"] .sc-1.on .sc-n, html[data-theme="workshop"] .sc-1.on .sc-t { color: #6ee7b7; }
html[data-theme="night"] .sc-3.on, html[data-theme="workshop"] .sc-3.on { background: rgba(251,191,36,.16); } html[data-theme="night"] .sc-3.on .sc-n, html[data-theme="night"] .sc-3.on .sc-t, html[data-theme="workshop"] .sc-3.on .sc-n, html[data-theme="workshop"] .sc-3.on .sc-t { color: #fbbf24; }
html[data-theme="night"] .sc-5.on, html[data-theme="workshop"] .sc-5.on { background: rgba(239,68,68,.16); } html[data-theme="night"] .sc-5.on .sc-n, html[data-theme="night"] .sc-5.on .sc-t, html[data-theme="workshop"] .sc-5.on .sc-n, html[data-theme="workshop"] .sc-5.on .sc-t { color: #fca5a5; }
html[data-theme="night"] .niv-faible, html[data-theme="workshop"] .niv-faible { background: rgba(52,211,153,.12); color: #6ee7b7; }
html[data-theme="night"] .niv-moyen, html[data-theme="workshop"] .niv-moyen { background: rgba(251,191,36,.12); color: #fbbf24; }
html[data-theme="night"] .niv-eleve, html[data-theme="workshop"] .niv-eleve { background: rgba(239,68,68,.12); color: #fca5a5; }
html[data-theme="night"] .niv-na, html[data-theme="workshop"] .niv-na { background: var(--th-bg3); color: var(--th-text3, #9ca3af); }

@media (max-width: 768px) { .sc { min-width: 100%; } .synth { flex-direction: column; } }
</style>
