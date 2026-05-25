<template>
  <div class="import-wrap">

    <!-- ══ GOOGLE SHEETS (priorité mobile) ══ -->
    <div class="gs-section">
      <div class="gs-title">
        <span class="gs-icon">🔗</span>
        Synchroniser depuis Google Sheets
      </div>

      <!-- URL configurée → hero button + config repliée -->
      <template v-if="gsUrl">
        <button
          class="gs-sync-hero"
          :class="{'gs-syncing': gsSyncing}"
          :disabled="gsSyncing"
          @click="syncGoogleSheets"
        >
          <span class="gs-sync-icon">{{ gsSyncing ? '⟳' : '🔄' }}</span>
          <span v-if="gsSyncing">Synchronisation… {{ gsProgress }}%</span>
          <span v-else>Actualiser depuis Google Sheets</span>
        </button>

        <div v-if="gsSyncing" class="gs-prog-bar">
          <div class="gs-prog-fill" :style="{width: gsProgress + '%'}"></div>
        </div>

        <div class="gs-meta">
          <span v-if="gsLastSync" class="gs-last">✓ Dernière sync : {{ gsLastSync }}</span>
          <button class="gs-url-toggle" @click="showUrlEdit = !showUrlEdit">
            {{ showUrlEdit ? '▲ Masquer' : '⚙ Modifier l\'URL' }}
          </button>
        </div>

        <div v-if="showUrlEdit" class="gs-url-config">
          <div class="gs-url-row">
            <input
              v-model="gsUrl"
              class="gs-url-inp"
              type="url"
              inputmode="url"
              autocomplete="url"
              placeholder="https://docs.google.com/spreadsheets/d/e/…/pub?…&output=csv"
              @change="saveGsUrl"
            />
            <button v-if="gsUrl" class="gs-clear-btn" @click="gsUrl=''; saveGsUrl()" title="Effacer l'URL">✕</button>
          </div>
        </div>
      </template>

      <!-- URL non configurée → setup -->
      <template v-else>
        <p class="gs-desc">Colle l'URL CSV de ta feuille Google Sheets "Réception SAP". Elle sera sauvegardée automatiquement.</p>
        <div class="gs-url-row">
          <input
            v-model="gsUrl"
            class="gs-url-inp"
            type="url"
            inputmode="url"
            autocomplete="url"
            placeholder="https://docs.google.com/spreadsheets/d/e/…/pub?…&output=csv"
            @change="saveGsUrl"
          />
        </div>
        <button
          class="gs-sync-hero gs-sync-disabled"
          disabled
        >
          <span class="gs-sync-icon">🔄</span>
          Actualiser depuis Google Sheets
        </button>
      </template>
    </div>

    <!-- Résultat Google Sheets -->
    <div class="result" v-if="gsStats">
      <div class="rh">Synchronisation terminée <span class="rt">{{ gsStats.type }}</span></div>
      <div class="rg">
        <div class="rc"><div class="rv" style="color:#1D9E75">{{ gsStats.created }}</div><div class="rl">Créés</div></div>
        <div class="rc"><div class="rv" style="color:#185FA5">{{ gsStats.updated }}</div><div class="rl">Mis à jour</div></div>
        <div class="rc"><div class="rv" style="color:#999">{{ gsStats.skipped }}</div><div class="rl">Ignorés</div></div>
        <div class="rc"><div class="rv" style="color:#E24B4A">{{ gsStats.errors.length }}</div><div class="rl">Erreurs</div></div>
      </div>
      <div class="errors" v-if="gsStats.errors.length">
        <div v-for="(e, i) in gsStats.errors" :key="i" class="err">{{ e }}</div>
      </div>
      <button class="btn" @click="$router.push('/lots')" style="margin-top:16px">Voir les lots →</button>
    </div>

    <!-- ══ SÉPARATEUR ══ -->
    <div class="sep">
      <span class="sep-line"></span>
      <span class="sep-txt">OU</span>
      <span class="sep-line"></span>
    </div>

    <!-- ══ IMPORT EXCEL (secondaire sur mobile) ══ -->
    <div class="excel-section">
      <div class="ph"><span class="pt">IMPORT EXCEL</span></div>
      <p class="desc">Importe directement ton fichier Excel (.xlsx) connecté à SAP. Les lots existants seront mis à jour, les nouveaux seront créés.</p>

      <div class="upload" @dragover.prevent @drop.prevent="onDrop" @click="$refs.fileInput.click()">
        <input ref="fileInput" type="file" accept=".xlsx,.xls" @change="onFile" hidden />
        <div v-if="!importing">
          <div class="ui">↑</div>
          <div>Glisse ton fichier ou clique pour sélectionner</div>
          <div class="uf">Format attendu : .xlsx avec colonnes SAP</div>
        </div>
        <div v-else>
          <div class="prog">{{ progress }}%</div>
          <div class="pb"><div class="pf" :style="{width: progress + '%'}"></div></div>
          <div class="ps">Import en cours...</div>
        </div>
      </div>

      <div class="result" v-if="stats">
        <div class="rh">Import terminé <span class="rt">{{ stats.type }}</span></div>
        <div class="rg">
          <div class="rc"><div class="rv" style="color:#1D9E75">{{ stats.created }}</div><div class="rl">Créés</div></div>
          <div class="rc"><div class="rv" style="color:#185FA5">{{ stats.updated }}</div><div class="rl">Mis à jour</div></div>
          <div class="rc"><div class="rv" style="color:#999">{{ stats.skipped }}</div><div class="rl">Ignorés</div></div>
          <div class="rc"><div class="rv" style="color:#E24B4A">{{ stats.errors.length }}</div><div class="rl">Erreurs</div></div>
        </div>
        <div class="errors" v-if="stats.errors.length">
          <div v-for="(e, i) in stats.errors" :key="i" class="err">{{ e }}</div>
        </div>
        <button class="btn" @click="$router.push('/lots')" style="margin-top:16px">Voir les lots →</button>
      </div>
    </div>

    <!-- ══ AIDE ══ -->
    <div class="help">
      <div class="sh"><span>Deux formats acceptés (détection automatique)</span></div>
      <div class="fmt"><span class="fl sap">SAP</span> Colonnes : N_lot, code_article, description, Statut_Lot, date_enregistrement, quantite...</div>
      <div class="fmt"><span class="fl hist">Historique</span> Colonnes : N°LOT, Date transfert DDL Fab, Date transfert DDL condt, Date de transfert D.A Physico...</div>
    </div>

  </div>
</template>

<script>
import { ref, onMounted } from 'vue'
import { importExcel, importFromGoogleSheets } from '../services/import'
import { supabase } from '../supabase'

var GS_URL_KEY = 'liberation_gs_url'
var GS_LAST_KEY = 'liberation_gs_last'

export default {
  setup() {
    var importing = ref(false)
    var progress = ref(0)
    var stats = ref(null)

    var gsUrl = ref('')
    var gsSyncing = ref(false)
    var gsProgress = ref(0)
    var gsStats = ref(null)
    var gsLastSync = ref('')
    var showUrlEdit = ref(false)

    onMounted(async function() {
      // 1. Charger depuis localStorage (rapide, même appareil)
      var cached = localStorage.getItem(GS_URL_KEY) || ''
      gsUrl.value = cached
      gsLastSync.value = localStorage.getItem(GS_LAST_KEY) || ''
      // 2. Charger depuis Supabase (synchronisé entre appareils)
      var res = await supabase.from('app_settings').select('value').eq('key', 'gs_url').maybeSingle()
      if (res.data && res.data.value) {
        gsUrl.value = res.data.value
        localStorage.setItem(GS_URL_KEY, res.data.value)
      }
    })

    var saveGsUrl = async function() {
      var val = gsUrl.value || ''
      localStorage.setItem(GS_URL_KEY, val)
      // Sauvegarder en DB pour synchronisation multi-appareils
      await supabase.from('app_settings').upsert({ key: 'gs_url', value: val }, { onConflict: 'key' })
    }

    var syncGoogleSheets = async function() {
      if (!gsUrl.value) return
      gsSyncing.value = true
      gsProgress.value = 0
      gsStats.value = null
      try {
        gsStats.value = await importFromGoogleSheets(gsUrl.value, function(p) { gsProgress.value = p })
        var now = new Date().toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })
        gsLastSync.value = now
        localStorage.setItem(GS_LAST_KEY, now)
      } catch(e) {
        gsStats.value = { created: 0, updated: 0, skipped: 0, errors: ['Erreur : ' + e.message], type: 'Google Sheets' }
      }
      gsSyncing.value = false
    }

    var processFile = async function(file) {
      if (!file || (!file.name.endsWith('.xlsx') && !file.name.endsWith('.xls'))) { alert('Fichier Excel (.xlsx) requis'); return }
      importing.value = true; progress.value = 0; stats.value = null
      try {
        stats.value = await importExcel(file, function(p) { progress.value = p })
      } catch(e) { alert('Erreur: ' + e.message) }
      importing.value = false
    }

    var onFile = function(e) { processFile(e.target.files[0]) }
    var onDrop = function(e) { processFile(e.dataTransfer.files[0]) }

    return { importing, progress, stats, onFile, onDrop, gsUrl, gsSyncing, gsProgress, gsStats, gsLastSync, showUrlEdit, saveGsUrl, syncGoogleSheets }
  }
}
</script>

<style scoped>
.import-wrap { max-width:600px }

/* ── Google Sheets section ── */
.gs-section { border:1px solid #d0e4f8; border-radius:8px; padding:20px; background:#f7fbff; margin-bottom:16px }
.gs-title { font-size:13px; font-weight:600; color:#0C447C; margin-bottom:14px; display:flex; align-items:center; gap:8px }
.gs-icon { font-size:16px }
.gs-desc { font-size:12px; color:#666; margin-bottom:14px; line-height:1.5 }

/* Hero sync button */
.gs-sync-hero {
  display:flex; align-items:center; justify-content:center; gap:10px;
  width:100%; padding:14px 20px;
  font-size:15px; font-weight:600; font-family:inherit;
  background:#185FA5; color:#fff;
  border:none; border-radius:6px; cursor:pointer;
  transition:.15s; min-height:52px;
  -webkit-tap-highlight-color: transparent;
}
.gs-sync-hero:hover:not(:disabled) { background:#0C447C }
.gs-sync-hero:disabled, .gs-sync-disabled { opacity:0.55; cursor:default }
.gs-sync-hero.gs-syncing { background:#0C447C }
.gs-sync-icon { font-size:18px; flex-shrink:0 }

/* Progress bar */
.gs-prog-bar { margin-top:10px; height:5px; background:#ddeefa; border-radius:3px; overflow:hidden }
.gs-prog-fill { height:100%; background:#185FA5; border-radius:3px; transition:width .3s }

/* Meta row: last sync + modify URL toggle */
.gs-meta { display:flex; align-items:center; justify-content:space-between; flex-wrap:wrap; gap:8px; margin-top:10px }
.gs-last { font-size:11px; color:#1D9E75; font-weight:500 }
.gs-url-toggle { font-size:11px; padding:4px 10px; border:1px solid #c0d8f0; background:#fff; color:#185FA5; border-radius:3px; cursor:pointer; font-family:inherit }
.gs-url-toggle:hover { background:#E6F1FB }

/* URL config row */
.gs-url-config { margin-top:12px }
.gs-url-row { display:flex; align-items:center; gap:6px }
.gs-url-inp {
  flex:1; font-size:12px; font-family:'SF Mono',monospace;
  border:1px solid #c0d8f0; border-radius:4px; padding:10px;
  outline:none; color:#333; background:#fff;
  -webkit-appearance:none;
}
.gs-url-inp:focus { border-color:#185FA5 }
.gs-url-inp::placeholder { color:#bbb; font-family:inherit }
.gs-clear-btn { border:none; background:none; color:#bbb; cursor:pointer; font-size:16px; padding:6px; flex-shrink:0 }
.gs-clear-btn:hover { color:#555 }

/* ── Séparateur ── */
.sep { display:flex; align-items:center; gap:12px; margin:20px 0 }
.sep-line { flex:1; height:1px; background:#e8e8e8 }
.sep-txt { font-size:11px; font-weight:600; color:#bbb; letter-spacing:1px }

/* ── Excel section ── */
.excel-section { }
.ph { padding-bottom:10px; border-bottom:2px solid #0a0a0a; margin-bottom:16px }
.pt { font-size:11px; font-weight:500; letter-spacing:1.5px }
.desc { font-size:13px; color:#666; margin-bottom:16px; line-height:1.5 }
.upload { border:2px dashed #ddd; border-radius:4px; padding:40px; text-align:center; cursor:pointer; font-size:13px; color:#666; transition:.15s }
.upload:hover { border-color:#185FA5; background:#fafafa }
.ui { font-size:28px; margin-bottom:8px; color:#999 }
.uf { font-size:11px; color:#999; margin-top:4px }
.prog { font-size:28px; font-weight:500; font-family:'SF Mono',monospace; color:#185FA5 }
.pb { width:100%; height:6px; background:#f0f0f0; border-radius:3px; margin:12px 0 }
.pf { height:100%; background:#185FA5; border-radius:3px; transition:width .3s }
.ps { font-size:12px; color:#999 }

/* ── Résultats ── */
.result { border:1px solid #e8e8e8; padding:20px; margin-top:16px; border-radius:4px }
.rh { font-size:14px; font-weight:500; margin-bottom:12px }
.rg { display:grid; grid-template-columns:repeat(4,1fr); border:1px solid #e8e8e8 }
.rc { padding:12px; text-align:center; border-right:1px solid #e8e8e8 }
.rc:last-child { border-right:none }
.rv { font-size:20px; font-weight:500; font-family:'SF Mono',monospace }
.rl { font-size:10px; color:#999; text-transform:uppercase; margin-top:2px }
.errors { margin-top:12px; font-size:12px }
.err { padding:4px 0; color:#E24B4A; border-bottom:1px solid #f5f5f5 }
.rt { font-size:11px; padding:2px 8px; border-radius:2px; background:#E6F1FB; color:#0C447C; margin-left:8px; font-weight:500 }
.btn { font-size:13px; padding:8px 20px; background:#185FA5; color:#fff; border:none; border-radius:2px; cursor:pointer }
.btn:hover { background:#0C447C }

/* ── Aide ── */
.help { margin-top:24px }
.sh { font-size:10px; font-weight:500; text-transform:uppercase; letter-spacing:1px; color:#999; padding-bottom:6px; border-bottom:1px solid #e8e8e8 }
.fmt { font-size:12px; color:#666; padding:6px 0; border-bottom:1px solid #f5f5f5; font-family:'SF Mono',monospace; line-height:1.6 }
.fl { font-size:10px; font-weight:600; padding:2px 6px; border-radius:2px; margin-right:8px; letter-spacing:.5px }
.fl.sap { background:#E6F1FB; color:#0C447C }
.fl.hist { background:#EAF3DE; color:#3B6D11 }

/* ── Mobile ── */
@media (max-width: 640px) {
  .import-wrap { max-width:100% }

  /* GS section : plus de padding, plus aéré */
  .gs-section { padding:16px; border-radius:6px }
  .gs-title { font-size:14px; margin-bottom:12px }

  /* Bouton sync encore plus grand sur mobile */
  .gs-sync-hero { font-size:16px; padding:16px; min-height:58px; border-radius:8px }
  .gs-sync-icon { font-size:20px }

  /* URL input: taille de police normale pour éviter le zoom iOS */
  .gs-url-inp { font-size:16px; padding:12px; font-family:inherit }

  /* Excel section masquée par défaut sur mobile (secondaire) */
  .excel-section .upload { padding:24px 16px }
  .upload { font-size:13px }
  .ui { font-size:22px }

  /* Stats 2×2 sur très petit écran */
  .rg { grid-template-columns:repeat(2, 1fr) }
  .rc { border-right:1px solid #e8e8e8; border-bottom:1px solid #e8e8e8 }
  .rc:nth-child(2) { border-right:none }
  .rc:nth-child(3) { border-bottom:none }
  .rc:nth-child(4) { border-right:none; border-bottom:none }

  .btn { width:100%; padding:12px; font-size:14px; border-radius:4px }

  /* Aide moins visible */
  .fmt { font-size:11px }
}
</style>
