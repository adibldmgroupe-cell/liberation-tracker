<template>
  <div class="lr">
    <div class="lr-head">
      <span class="lr-kicker">Feuille de route — production &amp; documentaire</span>
      <div class="lr-legend">
        <span><i class="lr-lg lr-l-done"></i>OK / terminé</span>
        <span><i class="lr-lg lr-l-cur"></i>En cours</span>
        <span><i class="lr-lg lr-l-wait"></i>À venir / N/A</span>
      </div>
    </div>

    <div class="lr-scroll">
      <div class="lr-lanes">
        <!-- Circuits (au-dessus : OF sur le départ fab, OC sur le conditionnement) -->
        <div v-if="docs" class="lr-grid lr-above" :style="gridCols">
          <div v-if="docs.of" class="lr-acell" :style="{ gridColumn: 1 }">
            <span class="lr-chip" :class="'c-'+docs.of.status"><i class="lr-cd"></i>Circuit OF</span>
            <div class="lr-conn"></div>
          </div>
          <div v-if="docs.oc && condIdx>=0" class="lr-acell" :style="{ gridColumn: condIdx+1 }">
            <span class="lr-chip" :class="'c-'+docs.oc.status"><i class="lr-cd"></i>Circuit OC</span>
            <div class="lr-conn"></div>
          </div>
        </div>

        <!-- Production (frise centrale) -->
        <div class="lr-grid lr-prod" :style="gridCols">
          <div class="lr-step" v-for="s in steps" :key="s.key" :class="'is-'+s.status">
            <div class="lr-top"><span class="lr-st">{{ statusLabel(s) }}</span><span class="lr-dt">{{ s.date ? fmtDate(s.date) : '—' }}</span></div>
            <div class="lr-dr">
              <span class="lr-dot">
                <NavIcon v-if="s.status==='done'" name="check" :size="12" />
                <NavIcon v-else-if="s.status==='ko'" name="x" :size="12" />
              </span>
            </div>
            <div class="lr-nm">{{ s.label }}</div>
          </div>
        </div>

        <!-- Documentaire (en dessous : IF/AQL sous la fin de fab, IC/AQL sous le conditionnement) -->
        <div v-if="docs" class="lr-grid lr-below" :style="gridCols">
          <div v-if="fabEndIdx>=0" class="lr-bcell" :style="{ gridColumn: fabEndIdx+1 }">
            <div class="lr-conn"></div>
            <span v-for="d in docs.fab" :key="d.label" class="lr-chip" :class="'c-'+d.status"><i class="lr-cd"></i>{{ d.label }}</span>
          </div>
          <div v-if="condIdx>=0" class="lr-bcell" :style="{ gridColumn: condIdx+1 }">
            <div class="lr-conn"></div>
            <span v-for="d in docs.cond" :key="d.label" class="lr-chip" :class="'c-'+d.status"><i class="lr-cd"></i>{{ d.label }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Bande parallèle : dossiers analytiques + rapports de validation -->
    <div v-if="docs && docs.parallel && docs.parallel.length" class="lr-para">
      <div class="lr-paral">En parallèle — analytique &amp; validation</div>
      <div class="lr-parow">
        <span v-for="d in docs.parallel" :key="d.label" class="lr-chip" :class="['c-'+d.status, d.status==='na' ? 'is-na' : '']">
          <i class="lr-cd"></i>{{ d.label }}<template v-if="d.status==='na'"> — N/A</template>
        </span>
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
    var gridCols = computed(function() { return { gridTemplateColumns: 'repeat(' + (props.steps.length || 1) + ', minmax(46px, 1fr))' } })
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
    return { condIdx, fabEndIdx, gridCols, statusLabel, fmtDate }
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
.lr-l-wait { width: 7px; height: 7px; border: 2px solid var(--th-border, #d1d5db); }
.lr-scroll { overflow-x: auto; }
.lr-lanes { min-width: 540px; }
.lr-grid { display: grid; align-items: end; }
.lr-acell { display: flex; flex-direction: column; align-items: center; }
.lr-bcell { display: flex; flex-direction: column; align-items: center; }
.lr-conn { width: 2px; height: 9px; background: var(--th-border, #d1d5db); }
.lr-step { text-align: center; position: relative; padding: 0 3px; min-width: 0; }
.lr-top { height: 30px; }
.lr-st { display: block; font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: .3px; color: var(--th-text3, #9ca3af); }
.lr-dt { font-size: 11px; color: var(--th-text2, #6b7280); }
.lr-dr { position: relative; height: 24px; display: flex; align-items: center; justify-content: center; margin: 3px 0; }
.lr-dr::before { content: ''; position: absolute; top: 50%; left: -50%; width: 100%; height: 2px; background: var(--th-border, #e5e7eb); }
.lr-step:first-child .lr-dr::before { display: none; }
.lr-dot { position: relative; z-index: 1; width: 22px; height: 22px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #fff; background: var(--th-border, #d1d5db); }
.lr-nm { font-size: 11px; font-weight: 500; color: var(--th-text, #111827); line-height: 1.2; margin-top: 2px; }
.is-done .lr-st { color: #1D9E75; } .is-done .lr-dot { background: #1D9E75; }
.is-current .lr-st { color: var(--th-accent, #2563eb); } .is-current .lr-dot { background: var(--th-accent, #2563eb); }
.is-ko .lr-st { color: #E24B4A; } .is-ko .lr-dot { background: #E24B4A; }
.is-wait .lr-dot { background: transparent; border: 2px solid var(--th-border, #d1d5db); }
.lr-chip { display: inline-flex; align-items: center; gap: 5px; border: 1px solid var(--th-border, #e5e7eb); border-radius: 6px; padding: 2px 7px; font-size: 10.5px; font-weight: 500; color: var(--th-text, #111827); background: var(--th-bg, #fff); margin: 1px; line-height: 1.5; white-space: nowrap; }
.lr-cd { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; background: var(--th-text3, #9ca3af); }
.c-done .lr-cd { background: #1D9E75; }
.c-cur .lr-cd { background: var(--th-accent, #2563eb); }
.c-ko .lr-cd { background: #E24B4A; }
.c-wait .lr-cd { background: var(--th-text3, #9ca3af); }
.is-na { opacity: .5; }
.lr-para { margin-top: 14px; border-top: 1px solid var(--th-border, #eee); padding-top: 10px; }
.lr-paral { font-size: 11px; text-transform: uppercase; letter-spacing: .4px; color: var(--th-text3, #9ca3af); margin-bottom: 6px; }
.lr-parow { display: flex; flex-wrap: wrap; gap: 6px; }
</style>
