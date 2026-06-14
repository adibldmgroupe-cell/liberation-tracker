<template>
  <div class="lr">
    <div class="lr-head">
      <span class="lr-kicker">Feuille de route — production &amp; documentaire</span>
      <div class="lr-legend">
        <span><i class="lr-lg lr-l-done"></i>Fait / OK</span>
        <span><i class="lr-lg lr-l-cur"></i>En cours</span>
        <span><i class="lr-lg lr-l-todo"></i>À faire</span>
        <span><i class="lr-lg lr-l-wait"></i>À venir / N/A</span>
      </div>
    </div>

    <div class="lr-scroll">
      <div class="lr-lanes">
        <!-- Circuits OF / OC (au-dessus) -->
        <div v-if="docs" class="lr-grid" :style="gridCols">
          <div v-if="docs.of" class="lr-acell" :style="{ gridColumn: 1 }">
            <span class="lr-chip" :class="'c-'+docs.of.status"><i class="lr-cd"></i>Circuit OF</span>
            <div class="lr-conn"></div>
          </div>
          <div v-if="docs.oc && condIdx>=0" class="lr-acell" :style="{ gridColumn: condIdx+1 }">
            <span class="lr-chip" :class="'c-'+docs.oc.status"><i class="lr-cd"></i>Circuit OC</span>
            <div class="lr-conn"></div>
          </div>
        </div>

        <!-- Production : statut -->
        <div class="lr-grid" :style="gridCols">
          <div class="lr-cell" v-for="s in steps" :key="s.key" :class="'is-'+s.status">
            <span class="lr-st">{{ statusLabel(s) }}</span><span class="lr-dt">{{ s.date ? fmtDate(s.date) : '—' }}</span>
          </div>
        </div>

        <!-- Production : ligne + cercles lumineux + DA sur la ligne (entre les cercles) -->
        <div class="lr-line" :style="lineStyle">
          <div class="lr-dcell" v-for="(s,i) in steps" :key="s.key" :class="'is-'+s.status" :style="{ gridColumn: i+1, gridRow: 1 }">
            <span class="lr-dot">
              <NavIcon v-if="s.status==='done'" name="check" :size="12" />
              <NavIcon v-else-if="s.status==='ko'" name="x" :size="12" />
            </span>
          </div>
          <span v-if="docs && fabEndIdx>=0 && condIdx>=0" v-for="d in docs.transFC" :key="'fc-'+d.label"
            class="lr-chip lr-online" :class="[d.da?'lr-da':'', 'c-'+d.status, d.status==='na'?'is-na':'']"
            :title="(d.full||d.label) + (d.status==='na' ? ' — non applicable' : '')"
            :style="{ gridColumn: (fabEndIdx+1)+' / '+(condIdx+2), gridRow: 1 }">
            <NavIcon v-if="d.da" name="flask" :size="10" /><i v-else class="lr-cd"></i>{{ d.label }}
          </span>
          <span v-if="docs && condIdx>=0" v-for="d in docs.transCR" :key="'cr-'+d.label"
            class="lr-chip lr-online" :class="[d.da?'lr-da':'', 'c-'+d.status, d.status==='na'?'is-na':'']"
            :title="(d.full||d.label) + (d.status==='na' ? ' — non applicable' : '')"
            :style="{ gridColumn: (condIdx+1)+' / '+(condIdx+3), gridRow: 1 }">
            <NavIcon v-if="d.da" name="flask" :size="10" /><i v-else class="lr-cd"></i>{{ d.label }}
          </span>
        </div>

        <!-- Production : noms -->
        <div class="lr-grid" :style="gridCols">
          <div class="lr-cell" v-for="s in steps" :key="s.key"><span class="lr-nm">{{ s.label }}</span></div>
        </div>

        <!-- Documents par phase (juste sous le nœud) -->
        <div v-if="docs" class="lr-grid lr-below" :style="gridCols">
          <div v-if="fabEndIdx>=0" class="lr-bcell" :style="{ gridColumn: fabEndIdx+1 }">
            <div class="lr-conn-up"></div>
            <span v-for="d in docs.fab" :key="d.label" class="lr-chip" :class="['c-'+d.status, d.status==='na'?'is-na':'']"><i class="lr-cd"></i>{{ d.label }}<template v-if="d.status==='na'"> — N/A</template></span>
          </div>
          <div v-if="condIdx>=0" class="lr-bcell" :style="{ gridColumn: condIdx+1 }">
            <div class="lr-conn-up"></div>
            <span v-for="d in docs.cond" :key="d.label" class="lr-chip" :class="['c-'+d.status, d.status==='na'?'is-na':'']"><i class="lr-cd"></i>{{ d.label }}<template v-if="d.status==='na'"> — N/A</template></span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import { computed } from 'vue'
import NavIcon from './NavIcon.vue'
export default {
  name: 'LotRoadmap',
  components: { NavIcon },
  props: {
    steps: { type: Array, default: function() { return [] } },
    docs: { type: Object, default: null }
  },
  setup(props) {
    var condIdx = computed(function() { return props.steps.findIndex(function(s) { return s.key === 'cond' }) })
    var fabEndIdx = computed(function() { return condIdx.value > 0 ? condIdx.value - 1 : -1 })
    var n = computed(function() { return props.steps.length || 1 })
    var gridCols = computed(function() { return { gridTemplateColumns: 'repeat(' + n.value + ', minmax(54px, 1fr))' } })
    var lineStyle = computed(function() { return { gridTemplateColumns: 'repeat(' + n.value + ', minmax(54px, 1fr))', '--inset': (50 / n.value) + '%' } })
    var statusLabel = function(s) {
      if (s.status === 'done') return 'Terminé'
      if (s.status === 'current') return 'En cours'
      if (s.status === 'ko') return 'Refusé'
      return 'À venir'
    }
    var fmtDate = function(d) {
      if (!d) return '—'
      var p = ('' + d).split('T')[0].split('-')
      return p.length === 3 ? p[2] + '/' + p[1] : ('' + d)
    }
    return { condIdx, fabEndIdx, gridCols, lineStyle, statusLabel, fmtDate }
  }
}
</script>
<style scoped>
.lr { background: var(--th-bg2, #f9fafb); border: 1px solid var(--th-border, #e5e7eb); border-radius: 10px; padding: 16px 18px; margin-bottom: 16px; }
.lr-head { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; margin-bottom: 14px; }
.lr-kicker { font-size: 11px; text-transform: uppercase; letter-spacing: .5px; color: var(--th-accent, #2563eb); font-weight: 600; }
.lr-legend { display: flex; gap: 11px; font-size: 11px; color: var(--th-text2, #6b7280); flex-wrap: wrap; }
.lr-legend span { display: flex; align-items: center; gap: 5px; }
.lr-lg { width: 9px; height: 9px; border-radius: 50%; }
.lr-l-done { background: #1D9E75; }
.lr-l-cur { background: var(--th-accent, #2563eb); }
.lr-l-todo { background: #E89C3A; }
.lr-l-wait { width: 7px; height: 7px; border: 2px solid var(--th-border, #d1d5db); }
.lr-scroll { overflow-x: auto; }
.lr-lanes { min-width: 560px; }
.lr-grid { display: grid; align-items: start; }
.lr-acell { display: flex; flex-direction: column; align-items: center; justify-content: flex-end; }
.lr-conn { width: 2px; height: 9px; background: var(--th-border, #d1d5db); }
.lr-conn-up { width: 2px; height: 8px; background: var(--th-border, #d1d5db); margin-bottom: 2px; }
.lr-cell { text-align: center; padding: 0 3px; min-width: 0; }
.lr-st { display: block; font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: .3px; color: var(--th-text3, #9ca3af); }
.lr-dt { font-size: 11px; color: var(--th-text2, #6b7280); }
.lr-nm { font-size: 11px; font-weight: 500; color: var(--th-text, #111827); line-height: 1.2; }
/* Ligne + cercles */
.lr-line { display: grid; align-items: center; position: relative; min-height: 30px; margin: 4px 0 5px; }
.lr-line::before { content: ''; position: absolute; top: 50%; left: var(--inset, 7%); right: var(--inset, 7%); height: 2px; background: var(--th-border, #e5e7eb); z-index: 0; }
.lr-dcell { display: flex; justify-content: center; z-index: 1; }
.lr-dot { width: 22px; height: 22px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #fff; background: var(--th-border, #d1d5db); }
.is-done .lr-st { color: #1D9E75; }
.is-done .lr-dot { background: #1D9E75; box-shadow: 0 0 0 4px rgba(29,158,117,.15), 0 0 11px 1px rgba(29,158,117,.55); }
.is-current .lr-st { color: var(--th-accent, #2563eb); }
.is-current .lr-dot { background: var(--th-accent, #2563eb); box-shadow: 0 0 0 4px rgba(37,99,235,.14), 0 0 11px 1px var(--th-accent, #2563eb); }
.is-ko .lr-st { color: #E24B4A; }
.is-ko .lr-dot { background: #E24B4A; box-shadow: 0 0 9px 1px rgba(226,75,74,.5); }
.is-wait .lr-dot { background: transparent; border: 2px solid var(--th-border, #d1d5db); }
/* Chips */
.lr-bcell { display: flex; flex-direction: column; align-items: center; padding-top: 2px; }
.lr-chip { display: inline-flex; align-items: center; gap: 5px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 6px; padding: 2px 7px; font-size: 10.5px; font-weight: 500; color: var(--th-text, #111827); background: var(--th-bg, #fff); margin: 1px; line-height: 1.5; white-space: nowrap; }
.lr-cd { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; background: var(--th-text3, #9ca3af); }
.c-done .lr-cd { background: #1D9E75; }
.c-cur .lr-cd { background: var(--th-accent, #2563eb); }
.c-todo .lr-cd { background: #E89C3A; }
.c-ko .lr-cd { background: #E24B4A; }
.c-wait .lr-cd { background: var(--th-text3, #9ca3af); }
.is-na { opacity: .42; font-weight: 400; }
/* DA : marqueur sur la ligne (fond masque la ligne), couleur selon l'état */
.lr-online { z-index: 2; justify-self: center; align-self: center; background: var(--th-bg2, #f9fafb); font-size: 9.5px; padding: 1px 6px; gap: 4px; margin: 0; }
.lr-da { border-style: dashed; }
.lr-da.c-wait { color: var(--th-text3, #9ca3af); border-color: var(--th-text3, #9ca3af); }
.lr-da.c-wait :deep(svg) { color: var(--th-text3, #9ca3af); }
.lr-da.c-todo { color: #B26B07; border-color: #E89C3A; background: rgba(232,156,58,.12); }
.lr-da.c-todo :deep(svg) { color: #B26B07; }
.lr-da.c-done { color: #1D9E75; border-color: #1D9E75; background: rgba(29,158,117,.12); }
.lr-da.c-done :deep(svg) { color: #1D9E75; }
.lr-da.c-na { color: var(--th-text3, #9ca3af); border-color: var(--th-border, #d1d5db); }
.lr-da.c-na :deep(svg) { color: var(--th-text3, #9ca3af); }
</style>
