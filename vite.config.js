import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  base: '/liberation-tracker/',
  plugins: [vue()],
  resolve: { alias: { '@': '/src' } },
})
