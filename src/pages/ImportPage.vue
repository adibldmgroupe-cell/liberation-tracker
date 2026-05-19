<template>
  <div style="max-width:600px">
    <div class="ph"><span class="pt">IMPORT EXCEL</span></div>
    <p class="desc">Importe directement ton fichier Excel (.xlsx) connecté à SAP. Les lots existants seront mis à jour, les nouveaux seront créés. Le fichier original n'est pas modifié.</p>

    <div class="upload" @dragover.prevent @drop.prevent="onDrop" @click="$refs.fileInput.click()">
      <input ref="fileInput" type="file" accept=".xlsx,.xls" @change="onFile" hidden />
      <div v-if="!importing">
        <div class="ui">↑</div>
        <div>Glisse ton fichier Excel ici ou clique pour sélectionner</div>
        <div class="uf">Format attendu : .xlsx avec colonnes SAP</div>
      </div>
      <div v-else>
        <div class="prog">{{progress}}%</div>
        <div class="pb"><div class="pf" :style="{width:progress+'%'}"></div></div>
        <div class="ps">Import en cours...</div>
      </div>
    </div>

    <div class="result" v-if="stats">
      <div class="rh">Import terminé <span class="rt">{{ stats.type }}</span></div>
      <div class="rg">
        <div class="rc"><div class="rv" style="color:#1D9E75">{{stats.created}}</div><div class="rl">Créés</div></div>
        <div class="rc"><div class="rv" style="color:#185FA5">{{stats.updated}}</div><div class="rl">Mis à jour</div></div>
        <div class="rc"><div class="rv" style="color:#999">{{stats.skipped}}</div><div class="rl">Ignorés</div></div>
        <div class="rc"><div class="rv" style="color:#E24B4A">{{stats.errors.length}}</div><div class="rl">Erreurs</div></div>
      </div>
      <div class="errors" v-if="stats.errors.length">
        <div v-for="(e,i) in stats.errors" :key="i" class="err">{{e}}</div>
      </div>
      <button class="btn" @click="$router.push('/lots')" style="margin-top:16px">Voir les lots →</button>
    </div>

    <div class="help">
      <div class="sh"><span>Deux formats acceptés (détection automatique)</span></div>
      <div class="fmt"><span class="fl">SAP</span> Colonnes : N_lot, code_article, description, Statut_Lot, date_enregistrement, quantite...</div>
      <div class="fmt"><span class="fl">Historique</span> Colonnes : N°LOT, Date transfert DDL Fab, Date transfert DDL condt, Date de transfert D.A Physico...</div>
    </div>
  </div>
</template>
<script>
import { ref } from 'vue'
import { importExcel } from '../services/import'
export default {
  setup() {
    const importing = ref(false), progress = ref(0), stats = ref(null)
    const processFile = async (file) => {
      if (!file || (!file.name.endsWith('.xlsx') && !file.name.endsWith('.xls'))) { alert('Fichier Excel (.xlsx) requis'); return }
      importing.value = true; progress.value = 0; stats.value = null
      try {
        stats.value = await importExcel(file, (p) => { progress.value = p })
      } catch (e) { alert('Erreur: ' + e.message) }
      importing.value = false
    }
    const onFile = (e) => processFile(e.target.files[0])
    const onDrop = (e) => processFile(e.dataTransfer.files[0])
    return { importing, progress, stats, onFile, onDrop }
  }
}
</script>
<style scoped>
.ph{padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:16px}.pt{font-size:11px;font-weight:500;letter-spacing:1.5px}
.desc{font-size:13px;color:#666;margin-bottom:16px;line-height:1.5}
.upload{border:2px dashed #ddd;border-radius:4px;padding:40px;text-align:center;cursor:pointer;font-size:13px;color:#666;transition:.15s}
.upload:hover{border-color:#185FA5;background:#fafafa}
.ui{font-size:28px;margin-bottom:8px;color:#999}.uf{font-size:11px;color:#999;margin-top:4px}
.prog{font-size:28px;font-weight:500;font-family:'SF Mono',monospace;color:#185FA5}
.pb{width:100%;height:6px;background:#f0f0f0;border-radius:3px;margin:12px 0}.pf{height:100%;background:#185FA5;border-radius:3px;transition:width .3s}
.ps{font-size:12px;color:#999}
.result{border:1px solid #e8e8e8;padding:20px;margin-top:16px}
.rh{font-size:14px;font-weight:500;margin-bottom:12px}
.rg{display:grid;grid-template-columns:repeat(4,1fr);gap:0;border:1px solid #e8e8e8}
.rc{padding:12px;text-align:center;border-right:1px solid #e8e8e8}.rc:last-child{border-right:none}
.rv{font-size:20px;font-weight:500;font-family:'SF Mono',monospace}.rl{font-size:10px;color:#999;text-transform:uppercase;margin-top:2px}
.errors{margin-top:12px;font-size:12px}.err{padding:4px 0;color:#E24B4A;border-bottom:1px solid #f5f5f5}
.btn{font-size:13px;padding:8px 20px;background:#185FA5;color:#fff;border:none;border-radius:2px;cursor:pointer}.btn:hover{background:#0C447C}
.help{margin-top:24px}
.sh{font-size:10px;font-weight:500;text-transform:uppercase;letter-spacing:1px;color:#999;padding-bottom:6px;border-bottom:1px solid #e8e8e8}
.fmt{font-size:12px;color:#666;padding:6px 0;border-bottom:1px solid #f5f5f5;font-family:'SF Mono',monospace;line-height:1.6}
.fl{font-size:10px;font-weight:600;padding:2px 6px;border-radius:2px;margin-right:8px;letter-spacing:.5px}
.fmt:first-of-type .fl{background:#E6F1FB;color:#0C447C}
.fmt:last-of-type .fl{background:#EAF3DE;color:#3B6D11}
.rt{font-size:11px;padding:2px 8px;border-radius:2px;background:#E6F1FB;color:#0C447C;margin-left:8px;font-weight:500}
</style>
