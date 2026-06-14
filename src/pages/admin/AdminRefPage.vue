<template>
  <div class="admin-ref">

    <!-- ══ BARRE D'ONGLETS ══ -->
    <div class="ar-tabs">
      <button
        v-for="t in tabs" :key="t.key"
        class="ar-tab" :class="{active: activeTab === t.key}"
        @click="switchTab(t.key)">
        <span class="ar-ico"><NavIcon :name="t.icon" :size="15" /></span>
        {{t.label}}
      </button>
    </div>

    <!-- ══ CONTENU — lazy-mount + état préservé (v-show) ══ -->
    <div class="ar-body">
      <template v-for="p in mountedPanels" :key="p.key">
        <div class="ar-panel" v-show="activeTab === p.key">
          <component :is="p.comp" />
        </div>
      </template>
    </div>

  </div>
</template>

<script>
import { ref, computed, defineAsyncComponent } from 'vue'
import NavIcon from '../../components/NavIcon.vue'

// Composants chargés en async — module téléchargé une seule fois, instance montée
// à la première activation de l'onglet, puis maintenue en mémoire (v-show).
var COMPS = {
  produits: defineAsyncComponent(function() { return import('../ProductsCatalogPage.vue') }),
  ateliers: defineAsyncComponent(function() { return import('./AdminAteliersPage.vue')   }),
  flux:     defineAsyncComponent(function() { return import('./AdminFluxPage.vue')       }),
  shifts:   defineAsyncComponent(function() { return import('./AdminShiftsPage.vue')     }),
  arrets:   defineAsyncComponent(function() { return import('./AdminArretTypesPage.vue') }),
}

export default {
  components: { NavIcon },
  setup() {
    var activeTab   = ref('produits')
    var mountedKeys = ref(['produits'])   // onglets déjà montés (lazy)

    var tabs = [
      { key: 'produits', icon: 'package', label: 'Catalogue produits'   },
      { key: 'ateliers', icon: 'factory', label: 'Processus & Ateliers' },
      { key: 'flux',     icon: 'workflow', label: 'Flux produits'        },
      { key: 'shifts',   icon: 'clock', label: 'Shifts & Équipes'     },
      { key: 'arrets',   icon: 'ban', label: "Types d'arrêts"       },
    ]

    // Panels effectivement montés (data chargée uniquement à la 1ère activation)
    var mountedPanels = computed(function() {
      return mountedKeys.value.map(function(k) {
        return { key: k, comp: COMPS[k] }
      })
    })

    var switchTab = function(key) {
      activeTab.value = key
      if (mountedKeys.value.indexOf(key) === -1) {
        mountedKeys.value = mountedKeys.value.concat([key])
      }
    }

    return { activeTab, tabs, mountedPanels, switchTab }
  }
}
</script>

<style scoped>
.admin-ref {
  /* Annule le padding de page-content pour coller le tab bar aux bords */
  margin: -16px -20px;
  min-height: calc(100vh - 57px);
  display: flex;
  flex-direction: column;
}

/* ── Barre d'onglets ── */
.ar-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 0;
  background: #fff;
  border-bottom: 1px solid #e8e8e8;
  padding: 0 16px;
  flex-shrink: 0;
  position: sticky;
  top: 0;
  z-index: 10;
}

.ar-tab {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 11px 14px;
  font-size: 12px;
  font-weight: 500;
  color: #888;
  border: none;
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
  background: transparent;
  cursor: pointer;
  font-family: inherit;
  transition: color .12s;
  white-space: nowrap;
  text-decoration: none;
}
.ar-tab:hover { color: #333; background: #fafafa; }
.ar-tab.active {
  color: #185FA5;
  border-bottom-color: #185FA5;
  background: transparent;
}
.ar-ico { font-size: 13px; }

/* ── Zone de contenu ── */
.ar-body {
  flex: 1;
  overflow-y: auto;
}

/* Chaque panel réinjecte son propre padding */
.ar-panel {
  padding: 16px 20px;
}
</style>
