import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (
            id.includes('read-excel-file') ||
            id.includes('fflate') ||
            id.includes('saxen') ||
            id.includes('unzipper-esm') ||
            id.includes('worker-f')
          ) {
            return 'read-excel-file'
          }
        },
      },
    },
  },
  test: {
    exclude: ['**/node_modules/**', '**/dist/**', '**/e2e/**'],
  },
  server: {
    /** Si 5173 está ocupado, Vite usa el siguiente libre: revisa la URL que imprime la consola. */
    strictPort: false,
  },
  plugins: [
    vue(),
    VitePWA({
      registerType: 'autoUpdate',
      /** En desarrollo no registrar SW (evita caché rota y “pantalla que no carga”). */
      devOptions: {
        enabled: false,
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg}'],
        globIgnores: ['**/read-excel-file-*.js'],
        cleanupOutdatedCaches: true,
      },
      manifest: {
        name: 'LOGREVA — Gestión Educativa',
        short_name: 'LOGREVA',
        description: 'Plataforma institucional de gestión académica',
        theme_color: '#0B1530',
        background_color: '#F8FAFC',
        display: 'standalone',
        icons: [
          {
            src: 'pwa-192x192.png',
            sizes: '192x192',
            type: 'image/png'
          },
          {
            src: 'pwa-512x512.png',
            sizes: '512x512',
            type: 'image/png'
          },
          {
            src: 'pwa-512x512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'maskable'
          }
        ]
      }
    })
  ]
})
