import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
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
        runtimeCaching: [
          {
            // Usar variable de entorno en lugar de URL hardcodeada
            urlPattern: /^https:\/\/[a-zA-Z0-9_-]+\.supabase\.co\/.*/i,
            handler: 'NetworkFirst',
            options: {
              cacheName: 'supabase-api-cache',
              expiration: {
                maxEntries: 100,
                maxAgeSeconds: 60 * 60 * 24 * 7 // 1 week
              },
              cacheableResponse: {
                statuses: [0, 200]
              }
            }
          }
        ]
      },
      manifest: {
        name: 'WebNotas Docentes',
        short_name: 'WebNotas',
        description: 'Plataforma de gestión de calificaciones',
        theme_color: '#4f46e5',
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
          }
        ]
      }
    })
  ]
})
