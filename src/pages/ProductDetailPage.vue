<template>
  <div v-if="product">
    <div class="bc"><span @click="$router.push('/products')">Produits</span> › {{ product.code_article }}</div>
    <div class="ph"><span class="pt">{{ product.description }}</span></div>
    <table class="tb">
      <thead><tr><th>N° Lot</th><th>Statut</th><th>Quantité</th><th>Entrée</th><th>Libération</th></tr></thead>
      <tbody><tr v-for="l in lots" :key="l.id" @click="$router.push('/lots/'+l.id)">
        <td class="mono bold">{{l.numero_lot}}</td>
        <td><span class="sp" :class="'s-'+l.statut_sap">{{statusLabels[l.statut_sap]}}</span></td>
        <td class="mono">{{l.quantite}}</td>
        <td class="mono dim">{{fmt(l.date_enregistrement)}}</td>
        <td class="mono dim">{{fmt(l.date_liberation)}}</td>
      </tr></tbody>
    </table>
  </div>
</template>
<script>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../supabase'
export default {
  setup() {
    const route = useRoute(), product = ref(null), lots = ref([])
    const statusLabels = { vide:'En prod.', quarantaine:'Quarantaine', sous_investigation:'Investigation', accepte:'Accepté' }
    const fmt = (d) => d ? new Date(d).toLocaleDateString('fr-FR') : '—'
    onMounted(async () => {
      const { data: p } = await supabase.from('products').select('*').eq('id', route.params.id).single()
      product.value = p
      const { data: l } = await supabase.from('lots').select('*').eq('product_id', route.params.id).order('date_enregistrement', { ascending: false })
      lots.value = l || []
    })
    return { product, lots, statusLabels, fmt }
  }
}
</script>
<style scoped>
.bc{font-size:12px;color:#999;margin-bottom:8px}.bc span{cursor:pointer;color:#185FA5}
.ph{padding-bottom:10px;border-bottom:2px solid #0a0a0a;margin-bottom:2px}.pt{font-size:16px;font-weight:500}
.tb{width:100%;border-collapse:collapse;font-size:13px}.tb th{font-size:10px;text-transform:uppercase;color:#999;font-weight:500;padding:6px 8px;text-align:left;border-bottom:1px solid #e8e8e8}
.tb td{padding:7px 8px;border-bottom:1px solid #f5f5f5}.tb tr{cursor:pointer}.tb tr:hover td{background:#fafafa}
.bold{font-weight:500}.mono{font-family:'SF Mono',monospace;font-size:12px}.dim{color:#999}
.sp{font-size:11px;padding:2px 8px;border-radius:2px;font-weight:500}
.s-quarantaine{background:#FAEEDA;color:#854F0B}.s-accepte{background:#EAF3DE;color:#3B6D11}.s-sous_investigation{background:#FCEBEB;color:#A32D2D}.s-vide{background:#f5f5f5;color:#999}
</style>
