# Cabeceras de seguridad del despliegue

El repositorio incluye dos configuraciones equivalentes:

- `app/vercel.json` para Vercel cuando la raíz del proyecto es `app`.
- `app/public/_headers` para hosts estáticos que reconocen el formato de Netlify o Cloudflare Pages.
- `app/public/.htaccess` para el despliegue actual en Hostinger Web/Cloud: fuerza HTTPS, conserva el fallback de Vue Router, aplica las cabeceras y configura caché segura para HTML/service worker y assets versionados.

Ambas configuran CSP, HSTS, protección contra iframes, bloqueo de MIME sniffing, política de referencia, permisos del navegador y aislamiento del opener. La CSP permite únicamente los recursos propios, Supabase y el cargador PDF actual de jsDelivr; no admite `unsafe-eval`.

## Verificación obligatoria

Después de desplegar, comprobar la página inicial y una ruta profunda:

```powershell
$response = Invoke-WebRequest -Uri 'https://DOMINIO/' -Method Head
$response.Headers['Content-Security-Policy']
$response.Headers['Strict-Transport-Security']
$response.Headers['X-Content-Type-Options']
$response.Headers['Referrer-Policy']
$response.Headers['Permissions-Policy']
```

La puerta se aprueba cuando todas están presentes por HTTPS, `frame-ancestors 'none'` y `X-Frame-Options: DENY` impiden embeber la aplicación, y la consola no reporta recursos legítimos bloqueados.

Antes de activar una interfaz Kushki, añadir exclusivamente los dominios oficiales que exija la modalidad contratada a `script-src`, `connect-src` o `frame-src`; no usar comodines generales ni habilitar `unsafe-eval`.

## Publicación en Hostinger

1. Ejecutar `npm ci`, `npm test -- --run`, `npm run build` y `npm run check:bundle` dentro de `app`.
2. Subir **el contenido interno** de `app/dist/` a `public_html`; no subir la carpeta `dist` como subcarpeta.
3. Confirmar que `public_html/.htaccess` fue cargado. Al ser un archivo oculto puede omitirse si el cliente FTP no muestra dotfiles.
4. Eliminar assets antiguos `assets/index-*` que ya no estén referenciados, sin borrar el nuevo directorio `assets` durante una publicación activa.
5. Purgar la caché/CDN desde hPanel después de reemplazar los archivos.
6. Verificar `/`, `/login`, `/planes` y una ruta profunda mediante HTTPS, y revisar las cabeceras con el comando anterior.

En planes Hostinger Agency puede ser necesario habilitar soporte `.htaccess` desde hPanel. Esta configuración no aplica a Hostinger Website Builder/Horizons.
