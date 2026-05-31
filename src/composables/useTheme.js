import { ref, watch } from 'vue'

// Singleton partagé — thème persisté en localStorage + appliqué sur <html>
var _theme = ref(localStorage.getItem('tracking_theme') || 'night')

// Application immédiate au chargement
document.documentElement.setAttribute('data-theme', _theme.value)

watch(_theme, function(v) {
  localStorage.setItem('tracking_theme', v)
  document.documentElement.setAttribute('data-theme', v)
})

export function useTheme() {
  return { theme: _theme }
}
