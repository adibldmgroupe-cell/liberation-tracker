import { ref, watch } from 'vue'

// Singleton partagé entre toutes les pages tracking
var _theme = ref(localStorage.getItem('tracking_theme') || 'night')

watch(_theme, function(v) {
  localStorage.setItem('tracking_theme', v)
})

export function useTheme() {
  return { theme: _theme }
}
