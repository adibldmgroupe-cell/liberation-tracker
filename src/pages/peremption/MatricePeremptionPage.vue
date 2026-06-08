<template>
  <div class="mp">
    <!-- En-tête -->
    <div class="fa-header">
      <div>
        <div class="fa-title">⚠️ Matrice des risques de péremption</div>
        <div class="fa-sub">{{ products.length }} produit(s) · {{ evaluatedCount }} évalué(s) · {{ products.length - evaluatedCount }} à évaluer</div>
      </div>
      <div class="fa-actions">
        <button v-if="canConfig" class="mp-btn-cfg" @click="openConfig">⚙ Pondérations &amp; seuils</button>
      </div>
    </div>

    <!-- Migration non exécutée -->
    <div v-if="needsMigration" class="mp-warn">
      ⚠️ Tables absentes — exécute la migration <code>034_peremption_risk.sql</code> dans Supabase SQL Editor, puis recharge.
    </div>

    <!-- KPI par niveau -->
    <div class="mp-kpis">
      <button class="mp-kpi" :class="{on:niveauFilter===''}" @click="niveauFilter=''">
        <span class="k-n">{{ products.length }}</span><span class="k-l">Tous</span>
      </button>
      <button class="mp-kpi kpi-faible" :class="{on:niveauFilter==='faible'}" @click="toggleNiveau('faible')">
        <span class="k-n">{{ counts.faible }}</span><span class="k-l">🟢 Faible</span>
      </button>
      <button class="mp-kpi kpi-moyen" :class="{on:niveauFilter==='moyen'}" @click="toggleNiveau('moyen')">
        <span class="k-n">{{ counts.moyen }}</span><span class="k-l">🟡 Moyen</span>
      </button>
      <button class="mp-kpi kpi-eleve" :class="{on:niveauFilter==='eleve'}" @click="toggleNiveau('eleve')">
        <span class="k-n">{{ counts.eleve }}</span><span class="k-l">🔴 Élevé</span>
      </button>
      <button class="mp-kpi kpi-na" :class="{on:niveauFilter==='na'}" @click="toggleNiveau('na')">
        <span class="k-n">{{ counts.na }}</span><span class="k-l">Non évalué</span>
      </button>
    </div>

    <!-- Toolbar -->
    <div class="mp-toolbar">
      <div class="mp-search-wrap">
        <span class="ts-icon">🔍</span>
        <input v-model="searchQ" class="mp-search" placeholder="Rechercher code, désignation, fabricant…" />
      </div>
      <select v-model="typeFilter" class="mp-type-filter">
        <option value="">Tous les types</option>
        <option value="generique">Générique (production)</option>
        <option value="otc">OTC (production)</option>
        <option value="sous_licence">Sous-licence</option>
        <option value="import">Import / Revente</option>
      </select>
    </div>

    <div v-if="loading" class="em">Chargement…</div>
    <div v-else-if="!filtered.length" class="em">Aucun produit{{ searchQ || niveauFilter ? ' pour ce filtre.' : '.' }}</div>
    <div v-else class="table-wrap">
      <table class="pt-table">
        <thead>
          <tr>
            <th>Code</th>
            <th>Désignation</th>
            <th>Partenaire (fabricant)</th>
            <th class="tc">Type</th>
            <th>Appro.</th>
            <th class="tc">Produit</th>
            <th class="tc">Partenaire</th>
            <th class="tc">Marché</th>
            <th class="tc">Global</th>
            <th class="tc">Niveau</th>
            <th class="tc">Validation</th>
            <th>Dernière éval.</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in filtered" :key="r.id" @click="goEval(r.id)" class="clk">
            <td class="mono">{{ r.code_article }}</td>
            <td class="td-desc">{{ r.description }}</td>
            <td>{{ r.fabricant || '—' }}</td>
            <td class="tc"><span class="ty" :class="TYPE_CLASS[r.type]">{{ TYPE_LABELS[r.type] }}</span></td>
            <td class="mode">{{ r.ev ? (MODE_APPRO_LABELS[r.ev.mode_appro] || '—') : '—' }}</td>
            <td class="tc mono">{{ r.ev && r.ev.score_produit != null ? r.ev.score_produit : '—' }}</td>
            <td class="tc mono">{{ r.ev && r.ev.score_partenaire != null ? r.ev.score_partenaire : '—' }}</td>
            <td class="tc mono">{{ r.ev && r.ev.score_marche != null ? r.ev.score_marche : '—' }}</td>
            <td class="tc mono strong">{{ r.ev && r.ev.score_global != null ? r.ev.score_global : '—' }}</td>
            <td class="tc">
              <span v-if="r.ev && r.ev.niveau" class="niv" :class="NIVEAU_CLASS[r.ev.niveau]">{{ NIVEAU_LABELS[r.ev.niveau] }}</span>
              <span v-else class="niv niv-na">Non évalué</span>
            </td>
            <td class="tc">
              <span v-if="valNiveau(r.ev)" class="valid-tag">Niveau {{ valNiveau(r.ev) }}</span>
              <span v-else class="val-none">—</span>
            </td>
            <td class="dt">{{ r.ev ? fmtDate(r.ev.evaluated_at) : '—' }}</td>
            <td class="tar"><button class="btn-eval" @click.stop="goEval(r.id)">{{ r.ev ? 'Réévaluer' : 'Évaluer' }}</button></td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal config pondérations & seuils -->
    <div class="overlay" v-if="showConfig" @click.self="showConfig=false">
      <div class="modal">
        <div class="mt">Pondérations &amp; seuils</div>
        <div class="modal-body-inner">
          <div class="cfg-sec">Pondération des axes (doit totaliser 100)</div>
          <div class="fg3">
            <div class="fi"><label>Produit (%)</label><input v-model.number="cfgForm.poids_produit" type="number" class="inp" /></div>
            <div class="fi"><label>Partenaire (%)</label><input v-model.number="cfgForm.poids_partenaire" type="number" class="inp" /></div>
            <div class="fi"><label>Marché (%)</label><input v-model.number="cfgForm.poids_marche" type="number" class="inp" /></div>
          </div>
          <div class="cfg-tot" :class="{bad: poidsTotal !== 100}">Total : {{ poidsTotal }} %</div>
          <div class="cfg-sec">Seuils de niveau (score global 1 → 5)</div>
          <div class="fg2">
            <div class="fi"><label>≤ ce seuil = 🟢 Faible</label><input v-model.number="cfgForm.seuil_moyen" type="number" step="0.1" class="inp" /></div>
            <div class="fi"><label>≤ ce seuil = 🟡 Moyen (sinon 🔴 Élevé)</label><input v-model.number="cfgForm.seuil_eleve" type="number" step="0.1" class="inp" /></div>
          </div>
          <div class="cfg-hint">Aperçu : ≤ {{ cfgForm.seuil_moyen }} Faible · ≤ {{ cfgForm.seuil_eleve }} Moyen · &gt; {{ cfgForm.seuil_eleve }} Élevé</div>
          <div class="merr" v-if="cfgErr">{{ cfgErr }}</div>
        </div>
        <div class="ma">
          <button class="mp-btn-cfg" :disabled="cfgSaving" @click="saveConfig">{{ cfgSaving ? '…' : 'Enregistrer' }}</button>
          <button class="bc2" @click="showConfig=false">Annuler</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import { loadPermissions, canPerform } from '../../services/permissions'
import { NIVEAU_LABELS, NIVEAU_CLASS, NIVEAU_ORDER, MODE_APPRO_LABELS, DEFAULT_CONFIG, decisionsFor, productType, TYPE_LABELS, TYPE_CLASS } from '../../services/peremptionRisk'

export default {
  setup() {
    var router = useRouter()
    var products = ref([])
    var evMap = ref({})
    var config = ref(Object.assign({}, DEFAULT_CONFIG))
    var loading = ref(true)
    var needsMigration = ref(false)
    var searchQ = ref('')
    var niveauFilter = ref('')
    var typeFilter = ref('')
    var userService = ref('')
    var canConfig = ref(false)

    // Config modal
    var showConfig = ref(false)
    var cfgForm = ref(Object.assign({}, DEFAULT_CONFIG))
    var cfgSaving = ref(false)
    var cfgErr = ref('')

    var rows = computed(function () {
      return products.value.map(function (p) {
        return { id: p.id, code_article: p.code_article, description: p.description, fabricant: p.fabricant, type: productType(p), ev: evMap.value[p.id] || null }
      })
    })
    var evaluatedCount = computed(function () { return rows.value.filter(function (r) { return r.ev }).length })
    var counts = computed(function () {
      var c = { faible: 0, moyen: 0, eleve: 0, na: 0 }
      rows.value.forEach(function (r) {
        if (r.ev && r.ev.niveau) c[r.ev.niveau] = (c[r.ev.niveau] || 0) + 1
        else c.na++
      })
      return c
    })
    var filtered = computed(function () {
      var q = searchQ.value.trim().toLowerCase()
      var nf = niveauFilter.value
      var tf = typeFilter.value
      var arr = rows.value.filter(function (r) {
        if (tf && r.type !== tf) return false
        if (nf === 'na') { if (r.ev && r.ev.niveau) return false }
        else if (nf) { if (!r.ev || r.ev.niveau !== nf) return false }
        if (!q) return true
        return (r.code_article || '').toLowerCase().includes(q)
          || (r.description || '').toLowerCase().includes(q)
          || (r.fabricant || '').toLowerCase().includes(q)
      })
      // tri : niveau décroissant (Élevé d'abord), puis non évalués, puis code
      return arr.sort(function (a, b) {
        var na = a.ev && a.ev.niveau ? NIVEAU_ORDER[a.ev.niveau] : 0
        var nb = b.ev && b.ev.niveau ? NIVEAU_ORDER[b.ev.niveau] : 0
        if (na !== nb) return nb - na
        return (a.code_article || '').localeCompare(b.code_article || '')
      })
    })
    var poidsTotal = computed(function () {
      return (Number(cfgForm.value.poids_produit) || 0) + (Number(cfgForm.value.poids_partenaire) || 0) + (Number(cfgForm.value.poids_marche) || 0)
    })

    var fmtDate = function (d) { return d ? new Date(d).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: '2-digit' }) : '—' }
    var valNiveau = function (ev) { if (!ev || !ev.niveau) return null; var d = decisionsFor(ev.niveau); return d ? d.validation : null }
    var toggleNiveau = function (n) { niveauFilter.value = niveauFilter.value === n ? '' : n }
    var goEval = function (id) { router.push('/peremption/' + id) }

    var openConfig = function () { cfgForm.value = Object.assign({}, config.value); cfgErr.value = ''; showConfig.value = true }
    var saveConfig = async function () {
      if (poidsTotal.value !== 100) { cfgErr.value = 'La somme des pondérations doit faire 100 %.'; return }
      if (Number(cfgForm.value.seuil_moyen) >= Number(cfgForm.value.seuil_eleve)) { cfgErr.value = 'Le seuil Faible doit être inférieur au seuil Moyen.'; return }
      cfgSaving.value = true; cfgErr.value = ''
      var u = await supabase.auth.getUser()
      var payload = {
        id: 1,
        poids_produit: Number(cfgForm.value.poids_produit) || 0,
        poids_partenaire: Number(cfgForm.value.poids_partenaire) || 0,
        poids_marche: Number(cfgForm.value.poids_marche) || 0,
        seuil_moyen: Number(cfgForm.value.seuil_moyen),
        seuil_eleve: Number(cfgForm.value.seuil_eleve),
        updated_at: new Date().toISOString(),
        updated_by: u.data.user ? u.data.user.id : null
      }
      var res = await supabase.from('peremption_config').upsert(payload, { onConflict: 'id' })
      if (res.error) { cfgErr.value = res.error.message; cfgSaving.value = false; return }
      config.value = payload
      showConfig.value = false; cfgSaving.value = false
    }

    var load = async function () {
      loading.value = true; needsMigration.value = false
      // 1. Produits actifs EN PREMIER (table toujours présente, indépendante du module)
      var pRes = await supabase.from('products').select('id, code_article, description, fabricant, groupe_article, actif').order('code_article')
      products.value = (pRes.data || []).filter(function (p) { return p.actif !== false })
      // 2. Config (la migration 034 seed la ligne id=1 → son absence = migration non exécutée)
      try {
        var cfgRes = await supabase.from('peremption_config').select('*').eq('id', 1).maybeSingle()
        if (cfgRes.data) config.value = Object.assign({}, DEFAULT_CONFIG, cfgRes.data)
        else needsMigration.value = true
      } catch (e) { needsMigration.value = true }
      // 3. Évaluations (dernière par produit) — idem
      try {
        var eRes = await supabase.from('peremption_evaluations').select('*').order('evaluated_at', { ascending: false })
        if (eRes.error) { needsMigration.value = true; evMap.value = {} }
        else {
          var m = {}
            ; (eRes.data || []).forEach(function (e) { if (!m[e.product_id]) m[e.product_id] = e })
          evMap.value = m
        }
      } catch (e) { needsMigration.value = true; evMap.value = {} }
      loading.value = false
    }

    onMounted(async function () {
      var u = await supabase.auth.getUser()
      if (u.data.user) {
        var p = await supabase.from('profiles').select('service').eq('id', u.data.user.id).single()
        if (p.data) { userService.value = p.data.service; await loadPermissions(p.data.service) }
      }
      canConfig.value = canPerform('configurer_risque_peremption')
      await load()
    })

    return {
      products, loading, needsMigration, searchQ, niveauFilter, typeFilter, canConfig,
      evaluatedCount, counts, filtered, fmtDate, valNiveau, toggleNiveau, goEval,
      NIVEAU_LABELS, NIVEAU_CLASS, MODE_APPRO_LABELS, TYPE_LABELS, TYPE_CLASS,
      showConfig, cfgForm, cfgSaving, cfgErr, poidsTotal, openConfig, saveConfig
    }
  }
}
</script>

<style scoped>
.mp { font-family: 'Inter', sans-serif; }
.fa-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; flex-wrap: wrap; margin-bottom: 14px; }
.fa-title { font-size: 18px; font-weight: 800; color: var(--th-text, #1a1a2e); }
.fa-sub { font-size: 12px; color: var(--th-text2, #6b7280); margin-top: 2px; }
.fa-actions { display: flex; gap: 8px; flex-wrap: wrap; }
.mp-btn-cfg { font-size: 12px; font-weight: 600; padding: 7px 14px; border-radius: 6px; border: 1px solid #ede9fe; background: #f5f3ff; color: #7c3aed; cursor: pointer; }
.mp-btn-cfg:hover { background: #ede9fe; }
.mp-btn-cfg:disabled { opacity: .5; cursor: not-allowed; }

.mp-warn { background: #fef3c7; color: #92400e; border: 1px solid #fde68a; border-radius: 6px; padding: 10px 14px; font-size: 12px; margin-bottom: 12px; }
.mp-warn code { font-family: 'SF Mono', monospace; background: rgba(0,0,0,.05); padding: 1px 5px; border-radius: 3px; }

.mp-kpis { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 14px; }
.mp-kpi { display: flex; flex-direction: column; align-items: center; gap: 1px; min-width: 78px; padding: 8px 12px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 8px; background: var(--th-bg2, #fff); cursor: pointer; }
.mp-kpi:hover { border-color: #c4b5fd; }
.mp-kpi.on { border-color: #7c3aed; box-shadow: 0 0 0 1px #7c3aed inset; }
.k-n { font-size: 18px; font-weight: 800; color: var(--th-text, #1a1a2e); font-family: 'SF Mono', monospace; }
.k-l { font-size: 10px; font-weight: 600; color: var(--th-text2, #6b7280); text-transform: uppercase; letter-spacing: .3px; }

.mp-toolbar { margin-bottom: 10px; display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
.mp-search-wrap { position: relative; max-width: 380px; flex: 1; min-width: 220px; }
.mp-type-filter { font-size: 12px; padding: 8px 10px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 6px; background: var(--th-input-bg, #fff); color: inherit; cursor: pointer; }
.mp-type-filter:focus { border-color: #7c3aed; outline: none; }
.ts-icon { position: absolute; left: 10px; top: 50%; transform: translateY(-50%); font-size: 13px; opacity: .6; }
.mp-search { width: 100%; box-sizing: border-box; font-size: 13px; padding: 8px 10px 8px 30px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 6px; outline: none; background: var(--th-input-bg, #fff); color: inherit; }
.mp-search:focus { border-color: #7c3aed; }

.em { text-align: center; padding: 40px; color: var(--th-text2, #9ca3af); font-size: 13px; }
.table-wrap { overflow: auto; max-height: calc(100vh - 320px); border: 1px solid var(--th-border, #e5e7eb); border-radius: 8px; }
.pt-table { width: 100%; border-collapse: collapse; font-size: 12px; }
.pt-table th { text-align: left; font-size: 11px; font-weight: 700; letter-spacing: .3px; text-transform: uppercase; color: #7c3aed; padding: 10px 12px; border-bottom: 1px solid #ede9fe; white-space: nowrap; background: #f5f3ff; position: sticky; top: 0; z-index: 2; }
.pt-table th.tc { text-align: center; }
.pt-table td { padding: 9px 12px; border-bottom: 1px solid var(--th-border, #f5f5f5); vertical-align: middle; color: var(--th-text, #222); }
.pt-table tr:last-child td { border-bottom: none; }
.clk { cursor: pointer; }
.pt-table tbody tr:hover td { background: #f5f3ff; }
.mono { font-family: 'SF Mono', monospace; font-size: 11px; }
.strong { font-weight: 800; }
.tc { text-align: center; }
.tar { text-align: right; }
.td-desc { max-width: 230px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mode { font-size: 11px; color: var(--th-text2, #6b7280); }
.dt { font-family: 'SF Mono', monospace; font-size: 11px; color: var(--th-text2, #9ca3af); white-space: nowrap; }
.btn-eval { font-size: 11px; font-weight: 600; padding: 4px 12px; border-radius: 5px; border: 1px solid #7c3aed; background: transparent; color: #7c3aed; cursor: pointer; white-space: nowrap; }
.btn-eval:hover { background: #7c3aed; color: #fff; }

/* Badges niveau — jour */
.niv { display: inline-block; font-size: 11px; font-weight: 700; padding: 2px 10px; border-radius: 10px; white-space: nowrap; }
.niv-faible { background: #d1fae5; color: #065f46; }
.niv-moyen { background: #fef3c7; color: #92400e; }
.niv-eleve { background: #FCEBEB; color: #b91c1c; }
.niv-na { background: #f3f4f6; color: #9ca3af; }
.valid-tag { display: inline-block; font-size: 11px; font-weight: 700; padding: 2px 9px; border-radius: 10px; background: #f5f3ff; color: #7c3aed; border: 1px solid #ede9fe; white-space: nowrap; }
.val-none { color: var(--th-text3, #bbb); }
.ty { display: inline-block; font-size: 10px; font-weight: 700; padding: 2px 8px; border-radius: 9px; white-space: nowrap; }
.ty-gen { background: #ede9fe; color: #6d28d9; }
.ty-otc { background: #e0f2fe; color: #0369a1; }
.ty-sl  { background: #fef3c7; color: #92400e; }
.ty-imp { background: #f3f4f6; color: #6b7280; }

/* KPI cartes — teinte de fond légère */
.kpi-faible.on { background: #ecfdf5; } .kpi-moyen.on { background: #fffbeb; } .kpi-eleve.on { background: #fef2f2; }

/* Overrides sombre (RÈGLE N°15c) */
html[data-theme="night"] .pt-table th,
html[data-theme="workshop"] .pt-table th { background: var(--th-bg3); color: var(--th-accent); border-bottom-color: var(--th-border); }
html[data-theme="night"] .pt-table tbody tr:hover td,
html[data-theme="workshop"] .pt-table tbody tr:hover td { background: var(--th-bg3); }
html[data-theme="night"] .mp-btn-cfg,
html[data-theme="workshop"] .mp-btn-cfg { background: var(--th-bg3); color: var(--th-accent); border-color: var(--th-border); }
html[data-theme="night"] .niv-faible,
html[data-theme="workshop"] .niv-faible { background: rgba(52,211,153,.12); color: #6ee7b7; }
html[data-theme="night"] .niv-moyen,
html[data-theme="workshop"] .niv-moyen { background: rgba(251,191,36,.12); color: #fbbf24; }
html[data-theme="night"] .niv-eleve,
html[data-theme="workshop"] .niv-eleve { background: rgba(239,68,68,.12); color: #fca5a5; }
html[data-theme="night"] .niv-na,
html[data-theme="workshop"] .niv-na { background: var(--th-bg3); color: var(--th-text3, #9ca3af); }
html[data-theme="night"] .valid-tag,
html[data-theme="workshop"] .valid-tag { background: var(--th-bg3); color: var(--th-accent); border-color: var(--th-border); }
html[data-theme="night"] .ty-gen, html[data-theme="workshop"] .ty-gen { background: var(--th-bg3); color: var(--th-accent); }
html[data-theme="night"] .ty-otc, html[data-theme="workshop"] .ty-otc { background: rgba(56,189,248,.14); color: #7dd3fc; }
html[data-theme="night"] .ty-sl,  html[data-theme="workshop"] .ty-sl  { background: rgba(251,191,36,.12); color: #fbbf24; }
html[data-theme="night"] .ty-imp, html[data-theme="workshop"] .ty-imp { background: var(--th-bg3); color: var(--th-text3, #9ca3af); }
html[data-theme="night"] .mp-warn,
html[data-theme="workshop"] .mp-warn { background: rgba(251,191,36,.12); color: #fbbf24; border-color: rgba(251,191,36,.3); }

/* Modal */
.overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 100; padding: 16px; }
.modal { background: var(--th-bg2, #fff); color: var(--th-text, #222); border-radius: 10px; box-shadow: 0 20px 50px rgba(0,0,0,.2); width: 100%; max-width: 460px; max-height: 90vh; overflow-y: auto; }
.mt { font-size: 14px; font-weight: 800; padding: 16px 20px 12px; border-bottom: 1px solid var(--th-border, #f3f4f6); }
.modal-body-inner { padding: 16px 20px; }
.cfg-sec { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .5px; color: #7c3aed; margin: 6px 0 8px; }
.fg3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; }
.fg2 { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.fi { display: flex; flex-direction: column; gap: 4px; }
.fi label { font-size: 10px; font-weight: 700; color: var(--th-text2, #6b7280); }
.inp { font-size: 13px; padding: 8px 10px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 5px; outline: none; width: 100%; box-sizing: border-box; background: var(--th-input-bg, #fff); color: inherit; }
.inp:focus { border-color: #7c3aed; }
.cfg-tot { font-size: 12px; font-weight: 600; margin: 8px 0; color: #1D9E75; }
.cfg-tot.bad { color: #E24B4A; }
.cfg-hint { font-size: 11px; color: var(--th-text2, #6b7280); margin-top: 8px; }
.merr { font-size: 11px; color: #ef4444; background: rgba(239,68,68,.08); padding: 6px 10px; border-radius: 4px; margin-top: 8px; }
.ma { display: flex; gap: 8px; padding: 12px 20px; border-top: 1px solid var(--th-border, #f3f4f6); }
.bc2 { padding: 7px 16px; background: var(--th-bg3, #f5f5f5); color: var(--th-text2, #666); border: 1px solid var(--th-border, #e5e7eb); border-radius: 5px; font-size: 12px; cursor: pointer; }

@media (max-width: 768px) {
  .pt-table th:nth-child(3), .pt-table td:nth-child(3),
  .pt-table th:nth-child(5), .pt-table td:nth-child(5),
  .pt-table th:nth-child(6), .pt-table td:nth-child(6),
  .pt-table th:nth-child(7), .pt-table td:nth-child(7),
  .pt-table th:nth-child(8), .pt-table td:nth-child(8),
  .pt-table th:nth-child(11), .pt-table td:nth-child(11),
  .pt-table th:nth-child(12), .pt-table td:nth-child(12) { display: none; }
  .fg3 { grid-template-columns: 1fr; }
}
</style>
