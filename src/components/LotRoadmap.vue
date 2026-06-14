<template>
  <div class="lr">
    <div class="lr-head">
      <span class="lr-kicker">Feuille de route — production</span>
      <div class="lr-legend">
        <span><i class="lr-lg lr-l-done"></i>Terminé</span>
        <span><i class="lr-lg lr-l-cur"></i>En cours</span>
        <span><i class="lr-lg lr-l-wait"></i>À venir</span>
      </div>
    </div>
    <div class="lr-track">
      <div class="lr-step" v-for="s in steps" :key="s.key" :class="'is-'+s.status">
        <div class="lr-top">
          <span class="lr-st">{{ statusLabel(s) }}</span>
          <span class="lr-dt">{{ s.date ? fmtDate(s.date) : '—' }}</span>
        </div>
        <div class="lr-dr">
          <span class="lr-dot">
            <NavIcon v-if="s.status==='done'" name="check" :size="12" />
            <NavIcon v-else-if="s.status==='ko'" name="x" :size="12" />
          </span>
        </div>
        <div class="lr-nm">{{ s.label }}</div>
      </div>
    </div>
  </div>
</template>
<script>
import NavIcon from './NavIcon.vue'
export default {
  name: 'LotRoadmap',
  components: { NavIcon },
  props: { steps: { type: Array, default: function() { return [] } } },
  setup() {
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
    return { statusLabel, fmtDate }
  }
}
</script>
<style scoped>
.lr { background: var(--th-bg2, #f9fafb); border: 1px solid var(--th-border, #e5e7eb); border-radius: 10px; padding: 16px 18px; margin-bottom: 16px; }
.lr-head { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; margin-bottom: 14px; }
.lr-kicker { font-size: 11px; text-transform: uppercase; letter-spacing: .5px; color: var(--th-accent, #2563eb); font-weight: 600; }
.lr-legend { display: flex; gap: 12px; font-size: 11px; color: var(--th-text2, #6b7280); }
.lr-legend span { display: flex; align-items: center; gap: 5px; }
.lr-lg { width: 10px; height: 10px; border-radius: 50%; }
.lr-l-done { background: #1D9E75; }
.lr-l-cur { background: var(--th-accent, #2563eb); }
.lr-l-wait { width: 8px; height: 8px; border: 2px solid var(--th-border, #d1d5db); }
.lr-track { display: flex; }
.lr-step { flex: 1; text-align: center; position: relative; padding: 0 2px; min-width: 0; }
.lr-top { height: 30px; }
.lr-st { display: block; font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: .3px; color: var(--th-text3, #9ca3af); }
.lr-dt { font-size: 11px; color: var(--th-text2, #6b7280); }
.lr-dr { position: relative; height: 24px; display: flex; align-items: center; justify-content: center; margin: 3px 0; }
.lr-dr::before { content: ''; position: absolute; top: 50%; left: -50%; width: 100%; height: 2px; background: var(--th-border, #e5e7eb); }
.lr-step:first-child .lr-dr::before { display: none; }
.lr-dot { position: relative; z-index: 1; width: 22px; height: 22px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #fff; background: var(--th-border, #d1d5db); }
.lr-nm { font-size: 11.5px; font-weight: 500; color: var(--th-text, #111827); line-height: 1.2; margin-top: 2px; }
.is-done .lr-st { color: #1D9E75; }
.is-done .lr-dot { background: #1D9E75; }
.is-current .lr-st { color: var(--th-accent, #2563eb); }
.is-current .lr-dot { background: var(--th-accent, #2563eb); }
.is-ko .lr-st { color: #E24B4A; }
.is-ko .lr-dot { background: #E24B4A; }
.is-wait .lr-dot { background: transparent; border: 2px solid var(--th-border, #d1d5db); }
@media (max-width: 640px) {
  .lr-track { flex-direction: column; align-items: stretch; }
  .lr-step { display: grid; grid-template-columns: 26px 1fr auto; align-items: center; gap: 10px; text-align: left; padding: 5px 0; }
  .lr-top { height: auto; order: 3; text-align: right; }
  .lr-st { display: inline; }
  .lr-dr { order: 1; margin: 0; height: 30px; }
  .lr-dr::before { top: -50%; left: 50%; transform: translateX(-50%); width: 2px; height: 100%; }
  .lr-step:first-child .lr-dr::before { display: block; top: 50%; height: 50%; }
  .lr-nm { order: 2; margin-top: 0; }
}
</style>
