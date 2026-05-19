<template>
  <div>
    <div class="ph"><span class="pt">PRODUITS</span><span class="pc" v-if="products.length">{{ products.length }} produits</span></div>
    <div v-if="loading" class="empty">Chargement...</div>
    <div v-else-if="!products.length" class="empty">Aucun produit</div>
    <div v-else class="table-wrap">
      <table class="tb">
        <thead><tr><th>Code</th><th>Désignation</th><th>Quarant.</th><th>Investig.</th><th>Acceptés</th><th>Total</th></tr></thead>
        <tbody><tr v-for="p in products" :key="p.id" @click="$router.push('/products/'+p.id)">
          <td class="mono">{{p.code_article}}</td><td class="bold">{{p.description}}</td>
          <td class="mono" :class="{'cw':p.quarantaine>0}">{{p.quarantaine}}</td>
          <td class="mono" :class="{'cd':p.investigation>0}">{{p.investigation}}</td>
          <td class="mono cg">{{p.accepte}}</td>
          <td class="mono">{{p.total}}</td>
        </tr></tbody>
      </table>
    </div>
  </div>
</template>
<script>
import { ref, onMounted } from 'vue'
import { supabase } from '../supabase'
export default {
  setup() {
    const products = ref([]), loading = ref(true)
    onMounted(async () => {
      const { data: lots } = await supabase.from('lots').select('product_id, statut_sap, products(id, code_article, description)')
      const map = {}
      for (const l of (lots || [])) {
        const p = l.products
        if (!p) continue
        if (!map[p.id]) {
          map[p.id] = { id: p.id, code_article: p.code_article, description: p.description, quarantaine: 0, investigation: 0, accepte: 0, total: 0 }
        }
        map[p.id].total++
        if (l.statut_sap === 'quarantaine') map[p.id].quarantaine++
        else if (l.statut_sap === 'sous_investigation') map[p.id].investigation++
        else if (l.statut_sap === 'accepte') map[p.id].accepte++
      }
      products.value = Object.values(map).sort((a, b) => b.quarantaine - a.quarantaine)
      loading.value = false
    })
    return { products, loading }
  }
}
</script>
<style scoped>
.ph{display:flex;align-items:baseline;justify-content:space-between;padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:2px}
.pt{font-size:11px;font-weight:500;letter-spacing:1.5px}.pc{font-size:11px;color:#999;font-family:'SF Mono',monospace}
.table-wrap{overflow-x:auto;overflow-y:auto;-webkit-overflow-scrolling:touch;max-height:calc(100vh - 150px)}
.tb{width:100%;border-collapse:collapse;font-size:13px}.tb th{font-size:10px;text-transform:uppercase;color:#999;font-weight:500;padding:6px 8px;text-align:left;border-bottom:1px solid #e8e8e8;position:sticky;top:0;background:#fff;z-index:1}
.tb td{padding:8px;border-bottom:1px solid #f5f5f5}.tb tr{cursor:pointer}.tb tr:hover td{background:#fafafa}
.bold{font-weight:500}.mono{font-family:'SF Mono',monospace;font-size:12px}
.cw{color:#BA7517}.cd{color:#E24B4A}.cg{color:#1D9E75}
.empty{text-align:center;padding:40px;color:#999}
@media(max-width:768px){
  .tb{font-size:12px}
  .tb td{padding:9px 8px}
  .table-wrap{max-height:calc(100vh - 180px)}
}
</style>
