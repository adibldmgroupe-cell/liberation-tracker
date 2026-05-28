<template>
  <div class="analytics" :data-theme="theme">
    <div class="ph">
      <span class="pt">ANALYTICS TRS</span>
      <div class="theme-sw">
        <button class="tsw-btn" :class="{active:theme==='night'}" @click="theme='night'" title="Nuit">🌙</button>
        <button class="tsw-btn" :class="{active:theme==='day'}" @click="theme='day'" title="Jour">☀️</button>
        <button class="tsw-btn" :class="{active:theme==='workshop'}" @click="theme='workshop'" title="Atelier">🏭</button>
      </div>
    </div>
    <div class="wip">Page en cours de développement — disponible dans l'étape suivante.</div>
  </div>
</template>
<script>
import { useTheme } from '../../composables/useTheme'
export default {
  setup() {
    var { theme } = useTheme()
    return { theme }
  }
}
</script>
<style scoped>
.analytics { min-height:100%; background:#0b0b1c; color:#e0e0f0; font-family:'Inter',sans-serif; font-size:13px; padding:12px 16px; }
.ph { display:flex; align-items:center; justify-content:space-between; padding-bottom:10px; border-bottom:2px solid #1a1a38; margin-bottom:16px; }
.pt { font-size:11px; font-weight:600; letter-spacing:1.5px; text-transform:uppercase; color:#a0a0c8; }
.wip { padding:40px; text-align:center; color:#4a4a70; font-size:14px; border:1px dashed #252545; border-radius:4px; }

/* ── JOUR ── */
.analytics[data-theme="day"] { background:#f0f2f5; color:#1a1a2e; }
.analytics[data-theme="day"] .ph { border-bottom-color:#d8dce8; }
.analytics[data-theme="day"] .pt { color:#5a5a8a; }
.analytics[data-theme="day"] .wip { color:#bbb; border-color:#ddd; }

/* ── ATELIER ── */
.analytics[data-theme="workshop"] { background:#161616; color:#f0f0f0; }
.analytics[data-theme="workshop"] .ph { border-bottom-color:#2a2a2a; }
.analytics[data-theme="workshop"] .pt { color:#aaa; letter-spacing:2px; }
.analytics[data-theme="workshop"] .wip { color:#555; border-color:#2a2a2a; }
</style>
